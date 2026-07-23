// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Dispatch
import Foundation

@main
struct TimeArcService {
  static func main() {
    let coordinator = TrackingCoordinator(
      idleThreshold: 60,
      enableFrontmost: true,
      enableMedia: true
    )
    let stopRequested = DispatchSemaphore(value: 0)

    Darwin.signal(SIGINT, SIG_IGN)
    Darwin.signal(SIGTERM, SIG_IGN)

    let interruptSource = DispatchSource.makeSignalSource(
      signal: SIGINT,
      queue: .global()
    )
    let terminateSource = DispatchSource.makeSignalSource(
      signal: SIGTERM,
      queue: .global()
    )

    interruptSource.setEventHandler {
      stopRequested.signal()
    }
    terminateSource.setEventHandler {
      stopRequested.signal()
    }

    interruptSource.activate()
    terminateSource.activate()

    defer {
      interruptSource.cancel()
      terminateSource.cancel()
    }

    let pollIntervalNanoseconds = UInt64(NSEC_PER_SEC)
    var nextPollNanoseconds = DispatchTime.now().uptimeNanoseconds

    while true {
      let deadline = DispatchTime(uptimeNanoseconds: nextPollNanoseconds)
      if stopRequested.wait(timeout: deadline) == .success {
        break
      }

      do {
        try coordinator.update(at: Int64(Date().timeIntervalSince1970))
      } catch {
        report("Tracking update failed: \(error)")
      }

      nextPollNanoseconds += pollIntervalNanoseconds
      let currentNanoseconds = DispatchTime.now().uptimeNanoseconds
      if nextPollNanoseconds <= currentNanoseconds {
        let missedIntervals =
          (currentNanoseconds - nextPollNanoseconds) / pollIntervalNanoseconds + 1
        nextPollNanoseconds += missedIntervals * pollIntervalNanoseconds
      }
    }

    do {
      try coordinator.shutdown(at: Int64(Date().timeIntervalSince1970))
    } catch {
      report("Tracking shutdown failed: \(error)")
      exit(EXIT_FAILURE)
    }
  }

  private static func report(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }
}
