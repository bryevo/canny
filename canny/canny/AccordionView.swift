//
//  AccordionView.swift
//  canny
//
//  Created by Brian Vo on 11/24/24.
//
import SwiftUI

struct AccordionView: View {
  let title: String
  let cards: [CardView]
  @State private var isExpanded = true

  var body: some View {
    DisclosureGroup(isExpanded: $isExpanded) {
      VStack(spacing: 10) {
        ForEach(cards.indices, id: \.self) { index in
          cards[index]
        }
      }
    } label: {
      Text(title)
        .font(.headline)
        .foregroundColor(.blue)
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
    .shadow(radius: 2)
  }
}

struct CardView: View {
  let name: String
  let balance: Double
  let currencyCode: String

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(name)
        .font(.title3)
        .fontWeight(.bold)

      Text("$\(balance, specifier: "%.2f") \(currencyCode)")
        .font(.body)
        .foregroundColor(.secondary)
    }
    .padding()
    .background(Color.white)
    .cornerRadius(8)
    .shadow(radius: 2)
  }
}
