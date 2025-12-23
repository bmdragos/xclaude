import Foundation

/// Global cache for xclaude data stored at ~/.xclaude/
public struct GlobalCache {
  public static let shared = GlobalCache()

  /// Cache directory path
  public let cacheDirectory: URL

  /// Cache file paths
  public var signingCachePath: URL { cacheDirectory.appendingPathComponent("signing.json") }
  public var simulatorsCachePath: URL { cacheDirectory.appendingPathComponent("simulators.json") }
  public var devicesCachePath: URL { cacheDirectory.appendingPathComponent("devices.json") }

  /// Cache TTL in seconds
  public let signingTTL: TimeInterval = 300  // 5 minutes
  public let simulatorsTTL: TimeInterval = 60  // 1 minute
  public let devicesTTL: TimeInterval = 30  // 30 seconds (devices change frequently)

  public init() {
    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
    self.cacheDirectory = homeDirectory.appendingPathComponent(".xclaude")
  }

  /// Ensure cache directory exists
  public func ensureCacheDirectory() throws {
    if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
      try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
  }

  // MARK: - Signing Cache

  /// Get cached signing data if still valid
  public func getCachedSigning() -> CachedData<SigningData>? {
    return getCached(from: signingCachePath, ttl: signingTTL)
  }

  /// Cache signing data
  public func cacheSigning(_ data: SigningData) throws {
    try cache(data, to: signingCachePath)
  }

  // MARK: - Simulators Cache

  /// Get cached simulators if still valid
  public func getCachedSimulators() -> CachedData<SimulatorsData>? {
    return getCached(from: simulatorsCachePath, ttl: simulatorsTTL)
  }

  /// Cache simulators data
  public func cacheSimulators(_ data: SimulatorsData) throws {
    try cache(data, to: simulatorsCachePath)
  }

  // MARK: - Devices Cache

  /// Get cached devices if still valid
  public func getCachedDevices() -> CachedData<DevicesData>? {
    return getCached(from: devicesCachePath, ttl: devicesTTL)
  }

  /// Cache devices data
  public func cacheDevices(_ data: DevicesData) throws {
    try cache(data, to: devicesCachePath)
  }

  // MARK: - Generic Cache Operations

  private func getCached<T: Codable>(from path: URL, ttl: TimeInterval) -> CachedData<T>? {
    guard FileManager.default.fileExists(atPath: path.path),
          let data = try? Data(contentsOf: path),
          let cached = try? JSONDecoder().decode(CachedData<T>.self, from: data) else {
      return nil
    }

    // Check if cache is still valid
    let age = Date().timeIntervalSince(cached.timestamp)
    guard age < ttl else {
      return nil
    }

    return cached
  }

  private func cache<T: Codable>(_ value: T, to path: URL) throws {
    try ensureCacheDirectory()
    let cached = CachedData(data: value, timestamp: Date())
    let data = try JSONEncoder().encode(cached)
    try data.write(to: path)
  }

  /// Clear all cached data
  public func clearCache() throws {
    let files = [signingCachePath, simulatorsCachePath, devicesCachePath]
    for file in files {
      if FileManager.default.fileExists(atPath: file.path) {
        try FileManager.default.removeItem(at: file)
      }
    }
  }
}

// MARK: - Cache Data Types

/// Wrapper for cached data with timestamp
public struct CachedData<T: Codable>: Codable {
  public let data: T
  public let timestamp: Date

  public init(data: T, timestamp: Date) {
    self.data = data
    self.timestamp = timestamp
  }
}

/// Cached signing data
public struct SigningData: Codable {
  public let identities: [SigningIdentity]
  public let profiles: [ProvisioningProfile]
  public let defaultTeamId: String?

  public init(identities: [SigningIdentity], profiles: [ProvisioningProfile], defaultTeamId: String?) {
    self.identities = identities
    self.profiles = profiles
    self.defaultTeamId = defaultTeamId
  }
}

/// Signing identity
public struct SigningIdentity: Codable {
  public let id: String
  public let name: String
  public let teamId: String?

  public init(id: String, name: String, teamId: String?) {
    self.id = id
    self.name = name
    self.teamId = teamId
  }
}

/// Provisioning profile
public struct ProvisioningProfile: Codable {
  public let uuid: String
  public let name: String
  public let path: String
  public let teamId: String
  public let bundleIdPattern: String
  public let platforms: [String]
  public let expiresAt: Date
  public let isWildcard: Bool
  public let isExpired: Bool

  public init(
    uuid: String, name: String, path: String, teamId: String,
    bundleIdPattern: String, platforms: [String], expiresAt: Date,
    isWildcard: Bool, isExpired: Bool
  ) {
    self.uuid = uuid
    self.name = name
    self.path = path
    self.teamId = teamId
    self.bundleIdPattern = bundleIdPattern
    self.platforms = platforms
    self.expiresAt = expiresAt
    self.isWildcard = isWildcard
    self.isExpired = isExpired
  }
}

/// Cached simulators data
public struct SimulatorsData: Codable {
  public let devices: [String: [Simulator]]

  public init(devices: [String: [Simulator]]) {
    self.devices = devices
  }
}

/// Simulator info
public struct Simulator: Codable {
  public let name: String
  public let udid: String
  public let state: String
  public let isAvailable: Bool
  public let runtime: String?

  public init(name: String, udid: String, state: String, isAvailable: Bool, runtime: String?) {
    self.name = name
    self.udid = udid
    self.state = state
    self.isAvailable = isAvailable
    self.runtime = runtime
  }
}

/// Cached devices data
public struct DevicesData: Codable {
  public let devices: [Device]

  public init(devices: [Device]) {
    self.devices = devices
  }
}

/// Physical device info
public struct Device: Codable {
  public let name: String
  public let udid: String
  public let platform: String
  public let osVersion: String?
  public let connectionType: String?

  public init(name: String, udid: String, platform: String, osVersion: String?, connectionType: String?) {
    self.name = name
    self.udid = udid
    self.platform = platform
    self.osVersion = osVersion
    self.connectionType = connectionType
  }
}
