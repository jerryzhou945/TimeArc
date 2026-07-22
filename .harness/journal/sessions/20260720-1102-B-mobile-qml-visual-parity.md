# Track B Session — Mobile QML Visual Parity

## Goal

Bring the runnable mobile QML shell into visual parity with the approved HTML
prototype: one global wallpaper, near-transparent content layers, readable
typography, icon-led statistics, and a Memory Lake-style date timeline.

## Service side

The background service, Android UsageStats bridge, SQLite schemas, and disk
contract remain unchanged. Existing mobile usage aggregation continues to emit
real app labels, icon paths, durations, dates, and report models. Preview-only
fallback rows may be added in QML when the service returns no records; they
must never be persisted or presented as collected data on a real populated
installation.

## UI side

`MobileAppShell` remains the sole wallpaper owner. `MobileTheme` and shared
components will expose transparent/ink tokens used consistently by Home,
Statistics, Memory Lake, Settings, and bottom navigation. Home keeps one
centered flip card. Statistics becomes a date-led, icon-rich time stream with
week/month/year/all drill-down. Memory Lake dates and report archive rows use
the same transparent timeline language as the approved HTML prototype.

## Expected files

- `qml/mobile/MobileTheme.qml`
- `qml/mobile/MobileAppShell.qml`
- `qml/mobile/components/MobileGlassPanel.qml`
- `qml/mobile/components/MobileUsageRankRow.qml`
- `qml/mobile/pages/MobileHomePage.qml`
- `qml/mobile/pages/MobileStatsPage.qml`
- `qml/mobile/pages/MobileHistoryPage.qml`
- `qml/mobile/pages/MobileSettingsPage.qml`
- `tests/mobile_ui_static_test.py`
- `docs/superpowers/plans/2026-07-20-mobile-qml-visual-parity.md`

## Explicit non-scope

- Service/database/C ABI files
- Frozen CMake files
- Desktop UI
- New third-party assets or dependencies

## Rules

- `rules/04-ui-conventions.md` applies; no rule text change is expected.
- No frozen files are touched.
- Build only through `.harness/tools/build.py`.

## Baseline

- 2026-07-20: harness preflight clean after rolling the journal index.
- 2026-07-20: baseline harness build succeeded.

## Result

- Added shared near-clear, wash, strong, wallpaper ink, and timeline tokens.
- Home keeps one centered card, three factual archive values, matching preview
  icons/names, and a lighter wallpaper-through face.
- Statistics now uses four date-led range rows and flat icon/time/progress
  rankings instead of repeated opaque blocks.
- Memory Lake now uses month-aware date rails, transparent separators, poetic
  preview moments, and an integrated month archive.
- Settings no longer repeats the abrupt “我的时间弧” profile block.
- Preview sample data is guarded by `--mobile-preview`; Android continues to
  use the existing runtime data and icon paths.

## Verification

- Harness build: success.
- `ctest --test-dir build --output-on-failure`: 1/1 passed.
- `tests/mobile_ui_static_test.py`: passed.
- `tests/android_usage_static_test.py`: passed.
- Visible `--mobile-preview`: responsive after 8 seconds (PID 24380).
- Qt/QML scan: no harness log was generated, so no warnings were captured.
- Final `harness_check.py`: clean.

## Manual smoke path

Launch `build/TimeArc.exe --mobile-preview`, switch through all four tabs,
toggle light/dark mode, select/reset a wallpaper, open each statistics range,
flip/share a Home card, open a monthly report, then scan the Qt/QML log.
