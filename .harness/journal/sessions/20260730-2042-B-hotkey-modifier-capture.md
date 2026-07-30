# 20260730-2042-B-hotkey-modifier-capture

## Metadata

- Author: Claude Code (Opus 5) · Track **B (Feature)** · 2026-07-30 20:42 (local)
- Branch: `development/macos-support`
- Goal: let the settings 快捷键 键帽 capture modifier combinations, not one letter.

## 1. Frozen files touched

None. `DesktopProfilePage.qml`, `DesktopAppShell.qml`, `MacMenuBar.qml`,
`components/I18n.js`, `docs/settings-remaining-work.md`.

## 2. Two-sided design

- **Service side:** nothing. No sampling source, no `usage_config.json` key, no schema
  or `data_bridge.h` touch, no IPC. `time-arc-service` unaffected and not rebuilt — the
  hotkeys live in GUI `timearc.db` KV, which it never reads.
- **UI side:** `KeyCaptureChip` emits a Qt portable sequence (`"Ctrl+Shift+K"`) instead
  of a letter. `setHotkey` owns policy: reject reserved sequences and the sibling
  hotkey, else canonicalize → write KV → `hotkeysChanged()` →
  `applyHotkeysFromSettings()` rebinds the shell's two `Shortcut`s. A bare `"N"` is
  already a valid `QKeySequence`, so `sequences: [root.memoHotkeyKey]` is **unchanged**
  and stored values need no migration. `doImport` now also emits `hotkeysChanged()` — it
  re-read the KV but never told the shell.

## 3. Decisions

- **Base key stays A–Z** — `Shift`+digit reports punctuation on most layouts (`Shift+2`
  → `Qt.Key_At`). Bare modifier keydowns need no case: `Qt.Key_Shift` is `0x01000020`,
  already outside the A–Z range check.
- **Universal reserved list**, not platform-scoped: `⌘Q`/`⌘W`/`⌘M` are free on
  Windows/Linux, but one list keeps exports portable and card copy to one rule.
- **Reject, stay capturing.** `setHotkey`'s bool return *is* the "leave capture" signal
  and the delegate must act on it — the chip's `capturing` is the single switch. First
  cut had the page clear its own `capturingHotkey` instead; the page has no handle on
  the chip, so the chip stayed lit and ate every later key.
- **macOS menu bar goes inert during capture.** AppKit performs an `NSMenu` key
  equivalent before the window sees the event and `Keys.onShortcutOverride` cannot stop
  it — without this, capture-mode `⌘Q` **quits the app**. A disabled `NSMenuItem` does
  not consume its key equivalent, so the key falls through and toasts. Edit menu needed
  nothing: focus is on the chip, not a text control, so `editorCanXxx` is already false.

## 4. Constraint probed

`Shortcut.portableText` (Qt 6.11.1, cocoa) canonicalizes modifiers as
**Meta+Ctrl+Alt+Shift**, not the order the code writes — `"Ctrl+Meta+F"` comes back as
`"Meta+Ctrl+F"`. Raw-string comparison against the hand-written reserved table would
therefore miss; both sides go through `_canonSeq`. `nativeText` (`⌃⌘F`, `⌃⌥⇧⌘K`) agrees
with `hotkeyDisplay` on every case tested, which pinned the ⌃⌥⇧⌘ display order.

## 5. Known limitations (deliberate)

- `⌃⌘F` is also the key equivalent of macOS's injected 进入全屏幕 row — not Qt's to
  disable, so it toggles full screen instead of toasting. Ditto OS keys the app never
  receives (`⌘Tab`, `⌘Space`).
- `reservedHotkeys` hand-mirrors three sites (`MacMenuBar.qml`, `main.qml:163`,
  `MemoOverlay.qml:619`); nothing enforces sync. Fix is the `KeyMap.js` table in
  `docs/desktop-keyboard-navigation-design.md` §4.1 — seeding it now, while `MacMenuBar`
  still hardcodes its rows, would make a *third* home for key definitions, so it waits
  for that design's phase 1.

## 6. Verification

`preflight.py --track B` clean. `build.py` success (`build-logs/20260730-210531`) — all
three QML files through `qmlcachegen`, no warnings. App launched, zero QML runtime
warnings; `scan_qt_log.py` recorded 2 L2s, both **pre-existing and unrelated** (unsigned
dev-build LaunchAgent codesigning, AppKit language pinning). `qmllint` vs the `git show
HEAD:` baseline adds exactly 3 `[unqualified]` on `modelData`/`ml` (file already has 219
by design) and 1 `[missing-property]` for `pageLoader.item.hotkeyCapturing` — same shape
as the 14 existing ones, `locked` on the copied-from `memoLocked` line among them.

Helpers, `setHotkey` and the capture state machine were extracted **verbatim from
source** into scratchpad QML harnesses (only substitution: `I18n.menu` → `i18nMenu`, QML
forbids uppercase property names) and run under `qml`: 47 assertions, all pass —
modifier masking (`KeypadModifier` ignored), `_canonSeq` order independence, reserved
hits via reordered spellings (`Shift+Ctrl+Z` → 重做), bare letters free, macOS glyph
order, the capture-ownership race, and the full capture→set→close flow with a mock chip
wired like the delegate. A control run of that flow against the old wiring fails 7 of
them, so it is not vacuous.

## 7. Manual smoke path (owed — NOT run)

GUI automation is unauthorized here (`osascript` → `-1743`) and the simulator tooling
cannot drive a macOS window, so none of this was executed. Settings → 备忘与番茄钟 →
快捷键. The checks that would catch a real regression: while capturing, `⌘Q` **must not
quit** (toast names 退出 TimeArc, chip stays capturing) and `⌘Z` must toast rather than
undo. Also bare `K` binds, `Esc` cancels, `⇧⌘K` survives a page reopen, en/ja translated.

## 8. Rule / doc updates

`docs/settings-remaining-work.md` rows 97/103 record the sequence format, combination
support and the reserved table; stale `DesktopAppShell.qml` refs fixed (`:257`→`:398`,
`:232/233`→`:318/319`). Row 104's 🟡 **unchanged** — Del/Esc/Wheel stay display-only. No
`rules/0X` claim changed; rule 04 §3 followed (new strings have `en`+`ja`; the two
Chinese-only conflict toasts are now translated).

## 9. Outcome

**Code complete, smoke path outstanding** — logic verified by harness, screen not.
