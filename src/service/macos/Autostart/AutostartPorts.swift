// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The launch agent identity, shared by registration and launchd control.
enum LaunchAgentIdentity {
  // The launchd label, matching resources/bundle/macos/com.timearc.service.plist.
  static let label = "com.timearc.service"

  // The bundled plist file name, resolved inside the app bundle by SMAppService.
  static let plistName = "com.timearc.service.plist"
}

// Where an autostart registration lives, as reported by `status`.
enum AutostartBackend: String, Equatable, Sendable {
  // The agent bundled in the app, registered through SMAppService.
  case bundledLaunchAgent = "bundled-launch-agent"

  // A plist this service wrote to the user's LaunchAgents directory.
  case userLaunchAgent = "user-launch-agent"
}

// The error types for autostart registration.
enum AutostartError: Error, Equatable, Sendable {
  // No backend could register the agent.
  case registrationFailed(String)

  // A registration exists but could not be removed.
  case removalFailed(String)

  // The service executable path could not be resolved.
  case executableUnavailable
}

// Register and unregister the service for launch at login.
protocol AutostartRegistering {
  // Register, reporting which backend accepted it.
  func enable() throws(AutostartError) -> AutostartBackend

  // Remove every registration this platform knows about. Removing an absent
  // registration succeeds.
  func disable() throws(AutostartError)

  // The backend currently holding a registration, if any.
  func state() -> AutostartBackend?
}
