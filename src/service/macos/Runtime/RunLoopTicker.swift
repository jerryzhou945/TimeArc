// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Drive the sampling loop from the main run loop, which the accessibility and
// workspace probes require.
final class RunLoopTicker: Ticking {
  // The repeating timer, retained so it can be invalidated on stop.
  private var timer: Timer?

  // Whether a stop was already requested. The first sample runs before the loop
  // starts, so it can fail fatally and stop the ticker before run() is reached.
  private var isStopped = false

  // Start sampling immediately and then once per period.
  func start(everySec periodSec: Int64, _ tick: @escaping () -> Void) {
    let timer = Timer(timeInterval: TimeInterval(periodSec), repeats: true) { _ in
      tick()
    }
    timer.tolerance = 0
    RunLoop.main.add(timer, forMode: .common)
    timer.fire()
    self.timer = timer
  }

  // Block on the main run loop until stop is requested.
  func run() {
    guard !self.isStopped else {
      return
    }
    CFRunLoopRun()
  }

  // Stop sampling and let run() return.
  func stop() {
    self.isStopped = true
    self.timer?.invalidate()
    self.timer = nil
    CFRunLoopStop(CFRunLoopGetMain())
  }
}
