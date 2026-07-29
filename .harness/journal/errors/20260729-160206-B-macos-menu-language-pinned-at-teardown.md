# Error Report - macos-menu-language-pinned-at-teardown

## Metadata

- Level: **L2**
- Track: **B**
- Topic: macos-menu-language-pinned-at-teardown
- Recorded: 2026-07-29T16:02:06Z
- Session: `../sessions/20260729-0325-B-macos-menu-bar-design.md`
- Platform: macOS
- Tooling: graceful-quit probe + lldb dump of the live NSMenu tree

## 1. What happened

On graceful quit the QML engine outlives SettingsRepository, so DesktopAppShell.languageMode re-evaluated to its zh fallback and fired a change signal; the menu bar pinned AppleLanguages=zh-Hans on the way out. Every second launch after choosing English or Japanese therefore started with AppKit in Chinese.

## 2. Evidence

Three launches, UI language `en`, each ended by the real quit path
(`Qt.quit()`), reading the pinned preference after each exit:

```
start 1: pref at launch (en)  AppKit en      bar: File Edit View Window Help
         pref after graceful quit ("zh-Hans")      <-- written during teardown
start 2: AppKit zh_CN   bar: File 编辑 View Window Help
start 3: AppKit zh_CN   bar: File 编辑 View Window Help
```

After the guard, the same three cycles hold `(en)` / AppKit `en`, and the
Japanese matrix holds `(ja)` / AppKit `ja` with Japanese rows in 編集.

## 3. Root cause

- Immediate cause: `DesktopAppShell.languageMode` is a *binding* on the
  `settingsRepository` context property. On quit the QML engine is torn down
  after that C++ object is gone, the binding re-evaluates to its `"zh"`
  fallback, `languageModeChanged` fires, and the menu bar pinned that value.
- Underlying cause: a shutdown-time binding re-evaluation was treated as a user
  choice, and it wrote persistent state that outlived the process.
- Why the harness/checklists did not prevent it: every earlier verification
  ended the app with `pkill`, which skips QML teardown entirely. The defect
  lives only in the graceful ⌘Q path, which no automated check exercised.

## 4. Fix

- Files changed: `src/services/macos/macos_menu_localizer.{h,cpp}`,
  `tests/macos_menu_bar_static_test.py`
- Short description: `MacMenuLocalizer` latches `shuttingDown_` on
  `QCoreApplication::aboutToQuit` and ignores every later `setLanguage()`.
  Nothing arriving after that point reflects a user choice.
- Commit: not applicable (uncommitted at time of writing)

## 5. Prevention

Persistent state must never be written from a path that can run during
teardown. Two rules worth carrying: bindings on context properties re-evaluate
when those objects die, so their fallbacks resurface as fake user input; and a
verification that kills the process with a signal has not tested quitting.
Exercise the real quit path when the feature writes anything that survives the
process.
