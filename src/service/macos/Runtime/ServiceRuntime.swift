// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Own the service lifecycle: take the lock, read the configuration, sample on a
// timer, and flush before exiting. Every effect goes through a port, so the
// policy in this file is the only thing that has to be reasoned about.
final class ServiceRuntime {
  // Consecutive sampling failures tolerated before the runtime stops repeating
  // itself. A denied Accessibility grant fails on every tick forever.
  private static let failureReportLimit = 5

  // Ports.
  private let configurationStore: any ConfigurationLoading
  private let instanceLock: any InstanceLocking
  private let clock: any Clocking
  private let ticker: any Ticking
  private let signals: any SignalObserving

  // Builds the coordinator once the policy is known, so tests can substitute probes.
  private let makeCoordinator: (TrackingPolicy) -> TrackingCoordinator

  // Sampling state.
  private var coordinator: TrackingCoordinator?
  private var lastTickUnixSec: Int64?
  private var gapThresholdSec: Int64 = 5
  private var consecutiveFailures = 0
  private var exitCode: ServiceExitCode = .success

  // Initialize the runtime with its ports.
  init(
    configurationStore: any ConfigurationLoading = FileConfigurationStore(),
    instanceLock: any InstanceLocking = FileInstanceLock(),
    clock: any Clocking = SystemClock(),
    ticker: any Ticking = RunLoopTicker(),
    signals: any SignalObserving = SignalObserver(),
    makeCoordinator: @escaping (TrackingPolicy) -> TrackingCoordinator = { policy in
      TrackingCoordinator(policy: policy)
    }
  ) {
    self.configurationStore = configurationStore
    self.instanceLock = instanceLock
    self.clock = clock
    self.ticker = ticker
    self.signals = signals
    self.makeCoordinator = makeCoordinator
  }

  // Run until a stop signal arrives and report the process exit code.
  func run() -> ServiceExitCode {
    // Refuse to collect alongside another instance.
    do {
      try self.instanceLock.acquire()
    } catch {
      switch error {
      case .alreadyRunning:
        self.report("another instance is already running.")
        return .alreadyRunning
      case .instanceLockUnavailable:
        self.report("the instance lock could not be acquired.")
        return .platformError
      }
    }
    defer { self.instanceLock.release() }

    // Read the control file. Only an unreadable schema stops the service.
    let configuration: ServiceConfiguration
    do {
      configuration = try self.configurationStore.load()
    } catch {
      switch error {
      case .unsupportedSchemaVersion(let version):
        self.report(
          "configuration schema_version \(version) is newer than the supported "
            + "version \(ServiceConfiguration.supportedSchemaVersion)."
        )
        return .configurationError
      }
    }

    // Nothing to collect is a successful run, not a failure.
    guard configuration.isCollecting else {
      self.debug("Tracking is disabled by configuration.")
      return .success
    }

    // Ask for the accessibility grant only once collection is certain, and
    // before the run loop takes over the main thread. Window and media titles
    // are unavailable without it.
    let accessibilityGranted = AccessibilityRequest.request()
    self.debug("Accessibility granted: \(accessibilityGranted)")

    // Sample on the configured period, and treat any longer interval as a break
    // in observation rather than elapsed foreground time.
    let pollPeriodSec = configuration.tracking.sampling.pollPeriodSec
    self.gapThresholdSec = max(3 * pollPeriodSec, 5)
    self.coordinator = self.makeCoordinator(configuration.trackingPolicy)

    self.signals.observe { [weak self] in
      self?.requestStop()
    }
    defer { self.signals.cancel() }

    self.debug("Starting service: pid=\(getpid()), pollPeriodSec=\(pollPeriodSec)")
    self.ticker.start(everySec: pollPeriodSec) { [weak self] in
      self?.tick()
    }
    self.ticker.run()

    return self.shutdown()
  }

  // Sample once. This is the only place that decides what a time interval means.
  private func tick() {
    guard let coordinator = self.coordinator else {
      return
    }

    let now = self.clock.wallUnixSec
    if let lastTickUnixSec, self.isDiscontinuous(from: lastTickUnixSec, to: now) {
      // The machine slept, the process stalled, or the clock was corrected.
      // Close the open sessions at the last time actually observed; anything
      // else would bill the gap as foreground activity.
      self.debug("Observation gap: lastTick=\(lastTickUnixSec), now=\(now)")
      do {
        try coordinator.shutdown(at: lastTickUnixSec)
      } catch {
        self.handle(error)
      }
    }
    self.lastTickUnixSec = now

    do {
      try coordinator.update(at: now)
      self.consecutiveFailures = 0
    } catch {
      self.handle(error)
    }
  }

  // Flush the open sessions and report the exit code.
  private func shutdown() -> ServiceExitCode {
    guard let coordinator = self.coordinator else {
      return self.exitCode
    }

    self.debug("Flushing trackers before shutdown.")
    do {
      try coordinator.shutdown(at: self.clock.wallUnixSec)
      self.debug("Shutdown complete.")
    } catch {
      self.report("Tracking shutdown failed: \(error)")
      return ServiceExitCode(error)
    }
    return self.exitCode
  }

  // Stop the run loop from a signal handler.
  private func requestStop() {
    self.debug("Received a stop signal.")
    self.ticker.stop()
  }

  // Apply the failure policy. A storage failure is fatal because every later
  // sample would be lost anyway; a probe failure is transient and must not turn
  // one denied permission into a per-second log.
  private func handle(_ error: TrackingError) {
    if error == .databaseRecordFailed {
      self.report("Tracking write failed: \(error)")
      self.exitCode = .databaseError
      self.ticker.stop()
      return
    }

    self.consecutiveFailures += 1
    if self.consecutiveFailures <= Self.failureReportLimit {
      self.report("Tracking update failed: \(error)")
      if self.consecutiveFailures == Self.failureReportLimit {
        self.report("Further tracking failures will not be reported.")
      }
    }
  }

  // Check whether the interval between two samples is longer than sampling
  // explains, or runs backward.
  private func isDiscontinuous(from lastUnixSec: Int64, to nowUnixSec: Int64) -> Bool {
    nowUnixSec < lastUnixSec || nowUnixSec - lastUnixSec > self.gapThresholdSec
  }

  // Report a message to standard error.
  private func report(_ message: String) {
    FileHandle.standardError.write(Data(("time-arc-service: " + message + "\n").utf8))
  }

  // Report a message to standard error in Debug builds.
  private func debug(_ message: @autoclosure () -> String) {
    #if TIMEARC_DEBUG
      self.report("[DEBUG] \(message())")
    #endif
  }
}
