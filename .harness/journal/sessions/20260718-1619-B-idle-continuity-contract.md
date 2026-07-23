# Change Proposal — idle-continuity-contract

## Metadata

- Author: Codex `/root`
- Track: **B (Feature)** — changes foreground-session semantics.
- Date: 2026-07-18 16:19 (Asia/Shanghai)
- Session goal: Define idle as paused foreground active time, not a session boundary.
- Branch: `development/macos-support`
- Related error reports: `errors/20260718-082135-B-idle-continuity-patch-context.md`,
  `errors/20260718-082225-B-harness-index-line-budget.md`

## 1. Frozen files touched

- `.harness/CHARTER.md` — record the amended idle/session contract and bump it to v0.11.

Rules updated with the amendment: `rules/02-platform-boundaries.md` and
`rules/03-data-contract.md`.

## 2. Motivation

Foreground tracking should retain the current app/window session while the
user is idle, stop accumulating `active_sec`, and resume that session when the
same identity returns. Closing on idle prevents `idle_sec` from representing
idle time and conflicts with the selected macOS accumulator design.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Service implementations keep a foreground session open across idle and exclude idle intervals from `active_sec`. |
| Consumer | The UI continues reading the same schema; `idle_sec` may now be nonzero and remains generated as `duration_sec - active_sec`. |

## 4. Migration plan

No DDL or record migration is required. Existing rows with `idle_sec = 0`
remain valid. New rows may span idle intervals and have nonzero `idle_sec`;
both shapes coexist under the current table schema.

## 5. Rollback plan

Revert the charter and rule changes and restore idle-triggered segmentation.
Existing rows remain structurally valid; no database restoration is required.

## 6. Test plan

- Pre-change reproduction: observe the Windows service close and insert a foreground row when the idle threshold is reached.
- Post-change verification: remain idle past the threshold, resume the same app/window, and verify one row spans the interval with `active_sec < duration_sec` and `idle_sec > 0`.
- New test artifacts: none in this harness-contract-only change.

## 7. Sign-off

- [x] `rules/02-platform-boundaries.md` and `rules/03-data-contract.md` updated.
- [x] `CHARTER.md` version bumped to v0.11.
- [x] `state/frozen-files.json` regenerated for the amended charter.
- [x] Main `README.md` not applicable to this harness-contract-only change.
