// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Cocoa
import ApplicationServices

struct AppEnv: WindowIdentifying {
  private(set) var windowTitle: String? = nil
  private(set) var appID: String? = nil
  private(set) var appName: String? = nil
  private var currentPID: pid_t? = nil

  // Update the current frontmost application info.
  mutating func update() {
    // Get the frontmost application.
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
      windowTitle = nil
      appID = nil
      appName = nil
      currentPID = nil
      return
    }

    // If the frontmost application has changed, update the stored info.
    let frontPID = frontApp.processIdentifier
    if currentPID != frontPID {
      currentPID = frontPID
      appID = frontApp.bundleIdentifier ?? "unknown.app"
      appName = frontApp.localizedName ?? "Unknown App"
    }

    // If the app is the same, just update the window title.
    windowTitle = getFocusedWindowTitle()

  }

  // Get the number of seconds the user has been idle.
  func getIdleSeconds() -> Double {
    CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: CGEventType(rawValue: ~0)!
    )
  }

  // Get the title of the currently focused window of the frontmost application using PID.
  private func getFocusedWindowTitle() -> String? {
    guard let pid = currentPID else {
      return nil
    }
    let appElement = AXUIElementCreateApplication(pid)

    // Ask the application for its currently focused window
    var focusedWindowValue: CFTypeRef?
    let focusedWindowStatus = AXUIElementCopyAttributeValue(
      appElement,
      kAXFocusedWindowAttribute as CFString,
      &focusedWindowValue
    )
    guard focusedWindowStatus == .success,
          let windowElement = focusedWindowValue
    else {
      return nil
    }

    // Ask the focused window for its title
    var titleValue: CFTypeRef?
    let titleStatus = AXUIElementCopyAttributeValue(
      windowElement as! AXUIElement,
      kAXTitleAttribute as CFString,
      &titleValue
    )
    guard titleStatus == .success,
          let title = titleValue as? String
    else {
      return nil
    }

    // Trim whitespace and newlines from the title.
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

}
