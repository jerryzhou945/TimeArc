# 20260605-1950-B-frameless-window

**Goal (one sentence).** Remove the native Win11 title bar and replace it with a
custom immersive frameless window chrome (floating app icon + min/max/close +
drag/resize), QQ-Music style, Windows desktop first.

## Track / scope

Track B (feature). **UI-only window chrome. No service side** — the on-disk
contract (`usage_records.jsonl` / `usage_current.json`) is untouched; this
crosses no UI/service seam, so the usual "service emits / UI consumes" pair is
N/A. Recorded here per Track B §Required.

This is **step 1 of 2** (user-approved): pure-QML frameless now; a later native
`WM_NCCALCSIZE` pass (snap-layouts flyout, maximize-over-taskbar correctness)
is deferred to step 2.

**Follow-up (same session, on user request "圆角"):** added Win11 **native
rounded corners + drop shadow** via DWM `DWMWA_WINDOW_CORNER_PREFERENCE`
(`DWMWCP_ROUND`), runtime-loaded `dwmapi.dll` in `src/main.cpp`
(`applyWin11RoundedCorners`, Windows-only, no frozen-CMake/link edit). Verified
on screen: all four corners round + subtle shadow; `PrintWindow` can't show it
(compositor effect) — used topmost + `CopyFromScreen`. This pulled rounding/
shadow out of step 2's scope.

## Design decisions

- **Immersive floating chrome** (user pick): chrome is a transparent
  full-window overlay; the shell background fills to the top edge; only the
  interactive content is inset by `topReserve` (40px).
- **Frameless only on real desktop**: `frameless = !mobilePreview`. Mobile
  preview keeps the native frame (dev tool); its shell just declares
  `topReserve` defensively.
- **Window move/resize** via Qt's native helpers `startSystemMove()` /
  `startSystemResize(edges)` (native loop ⇒ Windows snap-on-drag still works).
  Double-tap drag band = maximize toggle.
- **Memo overlay**: chrome is hidden while `memoOverlay.open` (the memo is a
  fullscreen modal with its own exit at top-right; its toolbar/page-folder sit
  at y≈14/18). Hiding the chrome there means **`MemoOverlay.qml` is not
  touched** — lowest risk.
- **Glyph contrast**: chrome `dark` mode bound to shell
  `prefersLightChrome = nightMode || fullBleedPage`.
- **App icon**: new brand SVG (`resources/icons/app_icon.svg`, aqua→violet
  rounded square + ink "T", matching the sidebar brand block). Shared by the
  chrome's top-left mark and the taskbar via `setWindowIcon` in `main.cpp`.

## Files (none frozen; verified against CHARTER §3)

- `qml/main.qml` — frameless flags, window-level `WindowChrome`, pass
  `topReserve`, gate chrome on `!memoOpen`.
- `qml/desktop/components/WindowChrome.qml` — NEW reusable chrome.
- `qml/desktop/DesktopAppShell.qml` — `topReserve`, inset RowLayout,
  expose `memoOpen` + `prefersLightChrome`.
- `qml/mobile/MobileAppShell.qml` — declare/apply `topReserve` (defensive).
- `resources/icons/app_icon.svg` — NEW.
- `src/main.cpp` — `QGuiApplication::setWindowIcon(...)`.
- `qml/CMakeLists.txt`, `resources/CMakeLists.txt` — register the two new files.

Hands off: top-level/src/resources `CMakeLists.txt` frozen entries, schema,
data_bridge, MemoOverlay internals.

## Risks to verify at runtime

- **Maximize covering the taskbar** (classic frameless gotcha). If
  `showMaximized()` covers it, fall back to manual `Screen.desktopAvailable*`
  geometry. MUST observe the real app, not just an offscreen grab.
- Resize edges vs. drag band z-order at top corners.
- Center click-through of the transparent overlay.

## Smoke path

Launch app → window has no white Win11 bar → drag from top moves it →
double-click top maximizes/restores → min/max/close work → drag edges resize →
open 备忘 (memo) → chrome hides, memo usable → exit memo → chrome returns →
taskbar icon is the new brand mark.
