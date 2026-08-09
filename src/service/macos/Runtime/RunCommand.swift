// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Run the tracking service in the foreground until a stop signal arrives.
struct RunCommand {
  // Execute the run command and report the process exit code.
  func execute() -> ServiceExitCode {
    ServiceRuntime().run()
  }
}
