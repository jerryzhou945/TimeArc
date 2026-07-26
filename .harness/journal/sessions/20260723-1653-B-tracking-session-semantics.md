# Change Proposal — tracking-session-semantics

## Metadata

- Author: Codex
- Track: B (Feature)
- Date: 2026-07-23 16:53 (local)
- Session goal: Define platform-independent foreground and media session behavior.
- Branch: current working branch
- Related error reports:
  `.harness/journal/errors/20260723-090023-B-markdown-search-quoting.md`
  and `.harness/journal/errors/20260723-090051-B-tracking-semantics-harness-drift.md`

## 1. Frozen files touched

- `.harness/CHARTER.md` — record the platform-independent tracking semantics
  amendment and bump the charter version.

## 2. Motivation

The documentation currently prescribes only app/title foreground identity,
lets input idle override video playback, and mandates media silence grace and
periodic splitting. The intended portable contract instead compares complete
normalized observations, treats video playback as active foreground use, ends
missing media immediately, and leaves persistence checkpointing optional.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | Platform services apply the same logical session and idle rules. |
| Consumer | The UI reads the unchanged tables; record boundaries may differ. |

## 4. Migration plan

No schema or existing-record migration is required. Existing rows remain valid.
Only future segmentation, idle accounting, and media end timing are affected.

## 5. Rollback plan

A documentation revert is sufficient before implementation. Once implemented,
rollback changes only future records; existing rows still require no migration.

## 6. Test plan

- Review all normative documentation for stale app/title-only identity,
  video-idle, silence-grace, and mandatory periodic-flush language.
- Confirm no source file is modified.
- Run `harness_check.py`.

## 7. Sign-off

- [x] `rules/02-platform-boundaries.md` and `rules/03-data-contract.md` updated.
- [x] `CHARTER.md` version bumped.
- [ ] `state/frozen-files.json` regenerated after the commit lands.
- [x] Main `README.md` updated.
