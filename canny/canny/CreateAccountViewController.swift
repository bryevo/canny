//
//  CreateAccountViewController.swift
//  canny
//
//  Created by Brian Vo on 10/19/24.
//
import iPhoneNumberField
import SwiftUI

struct CreateAccountView: View {
  @State private var fullName = "Brian Vo"
  @State private var email = "bryevo@gmail.com"
  @State private var phoneNumber = "+18587173976"
  @State var isEditingPN: Bool = false
  @State private var password = "test123"
  @State private var verifyPassword = "test123"
  @State private var showingAlert = false
  @State private var alertMessage = ""

  var body: some View {
    VStack(spacing: 20) {
      TextField("Full Name", text: $fullName)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.horizontal)

      TextField("Email", text: $email)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .keyboardType(.emailAddress)
        .autocapitalization(.none)
        .padding(.horizontal)

      iPhoneNumberField("(000) 000-0000", text: $phoneNumber, isEditing: $isEditingPN)
        .flagHidden(false)
        .flagSelectable(true)
        .font(UIFont(size: 30, weight: .light, design: .monospaced))
        .maximumDigits(10)
        .foregroundColor(Color.black)
        .clearButtonMode(.whileEditing)
        .onClear { _ in isEditingPN.toggle() }
        .accentColor(Color.black)
        .padding()
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: isEditingPN ? .gray : .white, radius: 10)
        .padding()

      SecureField("Password", text: $password)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.horizontal)

      SecureField("Verify Password", text: $verifyPassword)
        .textFieldStyle(RoundedBorderTextFieldStyle())
        .padding(.horizontal)

      Button(action: createAccount) {
        Text("Create Account")
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

  func createAccount() {
    guard !fullName.isEmpty, !email.isEmpty, !phoneNumber.isEmpty, !password.isEmpty else {
      alertMessage = "Please fill in all fields."
      showingAlert = true
      return
    }

    guard password == verifyPassword else {
      alertMessage = "Passwords do not match."
      showingAlert = true
      return
    }

    guard let url = URL(string: Constants.API.Auth.CREATE_ACCOUNT) else {
      alertMessage = "Invalid URL."
      showingAlert = true
      return
    }

    let parameters: [String: Any] = [
      "fullName": fullName,
      "email": email,
      "phoneNumber": phoneNumber,
      "password": password
    ]

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    do {
      request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])
    } catch {
      alertMessage = "Error serializing JSON."
      showingAlert = true
      return
    }

    URLSession.shared.dataTask(with: request) { _, response, error in
      if let error {
        DispatchQueue.main.async {
          alertMessage = "Error: \(error.localizedDescription)"
          showingAlert = true
        }
        return
      }

      if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
        DispatchQueue.main.async {
          alertMessage = "Invalid response code: \(httpResponse.statusCode)"
          showingAlert = true
        }
        return
      }

      DispatchQueue.main.async {
        alertMessage = "Account created successfully!"
        showingAlert = true
      }

    }.resume()
  }
}

struct CreateAccountView_Previews: PreviewProvider {
  static var previews: some View {
    CreateAccountView()
  }
}
