// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// The service entry point. It parses the command line, dispatches the command,
// and reports the exit code. Command behavior belongs to the command types.
@main
struct TimeArcService {
  static func main() {
    let arguments = Array(CommandLine.arguments.dropFirst())
    switch ServiceCommandParser.parse(arguments) {
    case .success(let command):
      exit(self.dispatch(command).rawValue)
    case .failure(let error):
      ServiceUsage.reportUsageError(error)
      exit(ServiceExitCode.usage.rawValue)
    }
  }

  // Execute the parsed command and report its exit code.
  private static func dispatch(_ command: ServiceCommand) -> ServiceExitCode {
    switch command {
    case .run:
      return RunCommand().execute()
    case .help:
      ServiceUsage.printHelp()
      return .success
    case .version:
      ServiceUsage.printVersion()
      return .success
    case .enable, .disable, .start, .stop, .restart, .status, .doctor:
      // These commands need the autostart, configuration, and diagnostics
      // slices, which are not implemented yet.
      ServiceUsage.reportUnimplemented(command)
      return .internalError
    }
  }
}
