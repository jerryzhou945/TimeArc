# Change Proposal — shared-service-data-bridge

## Metadata

- Author: Codex `/root`
- Track: B (Feature)
- Date: 2026-07-12 15:35 (local)
- Session goal (one sentence): Retire the Windows-only storage adapter and wire Windows trackers directly to the existing shared data-bridge APIs.
- Branch: `development/macos-support` (the user explicitly requested implementation on the current branch)
- Related error reports: `errors/20260712-073633-B-build-failure.md` (baseline build tree was not configured); `errors/20260712-073652-B-git-branch-permission.md` (superseded branch-creation attempt); `errors/20260712-074915-B-build-failure.md` (known empty Linux service entry point)

## 1. Frozen files touched

- `src/service/CMakeLists.txt` — stop compiling `windows/storage/*`; the implementation moves into the existing shared source set.

## 2. Motivation

Windows currently converts completed tracker sessions into a Windows-only storage context and record type before calling the existing shared table bridge. That adapter is an unnecessary middle layer: Windows can submit its app and session fields directly through `data_bridge.h`.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Windows trackers call the existing shared table bridge directly; the shared folder and macOS implementation remain untouched. |
| Consumer | None. The UI continues to open `timearc_service.db` read-only and sees the same tables and values. |

## 4. Migration plan

No on-disk impact. Existing and new records use the same SQLite tables, columns, segmentation, and identifiers; no migration or backup is required.

## 5. Rollback plan

Revert this code change to restore `windows/storage/*` and the former Windows-only bridge implementation. No data restoration is needed.

## 6. Test plan

- Pre-change reproduction: inspect the build graph and observe that `ta_storage_*` / `ta_write_usage_record*` live only in `windows/storage/usage_storage.c` while macOS calls them through an incomplete bridging header.
- Post-change verification: configure/build the service where toolchains are available; grep the build graph for removed Windows storage files; verify Windows record writes call only APIs declared in `data_bridge.h`.
- New test artifacts: none.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality (`01-architecture.md`, `02-platform-boundaries.md`, `03-data-contract.md`).
- [ ] `CHARTER.md` version bumped (not applicable; no invariant or disk-contract change).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible (not user-visible; service README will be updated).

## Service side / UI side design

Service side: Windows foreground and audio trackers will call `update_apps` plus the appropriate session API from `shared/data_bridge.h`; the startup config reader will remain Windows code in a small top-level Windows module, and the obsolete Windows storage context/files will be removed. No file under `src/service/shared/` will change.

UI side: no code changes are required because the database filename, schema, writer ownership, and read-only query path are unchanged.

## Outcome

Windows storage files were removed, tracker writes now use `update_apps`, `update_frontmost`, and `update_media`, and startup config parsing moved to `windows/service_config.*`. CMake configuration and the GUI target build succeeded; strict targeted C11 syntax checks passed for the changed Windows config/tracker sources. The full host build reaches the known empty Linux service entry point and fails there, so a Windows compile and runtime smoke remain pending.
