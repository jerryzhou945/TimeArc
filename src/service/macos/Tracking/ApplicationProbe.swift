// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import AppKit
import Foundation

// Probe the information of an app.
struct ApplicationProbe: FrontmostAppProbing, AppInformationProbing {
  // Probe the frontmost app information.
  func getFrontmostApp() -> AppInformation? {
    let app = NSWorkspace.shared.frontmostApplication
    guard let app,
      app.processIdentifier > 0,
      let bundleIdentifier = app.bundleIdentifier,
      let localizedName = app.localizedName,
      let bundleURL = app.bundleURL
    else {
      return nil
    }

    return AppInformation(
      pid: app.processIdentifier,
      id: bundleIdentifier,
      name: localizedName,
      path: bundleURL.path
    )
  }

  // Probe the app information for a given PID.
  func getAppInformation(for pid: Int32) -> AppInformation? {
    guard pid > 0 else {
      return nil
    }

    let app = NSRunningApplication(processIdentifier: pid)
    guard let app,
      let bundleIdentifier = app.bundleIdentifier,
      let localizedName = app.localizedName,
      let bundleURL = app.bundleURL
    else {
      return nil
    }

    return AppInformation(
      pid: pid,
      id: bundleIdentifier,
      name: localizedName,
      path: bundleURL.path
    )
  }
}
