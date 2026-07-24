// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The state of the media sessions, which can be active or shutdown.
enum MediaState: Equatable, Sendable {
  // Active media sessions with their start time.
  case active([MediaSession: Int64])

  // No active media sessions.
  case shutdown
}

// The state machine that tracks the media sessions and their active duration.
struct MediaStateMachine {
  // The current state of the media sessions.
  private(set) var state: MediaState

  // Initialize the state machine with no active media sessions.
  init() {
    self.state = .shutdown
  }

  // Initialize the state machine with the given media sessions and time.
  init(with sessions: Set<MediaSession>, at time: Int64) throws(TrackingError) {
    guard time > 0 else {
      throw TrackingError.timeValidationFailed
    }
    let data = Dictionary(uniqueKeysWithValues: sessions.map { ($0, time) })
    self.state = .active(data)
  }

  // Activate the state machine when it is shutdown.
  mutating func activate(with sessions: Set<MediaSession>, at time: Int64) throws(TrackingError) {
    _ = try self.refresh(with: sessions, at: time)
  }

  // Refresh the state machine when it is active.
  mutating func refresh(with sessions: Set<MediaSession>, at time: Int64)
    throws(TrackingError) -> [MediaRecord]?
  {
    if case .active(let data) = self.state {
      try self.validateTime(from: data, at: time)
      let currentSessions = Set(data.keys)
      let retiredSessions = currentSessions.subtracting(sessions)
      let newSessions = sessions.subtracting(currentSessions)
      var currentData = data.filter { !retiredSessions.contains($0.key) }
      let retiredData = data.filter { retiredSessions.contains($0.key) }
      let newData = Dictionary(uniqueKeysWithValues: newSessions.map { ($0, time) })
      currentData.merge(newData) { current, _ in current }
      self.transition(to: .active(currentData), at: time)
      return self.mapRecords(from: retiredData, at: time)
    } else {
      try self.validateTime(at: time)
      let data = Dictionary(uniqueKeysWithValues: sessions.map { ($0, time) })
      self.transition(to: .active(data), at: time)
      return nil
    }
  }

  // Shutdown the state machine when it is active.
  mutating func shutdown(at time: Int64) throws(TrackingError) -> [MediaRecord]? {
    if case .active(let data) = self.state {
      try self.validateTime(from: data, at: time)
      let records = self.mapRecords(from: data, at: time)
      self.transition(to: .shutdown, at: time)
      return records
    } else {
      try self.validateTime(at: time)
      return nil
    }
  }

  // Change state and report the transition in Debug builds.
  private mutating func transition(to newState: MediaState, at time: Int64) {
    let previousState = self.state
    self.state = newState
    guard previousState != newState else {
      return
    }

    #if TIMEARC_DEBUG
      let message =
        "[DEBUG] MediaStateMachine: unixSec=\(time), "
        + "\(Self.describe(previousState)) -> \(Self.describe(newState))\n"
      FileHandle.standardError.write(Data(message.utf8))
    #endif
  }

  #if TIMEARC_DEBUG
    // Describe the state and its sessions in a stable order.
    private static func describe(_ state: MediaState) -> String {
      switch state {
      case .active(let data):
        let sessions = data.keys.map { session in
          "\(session.app.id):\(session.mediaType.rawValue):"
            + "\(session.mediaTitle ?? "<nil>")"
        }.sorted().joined(separator: ", ")
        return "active(sessions=[\(sessions)])"
      case .shutdown:
        return "shutdown"
      }
    }
  #endif

  // Map the media sessions and their start times to media records with the given time.
  private func mapRecords(from data: [MediaSession: Int64], at time: Int64) -> [MediaRecord]? {
    var records = data.map { (session, startTime) in
      MediaRecord(
        app: session.app,
        mediaType: session.mediaType,
        mediaTitle: session.mediaTitle,
        startUnixSec: startTime,
        lastUpdateUnixSec: time
      )
    }
    records.removeAll { $0.startUnixSec >= time }
    records.sort { $0.startUnixSec < $1.startUnixSec }
    return records.isEmpty ? nil : records
  }

  // Validate that the given time is greater than zero.
  private func validateTime(at time: Int64) throws(TrackingError) {
    guard time > 0 else {
      throw TrackingError.timeValidationFailed
    }
  }

  // Validate that the given time is greater than zero and all the start times in the data.
  private func validateTime(from data: [MediaSession: Int64], at time: Int64) throws(TrackingError)
  {
    guard time > 0,
      data.values.allSatisfy({ $0 <= time })
    else {
      throw TrackingError.timeValidationFailed
    }
  }
}
