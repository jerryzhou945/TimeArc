// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import ApplicationServices

enum AccessibilityRequest {
  static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  @discardableResult
  static func request() -> Bool {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    let options = [promptKey: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }
}
