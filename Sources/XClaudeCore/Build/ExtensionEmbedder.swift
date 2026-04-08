import Foundation

/// Post-build step that embeds app extensions into a bundled `.app`.
///
/// The goal of this type is to let xclaude produce a fully-signed iOS/macOS
/// app with embedded `.appex` bundles without modifying the SwiftBundler fork.
/// The flow is:
///
/// 1. `swift-bundler` builds and bundles the parent `.app` normally. It
///    knows nothing about extensions.
/// 2. After `swift-bundler` finishes, `BuildRunner` calls
///    `ExtensionEmbedder.embedExtensions(...)` which:
///    - reads declared extensions from `xclaude.toml`'s `[extensions]` section,
///    - regenerates per-extension derived files (`Info.plist`,
///      `Entitlements.plist`) via `ConfigTranslator`,
///    - builds each extension target via `xcodebuild -scheme <name>` (reusing
///      the same derived data path as the main build so the binaries live
///      alongside the parent),
///    - wraps each extension binary in a `.appex` bundle inside the parent
///      app's `PlugIns/` directory,
///    - signs each `.appex` ad-hoc (simulator builds — device signing is a
///      follow-up),
///    - re-signs the parent `.app` with `--deep` so the nested bundles are
///      covered by the outer signature.
///
/// Bypassing SwiftBundler for extension embedding keeps the fork minimal and
/// makes upstream syncing easier.
public enum ExtensionEmbedder {

  // MARK: - Errors

  public struct EmbedError: Error, CustomStringConvertible {
    public let message: String
    public var description: String { message }
    public init(_ message: String) { self.message = message }
  }

  // MARK: - Entry point

  /// Embed every extension declared in `xclaude.toml` into a freshly-bundled
  /// `.app`. Safe to call on projects with no extensions — it'll return
  /// immediately.
  ///
  /// - Parameters:
  ///   - appPath: Path to the parent `.app` bundle produced by swift-bundler.
  ///   - projectDirectory: Project root (where `xclaude.toml` lives).
  ///   - platform: Target platform — determines where `PlugIns/` lives and
  ///               how `xcodebuild` is invoked.
  ///   - configuration: Debug or release.
  public static func embedExtensions(
    appPath: String,
    projectDirectory: URL,
    platform: BuildRunner.Platform,
    configuration: BuildRunner.Configuration
  ) async throws {
    // Fast path: no extensions declared.
    guard let config = try? XClaudeConfig.load(from: projectDirectory),
          let extensions = config.extensions,
          !extensions.isEmpty else {
      return
    }

    // Regenerate per-extension derived files so we always sign against
    // fresh plist/entitlements content, even if xclaude.toml changed since
    // the last build.
    try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: projectDirectory
    )

    let appURL = URL(fileURLWithPath: appPath)
    let plugInsURL = plugInsDirectory(for: appURL, platform: platform)
    try FileManager.default.createDirectory(
      at: plugInsURL,
      withIntermediateDirectories: true
    )

    // Build each extension and stage it into PlugIns/.
    for (extName, extConfig) in extensions.sorted(by: { $0.key < $1.key }) {
      guard ExtensionType(rawValue: extConfig.type) != nil else {
        throw EmbedError(
          "Unknown extension type '\(extConfig.type)' for '\(extName)'"
        )
      }

      // 1. Build the extension target.
      let extBinary = try await buildExtensionTarget(
        extensionName: extName,
        projectDirectory: projectDirectory,
        platform: platform,
        configuration: configuration
      )

      // 2. Assemble the `.appex` bundle.
      let appexURL = plugInsURL.appendingPathComponent("\(extName).appex")
      try stageAppexBundle(
        extensionName: extName,
        extensionBinary: extBinary,
        appexURL: appexURL,
        projectDirectory: projectDirectory,
        platform: platform
      )

      // 3. Sign it.
      try await signAppex(
        appexURL: appexURL,
        projectDirectory: projectDirectory,
        extensionName: extName,
        extConfig: extConfig,
        platform: platform
      )
    }

    // Re-sign the parent .app. `--deep` covers the freshly-embedded .appex
    // bundles; `--force` lets us overwrite swift-bundler's previous
    // signature.
    try await resignParentApp(appURL: appURL, platform: platform)
  }

  // MARK: - PlugIns directory layout

  /// `.appex` bundles live in different locations depending on the platform.
  /// - iOS/tvOS/visionOS/watchOS/simulators: `<App>.app/PlugIns/`
  /// - macOS: `<App>.app/Contents/PlugIns/`
  static func plugInsDirectory(
    for appURL: URL,
    platform: BuildRunner.Platform
  ) -> URL {
    switch platform {
    case .macOS:
      return appURL
        .appendingPathComponent("Contents")
        .appendingPathComponent("PlugIns")
    case .iOS, .iOSSimulator, .tvOS, .tvOSSimulator, .visionOS, .visionOSSimulator:
      return appURL.appendingPathComponent("PlugIns")
    }
  }

  // MARK: - Build

  /// Build an extension target via `xcodebuild -scheme <name>`, reusing the
  /// derived data directory that the main build populated so the resulting
  /// binary sits alongside the parent app's artifacts.
  ///
  /// Returns the path to the built extension executable.
  static func buildExtensionTarget(
    extensionName: String,
    projectDirectory: URL,
    platform: BuildRunner.Platform,
    configuration: BuildRunner.Configuration
  ) async throws -> URL {
    // swift-bundler writes derived data to .build/<triple>/. We reuse that
    // path so our xcodebuild invocation drops artifacts in the same tree.
    let derivedDataPath = derivedDataPath(
      in: projectDirectory,
      platform: platform
    )

    let (destination, productsSubdir) = xcodebuildDestination(for: platform)
    let configName = configuration == .debug ? "Debug" : "Release"

    let arguments: [String] = [
      "-scheme", extensionName,
      "-configuration", configName,
      "-usePackageSupportBuiltinSCM",
      "-skipMacroValidation",
      "-derivedDataPath", derivedDataPath.path,
      "-destination", destination,
    ]

    let (exitCode, _, stderr) = try await runProcess(
      "/usr/bin/xcodebuild",
      arguments: arguments,
      currentDirectory: projectDirectory
    )

    guard exitCode == 0 else {
      throw EmbedError(
        "xcodebuild failed to build extension '\(extensionName)' "
          + "(exit \(exitCode)): \(stderr.prefix(500))"
      )
    }

    // Locate the built binary. xcodebuild drops executables at
    // <derivedDataPath>/Build/Products/<configName>-<productsSubdir>/<name>
    let productsDir = derivedDataPath
      .appendingPathComponent("Build")
      .appendingPathComponent("Products")
      .appendingPathComponent("\(configName)-\(productsSubdir)")
    let binaryURL = productsDir.appendingPathComponent(extensionName)

    guard FileManager.default.fileExists(atPath: binaryURL.path) else {
      throw EmbedError(
        "Built extension binary not found at \(binaryURL.path). "
          + "Expected xcodebuild to produce it at that location."
      )
    }

    return binaryURL
  }

  /// Maps an xclaude build platform to an `xcodebuild -destination` argument
  /// and the corresponding products subdirectory suffix
  /// (e.g. `iphonesimulator` for iOS Simulator).
  private static func xcodebuildDestination(
    for platform: BuildRunner.Platform
  ) -> (destination: String, productsSubdir: String) {
    switch platform {
    case .iOSSimulator:
      return ("generic/platform=iOS Simulator", "iphonesimulator")
    case .iOS:
      return ("generic/platform=iOS", "iphoneos")
    case .macOS:
      return ("generic/platform=macOS", "")  // macOS products go straight under Build/Products/Debug/
    case .tvOSSimulator:
      return ("generic/platform=tvOS Simulator", "appletvsimulator")
    case .tvOS:
      return ("generic/platform=tvOS", "appletvos")
    case .visionOSSimulator:
      return ("generic/platform=visionOS Simulator", "xrsimulator")
    case .visionOS:
      return ("generic/platform=visionOS", "xros")
    }
  }

  /// Where xcodebuild's derived data lives for a given platform, matching
  /// what swift-bundler uses internally so the main-app and extension
  /// artifacts end up in the same tree.
  private static func derivedDataPath(
    in projectDirectory: URL,
    platform: BuildRunner.Platform
  ) -> URL {
    // swift-bundler uses `.build/<arch>-apple-<sdk>` — mirror that.
    let suffix: String
    switch platform {
    case .iOSSimulator: suffix = "arm64-apple-iphonesimulator"
    case .iOS: suffix = "arm64-apple-iphoneos"
    case .macOS: suffix = "arm64-apple-macosx"
    case .tvOSSimulator: suffix = "arm64-apple-appletvsimulator"
    case .tvOS: suffix = "arm64-apple-appletvos"
    case .visionOSSimulator: suffix = "arm64-apple-xrsimulator"
    case .visionOS: suffix = "arm64-apple-xros"
    }
    return projectDirectory.appendingPathComponent(".build").appendingPathComponent(suffix)
  }

  // MARK: - Appex staging

  /// Create the directory structure for an `.appex` bundle, copy the built
  /// binary in, and write the per-extension `Info.plist`.
  static func stageAppexBundle(
    extensionName: String,
    extensionBinary: URL,
    appexURL: URL,
    projectDirectory: URL,
    platform: BuildRunner.Platform
  ) throws {
    // Fresh slate — if the .appex already exists from a previous build,
    // delete it so codesign doesn't complain about a stale signature.
    try? FileManager.default.removeItem(at: appexURL)

    // On iOS-ish platforms, .appex layout is flat: everything at the top
    // level of the .appex directory. On macOS it's nested under Contents/.
    let (binaryDestDir, infoPlistDest): (URL, URL)
    switch platform {
    case .macOS:
      let contents = appexURL.appendingPathComponent("Contents")
      binaryDestDir = contents.appendingPathComponent("MacOS")
      infoPlistDest = contents.appendingPathComponent("Info.plist")
    default:
      binaryDestDir = appexURL
      infoPlistDest = appexURL.appendingPathComponent("Info.plist")
    }

    try FileManager.default.createDirectory(
      at: binaryDestDir,
      withIntermediateDirectories: true
    )

    // Copy the extension binary.
    let binaryDest = binaryDestDir.appendingPathComponent(extensionName)
    try FileManager.default.copyItem(at: extensionBinary, to: binaryDest)

    // Copy the derived Info.plist.
    let derivedInfoPlist = ConfigTranslator.extensionDerivedDirectory(
      for: projectDirectory,
      extensionName: extensionName
    ).appendingPathComponent("Info.plist")

    guard FileManager.default.fileExists(atPath: derivedInfoPlist.path) else {
      throw EmbedError(
        "Derived Info.plist not found for extension '\(extensionName)' at "
          + derivedInfoPlist.path
          + ". Did ConfigTranslator.generateExtensionDerivedFiles run?"
      )
    }
    try FileManager.default.copyItem(at: derivedInfoPlist, to: infoPlistDest)
  }

  // MARK: - Signing

  /// Sign a staged `.appex` bundle. For simulator builds we use ad-hoc
  /// signing (`--sign -`); device signing is a follow-up.
  static func signAppex(
    appexURL: URL,
    projectDirectory: URL,
    extensionName: String,
    extConfig: ExtensionConfig,
    platform: BuildRunner.Platform
  ) async throws {
    let entitlementsPath = ConfigTranslator.extensionDerivedDirectory(
      for: projectDirectory,
      extensionName: extensionName
    ).appendingPathComponent("Entitlements.plist")

    // Ad-hoc signing identity for simulator. Device signing would use the
    // actual developer identity here and pass a provisioning profile.
    let identity = "-"

    var arguments: [String] = [
      "--force",
      "--sign", identity,
      "--timestamp=none",
    ]

    if FileManager.default.fileExists(atPath: entitlementsPath.path) {
      arguments.append("--entitlements")
      arguments.append(entitlementsPath.path)
    }

    arguments.append(appexURL.path)

    let (exitCode, _, stderr) = try await runProcess(
      "/usr/bin/codesign",
      arguments: arguments,
      currentDirectory: projectDirectory
    )

    guard exitCode == 0 else {
      throw EmbedError(
        "Failed to sign extension '\(extensionName)' (exit \(exitCode)): "
          + stderr.prefix(500)
      )
    }
  }

  /// Re-sign the parent `.app` so its signature covers the freshly-embedded
  /// `.appex` bundles. `--deep` tells codesign to also verify/sign nested
  /// bundles; `--force` lets us overwrite swift-bundler's previous signature.
  static func resignParentApp(
    appURL: URL,
    platform: BuildRunner.Platform
  ) async throws {
    let identity = "-"  // Ad-hoc for simulator.

    let arguments: [String] = [
      "--force",
      "--deep",
      "--sign", identity,
      "--timestamp=none",
      appURL.path,
    ]

    let (exitCode, _, stderr) = try await runProcess(
      "/usr/bin/codesign",
      arguments: arguments,
      currentDirectory: appURL.deletingLastPathComponent()
    )

    guard exitCode == 0 else {
      throw EmbedError(
        "Failed to re-sign parent app after embedding extensions "
          + "(exit \(exitCode)): \(stderr.prefix(500))"
      )
    }
  }

  // MARK: - Subprocess helper

  /// Runs a subprocess and returns (exit code, stdout, stderr).
  ///
  /// Uses a continuation so the async runtime can service other work while
  /// the subprocess runs. A naive `process.waitUntilExit()` would block the
  /// calling thread — and because this is called from the MCP server's
  /// async event loop, blocking here means `build_status` (and every other
  /// MCP tool call) stops responding until the subprocess finishes. That
  /// was the first thing to bite us when wiring up extension embedding.
  private static func runProcess(
    _ executable: String,
    arguments: [String],
    currentDirectory: URL
  ) async throws -> (Int32, String, String) {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<(Int32, String, String), Error>) in
      let process = Process()
      process.executableURL = URL(fileURLWithPath: executable)
      process.arguments = arguments
      process.currentDirectoryURL = currentDirectory

      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      process.terminationHandler = { finishedProcess in
        // Read output AFTER the process has exited — blocking reads on a
        // running process's pipes can deadlock if the child fills its
        // stdout/stderr buffer.
        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        continuation.resume(
          returning: (finishedProcess.terminationStatus, stdout, stderr)
        )
      }

      do {
        try process.run()
      } catch {
        continuation.resume(throwing: error)
      }
    }
  }
}
