// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

struct WindowIdentity: Equatable, Hashable, Sendable {
  let windowTitle: String?
  let appID: String?
}

protocol WindowIdentifying {
  var windowTitle: String? { get }
  var appID: String? { get }
  func identifyWindow() -> WindowIdentity?
}

extension WindowIdentifying {
  func identifyWindow() -> WindowIdentity? {
    guard let appID = appID, let windowTitle = windowTitle else {
      return nil
    }
    return WindowIdentity(windowTitle: windowTitle, appID: appID)
  }
}
