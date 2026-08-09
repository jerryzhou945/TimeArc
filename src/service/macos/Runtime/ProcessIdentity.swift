// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// Ask the kernel which executable a process is running.
//
// The control channel uses this to accept only another copy of this binary, and
// the launch agent uses it to point a registration at the running executable.
// Both need the kernel's answer rather than argv[0], which a caller controls.
enum ProcessIdentity {
  // libproc's PROC_PIDPATHINFO_MAXSIZE is a macro Swift cannot import.
  private static let pathBufferSize = 4 * Int(MAXPATHLEN)

  // The executable path the kernel reports for a process.
  static func executablePath(of pid: pid_t) -> String? {
    var buffer = [CChar](repeating: 0, count: self.pathBufferSize)
    guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else {
      return nil
    }
    return String(cString: buffer)
  }

  // This process's own executable path.
  static var ownExecutablePath: String? {
    self.executablePath(of: getpid())
  }

  // This process's own executable, which is also the collector binary.
  static var ownExecutableURL: URL? {
    self.ownExecutablePath.map { URL(fileURLWithPath: $0) }
  }
}
