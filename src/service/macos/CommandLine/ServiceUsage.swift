// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Render the command-line usage, version, and diagnostics text.
enum ServiceUsage {
  // The service version. Keep in sync with the CMake project version.
  static let version = "0.1.0"

  // The platform name reported by the command-line interface.
  static let platform = "macOS"

  // Print the command usage to standard output.
  static func printHelp() {
    self.write(self.helpText, to: .standardOutput)
  }

  // Print the version information to standard output.
  static func printVersion() {
    self.write(self.versionText + "\n", to: .standardOutput)
  }

  // Report an invalid command line, followed by the usage, to standard error.
  static func reportUsageError(_ error: CommandLineError) {
    self.write("time-arc-service: \(self.describe(error))\n\n" + self.helpText, to: .standardError)
  }

  // Report a command that is recognized but not implemented yet.
  static func reportUnimplemented(_ command: ServiceCommand) {
    self.write("time-arc-service: \(command.name) is not implemented yet.\n", to: .standardError)
  }

  // The version line shared by the version command and the usage header.
  private static var versionText: String {
    "TimeArc Service \(self.version) on \(self.platform)"
  }

  // The usage text documented in src/service/README.md.
  private static var helpText: String {
    """
    \(self.versionText)

    Usage:
      time-arc-service [run]
      time-arc-service enable
      time-arc-service disable
      time-arc-service start
      time-arc-service stop
      time-arc-service restart
      time-arc-service status [--text|--json] [--verbose]
      time-arc-service doctor [--text|--json] [--verbose]
      time-arc-service help|-h|--help
      time-arc-service version|-v|--version

    Options:
      --text      Render the report as text. This is the default.
      --json      Render the report as JSON.
      --verbose   Include additional details in the report.

    """
  }

  // Describe a parsing failure in a single sentence.
  private static func describe(_ error: CommandLineError) -> String {
    switch error {
    case .unknownCommand(let command):
      return "unknown command '\(command)'."
    case .unknownOption(let option):
      return "unknown option '\(option)'."
    case .unexpectedArgument(let argument):
      return "unexpected argument '\(argument)'."
    case .repeatedOption(let option):
      return "repeated option '\(option)'."
    case .conflictingFormat:
      return "'--text' and '--json' cannot be combined."
    }
  }

  // Write a message to the given file handle.
  private static func write(_ message: String, to handle: FileHandle) {
    handle.write(Data(message.utf8))
  }
}
