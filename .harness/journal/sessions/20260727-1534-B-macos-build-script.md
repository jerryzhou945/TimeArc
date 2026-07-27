# Session — macOS build and release entry point

## Goal

Add `tools/build-macos.sh` with `--release` (default), `--build`, `--test`,
and `--package` modes covering CMake compilation through macOS deployment.

## Progress checklist

- [x] Inspect the harness build wrapper and local Qt/macOS deployment tools.
- [x] Implement the mode parser and build/test/package pipeline.
- [x] Add static checks and update release documentation.
- [x] Exercise safe modes, inspect the artifact, and run the harness audit.

## Expected files

- `tools/build-macos.sh`
- `tests/macos_build_script_static_test.py`
- `README.md`
- `docs/gui-resource-bundle-report.md`
- `.harness/rules/05-build-system.md`
- `.harness/state/open-issues.md`

No frozen file is expected to change. The existing CMake install layout remains
the source of truth.

## Two-sided design

Service side: the script builds and stages the existing `time-arc-service`
target in `TimeArc.app/Contents/MacOS`; sampling and disk output are unchanged.

UI side: the script stages `TimeArc.app`, runs `macdeployqt`, verifies portable
Qt linkage, signs when configured, and creates the distributable DMG.

Rules to update: `rules/05-build-system.md`. No data-contract or licensing
inventory change.

## Completion report

- Completed: Script, static contract test, docs, real build/test/package smoke,
  filtered QML deployment, portable-linkage check, ad-hoc signature, and DMG.
- Incomplete: Developer ID signing/notarization and clean-machine launch need
  release credentials/a separate host.
- Verification: `--build` passed; `--test` passed 2/2; `--package` produced a
  valid 127 MB arm64 app and verified 57 MB DMG. Both binaries, all three RCCs,
  private Qt frameworks, licenses, signature, and bundle symlinks were checked.
- Next: Run a credentialed `--release` before publishing.
- Risks: Local artifact is ad-hoc signed and not notarized. The configured SDK
  path warning belongs to the reused build cache, not the new script default.
- Harness: all seven final checks passed.
- Follow-up: Runtime launch found that Qt's macOS Controls style imports
  Fusion, which imports Basic. Packaging now retains and validates all three
  style modules instead of pruning Fusion as unused.
