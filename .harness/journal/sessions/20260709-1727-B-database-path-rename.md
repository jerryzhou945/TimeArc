# Change Proposal - database-path-rename

## Metadata

- Author: Codex
- Track: B (Feature), because frozen shared contract files move.
- Date: 2026-07-09 17:27 (Asia/Shanghai)
- Session goal (one sentence): Rename the shared service DB-path resolver from
  `usage_paths.*` to `database_path.*` and update references.
- Branch: development/macos-support
- Related error reports: `errors/20260709-092731-B-preflight-drift.md`,
  `errors/20260709-092720-A-wrong-track.md`

## 1. Frozen files touched

- `src/service/shared/usage_paths.h` - moved to `database_path.h`.
- `src/service/shared/usage_paths.c` - moved to `database_path.c`.
- `src/service/CMakeLists.txt` - points at the renamed shared files.
- `.harness/CHARTER.md` - names the renamed frozen files.
- `.harness/AGENTS.md` - routes the renamed files to rule 03.

## 2. Motivation

The helper now exposes only `get_database_path`; keeping the old
`usage_paths.*` name makes the shared contract look broader than it is.
Renaming the files keeps the API surface aligned with the service-owned SQLite
path contract introduced by `CHARTER` v0.5-v0.6.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Service storage still calls `get_database_path`; only the header/source filenames change. |
| Consumer | UI history behavior is unchanged; docs/rules refer to the new resolver name. |

Service side: the storage layer continues to resolve `usage_config.json`
`db_dir` and append `timearc_service.db`.

UI side: the UI still reads the service DB through its existing mirrored
config-first logic; no new UI dependency on service code is introduced.

## 4. Migration plan

No on-disk impact. Existing `timearc_service.db`, `timearc.db`,
`usage_records.jsonl`, `usage_current.json`, and `usage_config.json` contents
are interpreted the same way.

## 5. Rollback plan

A code revert is sufficient. No user data restore is required.

## 6. Test plan

- Pre-change reproduction: search for `usage_paths` in source/build files.
- Post-change verification: build through `.harness/tools/build.py` and search
  source/harness docs for stale `usage_paths` references.
- New test artifacts: none.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality: `rules/01`.
- [x] `CHARTER.md` version bumped.
- [x] `state/frozen-files.json` updated for files touched by this proposal.
- [ ] Main `README.md` updated if user-visible: not user-visible.

## 8. Outcome

Renamed the shared resolver to `database_path.{h,c}`, updated the include
guard, caller include, CMake source list, charter/rule/checklist references,
and frozen registry entries for this rename. `python .harness/tools/build.py`
passed. `harness_check.py` still reports pre-existing frozen hash drift in
`data_bridge.h` and `usage_record.h` only.
