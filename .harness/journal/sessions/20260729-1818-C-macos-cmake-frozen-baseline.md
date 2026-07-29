# Change Proposal — macos-cmake-frozen-baseline

## Metadata

- Author: Codex, at user direction
- Track: **C (Debug)** — this proposal repairs frozen-file audit drift for
  already-requested macOS build changes; it does not introduce another feature.
- Date: 2026-07-29 18:18 (local)
- Session goal: Preserve the macOS bundle identifier and menu-localizer source
  registration while restoring an accurate frozen-file baseline.
- Branch: `development/macos-support`
- Related error reports:
  `../errors/20260729-084317-B-unrelated-frozen-cmake-drift.md`,
  `../errors/20260729-100127-C-macos-app-menu-localization.md`

## 1. Frozen files touched

- `CMakeLists.txt` — retain the committed
  `MACOSX_BUNDLE_GUI_IDENTIFIER "com.timearc.TimeArcDesktop"` property.
- `src/CMakeLists.txt` — register `macos_menu_localizer.{h,cpp}` only inside
  the existing `APPLE` source branch.

## 2. Motivation

Commit `d2e1af7` added the required stable macOS bundle identifier without
updating the frozen-file registry, so every preflight reports drift even
though the project builds. The menu-localization fix also needs its two source
files compiled on macOS and nowhere else. The user explicitly directed that
both macOS changes be kept and the mismatch resolved.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | None. The native background service, data bridge, and on-disk contract are unchanged. |
| Consumer | The UI app keeps a stable macOS bundle identifier and compiles the native-menu translator only on Apple platforms. |

## 4. Migration plan

No on-disk impact. Existing GUI and service databases are interpreted exactly
as before.

## 5. Rollback plan

Revert the bundle-identifier property and menu-localizer source registration,
then regenerate the two recorded hashes. No data restore is required.

## 6. Test plan

- Pre-change reproduction: run `.harness/tools/preflight.py --track C` and
  observe frozen-file hash drift.
- Post-change verification: run the full harness audit and confirm the frozen
  hash pass succeeds; rebuild through `.harness/tools/build.py`.
- New test artifacts: existing `tests/macos_menu_bar_static_test.py` pins the
  Apple-only localizer registration.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality: no rule change required;
  both changes follow `rules/05-build-system.md`.
- [x] `CHARTER.md` version bumped: not a charter amendment.
- [x] `state/frozen-files.json` will be regenerated for the accepted content.
- [x] Main `README.md` updated if user-visible: bundle/menu behavior is already
  documented by the owning macOS sessions.
