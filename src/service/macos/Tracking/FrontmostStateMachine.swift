// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The state of the frontmost app, which can be active, idle or shutdown.
enum FrontmostState: Equatable, Sendable {
  // The frontmost app is actively being used by the user.
  case active(FrontmostRecord)

  // The frontmost app is idle due to user inactivity.
  case idle(FrontmostRecord)

  // No active frontmost app.
  case shutdown
}

// The state machine that tracks the frontmost app and its active duration.
struct FrontmostStateMachine {
  // The current state of the frontmost app.
  private(set) var state: FrontmostState

  // Initialize the state machine with no active frontmost app.
  init() {
    self.state = .shutdown
  }

  // Initialize the state machine with the given frontmost session and time.
  init(with session: FrontmostSession, at time: Int64) {
    let data = FrontmostRecord(
      app: session.app,
      windowTitle: session.windowTitle,
      startUnixSec: time,
      activeSec: 0,
      lastUpdateUnixSec: time
    )
    self.state = .active(data)
  }

  // Activate the state machine when it is shutdown.
  mutating func activate(with session: FrontmostSession, at time: Int64) {
    _ = self.refresh(with: session, at: time)
  }

  // Reactivate the state machine when it is idle.
  mutating func reactivate(at time: Int64) {
    let updatedData = self.updatedRecord(at: time)
    guard let updatedData else {
      return
    }
    self.state = .active(updatedData)
  }

  // Refresh the state machine when it is active.
  mutating func refresh(with session: FrontmostSession, at time: Int64) -> FrontmostRecord? {
    let previousData = self.updatedRecord(at: time)
    let updatedData = FrontmostRecord(
      app: session.app,
      windowTitle: session.windowTitle,
      startUnixSec: time,
      activeSec: 0,
      lastUpdateUnixSec: time
    )
    self.state = .active(updatedData)
    return previousData
  }

  // Mark the state machine as idle when it is active.
  mutating func idle(at time: Int64) {
    let updatedData = self.updatedRecord(at: time)
    guard let updatedData else {
      return
    }
    self.state = .idle(updatedData)
  }

  // Shutdown the state machine when it is active or idle.
  mutating func shutdown(at time: Int64) -> FrontmostRecord? {
    let previousData = self.updatedRecord(at: time)
    self.state = .shutdown
    return previousData
  }

  // Get the updated frontmost record with the given time.
  private func updatedRecord(at time: Int64) -> FrontmostRecord? {
    switch self.state {
    case .active(let data):
      guard data.startUnixSec < time else {
        return nil
      }
      return FrontmostRecord(
        app: data.app,
        windowTitle: data.windowTitle,
        startUnixSec: data.startUnixSec,
        activeSec: data.activeSec + (time - data.lastUpdateUnixSec),
        lastUpdateUnixSec: time
      )
    case .idle(let data):
      guard data.startUnixSec < time else {
        return nil
      }
      return FrontmostRecord(
        app: data.app,
        windowTitle: data.windowTitle,
        startUnixSec: data.startUnixSec,
        activeSec: data.activeSec,
        lastUpdateUnixSec: time
      )
    default:
      return nil
    }
  }
}
