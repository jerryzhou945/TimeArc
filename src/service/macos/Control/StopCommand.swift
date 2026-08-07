// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// Ask a running instance to flush its open sessions and exit.
//
// The instance exits successfully, and the launch agent is registered with
// KeepAlive restricted to unsuccessful exits, so launchd leaves it stopped. That
// is what separates `stop` from `disable`.
struct StopCommand {
  // How long to wait for the instance to finish flushing and release the socket.
  private static let shutdownTimeoutSec = 10.0

  // The control client used to reach the instance.
  private let client: any ControlClienting

  // Initialize the command with its port.
  init(client: any ControlClienting = ControlClient()) {
    self.client = client
  }

  // Execute the stop command and report the process exit code.
  func execute() -> ServiceExitCode {
    // Nothing collecting means nothing to stop, which the CLI reports as success.
    guard self.isRunning() else {
      return .success
    }

    do {
      let response = try self.client.send(.stop)
      guard response.ok else {
        return self.terminateFallback()
      }
    } catch {
      // Collecting but not answering: an instance older than the control
      // channel, or one wedged before it began serving. Signal it instead.
      return self.terminateFallback()
    }

    return self.waitUntilStopped() ? .success : .platformError
  }

  // Whether an instance is collecting. The lock is the authority; the socket
  // only says whether that instance can also be talked to.
  private func isRunning() -> Bool {
    FileInstanceLock.isHeld()
  }

  // Wait for the instance to release the socket, which happens after it has
  // flushed. Reporting success earlier would let a caller relocate the database
  // out from under a still-writing process.
  private func waitUntilStopped() -> Bool {
    let deadline = Date().addingTimeInterval(Self.shutdownTimeoutSec)
    while Date() < deadline {
      if !self.isRunning() {
        return true
      }
      usleep(200_000)
    }
    return !self.isRunning()
  }

  // Signal the lock holder when the control channel cannot carry the request.
  // SIGTERM still reaches the runtime's handler, so the flush path is the same;
  // only the delivery differs. There is deliberately no SIGKILL escalation: it
  // would discard the open session this command exists to preserve.
  private func terminateFallback() -> ServiceExitCode {
    guard let pid = FileInstanceLock.holderPid() else {
      return .platformError
    }
    guard kill(pid, SIGTERM) == 0 else {
      return .platformError
    }
    return self.waitUntilStopped() ? .success : .platformError
  }
}
