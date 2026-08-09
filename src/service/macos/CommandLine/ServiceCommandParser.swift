// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Parse the command line into a command. The parser is total and performs no I/O.
enum ServiceCommandParser {
  // Parse the arguments that follow the executable path.
  static func parse(_ arguments: [String]) -> Result<ServiceCommand, CommandLineError> {
    // launchd starts the bundled agent without arguments, so running is the default.
    guard let verb = arguments.first else {
      return .success(.run)
    }

    // Every command takes its options after the verb.
    let operands = Array(arguments.dropFirst())
    switch verb {
    case "run":
      return self.parse(.run, with: operands)
    case "enable":
      return self.parse(.enable, with: operands)
    case "disable":
      return self.parse(.disable, with: operands)
    case "start":
      return self.parse(.start, with: operands)
    case "stop":
      return self.parse(.stop, with: operands)
    case "restart":
      return self.parse(.restart, with: operands)
    case "status":
      return self.parseReportOptions(operands).map(ServiceCommand.status)
    case "doctor":
      return self.parseReportOptions(operands).map(ServiceCommand.doctor)
    case "help", "-h", "--help":
      return self.parse(.help, with: operands)
    case "version", "-v", "--version":
      return self.parse(.version, with: operands)
    default:
      return .failure(self.isOption(verb) ? .unknownOption(verb) : .unknownCommand(verb))
    }
  }

  // Accept a command that takes no operands.
  private static func parse(_ command: ServiceCommand, with operands: [String])
    -> Result<ServiceCommand, CommandLineError>
  {
    guard let operand = operands.first else {
      return .success(command)
    }
    return .failure(self.isOption(operand) ? .unknownOption(operand) : .unexpectedArgument(operand))
  }

  // Parse the report options shared by the status and doctor commands.
  private static func parseReportOptions(_ operands: [String])
    -> Result<ReportOptions, CommandLineError>
  {
    var format: OutputFormat?
    var verbose = false

    for operand in operands {
      switch operand {
      case "--text", "--json":
        // The two formats exclude each other, and neither may be repeated.
        let requested: OutputFormat = operand == "--json" ? .json : .text
        if let format {
          return .failure(format == requested ? .repeatedOption(operand) : .conflictingFormat)
        }
        format = requested
      case "--verbose":
        guard !verbose else {
          return .failure(.repeatedOption(operand))
        }
        verbose = true
      default:
        return .failure(
          self.isOption(operand) ? .unknownOption(operand) : .unexpectedArgument(operand)
        )
      }
    }

    return .success(ReportOptions(format: format ?? .text, verbose: verbose))
  }

  // Check whether an argument is written as an option rather than a positional value.
  private static func isOption(_ argument: String) -> Bool {
    argument.hasPrefix("-")
  }
}
