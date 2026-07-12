# Change Proposal - db-dir-service-db

## Metadata

- Author: Codex
- Track: B (Feature)
- Date: 2026-07-09 00:14 CST
- Session goal (one sentence): Replace full database-path customization with directory-only `usage_config.json` `db_dir` and lock the SQLite filename to `timearc_service.db`.
- Branch: development/macos-support
- Related error reports: `errors/20260708-161328-B-preflight-drift.md`

## 1. Frozen files touched

- `.harness/CHARTER.md` - amend I1/I2 and version notes from `db_path`/`timearc.db` to `db_dir`/`timearc_service.db`.
- `src/service/shared/usage_paths.c` - resolve configured DB directories instead of configured DB file paths, and use the new platform defaults.

## 2. Motivation

The old config let users point the service at an arbitrary database filename, which makes backup/migration and UI/service agreement harder. The new contract lets users choose the containing directory only; both processes always append the locked database filename.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | The service reads `usage_config.json` `db_dir` and writes SQLite at `<db_dir>/timearc_service.db`; absent/invalid config falls back to the platform service-data default. |
| Consumer | The UI reads/writes the same `db_dir` key, relocates by choosing a directory, and continues to read the same locked filename the service writes. |

## 4. Migration plan

Existing history records and SQLite table schemas are unchanged. Existing `db_path` config keys are no longer honored; on the next UI relocation/default-restore write, the UI removes stale `db_path` while preserving idle/track keys. Existing old-name DB files are not renamed automatically in this pass.

## 5. Rollback plan

A code/doc revert restores the prior `db_path` behavior. If a user has already moved to `timearc_service.db`, the DB file can be copied back manually if a rollback needs the old filename.

## 6. Test plan

- Pre-change reproduction: write `usage_config.json` with `db_path` and observe full-file path selection.
- Post-change verification: write `db_dir` and observe `<db_dir>/timearc_service.db`; absent/corrupt config falls back to the platform default; relocation writes `db_dir` and preserves idle/track.
- New test artifacts: update `timearc_db_smoke` D2/H5 assertions.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality.
- [x] `CHARTER.md` version bumped.
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [x] Main `README.md` updated if user-visible.

## 8. Result

- `usage_paths.c` now reads `usage_config.json` `db_dir`, appends the locked
  `timearc_service.db` filename, and falls back to the platform service-data
  default when the key is absent or the config is unreadable.
- The UI-side `DatabaseManager` mirrors the same directory-only pointer,
  writes `db_dir`, removes stale `db_path` on DB-location writes, and keeps the
  H5 idle/track keys preserved through the shared atomic RMW helper.
- Verification:
  - `git diff --check` passed.
  - `python .harness/tools/build.py --track B --session .harness/journal/sessions/20260709-0014-B-db-dir-service-db.md` passed.
  - `ctest --test-dir build --output-on-failure` passed (`timearc_db_smoke`).
