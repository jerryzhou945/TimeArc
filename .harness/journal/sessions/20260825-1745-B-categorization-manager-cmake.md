# Change Proposal — categorization manager build entry

## Metadata

- Author: Claude Code
- Track: **B (Feature)**
- Date: 2026-08-25 17:45
- Session goal: add the `CategorizationManager` QObject so the new rule engine
  can be owned, persisted and exposed to QML.
- Branch: `feature/ui-statistics`
- Related error reports:
  `journal/errors/20260825-082229-B-categorization-scoring-inversion.md`,
  `journal/errors/20260825-083634-B-categorization-short-needle-lint.md`

## 1. Frozen files touched

- `src/CMakeLists.txt` — append
  `services/categorization_manager.cpp` and `.h` to
  `TIME_ARC_DATABASE_SOURCES`. No target, flag, include dir, or link change.

## 2. Motivation

Rollout step 1 (`docs/categorization-redesign.md`) landed the rule engine as
headers only, precisely to avoid this file. Steps 2–4 need a QObject: the rule
set must be loaded from and written to the GUI settings store, exposed to QML
for the settings UI, and must emit a change signal so the read layer
recomputes. A QObject needs AUTOMOC, and AUTOMOC only processes a header whose
basename matches a source already listed here — sources are listed explicitly,
with no globbing.

The alternatives are worse. Hiding a second Q_OBJECT inside
`usage_stat_manager.h` to borrow its AUTOMOC entry buries a manager where no
one will find it. Bolting the rule CRUD onto `SettingsRepository` makes the
settings store own product logic it has no business owning. `tracks/B-feature.md`
explicitly allows "New QObject managers — following the existing four as
template", which is what this is.

## 3. Impact on the other process

| Side        | Effect                                                        |
|-------------|---------------------------------------------------------------|
| Producer    | None. The service is untouched; no schema, no `data_bridge.h`, no sampling change. |
| Consumer    | One more translation unit in the UI target. Categorization moves from four hardcoded sources to one loadable table. |

## 4. Migration plan

No on-disk impact on the service contract. The GUI database gains one
`settings` row, key `categorization`, written only after the user's first
edit. Its absence means "follow the shipped defaults", so existing installs
are unaffected until the user customizes, and `Restore all defaults` deletes
the row. Category identifiers change from Chinese literals to ASCII ids
(`开发` → `dev`); nothing persisted the old literals, because categories were
always computed at read time and never stored on records.

## 5. Rollback plan

Code revert is sufficient. If a stored `categorization` row exists from a
newer build, the older build ignores the key entirely and falls back to its
own classifiers, so a downgrade loses customization but corrupts nothing.

## 6. Test plan

- Pre-change reproduction: `usage_stat_manager.cpp` carries a Windows-only
  keyword ladder; on macOS `com.google.Chrome` matches none of `chrome.exe`,
  `google\chrome`, `google/chrome`, so browsing lands in 其他 and no `site:*`
  identity is ever produced.
- Post-change verification: `timearc_db_smoke` fixture asserts
  `com.google.Chrome` → `app.chrome`/`browse` and a YouTube window title →
  `site.youtube`/`video` on both platforms; `ctest` green; app launches and
  the settings page lists rules.
- New test artifacts: categorization fixture in `tests/db_smoke.cpp`
  (18 cases at step 1, extended in step 2).

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality (`01-architecture.md`,
      `04-ui-conventions.md`).
- [ ] `CHARTER.md` version bumped (not a charter amendment; no invariant moves).
- [x] `state/frozen-files.json` regenerated after the edit.
- [x] Main `README.md` updated if user-visible.
