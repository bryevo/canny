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
      guard let self else { return }
      if let result {
        switch result {
        case let .success(handler):
          Task { @MainActor in
            self.linkController = LinkController(handler: handler)
          }
        case let .failure(createError):
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
    guard let url = URL(string: PlaidAPI.GET_LINK_TOKEN) else {
      return (nil, NSError(domain: "Invalid URL", code: 400, userInfo: nil))
    }
    if AuthManager.loadFromKeychain(key: Keys.USER_ID) == nil || AuthManager.loadFromKeychain(key: Keys.EMAIL) == nil {
      return (nil, NSError(domain: "Unable to get user information", code: 401, userInfo: nil))
    }
    // Prepare the request body
    let body: [String: String] = [
      "id": AuthManager.loadFromKeychain(key: Keys.USER_ID)!,
      "email": AuthManager.loadFromKeychain(key: Keys.EMAIL)!
    ]
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(AuthManager.loadFromKeychain(key: Keys.JWT_TOKEN), forHTTPHeaderField: Keys.JWT_TOKEN)
    request.setValue(AuthManager.loadFromKeychain(key: Keys.REFRESH_TOKEN), forHTTPHeaderField: Keys.REFRESH_TOKEN)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)
      if let httpResponse = response as? HTTPURLResponse {
        // Access the response headers
        if let updatedJwtToken = httpResponse.allHeaderFields[Keys.JWT_TOKEN] as? String {
          AuthManager.updateToKeychain(key: Keys.JWT_TOKEN, token: updatedJwtToken)
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
    let (linkToken, error) = await generateLinkToken()
    if let error {
      print("Error: \(error.localizedDescription)")
    } else if let linkToken {
      var linkConfiguration = LinkTokenConfiguration(token: linkToken) { success in
        Task { @MainActor in
          // Make asynchronous calls here
          self.accessToken = await self.getAccessToken(publicToken: success.publicToken) ?? ""
          let accessTokensKeyChain = AuthManager.loadFromKeychain(key: Keys.PLAID_ACCESS_TOKENS)
          var accessTokens: [String] = []
          if let accessTokensKeyChain {
            accessTokens = try JSONDecoder().decode([String].self, from: Data(accessTokensKeyChain.utf8))
            if !accessTokens.contains(self.accessToken) {
              accessTokens.append(self.accessToken)
            }
          }
          AuthManager.updateToKeychain(key: Keys.PLAID_ACCESS_TOKENS, token: jsonStringify(accessTokens)!)
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
      linkConfiguration.onEvent = { _ in
        //                print("Link Event: \(event)")
      }

      return linkConfiguration
    }
    return nil
  }

  private func getAccessToken(publicToken: String) async -> String? {
    // Define the URL for the request
    guard let url = URL(string: PlaidAPI.EXCHANGE_PUBLIC_FOR_ACCESS_TOKEN) else {
      return nil
    }

    // Create a URLRequest with headers
    var request = URLRequest(url: url)
    request.setValue(publicToken, forHTTPHeaderField: Constants.Headers.PLAID_PUBLIC_TOKEN)
    request.setValue(AuthManager.loadFromKeychain(key: Keys.JWT_TOKEN), forHTTPHeaderField: Keys.JWT_TOKEN)
    request.setValue(AuthManager.loadFromKeychain(key: Keys.REFRESH_TOKEN), forHTTPHeaderField: Keys.REFRESH_TOKEN)

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
