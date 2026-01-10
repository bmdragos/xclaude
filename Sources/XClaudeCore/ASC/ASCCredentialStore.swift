import Foundation

/// Manages persistent storage of App Store Connect credentials with multi-profile support
public struct ASCCredentialStore {

  /// Container for all credential profiles
  public struct CredentialProfiles: Codable {
    public var profiles: [String: AppStoreConnectClient.Credentials]

    public init(profiles: [String: AppStoreConnectClient.Credentials] = [:]) {
      self.profiles = profiles
    }
  }

  /// Default profile name
  public static let defaultProfile = "default"

  private static var credentialsFileURL: URL {
    let xclaude = FileManager.default.homeDirectoryForCurrentUser
      .appendingPathComponent(".xclaude")
    return xclaude.appendingPathComponent("asc_credentials.json")
  }

  /// Load all credential profiles from disk
  public static func loadAll() throws -> CredentialProfiles {
    let url = credentialsFileURL

    guard FileManager.default.fileExists(atPath: url.path) else {
      return CredentialProfiles()
    }

    let data = try Data(contentsOf: url)
    let decoder = JSONDecoder()

    // Try new format first (profiles dictionary)
    if let profiles = try? decoder.decode(CredentialProfiles.self, from: data) {
      return profiles
    }

    // Fall back to legacy format (single credentials) and migrate
    if let legacy = try? decoder.decode(AppStoreConnectClient.Credentials.self, from: data) {
      var profiles = CredentialProfiles()
      profiles.profiles[defaultProfile] = legacy
      // Auto-migrate to new format
      try? saveAll(profiles)
      return profiles
    }

    return CredentialProfiles()
  }

  /// Load credentials for a specific profile
  public static func load(profile: String = defaultProfile) throws -> AppStoreConnectClient.Credentials? {
    let profiles = try loadAll()
    return profiles.profiles[profile]
  }

  /// Save all credential profiles to disk
  public static func saveAll(_ profiles: CredentialProfiles) throws {
    let url = credentialsFileURL

    // Create directory if needed
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(profiles)

    try data.write(to: url, options: .atomic)

    // Set restrictive permissions (owner read/write only)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
  }

  /// Save credentials for a specific profile
  public static func save(_ credentials: AppStoreConnectClient.Credentials, profile: String = defaultProfile) throws {
    var profiles = (try? loadAll()) ?? CredentialProfiles()
    profiles.profiles[profile] = credentials
    try saveAll(profiles)
  }

  /// Delete a specific profile
  public static func delete(profile: String) throws {
    var profiles = try loadAll()
    profiles.profiles.removeValue(forKey: profile)
    try saveAll(profiles)
  }

  /// Delete all stored credentials
  public static func deleteAll() throws {
    let url = credentialsFileURL
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }

  /// Check if a profile exists
  public static func exists(profile: String = defaultProfile) -> Bool {
    guard let profiles = try? loadAll() else { return false }
    return profiles.profiles[profile] != nil
  }

  /// List all profile names
  public static func listProfiles() -> [String] {
    guard let profiles = try? loadAll() else { return [] }
    return Array(profiles.profiles.keys).sorted()
  }
}
