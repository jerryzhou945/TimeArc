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
  init(with sessions: Set<MediaSession>, at time: Int64) {
    let data = Dictionary(uniqueKeysWithValues: sessions.map { ($0, time) })
    self.state = .active(data)
  }

  // Activate the state machine when it is shutdown.
  mutating func activate(with sessions: Set<MediaSession>, at time: Int64) {
    _ = self.refresh(with: sessions, at: time)
  }

  // Refresh the state machine when it is active.
  mutating func refresh(with sessions: Set<MediaSession>, at time: Int64) -> [MediaRecord]? {
    if case .active(let data) = self.state {
      let currentSessions = Set(data.keys)
      let retiredSessions = currentSessions.subtracting(sessions)
      let newSessions = sessions.subtracting(currentSessions)
      var currentData = data.filter { !retiredSessions.contains($0.key) }
      let retiredData = data.filter { retiredSessions.contains($0.key) }
      let newData = Dictionary(uniqueKeysWithValues: newSessions.map { ($0, time) })
      currentData.merge(newData) { $0 }
      self.state = .active(currentData)
      return self.mapRecords(from: retiredData, at: time)
    } else {
      let data = Dictionary(uniqueKeysWithValues: sessions.map { ($0, time) })
      self.state = .active(data)
      return nil
    }
  }

  // Shutdown the state machine when it is active.
  mutating func shutdown(at time: Int64) -> [MediaRecord]? {
    if case .active(let data) = self.state {
      let records = self.mapRecords(from: data, at: time)
      self.state = .shutdown
      return records
    } else {
      return nil
    }
  }

  // Map the media sessions and their start times to media records with the given time.
  private func mapRecords(from data: [MediaSession: Int64], at time: Int64) -> [MediaRecord]? {
    let mapData = data.filter { $0.value < time }
    let records = mapData.map { (session, startTime) in
      MediaRecord(
        app: session.app,
        mediaType: session.mediaType,
        mediaTitle: session.mediaTitle,
        startUnixSec: startTime,
        lastUpdateUnixSec: time
      )
    }
    records.sort { $0.startUnixSec < $1.startUnixSec }
    return records.isEmpty ? nil : records
  }
}
