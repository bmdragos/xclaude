import Foundation

/// Signing discovery - scans keychain and provisioning profiles
public struct SigningDiscovery {
  private let cache = GlobalCache.shared

  public init() {}

  /// Discover all signing identities and provisioning profiles
  /// Uses cache if available and not expired
  public func discoverAll(forceRefresh: Bool = false) async throws -> SigningData {
    // Check cache first
    if !forceRefresh, let cached = cache.getCachedSigning() {
      return cached.data
    }

    // Discover fresh data
    let identities = try await discoverIdentities()
    let profiles = try await discoverProfiles()
    let defaultTeamId = identities.first?.teamId

    let data = SigningData(
      identities: identities,
      profiles: profiles,
      defaultTeamId: defaultTeamId
    )

    // Cache the result
    try? cache.cacheSigning(data)

    return data
  }

  /// Discover signing identities from keychain
  public func discoverIdentities() async throws -> [SigningIdentity] {
    let output = try await runCommand(
      "/usr/bin/security",
      arguments: ["find-identity", "-v", "-p", "codesigning"]
    )

    var results: [SigningIdentity] = []

    // Parse output lines like:
    //   1) ABC123... "Apple Development: name@email.com (TEAMID)"
    let lines = output.split(separator: "\n")
    for line in lines {
      let lineStr = String(line).trimmingCharacters(in: .whitespaces)

      // Skip lines that don't start with a number
      guard let firstChar = lineStr.first, firstChar.isNumber else {
        continue
      }

      // Extract the hash (40 hex chars after the "N) " prefix)
      guard let parenIndex = lineStr.firstIndex(of: ")"),
            let quoteIndex = lineStr.firstIndex(of: "\"") else {
        continue
      }

      let afterParen = lineStr.index(after: parenIndex)
      guard afterParen < quoteIndex else { continue }

      let hashRange = afterParen..<quoteIndex
      let hash = lineStr[hashRange].trimmingCharacters(in: .whitespaces)

      // Extract the name (in quotes)
      guard let nameStart = lineStr.firstIndex(of: "\""),
            let nameEnd = lineStr.lastIndex(of: "\""),
            nameStart != nameEnd else {
        continue
      }

      let nameRange = lineStr.index(after: nameStart)..<nameEnd
      let name = String(lineStr[nameRange])

      // Extract team ID from name (usually in parentheses at end)
      var teamId: String? = nil
      if let teamStart = name.lastIndex(of: "("),
         let teamEnd = name.lastIndex(of: ")") {
        let teamRange = name.index(after: teamStart)..<teamEnd
        teamId = String(name[teamRange])
      }

      results.append(SigningIdentity(id: hash, name: name, teamId: teamId))
    }

    return results
  }

  /// Discover provisioning profiles
  public func discoverProfiles() async throws -> [ProvisioningProfile] {
    let profilesDirectory = try getProfilesDirectory()

    guard FileManager.default.fileExists(atPath: profilesDirectory.path) else {
      return []
    }

    let contents = try FileManager.default.contentsOfDirectory(
      at: profilesDirectory,
      includingPropertiesForKeys: nil
    )

    var results: [ProvisioningProfile] = []

    for file in contents where file.pathExtension == "mobileprovision" {
      do {
        let profile = try await parseProvisioningProfile(at: file)
        results.append(profile)
      } catch {
        // Skip profiles that fail to parse
        continue
      }
    }

    return results
  }

  /// Parse a provisioning profile
  private func parseProvisioningProfile(at file: URL) async throws -> ProvisioningProfile {
    // Use openssl to extract the plist from the signed profile
    let plistContent = try await runCommand(
      "/usr/bin/openssl",
      arguments: ["smime", "-verify", "-in", file.path, "-noverify", "-inform", "der"],
      captureStderr: false
    )

    guard let plistData = plistContent.data(using: .utf8) else {
      throw DiscoveryError.invalidProfile(file.path)
    }

    guard let plist = try PropertyListSerialization.propertyList(
      from: plistData,
      options: [],
      format: nil
    ) as? [String: Any] else {
      throw DiscoveryError.invalidProfile(file.path)
    }

    // Extract fields
    let name = plist["AppIDName"] as? String ?? file.deletingPathExtension().lastPathComponent
    let teamIds = plist["TeamIdentifier"] as? [String] ?? []
    let expirationDate = plist["ExpirationDate"] as? Date ?? Date()
    let platforms = plist["Platform"] as? [String] ?? []

    // Get bundle ID from entitlements
    var bundleIdPattern = "*"
    if let entitlements = plist["Entitlements"] as? [String: Any],
       let appId = entitlements["application-identifier"] as? String {
      // Remove team ID prefix
      let parts = appId.split(separator: ".")
      bundleIdPattern = parts.dropFirst().joined(separator: ".")
    }

    return ProvisioningProfile(
      uuid: file.deletingPathExtension().lastPathComponent,
      name: name,
      path: file.path,
      teamId: teamIds.first ?? "",
      bundleIdPattern: bundleIdPattern,
      platforms: platforms,
      expiresAt: expirationDate,
      isWildcard: bundleIdPattern.contains("*"),
      isExpired: expirationDate < Date()
    )
  }

  /// Get current signing status (summary for quick checks)
  public func getStatus() async throws -> SigningStatus {
    let data = try await discoverAll()

    var issues: [String] = []

    if data.identities.isEmpty {
      issues.append("No signing identities found in keychain")
    }

    let validProfiles = data.profiles.filter { !$0.isExpired }
    if validProfiles.isEmpty {
      issues.append("No valid provisioning profiles found")
    }

    return SigningStatus(
      configured: data.defaultTeamId != nil && !validProfiles.isEmpty,
      teamId: data.defaultTeamId,
      identityCount: data.identities.count,
      profileCount: validProfiles.count,
      issues: issues
    )
  }

  // MARK: - Private

  private func getProfilesDirectory() throws -> URL {
    let libraryDirectory = try FileManager.default.url(
      for: .libraryDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
    return libraryDirectory
      .appendingPathComponent("Developer")
      .appendingPathComponent("Xcode")
      .appendingPathComponent("UserData")
      .appendingPathComponent("Provisioning Profiles")
  }

  private func runCommand(
    _ command: String,
    arguments: [String],
    captureStderr: Bool = true
  ) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
    process.arguments = arguments

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = captureStderr ? stdoutPipe : stderrPipe

    try process.run()
    process.waitUntilExit()

    let data = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }
}

/// Signing status summary
public struct SigningStatus: Codable {
  public let configured: Bool
  public let teamId: String?
  public let identityCount: Int
  public let profileCount: Int
  public let issues: [String]

  public init(configured: Bool, teamId: String?, identityCount: Int, profileCount: Int, issues: [String]) {
    self.configured = configured
    self.teamId = teamId
    self.identityCount = identityCount
    self.profileCount = profileCount
    self.issues = issues
  }
}

enum DiscoveryError: Error {
  case notSupported(String)
  case invalidProfile(String)
  case noMatchingProfile(String)
  case noMatchingIdentity(String)
}

// MARK: - Profile Matching

extension SigningDiscovery {
  /// Find a provisioning profile that matches the given bundle ID
  /// Returns the best match: exact match first, then wildcard
  public func findMatchingProfile(
    bundleId: String,
    platform: String = "iOS",
    signingData: SigningData? = nil
  ) async throws -> ProvisioningProfile {
    let data: SigningData
    if let provided = signingData {
      data = provided
    } else {
      data = try await discoverAll()
    }

    // Filter valid (non-expired) profiles for the platform
    let validProfiles = data.profiles.filter { profile in
      !profile.isExpired && profile.platforms.contains(where: { $0.lowercased().contains(platform.lowercased()) })
    }

    // First try exact match
    if let exact = validProfiles.first(where: { $0.bundleIdPattern == bundleId }) {
      return exact
    }

    // Then try wildcard matches
    let wildcards = validProfiles.filter { $0.isWildcard }

    // Sort wildcards by specificity (more prefix = better match)
    let sorted = wildcards.sorted { a, b in
      let aPrefix = a.bundleIdPattern.replacingOccurrences(of: "*", with: "")
      let bPrefix = b.bundleIdPattern.replacingOccurrences(of: "*", with: "")
      return aPrefix.count > bPrefix.count
    }

    for profile in sorted {
      if matchesWildcard(bundleId: bundleId, pattern: profile.bundleIdPattern) {
        return profile
      }
    }

    throw DiscoveryError.noMatchingProfile(bundleId)
  }

  /// Find a signing identity for the given team ID
  public func findMatchingIdentity(
    teamId: String,
    preferredName: String? = nil,
    signingData: SigningData? = nil
  ) async throws -> SigningIdentity {
    let data: SigningData
    if let provided = signingData {
      data = provided
    } else {
      data = try await discoverAll()
    }

    // Filter identities by team ID
    let teamIdentities = data.identities.filter { $0.teamId == teamId }

    guard !teamIdentities.isEmpty else {
      throw DiscoveryError.noMatchingIdentity(teamId)
    }

    // If preferred name specified, try to match
    if let preferred = preferredName,
       let match = teamIdentities.first(where: { $0.name.contains(preferred) }) {
      return match
    }

    // Prefer development certificates over distribution
    if let dev = teamIdentities.first(where: { $0.name.contains("Development") }) {
      return dev
    }

    return teamIdentities[0]
  }

  /// Check if bundle ID matches a wildcard pattern
  private func matchesWildcard(bundleId: String, pattern: String) -> Bool {
    // Pattern like "com.company.*" or just "*"
    if pattern == "*" {
      return true
    }

    let prefix = pattern.replacingOccurrences(of: "*", with: "")
    return bundleId.hasPrefix(prefix)
  }
}

// MARK: - Entitlements Generation

extension SigningDiscovery {
  /// Resolved signing info ready for code signing
  public struct ResolvedSigning: Codable {
    public let identity: SigningIdentity
    public let profile: ProvisioningProfile
    public let teamId: String
    public let entitlementsPath: String

    public init(identity: SigningIdentity, profile: ProvisioningProfile, teamId: String, entitlementsPath: String) {
      self.identity = identity
      self.profile = profile
      self.teamId = teamId
      self.entitlementsPath = entitlementsPath
    }
  }

  /// Resolve all signing components for a project
  public func resolveSigning(
    bundleId: String,
    platform: String,
    projectDirectory: URL,
    config: XClaudeConfig? = nil
  ) async throws -> ResolvedSigning {
    let signingData = try await discoverAll()

    // Find matching profile (use configured or discover)
    let profile: ProvisioningProfile
    if let configuredPath = config?.signing?.profile {
      // Use configured profile path
      if let match = signingData.profiles.first(where: { $0.path.contains(configuredPath) || $0.name == configuredPath }) {
        profile = match
      } else {
        throw DiscoveryError.noMatchingProfile("Configured profile not found: \(configuredPath)")
      }
    } else {
      profile = try await findMatchingProfile(bundleId: bundleId, platform: platform, signingData: signingData)
    }

    // Find matching identity (use configured or discover)
    let identity: SigningIdentity
    if let configuredIdentity = config?.signing?.identity {
      if let match = signingData.identities.first(where: { $0.name.contains(configuredIdentity) || $0.id == configuredIdentity }) {
        identity = match
      } else {
        throw DiscoveryError.noMatchingIdentity("Configured identity not found: \(configuredIdentity)")
      }
    } else {
      identity = try await findMatchingIdentity(teamId: profile.teamId, signingData: signingData)
    }

    // Generate entitlements file
    let entitlementsPath = try generateEntitlements(
      bundleId: bundleId,
      teamId: profile.teamId,
      projectDirectory: projectDirectory
    )

    return ResolvedSigning(
      identity: identity,
      profile: profile,
      teamId: profile.teamId,
      entitlementsPath: entitlementsPath.path
    )
  }

  /// Generate entitlements plist for code signing
  /// Merges required signing entitlements with any capability entitlements
  public func generateEntitlements(
    bundleId: String,
    teamId: String,
    projectDirectory: URL
  ) throws -> URL {
    let derivedDir = projectDirectory.appendingPathComponent(".xclaude/derived")
    try FileManager.default.createDirectory(at: derivedDir, withIntermediateDirectories: true)

    let entitlementsPath = derivedDir.appendingPathComponent("Entitlements.plist")

    // Start with any existing capability entitlements
    var entitlements: [String: Any] = [:]
    if FileManager.default.fileExists(atPath: entitlementsPath.path),
       let data = try? Data(contentsOf: entitlementsPath),
       let existing = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] {
      entitlements = existing
    }

    // Add required signing entitlements
    let appIdentifier = "\(teamId).\(bundleId)"
    entitlements["application-identifier"] = appIdentifier
    entitlements["com.apple.developer.team-identifier"] = teamId
    entitlements["get-task-allow"] = true  // Required for development signing
    entitlements["keychain-access-groups"] = [appIdentifier]

    // Write entitlements
    let plistData = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
    try plistData.write(to: entitlementsPath)

    return entitlementsPath
  }
}
