// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Render a status report as human-readable text, per src/service/README.md.
struct TextStatusRenderer: StatusRendering {
  func render(_ report: StatusReport) -> String {
    let tracking = report.configuration.tracking
    var lines = [
      "TimeArc Service \(ServiceUsage.version) on \(ServiceUsage.platform)",
      "",
      "Tracking: \(report.running ? "running" : "stopped")",
    ]

    if tracking.frontmost.enabled {
      lines.append(
        "Frontmost apps: enabled (idle threshold \(tracking.frontmost.idleThresholdSec)s)")
    } else {
      lines.append("Frontmost apps: disabled")
    }
    lines.append("Media sessions: \(tracking.media.enabled ? "enabled" : "disabled")")

    if let backend = report.autostartBackend {
      lines.append("Autostart: enabled (\(backend.rawValue))")
    } else {
      lines.append("Autostart: disabled")
    }

    // Tracking disabled in configuration outranks the sub-switches: nothing is
    // collected at all, which the lines above would not otherwise make obvious.
    if !tracking.enabled {
      lines.append("")
      lines.append("Tracking is disabled in configuration; no records are written.")
    }

    return lines.joined(separator: "\n") + "\n"
  }
}

// Render a status report as JSON, for the GUI and for scripts.
struct JSONStatusRenderer: StatusRendering {
  func render(_ report: StatusReport) -> String {
    let tracking = report.configuration.tracking

    // The README types this field as `string or null`, and JSONSerialization
    // spells JSON null as NSNull. Built in two steps rather than with `??`,
    // which would mix String and NSNull into an implicitly coerced `Any?`.
    var backend: Any = NSNull()
    if let registered = report.autostartBackend {
      backend = registered.rawValue
    }

    let object: [String: Any] = [
      "schema_version": ControlWire.schemaVersion,
      "command": "status",
      "platform": report.platform,
      "tracking": [
        "running": report.running,
        "enabled": tracking.enabled,
        "frontmost": [
          "enabled": tracking.frontmost.enabled,
          "idle_threshold_sec": tracking.frontmost.idleThresholdSec,
        ],
        "media": [
          "enabled": tracking.media.enabled
        ],
      ],
      "autostart": [
        "enabled": report.autostartEnabled,
        "backend": backend,
      ],
    ]

    guard
      let data = try? JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys]
      ),
      let text = String(data: data, encoding: .utf8)
    else {
      return "{}\n"
    }
    return text + "\n"
  }
}
