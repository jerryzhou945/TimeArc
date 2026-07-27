# Change Proposal — Functional GUI resource packs

## Metadata

- Author: `/root`
- Track: B (Feature)
- Date: 2026-07-27 14:51 (Asia/Shanghai)
- Session goal: Replace the single desktop GUI RCC with separate background, site-icon, and monthly-recap packs.
- Branch: `development/macos-support`
- Related error reports: `stale-single-rcc-bundle-artifact`

## Progress checklist

- [x] Confirm the single-RCC implementation builds and passes its smoke test.
- [x] Split resource manifests, generation, copying, and runtime registration.
- [x] Verify pack contents, alias uniqueness, platform layout, and Android wiring.
- [x] Update documentation, refresh frozen hashes, and run the final harness audit.

## 1. Frozen files touched

- `CMakeLists.txt` — generate, copy, install, and test three functional RCC files instead of one.

## 2. Motivation

One archive makes unrelated backgrounds, site icons, and recap scenes a single update and failure unit. Functional packs improve diagnostics, replacement scope, and release inspection without changing existing resource URLs.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer / service side | None; the service remains a separate executable in the same platform locations. |
| Consumer / UI side | The UI registers three required archives before QML starts; all existing `qrc:` aliases remain unchanged. |

Service side design: service sampling, storage, and bundle placement are unchanged.

UI side design: the desktop UI loads background, site-icon, and monthly-recap archives from one asset directory. Android embeds the same three source QRCs into its package.

Rules to update: `rules/05-build-system.md`. No schema, data-contract, dependency, or licensing change.

## 4. Migration plan

No on-disk user-data impact. Release packages replace `timearc-gui-assets.rcc`
with three functional files.

## 5. Rollback plan

Revert the functional manifests/build/loader changes to restore the single archive.

## 6. Test plan

- Pre-change reproduction: build and observe one `timearc-gui-assets.rcc`.
- Post-change verification: build and install; confirm exactly three archives in each desktop asset directory and successful runtime registration.
- New test artifacts: extend the resource smoke test to validate each pack, exact functional membership, and unique aliases.

## 7. Completion report

- Completed: Three functional packs, table-driven build/loader, Android wiring, Windows staging, stale-pack cleanup, tests, and documentation.
- Incomplete: None.
- Verification: Harness builds, functional RCC smoke, manifest alias test, mobile static check, bundle inspection, temporary install, and full harness audit passed.
- Next: Run Windows packaging in its release environment.
- Risks: Windows packaging remains unexecuted on this macOS host.

## 8. Sign-off

- [x] `rules/05-build-system.md` updated.
- [x] `README.md` and the implementation report updated.
- [x] Frozen-file hash refreshed after the approved edit.
