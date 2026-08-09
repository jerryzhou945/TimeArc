// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// Talk to launchd, and launch this executable when launchd cannot.
enum LaunchAgentControl {
  // This process's own executable, which is also the collector binary.
  static var executableURL: URL? {
    ProcessIdentity.ownExecutableURL
  }

  // The per-user launchd domain target for the agent.
  static var domainTarget: String {
    "gui/\(getuid())/\(LaunchAgentIdentity.label)"
  }

  // Ask launchd to start the registered agent. Fails when the agent is not
  // registered, which is the caller's cue to launch the collector directly.
  static func kickstart() -> Bool {
    self.launchctl(["kickstart", self.domainTarget]) == 0
  }

  // Load a plist into the user's launchd domain.
  static func bootstrap(_ plist: URL) -> Bool {
    self.launchctl(["bootstrap", "gui/\(getuid())", plist.path]) == 0
  }

  // Remove the agent from the user's launchd domain. Reports success when it was
  // not loaded, so `disable` stays idempotent.
  static func bootout() -> Bool {
    let status = self.launchctl(["bootout", self.domainTarget])
    return status == 0 || status == ESRCH
  }

  // Whether launchd currently knows the agent.
  static func isLoaded() -> Bool {
    self.launchctl(["print", self.domainTarget]) == 0
  }

  // Launch the collector as a detached process, so `start` works before the
  // agent has ever been registered. The child outlives this CLI invocation and
  // is reparented to launchd.
  static func spawnDetached() -> Bool {
    guard let executable = self.executableURL else {
      return false
    }
    let process = Process()
    process.executableURL = executable
    process.arguments = ["run"]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      return true
    } catch {
      return false
    }
  }

  // Run launchctl and report its exit status, or -1 when it could not run.
  @discardableResult
  private static func launchctl(_ arguments: [String]) -> Int32 {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
      return process.terminationStatus
    } catch {
      return -1
    }
  }
}
