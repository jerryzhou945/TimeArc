// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Dispatch
import Foundation

// Run the tracking loop in the foreground until a stop signal arrives.
struct RunCommand {
  // The seconds without input after which a frontmost session becomes idle.
  private static let idleThreshold: Int64 = 60

  // The seconds between tracking samples.
  private static let pollInterval: TimeInterval = 1

  // Execute the run command and report the process exit code.
  func execute() -> ServiceExitCode {
    let accessibilityGranted = AccessibilityRequest.request()
    self.debug(
      "Starting service: pid=\(getpid()), "
        + "accessibilityGranted=\(accessibilityGranted)"
    )

    let coordinator = TrackingCoordinator(
      idleThreshold: Self.idleThreshold,
      enableFrontmost: true,
      enableMedia: true
    )

    // Handle the stop signals on the main queue instead of the default disposition.
    Darwin.signal(SIGINT, SIG_IGN)
    Darwin.signal(SIGTERM, SIG_IGN)

    let interruptSource = DispatchSource.makeSignalSource(
      signal: SIGINT,
      queue: .main
    )
    let terminateSource = DispatchSource.makeSignalSource(
      signal: SIGTERM,
      queue: .main
    )

    interruptSource.setEventHandler {
      self.debug("Received SIGINT.")
      CFRunLoopStop(CFRunLoopGetMain())
    }
    terminateSource.setEventHandler {
      self.debug("Received SIGTERM.")
      CFRunLoopStop(CFRunLoopGetMain())
    }

    interruptSource.activate()
    terminateSource.activate()

    defer {
      interruptSource.cancel()
      terminateSource.cancel()
    }

    // Sample immediately, then once per poll interval until the run loop stops.
    let pollTimer = Timer(timeInterval: Self.pollInterval, repeats: true) { _ in
      let pollUnixSec = Int64(Date().timeIntervalSince1970)
      self.debug("Polling trackers: unixSec=\(pollUnixSec)")
      do {
        try coordinator.update(at: pollUnixSec)
      } catch {
        self.report("Tracking update failed: \(error)")
      }
    }
    pollTimer.tolerance = 0
    RunLoop.main.add(pollTimer, forMode: .common)
    pollTimer.fire()
    CFRunLoopRun()
    pollTimer.invalidate()

    // Write the sessions that are still open before the process exits.
    self.debug("Flushing trackers before shutdown.")
    do {
      try coordinator.shutdown(at: Int64(Date().timeIntervalSince1970))
      self.debug("Shutdown complete.")
      return .success
    } catch {
      self.report("Tracking shutdown failed: \(error)")
      return ServiceExitCode(error)
    }
  }

  // Report a message to standard error.
  private func report(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }

  // Report a message to standard error in Debug builds.
  private func debug(_ message: @autoclosure () -> String) {
    #if TIMEARC_DEBUG
      self.report("[DEBUG] \(message())")
    #endif
  }
}
