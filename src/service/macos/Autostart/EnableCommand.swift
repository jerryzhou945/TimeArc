// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Register the service to start at login.
struct EnableCommand {
  // The registration port.
  private let autostart: any AutostartRegistering

  // Initialize the command with its port.
  init(autostart: any AutostartRegistering = LaunchAgentAutostart()) {
    self.autostart = autostart
  }

  // Execute the enable command and report the process exit code.
  func execute() -> ServiceExitCode {
    do {
      let backend = try self.autostart.enable()
      FileHandle.standardOutput.write(
        Data("Autostart enabled (\(backend.rawValue)).\n".utf8))
      return .success
    } catch {
      FileHandle.standardError.write(
        Data("time-arc-service: could not enable autostart: \(error)\n".utf8))
      return .platformError
    }
  }
}
