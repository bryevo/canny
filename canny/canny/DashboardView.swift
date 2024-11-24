//
//  DashboardView.swift
//  canny
//
//  Created by Brian Vo on 11/9/24.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authViewModel: AuthManager
    @State private var accounts: [String: Plaid.AccountBase] = [:]
    
    var body: some View {
        VStack(spacing: 20) {
            // Iterate through the dictionary
            ForEach(accounts.map { $0.value }, id: \.account_id) { account in
                VStack(alignment: .leading) {
                    Text("Name: \(account.official_name ?? account.name)").font(.system(size: 17, weight: .medium))
                    
                    Text("Available Balance: \(account.balances.available ?? 0, specifier: "%.2f")").font(.system(size: 17, weight: .medium))
                    
                    Text("Current Balance: \(account.balances.current ?? 0, specifier: "%.2f")").font(.system(size: 17, weight: .medium))
                    
                }
            }.padding()
            NavigationLink("Add new account", destination: PlaidContentView()).padding()
            Button(action: logout, label:  {
                Text("Logout")
                    .font(.system(size: 17, weight: .medium))
            })
            .padding()
            .cornerRadius(4)
        }.padding()
            .onAppear {
                loadAccountSummary() // Call the function when the view appears
            }
    }
    
    
    private func logout() {
        AuthManager.logout() { loggedOut in
            Task { @MainActor  in
                authViewModel.isLoggedIn = false
                print("Logged out")
            }
        }
    }
    
    
    struct Plaid: Codable {
        struct AccountBase: Codable {
            let account_id: String
            let balances: Plaid.AccountBalance
            let name: String
            let official_name: String?
            let subtype: String
            let type: String
        }
        struct AccountBalance: Codable {
            let available: Double?
            let current: Double?
            let iso_currency_code: String
            let limit: Double?
        }
    }
    
    private func loadAccountSummary() {
        print("Loading Account Summary...")
        Task { @MainActor in
            let accessTokensKeyChain = AuthManager.loadFromKeychain(key: "plaid-access-tokens")
            var accessTokens: [String] = []
            if let accessTokensKeyChain {
                accessTokens = try JSONDecoder().decode([String].self, from: Data(accessTokensKeyChain.utf8))
            }
            else {
                accessTokens = await self.getAccessTokens() ?? []
            }
            if let accountSummmaryResponse = await self.getAccountSummary(accessTokens: accessTokens) {
                accounts = accountSummmaryResponse
                print("Account summary loaded")
            }
        }
    }
    
    private func getAccessTokens() async -> [String]? {
        // Define the URL for the request
        guard let url = URL(string: "http://localhost:3000/get-access-tokens") else {
            return nil
        }
        // Create a URLRequest with headers
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthManager.loadFromKeychain(key: "jwtToken"), forHTTPHeaderField: "canny-access-token")
        request.setValue(AuthManager.loadFromKeychain(key: "refreshToken"), forHTTPHeaderField: "canny-refresh-token")
        // Use URLSession to make the request
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if the response is successful
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                AuthManager.deleteFromKeychain(key: "jwtToken")
                AuthManager.deleteFromKeychain(key: "refreshToken")
                authViewModel.isLoggedIn = false
                return nil
            }
            
            // Return the response data as a string
            let accessTokenResponse = try JSONDecoder().decode([String].self, from: data)
            AuthManager.saveToKeychain(key: "plaid-access-tokens", token: jsonStringify(accessTokenResponse)!)
            return accessTokenResponse
        } catch {
            // Handle any errors
            print("Error making request: \(error)")
            return nil
        }
    }
    private func getAccountSummary(accessTokens:[String]) async -> [String: Plaid.AccountBase]? {
        // Define the URL for the request
        guard let url = URL(string: "http://localhost:3000/get-account-summaries") else {
            return nil
        }
        // Create a URLRequest with headers
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(AuthManager.loadFromKeychain(key: "jwtToken"), forHTTPHeaderField: "canny-access-token")
        request.setValue(AuthManager.loadFromKeychain(key: "refreshToken"), forHTTPHeaderField: "canny-refresh-token")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: accessTokens, options: [])
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check if the response is successful
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                AuthManager.deleteFromKeychain(key: "jwtToken")
                AuthManager.deleteFromKeychain(key: "refreshToken")
                authViewModel.isLoggedIn = false
                return nil
            }
            // Return the response data as a string
            return try JSONDecoder().decode([String: Plaid.AccountBase].self, from: data)
        } catch {
            // Handle any errors
            print("Error making request: \(error)")
            return nil
        }
    }
}

#Preview {
    DashboardView()
}
