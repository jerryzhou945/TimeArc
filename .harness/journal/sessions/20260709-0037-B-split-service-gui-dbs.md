# Change Proposal - split-service-gui-dbs

## Metadata

- Author: Codex
- Track: B (Feature)
- Date: 2026-07-09 00:37 CST
- Session goal (one sentence): Split SQLite ownership so the service writes only `timearc_service.db` history tables and the GUI writes only its own `timearc.db` tables.
- Branch: development/macos-support
- Related error reports: `errors/20260708-163255-B-preflight-drift.md`

## 1. Frozen files touched

- `.harness/CHARTER.md` - amend I2 from one shared SQLite contract to two process-owned SQLite files.

## 2. Motivation

The previous shared SQLite design made both processes potential writers of the
same file and required rollback/lock-probe relocation code. The new contract
keeps each database single-writer: service-owned history in
`timearc_service.db`, GUI-owned app state in `timearc.db`.

## 3. Service side

The service resolves `usage_config.json` `db_dir`, appends
`timearc_service.db`, creates only `apps`, `frontmost_sessions`, and
`media_sessions`, and remains the only writer for that file. JSONL/current
fallback files stay unchanged.

## 4. UI side

The GUI opens its original `timearc.db` for settings, tags, manual projects,
mobile/device tables, and other GUI-only state. It opens `timearc_service.db`
through a separate read-only connection for history reads and falls back to
JSONL when the service DB is absent or empty. The GUI may still write
`usage_config.json` service controls (`db_dir`, idle, track), but it must not
write or migrate service-history rows.

## 5. Migration plan

Existing `timearc_service.db` service-history rows remain in place. Existing
GUI tables created in the previous shared file will be recreated in
`timearc.db` on next launch; automatic data copy is intentionally deferred so
the ownership split is explicit and no service-owned file is modified by the
GUI. JSONL remains the history fallback.

## 6. Rollback plan

A code/doc revert restores the previous shared-DB behavior. Existing files are
not deleted by this change.

## 7. Test plan

- Update `timearc_db_smoke` to assert the GUI DB and service DB are distinct.
- Assert the service DB contains only `apps`, `frontmost_sessions`, and
  `media_sessions` in the contract path.
- Assert GUI repositories write only through the GUI connection and history
  repositories read through the service connection.
- Run harness build and `ctest --test-dir build --output-on-failure`.

## 8. Sign-off

- [x] `rules/*.md` updated to reflect new reality.
- [x] `CHARTER.md` version bumped.
- [x] Main `README.md` updated if user-visible.
- [x] Verification commands recorded.

## 9. Result

- `DatabaseManager` now owns the GUI `timearc.db` connection and opens
  `timearc_service.db` separately as read-only service history.
- Foreground/media history repositories and `UsageStatManager` read from the
  `timearc_service` connection; their GUI-side write methods fail honestly.
- GUI DB backup/restore now applies to `timearc.db`; service DB directory
  changes only update `usage_config.json` `db_dir` and never move/write the
  service DB file.
- `timearc_db_smoke` now asserts the two DB files are distinct, service DB has
  exactly the three service tables, and GUI DB has no service-history tables.
- Verification:
  - `git diff --check` passed.
  - `python .harness/tools/build.py --track B --session .harness/journal/sessions/20260709-0037-B-split-service-gui-dbs.md` passed.
  - `ctest --test-dir build --output-on-failure` passed.
