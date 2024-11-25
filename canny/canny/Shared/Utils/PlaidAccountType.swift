//
//  PlaidAccountType.swift
//  canny
//
//  Created by Brian Vo on 11/24/24.
//

import Foundation

enum PlaidAccountType: String, Codable, Hashable {
  case depository
  case credit
  case investment
  case loan
  case brokerage
  case other
}
