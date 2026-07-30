# Change Proposal — GUI resource bundle

## Metadata

- Author: `/root`
- Track: B (Feature)
- Date: 2026-07-27 14:15 (Asia/Shanghai)
- Session goal: Move non-core GUI artwork out of the main executable and place both macOS executables in `TimeArc.app/Contents/MacOS`.
- Branch: `development/macos-support`
- Related error reports: `qt-rcc-path-assumption`, `binary-rcc-list-probe`,
  `desktop-static-manifest-path`, `gui-resource-final-index-line-budget`,
  `index-trim-patch-context`

## Progress checklist

- [x] Inspect current resource registration, references, sizes, and bundle layout.
- [x] Add the external GUI resource archive and platform bundle placement.
- [x] Register the archive before loading QML and verify existing resource URLs.
- [x] Build, inspect the macOS bundle, run static tests, and run the harness audit.

## 1. Frozen files touched

- `CMakeLists.txt` — generate/copy the external GUI archive and copy the macOS service into the app's `Contents/MacOS` directory.

## 2. Motivation

The executable currently embeds large content artwork and about 11.6 MB of unreferenced Memory Lake art. The existing macOS app also leaves `time-arc-service` outside the `.app`, so a built app is not a complete two-process bundle.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer / service side | Service behavior and disk output are unchanged; only the macOS packaged location becomes `Contents/MacOS/time-arc-service`. |
| Consumer / UI side | The UI registers a required bundled `.rcc` archive before loading QML; existing `qrc:/qt/qml/time_arc/resources/...` URLs remain stable. |

Service side design: `time-arc-service` remains a standalone executable and sole automatic-usage database writer. Packaging it beside `TimeArc` changes no storage, sampling, or process boundary.

UI side design: QML/JS and small shell icons remain embedded. Large active backgrounds, site icons, and monthly recap artwork move to an external Qt binary resource archive loaded before the QML engine starts.

Rules to update: `rules/05-build-system.md`. Licensing rules remain accurate because license texts stay embedded and the Qt linkage posture is unchanged.

## 4. Migration plan

No on-disk impact. Existing databases and configuration files are unchanged.

## 5. Rollback plan

Revert the build/resource/runtime registration changes. No data restoration is required.

## 6. Test plan

- Pre-change reproduction: inspect `TimeArc` resource objects and observe large raster assets embedded; inspect `TimeArc.app` and observe the helper is absent.
- Post-change verification: build through the harness; confirm the external `.rcc` and both binaries are in their platform bundle locations; confirm registered URLs exist and the app loads QML without resource warnings.
- New test artifacts: extend static resource/build checks if an existing suitable test is present.

## 7. Completion report

- Completed: External desktop RCC, Android embedding, macOS dual-binary layout, Windows staging, documentation, and focused tests.
- Incomplete: None.
- Verification: Harness builds, resource smoke, mobile/harness static checks, generated bundle inspection, temporary-prefix install, and the full harness audit passed.
- Next: Run Windows clean-machine packaging and macOS Qt deployment/signing in their release environments.
- Risks: Windows packaging remains unexecuted on this macOS host; runtime Qt deployment/signing remains separate release work.

## 8. Sign-off

- [x] `rules/05-build-system.md` updated.
- [x] `README.md` updated.
- [x] Frozen-file hashes regenerated after the approved edit.
