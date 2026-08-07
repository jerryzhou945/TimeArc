// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Read the control file and map it onto the service configuration.
//
// The file is advisory: an absent, unreadable, or malformed file falls back to
// the documented defaults, and so does any single key that is missing or out of
// range. Only a schema written by a newer TimeArc stops the service, because
// interpreting unknown semantics would silently mis-collect.
struct FileConfigurationStore: ConfigurationLoading {
  // Load the configuration from the resolved control file.
  func load() throws(ConfigurationError) -> ServiceConfiguration {
    // A missing file is the normal case on a fresh install.
    let url = ServiceConfigurationPath.configurationFile
    guard let data = try? Data(contentsOf: url) else {
      return ServiceConfiguration()
    }

    // A malformed file keeps the defaults, but the user should know about it.
    guard let parsed = try? JSONSerialization.jsonObject(with: data),
      let root = parsed as? [String: Any]
    else {
      self.report("configuration is not a JSON object, using defaults: \(url.path)")
      return ServiceConfiguration()
    }

    // Refuse a file this build cannot interpret rather than mis-collecting.
    if let version = self.integer(in: root, at: "schema_version"),
      version > ServiceConfiguration.supportedSchemaVersion
    {
      throw ConfigurationError.unsupportedSchemaVersion(version)
    }

    let defaults = ServiceConfiguration()
    let sampling = SamplingConfiguration(
      pollPeriodSec: self.seconds(
        in: root,
        at: "tracking.sampling.poll_period_sec",
        default: defaults.tracking.sampling.pollPeriodSec,
        in: 1...60
      ),
      minSessionSec: self.seconds(
        in: root,
        at: "tracking.sampling.min_session_sec",
        default: defaults.tracking.sampling.minSessionSec,
        in: 1...60
      ),
      maxSessionSec: self.seconds(
        in: root,
        at: "tracking.sampling.max_session_sec",
        default: defaults.tracking.sampling.maxSessionSec,
        in: 60...86400,
        allowing: 0
      )
    )
    let frontmost = FrontmostConfiguration(
      enabled: self.flag(
        in: root,
        at: "tracking.frontmost.enabled",
        default: defaults.tracking.frontmost.enabled
      ),
      idleThresholdSec: self.seconds(
        in: root,
        at: "tracking.frontmost.idle_threshold_sec",
        default: defaults.tracking.frontmost.idleThresholdSec,
        in: 0...86400
      ),
      videoOverridesIdle: self.flag(
        in: root,
        at: "tracking.frontmost.video_overrides_idle",
        default: defaults.tracking.frontmost.videoOverridesIdle
      )
    )
    let media = MediaConfiguration(
      enabled: self.flag(
        in: root,
        at: "tracking.media.enabled",
        default: defaults.tracking.media.enabled
      )
    )

    return ServiceConfiguration(
      tracking: TrackingConfiguration(
        enabled: self.flag(in: root, at: "tracking.enabled", default: defaults.tracking.enabled),
        sampling: sampling,
        frontmost: frontmost,
        media: media
      )
    )
  }

  // Read a boolean key, falling back to the default when it is absent or invalid.
  private func flag(in root: [String: Any], at path: String, default defaultValue: Bool) -> Bool {
    guard let value = self.value(in: root, at: path) else {
      return defaultValue
    }
    guard CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID(), let flag = value as? Bool else {
      self.report("'\(path)' is not a boolean, using \(defaultValue)")
      return defaultValue
    }
    return flag
  }

  // Read a seconds key, falling back to the default when it is absent, invalid,
  // or outside the documented range.
  private func seconds(
    in root: [String: Any],
    at path: String,
    default defaultValue: Int64,
    in range: ClosedRange<Int64>,
    allowing exception: Int64? = nil
  ) -> Int64 {
    guard self.value(in: root, at: path) != nil else {
      return defaultValue
    }
    guard let seconds = self.integer(in: root, at: path) else {
      self.report("'\(path)' is not an integer, using \(defaultValue)")
      return defaultValue
    }
    guard range.contains(seconds) || seconds == exception else {
      self.report(
        "'\(path)' is \(seconds), outside \(range.lowerBound)-\(range.upperBound), "
          + "using \(defaultValue)"
      )
      return defaultValue
    }
    return seconds
  }

  // Read an integer key. Booleans and fractional numbers are not integers.
  private func integer(in root: [String: Any], at path: String) -> Int64? {
    guard let value = self.value(in: root, at: path),
      CFGetTypeID(value as CFTypeRef) != CFBooleanGetTypeID(),
      let number = value as? NSNumber
    else {
      return nil
    }
    let seconds = number.int64Value
    return Double(seconds) == number.doubleValue ? seconds : nil
  }

  // Resolve a dotted key path inside the parsed object.
  private func value(in root: [String: Any], at path: String) -> Any? {
    var current: Any? = root
    for component in path.split(separator: ".") {
      guard let object = current as? [String: Any] else {
        return nil
      }
      current = object[String(component)]
    }
    return current
  }

  // Report a configuration problem to standard error.
  private func report(_ message: String) {
    FileHandle.standardError.write(Data(("time-arc-service: " + message + "\n").utf8))
  }
}
