//
//  DashboardView.swift
//  canny
//
//  Created by Brian Vo on 11/9/24.
//

import SwiftUI

struct DashboardView: View {
  @EnvironmentObject var authViewModel: AuthManager
  @State private var accountTotal: Double = 0
  @State private var accounts: [PlaidAccountType: [PlaidAccount.AccountBase]] = [:]

  var body: some View {
    VStack(spacing: 20) {
      Text("Net Worth: $\(accountTotal, specifier: "%.2f")")
        .font(.title)
        .fontWeight(.bold)
      if accounts[PlaidAccountType.depository] != nil {
        AccordionView(
          title: "Bank Accounts",
          cards: accounts[.depository]?.map { account in
            CardView(
              name: account.officialName ?? account.name,
              balance: account.balances.current,
              currencyCode: account.balances.isoCurrencyCode
            )
          } ?? []
        )
      }
      if accounts[PlaidAccountType.credit] != nil {
        AccordionView(
          title: "Credit Cards",
          cards: accounts[.credit]?.map { account in
            CardView(
              name: account.officialName ?? account.name,
              balance: account.balances.current,
              currencyCode: account.balances.isoCurrencyCode
            )
          } ?? []
        )
      }
      if accounts[PlaidAccountType.investment] != nil {
        AccordionView(
          title: "Investments",
          cards: accounts[.investment]?.map { account in
            CardView(
              name: account.officialName ?? account.name,
              balance: account.balances.current,
              currencyCode: account.balances.isoCurrencyCode
            )
          } ?? []
        )
      }
      NavigationLink("Add new account", destination: PlaidContentView()).padding()
      Button(action: logout, label: {
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
    AuthManager.logout { _ in
      Task { @MainActor in
        authViewModel.isLoggedIn = false
        print("Logged out")
      }
    }
  }

  private func loadAccountSummary() {
    print("Loading Account Summary...")
    Task { @MainActor in
      let accessTokensKeyChain = AuthManager.loadFromKeychain(key: Keys.PLAID_ACCESS_TOKENS)
      var accessTokens: [String] = []
      if let accessTokensKeyChain {
        accessTokens = try JSONDecoder().decode([String].self, from: Data(accessTokensKeyChain.utf8))
      } else {
        accessTokens = await getAccessTokens() ?? []
      }
      if let accountSummmaryResponse = await getAccountSummary(accessTokens: accessTokens) {
        accountTotal = 0
        for (key, accs) in accountSummmaryResponse {
          if let accountType = PlaidAccountType(rawValue: key) {
            accounts[accountType] = accs
            if key != PlaidAccountType.credit.rawValue {
              accountTotal += accs.reduce(0.0) { partialSum, account in
                partialSum + account.balances.current
              }
            } else {
              accountTotal -= accs.reduce(0.0) { partialSum, account in
                partialSum + account.balances.current
              }
            }
          }
        }
        print("Account summary loaded")
      }
    }
  }

  private func getAccessTokens() async -> [String]? {
    // Define the URL for the request
    guard let url = URL(string: Constants.API.Plaid.GET_ACCESS_TOKENS) else {
      return nil
    }
    // Create a URLRequest with headers
    var request = URLRequest(url: url)
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(AuthManager.loadFromKeychain(key: Keys.JWT_TOKEN), forHTTPHeaderField: Keys.JWT_TOKEN)
    request.setValue(AuthManager.loadFromKeychain(key: Keys.REFRESH_TOKEN), forHTTPHeaderField: Keys.REFRESH_TOKEN)
    // Use URLSession to make the request
    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      // Check if the response is successful
      guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        AuthManager.deleteFromKeychain(key: Keys.JWT_TOKEN)
        AuthManager.deleteFromKeychain(key: Keys.REFRESH_TOKEN)
        authViewModel.isLoggedIn = false
        return nil
      }

      // Return the response data as a string
      let accessTokenResponse = try JSONDecoder().decode([String].self, from: data)
      AuthManager.saveToKeychain(key: Keys.PLAID_ACCESS_TOKENS, token: jsonStringify(accessTokenResponse)!)
      return accessTokenResponse
    } catch {
      // Handle any errors
      print("Error making request: \(error)")
      return nil
    }
  }

  private func getAccountSummary(accessTokens: [String]) async -> [String: [PlaidAccount.AccountBase]]? {
    // Define the URL for the request
    guard let url = URL(string: Constants.API.Plaid.GET_ACCOUNT_SUMMARY) else {
      return nil
    }
    // Create a URLRequest with headers
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(AuthManager.loadFromKeychain(key: Keys.JWT_TOKEN), forHTTPHeaderField: Keys.JWT_TOKEN)
    request.setValue(AuthManager.loadFromKeychain(key: Keys.REFRESH_TOKEN), forHTTPHeaderField: Keys.REFRESH_TOKEN)
    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: accessTokens, options: [])
      let (data, response) = try await URLSession.shared.data(for: request)

      // Check if the response is successful
      guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
        AuthManager.deleteFromKeychain(key: Keys.JWT_TOKEN)
        AuthManager.deleteFromKeychain(key: Keys.REFRESH_TOKEN)
        authViewModel.isLoggedIn = false
        return nil
      }
      // Return the response data as a string
      return try JSONDecoder().decode([String: [PlaidAccount.AccountBase]].self, from: data)
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
