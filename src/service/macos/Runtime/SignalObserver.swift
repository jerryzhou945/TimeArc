// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import Darwin
import Dispatch
import Foundation

// Observe SIGINT and SIGTERM so the service can flush before it exits.
final class SignalObserver: SignalObserving {
  // The signals that request a graceful shutdown.
  private static let signals: [Int32] = [SIGINT, SIGTERM]

  // The active dispatch sources, retained until cancelled.
  private var sources: [DispatchSourceSignal] = []

  // Deliver stop requests on the main queue instead of the default disposition,
  // which would terminate the process before the pending sessions are written.
  func observe(_ onStop: @escaping () -> Void) {
    self.sources = Self.signals.map { signal in
      Darwin.signal(signal, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: signal, queue: .main)
      source.setEventHandler {
        onStop()
      }
      source.activate()
      return source
    }
  }

  // Stop observing the signals.
  func cancel() {
    for source in self.sources {
      source.cancel()
    }
    self.sources = []
  }
}
