//
//  PlaidTypes.swift
//  canny
//
//  Created by Brian Vo on 11/24/24.
//

import Foundation

struct PlaidAccount: Codable {
  struct AccountBase: Codable {
    let accountID: String
    let balances: AccountBalance
    let mask: String
    let name: String
    let officialName: String?
    let subtype: String
    let type: String

    enum CodingKeys: String, CodingKey {
      case accountID = "account_id"
      case balances
      case mask
      case name
      case officialName = "official_name"
      case subtype
      case type
    }
  }

  struct AccountBalance: Codable {
    let available: Double?
    let current: Double
    let isoCurrencyCode: String
    let limit: Double?
    let unofficialCurrencyCode: String?

    enum CodingKeys: String, CodingKey {
      case available
      case current
      case isoCurrencyCode = "iso_currency_code"
      case limit
      case unofficialCurrencyCode = "unofficial_currency_code"
    }
  }
}
