// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Remove every autostart registration.
//
// This does not stop a running collector: `stop` owns that, and separating the
// two is the point of the KeepAlive change that accompanies this command.
struct DisableCommand {
  // The registration port.
  private let autostart: any AutostartRegistering

  // Initialize the command with its port.
  init(autostart: any AutostartRegistering = LaunchAgentAutostart()) {
    self.autostart = autostart
  }

  // Execute the disable command and report the process exit code.
  func execute() -> ServiceExitCode {
    do {
      try self.autostart.disable()
      FileHandle.standardOutput.write(Data("Autostart disabled.\n".utf8))
      return .success
    } catch {
      FileHandle.standardError.write(
        Data("time-arc-service: could not disable autostart: \(error)\n".utf8))
      return .platformError
    }
  }
}
