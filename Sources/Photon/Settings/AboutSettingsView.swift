import AppKit
import PhotonCore
import SwiftUI

struct AboutSettingsView: View {
  var body: some View {
    PhotonSettingsPage(title: "About") {
      PhotonSettingsCard {
        HStack {
          Spacer()
          VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
              .resizable()
              .frame(width: 96, height: 96)
            Text("Photon")
              .font(.system(size: 20, weight: .semibold))
            Text("Version \(PhotonVersion.string)")
              .foregroundStyle(.secondary)
            Text("com.ryanstoffel.photon")
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
            Text("A small, fast macOS launcher.")
              .multilineTextAlignment(.center)
            Link("github.com/ryan-stoffel/photon", destination: Self.repositoryURL)
            Text("Copyright 2026 Ryan Stoffel. MIT License.")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 16)
          Spacer()
        }
      }
    }
  }

  private static let repositoryURL = URL(string: "https://github.com/ryan-stoffel/photon")!
}
