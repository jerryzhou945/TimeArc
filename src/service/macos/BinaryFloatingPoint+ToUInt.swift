// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

extension BinaryFloatingPoint {
  // Converts a floating-point value to UInt64 using safe clamping.
  func clampedToUInt64() -> UInt64 {
    if self.isNaN || self <= 0 {
      return 0
    }

    if self.isInfinite || self >= Self(UInt64.max) {
      return UInt64.max
    }

    return UInt64(self)
  }

}
