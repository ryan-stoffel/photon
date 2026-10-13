import Foundation

/// `photon://note/<id>` links that open a specific note. Photon-Dev uses `photon-dev://` because it keeps
/// its own notes folder.
public enum NoteDeepLink: Sendable {
  /// The app bundle's URL scheme, "photon" outside a bundle (tests, `swift run`).
  public static let scheme: String = {
    let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
    return (types?.first?["CFBundleURLSchemes"] as? [String])?.first ?? "photon"
  }()

  public static let host = "note"

  public static func url(for id: String) -> URL? {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.path = "/" + id
    return components.url
  }

  public static func noteID(from url: URL) -> String? {
    guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host else {
      return nil
    }
    let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return id.isEmpty ? nil : id
  }
}
