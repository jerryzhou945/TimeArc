# Change Proposal - database-storage

## Metadata

- Author: Codex
- Track: B (Feature), because the service gets a shared SQLite storage layer.
- Date: 2026-07-09 18:01 (Asia/Shanghai)
- Session goal (one sentence): Implement shared `database_storage.*` for the service-owned SQLite database and route bridge writes through it.
- Branch: development/macos-support
- Related error reports: `errors/20260709-100109-B-preflight-frozen-drift.md`, `errors/20260709-101145-B-shell-backtick-pattern.md`

## 1. Frozen files touched

- `src/service/CMakeLists.txt` - builds `data_bridge.c` and `database_storage.*`.
- `src/service/shared/data_bridge.h` - already drifted before this session; proposal covers the service rewrite API shape.
- `src/service/shared/usage_record.h` - already drifted before this session; no further edit planned here.

## 2. Motivation

`data_bridge.c` currently exposes the new app/frontmost/media bridge entry points but has no implementation. The service needs a shared low-level SQLite writer using `database_path.*` so Windows and Swift callers do not each own separate DDL.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Service writes `apps`, `frontmost_sessions`, and `media_sessions` through shared SQLite storage. |
| Consumer | UI keeps reading `timearc_service.db`; docs now describe the service DB columns explicitly. |

Service side: JSONL/current snapshot behavior stays separate; SQLite history moves behind `database_storage.*`.

UI side: no UI code is changed in this session while the service rewrite is in progress.

## 4. Migration plan

This rewrite defines the service DB schema as requested. Existing DBs with the old `app_identifier`/`playback_sec` shape are not migrated by this patch; schema mismatch should fail at open/write time rather than silently mixing shapes.

## 5. Rollback plan

A code revert returns the service to the prior stub/Windows-local SQLite behavior. If a developer tested against the new schema, remove the test `timearc_service.db` before rerunning the old writer.

## 6. Test plan

- Pre-change reproduction: call sites reach stubbed `update_*` functions with no return value.
- Post-change verification: build through `.harness/tools/build.py` and inspect docs for the requested schema.
- New test artifacts: none planned.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality: `rules/03`.
- [ ] `CHARTER.md` version bumped: not needed; existing v0.6/v0.7 already names this DB split/path.
- [ ] `state/frozen-files.json` will be regenerated after the service rewrite lands.
- [ ] Main `README.md` updated if user-visible: not user-visible.

## 8. Outcome

Implemented `database_storage.{h,c}`, wired `data_bridge.c`, routed Windows SQLite writes through the shared storage layer, and documented the requested table shapes. `python .harness/tools/build.py` passed; the initial frozen-file drift remains part of the larger rewrite state.
