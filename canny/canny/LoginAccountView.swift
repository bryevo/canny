//
//  CreateAccountViewController.swift
//  canny
//
//  Created by Brian Vo on 10/19/24.
//
import SwiftUI
import CryptoKit

struct LoginAccountView: View {
    @EnvironmentObject var authViewModel: AuthManager
    @State private var email = "bryevo@gmail.com"
    @State private var password = "test123"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var id: UUID?
    @State private var token: String?
    
    var body: some View {
            VStack(spacing: 20) {
                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                
                Button(action: login) {
                    Text("Login")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding()
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        
    }
    
    func login() {
        guard  !email.isEmpty,  !password.isEmpty else {
            alertMessage = "Please fill in all fields."
            showingAlert = true
            return
        }
        AuthManager.login(email: self.email, password: self.password) { userId in
            if userId != nil {
                DispatchQueue.main.async {
                    authViewModel.isLoggedIn = true
                    print("GO TO PLAID")
                }
            } else {
                alertMessage = "Login failed."
                showingAlert = true
                return
            }
        }
    }
}

struct LoginAccountView_Previews: PreviewProvider {
    static var previews: some View {
        LoginAccountView()
    }
}
