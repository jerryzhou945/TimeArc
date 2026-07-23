// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import CoreGraphics
import Foundation

// Probe the seconds since last input.
struct InputActionProbe: InputActionProbing {
  func getSecondsSinceLastInput() -> Int64 {
    guard let anyEventType = CGEventType(rawValue: UInt32.max) else {
      return 0
    }

    let idleSec = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: anyEventType
    )

    guard !idleSec.isNaN, idleSec > 0 else {
      return 0
    }
    guard idleSec.isFinite, idleSec < Double(Int64.max) else {
      return Int64.max
    }

    return Int64(idleSec)
  }
}
