//
//  StringUtils.swift
//  canny
//
//  Created by Brian Vo on 11/23/24.
//

import Foundation

func jsonStringify<T: Encodable>(_ value: T) -> String? {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted // Optional: Makes the JSON more readable
    do {
        let jsonData = try encoder.encode(value)
        return String(data: jsonData, encoding: .utf8)
    } catch {
        print("Error encoding JSON: \(error)")
        return nil
    }
}
