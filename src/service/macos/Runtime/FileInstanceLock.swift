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
