# Change Proposal - database-path-comments

## Metadata

- Author: Codex
- Track: B (Feature), because frozen shared contract files change.
- Date: 2026-07-09 17:37 (Asia/Shanghai)
- Session goal (one sentence): Add clarifying comments to
  `src/service/shared/database_path.*` without changing behavior.
- Branch: development/macos-support
- Related error reports: `errors/20260709-093720-B-preflight-drift.md`

## 1. Frozen files touched

- `src/service/shared/database_path.h` - document the public resolver contract.
- `src/service/shared/database_path.c` - document path ownership, defaults, and
  config fallback behavior.

## 2. Motivation

The DB-path resolver encodes the service/UI disk contract and platform
directory choices. A few targeted comments make the frozen contract easier to
review without altering path resolution.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Service behavior is unchanged; comments describe existing path resolution. |
| Consumer | UI behavior is unchanged; comments clarify the shared `db_dir` contract. |

Service side: no emitted records, database tables, or filenames change.

UI side: no read path or fallback behavior changes.

## 4. Migration plan

No on-disk impact. Existing DBs, JSONL snapshots, and `usage_config.json`
contents are interpreted the same way.

## 5. Rollback plan

A code revert is sufficient; no data restore is required.

## 6. Test plan

- Pre-change reproduction: inspect `database_path.*` and note sparse contract
  comments.
- Post-change verification: run `git diff --check`; build if needed.
- New test artifacts: none.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality: not needed.
- [ ] `CHARTER.md` version bumped: not needed, comments only.
- [x] `state/frozen-files.json` updated for these frozen files.
- [ ] Main `README.md` updated if user-visible: not user-visible.

## 8. Outcome

Added comments to document the public resolver contract, the fixed service DB
filename, the separate config/default DB locations, and config fallback
semantics. `git diff --check` passed. `harness_check.py` still reports only the
pre-existing `data_bridge.h` and `usage_record.h` frozen hash drift.
