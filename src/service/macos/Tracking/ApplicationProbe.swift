// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import AppKit
import Foundation

// Probe the information of an app.
struct ApplicationProbe: FrontmostAppProbing, AppInformationProbing {
  // Probe the frontmost app information.
  func getFrontmostApp() throws(TrackingError) -> AppInformation? {
    guard let app = NSWorkspace.shared.frontmostApplication else {
      return nil
    }

    guard app.processIdentifier > 0,
      let bundleIdentifier = app.bundleIdentifier,
      let localizedName = app.localizedName,
      let bundleURL = app.bundleURL
    else {
      throw TrackingError.appInformationUnavailable
    }

    return AppInformation(
      pid: app.processIdentifier,
      id: bundleIdentifier,
      name: localizedName,
      path: bundleURL.path
    )
  }

  // Probe the app information for a given PID.
  func getAppInformation(for pid: Int32) throws(TrackingError) -> AppInformation? {
    guard pid > 0,
      let app = NSRunningApplication(processIdentifier: pid)
    else {
      return nil
    }

    guard let bundleIdentifier = app.bundleIdentifier,
      let localizedName = app.localizedName,
      let bundleURL = app.bundleURL
    else {
      throw TrackingError.appInformationUnavailable
    }

    return AppInformation(
      pid: pid,
      id: bundleIdentifier,
      name: localizedName,
      path: bundleURL.path
    )
  }
}
