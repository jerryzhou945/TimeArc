// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// The rendering format requested for a report command.
enum OutputFormat: String, Equatable, Sendable {
  case text
  case json
}

// The options that control how a report command renders its result.
struct ReportOptions: Equatable, Sendable {
  // The requested output format.
  let format: OutputFormat

  // Whether the report includes additional details.
  let verbose: Bool

  // Initialize the report options with the documented defaults.
  init(format: OutputFormat = .text, verbose: Bool = false) {
    self.format = format
    self.verbose = verbose
  }
}

// The command requested on the command line.
enum ServiceCommand: Equatable, Sendable {
  // Run the service in the foreground until a stop signal arrives.
  case run

  // Register the service for autostart on login.
  case enable

  // Remove every autostart registration known to the platform.
  case disable

  // Start the service in the background.
  case start

  // Request a graceful shutdown of the running service.
  case stop

  // Stop the service and start it again with a fresh configuration.
  case restart

  // Query the service state and print it in the requested format.
  case status(ReportOptions)

  // Examine the service installation and print the report.
  case doctor(ReportOptions)

  // Print the command usage.
  case help

  // Print the version information.
  case version

  // The verb that selects this command on the command line.
  var name: String {
    switch self {
    case .run:
      return "run"
    case .enable:
      return "enable"
    case .disable:
      return "disable"
    case .start:
      return "start"
    case .stop:
      return "stop"
    case .restart:
      return "restart"
    case .status:
      return "status"
    case .doctor:
      return "doctor"
    case .help:
      return "help"
    case .version:
      return "version"
    }
  }
}

// The error types for command-line parsing.
enum CommandLineError: Error, Equatable, Sendable {
  // The first argument is not a known command.
  case unknownCommand(String)

  // An option is not recognized by the command.
  case unknownOption(String)

  // A positional argument was supplied where none is accepted.
  case unexpectedArgument(String)

  // The same option was supplied more than once.
  case repeatedOption(String)

  // Both output formats were requested for the same command.
  case conflictingFormat
}
