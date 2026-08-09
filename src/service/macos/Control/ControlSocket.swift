// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Foundation

// The socket plumbing shared by the control server and client: address
// construction, framed reads, and complete writes.
enum ControlSocket {
  // How long either side waits for the other to finish a message.
  static let timeoutSec = 5

  // Build the unix address for a path, refusing one that does not fit rather
  // than binding a silently truncated path.
  static func address(for path: String) throws(ControlError) -> sockaddr_un {
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

    let bytes = Array(path.utf8)
    let capacity = MemoryLayout.size(ofValue: address.sun_path)
    guard bytes.count < capacity else {
      throw ControlError.socketPathTooLong
    }

    withUnsafeMutablePointer(to: &address.sun_path) { field in
      field.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
        for (index, byte) in bytes.enumerated() {
          destination[index] = CChar(bitPattern: byte)
        }
        destination[bytes.count] = 0
      }
    }
    return address
  }

  // Run a socket call that needs the address as a generic sockaddr.
  static func withSockAddr<T>(_ address: sockaddr_un, _ body: (UnsafePointer<sockaddr>, socklen_t) -> T)
    -> T
  {
    var value = address
    return withUnsafePointer(to: &value) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { generic in
        body(generic, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
  }

  // Bound the time a peer can hold a descriptor open mid-message, so one stuck
  // client cannot stall the instance that is also sampling on this queue.
  static func setTimeout(_ descriptor: Int32) {
    var timeout = timeval(tv_sec: self.timeoutSec, tv_usec: 0)
    let size = socklen_t(MemoryLayout<timeval>.size)
    setsockopt(descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout, size)
    setsockopt(descriptor, SOL_SOCKET, SO_SNDTIMEO, &timeout, size)
  }

  // Read one newline-delimited message, without its delimiter.
  static func readMessage(_ descriptor: Int32) -> Data? {
    var message = Data()
    var byte: UInt8 = 0
    while message.count < ControlWire.maximumMessageBytes {
      let count = read(descriptor, &byte, 1)
      if count == 1 {
        if byte == 0x0A {
          return message
        }
        message.append(byte)
        continue
      }
      // A closed peer that already sent a complete message without the
      // delimiter is still readable; anything else is a failure.
      return count == 0 && !message.isEmpty ? message : nil
    }
    return nil
  }

  // Write a message in full, tolerating short writes.
  @discardableResult
  static func writeMessage(_ descriptor: Int32, _ data: Data) -> Bool {
    var remaining = data[...]
    while !remaining.isEmpty {
      let written = remaining.withUnsafeBytes { buffer in
        write(descriptor, buffer.baseAddress, buffer.count)
      }
      guard written > 0 else {
        return false
      }
      remaining = remaining.dropFirst(written)
    }
    return true
  }
}
