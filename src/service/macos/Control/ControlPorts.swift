// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Foundation

// A request sent to a running service instance over the control channel.
//
// CHARTER v0.14 permits this channel between `time-arc-service` instances only.
// It is never a UI channel: the UI drives the service through its CLI, and the
// server rejects any peer that is not this same executable.
enum ControlRequest: String, Equatable, Sendable {
  // Ask whether an instance is listening. Used for readiness and liveness.
  case ping

  // Ask the instance to flush its open sessions and exit successfully.
  case stop
}

// The outcome of a control request.
struct ControlResponse: Equatable, Sendable {
  // Whether the instance accepted and performed the request.
  let ok: Bool

  // The command echoed back, so a caller can match response to request.
  let command: String

  // A machine-readable failure reason when `ok` is false.
  let error: String?

  // Report success for a request.
  static func success(_ request: ControlRequest) -> ControlResponse {
    ControlResponse(ok: true, command: request.rawValue, error: nil)
  }

  // Report a request this build does not implement. Returning a response rather
  // than closing the connection is what lets a newer peer probe an older one.
  static func unsupported(_ command: String) -> ControlResponse {
    ControlResponse(ok: false, command: command, error: "unsupported_command")
  }
}

// The error types for the control channel.
enum ControlError: Error, Equatable, Sendable {
  // No instance is listening on the socket.
  case notListening

  // The socket path does not fit in the platform's sockaddr_un.
  case socketPathTooLong

  // The socket could not be created, bound, or listened on.
  case socketUnavailable

  // The peer did not answer within the timeout.
  case timedOut

  // The peer answered with something this build cannot parse.
  case malformedResponse
}

// Serve control requests for the lifetime of a running instance.
protocol ControlServing {
  func start(_ handle: @escaping (ControlRequest) -> ControlResponse) throws(ControlError)
  func stop()
}

// Send a single control request to a running instance.
protocol ControlClienting {
  func send(_ request: ControlRequest) throws(ControlError) -> ControlResponse
}

// The wire format: one JSON object per line, versioned so a future field or
// command can be added without breaking an older peer.
enum ControlWire {
  // The schema version this build speaks.
  static let schemaVersion = 1

  // The maximum accepted message size. A control message is a few dozen bytes;
  // anything larger is a peer that has lost the plot, not a request.
  static let maximumMessageBytes = 64 * 1024

  // Encode a request as a single line.
  static func encode(_ request: ControlRequest) -> Data {
    let object: [String: Any] = [
      "schema_version": self.schemaVersion,
      "command": request.rawValue,
    ]
    return self.line(from: object)
  }

  // Encode a response as a single line.
  static func encode(_ response: ControlResponse) -> Data {
    var object: [String: Any] = [
      "schema_version": self.schemaVersion,
      "ok": response.ok,
      "command": response.command,
    ]
    if let error = response.error {
      object["error"] = error
    }
    return self.line(from: object)
  }

  // Decode a request line. An unknown command decodes to its raw string so the
  // server can answer `unsupported_command` instead of dropping the connection.
  static func decodeRequest(_ data: Data) -> (request: ControlRequest?, command: String)? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let command = object["command"] as? String
    else {
      return nil
    }
    return (ControlRequest(rawValue: command), command)
  }

  // Decode a response line.
  static func decodeResponse(_ data: Data) -> ControlResponse? {
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let ok = object["ok"] as? Bool,
      let command = object["command"] as? String
    else {
      return nil
    }
    return ControlResponse(ok: ok, command: command, error: object["error"] as? String)
  }

  // Serialize one JSON object followed by the newline delimiter.
  private static func line(from object: [String: Any]) -> Data {
    guard var data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    else {
      return Data("{}\n".utf8)
    }
    data.append(0x0A)
    return data
  }
}
