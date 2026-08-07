// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The service state reported by `status`, as specified in src/service/README.md.
//
// This is a pure value: everything in it is gathered by the command from the
// configuration, the instance lock, and the autostart backend, so the report can
// be rendered and reasoned about without touching the system again.
struct StatusReport: Equatable, Sendable {
  // The operating system producing the records.
  let platform: String

  // Whether a collector is actively tracking right now.
  let running: Bool

  // The collection settings currently on disk.
  let configuration: ServiceConfiguration

  // The backend holding an autostart registration, if any.
  let autostartBackend: AutostartBackend?

  // Whether the service is registered to start at login.
  var autostartEnabled: Bool {
    self.autostartBackend != nil
  }

  // The exit code for this state, per the README's table. Running and enabled is
  // the only success; the rest describe which half is missing so a caller can
  // act without parsing the output.
  var exitCode: ServiceExitCode {
    switch (self.running, self.configuration.tracking.enabled) {
    case (true, true):
      return .success
    case (true, false):
      return .statusRunningNotEnabled
    case (false, true):
      return .statusNotRunningEnabled
    case (false, false):
      return .statusNotRunningNotEnabled
    }
  }
}

// Render a report in the format the caller asked for.
protocol StatusRendering {
  func render(_ report: StatusReport) -> String
}
