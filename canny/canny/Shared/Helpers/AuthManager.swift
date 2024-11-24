//
//  AuthManager.swift
//  canny
//
//  Created by Brian Vo on 10/21/24.
//
import SwiftUI
import Security

class AuthManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    init() {
        isLoggedIn = AuthManager.loadFromKeychain(key: "jwtToken") != nil && AuthManager.loadFromKeychain(key: "refreshToken") != nil
    }
    struct GetAccessTokenResponse: Codable {
        let item_id: String
        let access_token: String
        let request_id: String
    }
    
    // Keychain Helper
    static func saveToKeychain(key: String, token: String) {
        let data = Data(token.utf8)
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data
        ] as CFDictionary
        
        SecItemAdd(query, nil)
    }
    
    static func loadFromKeychain(key: String) -> String? {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ] as CFDictionary
        
        var result: AnyObject?
        SecItemCopyMatching(query, &result)
        
        if let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func deleteFromKeychain(key: String) {
        let query = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ] as CFDictionary
        
        SecItemDelete(query)
    }
    
    static func updateToKeychain(key: String, token: String) {
        deleteFromKeychain(key: key)
        saveToKeychain(key: key, token: token)
    }
    
    struct LoginResponseData: Codable {
        let id: UUID
        let token: String
        let refreshToken: String
    }
    
    static func login(email: String, password: String, completion: @escaping (UUID?) -> Void) {
        let url = URL(string: "http://localhost:3000/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Assuming you have login credentials to send
        let body = ["email": email, "password": password]
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UIDevice.current.identifierForVendor?.uuidString, forHTTPHeaderField: "device-id")
        request.setValue(UIDevice.current.model, forHTTPHeaderField: "device-model")
        request.setValue(UIDevice.current.name, forHTTPHeaderField: "device-name")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    // Handle error appropriately
                    completion(nil)
                }
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    // Handle invalid response code
                    completion(nil)
                }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            do {
                let responseData = try JSONDecoder().decode(LoginResponseData.self, from: data)
                let jwt = responseData.token
                let refreshToken = responseData.refreshToken
                updateToKeychain(key: "jwtToken", token: jwt)
                updateToKeychain(key: "refreshToken", token: refreshToken)
                completion(responseData.id)
            } catch {
                DispatchQueue.main.async {
                    // Handle JSON decoding error
                    completion(nil)
                }
            }
            
        }.resume()
    }
    
    static func logout(completion: @escaping (UUID?) -> Void) {
        let url = URL(string: "http://localhost:3000/logout")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Assuming you have login credentials to send
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthManager.loadFromKeychain(key: "jwtToken"), forHTTPHeaderField: "canny-access-token")
        request.setValue(UIDevice.current.identifierForVendor?.uuidString, forHTTPHeaderField: "device-id")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if error != nil {
                DispatchQueue.main.async {
                    // Handle error appropriately
                    completion(nil)
                }
                return
            }
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    // Handle invalid response code
                    completion(nil)
                }
                return
            }
            deleteFromKeychain(key: "jwtToken")
            deleteFromKeychain(key: "refreshToken")
            deleteFromKeychain(key: "plaid-access-tokens")
            completion(nil)
        }.resume()
    }
    
    // Use JWT for Authenticated Requests
    static func makeAuthenticatedRequest() {
        guard let token = loadFromKeychain(key: "jwtToken") else { return }
        
        var request = URLRequest(url: URL(string: "https://your-api-endpoint.com/protected")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }.resume()
    }
    
    // Refresh JWT
    static func refreshJWT() {
        guard let refreshToken = loadFromKeychain(key: "refreshToken") else { return }
        
        var request = URLRequest(url: URL(string: "https://your-api-endpoint.com/refresh")!)
        request.httpMethod = "POST"
        
        // Assuming refresh token needs to be sent in the body
        let body = ["refresh_token": refreshToken]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newJwt = json["token"] as? String {
                DispatchQueue.main.async {
                    updateToKeychain(key: "jwtToken",token: newJwt)
                }
            }
        }.resume()
    }
}
