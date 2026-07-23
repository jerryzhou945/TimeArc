// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Jeff Zhang

import ApplicationServices
import Foundation

// Probe the title of a window or media.
struct TitleProbe: WindowTitleProbing, AudioTitleProbing {
  private static let maximumMediaTitleTraversalDepth = 32
  private static let maximumMediaTitleVisitedElements = 512

  // Carry the state produced while recursively searching an accessibility subtree.
  private struct MediaTitleSearchResult {
    // Whether the subtree contains a recognized playback control.
    let hasPlaybackControl: Bool

    // Meaningful static text collected from the subtree.
    let texts: [String]

    // Deduplicated text from the smallest subtree containing text and playback controls.
    let resolvedTexts: [String]?
  }

  // Probe the window title for a given PID.
  func getWindowTitle(for pid: Int32) throws(TrackingError) -> String? {
    guard let applicationElement = applicationElement(for: pid),
      let focusedWindow: AXUIElement = try attribute(
        of: applicationElement,
        named: kAXFocusedWindowAttribute as CFString
      ),
      let title: String = try attribute(
        of: focusedWindow,
        named: kAXTitleAttribute as CFString
      )
    else {
      return nil
    }
    return meaningfulText(from: title)
  }

  // Probe the audio title for a given PID.
  func getAudioTitle(for pid: Int32) throws(TrackingError) -> String? {
    guard let applicationElement = applicationElement(for: pid),
      let searchResult = try? searchForMediaTitle(in: applicationElement),
      let texts = searchResult.resolvedTexts
    else {
      return nil
    }
    return texts.joined(separator: " - ")
  }

  // Create an accessibility application element for a valid PID.
  private func applicationElement(for pid: Int32) -> AXUIElement? {
    guard pid > 0 else {
      return nil
    }
    return AXUIElementCreateApplication(pid)
  }

  // Read and cast an accessibility attribute from an element.
  private func attribute<T>(of element: AXUIElement, named name: CFString)
    throws(TrackingError) -> T?
  {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, name, &value)
    switch result {
    case .noValue, .attributeUnsupported, .invalidUIElement:
      return nil
    case .success:
      guard let value else {
        throw TrackingError.accessibilityTitleUnavailable
      }
      guard let typedValue = value as? T else {
        throw TrackingError.accessibilityTitleUnavailable
      }
      return typedValue
    default:
      throw TrackingError.accessibilityTitleUnavailable
    }
  }

  // Trim a string and reject values containing only whitespace.
  private func meaningfulText(from text: String?) -> String? {
    guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty
    else {
      return nil
    }
    return text
  }

  // Find the smallest subtree containing playback controls and meaningful static text.
  private func searchForMediaTitle(in element: AXUIElement)
    throws(TrackingError) -> MediaTitleSearchResult
  {
    var visitedElements = 0
    return try self.searchForMediaTitle(
      in: element,
      depth: 0,
      visitedElements: &visitedElements
    )
  }

  // Search an accessibility subtree while respecting deterministic traversal limits.
  private func searchForMediaTitle(in element: AXUIElement, depth: Int, visitedElements: inout Int)
    throws(TrackingError) -> MediaTitleSearchResult
  {
    guard depth < Self.maximumMediaTitleTraversalDepth,
      visitedElements < Self.maximumMediaTitleVisitedElements
    else {
      throw TrackingError.accessibilityTitleUnavailable
    }
    visitedElements += 1

    let role: String? = try attribute(of: element, named: kAXRoleAttribute as CFString)
    var texts: [String] = []
    if role == kAXStaticTextRole as String {
      let value: String? = try attribute(of: element, named: kAXValueAttribute as CFString)
      let title: String? = try attribute(of: element, named: kAXTitleAttribute as CFString)
      if let text = meaningfulText(from: value) ?? meaningfulText(from: title) {
        texts.append(text)
      }
    }

    let controlStrings: [String] = [
      try attribute(of: element, named: kAXTitleAttribute as CFString) as String?,
      try attribute(of: element, named: kAXValueAttribute as CFString) as String?,
      try attribute(of: element, named: kAXDescriptionAttribute as CFString) as String?,
    ].compactMap { $0?.lowercased() }
    let playbackControls: Set<String> = [
      "play",
      "pause",
      "next",
      "next track",
      "previous",
      "previous track",
    ]

    var hasPlaybackControl = controlStrings.contains {
      playbackControls.contains($0)
    }
    let children: [AXUIElement] =
      try attribute(of: element, named: kAXChildrenAttribute as CFString) ?? []
    for child in children {
      guard depth + 1 < Self.maximumMediaTitleTraversalDepth,
        visitedElements < Self.maximumMediaTitleVisitedElements
      else {
        throw TrackingError.accessibilityTitleUnavailable
      }
      let result = try searchForMediaTitle(
        in: child,
        depth: depth + 1,
        visitedElements: &visitedElements
      )
      if let resolvedTexts = result.resolvedTexts {
        return MediaTitleSearchResult(
          hasPlaybackControl: false,
          texts: [],
          resolvedTexts: resolvedTexts
        )
      }
      hasPlaybackControl = hasPlaybackControl || result.hasPlaybackControl
      texts.append(contentsOf: result.texts)
    }

    guard hasPlaybackControl, !texts.isEmpty else {
      return MediaTitleSearchResult(
        hasPlaybackControl: hasPlaybackControl,
        texts: texts,
        resolvedTexts: nil
      )
    }

    var seen = Set<String>()
    let uniqueTexts = texts.filter { seen.insert($0).inserted }
    return MediaTitleSearchResult(
      hasPlaybackControl: hasPlaybackControl,
      texts: texts,
      resolvedTexts: uniqueTexts
    )
  }
}
