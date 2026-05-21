import Foundation

// MARK: - Build Status

public enum BuildStatus: String, Codable, Sendable {
  /// The underlying `swift-bundler` process is still running.
  case running
  /// `swift-bundler` exited successfully and xclaude is now running its own
  /// post-processing (asset catalog compilation, extension embedding,
  /// re-signing). Clients should treat this as "not done yet" — the `.app`
  /// bundle exists on disk but is not yet complete.
  case postProcessing = "post_processing"
  /// Everything is done and the `.app` is ready to install/run.
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
  private var _postProcessError: String?
  private let maxBufferLines = 5000
  private var _postProcessTask: Task<Void, Never>?

  /// Optional post-processing closure, invoked after `swift-bundler` exits
  /// successfully. While it runs, the job's status is `.postProcessing`. When
  /// the closure returns, the status transitions to `.success`. If the
  /// closure throws, `.failed` with the error recorded in `postProcessError`.
  public typealias PostProcessHandler = @Sendable (BuildJob) async throws -> Void
  private let postProcessHandler: PostProcessHandler?

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
    outputPipe: Pipe,
    postProcessHandler: PostProcessHandler? = nil
  ) {
    self.id = id
    self.projectPath = projectPath
    self.platform = platform
    self.configuration = configuration
    self.startTime = Date()
    self.process = process
    self.outputPipe = outputPipe
    self.postProcessHandler = postProcessHandler

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

  public var postProcessError: String? {
    lock.lock()
    defer { lock.unlock() }
    return _postProcessError
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

    _exitCode = exitCode

    // Stop the readability handler — the child's stdout/stderr are closed.
    outputPipe.fileHandleForReading.readabilityHandler = nil

    // Failed or no post-processing requested → transition directly to a
    // terminal state.
    guard exitCode == 0, let handler = postProcessHandler else {
      _status = exitCode == 0 ? .success : .failed
      _endTime = Date()
      lock.unlock()
      return
    }

    // swift-bundler exited successfully; run the post-process handler in a
    // detached task and transition to .postProcessing. The job stays in
    // .postProcessing until the handler returns, at which point
    // finishPostProcessing() flips it to .success (or .failed on error).
    _status = .postProcessing
    lock.unlock()

    _postProcessTask = Task { [weak self] in
      guard let self = self else { return }
      do {
        try await handler(self)
        self.finishPostProcessing(error: nil)
      } catch {
        self.finishPostProcessing(error: "\(error)")
      }
    }
  }

  private func finishPostProcessing(error: String?) {
    lock.lock()
    defer { lock.unlock() }
    _endTime = Date()
    if let error = error {
      _postProcessError = error
      _status = .failed
    } else {
      _status = .success
    }
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
    swiftBundlerPath: String,
    postProcessHandler: BuildJob.PostProcessHandler? = nil
  ) throws -> BuildJob {
    let jobId = "build-\(nextJobId)"
    nextJobId += 1

    let process = Process()
    // Wrap swift-bundler in `script -q /dev/null` so the child sees a PTY
    // instead of a pipe on stdout. iOS device builds otherwise wedge
    // *inside* xcodebuild: clang runs an initial `-v -E -dM` SDK probe whose
    // output piles up in the clang→SWBBuildService pipe; the back-pressure
    // propagates all the way out through xcbeautify and swift-bundler to the
    // pipe we control, and clang blocks forever on a single `write()`
    // syscall. A pseudo-TTY is what xcodebuild expects for interactive
    // builds and avoids the whole back-pressure cascade. macOS's `script`
    // takes care of allocating the PTY for us, and `-q /dev/null` keeps
    // it from also writing a typescript file.
    process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
    process.arguments = ["-q", "/dev/null", swiftBundlerPath] + arguments
    process.currentDirectoryURL = URL(fileURLWithPath: projectPath)

    // Capture both stdout and stderr. `script`'s stdout is the PTY master
    // it allocated; reading it gets us everything swift-bundler (and its
    // xcodebuild descendants) wrote to the slave PTY.
    let outputPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = outputPipe

    let job = BuildJob(
      id: jobId,
      projectPath: projectPath,
      platform: platform,
      configuration: configuration,
      process: process,
      outputPipe: outputPipe,
      postProcessHandler: postProcessHandler
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
  /// Non-nil only when `status == .failed` due to a post-processing error
  /// (asset catalog compilation, extension embedding, or re-signing).
  public let postProcessError: String?

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
    self.postProcessError = job.postProcessError
  }
}
