# Rule 04 — UI Conventions

Rules for anything under `qml/` and `src/services/`.

## 1. Shell selection

`qml/Main.qml` chooses a shell at load time:

- If `TIMEARC_MOBILE_PREVIEW` env var is set or the app was invoked with
  `--mobile` / `--mobile-preview`, force `MobileAppShell`.
- Otherwise, pick `MobileAppShell` when `width <= 720`, else `DesktopAppShell`.

When you add a new top-level page, add it to **both** shells. Mobile-only or
desktop-only pages are allowed but must be reflected in the shell's navigation
code, not in `Main.qml`.

## 2. Theme contract

`DesktopAppShell` owns day/night mode. Pages participate by exposing
optional properties:

- `nightMode: bool`
- `themeTextPrimary: color`, `themeTextSecondary: color`
- `themePanelColor: color`, `themeBorderColor: color`, `themeAccentColor: color`

`applyThemeToLoadedPage()` pushes values through if the Loader's item declares
them. New pages should:

1. Declare the above properties with sensible day-mode defaults.
2. Derive any additional colors locally from `nightMode`.
3. Not break if the shell never pushes values (i.e., standalone preview).

Mobile pages read `MobileTheme` through `theme: mobileTheme`. Do not mix the
desktop theme plumbing into mobile pages.

## 3. Language

- QML comments, UI-string property names, and source/fallback visible text are
  Chinese; runtime translation helpers may present English/Japanese (or later)
  from user settings when Chinese remains fallback and layouts stay stable.
- C++ identifiers (symbols, method names) are English.
- Inline comments in C++/C/Swift may be mixed (the current codebase is
  predominantly Chinese with English section banners). Continue that style.

## 4. QML anti-patterns

Reject these in review:

- **`localStorage` / `sessionStorage` / `fetch`**: QML does not have these.
  Route all persistence through a manager.
- **Hard-coded colors for new UI elements** that should adapt to night mode.
  Add them to the theme plumbing instead.
- **New QML context properties** injected from C++ without being a `QObject`
  with `Q_PROPERTY`. The existing four managers are the template.
- **Blocking file I/O in QML**. If you need to read a file, add a method on a
  manager.

## 5. Images and icons

- Native app icons come from `AppIconImageProvider` via
  `image://appicon/<exe path>`. Do not embed per-app icons in resources.
- Static UI icons live in `resources/icons/`. SVG preferred.
- Memory Lake artwork lives in `resources/memorylake/`.
- Background images: `background.png`, `background_night.png`, and the
  optional `background_japanese_style.png`. If you add a new one, add it to
  `resources/CMakeLists.txt`.

## 6. Cross-manager signals

The four managers do not know about each other directly; QML mediates. For
example, when `TimerManager` emits `timerStopped(name, seconds)`, the shell's
QML handler calls `ProjectManager.addElapsedTime(...)`.

If you think you need a `QObject::connect` between two managers in C++, stop
and reconsider. The current seam is in QML for a reason: it keeps the managers
composable and testable.

## 7. Stats & aggregation ranges

Both `ProjectManager` and `UsageStatManager` accept a `range` string in the
set `{"day", "month", "year", "all"}`. Keep this vocabulary consistent. When
a new range is needed (e.g., `"week"`), add it to both, not just one.

## 8. Memory Lake memo overlay (备忘黑板)

The 「备忘」 nav entry is a **modal overlay action**, not a page route: clicking it
sets `memoOverlay.open` over the current page (no `selectedIndex` / `pageLoader`
switch). Do not add a "memo page" or route it through the Loader. The overlay is
desktop-only (`DesktopAppShell`); no mobile equivalent yet.

Memo content (canvas ink, sticky notes, text layers, pages) is **UI-private local
state**, outside the service↔UI disk contract — persist it via a C++ manager
(`QObject` + `Q_PROPERTY`), never QML `localStorage`/`LocalStorage` (§4) and never
service database/config paths. New memo components live in `qml/desktop/memorylake/`; all
colors/easings come from `MemoryLakeStyle` (no inline hex). Specs:
`docs/memory-lake-memo-functional-replication.md` + `…-memo-render-pipeline-replication.md`.

Added in the memo QA/feature round: `MemoDatePicker` (self-drawn calendar + 24h
time, no `Qt.labs`) for sticky due dates (`odue`), and a marquee **select tool**
(ink region + objects: delete / copy / move / scale). Native style ignores SpinBox custom.
