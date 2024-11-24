//
//  Constants.swift
//  canny
//
//  Created by Brian Vo on 11/24/24.
//

import Foundation
typealias Keys = Constants.Keys
typealias PlaidAPI = Constants.API.Plaid

struct Constants {
    struct API {
        //                static let BASE_URI = "https://api.canny.io"
        static let BASE_URI = "http://localhost:3000/api"
        struct Auth {
            static let AUTH_BASE_URI = BASE_URI + "/auth"
            static let CREATE_ACCOUNT = AUTH_BASE_URI + "/create-account"
            static let LOGIN = AUTH_BASE_URI + "/login"
            static let LOGOUT = AUTH_BASE_URI + "/logout"
        }
        struct Plaid {
            static let PLAID_BASE_URI = BASE_URI + "/plaid"
            static let GET_LINK_TOKEN = PLAID_BASE_URI + "/get-link-token"
            static let EXCHANGE_PUBLIC_FOR_ACCESS_TOKEN = PLAID_BASE_URI + "/exchange-public-for-access-token"
            static let GET_ACCESS_TOKENS = PLAID_BASE_URI + "/get-access-tokens"
            static let GET_ACCOUNT_SUMMARY = PLAID_BASE_URI + "/get-account-summary"
        }
    }
    struct Keys {
        static let JWT_TOKEN = "canny-jwt-token"
        static let REFRESH_TOKEN = "canny-refresh-token"
        static let PLAID_ACCESS_TOKENS = "plaid-access-tokens"
        static let USER_ID = "user-id"
        static let EMAIL = "email"
    }
    struct Headers {
        static let PLAID_PUBLIC_TOKEN = "plaid-public-token"
    }
    struct Messages {
        static let errorMessage = "Something went wrong. Please try again."
        static let successMessage = "Operation completed successfully."
    }
}
