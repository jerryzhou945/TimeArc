// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import CoreAudio
import Foundation

// Probe the audio processes for the system.
struct AudioProcessProbe: AudioProcessProbing {
  // Get the list of PIDs for processes that are currently producing audio output, including all system audio.
  func getAudioProcesses() -> Set<Int32>? {
    // Prefer Core Audio's typed Swift wrappers when they are available.
    if #available(macOS 15.0, *) {
      return getAudioProcessesUsingSwiftAPI()
    }

    // Older systems expose the same information through HAL property calls.
    return getAudioProcessesUsingLegacyAPI()
  }

  // Use the Swift API to get the list of audio processes.
  @available(macOS 15.0, *)
  private func getAudioProcessesUsingSwiftAPI() -> Set<Int32>? {
    guard let processes = try? AudioHardwareSystem.shared.processes else {
      return nil
    }

    // A process can disappear between enumeration and property access, so skip failures.
    let pids: Set<Int32> = Set(
      processes.compactMap { process in
        guard (try? process.isRunningOutput) == true else {
          return nil
        }

        return try? process.pid
      })
    return pids.isEmpty ? nil : pids
  }

  // Use the legacy HAL API to get the list of audio processes.
  private func getAudioProcessesUsingLegacyAPI() -> Set<Int32>? {
    // First query the byte count needed for the process AudioObjectID list.
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyProcessObjectList,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0

    guard
      AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &dataSize
      ) == noErr
    else {
      return nil
    }

    let objectSize = MemoryLayout<AudioObjectID>.stride
    let processCount = Int(dataSize) / objectSize
    guard processCount > 0 else {
      return nil
    }

    var processObjects = [AudioObjectID](
      repeating: kAudioObjectUnknown,
      count: processCount
    )
    let status = processObjects.withUnsafeMutableBytes { buffer in
      AudioObjectGetPropertyData(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &dataSize,
        buffer.baseAddress!
      )
    }
    guard status == noErr else {
      return nil
    }

    // The returned size may shrink if a process exits while the list is being read.
    let returnedProcessCount = min(Int(dataSize) / objectSize, processObjects.count)
    let pids: Set<Int32> = Set(
      processObjects.prefix(returnedProcessCount).compactMap {
        processObject -> Int32? in
        guard isRunningOutput(processObject) else {
          return nil
        }

        return pid(for: processObject)
      }
    )
    return pids.isEmpty ? nil : pids
  }

  // Check if the given process object is currently producing audio output.
  private func isRunningOutput(_ processObject: AudioObjectID) -> Bool {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyIsRunningOutput,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: UInt32 = 0
    var dataSize = UInt32(MemoryLayout.size(ofValue: value))

    let status = AudioObjectGetPropertyData(
      processObject,
      &address,
      0,
      nil,
      &dataSize,
      &value
    )
    return status == noErr && value != 0
  }

  // Get the PID for the given process object.
  private func pid(for processObject: AudioObjectID) -> Int32? {
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioProcessPropertyPID,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMain
    )
    var value: pid_t = 0
    var dataSize = UInt32(MemoryLayout.size(ofValue: value))

    let status = AudioObjectGetPropertyData(
      processObject,
      &address,
      0,
      nil,
      &dataSize,
      &value
    )
    return status == noErr ? Int32(value) : nil
  }
}
