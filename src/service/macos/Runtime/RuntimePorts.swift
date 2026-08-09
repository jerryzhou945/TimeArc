// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The error types for the service runtime.
enum RuntimeError: Error, Equatable, Sendable {
  // Another instance already holds the single-instance lock.
  case alreadyRunning

  // The lock file could not be created or locked for an unrelated reason.
  case instanceLockUnavailable
}

// Read the current time. Records store wall time, and comparing consecutive
// samples of it is what reveals a sleep, a stall, or a corrected clock: a
// monotonic clock cannot, because on Darwin it stops advancing during sleep.
protocol Clocking {
  var wallUnixSec: Int64 { get }
}

// Schedule repeated work on the main run loop and block until it stops.
protocol Ticking {
  func start(everySec periodSec: Int64, _ tick: @escaping () -> Void)
  func run()
  func stop()
}

// Observe the stop signals delivered to the process.
protocol SignalObserving {
  func observe(_ onStop: @escaping () -> Void)
  func cancel()
}

// Guarantee that only one service instance collects at a time.
protocol InstanceLocking {
  func acquire() throws(RuntimeError)
  func release()
}
