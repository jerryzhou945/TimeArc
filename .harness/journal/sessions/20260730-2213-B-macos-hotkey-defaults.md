# 20260730-2213-B-macos-hotkey-defaults

## Metadata

- Author: Claude Code (Opus 5) · Track **B (Feature)** · 2026-07-30 22:13 (local)
- Branch: `development/macos-support`
- Goal: macOS factory default for the memo / pomodoro hotkeys becomes ⇧⌘N / ⇧⌘P; other
  platforms keep bare N / P. Follows `20260730-2042-B-hotkey-modifier-capture`.

## 1. Frozen files touched

None. New file `qml/desktop/components/Hotkeys.js` (+ one line in the non-frozen
`qml/CMakeLists.txt`, per rule 05). Edited: `DesktopAppShell.qml`,
`DesktopProfilePage.qml`, `components/I18n.js`, `README.md`, three `docs/`.

## 2. Two-sided design

- **Service side:** nothing. No sampling source, no `usage_config.json` key, no schema
  or `data_bridge.h` touch, no IPC. `time-arc-service` not rebuilt.
- **UI side:** `Hotkeys.memoDefault()` / `pomodoroDefault()` return `"Ctrl+Shift+N"` /
  `"Ctrl+Shift+P"` on `Qt.platform.os === "osx"`, else `"N"` / `"P"`. Both consumers
  read that one source: the shell (property initializer + `getValue` fallback in
  `applyHotkeysFromSettings`) and the settings page (initializer + `_getStr` fallback in
  `reloadFromKV`). Stored values are untouched, so existing installs keep whatever they
  had — this only changes what a key with no KV row resolves to.

## 3. Decisions

- **A shared `.pragma library`, not a literal in each file.** Two consumers must agree;
  if they drift the symptom is "settings page shows N while ⇧⌘N is what actually fires"
  — the same split-ownership bug class as the capture-state defect fixed earlier today.
  Probed first that `.pragma library` can read `Qt.platform` (it can). This is a
  different situation from the `KeyMap.js` question in the previous session, which had
  one consumer and would have added a third home.
- **Reserved table gains a `cmd` field.** ⇧⌘N/⇧⌘P were flatly reserved, so the new
  default was a value the UI refused to set — the settings page would have been
  rejecting the factory setting. An entry whose `cmd` equals the hotkey being edited is
  now allowed: memo may take ⇧⌘N, pomodoro may not, and vice versa. Cross-assignment
  stays refused because the macOS menu row would win anyway and the binding would be
  dead.
- **Delete / Backspace on the key cap disables the hotkey** — stores `""`, which the
  shell already reads as "don't bind" (`sequences: [] `, `enabled: false`), and
  `SettingsRepository::getValue` returns a stored empty string rather than falling back,
  so it survives a restart. Verified both in the C++ before relying on it. On macOS it
  restores the factory key instead — the menu row owns that key equivalent regardless,
  so a stored `""` would read 未设置 in the UI while the key kept working. The toast
  reports only the result (已恢复默认 ⇧⌘N / Restored the default ⇧⌘N / 既定の ⇧⌘N
  に戻しました); the reason lives in `Hotkeys.canDisable()` rather than in one line of
  UI. Empty skips the reserved and sibling checks — otherwise disabling *both* hotkeys
  trips "conflicts with the other" (`"" === ""`).
- **`memo_hotkey_n` removed entirely, all platforms** (user decision). It was the escape
  hatch for a bare letter stealing keystrokes; with modifiers available and ⇧⌘N shipping
  as the macOS default there is nothing to escape. It had also become a lie on macOS:
  the menu row 显示 › 备忘黑板 carries ⇧⌘N and was deliberately not gated on the
  preference, so switching it off would not have stopped the key. The memo `Shortcut` is
  now guarded only by `memoLocked`, matching pomodoro.

## 4. Migration / leftovers

Existing databases keep a `memo_hotkey_n` row, now read by nobody — an inert orphan,
deliberately not deleted (a KV migration for one dead boolean costs more than it saves).
Anyone re-adding that key must know it may hold a stale value.

## 5. Verification

`build.py` success (`build-logs/20260730-222921`), zero warnings, `Hotkeys.js` in the QML
resource, no residual `memo_hotkey_n` refs outside two explanatory comments.

Extraction harness re-run with the real `Hotkeys.js` imported and `setHotkey` lifted
verbatim (only substitution: `I18n.menu` → `i18nMenu`): 17 assertions, all pass —
platform defaults and their ⇧⌘N/⇧⌘P display, `_reservedOwner` allowing each command its
own built-in key while refusing the sibling's, and the round trip "set to default →
rebind elsewhere → set back to default" succeeding, which is the case the flat reserved
table used to break.

The disable branch runs twice: once against the real module, and once against a copy
whose two platform predicates are rewritten to simulate Windows/Linux (rest verbatim) —
this machine can only be macOS, and the disable path *is* the non-macOS behavior. Both
pass: macOS restores ⇧⌘N; elsewhere the key cap reads 未设置, KV holds `""`, both
hotkeys can be off at once, and a later rebind still works. Toast wording was checked by
driving the real `I18n.js` through zh/en/ja rather than reading the tables. The dedupe
session's two i18n static tests still pass, and the earlier `ChipFlow` / `DefaultsFlow`
suites remain green.

**Not run:** the on-screen walk (GUI automation unauthorized here, `osascript` →
`-1743`). Still owed, now including: fresh profile on macOS shows ⇧⌘N/⇧⌘P in the key
caps and both actually toggle; the 备忘与番茄钟 card no longer shows a 「按 …
打开备忘录」 switch; the hotkey works with no preference gating it.

## 6. Rule / doc updates

`README.md` two spots (macOS menu-bar paragraph; settings feature list). Both
`docs/settings-remaining-work.md` hotkey rows updated. `settings-implementation-issues.md`
and `settings-functional-replication.md` are v88 replication specs — `memo_hotkey_n` items
struck through with a "后续撤销" note rather than deleted, since the spec did call for
them and the removal is a later product decision. No `rules/0X` claim changed.

## 7. Outcome

**Code complete, smoke path outstanding** — logic verified by harness, screen not.
