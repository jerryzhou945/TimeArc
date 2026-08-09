// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Read the wall clock from the system.
struct SystemClock: Clocking {
  // The current Unix time in seconds. Records store this value, and it can jump
  // in either direction when the clock is corrected or the machine sleeps.
  var wallUnixSec: Int64 {
    Int64(Date().timeIntervalSince1970)
  }
}
