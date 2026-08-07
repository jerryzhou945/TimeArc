// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The sampling settings documented in src/service/README.md.
struct SamplingConfiguration: Equatable, Sendable {
  // Sampling period for tracking information, in seconds.
  let pollPeriodSec: Int64

  // Records shorter than this many seconds are not written.
  let minSessionSec: Int64

  // When an open record reaches this many seconds it is written and a new one
  // starts. Zero means uncapped.
  let maxSessionSec: Int64

  // Initialize the sampling settings with the documented defaults.
  init(pollPeriodSec: Int64 = 1, minSessionSec: Int64 = 1, maxSessionSec: Int64 = 300) {
    self.pollPeriodSec = pollPeriodSec
    self.minSessionSec = minSessionSec
    self.maxSessionSec = maxSessionSec
  }
}

// The frontmost app tracking settings.
struct FrontmostConfiguration: Equatable, Sendable {
  // Whether frontmost app tracking is enabled.
  let enabled: Bool

  // The idle threshold in seconds. Zero disables idle detection.
  let idleThresholdSec: Int64

  // Whether video-like foreground playback keeps a session active while input is idle.
  let videoOverridesIdle: Bool

  // Initialize the frontmost settings with the documented defaults.
  init(enabled: Bool = true, idleThresholdSec: Int64 = 60, videoOverridesIdle: Bool = true) {
    self.enabled = enabled
    self.idleThresholdSec = idleThresholdSec
    self.videoOverridesIdle = videoOverridesIdle
  }
}

// The media tracking settings.
struct MediaConfiguration: Equatable, Sendable {
  // Whether media tracking is enabled.
  let enabled: Bool

  // Initialize the media settings with the documented defaults.
  init(enabled: Bool = true) {
    self.enabled = enabled
  }
}

// The tracking section of the control file.
struct TrackingConfiguration: Equatable, Sendable {
  // Whether tracking is enabled at all.
  let enabled: Bool

  // The sampling settings.
  let sampling: SamplingConfiguration

  // The frontmost app tracking settings.
  let frontmost: FrontmostConfiguration

  // The media tracking settings.
  let media: MediaConfiguration

  // Initialize the tracking settings with the documented defaults.
  init(
    enabled: Bool = true,
    sampling: SamplingConfiguration = SamplingConfiguration(),
    frontmost: FrontmostConfiguration = FrontmostConfiguration(),
    media: MediaConfiguration = MediaConfiguration()
  ) {
    self.enabled = enabled
    self.sampling = sampling
    self.frontmost = frontmost
    self.media = media
  }
}

// The service configuration read from the control file. The database directory
// is deliberately absent: the database path is resolved by the shared C
// resolver, and a second Swift copy of that logic would let the two processes
// disagree about where history lives.
struct ServiceConfiguration: Equatable, Sendable {
  // The schema version supported by this build.
  static let supportedSchemaVersion: Int64 = 1

  // The tracking settings.
  let tracking: TrackingConfiguration

  // Initialize the configuration with the documented defaults.
  init(tracking: TrackingConfiguration = TrackingConfiguration()) {
    self.tracking = tracking
  }

  // Whether any tracking work is requested. The run command exits successfully
  // when nothing would be collected.
  var isCollecting: Bool {
    self.tracking.enabled && (self.tracking.frontmost.enabled || self.tracking.media.enabled)
  }

  // The collection policy handed to the tracking coordinator.
  var trackingPolicy: TrackingPolicy {
    TrackingPolicy(
      enableFrontmost: self.tracking.frontmost.enabled,
      enableMedia: self.tracking.media.enabled,
      idleThresholdSec: self.tracking.frontmost.idleThresholdSec,
      videoOverridesIdle: self.tracking.frontmost.videoOverridesIdle,
      minSessionSec: self.tracking.sampling.minSessionSec,
      maxSessionSec: self.tracking.sampling.maxSessionSec
    )
  }
}

// The error types for configuration loading.
enum ConfigurationError: Error, Equatable, Sendable {
  // The file was written by a newer TimeArc and cannot be interpreted safely.
  case unsupportedSchemaVersion(Int64)
}

// Load the service configuration.
protocol ConfigurationLoading {
  func load() throws(ConfigurationError) -> ServiceConfiguration
}
