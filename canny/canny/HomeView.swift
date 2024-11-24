//
//  HomeView.swift
//  canny
//
//  Created by Brian Vo on 10/27/24.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthManager
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var id: UUID?
    @State private var token: String?
    @State private var path = NavigationPath()
    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 20) {
                if authViewModel.isLoggedIn  {
                    DashboardView()
                } else {
                    LoginAccountView()
                }
            }
        }
    }
}
