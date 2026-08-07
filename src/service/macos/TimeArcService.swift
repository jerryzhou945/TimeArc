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
    case .start:
      return StartCommand().execute()
    case .stop:
      return StopCommand().execute()
    case .restart:
      // Restart is the composition of the two, not a third code path: stop
      // waits for the flush, so start always sees a released lock and socket.
      let stopped = StopCommand().execute()
      guard stopped == .success else {
        return stopped
      }
      return StartCommand().execute()
    case .enable:
      return EnableCommand().execute()
    case .disable:
      return DisableCommand().execute()
    case .help:
      ServiceUsage.printHelp()
      return .success
    case .version:
      ServiceUsage.printVersion()
      return .success
    case .status, .doctor:
      // These commands need the diagnostics slice, which is not implemented yet.
      ServiceUsage.reportUnimplemented(command)
      return .internalError
    }
  }
}
