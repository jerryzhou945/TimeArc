// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

final class TrackingCoordinator {
  // State machines for frontmost and media sessions.
  private var frontmost: FrontmostStateMachine
  private var media: MediaStateMachine

  // The collection policy resolved from the control file.
  private let policy: TrackingPolicy

  // Probes for frontmost and media session information.
  private let frontmostAppProbe: any FrontmostAppProbing
  private let appInformationProbe: any AppInformationProbing
  private let windowTitleProbe: any WindowTitleProbing
  private let audioTitleProbe: any AudioTitleProbing
  private let inputActionProbe: any InputActionProbing
  private let sleepAssertionProbe: any SleepAssertionProbing
  private let audioProcessProbe: any AudioProcessProbing
  private let dataBridge: any DataBridging

  // Initialize the tracking coordinator with the necessary probes and initial state.
  init(
    policy: TrackingPolicy,
    frontmostAppProbe: any FrontmostAppProbing = ApplicationProbe(),
    appInformationProbe: any AppInformationProbing = ApplicationProbe(),
    windowTitleProbe: any WindowTitleProbing = TitleProbe(),
    audioTitleProbe: any AudioTitleProbing = TitleProbe(),
    inputActionProbe: any InputActionProbing = InputActionProbe(),
    sleepAssertionProbe: any SleepAssertionProbing = SleepAssertionProbe(),
    audioProcessProbe: any AudioProcessProbing = AudioProcessProbe(),
    dataBridge: any DataBridging = DataBridge()
  ) {
    // Set the collection policy.
    self.policy = policy

    // Set the probes and data bridge.
    self.frontmostAppProbe = frontmostAppProbe
    self.appInformationProbe = appInformationProbe
    self.windowTitleProbe = windowTitleProbe
    self.audioTitleProbe = audioTitleProbe
    self.inputActionProbe = inputActionProbe
    self.sleepAssertionProbe = sleepAssertionProbe
    self.audioProcessProbe = audioProcessProbe
    self.dataBridge = dataBridge

    // Initialize the state machines for frontmost and media sessions.
    self.frontmost = FrontmostStateMachine()
    self.media = MediaStateMachine()
  }

  // Update the tracking state and write the records to the database.
  func update(at time: Int64) throws(TrackingError) {
    var assertions: [Int32: SleepAssertionType]?
    if self.policy.enableFrontmost || self.policy.enableMedia {
      assertions = try self.sleepAssertionProbe.getSleepAssertions()
    }
    if self.policy.enableFrontmost {
      try self.updateFrontmost(with: assertions, at: time)
    }
    if self.policy.enableMedia {
      try self.updateMedia(with: assertions, at: time)
    }
  }

  // Shutdown the tracking coordinator and write any remaining records to the database.
  func shutdown(at time: Int64) throws(TrackingError) {
    if self.policy.enableFrontmost, let record = try self.frontmost.shutdown(at: time) {
      try self.bridge(record)
    }
    if self.policy.enableMedia, let records = try self.media.shutdown(at: time) {
      for record in records {
        try self.bridge(record)
      }
    }
  }

  // Update the frontmost state machine and write the frontmost record to the database.
  private func updateFrontmost(with assertions: [Int32: SleepAssertionType]?, at time: Int64)
    throws(TrackingError)
  {
    // Get the frontmost session information from the probe.
    guard let frontmostSession = try self.getFrontmostSession() else {
      // Shutdown the frontmost state machine if there is no frontmost session.
      guard let record = try self.frontmost.shutdown(at: time) else {
        return
      }
      try self.bridge(record)
      return
    }

    // Update the frontmost state machine based on the current state and the new session information.
    switch self.frontmost.state {
    case .active(let data):
      // Check if the new frontmost app information matches the current record.
      if self.isSame(frontmostSession, data) {
        // Flush the open record when it reaches the configured maximum length.
        // Refreshing with the same session keeps the identity and restarts the
        // record at this time, so the written rows stay contiguous.
        if self.hasReachedMaximum(from: data.startUnixSec, at: time),
          let record = try self.frontmost.refresh(with: frontmostSession, at: time)
        {
          try self.bridge(record, enforcingMinimum: false)
        }

        if self.isIdle(try self.getIdleTime(from: assertions, for: frontmostSession.app.pid)) {
          try self.frontmost.idle(at: time)
        }
        return
      }

      // Refresh the frontmost state machine with the new session information.
      guard let record = try self.frontmost.refresh(with: frontmostSession, at: time) else {
        return
      }
      try self.bridge(record)
    case .idle(let data):
      // Check if the new frontmost app information matches the current record.
      if self.isSame(frontmostSession, data) {
        // Flush the open record when it reaches the configured maximum length.
        // Refreshing reactivates the session, so mark it idle again at the same
        // time, which accumulates no active seconds.
        if self.hasReachedMaximum(from: data.startUnixSec, at: time),
          let record = try self.frontmost.refresh(with: frontmostSession, at: time)
        {
          try self.bridge(record, enforcingMinimum: false)
          try self.frontmost.idle(at: time)
        }

        if !self.isIdle(try self.getIdleTime(from: assertions, for: frontmostSession.app.pid)) {
          try self.frontmost.reactivate(at: time)
        }
        return
      }

      // Refresh the frontmost state machine with the new session information.
      guard let record = try self.frontmost.refresh(with: frontmostSession, at: time) else {
        return
      }
      try self.bridge(record)
    default:
      // Activate the frontmost state machine with the new session information.
      try self.frontmost.activate(with: frontmostSession, at: time)
    }
  }

  // Update the media state machine and write the media records to the database.
  private func updateMedia(with assertions: [Int32: SleepAssertionType]?, at time: Int64)
    throws(TrackingError)
  {
    // Get the media session information from the probe.
    guard let mediaSessions = try self.getMediaSession(from: assertions) else {
      // Shutdown the media state machine if there are no media sessions.
      guard let records = try self.media.shutdown(at: time) else {
        return
      }
      for record in records {
        try self.bridge(record)
      }
      return
    }

    // Update the media state machine based on the current state and the new session information.
    if case .active(let data) = self.media.state {
      // Flush every open record that reached the configured maximum length by
      // retiring those sessions; the refresh below re-adds them at this time,
      // so their identity is unchanged and the written rows stay contiguous.
      let matured = Set(data.filter { self.hasReachedMaximum(from: $0.value, at: time) }.keys)
      if !matured.isEmpty,
        let records = try self.media.refresh(
          with: Set(data.keys).subtracting(matured),
          at: time
        )
      {
        for record in records {
          try self.bridge(record, enforcingMinimum: false)
        }
      }

      // Refresh the media state machine with the new session information.
      guard let records = try self.media.refresh(with: mediaSessions, at: time) else {
        return
      }
      for record in records {
        try self.bridge(record)
      }
    } else {
      // Activate the media state machine with the new session information.
      try self.media.activate(with: mediaSessions, at: time)
    }
  }

  // Write a frontmost record unless it is shorter than the configured minimum.
  private func bridge(_ record: FrontmostRecord, enforcingMinimum: Bool = true)
    throws(TrackingError)
  {
    guard self.isLongEnough(record.lastUpdateUnixSec - record.startUnixSec, enforcingMinimum)
    else {
      return
    }
    try self.dataBridge.bridgeFrontmostRecord(record)
  }

  // Write a media record unless it is shorter than the configured minimum.
  private func bridge(_ record: MediaRecord, enforcingMinimum: Bool = true) throws(TrackingError) {
    guard self.isLongEnough(record.lastUpdateUnixSec - record.startUnixSec, enforcingMinimum)
    else {
      return
    }
    try self.dataBridge.bridgeMediaRecord(record)
  }

  // Check whether a record is long enough to be written. Records flushed at the
  // configured maximum length are always written.
  private func isLongEnough(_ durationSec: Int64, _ enforcingMinimum: Bool) -> Bool {
    !enforcingMinimum || durationSec >= self.policy.minSessionSec
  }

  // Check whether an open record has reached the configured maximum length.
  private func hasReachedMaximum(from startUnixSec: Int64, at time: Int64) -> Bool {
    self.policy.maxSessionSec > 0 && time - startUnixSec >= self.policy.maxSessionSec
  }

  // Compare the frontmost session with the active record.
  private func isSame(_ session: FrontmostSession, _ record: FrontmostRecord) -> Bool {
    session.app == record.app && session.windowTitle == record.windowTitle
  }

  // Check if the current time exceeds the idle threshold. A threshold of zero
  // disables idle detection.
  private func isIdle(_ time: Int64) -> Bool {
    self.policy.idleThresholdSec > 0 && time >= self.policy.idleThresholdSec
  }

  // Get the frontmost session.
  private func getFrontmostSession() throws(TrackingError) -> FrontmostSession? {
    // Get the frontmost app information.
    guard let app = try self.frontmostAppProbe.getFrontmostApp() else {
      return nil
    }

    // Get the window title for the frontmost app.
    let windowTitle = try self.windowTitleProbe.getWindowTitle(for: app.pid)

    // Return the frontmost session with the app information and window title.
    return FrontmostSession(app: app, windowTitle: windowTitle)
  }

  // Get the media sessions.
  private func getMediaSession(from assertions: [Int32: SleepAssertionType]?)
    throws(TrackingError) -> Set<MediaSession>?
  {
    // Get the audio processes.
    guard let assertions,
      let processes = try self.audioProcessProbe.getAudioProcesses()
    else {
      return nil
    }

    // Check the sleep assertions for the audio processes and determine the media type and title.
    var mediaSessions: Set<MediaSession> = []
    var mediaType: MediaType
    var mediaTitle: String?
    for pid in processes {
      // Get the sleep assertion for the process.
      guard let assertion = assertions[pid] else {
        continue
      }

      // Determine the media type and title based on the sleep assertion.
      switch assertion {
      case .background:
        mediaType = .audio
        mediaTitle = try self.audioTitleProbe.getAudioTitle(for: pid)
      case .foreground:
        mediaType = .video
        mediaTitle = try self.windowTitleProbe.getWindowTitle(for: pid)
      default:
        continue
      }

      // Get the app information for the process.
      guard let app = try self.appInformationProbe.getAppInformation(for: pid) else {
        continue
      }

      // Add the media session to the set of media sessions.
      mediaSessions.insert(MediaSession(app: app, mediaType: mediaType, mediaTitle: mediaTitle))
    }

    // Return nil if there are no media sessions, otherwise return the set of media sessions.
    return mediaSessions.isEmpty ? nil : mediaSessions
  }

  // Get the idle time for the given PID. Foreground playback counts as activity
  // only when the policy allows video to override input idle.
  private func getIdleTime(from assertions: [Int32: SleepAssertionType]?, for pid: Int32)
    throws(TrackingError) -> Int64
  {
    if self.policy.videoOverridesIdle, let assertions, assertions[pid] == .foreground {
      return 0
    } else {
      return try self.inputActionProbe.getSecondsSinceLastInput()
    }
  }
}
