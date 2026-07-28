# 20260729-0229-B-macos-status-bar-menu

## Metadata

- Author: Claude Code (Opus 5)
- Track: **B (Feature)** — new macOS-only status-item capability.
- Date: 2026-07-29 02:29 (local)
- Session goal: rework the macOS status bar menu — open, autostart placeholder,
  quit — localized in all three UI languages.
- Branch: `development/macos-support`
- Predecessor: `20260729-0155-B-macos-close-keeps-app-running.md`

## 1. Frozen files touched

None. The diff is `src/services/macos/macos_status_bar_icon.{h,cpp}` plus one
`attach()` call in `src/main.cpp`; no new source file, so `src/CMakeLists.txt`
is untouched.

## 2. Motivation

The status item carried three rows (`打开 TimeArc`, a permanently disabled
`后台采集继续运行`, `退出 TimeArc`), all hardcoded Chinese. The middle row was a
billboard, not a control — it stated a fact that never changes and cost a slot
in the one menu that, since the red button stopped quitting the app, is the
only route back to a closed window. And the app ships three UI languages
(`language_mode` ∈ `zh|en|ja`, `qml/desktop/components/I18n.js`) that the
status item ignored, so non-Chinese users got Chinese in their menu bar.

## 3. Impact on the other process

| Side     | Effect                                                        |
|----------|---------------------------------------------------------------|
| Producer | None. Nothing under `src/service/` is touched; no sampling, schema, or control-file change. The status menu never talks to the service. |
| Consumer | UI-only. The menu reads one existing UI setting, `language_mode`. |

## 4. Migration plan / 5. Rollback plan

No on-disk impact. `language_mode` is an existing UI-private
`SettingsRepository` key, read here and never written. Rollback is a code
revert of two files plus one `main.cpp` call site.

## 6. Test plan

- `打开 TimeArc` with the window closed → window returns (unchanged path);
  `退出 TimeArc` quits (unchanged path).
- Switch 设置 → 界面语言 to English / 日本語, reopen the menu → all three rows
  are translated, no restart. Autostart row present but disabled in each.
- Windows/Linux untouched — the file is inside the `if(APPLE)` source list.

## 7. Design — two sides

**Service side.** Unchanged. `time-arc-service` keeps sampling regardless of
menu state; the menu offers no service control, deliberately (see §8).

**UI side.** `MacStatusBarIcon` gains `attach(SettingsRepository*)`, called
from `main.cpp` next to the existing `connectToRoot()`. Menu rows are built
once in the constructor and their text is recomputed in a `QMenu::aboutToShow`
handler, which re-reads `language_mode` each time — no language-change signal
has to be plumbed from QML into C++, since the menu is invisible except in the
moment before it opens. Strings live in a three-column table in the `.cpp`
rather than routing through `I18n.js` (a QML JS library C++ cannot call);
`stringsForMode()` mirrors its `langKey()` fallback (unrecognized → `zh`).

## 8. Deliberate omissions

- **No timer rows.** An earlier revision in this session carried a
  start/pause/resume row plus `结束并记录` driven by `TimerManager`; removed at
  the user's request. The status item is now navigation and lifecycle only,
  and no longer links against `TimerManager` at all — timer control lives in
  the window, where project choice already does.
- **No 暂停后台采集 row.** Pausing the sampler means the UI signalling the
  service; `CHARTER` §2 forbids IPC. It would need a control file added to the
  disk contract, i.e. a change proposal first.
- **Autostart is a disabled placeholder.**
  `SettingsRepository::autostartSupported()` returns false off Windows
  (`settings_repository.cpp:424`), and `registerMacLaunchAgent()` is
  register-only — no query, no unregister. A live checkmark needs both added
  to `macos_launch_agent.mm` first.
- **No status/summary rows.** `QSystemTrayIcon` gives plain `QMenu` rows only;
  a glanceable today-total block wants a custom `NSView` menu item.

## Outcome

Shipped. The status menu is 打开 TimeArc / disabled 开机自启 / 退出 TimeArc,
localized zh-en-ja. `tests/macos_status_bar_menu_static_test.py` is new and
passes — it now also forbids any `TimerManager` symbol in the status-item
files, so the removal cannot silently come back;
`macos_fullscreen_close_static_test.py` still passes (its
`forbid(status_bar, "&QSystemTrayIcon::activated")` holds — click-opens-menu
is unchanged). Build clean, no new warnings; a launch + `scan_qt_log.py
--track B` recorded 0 L2s, the only stderr line being the known unsigned-build
LaunchAgent codesigning failure already in `state/open-issues.md`.

Not verified by me: the menu itself. Driving a status-bar menu needs
Accessibility permission this session lacks (`osascript` → System Events
-1743), so §6's rows and language switch await a human smoke pass.
