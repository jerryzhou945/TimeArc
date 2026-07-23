// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation
import IOKit.pwr_mgt

// Probe the sleep assertions for the system.
struct SleepAssertionProbe: SleepAssertionProbing {
  func getSleepAssertions() throws(TrackingError) -> [Int32: SleepAssertionType]? {
    // Get the sleep assertions by process.
    var assertionsValue: Unmanaged<CFDictionary>?
    let status = IOPMCopyAssertionsByProcess(&assertionsValue)
    guard status == kIOReturnSuccess,
      let assertions = assertionsValue?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
    else {
      throw TrackingError.powerAssertionUnavailable
    }

    // Map the assertions to a dictionary of pid and sleep assertion type.
    var sleepAssertions: [Int32: SleepAssertionType] = [:]
    for (pidNumber, processAssertions) in assertions {
      let pid = pidNumber.int32Value
      for assertion in processAssertions {
        // Check if the assertion has a valid type and level.
        guard let type = assertion[kIOPMAssertionTypeKey] as? String,
          let level = assertion[kIOPMAssertionLevelKey] as? NSNumber,
          level.intValue > 0
        else {
          continue
        }

        // Determine the sleep assertion type based on the assertion type string.
        switch type {
        case "PreventSystemSleep":
          sleepAssertions[pid] = .system
          break
        case "PreventUserIdleDisplaySleep", "NoDisplaySleepAssertion":
          if sleepAssertions[pid] != .system {
            sleepAssertions[pid] = .foreground
          }
        case "PreventUserIdleSystemSleep", "NoIdleSleepAssertion":
          if sleepAssertions[pid] == nil {
            sleepAssertions[pid] = .background
          }
        default:
          continue
        }
      }
    }
    return sleepAssertions.isEmpty ? nil : sleepAssertions
  }
}
