// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Start a background instance and wait until it is actually collecting.
struct StartCommand {
  // How long to wait for a freshly launched instance to answer.
  private static let readinessTimeoutSec = 10.0

  // Ports.
  private let client: any ControlClienting
  private let configurationStore: any ConfigurationLoading

  // Initialize the command with its ports.
  init(
    client: any ControlClienting = ControlClient(),
    configurationStore: any ConfigurationLoading = FileConfigurationStore()
  ) {
    self.client = client
    self.configurationStore = configurationStore
  }

  // Execute the start command and report the process exit code.
  func execute() -> ServiceExitCode {
    // Starting a collector that would immediately exit is a successful no-op.
    do {
      guard try self.configurationStore.load().isCollecting else {
        return .success
      }
    } catch {
      switch error {
      case .unsupportedSchemaVersion(let version):
        FileHandle.standardError.write(
          Data("time-arc-service: configuration schema_version \(version) is too new.\n".utf8))
        return .configurationError
      }
    }

    // Idempotent, like the Windows instance mutex: an already running collector
    // is success, not a conflict.
    if self.isRunning() {
      return .success
    }

    // Prefer launchd, so the started instance is the one it supervises rather
    // than an unmanaged orphan. Skip it when the control file is redirected:
    // launchd does not inherit this process's environment, so its instance
    // would read a different configuration than the caller asked for.
    if !ServiceConfigurationPath.isRedirected, LaunchAgentControl.kickstart(),
      self.waitUntilRunning()
    {
      return .success
    }

    // Either the agent is not registered, launchd refused, or its instance is
    // not the one being waited for. Launching directly covers all three, and
    // makes `start` work before `enable` has ever run.
    guard LaunchAgentControl.spawnDetached() else {
      return .platformError
    }
    return self.waitUntilRunning() ? .success : .platformError
  }

  // Whether an instance is already collecting. The lock is the authority, so a
  // running instance from an older build still counts and `start` stays a no-op
  // rather than spawning a second collector that would exit 6.
  private func isRunning() -> Bool {
    FileInstanceLock.isHeld()
  }

  // Wait for the new instance to reach a stable state. Readiness means it has
  // taken the lock and is serving the control channel, which happens only after
  // it has read its configuration and built the coordinator.
  private func waitUntilRunning() -> Bool {
    let deadline = Date().addingTimeInterval(Self.readinessTimeoutSec)
    while Date() < deadline {
      if ((try? self.client.send(.ping))?.ok) == true {
        return true
      }
      usleep(200_000)
    }
    return FileInstanceLock.isHeld()
  }
}
