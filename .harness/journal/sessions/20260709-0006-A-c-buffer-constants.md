# Change Proposal - c-buffer-constants

## Metadata

- Author: Codex
- Track: A (Stabilize)
- Date: 2026-07-09 00:06 CST
- Session goal (one sentence): Replace remaining C hardcoded path/title/name buffer sizes with the shared `TA_MAX_*_BYTES` constants from `util.h`.
- Branch: development/macos-support
- Related error reports: `errors/20260708-160530-A-preflight-drift.md`, `errors/20260708-160923-A-chained-read-command.md`

## 1. Frozen files touched

- `src/service/shared/usage_record.h` - replace literal field array sizes with existing `TA_MAX_PATH_BYTES`, `TA_MAX_TITLE_BYTES`, and `TA_MAX_NAME_BYTES`.
- `src/service/shared/usage_paths.c` - replace path-construction scratch buffer literals with `TA_MAX_PATH_BYTES`.

## 2. Motivation

Several C-facing record/storage/path buffers still spell out raw byte counts directly even though `src/include/util.h` defines the canonical sizes. Using the shared names keeps record buffers aligned with platform sampling buffers.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Service C code uses named constants for the same buffer capacities; no record writer behavior changes. |
| Consumer | The in-memory C record layout remains byte-equivalent because the macro values match the old literals; no UI read behavior changes. |

## 4. Migration plan

No on-disk impact. `usage_records.jsonl`, `usage_current.json`, and SQLite rows keep the same schema and values.

## 5. Rollback plan

A code revert restores the literals. No data restore is required.

## 6. Test plan

- Pre-change reproduction: `rg -n "\b(4096|512|256)\b" src --glob '*.c' --glob '*.h'` shows remaining path/title/name literals in C-facing files.
- Post-change verification: the same search no longer shows those literals outside `util.h`; harness build succeeds.
- New test artifacts: none planned.
- Result: `git diff --check` passed; `rg -n "\b(4096|512|256)\b" src --glob '*.c' --glob '*.h'` now only reports `src/include/util.h`; `python .harness/tools/build.py --track A --session .harness/journal/sessions/20260709-0006-A-c-buffer-constants.md` passed.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality (not needed).
- [x] `CHARTER.md` version bumped (not needed).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible.
