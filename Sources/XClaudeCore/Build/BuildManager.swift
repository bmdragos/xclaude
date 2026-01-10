import Foundation

// MARK: - Build Status

public enum BuildStatus: String, Codable, Sendable {
  case running
  case success
  case failed
  case cancelled
}

// MARK: - Build Job

/// Represents an active or completed build with buffered output
public final class BuildJob: @unchecked Sendable {
  public let id: String
  public let projectPath: String
  public let platform: String
  public let configuration: String
  public let startTime: Date

  private let process: Process
  private let outputPipe: Pipe
  private let queue = DispatchQueue(label: "build.output")
  private let lock = NSLock()

  private var _outputBuffer: [String] = []
  private var _status: BuildStatus = .running
  private var _exitCode: Int32?
  private var _endTime: Date?
  private var _appPath: String?
  private let maxBufferLines = 5000

  public var status: BuildStatus {
    lock.lock()
    defer { lock.unlock() }
    return _status
  }

  public var exitCode: Int32? {
    lock.lock()
    defer { lock.unlock() }
    return _exitCode
  }

  public var endTime: Date? {
    lock.lock()
    defer { lock.unlock() }
    return _endTime
  }

  public var appPath: String? {
    lock.lock()
    defer { lock.unlock() }
    return _appPath
  }

  public func setAppPath(_ path: String) {
    lock.lock()
    defer { lock.unlock() }
    _appPath = path
  }

  public var duration: TimeInterval {
    let end = endTime ?? Date()
    return end.timeIntervalSince(startTime)
  }

  public var bufferedLineCount: Int {
    lock.lock()
    defer { lock.unlock() }
    return _outputBuffer.count
  }

  init(
    id: String,
    projectPath: String,
    platform: String,
    configuration: String,
    process: Process,
    outputPipe: Pipe
  ) {
    self.id = id
    self.projectPath = projectPath
    self.platform = platform
    self.configuration = configuration
    self.startTime = Date()
    self.process = process
    self.outputPipe = outputPipe

    // Set up async output reading
    outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else { return }

      if let str = String(data: data, encoding: .utf8) {
        self?.appendOutput(str)
      }
    }

    // Set up termination handler
    process.terminationHandler = { [weak self] proc in
      self?.handleTermination(exitCode: proc.terminationStatus)
    }
  }

  private func appendOutput(_ text: String) {
    lock.lock()
    defer { lock.unlock() }

    let lines = text.components(separatedBy: .newlines)
    for line in lines where !line.isEmpty {
      _outputBuffer.append(line)
    }

    // Trim buffer if too large
    if _outputBuffer.count > maxBufferLines {
      _outputBuffer = Array(_outputBuffer.suffix(maxBufferLines))
    }
  }

  private func handleTermination(exitCode: Int32) {
    lock.lock()
    defer { lock.unlock() }

    _exitCode = exitCode
    _endTime = Date()
    _status = exitCode == 0 ? .success : .failed

    // Stop the readability handler
    outputPipe.fileHandleForReading.readabilityHandler = nil
  }

  /// Read buffered output lines (non-blocking)
  /// - Parameters:
  ///   - count: Number of recent lines to return (nil = all)
  ///   - clear: Whether to clear the buffer after reading (default: false)
  public func readOutput(count: Int? = nil, clear: Bool = false) -> [String] {
    lock.lock()
    defer { lock.unlock() }

    let lines: [String]
    if let count = count {
      lines = Array(_outputBuffer.suffix(count))
    } else {
      lines = _outputBuffer
    }

    if clear {
      _outputBuffer = []
    }

    return lines
  }

  /// Cancel the build
  public func cancel() {
    lock.lock()
    if _status == .running {
      _status = .cancelled
    }
    lock.unlock()

    if process.isRunning {
      process.terminate()
    }
  }
}

// MARK: - Build Manager Actor

/// Actor managing active builds with buffered output
public actor BuildManager {
  public static let shared = BuildManager()

  private var jobs: [String: BuildJob] = [:]
  private var nextJobId: Int = 1

  private init() {}

  /// Start a new build job
  /// Returns immediately with job ID - use `readOutput` to get build progress
  public func startBuild(
    projectPath: String,
    platform: String,
    configuration: String,
    arguments: [String],
    swiftBundlerPath: String
  ) throws -> BuildJob {
    let jobId = "build-\(nextJobId)"
    nextJobId += 1

    let process = Process()
    process.executableURL = URL(fileURLWithPath: swiftBundlerPath)
    process.arguments = arguments
    process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

    // Capture both stdout and stderr
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    let job = BuildJob(
      id: jobId,
      projectPath: projectPath,
      platform: platform,
      configuration: configuration,
      process: process,
      outputPipe: outputPipe
    )

    jobs[jobId] = job

    try process.run()

    return job
  }

  /// Get a job by ID
  public func getJob(_ id: String) -> BuildJob? {
    return jobs[id]
  }

  /// Get all active jobs
  public func activeJobs() -> [BuildJob] {
    return jobs.values.filter { $0.status == .running }
  }

  /// Get recent jobs (active + last N completed)
  public func recentJobs(limit: Int = 5) -> [BuildJob] {
    let sorted = jobs.values.sorted { a, b in
      a.startTime > b.startTime
    }
    return Array(sorted.prefix(limit))
  }

  /// Clean up old completed jobs
  public func cleanup(keepLast: Int = 5) {
    let completed = jobs.values
      .filter { $0.status != .running }
      .sorted { $0.startTime > $1.startTime }

    if completed.count > keepLast {
      let toRemove = completed.dropFirst(keepLast)
      for job in toRemove {
        jobs.removeValue(forKey: job.id)
      }
    }
  }

  /// Cancel a job
  public func cancel(_ id: String) -> Bool {
    guard let job = jobs[id] else { return false }
    job.cancel()
    return true
  }
}

// MARK: - Build Job Info (Codable summary)

public struct BuildJobInfo: Codable {
  public let id: String
  public let projectPath: String
  public let platform: String
  public let configuration: String
  public let status: BuildStatus
  public let exitCode: Int32?
  public let startTime: Date
  public let endTime: Date?
  public let duration: TimeInterval
  public let bufferedLines: Int
  public let appPath: String?

  public init(from job: BuildJob) {
    self.id = job.id
    self.projectPath = job.projectPath
    self.platform = job.platform
    self.configuration = job.configuration
    self.status = job.status
    self.exitCode = job.exitCode
    self.startTime = job.startTime
    self.endTime = job.endTime
    self.duration = job.duration
    self.bufferedLines = job.bufferedLineCount
    self.appPath = job.appPath
  }
}
