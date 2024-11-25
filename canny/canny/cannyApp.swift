//
//  cannyApp.swift
//  canny
//
//  Created by Brian Vo on 10/19/24.
//

import SwiftUI

@main
struct CannyApp: App {
  @StateObject var authViewModel = AuthManager()

  var body: some Scene {
    WindowGroup {
      NavigationStack {
        VStack {
          //                    CreateAccountView()
          //                    LoginAccountView()
          HomeView()
        }
      }.environmentObject(authViewModel)
    }
  }
}
