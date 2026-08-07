// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// Send one control request to a running instance and read its answer.
struct ControlClient: ControlClienting {
  // Connect, send, read, close. A refused connection means no instance is
  // listening, which callers treat as "not running" rather than an error.
  func send(_ request: ControlRequest) throws(ControlError) -> ControlResponse {
    let path = ServiceConfigurationPath.controlSocket.path
    let address = try ControlSocket.address(for: path)

    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
      throw ControlError.socketUnavailable
    }
    defer { close(descriptor) }

    ControlSocket.setTimeout(descriptor)
    let connected = ControlSocket.withSockAddr(address) { pointer, length in
      connect(descriptor, pointer, length)
    }
    guard connected == 0 else {
      throw ControlError.notListening
    }

    guard ControlSocket.writeMessage(descriptor, ControlWire.encode(request)) else {
      throw ControlError.timedOut
    }
    guard let data = ControlSocket.readMessage(descriptor) else {
      throw ControlError.timedOut
    }
    guard let response = ControlWire.decodeResponse(data) else {
      throw ControlError.malformedResponse
    }
    return response
  }
}
