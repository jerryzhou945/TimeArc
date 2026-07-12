# Change Proposal — retire-usage-record-contract

## Metadata

- Author: Codex `/root`
- Track: B (Feature)
- Date: 2026-07-12 20:43 (local)
- Session goal: Remove the unused `TimeArcUsageRecord` contract and align build and documentation with the table-specific data bridge.
- Branch: `development/macos-support`
- Related error reports: `errors/20260712-124337-B-build-failure.md` (sandbox-only Swift module-cache failure)

## 1. Frozen files touched

- `src/service/shared/usage_record.h` — delete the unused aggregate record type.
- `src/service/CMakeLists.txt` — remove the deleted header from the service target.
- `.harness/CHARTER.md` — remove the retired file from the frozen list and record the contract cleanup.
- `.harness/AGENTS.md` — route shared-contract changes through the live bridge and database files.

## 2. Motivation

Commit `a887833` removed the final `TimeArcUsageRecord` consumer when Windows storage moved to the table-specific `data_bridge.h` API. Keeping the header and its prose now advertises a contract that no producer or consumer follows.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | No runtime change; services already submit app, foreground, and media fields through `data_bridge.h`. |
| Consumer | No runtime change; the UI already reads the three service SQLite tables directly. |

## 4. Migration plan

No on-disk impact. Table names, columns, values, database paths, and ownership remain unchanged.

## 5. Rollback plan

A code revert restores the header and documentation; no data restoration is needed.

## 6. Test plan

- Pre-change reproduction: search finds no include or type use outside the obsolete header, only build/document references.
- Post-change verification: search finds no active `usage_record` or `TimeArcUsageRecord` references; build and harness checks pass.
- New test artifacts: none.

## 7. Sign-off

- [x] `rules/01-architecture.md` and `rules/02-platform-boundaries.md` will reflect the table-specific contract.
- [x] `CHARTER.md` will be bumped to v0.10.
- [x] `state/frozen-files.json` was regenerated after edits.
- [x] Main `README.md` will be updated where it names the obsolete contract.

## Outcome

The obsolete aggregate header and protocol document were deleted. Active
architecture, platform, build, checklist, README, backlog, and audit documents
now describe the table-specific bridge and three-table SQLite contract. The
post-change build, database smoke test, stale-reference search, and full harness
check passed; there is no on-disk or runtime behavior change.
