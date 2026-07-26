// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import CoreGraphics
import Foundation

// Probe the seconds since last input.
struct InputActionProbe: InputActionProbing {
  func getSecondsSinceLastInput() throws(TrackingError) -> Int64 {
    guard let anyEventType = CGEventType(rawValue: UInt32.max) else {
      throw TrackingError.eventInputUnavailable
    }
    let idleSec = CGEventSource.secondsSinceLastEventType(
      .combinedSessionState,
      eventType: anyEventType
    )
    guard idleSec.isFinite,
      idleSec >= 0,
      idleSec < Double(Int64.max)
    else {
      throw TrackingError.eventInputUnavailable
    }
    return Int64(idleSec)
  }
}
