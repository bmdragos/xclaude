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
  ///   - parentSigning: Resolved signing for the parent app. Non-nil for
  ///               device builds, nil for simulator (which uses ad-hoc).
  ///               Extensions reuse the parent's identity; each extension
  ///               resolves its own provisioning profile separately from
  ///               `SigningDiscovery` using its extension bundle ID.
  public static func embedExtensions(
    appPath: String,
    projectDirectory: URL,
    platform: BuildRunner.Platform,
    configuration: BuildRunner.Configuration,
    parentSigning: SigningDiscovery.ResolvedSigning? = nil
  ) async throws {
    // Fast path: no extensions declared.
    guard let config = try? XClaudeConfig.load(from: projectDirectory),
          let extensions = config.extensions,
          !extensions.isEmpty else {
      return
    }

    // Regenerate per-extension derived files so we always sign against
    // fresh plist/entitlements content, even if xclaude.toml changed since
    // the last build. For simulator builds, omit application-identifier
    // from the extension's Entitlements.plist (pkd refuses to spawn ad-hoc
    // .appex bundles that carry one).
    try ConfigTranslator.generateExtensionDerivedFiles(
      config: config,
      projectDirectory: projectDirectory,
      adHocSimulator: parentSigning == nil && platform.isSimulator
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

      // 2. Assemble the `.appex` bundle. For device builds this is also
      //    where the extension's provisioning profile gets embedded (via
      //    the `extensionSigning` resolved below).
      let appexURL = plugInsURL.appendingPathComponent("\(extName).appex")
      try stageAppexBundle(
        extensionName: extName,
        extensionBinary: extBinary,
        appexURL: appexURL,
        projectDirectory: projectDirectory,
        platform: platform
      )

      // 3. For device builds, resolve the extension's own provisioning
      //    profile (each extension bundle ID needs its own profile in
      //    Apple Portal) and copy it into the .appex. For simulator builds
      //    this is a no-op — simulator uses ad-hoc signing with no profile.
      //
      //    Inherit the parent app's signing mode: a debug parent build
      //    must embed development extension profiles, a release parent
      //    must embed distribution ones — otherwise the .app + .appex
      //    pair has mismatched profile types and on-device install fails.
      var extensionSigning: SigningDiscovery.ResolvedSigning? = nil
      if platform.requiresSigning && parentSigning != nil {
        let extBundleId =
          extConfig.bundleId ?? "\(config.app.bundleId).\(extName)"
        do {
          let discovery = SigningDiscovery()
          extensionSigning = try await discovery.resolveSigning(
            bundleId: extBundleId,
            platform: platform.platformName,
            projectDirectory: projectDirectory,
            config: config,
            mode: configuration.signingMode
          )
        } catch {
          throw EmbedError(
            "Failed to resolve signing for extension '\(extName)' with "
              + "bundle ID '\(extBundleId)': \(error). Device builds require "
              + "a provisioning profile for each extension's bundle ID. "
              + "Create one via Apple Developer Portal or asc_create_profile."
          )
        }

        // Copy the profile into the .appex. iOS extensions expect it at
        // the top of the bundle; macOS extensions at Contents/.
        if let signing = extensionSigning {
          try embedProvisioningProfile(
            from: URL(fileURLWithPath: signing.profile.path),
            intoBundle: appexURL,
            platform: platform
          )
        }
      }

      // 4. Sign it.
      try await signAppex(
        appexURL: appexURL,
        projectDirectory: projectDirectory,
        extensionName: extName,
        extConfig: extConfig,
        platform: platform,
        extensionSigning: extensionSigning
      )
    }

    // Re-sign the parent .app to cover the freshly-embedded .appex bundles.
    // For simulator builds (no resolved signing) we also emit an ad-hoc
    // Entitlements.plist from xclaude.toml's [capabilities] so the parent
    // can read the App Group container that the extension wrote to.
    // Without this, swift-bundler's ad-hoc signing pass leaves the parent
    // with zero entitlements and `containerURL(forSecurityApplicationGroupIdentifier:)`
    // returns nil at runtime.
    let parentSimulatorEntitlements: URL? = {
      guard parentSigning == nil, platform.isSimulator else { return nil }
      return try? writeAdHocParentEntitlements(
        config: config,
        projectDirectory: projectDirectory
      )
    }()

    try await resignParentApp(
      appURL: appURL,
      platform: platform,
      parentSigning: parentSigning,
      adHocEntitlementsPath: parentSimulatorEntitlements
    )
  }

  /// Build an ad-hoc Entitlements.plist for the parent app, derived from
  /// xclaude.toml's `[capabilities]` section. Used for iOS Simulator builds
  /// (and other ad-hoc targets) so the parent app still gets App Group,
  /// keychain, and other capabilities even without a provisioning profile.
  ///
  /// Returns the path to the written file, or nil if nothing was emitted
  /// (no capabilities → nothing useful to sign).
  private static func writeAdHocParentEntitlements(
    config: XClaudeConfig,
    projectDirectory: URL
  ) throws -> URL? {
    guard let capabilities = config.capabilities, !capabilities.isEmpty else {
      return nil
    }

    // Deliberately NO `application-identifier` here. On simulator that key
    // is validated against the signature's identity, and ad-hoc signing
    // can't produce a real team-prefixed identifier — including it makes
    // launchd reject the binary with the unhelpful NSPOSIXErrorDomain
    // code 163 ("Launchd job spawn failed"). App Group access works fine
    // without it; `com.apple.security.application-groups` alone is what
    // grants `containerURL(forSecurityApplicationGroupIdentifier:)`.
    //
    // `get-task-allow` is also intentionally omitted — once
    // `application-identifier` is gone, simulator launchd doesn't require
    // it and adding it just makes codesign warn about a stray flag on an
    // ad-hoc signature.
    var entitlements: [String: Any] = [:]

    // Resolve each capability the same way per-extension entitlements do.
    // Simulator builds are iOS-only, so we use the .iOS platform spec.
    var addedCapabilityKeys = false
    for (capName, capValue) in capabilities {
      guard let manifest = CapabilityRegistry.manifest(for: capName) else {
        continue
      }
      let resolved = manifest.resolvedEntitlements(
        for: .iOS,
        userValue: capValue
      )
      for (key, value) in resolved {
        entitlements[key] = value
        addedCapabilityKeys = true
      }
    }

    // No capability mapped to an iOS entitlement (e.g. only iOS-Info.plist-
    // only capabilities like `camera` were declared) — skip emission so we
    // don't add an entitlements file with nothing real in it.
    guard addedCapabilityKeys else { return nil }

    let derivedDir = ConfigTranslator.derivedDirectory(for: projectDirectory)
    try FileManager.default.createDirectory(
      at: derivedDir,
      withIntermediateDirectories: true
    )
    let path = derivedDir.appendingPathComponent("Entitlements.plist")
    let data = try PropertyListSerialization.data(
      fromPropertyList: entitlements,
      format: .xml,
      options: 0
    )
    try data.write(to: path)
    return path
  }

  /// Copy a provisioning profile into an app or extension bundle as
  /// `embedded.mobileprovision`. iOS-ish platforms place it at the bundle
  /// root; macOS places it under `Contents/`.
  private static func embedProvisioningProfile(
    from profileURL: URL,
    intoBundle bundleURL: URL,
    platform: BuildRunner.Platform
  ) throws {
    let destRoot: URL
    switch platform {
    case .macOS:
      destRoot = bundleURL.appendingPathComponent("Contents")
    default:
      destRoot = bundleURL
    }
    let dest = destRoot.appendingPathComponent("embedded.mobileprovision")
    // Replace any existing profile.
    try? FileManager.default.removeItem(at: dest)
    try FileManager.default.copyItem(at: profileURL, to: dest)
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

  /// Sign a staged `.appex` bundle.
  ///
  /// - For simulator builds (`extensionSigning == nil`): ad-hoc signing
  ///   with identity `-` and the derived entitlements file.
  /// - For device builds (`extensionSigning != nil`): sign with the resolved
  ///   identity from the keychain. The provisioning profile is already in
  ///   the bundle (embedded by `embedProvisioningProfile`), and the
  ///   entitlements file is the per-extension one from ConfigTranslator.
  static func signAppex(
    appexURL: URL,
    projectDirectory: URL,
    extensionName: String,
    extConfig: ExtensionConfig,
    platform: BuildRunner.Platform,
    extensionSigning: SigningDiscovery.ResolvedSigning? = nil
  ) async throws {
    let entitlementsPath = ConfigTranslator.extensionDerivedDirectory(
      for: projectDirectory,
      extensionName: extensionName
    ).appendingPathComponent("Entitlements.plist")

    // For device builds the entitlements file's `application-identifier`
    // must be the full `<teamId>.<bundleId>` form, matching the embedded
    // provisioning profile. ConfigTranslator wrote just the bare bundle
    // id (correct for simulator's ad-hoc signing, where any team prefix
    // would be invented); inject the team prefix here now that signing
    // is resolved. Same treatment for `keychain-access-groups` if it
    // ever shows up.
    if let signing = extensionSigning,
       FileManager.default.fileExists(atPath: entitlementsPath.path) {
      let data = try Data(contentsOf: entitlementsPath)
      if var plist = try PropertyListSerialization.propertyList(
        from: data, format: nil
      ) as? [String: Any] {
        let prefix = "\(signing.teamId)."
        if let appId = plist["application-identifier"] as? String,
           !appId.hasPrefix(prefix) {
          plist["application-identifier"] = prefix + appId
        }
        if let groups = plist["keychain-access-groups"] as? [String] {
          plist["keychain-access-groups"] = groups.map {
            $0.hasPrefix(prefix) ? $0 : prefix + $0
          }
        }
        let updated = try PropertyListSerialization.data(
          fromPropertyList: plist, format: .xml, options: 0
        )
        try updated.write(to: entitlementsPath)
      }
    }

    // Pick the identity: resolved identity for device, ad-hoc for simulator.
    let identity = extensionSigning?.identity.id ?? "-"

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
  /// `.appex` bundles.
  ///
  /// - Simulator (`parentSigning == nil`): `codesign --deep --sign -`. The
  ///   `--deep` flag re-signs nested bundles with ad-hoc too, which is
  ///   what we want since the .appex were already ad-hoc signed.
  /// - Device (`parentSigning != nil`): sign the parent WITHOUT `--deep`
  ///   so codesign seals the existing nested signatures by content hash
  ///   rather than attempting to re-sign them (each .appex has its own
  ///   entitlements and profile that the parent's identity alone can't
  ///   produce via --deep).
  static func resignParentApp(
    appURL: URL,
    platform: BuildRunner.Platform,
    parentSigning: SigningDiscovery.ResolvedSigning? = nil,
    adHocEntitlementsPath: URL? = nil
  ) async throws {
    var arguments: [String] = [
      "--force",
      "--timestamp=none",
    ]

    if let signing = parentSigning {
      // Device build: reuse the parent's identity and entitlements.
      arguments.append(contentsOf: ["--sign", signing.identity.id])
      arguments.append(contentsOf: ["--entitlements", signing.entitlementsPath])
      // Explicitly NO --deep — nested .appex bundles are already signed
      // with their own identities/profiles and we want codesign to just
      // seal them by hash.
    } else {
      // Simulator build: ad-hoc. If the project declares capabilities, the
      // caller pre-built an ad-hoc Entitlements.plist; embed it so the
      // parent app actually gets App Group / keychain / etc. access at
      // runtime. Without it, swift-bundler's earlier ad-hoc sign left the
      // parent with zero entitlements and capability APIs return nil.
      // No --deep here either when we have an entitlements file: --deep
      // re-signs nested .appex bundles with the SAME entitlements, which
      // would clobber the extension's per-target entitlements. With nothing
      // to embed --deep is harmless and we keep it for back-compat with
      // simulator builds that don't declare any capabilities.
      arguments.append(contentsOf: ["--sign", "-"])
      if let entitlements = adHocEntitlementsPath {
        arguments.append(contentsOf: ["--entitlements", entitlements.path])
      } else {
        arguments.append("--deep")
      }
    }

    arguments.append(appURL.path)

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
  /// the subprocess runs, and drains the child's stdout/stderr pipes
  /// continuously via `readabilityHandler` so the child never blocks on a
  /// full pipe buffer.
  ///
  /// Two hazards this function is careful about:
  ///
  /// 1. Blocking the async runtime — a naive `process.waitUntilExit()`
  ///    would block the thread running the MCP server's event loop,
  ///    which means `build_status` (and every other MCP tool call)
  ///    stops responding until the subprocess finishes.
  /// 2. Pipe buffer deadlock — the OS pipe buffer is only ~64KB. If we
  ///    only read output AFTER the child exits, a chatty subprocess like
  ///    `xcodebuild` fills the buffer, blocks trying to write more, and
  ///    never exits. The termination handler then never fires and the
  ///    continuation hangs forever. We avoid this by draining the pipes
  ///    while the child is running via `readabilityHandler` and
  ///    reassembling the accumulated data when the termination handler
  ///    fires. Yes, this one bit us.
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

      // Accumulator buffers for streaming pipe data. Wrapped in a lock
      // because readabilityHandler callbacks fire on a background queue
      // while the termination handler fires on another queue.
      let bufferLock = NSLock()
      nonisolated(unsafe) var stdoutData = Data()
      nonisolated(unsafe) var stderrData = Data()

      stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        bufferLock.lock()
        stdoutData.append(chunk)
        bufferLock.unlock()
      }

      stderrPipe.fileHandleForReading.readabilityHandler = { handle in
        let chunk = handle.availableData
        guard !chunk.isEmpty else { return }
        bufferLock.lock()
        stderrData.append(chunk)
        bufferLock.unlock()
      }

      process.terminationHandler = { finishedProcess in
        // Clear the readability handlers so no further chunks arrive after
        // we've snapshotted the buffers. Also drain any final bytes that
        // were waiting in the pipe but hadn't triggered a readability
        // callback yet.
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        let finalStdout = stdoutPipe.fileHandleForReading.availableData
        let finalStderr = stderrPipe.fileHandleForReading.availableData

        bufferLock.lock()
        if !finalStdout.isEmpty { stdoutData.append(finalStdout) }
        if !finalStderr.isEmpty { stderrData.append(finalStderr) }
        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""
        bufferLock.unlock()

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
