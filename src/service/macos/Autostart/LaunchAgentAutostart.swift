// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation
import ServiceManagement

// Register the service for launch at login.
//
// Two backends, in the order src/service/README.md documents. The bundled agent
// is preferred because launchd resolves it relative to the app and it needs no
// file outside the bundle. It requires a validly signed app, so on an ad-hoc
// signed development build SMAppService reports `notFound` and the user-level
// agent is what actually registers.
struct LaunchAgentAutostart: AutostartRegistering {
  // Register with the best backend that accepts the agent.
  func enable() throws(AutostartError) -> AutostartBackend {
    if self.enableBundled() {
      // A stale user-level agent would otherwise run a second collector.
      self.removeUserAgent()
      return .bundledLaunchAgent
    }

    try self.enableUser()
    return .userLaunchAgent
  }

  // Remove both backends. Removing what is not there is success.
  func disable() throws(AutostartError) {
    self.disableBundled()

    let plist = Self.userAgentURL
    if FileManager.default.fileExists(atPath: plist.path) || LaunchAgentControl.isLoaded() {
      guard LaunchAgentControl.bootout() else {
        throw AutostartError.removalFailed("launchctl could not unload \(LaunchAgentIdentity.label)")
      }
      self.removeUserAgent()
    }
  }

  // The backend currently holding a registration.
  func state() -> AutostartBackend? {
    if #available(macOS 13.0, *), SMAppService.agent(plistName: LaunchAgentIdentity.plistName).status == .enabled {
      return .bundledLaunchAgent
    }
    if FileManager.default.fileExists(atPath: Self.userAgentURL.path) {
      return .userLaunchAgent
    }
    return nil
  }

  // Try the bundled agent, reporting whether it is now registered. `requiresApproval`
  // counts as registered: the item exists and the user approves it in System
  // Settings, which no amount of retrying here can substitute for.
  private func enableBundled() -> Bool {
    guard #available(macOS 13.0, *) else {
      return false
    }
    let service = SMAppService.agent(plistName: LaunchAgentIdentity.plistName)
    switch service.status {
    case .enabled:
      return true
    case .requiresApproval:
      return true
    default:
      break
    }

    do {
      try service.register()
    } catch {
      return false
    }
    return service.status == .enabled || service.status == .requiresApproval
  }

  // Unregister the bundled agent when it holds a registration.
  private func disableBundled() {
    guard #available(macOS 13.0, *) else {
      return
    }
    let service = SMAppService.agent(plistName: LaunchAgentIdentity.plistName)
    guard service.status == .enabled || service.status == .requiresApproval else {
      return
    }
    try? service.unregister()
  }

  // Write and load a user-level agent pointing at this executable.
  private func enableUser() throws(AutostartError) {
    guard let executable = LaunchAgentControl.executableURL else {
      throw AutostartError.executableUnavailable
    }

    let plist = Self.userAgentURL
    do {
      try FileManager.default.createDirectory(
        at: plist.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try PropertyListSerialization.data(
        fromPropertyList: Self.userAgentDefinition(for: executable),
        format: .xml,
        options: 0
      )
      try data.write(to: plist, options: .atomic)
    } catch {
      throw AutostartError.registrationFailed("could not write \(plist.path)")
    }

    // Reload rather than load: a previously loaded definition would otherwise
    // keep running with the old program path.
    _ = LaunchAgentControl.bootout()
    guard LaunchAgentControl.bootstrap(plist) else {
      throw AutostartError.registrationFailed("launchctl could not load \(plist.path)")
    }
  }

  // Delete the user-level plist, ignoring its absence.
  private func removeUserAgent() {
    try? FileManager.default.removeItem(at: Self.userAgentURL)
  }

  // The user-level agent path, the documented fallback location.
  private static var userAgentURL: URL {
    let home =
      ProcessInfo.processInfo.environment["HOME"].map { URL(fileURLWithPath: $0) }
      ?? FileManager.default.homeDirectoryForCurrentUser
    return
      home
      .appendingPathComponent("Library")
      .appendingPathComponent("LaunchAgents")
      .appendingPathComponent(LaunchAgentIdentity.plistName)
  }

  // The user-level definition. KeepAlive is restricted to unsuccessful exits so
  // this backend behaves exactly like the bundled one: `stop` stays stopped, a
  // crash still restarts.
  private static func userAgentDefinition(for executable: URL) -> [String: Any] {
    [
      "Label": LaunchAgentIdentity.label,
      "ProgramArguments": [executable.path, "run"],
      "RunAtLoad": true,
      "KeepAlive": ["SuccessfulExit": false],
      "ProcessType": "Background",
      "LimitLoadToSessionType": "Aqua",
    ]
  }
}
