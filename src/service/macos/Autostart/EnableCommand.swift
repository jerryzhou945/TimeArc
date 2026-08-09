// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Register the service to start at login.
struct EnableCommand {
  // How long to let the freshly registered agent come up before returning.
  private static let settleTimeoutSec = 8.0

  // Ports.
  private let autostart: any AutostartRegistering
  private let configurationStore: any ConfigurationLoading

  // Initialize the command with its ports.
  init(
    autostart: any AutostartRegistering = LaunchAgentAutostart(),
    configurationStore: any ConfigurationLoading = FileConfigurationStore()
  ) {
    self.autostart = autostart
    self.configurationStore = configurationStore
  }

  // Execute the enable command and report the process exit code.
  func execute() -> ServiceExitCode {
    let backend: AutostartBackend
    do {
      backend = try self.autostart.enable()
    } catch {
      FileHandle.standardError.write(
        Data("time-arc-service: could not enable autostart: \(error)\n".utf8))
      return .platformError
    }

    self.startCollectorIfIdle()
    FileHandle.standardOutput.write(Data("Autostart enabled (\(backend.rawValue)).\n".utf8))
    return .success
  }

  // Make sure a collector is actually running once autostart is on.
  //
  // RunAtLoad only fires when launchd *loads* the job, so registering an agent
  // that is already registered starts nothing -- which is the state `enable`
  // lands in whenever it is called to resume collection rather than to set it up
  // for the first time. Asking launchd to run the job covers that, and keeps the
  // collector under the supervisor instead of spawning one this process owns.
  private func startCollectorIfIdle() {
    // Tracking switched off in configuration means the collector would exit
    // immediately; leaving it stopped is the correct outcome, not a failure.
    guard let configuration = try? self.configurationStore.load(), configuration.isCollecting
    else {
      return
    }
    if FileInstanceLock.isHeld() {
      return
    }

    _ = LaunchAgentControl.kickstart()

    // launchd returns before the collector has taken its lock, so a caller that
    // checks `status` next would otherwise race it. Best effort: the exit code
    // reports registration, which is all `enable` promises.
    let deadline = Date().addingTimeInterval(Self.settleTimeoutSec)
    while Date() < deadline {
      if FileInstanceLock.isHeld() {
        return
      }
      usleep(200_000)
    }
  }
}
