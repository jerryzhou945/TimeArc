// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// Resolve the control file location.
//
// This mirrors `build_config_path` in `src/service/shared/database_path.c`,
// whose helpers are static and therefore unavailable to Swift. The literals are
// kept in this one file so the duplication stays auditable, and
// `tests/macos_service_config_static_test.py` asserts they still match the C
// side. If another platform needs the same path, export `get_config_path` from
// the shared C layer instead of copying this file.
enum ServiceConfigurationPath {
  // The environment variable that redirects the control file, used by tests so
  // they never touch the real user profile.
  static let overrideVariable = "TIMEARC_SERVICE_CONFIG"

  // The application directory inside the platform configuration base.
  private static let applicationDirectory = "TimeArc"

  // The configuration directory inside the application directory.
  private static let configurationDirectory = "config"

  // The control file name.
  private static let fileName = "service_config.json"

  // The lock file name, kept beside the control file because that directory is
  // fixed while the database directory is user-redirectable.
  private static let lockFileName = "time-arc-service.lock"

  // The control socket name. It lives beside the lock for the same reason, and
  // because holding the lock is what entitles an instance to own the socket.
  private static let socketFileName = "time-arc-service.sock"

  // Whether the control file has been redirected away from its canonical
  // location. A redirected caller wants the instance that reads *that* file,
  // which is never the one launchd starts: a launchd job does not inherit this
  // process's environment.
  static var isRedirected: Bool {
    (ProcessInfo.processInfo.environment[self.overrideVariable] ?? "").isEmpty == false
  }

  // The control file path, honoring the test redirect.
  static var configurationFile: URL {
    if let override = ProcessInfo.processInfo.environment[self.overrideVariable],
      !override.isEmpty
    {
      return URL(fileURLWithPath: override)
    }
    return self.directory.appendingPathComponent(self.fileName)
  }

  // The instance lock file path.
  static var lockFile: URL {
    self.directory.appendingPathComponent(self.lockFileName)
  }

  // The control socket path. Unix socket paths are limited to 104 bytes on this
  // platform, which the control layer checks before binding.
  static var controlSocket: URL {
    self.directory.appendingPathComponent(self.socketFileName)
  }

  // The directory holding the control file. When the control file is redirected
  // the lock follows it, so a redirected test run cannot block the real service.
  static var directory: URL {
    if let override = ProcessInfo.processInfo.environment[self.overrideVariable],
      !override.isEmpty
    {
      return URL(fileURLWithPath: override).deletingLastPathComponent()
    }
    return
      self.home
      .appendingPathComponent("Library")
      .appendingPathComponent("Application Support")
      .appendingPathComponent(self.applicationDirectory)
      .appendingPathComponent(self.configurationDirectory)
  }

  // The home directory, read from the environment exactly as the C resolver
  // does with getenv("HOME"). Reading it any other way would let the two
  // processes resolve different directories for the same install.
  private static var home: URL {
    guard let home = ProcessInfo.processInfo.environment["HOME"], !home.isEmpty else {
      return FileManager.default.homeDirectoryForCurrentUser
    }
    return URL(fileURLWithPath: home)
  }
}
