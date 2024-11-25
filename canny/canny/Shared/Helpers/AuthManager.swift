//
//  AuthManager.swift
//  canny
//
//  Created by Brian Vo on 10/21/24.
//
import Security
import SwiftUI

class AuthManager: ObservableObject {
  @Published var isLoggedIn: Bool = false
  init() {
    self.isLoggedIn = AuthManager.loadFromKeychain(key: Keys.JWT_TOKEN) != nil && AuthManager
      .loadFromKeychain(key: Keys.REFRESH_TOKEN) != nil
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
    let url = URL(string: Constants.API.Auth.LOGIN)!
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
      guard let data else {
        DispatchQueue.main.async {
          completion(nil)
        }
        return
      }
      do {
        let responseData = try JSONDecoder().decode(LoginResponseData.self, from: data)
        let jwt = responseData.token
        let refreshToken = responseData.refreshToken
        updateToKeychain(key: Keys.JWT_TOKEN, token: jwt)
        updateToKeychain(key: Keys.REFRESH_TOKEN, token: refreshToken)
        updateToKeychain(key: Keys.USER_ID, token: responseData.id.uuidString)
        updateToKeychain(key: Keys.EMAIL, token: email)
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
    let url = URL(string: Constants.API.Auth.LOGOUT)!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"

    // Assuming you have login credentials to send
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(AuthManager.loadFromKeychain(key: Keys.JWT_TOKEN), forHTTPHeaderField: Keys.JWT_TOKEN)
    request.setValue(UIDevice.current.identifierForVendor?.uuidString, forHTTPHeaderField: "device-id")

    URLSession.shared.dataTask(with: request) { _, response, error in
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
      deleteFromKeychain(key: Keys.JWT_TOKEN)
      deleteFromKeychain(key: Keys.REFRESH_TOKEN)
      deleteFromKeychain(key: Keys.PLAID_ACCESS_TOKENS)
      deleteFromKeychain(key: Keys.USER_ID)
      deleteFromKeychain(key: Keys.EMAIL)
      completion(nil)
    }.resume()
  }
}
