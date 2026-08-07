// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The type of media, which can be audio or video.
enum MediaType: String, Equatable, Sendable {
  case audio
  case video
}

// The type of sleep assertion, which can be system, foreground, or background.
enum SleepAssertionType: String, Equatable, Sendable {
  case system
  case foreground
  case background
}

// The collection policy that drives the tracking coordinator. The configuration
// layer maps the control file onto this type; tracking never reads the file.
struct TrackingPolicy: Equatable, Sendable {
  // Whether frontmost app tracking is enabled.
  let enableFrontmost: Bool

  // Whether media tracking is enabled.
  let enableMedia: Bool

  // The seconds without input after which a frontmost session becomes idle.
  // Zero disables idle detection.
  let idleThresholdSec: Int64

  // Whether video-like foreground playback keeps a session active while input is idle.
  let videoOverridesIdle: Bool

  // Records shorter than this many seconds are not written.
  let minSessionSec: Int64

  // When an open record reaches this many seconds it is written and a new one
  // starts. Zero leaves record length uncapped.
  let maxSessionSec: Int64

  // Initialize the policy with the documented defaults.
  init(
    enableFrontmost: Bool = true,
    enableMedia: Bool = true,
    idleThresholdSec: Int64 = 60,
    videoOverridesIdle: Bool = true,
    minSessionSec: Int64 = 1,
    maxSessionSec: Int64 = 300
  ) {
    self.enableFrontmost = enableFrontmost
    self.enableMedia = enableMedia
    self.idleThresholdSec = idleThresholdSec
    self.videoOverridesIdle = videoOverridesIdle
    self.minSessionSec = minSessionSec
    self.maxSessionSec = maxSessionSec
  }
}

// Information about an app.
struct AppInformation: Equatable, Sendable, Hashable {
  let pid: Int32
  let id: String
  let name: String
  let path: String
}

// Information about a frontmost session.
struct FrontmostSession: Equatable, Sendable, Hashable {
  let app: AppInformation
  let windowTitle: String?
}

// Information about a frontmost record.
struct FrontmostRecord: Equatable, Sendable, Hashable {
  let app: AppInformation
  let windowTitle: String?
  let startUnixSec: Int64
  let activeSec: Int64
  let lastUpdateUnixSec: Int64
}

// Information about a media session.
struct MediaSession: Equatable, Sendable, Hashable {
  let app: AppInformation
  let mediaType: MediaType
  let mediaTitle: String?
}

// Information about a media record.
struct MediaRecord: Equatable, Sendable, Hashable {
  let app: AppInformation
  let mediaType: MediaType
  let mediaTitle: String?
  let startUnixSec: Int64
  let lastUpdateUnixSec: Int64
}

// The error types for tracking.
enum TrackingError: Error, Equatable, Sendable {
  case appInformationUnavailable
  case accessibilityTitleUnavailable
  case eventInputUnavailable
  case powerAssertionUnavailable
  case audioProcessUnavailable
  case databaseRecordFailed
  case timeValidationFailed
}

// Probe the frontmost app information.
protocol FrontmostAppProbing {
  func getFrontmostApp() throws(TrackingError) -> AppInformation?
}

// Probe the app information for a given PID.
protocol AppInformationProbing {
  func getAppInformation(for pid: Int32) throws(TrackingError) -> AppInformation?
}

// Probe the window title for a given PID.
protocol WindowTitleProbing {
  func getWindowTitle(for pid: Int32) throws(TrackingError) -> String?
}

// Probe the audio title for a given PID.
protocol AudioTitleProbing {
  func getAudioTitle(for pid: Int32) throws(TrackingError) -> String?
}

// Probe the seconds since last input.
protocol InputActionProbing {
  func getSecondsSinceLastInput() throws(TrackingError) -> Int64
}

// Probe the sleep assertions for the system.
protocol SleepAssertionProbing {
  func getSleepAssertions() throws(TrackingError) -> [Int32: SleepAssertionType]?
}

// Probe the audio processes for the system.
protocol AudioProcessProbing {
  func getAudioProcesses() throws(TrackingError) -> Set<Int32>?
}

// Bridge the records to SQLite database.
protocol DataBridging {
  func bridgeFrontmostRecord(_ record: FrontmostRecord) throws(TrackingError)
  func bridgeMediaRecord(_ record: MediaRecord) throws(TrackingError)
}
