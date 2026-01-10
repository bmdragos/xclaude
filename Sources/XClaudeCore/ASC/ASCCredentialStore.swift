import Foundation

/// Manages persistent storage of App Store Connect credentials
public struct ASCCredentialStore {

  private static var credentialsFileURL: URL {
    let xclaude = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".xclaude")
    return xclaude.appendingPathComponent("asc_credentials.json")
  }

  /// Load credentials from disk
  public static func load() throws -> AppStoreConnectClient.Credentials? {
    let url = credentialsFileURL

    guard FileManager.default.fileExists(atPath: url.path) else {
      return nil
    }

    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()
    return try decoder.decode(AppStoreConnectClient.Credentials.self, from: data)
  }

  /// Save credentials to disk
  public static func save(_ credentials: AppStoreConnectClient.Credentials) throws {
    let url = credentialsFileURL

    // Create directory if needed
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(credentials)

    try data.write(to: url, options: .atomic)

    // Set restrictive permissions (owner read/write only)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }

  /// Delete stored credentials
  public static func delete() throws {
    let url = credentialsFileURL
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }

  /// Check if credentials are stored
  public static func exists() -> Bool {
    return FileManager.default.fileExists(atPath: credentialsFileURL.path)
  }
}
