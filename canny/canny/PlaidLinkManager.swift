//
//  PlaidContentView.swift
//  canny
//
//  Created by Brian Vo on 10/20/24.
//
import LinkKit
import SwiftUI

class PlaidLinkManager: ObservableObject {
    @Published var isPresentingLink = false
    @Published var linkController: LinkController?
    private var accessToken: String = ""
    init() {
        print("Initializing Plaid Link Manager")
        createHandler { [weak self] result in
            guard let self = self else { return }
            if let result = result {
                switch result {
                case .success(let handler):
                    Task { @MainActor  in
                        self.linkController = LinkController(handler: handler)
                    }
                case .failure(let createError):
                    print("Link Creation Error: \(createError.localizedDescription)")
                }
            }
        }
    }
    
    
    private func createHandler(completion: @escaping (Result<Handler, Plaid.CreateError>?) -> Void) {
        Task {
            if let configuration = await createLinkTokenConfiguration() {
                let result = Plaid.create(configuration)
                completion(result)
            } else {
                completion(nil)
            }
        }
    }
    
    @MainActor
    func generateLinkToken() async -> (String?, Error?) {
        // Set the URL
        guard let url = URL(string: "http://localhost:3000/get-link-token") else {
            return (nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
        }
        
        // Prepare the request body
        let body: [String: String] = [
            "id": "1053c9e0-261f-4ce4-8e78-2f816e2dd22d",
            "email": "ovnairb@gmail.com"
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthManager.loadFromKeychain(key: "jwtToken"), forHTTPHeaderField: "canny-access-token")
        request.setValue(AuthManager.loadFromKeychain(key: "refreshToken"), forHTTPHeaderField: "canny-refresh-token")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // Access the response headers
                if let updatedJwtToken = httpResponse.allHeaderFields["canny-access-token"] as? String {
                    AuthManager.updateToKeychain(key: "jwtToken", token: updatedJwtToken)
                }
            }
            // Convert data to string
            if let stringData = String(data: data, encoding: .utf8) {
                return (stringData, nil)
            } else {
                return (nil, NSError(domain: "Failed to convert data to string", code: 400, userInfo: nil))
            }
        } catch {
            return (nil, error)
        }
    }
    
    func createLinkTokenConfiguration() async -> LinkTokenConfiguration? {
        let (linkToken, error) =  await generateLinkToken();
        if let error = error {
            print("Error: \(error.localizedDescription)")
        } else if let linkToken = linkToken {
            var linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
                Task { @MainActor in
                    // Make asynchronous calls here
                    self.accessToken = await self.getAccessToken(publicToken: success.publicToken) ?? ""
                    let accessTokensKeyChain = AuthManager.loadFromKeychain(key: "plaid-access-tokens")
                    var accessTokens: [String] = []
                    if let accessTokensKeyChain {
                        accessTokens = try JSONDecoder().decode([String].self, from: Data(accessTokensKeyChain.utf8))
                        if !accessTokens.contains(self.accessToken) {
                            accessTokens.append(self.accessToken)
                        }
                    }
                    AuthManager.updateToKeychain(key: "plaid-access-tokens", token: jsonStringify(accessTokens)!)
                    self.isPresentingLink = false
                }
            }
            
            // Optional closure is called when a user exits Link without successfully linking an Item,
            // or when an error occurs during Link initialization. It should take a single LinkExit argument,
            // containing an optional error and a metadata of type ExitMetadata.
            // Ref - https://plaid.com/docs/link/ios/#onexit
            linkConfiguration.onExit = { exit in
                if let error = exit.error {
                    print("exit with \(error)\n\(exit.metadata)")
                } else {
                    // User exited the flow without an error.
                    print("exit with \(exit.metadata)")
                }
                self.isPresentingLink = false
            }
            
            // Optional closure is called when certain events in the Plaid Link flow have occurred, for example,
            // when the user selected an institution. This enables your application to gain further insight into
            // what is going on as the user goes through the Plaid Link flow.
            // Ref - https://plaid.com/docs/link/ios/#onevent
            linkConfiguration.onEvent = { event in
                //                print("Link Event: \(event)")
            }
            
            return linkConfiguration
        }
        return nil
    }
    
    private func getAccessToken(publicToken: String) async -> String? {
        // Define the URL for the request
        guard let url = URL(string: "http://localhost:3000/exchange-public-for-access-token") else {
            return nil
        }
        
        // Create a URLRequest with headers
        var request = URLRequest(url: url)
        request.setValue(publicToken, forHTTPHeaderField: "plaid-public-token")
        request.setValue(AuthManager.loadFromKeychain(key: "jwtToken"), forHTTPHeaderField: "canny-access-token")
        request.setValue(AuthManager.loadFromKeychain(key: "refreshToken"), forHTTPHeaderField: "canny-refresh-token")
        
        // Use URLSession to make the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if the response is successful
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            // Return the response data as a string
            return String(data: data, encoding: .utf8)
        } catch {
            // Handle any errors
            print("Error making request: \(error)")
            return nil
        }
    }
}

