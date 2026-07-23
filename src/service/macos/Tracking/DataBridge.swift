// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Bridge the records to SQLite database.
struct DataBridge: DataBridging {
  // Bridge the frontmost record to SQLite database.
  func bridgeFrontmostRecord(_ record: FrontmostRecord) throws(TrackingError) {
    try bridgeAppInformation(record.app, at: record.lastUpdateUnixSec)
    guard
      updateFrontmost(
        appId: record.app.id,
        windowTitle: record.windowTitle ?? "Unknown Window",
        startUnixSec: record.startUnixSec,
        endUnixSec: record.lastUpdateUnixSec,
        activeSec: record.activeSec
      ) == 0
    else {
      throw TrackingError.databaseRecordFailed
    }
  }

  // Bridge the media record to SQLite database.
  func bridgeMediaRecord(_ record: MediaRecord) throws(TrackingError) {
    try bridgeAppInformation(record.app, at: record.lastUpdateUnixSec)
    guard
      updateMedia(
        appId: record.app.id,
        mediaType: record.mediaType.rawValue,
        mediaTitle: record.mediaTitle ?? "Unknown Media",
        startUnixSec: record.startUnixSec,
        endUnixSec: record.lastUpdateUnixSec
      ) == 0
    else {
      throw TrackingError.databaseRecordFailed
    }
  }

  // Bridge the app information to SQLite database.
  private func bridgeAppInformation(_ app: AppInformation, at time: Int64) throws(TrackingError) {
    guard
      updateApps(
        appId: app.id,
        platform: "macos",
        displayName: app.name,
        iconPath: app.path,
        executablePath: app.path,
        updatedAt: time
      ) == 0
    else {
      throw TrackingError.databaseRecordFailed
    }
  }
}
