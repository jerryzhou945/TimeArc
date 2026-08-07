// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Report the service state.
//
// Every input is read locally: the control file for the settings, the instance
// lock for whether a collector is live, and the autostart backend for the
// registration. Nothing here talks to a running instance, so `status` answers
// the same way whether or not the collector is healthy enough to serve the
// control channel -- which is exactly the case a caller most needs an answer in.
struct StatusCommand {
  // Ports.
  private let configurationStore: any ConfigurationLoading
  private let autostart: any AutostartRegistering

  // Initialize the command with its ports.
  init(
    configurationStore: any ConfigurationLoading = FileConfigurationStore(),
    autostart: any AutostartRegistering = LaunchAgentAutostart()
  ) {
    self.configurationStore = configurationStore
    self.autostart = autostart
  }

  // Execute the status command and report the process exit code.
  func execute(_ options: ReportOptions) -> ServiceExitCode {
    // A configuration this build cannot interpret means the reported settings
    // would be fiction, so the state cannot be queried reliably.
    let configuration: ServiceConfiguration
    do {
      configuration = try self.configurationStore.load()
    } catch {
      FileHandle.standardError.write(
        Data("time-arc-service: could not read the configuration: \(error)\n".utf8))
      return .statusUnavailable
    }

    let report = StatusReport(
      platform: "macos",
      running: FileInstanceLock.isHeld(),
      configuration: configuration,
      autostartBackend: self.autostart.state()
    )

    let renderer: any StatusRendering =
      options.format == .json ? JSONStatusRenderer() : TextStatusRenderer()
    FileHandle.standardOutput.write(Data(renderer.render(report).utf8))
    return report.exitCode
  }
}
