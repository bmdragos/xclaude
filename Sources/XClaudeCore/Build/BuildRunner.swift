import Foundation

/// Runs swift-bundler builds and parses results
public struct BuildRunner {

  /// Build result
  public struct BuildResult: Codable {
    public let success: Bool
    public let appPath: String?
    public let platform: String
    public let configuration: String
    public let duration: Double
    public let warnings: [String]
    public let errors: [BuildError]
    public let signing: SigningInfo?

    public init(success: Bool, appPath: String?, platform: String, configuration: String,
                duration: Double, warnings: [String], errors: [BuildError], signing: SigningInfo? = nil) {
      self.success = success
      self.appPath = appPath
      self.platform = platform
      self.configuration = configuration
      self.duration = duration
      self.warnings = warnings
      self.errors = errors
      self.signing = signing
    }
  }

  /// Info about signing used for the build
  public struct SigningInfo: Codable {
    public let identity: String
    public let profile: String
    public let teamId: String

    public init(identity: String, profile: String, teamId: String) {
      self.identity = identity
      self.profile = profile
      self.teamId = teamId
    }
  }

  /// Structured build error
  public struct BuildError: Codable {
    public let code: String
    public let message: String
    public let file: String?
    public let line: Int?
    public let suggestion: String?
    public let fixable: Bool

    public init(code: String, message: String, file: String? = nil, line: Int? = nil,
                suggestion: String? = nil, fixable: Bool = false) {
      self.code = code
      self.message = message
      self.file = file
      self.line = line
      self.suggestion = suggestion
      self.fixable = fixable
    }
  }

  /// Platform mapping for swift-bundler
  public enum Platform: String, CaseIterable {
    case iOS
    case iOSSimulator
    case macOS
    case tvOS
    case tvOSSimulator
    case visionOS
    case visionOSSimulator

    /// Whether this platform requires code signing
    public var requiresSigning: Bool {
      switch self {
      case .iOS, .tvOS, .visionOS:
        return true
      case .iOSSimulator, .tvOSSimulator, .visionOSSimulator, .macOS:
        return false
      }
    }

    /// Platform name for profile matching (matches provisioning profile platform field)
    public var platformName: String {
      switch self {
      case .iOS, .iOSSimulator:
        return "iOS"
      case .macOS:
        return "macOS"
      case .tvOS, .tvOSSimulator:
        return "tvOS"
      case .visionOS, .visionOSSimulator:
        return "xrOS"  // visionOS uses xrOS in profiles
      }
    }
  }

  /// Build configuration
  public enum Configuration: String {
    case debug
    case release
  }

  /// Build an app using swift-bundler
  public static func build(
    projectDirectory: URL,
    platform: Platform = .iOSSimulator,
    configuration: Configuration = .debug,
    swiftBundlerPath: String? = nil
  ) async throws -> BuildResult {
    let startTime = Date()

    // Detect project type and setup config
    let projectType = ConfigTranslator.detectProjectType(at: projectDirectory)

    // Track if we need to clean up generated Bundler.toml
    var needsCleanup = false
    let bundlerTomlPath = projectDirectory.appendingPathComponent("Bundler.toml")
    let backupPath = projectDirectory.appendingPathComponent("Bundler.toml.xclaude-backup")

    // Ensure cleanup happens even if we throw
    defer {
      if needsCleanup {
        try? FileManager.default.removeItem(at: bundlerTomlPath)
        if FileManager.default.fileExists(atPath: backupPath.path) {
          try? FileManager.default.moveItem(at: backupPath, to: bundlerTomlPath)
        }
      }
    }

    switch projectType {
    case .xclaude:
      // Load and translate config - generate Bundler.toml directly in project root
      let config = try XClaudeConfig.load(from: projectDirectory)

      // Backup existing Bundler.toml if present
      if FileManager.default.fileExists(atPath: bundlerTomlPath.path) {
        try? FileManager.default.removeItem(at: backupPath)
        try? FileManager.default.moveItem(at: bundlerTomlPath, to: backupPath)
      }

      // Generate Bundler.toml in project root
      let configPath = try ConfigTranslator.translate(config: config, projectDirectory: projectDirectory)
      try? FileManager.default.removeItem(at: bundlerTomlPath)
      try FileManager.default.copyItem(at: configPath, to: bundlerTomlPath)
      needsCleanup = true

    case .swiftBundler:
      // Use existing Bundler.toml directly
      break

    case .swiftPackage:
      // No config - swift-bundler might work with defaults or fail
      break

    case .unknown:
      return BuildResult(
        success: false,
        appPath: nil,
        platform: platform.rawValue,
        configuration: configuration.rawValue,
        duration: 0,
        warnings: [],
        errors: [BuildError(
          code: "NO_PROJECT",
          message: "No Swift project found at \(projectDirectory.path)",
          suggestion: "Create a Package.swift or xclaude.toml file",
          fixable: false
        )]
      )
    }

    // Resolve signing if required
    var resolvedSigning: SigningDiscovery.ResolvedSigning? = nil
    if platform.requiresSigning {
      let config = try? XClaudeConfig.load(from: projectDirectory)
      let bundleId = config?.app.bundleId ?? "com.example.app"

      let discovery = SigningDiscovery()
      do {
        resolvedSigning = try await discovery.resolveSigning(
          bundleId: bundleId,
          platform: platform.platformName,
          projectDirectory: projectDirectory,
          config: config
        )
      } catch {
        return BuildResult(
          success: false,
          appPath: nil,
          platform: platform.rawValue,
          configuration: configuration.rawValue,
          duration: Date().timeIntervalSince(startTime),
          warnings: [],
          errors: [BuildError(
            code: "SIGNING_REQUIRED",
            message: "Device builds require code signing: \(error.localizedDescription)",
            suggestion: "Run discover_signing to find available identities and profiles",
            fixable: true
          )]
        )
      }
    }

    // Find swift-bundler executable
    let bundlerPath = swiftBundlerPath ?? findSwiftBundler()

    guard let bundlerPath = bundlerPath else {
      return BuildResult(
        success: false,
        appPath: nil,
        platform: platform.rawValue,
        configuration: configuration.rawValue,
        duration: Date().timeIntervalSince(startTime),
        warnings: [],
        errors: [BuildError(
          code: "BUNDLER_NOT_FOUND",
          message: "swift-bundler executable not found",
          suggestion: "Build swift-bundler with: swift build --product swift-bundler",
          fixable: false
        )]
      )
    }

    // Build arguments
    var arguments = ["bundle", "-p", platform.rawValue, "-c", configuration.rawValue]
    arguments.append("--directory")
    arguments.append(projectDirectory.path)

    // Add signing arguments if resolved
    if let signing = resolvedSigning {
      arguments.append("--identity")
      arguments.append(signing.identity.name)
      arguments.append("--provisioning-profile")
      arguments.append(signing.profile.path)
      arguments.append("--entitlements")
      arguments.append(signing.entitlementsPath)
    } else if platform == .macOS {
      // For macOS, sign with entitlements if they exist (for capabilities like apple-events)
      let entitlementsPath = ConfigTranslator.derivedDirectory(for: projectDirectory)
        .appendingPathComponent("Entitlements.plist")
      if FileManager.default.fileExists(atPath: entitlementsPath.path) {
        // macOS requires codesigning to embed entitlements
        // Use identity from config, or default to "Apple Development"
        let config = try? XClaudeConfig.load(from: projectDirectory)
        let identity = config?.signing?.identity ?? "Apple Development"

        arguments.append("--codesign")
        arguments.append("--identity")
        arguments.append(identity)
        arguments.append("--entitlements")
        arguments.append(entitlementsPath.path)
      }
    }

    // Run swift-bundler
    let (exitCode, stdout, stderr) = try await runProcess(
      bundlerPath,
      arguments: arguments,
      currentDirectory: projectDirectory
    )

    // Note: Cleanup is handled by defer block at top of function

    let duration = Date().timeIntervalSince(startTime)

    // Parse output
    let (warnings, errors) = parseOutput(stdout: stdout, stderr: stderr)

    // Find built app path
    var appPath: String? = nil
    if exitCode == 0 {
      appPath = findBuiltApp(in: projectDirectory, appName: detectAppName(from: projectDirectory))
    }

    // Build signing info for result
    var signingInfo: SigningInfo? = nil
    if let signing = resolvedSigning {
      signingInfo = SigningInfo(
        identity: signing.identity.name,
        profile: signing.profile.name,
        teamId: signing.teamId
      )
    }

    return BuildResult(
      success: exitCode == 0,
      appPath: appPath,
      platform: platform.rawValue,
      configuration: configuration.rawValue,
      duration: duration,
      warnings: warnings,
      errors: errors,
      signing: signingInfo
    )
  }

  // MARK: - Private Helpers

  private static func findSwiftBundler() -> String? {
    // First check next to xclaude executable (same build directory)
    if let execPath = Bundle.main.executablePath {
      let execDir = URL(fileURLWithPath: execPath).deletingLastPathComponent()
      let siblingPath = execDir.appendingPathComponent("swift-bundler").path
      if FileManager.default.isExecutableFile(atPath: siblingPath) {
        return siblingPath
      }
    }

    // Check common locations
    let candidates = [
      ".build/debug/swift-bundler",
      ".build/release/swift-bundler",
      "/usr/local/bin/swift-bundler",
      "~/.local/bin/swift-bundler"
    ]

    for candidate in candidates {
      let path = NSString(string: candidate).expandingTildeInPath
      if FileManager.default.isExecutableFile(atPath: path) {
        return path
      }
    }

    // Try which command
    if let result = try? runProcessSync("/usr/bin/which", arguments: ["swift-bundler"]),
       !result.isEmpty {
      return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    return nil
  }

  private static func findBuiltApp(in projectDirectory: URL, appName: String?) -> String? {
    let buildDir = projectDirectory.appendingPathComponent(".build/bundler")

    guard FileManager.default.fileExists(atPath: buildDir.path) else {
      return nil
    }

    // Look for .app bundle
    if let contents = try? FileManager.default.contentsOfDirectory(at: buildDir, includingPropertiesForKeys: nil) {
      for item in contents {
        if item.pathExtension == "app" {
          return item.path
        }
      }
    }

    return nil
  }

  private static func detectAppName(from projectDirectory: URL) -> String? {
    // Try xclaude.toml first
    if let config = try? XClaudeConfig.load(from: projectDirectory) {
      return config.app.name
    }
    return nil
  }

  private static func parseOutput(stdout: String, stderr: String) -> (warnings: [String], errors: [BuildError]) {
    var warnings: [String] = []
    var errors: [BuildError] = []

    let allOutput = stdout + "\n" + stderr

    for line in allOutput.split(separator: "\n") {
      let lineStr = String(line)

      // Swift compiler warnings
      if lineStr.contains("warning:") {
        warnings.append(lineStr)
      }

      // Swift compiler errors
      if lineStr.contains("error:") {
        // Parse file:line:col: error: message format
        let parts = lineStr.split(separator: ":", maxSplits: 4)
        if parts.count >= 4 {
          let file = String(parts[0])
          let line = Int(parts[1])
          let message = parts.dropFirst(3).joined(separator: ":").trimmingCharacters(in: .whitespaces)

          errors.append(BuildError(
            code: "COMPILER_ERROR",
            message: message,
            file: file,
            line: line,
            fixable: false
          ))
        } else {
          errors.append(BuildError(
            code: "BUILD_ERROR",
            message: lineStr,
            fixable: false
          ))
        }
      }
    }

    return (warnings, errors)
  }

  private static func runProcess(
    _ executable: String,
    arguments: [String],
    currentDirectory: URL
  ) async throws -> (exitCode: Int32, stdout: String, stderr: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    process.currentDirectoryURL = currentDirectory

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    try process.run()
    process.waitUntilExit()

    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

    return (
      process.terminationStatus,
      String(data: stdoutData, encoding: .utf8) ?? "",
      String(data: stderrData, encoding: .utf8) ?? ""
    )
  }

  private static func runProcessSync(_ executable: String, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
  }
}
