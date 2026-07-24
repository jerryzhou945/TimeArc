// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Dispatch
import Foundation

@main
struct TimeArcService {
  static func main() {
    let accessibilityGranted = AccessibilityRequest.request()
    debug(
      "Starting service: pid=\(getpid()), "
        + "accessibilityGranted=\(accessibilityGranted)"
    )

    let coordinator = TrackingCoordinator(
      idleThreshold: 60,
      enableFrontmost: true,
      enableMedia: true
    )

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
      debug("Received SIGINT.")
      CFRunLoopStop(CFRunLoopGetMain())
    }
    terminateSource.setEventHandler {
      debug("Received SIGTERM.")
      CFRunLoopStop(CFRunLoopGetMain())
    }

    interruptSource.activate()
    terminateSource.activate()

    defer {
      interruptSource.cancel()
      terminateSource.cancel()
    }

    let pollTimer = Timer(timeInterval: 1, repeats: true) { _ in
      let pollUnixSec = Int64(Date().timeIntervalSince1970)
      debug("Polling trackers: unixSec=\(pollUnixSec)")
      do {
        try coordinator.update(at: pollUnixSec)
      } catch {
        report("Tracking update failed: \(error)")
      }
    }
    pollTimer.tolerance = 0
    RunLoop.main.add(pollTimer, forMode: .common)
    pollTimer.fire()
    CFRunLoopRun()
    pollTimer.invalidate()

    debug("Flushing trackers before shutdown.")
    do {
      try coordinator.shutdown(at: Int64(Date().timeIntervalSince1970))
      debug("Shutdown complete.")
    } catch {
      report("Tracking shutdown failed: \(error)")
      exit(EXIT_FAILURE)
    }
  }

  private static func report(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }

  private static func debug(_ message: @autoclosure () -> String) {
    #if TIMEARC_DEBUG
      report("[DEBUG] \(message())")
    #endif
  }
}
