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

// Probe the frontmost app information.
protocol FrontmostAppProbing {
  func getFrontmostApp() -> AppInformation?
}

// Probe the app information for a given PID.
protocol AppInformationProbing {
  func getAppInformation(for pid: Int32) -> AppInformation?
}

// Probe the window title for a given PID.
protocol WindowTitleProbing {
  func getWindowTitle(for pid: Int32) -> String?
}

// Probe the audio title for a given PID.
protocol AudioTitleProbing {
  func getAudioTitle(for pid: Int32) -> String?
}

// Probe the seconds since last input.
protocol InputActionProbing {
  func getSecondsSinceLastInput() -> Int64
}

// Probe the sleep assertions for the system.
protocol SleepAssertionProbing {
  func getSleepAssertions() -> [Int32: SleepAssertionType]?
}

// Probe the audio processes for the system.
protocol AudioProcessProbing {
  func getAudioProcesses() -> Set<Int32>?
}

// Bridge the records to SQLite database.
protocol DataBridging {
  func bridgeFrontmostRecord(_ record: FrontmostRecord)
  func bridgeMediaRecord(_ record: MediaRecord)
}
