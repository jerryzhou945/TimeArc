// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

struct AppInfo: WindowIdentifying {
  private(set) var windowTitle: String? = nil
  private(set) var appID: String? = nil
  private(set) var appName: String? = nil
  private(set) var timestamp: UInt64 = Date().timeIntervalSince1970.clampedToUInt64()
  private(set) var activeTime: UInt64 = 0
  private var isActive: Bool = true

  // Update the idle state based on the number of seconds the user has been idle.
  mutating func updateIdleState(time idleSeconds: Double, threshold: Double = 300) {
    let wasActive = isActive
    isActive = idleSeconds < threshold
    let now = Date().timeIntervalSince1970.clampedToUInt64()

    if wasActive && !isActive {
      // User just became idle, update active time.
      let elapsed = now >= timestamp ? (now - timestamp) : 0
      activeTime += elapsed
    }

    if !wasActive && isActive {
      // User just became active again, reset timestamp.
      timestamp = now
    }
  }

  // Update the current frontmost application info.
  mutating func updateNewApp(windowTitle: String?, appID: String?, appName: String?) {
    self.windowTitle = windowTitle
    self.appID = appID
    self.appName = appName
    timestamp = Date().timeIntervalSince1970.clampedToUInt64()
    activeTime = 0
    isActive = true
  }

}
