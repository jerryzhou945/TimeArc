// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// Guarantee a single collector per user with an advisory file lock, the macOS
// counterpart of the Windows named mutex required by CHARTER I1.
//
// The lock lives beside the control file because that directory is fixed, while
// the database directory is user-redirectable: a lock under the database would
// let two services collect into two different files.
final class FileInstanceLock: InstanceLocking {
  // The locked file descriptor, held for the lifetime of the run.
  private var descriptor: Int32?

  // Take the lock, reporting whether another instance already holds it.
  func acquire() throws(RuntimeError) {
    let directory = ServiceConfigurationPath.directory
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let path = ServiceConfigurationPath.lockFile.path
    let descriptor = open(path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      throw RuntimeError.instanceLockUnavailable
    }

    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      close(descriptor)
      throw RuntimeError.alreadyRunning
    }

    // Record the owner so a later status command can find the running service.
    _ = ftruncate(descriptor, 0)
    let pid = "\(getpid())\n"
    pid.withCString { pointer in
      _ = write(descriptor, pointer, strlen(pointer))
    }
    self.descriptor = descriptor
  }

  // Whether some instance currently holds the lock.
  //
  // This is the authoritative liveness test, and it is deliberately not "does
  // the control socket answer": an instance from a build older than the control
  // channel, or one wedged before it started serving, still holds the lock and
  // is still collecting. Taking the lock and dropping it immediately is
  // race-free in a way that checking a recorded pid is not.
  static func isHeld() -> Bool {
    let descriptor = open(ServiceConfigurationPath.lockFile.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
    guard descriptor >= 0 else {
      return false
    }
    defer { close(descriptor) }

    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
      return true
    }
    flock(descriptor, LOCK_UN)
    return false
  }

  // The pid recorded by the instance that holds the lock, if any. This file's
  // format is owned here, so the signal fallback in `stop` reads it through this
  // accessor rather than parsing the file itself.
  static func holderPid() -> pid_t? {
    guard let contents = try? String(contentsOf: ServiceConfigurationPath.lockFile, encoding: .utf8),
      let pid = pid_t(contents.trimmingCharacters(in: .whitespacesAndNewlines)),
      pid > 0
    else {
      return nil
    }
    return pid
  }

  // Release the lock. Closing the descriptor would be enough, but unlocking
  // first keeps the intent explicit.
  func release() {
    guard let descriptor = self.descriptor else {
      return
    }
    flock(descriptor, LOCK_UN)
    close(descriptor)
    self.descriptor = nil
  }

  deinit {
    self.release()
  }
}
