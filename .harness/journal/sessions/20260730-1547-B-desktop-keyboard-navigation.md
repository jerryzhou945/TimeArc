# 20260730-1547-B-desktop-keyboard-navigation

## Metadata

- Author: Claude Code (Opus 5)
- Track: **B (Feature)** — design only this session; no code changed.
- Date: 2026-07-30 15:47 (local)
- Session goal: audit the desktop shell's keyboard surface and design
  keyboard-focused navigation for Windows + macOS.
- Branch: `development/macos-support`

## 1. Frozen files touched

None. Deliverable is one new file: `docs/desktop-keyboard-navigation-design.md`.

## 2. Two-sided design

- **Service side:** nothing. No sampling source, no `usage_config.json` key, no
  schema or `data_bridge.h` touch, no IPC. `time-arc-service` is unaffected and
  not rebuilt.
- **UI side:** three layers in `qml/desktop/` — a `KeyMap.js` command table read
  by both `MacMenuBar` and a new always-on `DesktopShortcuts.qml`; a region layer
  (`KeyRegion.qml` + shell-owned focus stack); a cursor layer that writes the
  state properties the mouse already writes, drawn by `FocusRing.qml`. New
  `MemoryLakeStyle` focus tokens. No new manager, no persistence in phases 1–2.

## 3. Audit findings (the reason for the design)

1. **Windows/Linux have no navigation keys.** ⌘1–⌘4, ⌘,, ⇧⌘N/P/D/E all ship as
   `Platform.MenuItem.shortcut` inside the macOS-gated `Loader` (`main.qml:142`).
   Off macOS the whole set does not exist; letters `N`/`P` + `Esc` are all there is.
2. **Nothing is focusable.** 132 `MouseArea`s in `qml/desktop/`; zero
   `FocusScope` / `KeyNavigation` / `activeFocusOnTab`; no `activeFocus`-driven
   visual anywhere.
3. **Focus has no owner.** Only `DesktopStatsPage.qml:618` and
   `DesktopProfilePage.qml:348` self-focus; `MemoOverlay` grabs focus on open
   (`:604`) and returns it to nobody, so one 备忘 round trip kills even their `Esc`.
4. **In-page reach is mouse/wheel only** — but each surface already keeps its
   selection in one QML property (`selectedIndex`, `range`/`periodOffset`,
   `currentTab`, `activeView`/`selectedDateKey`), so cursors can ride that state
   instead of retrofitting focus onto every `MouseArea`.

## 4. Constraint probed this session

Qt Quick's focus chain consults `QStyleHints::tabFocusBehavior()` — confirmed by
symbol import in the installed Qt 6.11.1 `QtQuick` framework:

```
nm -u lib/QtQuick.framework/QtQuick | grep tabFocus
__ZNK11QStyleHints16tabFocusBehaviorEv
```

Scratchpad QML probe on this machine (cocoa, `AppleKeyboardUIMode = 2`, i.e.
keyboard navigation **on**):

```
tabFocusBehavior = 255   (Qt.TabFocusAllControls)
```

With the macOS default (setting off) the cocoa plugin reports text-controls-only,
so Tab cannot reach a nav item. Hence the design never relies on Tab alone and
gives every region a `Ctrl+Alt+digit` key. Verifying the setting-off value on a
clean account, and whether a native menu equivalent plus an identical QML
`Shortcut` double-fires, are the two phase-0 probes in the doc §10.

## 5. Design decisions worth carrying forward

- Cursors write existing state → keyboard and mouse share one code path; the
  flip lock (`memoLocked` / `selectCard` early-return) keeps working unchanged.
- Tab ring stays ~4 stops per page; no bare-letter shortcut is added, so the
  rebindable `N`/`P` and every text field are untouched.
- `Esc` becomes a ladder (popup → selection → overlay → region → 回首页); the
  existing one-press "回首页" on stats/settings becomes the second press. Flagged
  as a deliberate behavior change with a phase-1 acceptance check.
- macOS menu rows keep owning their sequences; the QML `Shortcut` set is gated
  `active: !macSidebarChrome` for those commands.
- ⌘1–⌘4 numbering and 设置 = ⌘, are preserved per `macos-menu-bar-design.md` §2.4.
- Rejected: tab-everything, a Controls migration, vim keys, a C++ command layer,
  `F6` as a shared ring, `Ctrl+Shift+digit` (⇧⌘3/4/5 are macOS screenshots).

## 6. Rule / doc updates owed at implementation time

- `rules/04-ui-conventions.md` **new §9** (keyboard/focus contract) — same commit
  as phase 1.
- `qml/CMakeLists.txt` must list each new QML file (rule 05).
- `docs/macos-menu-bar-design.md` §2.4 pointer; `docs/settings-remaining-work.md:104`
  🟡 → ✅ when the generated 快捷键 card lands; `CLAUDE.md` doc list; `README.md`
  when phase 1 ships.

## 7. Verification

No build: no source file changed, so `build.py` was not run and there is no Qt
log to `scan_qt_log.py`. `preflight.py --track B`: clean. `harness_check.py`:
clean. No error report filed — nothing failed and no premise was overturned.

## 8. Outcome

**done** (design). Implementation not started; phase 0 probes are the next
session's entry point.
