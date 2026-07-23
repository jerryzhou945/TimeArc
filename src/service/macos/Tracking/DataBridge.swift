// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Bridge the records to SQLite database.
struct DataBridge: DataBridging {
  // Bridge the frontmost record to SQLite database.
  func bridgeFrontmostRecord(_ record: FrontmostRecord) {
    bridgeAppInformation(record.app, at: record.lastUpdateUnixSec)
    updateFrontmost(
      appId: record.app.id,
      windowTitle: record.windowTitle ?? "Unknown Window",
      startUnixSec: record.startUnixSec,
      endUnixSec: record.lastUpdateUnixSec,
      activeSec: record.activeSec
    )
  }

  // Bridge the media record to SQLite database.
  func bridgeMediaRecord(_ record: MediaRecord) {
    bridgeAppInformation(record.app, at: record.lastUpdateUnixSec)
    updateMedia(
      appId: record.app.id,
      mediaType: record.mediaType.rawValue,
      mediaTitle: record.mediaTitle ?? "Unknown Media",
      startUnixSec: record.startUnixSec,
      endUnixSec: record.lastUpdateUnixSec
    )
  }

  // Bridge the app information to SQLite database.
  private func bridgeAppInformation(_ app: AppInformation, at time: Int64) {
    updateApps(
      appId: app.id,
      platform: "macos",
      displayName: app.name,
      iconPath: app.path,
      executablePath: app.path,
      updatedAt: time
    )
  }
}
