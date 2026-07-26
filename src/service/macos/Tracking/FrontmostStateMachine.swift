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
  init(with session: FrontmostSession, at time: Int64) throws(TrackingError) {
    guard time > 0 else {
      throw TrackingError.timeValidationFailed
    }
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
  mutating func activate(with session: FrontmostSession, at time: Int64) throws(TrackingError) {
    _ = try self.refresh(with: session, at: time)
  }

  // Reactivate the state machine when it is idle.
  mutating func reactivate(at time: Int64) throws(TrackingError) {
    let updatedData = try self.updatedRecord(at: time)
    guard let updatedData else {
      return
    }
    self.transition(to: .active(updatedData), at: time)
  }

  // Refresh the state machine when it is active.
  mutating func refresh(with session: FrontmostSession, at time: Int64)
    throws(TrackingError) -> FrontmostRecord?
  {
    let previousData = try self.updatedRecord(at: time)
    let updatedData = FrontmostRecord(
      app: session.app,
      windowTitle: session.windowTitle,
      startUnixSec: time,
      activeSec: 0,
      lastUpdateUnixSec: time
    )
    self.transition(to: .active(updatedData), at: time)
    guard let previousData else {
      return nil
    }
    return previousData.startUnixSec >= time ? nil : previousData
  }

  // Mark the state machine as idle when it is active.
  mutating func idle(at time: Int64) throws(TrackingError) {
    let updatedData = try self.updatedRecord(at: time)
    guard let updatedData else {
      return
    }
    self.transition(to: .idle(updatedData), at: time)
  }

  // Shutdown the state machine when it is active or idle.
  mutating func shutdown(at time: Int64) throws(TrackingError) -> FrontmostRecord? {
    let previousData = try self.updatedRecord(at: time)
    self.transition(to: .shutdown, at: time)
    guard let previousData else {
      return nil
    }
    return previousData.startUnixSec >= time ? nil : previousData
  }

  // Change state and report the transition in Debug builds.
  private mutating func transition(to newState: FrontmostState, at time: Int64) {
    let previousState = self.state
    self.state = newState
    guard previousState != newState else {
      return
    }

    #if TIMEARC_DEBUG
      let message =
        "[DEBUG] FrontmostStateMachine: unixSec=\(time), "
        + "\(Self.describe(previousState)) -> \(Self.describe(newState))\n"
      FileHandle.standardError.write(Data(message.utf8))
    #endif
  }

  #if TIMEARC_DEBUG
    // Describe the state without including duration bookkeeping details.
    private static func describe(_ state: FrontmostState) -> String {
      switch state {
      case .active(let data):
        return
          "active(appId=\(data.app.id), windowTitle=\(data.windowTitle ?? "<nil>"))"
      case .idle(let data):
        return
          "idle(appId=\(data.app.id), windowTitle=\(data.windowTitle ?? "<nil>"))"
      case .shutdown:
        return "shutdown"
      }
    }
  #endif

  // Get the updated frontmost record with the given time.
  private func updatedRecord(at time: Int64) throws(TrackingError) -> FrontmostRecord? {
    switch self.state {
    case .active(let data):
      try self.validateTime(from: data, at: time)
      return FrontmostRecord(
        app: data.app,
        windowTitle: data.windowTitle,
        startUnixSec: data.startUnixSec,
        activeSec: data.activeSec + (time - data.lastUpdateUnixSec),
        lastUpdateUnixSec: time
      )
    case .idle(let data):
      try self.validateTime(from: data, at: time)
      return FrontmostRecord(
        app: data.app,
        windowTitle: data.windowTitle,
        startUnixSec: data.startUnixSec,
        activeSec: data.activeSec,
        lastUpdateUnixSec: time
      )
    default:
      try self.validateTime(at: time)
      return nil
    }
  }

  // Validate that the given time is greater than zero.
  private func validateTime(at time: Int64) throws(TrackingError) {
    guard time > 0 else {
      throw TrackingError.timeValidationFailed
    }
  }

  // Validate that the given time is greater than zero and the last update time of the frontmost record.
  private func validateTime(from data: FrontmostRecord, at time: Int64) throws(TrackingError) {
    guard time > 0,
      data.startUnixSec <= time,
      data.lastUpdateUnixSec <= time
    else {
      throw TrackingError.timeValidationFailed
    }
  }
}
