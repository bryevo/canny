//
//  PlaidContentView.swift
//  canny
//
//  Created by Brian Vo on 10/19/24.
//
import LinkKit
import SwiftUI

struct PlaidContentView: View {
  @EnvironmentObject var authViewModel: AuthManager
  @State private var isPresentingLink = false
  @StateObject private var linkManager = PlaidLinkManager()

  var body: some View {
    ZStack(alignment: .leading) {
      backgroundColor.ignoresSafeArea()

      VStack(alignment: .leading, spacing: 12) {
        Text("WELCOME")
          .foregroundColor(plaidBlue)
          .font(.system(size: 12, weight: .bold))

        Text("Plaid Link SDK\nSwiftUI Example")
          .font(.system(size: 32, weight: .light))

        versionInformation()

        Spacer()

        VStack(alignment: .center) {
          Button(action: {
            isPresentingLink = true
          }, label: {
            Text("Open Plaid Link")
              .font(.system(size: 17, weight: .medium))
              .frame(width: 312)
          })
          .padding()
          .foregroundColor(.white)
          .background(plaidBlue)
          .cornerRadius(4)
        }
        .frame(height: 56)
      }
      .padding(EdgeInsets(top: 16, leading: 32, bottom: 0, trailing: 32))
    }
    .fullScreenCover(
      isPresented: $isPresentingLink,
      onDismiss: { isPresentingLink = false },
      content: {
        if let linkController = linkManager.linkController {
          linkController.ignoresSafeArea(.all)
        } else {
          Text("Error: LinkController not initialized")
        }
      }
    )
  }

  private let backgroundColor: Color = .init(
    red: 247 / 256,
    green: 249 / 256,
    blue: 251 / 256,
    opacity: 1
  )

  private let plaidBlue: Color = .init(
    red: 0,
    green: 191 / 256,
    blue: 250 / 256,
    opacity: 1
  )

  private func versionInformation() -> some View {
    let linkKitBundle = Bundle(for: PLKPlaid.self)
    let linkKitVersion = linkKitBundle.object(
      forInfoDictionaryKey: "CFBundleShortVersionString"
    )!
    let linkKitBuild = linkKitBundle.object(
      forInfoDictionaryKey: kCFBundleVersionKey as String
    )!
    let linkKitName = linkKitBundle.object(
      forInfoDictionaryKey: kCFBundleNameKey as String
    )!
    let versionText = "\(linkKitName) \(linkKitVersion)+\(linkKitBuild)"

    return Text(versionText)
      .foregroundColor(.gray)
      .font(.system(size: 12))
  }
}

struct LinkView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
