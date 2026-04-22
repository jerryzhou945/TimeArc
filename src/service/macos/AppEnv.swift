// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Cocoa
import ApplicationServices
import IOKit.pwr_mgt

enum MediaType {
  case video
  case audio
  case null
}

struct AppEnv: WindowIdentifying {
  private(set) var windowTitle: String? = nil
  private(set) var appID: String? = nil
  private var frontmostApp: NSRunningApplication? = nil

  // Update the current frontmost application info.
  mutating func update() {
    // Get the frontmost application.
    guard let currentApp = NSWorkspace.shared.frontmostApplication else {
      windowTitle = nil
      appID = nil
      frontmostApp = nil
      return
    }

    // If the frontmost application has changed, update the app info.
    if frontmostApp?.processIdentifier != currentApp.processIdentifier {
      frontmostApp = currentApp
      appID = currentApp.bundleIdentifier ?? "app.unknown"
    }

    // Update the window title regardless of whether the app changed.
    windowTitle = getFocusedWindowTitle()

  }

  // Get the number of seconds the user has been idle.
  func getIdleSeconds() -> Double {
    CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: CGEventType(rawValue: ~0)!
    )
  }

  // Get the name of the frontmost application.
  func getAppName() -> String {
    frontmostApp?.localizedName ?? "Unknown App"
  }

  // Get the icon path of the frontmost application.
  func getAppIcon() -> String {
    frontmostApp?.bundleURL?.path ?? ""
  }

  // Get the media playback state of the app.
  func getMediaType() -> MediaType {
    guard let pid = frontmostApp?.processIdentifier else {
      return .null
    }

    // Get the list of power assertions for all processes.
    var assertionsValue: Unmanaged<CFDictionary>?
    let assertionsStatus = IOPMCopyAssertionsByProcess(&assertionsValue)
    guard assertionsStatus == kIOReturnSuccess,
          let assertionsDict = assertionsValue?.takeRetainedValue()
                               as? [NSNumber: [[String: Any]]]
    else {
      return .null
    }

    // Check if the PID is in the list of assertions.
    guard let targetAssertions = assertionsDict[NSNumber(value: pid)] else {
      return .null
    }

    // Check if the app is holding a media playback assertion.
    for assertion in targetAssertions {
      guard let type = assertion[kIOPMAssertionTypeKey] as? String,
            let name = assertion[kIOPMAssertionNameKey] as? String,
            let level = assertion[kIOPMAssertionLevelKey] as? Int,
            level > 0
      else {
        continue
      }

      let lowercasedType = type.lowercased()
      let lowercasedName = name.lowercased()

      // Check for video assertions first.
      if isVideoAssertion(lowercasedType) {
        return .video
      }

      // If no video assertions, check for audio assertions.
      if isAudioAssertion(lowercasedType, lowercasedName) {
        return .audio
      }

    }

    return .null

  }

  // Get the title of the currently focused window of the frontmost application.
  private func getFocusedWindowTitle() -> String? {
    guard let pid = frontmostApp?.processIdentifier else {
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
    let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedTitle.isEmpty ? nil : trimmedTitle

  }

  private func isVideoAssertion(_ lowercasedType: String) -> Bool {
    lowercasedType.contains("displaysleep")
  }

  private func isAudioAssertion(_ lowercasedType: String, _ lowercasedName: String) -> Bool {
    guard lowercasedType.contains("useridlesystemsleep") ||
          lowercasedType.contains("noidlesleep")
    else {
      return false
    }

    let nameKeywords = ["audio", "music", "media", "play", "stream"]
    return nameKeywords.contains(where: lowercasedName.contains)

  }

}
