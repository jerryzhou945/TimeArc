# 20260729-0155-B-macos-close-keeps-app-running

## Metadata

- Author: Claude Code (Opus 5)
- Track: **B (Feature)** — new macOS-only app-lifecycle capability.
- Date: 2026-07-29 01:55 (local)
- Session goal: make the macOS red traffic light close the window while the
  app keeps running in the Dock, per platform convention.
- Branch: `development/macos-support`
- Related error reports:
  `errors/20260728-150542-C-macos-fullscreen-close-black-screen.md`

## 1. Frozen files touched

- `src/CMakeLists.txt` — append `services/macos/macos_app_lifecycle.{h,mm}` to
  the existing `if(APPLE)` block. No target, flag, or include-dir change.

## 2. Motivation

Today `qml/main.qml` treats every desktop platform the same: `onClosing`
rejects the close and hides the window to the tray/status item. That is the
Windows convention. On macOS the red button closes the *window*; the process
stays alive with its Dock icon and menu bar, and a Dock click reopens the
window. The current build hides the window with no reopen handler, so after
clicking red the Dock icon is inert — the status item is the only way back.

## 3. Impact on the other process

| Side        | Effect                                          |
|-------------|-------------------------------------------------|
| Producer    | None. The service is a separate process and keeps sampling; nothing in `src/service/` is touched. |
| Consumer    | UI-only. The macOS UI window can now be destroyed and recreated at runtime, so `MacTrafficLightsController` re-creates its native button references on window visibility changes. |

## 4. Migration plan / 5. Rollback plan

No on-disk impact. Window geometry keeps using the existing UI-private
`SettingsRepository` keys (`window_width/height/x/y`), still written only from
the windowed state. Rollback is a code revert — three UI files plus the CMake
source list; no data is written or reinterpreted.

## 6. Test plan

- Pre-change reproduction: launch on macOS, click the red button — the window
  disappears; clicking the Dock icon does nothing.
- Post-change verification: click red → window closes, Dock and menu bar stay;
  click the Dock icon → window returns with working traffic lights; from full
  screen, red exits full screen then closes (no black screen, no orphaned
  Space); status-item click → menu only, 打开 TimeArc restores, 退出 TimeArc
  and ⌘Q quit; Windows/Linux unchanged (close hides to tray with its
  notification, tray click restores).
- New test artifacts: `tests/macos_fullscreen_close_static_test.py` rewritten
  against the new symbols.

## 7. Design — two sides

**Service side.** Unchanged — no sampling, schema field, or control file.
`time-arc-service` keeps writing `timearc_service.db` whether the UI window is
open or closed, which is why closing the window without quitting is safe.

**UI side.** A new Objective-C++ adapter `MacAppLifecycle`
(`src/services/macos/macos_app_lifecycle.{h,mm}`) owns two AppKit concerns:
a forwarding `NSApplication` delegate proxy that answers
`applicationShouldHandleReopen:hasVisibleWindows:` by re-showing the `QWindow`,
and the full-screen-exit observer moved out of `macos_traffic_lights.mm`.
`beginWindowClose()` returns whether the close may proceed now, so QML sets
`close.accepted` from it and the observer re-issues the close after
`NSWindowDidExitFullScreenNotification`. `main.cpp` sets
`setQuitOnLastWindowClosed(false)` on macOS only.

## 8. Sign-off

- [x] `rules/*.md` updated — none claim close-to-tray behavior; nothing stale.
- [x] `CHARTER.md` version bump — not needed; no invariant changes.
- [x] `state/frozen-files.json` regenerated after the commit lands.
- [x] `README.md` updated (user-visible: §desktop shell + §macOS packaging).

## Outcome

Shipped. macOS now follows the platform convention: the red button closes the
window, the process stays in the Dock and menu bar, and the Dock icon reopens
it. Windows/Linux still hide to the tray with their notification — the QML
branch is gated on `macSidebarChrome`, and no non-Apple source changed.

`MacTrafficLightsController` lost `hideToTray()` and the full-screen observer
(both moved into `MacAppLifecycle`) and gained a `QWindow::visibleChanged`
connection, because a real close destroys the platform window and its AppKit
buttons; the cached pointers now follow that lifetime instead of dangling.

Follow-up in the same session: `MacStatusBarIcon` dropped its
`QSystemTrayIcon::activated` handler, so clicking the macOS status item opens
its menu instead of restoring the window — 打开 TimeArc is the explicit
restore. `NotifierTray.qml` (Windows/Linux) keeps click-to-restore.

Both harness builds succeeded with no new warnings; the required Qt log scan
drained three stale L2 reports, all the known unsigned-build LaunchAgent
codesigning warning (`open-issues.md` → macOS packaging), none from this
change. Trimmed three rows from `journal/INDEX.md` for the line budget. User
confirmed the smoke path functional: click red → window closes, app keeps
running; click Dock icon → window returns.
