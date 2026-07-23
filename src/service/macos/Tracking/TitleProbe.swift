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
  func getWindowTitle(for pid: Int32) -> String? {
    guard let applicationElement = applicationElement(for: pid),
      let focusedWindow: AXUIElement = attribute(
        of: applicationElement,
        named: kAXFocusedWindowAttribute as CFString
      ),
      let title: String = attribute(
        of: focusedWindow,
        named: kAXTitleAttribute as CFString
      )
    else {
      return nil
    }

    return meaningfulText(from: title)
  }

  // Probe the audio title for a given PID.
  func getAudioTitle(for pid: Int32) -> String? {
    guard let applicationElement = applicationElement(for: pid),
      let texts = searchForMediaTitle(in: applicationElement).resolvedTexts
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
  private func attribute<T>(of element: AXUIElement, named name: CFString) -> T? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name, &value) == .success else {
      return nil
    }

    return value as? T
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
  private func searchForMediaTitle(in element: AXUIElement) -> MediaTitleSearchResult {
    var visitedElements = 0
    return self.searchForMediaTitle(
      in: element,
      depth: 0,
      visitedElements: &visitedElements
    )
  }

  // Search an accessibility subtree while respecting deterministic traversal limits.
  private func searchForMediaTitle(
    in element: AXUIElement,
    depth: Int,
    visitedElements: inout Int
  ) -> MediaTitleSearchResult {
    guard depth < Self.maximumMediaTitleTraversalDepth,
      visitedElements < Self.maximumMediaTitleVisitedElements
    else {
      return MediaTitleSearchResult(
        hasPlaybackControl: false,
        texts: [],
        resolvedTexts: nil
      )
    }
    visitedElements += 1

    let role: String? = attribute(of: element, named: kAXRoleAttribute as CFString)
    var texts: [String] = []

    if role == kAXStaticTextRole as String {
      let value: String? = attribute(of: element, named: kAXValueAttribute as CFString)
      let title: String? = attribute(of: element, named: kAXTitleAttribute as CFString)

      if let text = meaningfulText(from: value ?? title) {
        texts.append(text)
      }
    }

    let controlStrings: [String] = [
      attribute(of: element, named: kAXTitleAttribute as CFString) as String?,
      attribute(of: element, named: kAXValueAttribute as CFString) as String?,
      attribute(of: element, named: kAXDescriptionAttribute as CFString) as String?,
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

    let canDescend =
      depth + 1 < Self.maximumMediaTitleTraversalDepth
      && visitedElements < Self.maximumMediaTitleVisitedElements
    let children: [AXUIElement] =
      canDescend
      ? attribute(of: element, named: kAXChildrenAttribute as CFString) ?? []
      : []

    for child in children {
      guard visitedElements < Self.maximumMediaTitleVisitedElements else {
        break
      }

      let result = searchForMediaTitle(
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
