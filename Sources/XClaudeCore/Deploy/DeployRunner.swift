import Foundation

/// Deploys and launches apps on simulators and devices
public struct DeployRunner {

  /// Deploy result
  public struct DeployResult: Codable {
    public let success: Bool
    public let target: TargetInfo
    public let appPath: String
    public let bundleId: String
    public let launched: Bool
    public let error: String?

    public init(success: Bool, target: TargetInfo, appPath: String, bundleId: String,
                launched: Bool, error: String? = nil) {
      self.success = success
      self.target = target
      self.appPath = appPath
      self.bundleId = bundleId
      self.launched = launched
      self.error = error
    }
  }

  /// Target device/simulator info
  public struct TargetInfo: Codable {
    public let type: TargetType
    public let udid: String
    public let name: String

    public init(type: TargetType, udid: String, name: String) {
      self.type = type
      self.udid = udid
      self.name = name
    }
  }

  public enum TargetType: String, Codable {
    case simulator
    case device
  }

  /// Deploy target specification
  public enum Target {
    case simulator(udid: String)
    case simulatorByName(name: String)
    case anyBootedSimulator
    case device(udid: String)
    case deviceByName(name: String)
    case anyDevice

    /// Parse target string from MCP argument
    public static func parse(_ string: String) -> Target {
      switch string.lowercased() {
      case "simulator":
        return .anyBootedSimulator
      case "device":
        return .anyDevice
      default:
        // Check if it looks like a UDID (contains dashes or is 40 hex chars)
        if string.contains("-") || (string.count == 40 && string.allSatisfy({ $0.isHexDigit })) {
          // Could be simulator or device UDID - try to detect
          return .simulator(udid: string)  // Default to simulator, will try device if fails
        } else {
          // Assume it's a name
          return .simulatorByName(name: string)
        }
      }
    }
  }

  // MARK: - Simulator Deployment

  /// Deploy to simulator
  public static func deployToSimulator(
    appPath: String,
    bundleId: String,
    target: Target,
    launch: Bool = true
  ) async throws -> DeployResult {

    // Resolve target to actual simulator
    let (udid, name) = try await resolveSimulator(target)

    // Boot simulator if needed
    try await bootSimulatorIfNeeded(udid: udid)

    // Install app
    let installResult = try await runSimctl(["install", udid, appPath])
    if !installResult.success {
      return DeployResult(
        success: false,
        target: TargetInfo(type: .simulator, udid: udid, name: name),
        appPath: appPath,
        bundleId: bundleId,
        launched: false,
        error: installResult.error ?? "Failed to install app"
      )
    }

    // Launch if requested
    var launched = false
    if launch {
      let launchResult = try await runSimctl(["launch", udid, bundleId])
      launched = launchResult.success
    }

    return DeployResult(
      success: true,
      target: TargetInfo(type: .simulator, udid: udid, name: name),
      appPath: appPath,
      bundleId: bundleId,
      launched: launched
    )
  }

  /// Resolve simulator target to UDID and name
  private static func resolveSimulator(_ target: Target) async throws -> (udid: String, name: String) {
    switch target {
    case .simulator(let udid):
      // Verify simulator exists and get name
      let info = try await getSimulatorInfo(udid: udid)
      return (udid, info.name)

    case .simulatorByName(let name):
      // Find simulator by name
      let simulators = try await listSimulators()
      guard let sim = simulators.first(where: { $0.name == name }) else {
        throw DeployError.simulatorNotFound(name)
      }
      return (sim.udid, sim.name)

    case .anyBootedSimulator:
      // Find any booted simulator
      let simulators = try await listSimulators()
      if let booted = simulators.first(where: { $0.state == "Booted" }) {
        return (booted.udid, booted.name)
      }
      // No booted simulator - boot the first available iPhone
      if let iphone = simulators.first(where: { $0.name.contains("iPhone") }) {
        return (iphone.udid, iphone.name)
      }
      // Fall back to any simulator
      guard let any = simulators.first else {
        throw DeployError.noSimulatorsAvailable
      }
      return (any.udid, any.name)

    default:
      throw DeployError.invalidTarget("Expected simulator target")
    }
  }

  private static func bootSimulatorIfNeeded(udid: String) async throws {
    let info = try await getSimulatorInfo(udid: udid)
    if info.state != "Booted" {
      _ = try await runSimctl(["boot", udid])
      // Wait for boot
      try await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds
    }
  }

  private struct SimulatorInfo {
    let udid: String
    let name: String
    let state: String
  }

  private static func getSimulatorInfo(udid: String) async throws -> SimulatorInfo {
    let simulators = try await listSimulators()
    guard let sim = simulators.first(where: { $0.udid == udid }) else {
      throw DeployError.simulatorNotFound(udid)
    }
    return SimulatorInfo(udid: sim.udid, name: sim.name, state: sim.state)
  }

  private static func listSimulators() async throws -> [SimulatorInfo] {
    let output = try await runCommand("/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"])

    guard let data = output.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let devices = json["devices"] as? [String: [[String: Any]]] else {
      throw DeployError.failedToListSimulators
    }

    var results: [SimulatorInfo] = []
    for (_, simulators) in devices {
      for sim in simulators {
        guard let name = sim["name"] as? String,
              let udid = sim["udid"] as? String,
              let state = sim["state"] as? String,
              let isAvailable = sim["isAvailable"] as? Bool,
              isAvailable else {
          continue
        }
        results.append(SimulatorInfo(udid: udid, name: name, state: state))
      }
    }
    return results
  }

  private static func runSimctl(_ arguments: [String]) async throws -> (success: Bool, error: String?) {
    let result = try await runCommand("/usr/bin/xcrun", arguments: ["simctl"] + arguments)
    // simctl returns empty on success, error message on failure
    let success = result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                  !result.lowercased().contains("error")
    return (success, success ? nil : result)
  }

  // MARK: - Device Deployment

  /// Deploy to physical device
  public static func deployToDevice(
    appPath: String,
    bundleId: String,
    target: Target,
    launch: Bool = true
  ) async throws -> DeployResult {

    // Resolve target to actual device
    let (udid, name) = try await resolveDevice(target)

    // Install app using devicectl
    let installArgs = ["device", "install", "app", "--device", udid, appPath]
    let installOutput = try await runCommand("/usr/bin/xcrun", arguments: ["devicectl"] + installArgs)

    if installOutput.lowercased().contains("error") {
      return DeployResult(
        success: false,
        target: TargetInfo(type: .device, udid: udid, name: name),
        appPath: appPath,
        bundleId: bundleId,
        launched: false,
        error: installOutput
      )
    }

    // Launch if requested
    var launched = false
    if launch {
      let launchArgs = ["device", "process", "launch", "--device", udid, bundleId]
      let launchOutput = try await runCommand("/usr/bin/xcrun", arguments: ["devicectl"] + launchArgs)
      launched = !launchOutput.lowercased().contains("error")
    }

    return DeployResult(
      success: true,
      target: TargetInfo(type: .device, udid: udid, name: name),
      appPath: appPath,
      bundleId: bundleId,
      launched: launched
    )
  }

  /// Resolve device target to UDID and name
  private static func resolveDevice(_ target: Target) async throws -> (udid: String, name: String) {
    switch target {
    case .device(let udid):
      let info = try await getDeviceInfo(udid: udid)
      return (udid, info.name)

    case .deviceByName(let name):
      let devices = try await listDevices()
      guard let dev = devices.first(where: { $0.name == name }) else {
        throw DeployError.deviceNotFound(name)
      }
      return (dev.udid, dev.name)

    case .anyDevice:
      let devices = try await listDevices()
      guard let dev = devices.first else {
        throw DeployError.noDevicesConnected
      }
      return (dev.udid, dev.name)

    default:
      throw DeployError.invalidTarget("Expected device target")
    }
  }

  private struct DeviceInfo {
    let udid: String
    let name: String
  }

  private static func getDeviceInfo(udid: String) async throws -> DeviceInfo {
    let devices = try await listDevices()
    guard let dev = devices.first(where: { $0.udid == udid }) else {
      throw DeployError.deviceNotFound(udid)
    }
    return DeviceInfo(udid: dev.udid, name: dev.name)
  }

  private static func listDevices() async throws -> [DeviceInfo] {
    let output = try await runCommand("/usr/bin/xcrun", arguments: ["devicectl", "list", "devices", "-j"])

    guard let data = output.data(using: .utf8),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let result = json["result"] as? [String: Any],
          let devices = result["devices"] as? [[String: Any]] else {
      return []
    }

    var results: [DeviceInfo] = []
    for device in devices {
      guard let props = device["deviceProperties"] as? [String: Any],
            let name = props["name"] as? String,
            let udid = device["identifier"] as? String else {
        continue
      }
      results.append(DeviceInfo(udid: udid, name: name))
    }
    return results
  }

  // MARK: - Helpers

  private static func runCommand(_ command: String, arguments: [String]) async throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: command)
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

/// Deploy errors
public enum DeployError: Error, CustomStringConvertible {
  case simulatorNotFound(String)
  case noSimulatorsAvailable
  case deviceNotFound(String)
  case noDevicesConnected
  case invalidTarget(String)
  case installFailed(String)
  case launchFailed(String)
  case failedToListSimulators

  public var description: String {
    switch self {
    case .simulatorNotFound(let id):
      return "Simulator not found: \(id)"
    case .noSimulatorsAvailable:
      return "No simulators available"
    case .deviceNotFound(let id):
      return "Device not found: \(id)"
    case .noDevicesConnected:
      return "No devices connected"
    case .invalidTarget(let msg):
      return "Invalid target: \(msg)"
    case .installFailed(let msg):
      return "Install failed: \(msg)"
    case .launchFailed(let msg):
      return "Launch failed: \(msg)"
    case .failedToListSimulators:
      return "Failed to list simulators"
    }
  }
}
