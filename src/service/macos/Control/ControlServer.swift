// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Dispatch
import Foundation

// Serve control requests for a running instance.
//
// Requests are accepted and handled on the main queue, the same queue the
// sampling timer runs on. That is deliberate: a request can never interleave
// with a tick, so later commands that report live tracking state need no locking
// and no shared mutable state.
final class ControlServer: ControlServing {
  // The listening descriptor, owned for the lifetime of the run.
  private var listener: Int32?

  // The accept source feeding the main queue.
  private var source: DispatchSourceRead?

  // The bound path, kept so it can be unlinked on stop.
  private var boundPath: String?

  // Start listening. The caller must already hold the instance lock: that is
  // what makes removing a stale socket file safe here.
  func start(_ handle: @escaping (ControlRequest) -> ControlResponse) throws(ControlError) {
    let path = ServiceConfigurationPath.controlSocket.path
    let address = try ControlSocket.address(for: path)

    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
      throw ControlError.socketUnavailable
    }

    // A socket file left by a crashed instance would block bind. No live owner
    // can exist, because this process holds the lock.
    unlink(path)

    let bound = ControlSocket.withSockAddr(address) { pointer, length in
      bind(descriptor, pointer, length)
    }
    guard bound == 0, listen(descriptor, 4) == 0 else {
      close(descriptor)
      throw ControlError.socketUnavailable
    }

    // Same-user only, as the first of three peer defenses.
    chmod(path, S_IRUSR | S_IWUSR)

    let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: .main)
    source.setEventHandler { [weak self] in
      self?.accept(on: descriptor, handle)
    }
    source.activate()

    self.listener = descriptor
    self.source = source
    self.boundPath = path
  }

  // Stop listening and remove the socket file.
  func stop() {
    self.source?.cancel()
    self.source = nil
    if let listener = self.listener {
      close(listener)
      self.listener = nil
    }
    if let boundPath = self.boundPath {
      unlink(boundPath)
      self.boundPath = nil
    }
  }

  deinit {
    self.stop()
  }

  // Accept one connection, answer one request, and close.
  private func accept(on listener: Int32, _ handle: @escaping (ControlRequest) -> ControlResponse) {
    let client = Darwin.accept(listener, nil, nil)
    guard client >= 0 else {
      return
    }
    defer { close(client) }

    guard self.isServiceInstance(client) else {
      return
    }

    ControlSocket.setTimeout(client)
    guard let data = ControlSocket.readMessage(client),
      let decoded = ControlWire.decodeRequest(data)
    else {
      return
    }

    // An unknown command gets a response rather than a dropped connection, so a
    // newer peer can discover what this build supports.
    guard let request = decoded.request else {
      ControlSocket.writeMessage(client, ControlWire.encode(.unsupported(decoded.command)))
      return
    }
    ControlSocket.writeMessage(client, ControlWire.encode(handle(request)))
  }

  // Accept only another copy of this same executable.
  //
  // CHARTER I1 keeps the UI on disk and CLI invocation, never this channel. The
  // socket mode already limits callers to this user; these two checks make the
  // restriction identity-based rather than conventional, so the UI binary is
  // refused even though it runs as the same user.
  private func isServiceInstance(_ client: Int32) -> Bool {
    var peerUid = uid_t()
    var peerGid = gid_t()
    guard getpeereid(client, &peerUid, &peerGid) == 0, peerUid == geteuid() else {
      return false
    }

    var peerPid = pid_t()
    var size = socklen_t(MemoryLayout<pid_t>.size)
    guard getsockopt(client, SOL_LOCAL, LOCAL_PEERPID, &peerPid, &size) == 0 else {
      return false
    }

    // Compare kernel-reported executable paths on both sides. argv[0] would be
    // trivial for a caller to forge; this is not.
    guard let peerPath = ProcessIdentity.executablePath(of: peerPid),
      let ownPath = ProcessIdentity.ownExecutablePath
    else {
      return false
    }
    return peerPath == ownPath
  }
}
