// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The process exit codes documented in src/service/README.md.
enum ServiceExitCode: Int32, Equatable, Sendable {
  // Command completed successfully.
  case success = 0

  // Command failed due to a generic internal error.
  case internalError = 1

  // Invalid command or arguments.
  case usage = 2

  // Command failed due to a platform error.
  case platformError = 3

  // The service failed to start because of a configuration error.
  case configurationError = 4

  // The service failed to start because of a database error.
  case databaseError = 5

  // A second instance of the service is already running.
  case alreadyRunning = 6

  // Service state could not be queried reliably.
  case statusUnavailable = 10

  // Service is running but not enabled in configuration.
  case statusRunningNotEnabled = 11

  // Service is not running but enabled in configuration.
  case statusNotRunningEnabled = 12

  // Service is not running and not enabled in configuration.
  case statusNotRunningNotEnabled = 13

  // Doctor results could not be queried reliably.
  case doctorUnavailable = 20

  // Doctor overall status is degraded.
  case doctorDegraded = 21

  // Doctor overall status is failed.
  case doctorFailed = 22

  // Map a tracking failure to the exit code reported to the shell.
  init(_ error: TrackingError) {
    switch error {
    case .databaseRecordFailed:
      self = .databaseError
    case .appInformationUnavailable,
      .accessibilityTitleUnavailable,
      .eventInputUnavailable,
      .powerAssertionUnavailable,
      .audioProcessUnavailable,
      .timeValidationFailed:
      self = .platformError
    }
  }
}
