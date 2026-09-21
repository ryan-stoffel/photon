import AppKit
import PhotonCore
import SwiftUI

struct AboutSettingsView: View {
  var body: some View {
    Form {
      Section {
        HStack {
          Spacer()
          VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
              .resizable()
              .frame(width: 96, height: 96)
            Text("Photon")
              .font(.title.weight(.semibold))
            Text("Version \(PhotonVersion.string)")
              .foregroundStyle(.secondary)
            Text("com.ryanstoffel.photon")
              .font(.caption.monospaced())
              .foregroundStyle(.secondary)
            Text("A small, fast macOS launcher.")
              .multilineTextAlignment(.center)
            Link("github.com/ryan-stoffel/photon", destination: Self.repositoryURL)
            Text("Copyright 2026 Ryan Stoffel. MIT License.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 12)
          Spacer()
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("About")
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  private static let repositoryURL = URL(string: "https://github.com/ryan-stoffel/photon")!
}
