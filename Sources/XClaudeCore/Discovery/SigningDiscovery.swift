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

      // Extract team ID from certificate's OU field (more reliable than parsing name)
      // The name's parentheses contain the user's personal ID, not the org team ID
      let teamId = await extractTeamIdFromCertificate(name: name, hash: hash)

      results.append(SigningIdentity(id: hash, name: name, teamId: teamId))
    }

    return results
  }

  /// Extract the actual team ID from a certificate's OU (Organizational Unit) field
  /// This is more reliable than parsing from the certificate name, which contains
  /// the user's personal ID rather than the organization's team ID
  private func extractTeamIdFromCertificate(name: String, hash: String) async -> String? {
    // First try to get OU from the certificate using the hash
    do {
      let certOutput = try await runCommand(
        "/usr/bin/security",
        arguments: ["find-certificate", "-c", name, "-p"]
      )

      // Parse the PEM certificate to extract OU field
      let opensslOutput = try await runCommandWithInput(
        "/usr/bin/openssl",
        arguments: ["x509", "-noout", "-subject"],
        input: certOutput
      )

      // Parse OU from subject line like: subject=...OU=5N8M3V42V6...
      // Format varies: OU = 5N8M3V42V6 or OU=5N8M3V42V6
      if let ouRange = opensslOutput.range(of: "OU\\s*=\\s*([A-Z0-9]+)", options: .regularExpression) {
        let ouMatch = String(opensslOutput[ouRange])
        // Extract just the value after "OU" and "="
        let components = ouMatch.components(separatedBy: "=")
        if components.count >= 2 {
          return components[1].trimmingCharacters(in: .whitespaces)
        }
      }
    } catch {
      // Fall back to parsing from name if certificate lookup fails
    }

    // Fallback: extract from name's parentheses (less reliable for org certs)
    if let teamStart = name.lastIndex(of: "("),
       let teamEnd = name.lastIndex(of: ")") {
      let teamRange = name.index(after: teamStart)..<teamEnd
      return String(name[teamRange])
    }

    return nil
  }

  /// Run a command with stdin input. See `runCommand` for the rationale
  /// behind the continuation + readabilityHandler pattern.
  private func runCommandWithInput(
    _ command: String,
    arguments: [String],
    input: String,
    timeoutSeconds: Int = 30
  ) async throws -> String {
    try await Self.runProcessAsync(
      command,
      arguments: arguments,
      stdinInput: input,
      mergeStderrIntoStdout: false,
      timeoutSeconds: timeoutSeconds
    )
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

    // Extract fields.
    //
    // `Name` is the profile's user-facing name (e.g. "Lode Bike Development",
    // "Lode Bike App Store") — shown in Apple Developer Portal and unique per
    // profile. `AppIDName` is the App ID's display name (e.g. "Lode Bike") and
    // is shared between every profile for the same bundle id. We need `Name`
    // to disambiguate dev-vs-distribution profiles for the same app, so it
    // becomes our primary `name`. Falls back to `AppIDName`, then the file's
    // basename, so legacy/odd profiles still parse.
    let plistName = plist["Name"] as? String
    let appIdName = plist["AppIDName"] as? String
      ?? file.deletingPathExtension().lastPathComponent
    let name = plistName ?? appIdName
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

    // Detect profile type from plist keys:
    // - ProvisionedDevices array exists → Development
    // - ProvisionsAllDevices = true → Ad Hoc or Enterprise
    // - Neither → App Store
    let profileType: ProfileType
    if plist["ProvisionedDevices"] != nil {
      profileType = .development
    } else if plist["ProvisionsAllDevices"] as? Bool == true {
      // Could be ad-hoc or enterprise, check for enterprise team
      // For now, assume ad-hoc (enterprise is rare)
      profileType = .adHoc
    } else {
      profileType = .appStore
    }

    return ProvisioningProfile(
      uuid: file.deletingPathExtension().lastPathComponent,
      name: name,
      appIdName: appIdName,
      path: file.path,
      teamId: teamIds.first ?? "",
      bundleIdPattern: bundleIdPattern,
      platforms: platforms,
      expiresAt: expirationDate,
      isWildcard: bundleIdPattern.contains("*"),
      isExpired: expirationDate < Date(),
      profileType: profileType
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

  /// Run a subprocess and return stdout. Two hazards this implementation
  /// is careful about — both inherited verbatim from the comment block on
  /// `ExtensionEmbedder.runProcess`, where they bit us first:
  ///
  /// 1. **Blocking the async executor.** `process.waitUntilExit()` is
  ///    synchronous; calling it from a Swift async context blocks the
  ///    underlying executor thread. The MCP server runs every tool call
  ///    on the same executor, so a single signing-discovery call can
  ///    wedge every concurrent `get_signing_status` / `get_config` /
  ///    `build_start` invocation until the subprocess returns. We use
  ///    `withCheckedThrowingContinuation` + `terminationHandler` so the
  ///    executor stays free.
  /// 2. **Pipe buffer deadlock.** OS pipes are ~64 KB; if we only read
  ///    stdout after `waitUntilExit`, a chatty subprocess fills the
  ///    buffer, blocks on write, and never exits — `waitUntilExit` then
  ///    blocks forever. `readabilityHandler` drains the pipe as data
  ///    arrives so the child can always make progress.
  ///
  /// Plus a hard timeout: keychain commands can stall indefinitely on a
  /// pending UI access prompt (the security agent dialog never reaches
  /// the MCP process and we'd hang silently). Defaults to 30 s, which
  /// is long enough for legitimate `security find-certificate` work on
  /// keychains with hundreds of entries but short enough to surface as
  /// an error before the user gives up and kills the MCP.
  private func runCommand(
    _ command: String,
    arguments: [String],
    captureStderr: Bool = true,
    timeoutSeconds: Int = 30
  ) async throws -> String {
    try await Self.runProcessAsync(
      command,
      arguments: arguments,
      stdinInput: nil,
      mergeStderrIntoStdout: captureStderr,
      timeoutSeconds: timeoutSeconds
    )
  }

  /// Shared async-safe subprocess driver used by `runCommand` and
  /// `runCommandWithInput`. Returns the stdout (optionally with stderr
  /// merged in) as a UTF-8 string. Throws `DiscoveryError.subprocessTimeout`
  /// if the process doesn't exit within `timeoutSeconds`.
  fileprivate static func runProcessAsync(
    _ command: String,
    arguments: [String],
    stdinInput: String?,
    mergeStderrIntoStdout: Bool,
    timeoutSeconds: Int
  ) async throws -> String {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<String, Error>) in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: command)
      process.arguments = arguments

      let stdoutPipe = Pipe()
      let stderrPipe = mergeStderrIntoStdout ? stdoutPipe : Pipe()
      let stdinPipe: Pipe? = stdinInput != nil ? Pipe() : nil

      process.standardOutput = stdoutPipe
      process.standardError = mergeStderrIntoStdout
        ? stdoutPipe
        : FileHandle.nullDevice
      if let stdinPipe { process.standardInput = stdinPipe }

      // Pipe accumulators. The readability + termination callbacks fire on
      // separate dispatch queues so the buffer needs a lock. `resumed` is
      // used to ensure we only call the continuation once — the timeout
      // path and the normal-exit path race.
      let bufferLock = NSLock()
      nonisolated(unsafe) var stdoutData = Data()
      nonisolated(unsafe) var resumed = false

      @Sendable func resumeOnce(_ result: Result<String, Error>) {
        bufferLock.lock()
        let already = resumed
        resumed = true
        bufferLock.unlock()
        guard !already else { return }
        switch result {
        case .success(let s): continuation.resume(returning: s)
        case .failure(let e): continuation.resume(throwing: e)
        }
      }

      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        bufferLock.lock()
        stdoutData.append(chunk)
        bufferLock.unlock()
      }

      process.terminationHandler = { _ in
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        let finalChunk = stdoutPipe.fileHandleForReading.availableData
        bufferLock.lock()
        if !finalChunk.isEmpty { stdoutData.append(finalChunk) }
        let str = String(data: stdoutData, encoding: .utf8) ?? ""
        bufferLock.unlock()
        resumeOnce(.success(str))
      }

      // Timeout race. If the subprocess doesn't exit in time we terminate
      // it (which triggers the termination handler — but resumeOnce will
      // ignore the late success path) and throw a typed error.
      DispatchQueue.global().asyncAfter(
        deadline: .now() + .seconds(timeoutSeconds)
      ) {
        bufferLock.lock()
        let already = resumed
        bufferLock.unlock()
        guard !already else { return }
        if process.isRunning {
          process.terminate()
        }
        resumeOnce(.failure(DiscoveryError.subprocessTimeout(
          command: command,
          seconds: timeoutSeconds
        )))
      }

      do {
        try process.run()
        // Feed stdin AFTER the process is running. `write` is synchronous
        // but the buffer is large enough for the inputs we use (PEM certs
        // ≈ 2 KB, well under 64 KB).
        if let stdinPipe, let input = stdinInput {
          if let data = input.data(using: .utf8) {
            stdinPipe.fileHandleForWriting.write(data)
          }
          stdinPipe.fileHandleForWriting.closeFile()
        }
        // Silence the unused warning for stderrPipe when separate.
        _ = stderrPipe
      } catch {
        resumeOnce(.failure(error))
      }
    }
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

enum DiscoveryError: Error, LocalizedError {
  case notSupported(String)
  case invalidProfile(String)
  case noMatchingProfile(String)
  case noMatchingIdentity(String)
  case subprocessTimeout(command: String, seconds: Int)

  var errorDescription: String? {
    switch self {
    case .notSupported(let s): return s
    case .invalidProfile(let s): return "Invalid provisioning profile: \(s)"
    case .noMatchingProfile(let s): return "No matching provisioning profile: \(s)"
    case .noMatchingIdentity(let s): return "No matching signing identity: \(s)"
    case .subprocessTimeout(let cmd, let secs):
      return "Subprocess \(cmd) did not return within \(secs)s — likely a "
        + "blocked keychain access prompt or a locked keychain. Check the "
        + "system keychain UI for a pending dialog."
    }
  }
}

extension SigningDiscovery {
  /// Returns true when the profile's type matches the requested signing mode.
  /// Distribution mode covers app-store, ad-hoc, and enterprise — all the
  /// non-development types. Used to disambiguate when multiple profiles match
  /// the same bundle id (e.g. dev + app-store profile for the same app).
  static func profileTypeMatches(
    _ type: ProfileType, mode: SigningMode
  ) -> Bool {
    switch mode {
    case .development:
      return type == .development
    case .distribution:
      return type == .appStore || type == .adHoc || type == .enterprise
    }
  }
}

// MARK: - Profile Matching

extension SigningDiscovery {
  /// Find a provisioning profile that matches the given bundle ID.
  /// Returns the best match: exact match first, then widest wildcard.
  ///
  /// When `mode` is supplied, profiles whose `profileType` matches the mode
  /// are preferred over those that don't — this is what distinguishes a
  /// development profile from a distribution profile when both exist for the
  /// same bundle id (the symptom that prompted this code: a debug build
  /// silently picking up the App Store profile and producing an installable
  /// .app that fails on-device with "Beta profile without proper entitlement").
  public func findMatchingProfile(
    bundleId: String,
    platform: String = "iOS",
    mode: SigningMode? = nil,
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

    // Mode-aware preference: a matching profileType beats anything else.
    func preferByMode(_ a: ProvisioningProfile, _ b: ProvisioningProfile) -> Bool {
      guard let mode = mode else { return false }
      let aMatches = SigningDiscovery.profileTypeMatches(a.profileType, mode: mode)
      let bMatches = SigningDiscovery.profileTypeMatches(b.profileType, mode: mode)
      return aMatches && !bMatches
    }

    // First try exact bundle-id matches, mode-preferred first.
    let exactMatches = validProfiles.filter { $0.bundleIdPattern == bundleId }
    if let exact = exactMatches.sorted(by: preferByMode).first {
      return exact
    }

    // Then try wildcard matches: longest prefix wins, ties broken by mode.
    let wildcards = validProfiles.filter { $0.isWildcard }
    let sorted = wildcards.sorted { a, b in
      let aPrefix = a.bundleIdPattern.replacingOccurrences(of: "*", with: "")
      let bPrefix = b.bundleIdPattern.replacingOccurrences(of: "*", with: "")
      if aPrefix.count != bPrefix.count {
        return aPrefix.count > bPrefix.count
      }
      return preferByMode(a, b)
    }

    for profile in sorted {
      if matchesWildcard(bundleId: bundleId, pattern: profile.bundleIdPattern) {
        return profile
      }
    }

    throw DiscoveryError.noMatchingProfile(bundleId)
  }

  /// Find a signing identity for the given team ID.
  ///
  /// When `mode == .distribution`, prefers "Apple Distribution" certs so that
  /// a release build doesn't accidentally pick up the development cert. For
  /// `.development` (or unspecified), prefers "Apple Development". Note:
  /// "Developer ID Application" is macOS-direct-distribution only and is
  /// never returned for iOS distribution.
  public func findMatchingIdentity(
    teamId: String,
    preferredName: String? = nil,
    mode: SigningMode? = nil,
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

    // Mode-aware preference.
    if mode == .distribution {
      if let dist = teamIdentities.first(where: {
        $0.name.hasPrefix("Apple Distribution") || $0.name.hasPrefix("iPhone Distribution")
      }) {
        return dist
      }
      // No Distribution cert found — fall through to Development as a last
      // resort. The build will probably fail at codesign, but a clear
      // codesign error is better than a silent miscompile.
    }

    // Prefer Apple Development certificates (for iOS device builds)
    // Note: "Developer ID Application" is for macOS distribution, NOT iOS development
    if let dev = teamIdentities.first(where: { $0.name.hasPrefix("Apple Development") }) {
      return dev
    }

    // Fall back to any development certificate (but not "Developer ID")
    if let dev = teamIdentities.first(where: {
      $0.name.contains("Development") && !$0.name.contains("Developer ID")
    }) {
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

  /// Format a "configured profile not found" error that lists every plausible
  /// candidate (matching bundle id, current platform), grouped by type, with
  /// uuids — so the user can fix `xclaude.toml` without round-tripping
  /// through `discover_signing`.
  func formatProfileNotFoundMessage(
    configured: String,
    bundleId: String,
    platform: String,
    mode: SigningMode?,
    signingData: SigningData
  ) -> String {
    let platformLower = platform.lowercased()
    let candidates = signingData.profiles.filter { profile in
      guard !profile.isExpired else { return false }
      let platformOK = profile.platforms.contains {
        $0.lowercased().contains(platformLower)
      }
      guard platformOK else { return false }
      if profile.bundleIdPattern == bundleId { return true }
      if profile.isWildcard {
        let prefix = profile.bundleIdPattern.replacingOccurrences(of: "*", with: "")
        return prefix.isEmpty || bundleId.hasPrefix(prefix)
      }
      return false
    }

    let modeStr = mode.map { " (\($0.rawValue) mode)" } ?? ""
    if candidates.isEmpty {
      return "Configured profile '\(configured)' not found, "
        + "and no \(platform) profiles match bundle id '\(bundleId)'\(modeStr). "
        + "Run `discover_signing` to see all profiles, or check that your "
        + "Apple Developer Portal has a profile for this bundle id."
    }

    let sorted = candidates.sorted { a, b in
      if a.profileType != b.profileType {
        return a.profileType.rawValue < b.profileType.rawValue
      }
      return a.name < b.name
    }
    let formatted = sorted.map { p in
      "\"\(p.name)\" [\(p.profileType.rawValue)] uuid=\(p.uuid)"
    }.joined(separator: ", ")
    return "Configured profile '\(configured)' not found "
      + "(matched neither uuid, Name, nor a path substring). "
      + "Available \(platform) profiles for '\(bundleId)'\(modeStr): \(formatted)"
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

  /// Resolve all signing components for a project.
  ///
  /// `mode` selects between `[signing.<platform>.development]` and
  /// `[signing.<platform>.distribution]` sub-tables in `xclaude.toml`. Pass
  /// `.development` for debug builds, `.distribution` for release / archive.
  /// If unset, only the platform-level `[signing.<platform>]` section (and
  /// the top-level `[signing]` defaults) are consulted.
  public func resolveSigning(
    bundleId: String,
    platform: String,
    projectDirectory: URL,
    config: XClaudeConfig? = nil,
    mode: SigningMode? = nil
  ) async throws -> ResolvedSigning {
    let signingData = try await discoverAll()

    // Get platform+mode-specific signing config (falls back to generic if not set).
    // Passing `mode` here is what makes [signing.iOS.development] vs
    // [signing.iOS.distribution] actually load — without it, only the root of
    // [signing.iOS] is consulted and the mode sub-tables are dead config.
    let platformSigning = config?.signing?.forPlatform(platform, mode: mode)

    // Find matching profile (use configured or discover).
    //
    // Configured profile is matched first by uuid, then by exact Name, then by
    // path containment — this lets users specify either "9f12442f-…" or
    // "Lode Bike Development" interchangeably. Note: post-fix, `profile.name`
    // is the actual Name field (e.g. "Lode Bike Development"), not AppIDName,
    // so name-based config now disambiguates dev vs dist correctly.
    let profile: ProvisioningProfile
    if let configuredPath = platformSigning?.profile {
      if let match = signingData.profiles.first(where: {
        $0.uuid == configuredPath
          || $0.name == configuredPath
          || $0.path.contains(configuredPath)
      }) {
        profile = match
      } else {
        throw DiscoveryError.noMatchingProfile(
          formatProfileNotFoundMessage(
            configured: configuredPath,
            bundleId: bundleId,
            platform: platform,
            mode: mode,
            signingData: signingData
          )
        )
      }
    } else {
      profile = try await findMatchingProfile(
        bundleId: bundleId,
        platform: platform,
        mode: mode,
        signingData: signingData
      )
    }

    // Find matching identity (use configured or discover)
    let identity: SigningIdentity
    if let configuredIdentity = platformSigning?.identity {
      if let match = signingData.identities.first(where: { $0.name.contains(configuredIdentity) || $0.id == configuredIdentity }) {
        identity = match
      } else {
        throw DiscoveryError.noMatchingIdentity("Configured identity not found: \(configuredIdentity)")
      }
    } else {
      identity = try await findMatchingIdentity(
        teamId: profile.teamId, mode: mode, signingData: signingData
      )
    }

    // Generate entitlements file (fresh each build from xclaude.toml capabilities)
    let entitlementsPath = try generateEntitlements(
      bundleId: bundleId,
      teamId: profile.teamId,
      projectDirectory: projectDirectory,
      platform: platform,
      config: config
    )

    return ResolvedSigning(
      identity: identity,
      profile: profile,
      teamId: profile.teamId,
      entitlementsPath: entitlementsPath.path
    )
  }

  /// Generate entitlements plist for code signing
  /// Regenerates fresh each build from xclaude.toml capabilities - no persistent state
  /// Filters out platform-incompatible entitlements automatically
  public func generateEntitlements(
    bundleId: String,
    teamId: String,
    projectDirectory: URL,
    platform: String = "iOS",
    config: XClaudeConfig? = nil
  ) throws -> URL {
    let derivedDir = projectDirectory.appendingPathComponent(".xclaude/derived")
    try FileManager.default.createDirectory(at: derivedDir, withIntermediateDirectories: true)

    let entitlementsPath = derivedDir.appendingPathComponent("Entitlements.plist")
    let isMacOS = platform.lowercased().contains("macos")

    // Start fresh - don't merge with existing file
    var entitlements: [String: Any] = [:]

    // Add required signing entitlements
    let appIdentifier = "\(teamId).\(bundleId)"
    entitlements["application-identifier"] = appIdentifier
    entitlements["com.apple.developer.team-identifier"] = teamId
    entitlements["get-task-allow"] = true  // Required for development signing
    entitlements["keychain-access-groups"] = [appIdentifier]

    // Add entitlements from capabilities in xclaude.toml using the manifest
    // registry. Each capability asks its manifest "what entitlements do you
    // need on THIS platform?" — capabilities that produce no entitlements on
    // the target platform (e.g. camera on iOS, which is Info.plist-only) are
    // skipped, which is the critical fix for the long-standing "camera breaks
    // iOS provisioning profile" bug.
    if let capabilities = config?.capabilities {
      let targetPlatform: CapabilityPlatform = isMacOS ? .macOS : .iOS
      for (capName, capValue) in capabilities {
        guard let manifest = CapabilityRegistry.manifest(for: capName) else {
          continue  // Skip unknown capabilities
        }
        // Skip capabilities not supported on this platform entirely.
        guard manifest.supports(targetPlatform) else {
          continue
        }
        // Emit whatever entitlements the manifest declares for this platform.
        // Empty = Info.plist-only on this platform (correct for iOS camera,
        // bluetooth, location, photos, contacts, calendars, audio-input).
        let resolved = manifest.resolvedEntitlements(
          for: targetPlatform,
          userValue: capValue
        )
        for (key, value) in resolved {
          entitlements[key] = value
        }
      }
    }

    // macOS-specific: ensure proper get-task-allow variant
    if isMacOS {
      // macOS uses com.apple.security.get-task-allow
      entitlements.removeValue(forKey: "get-task-allow")
      entitlements["com.apple.security.get-task-allow"] = true
    }

    // Write entitlements
    let plistData = try PropertyListSerialization.data(fromPropertyList: entitlements, format: .xml, options: 0)
    try plistData.write(to: entitlementsPath)

    return entitlementsPath
  }
}
