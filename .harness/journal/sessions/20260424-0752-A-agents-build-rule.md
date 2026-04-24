# Change Proposal — agents-build-rule

## Metadata

- Author: Codex
- Track: **A (Stabilize)** — no new behavior, hardens an existing soft
  convention into the MUST list.
- Date: 2026-04-24 07:52 (local)
- Session goal: make `tools/build.py` the canonical build command in
  AGENTS.md, so bare `cmake --build` stops being used in practice.
- Branch: main

## 1. Frozen files touched

- `.harness/AGENTS.md` — add a fifth MUST-step to §4 covering build.

## 2. Motivation

`build.py` auto-captures L1 errors; bare `cmake --build` does not. Without
naming it in AGENTS.md, future Codex sessions will keep using the raw
command and miss errors. Harden.

## 3. Impact on the other process

| Side     | Effect                                 |
|----------|----------------------------------------|
| Producer | none                                   |
| Consumer | none — agent-facing doc change only    |

## 4. Migration plan

None. No on-disk or schema change.

## 5. Rollback plan

Revert the AGENTS.md diff, re-bootstrap frozen hashes.

## 6. Test plan

- Pre: `grep -c 'build.py' AGENTS.md` == 0.
- Post: ≥ 1, plus `cmake --build` appears only as "do not call directly".

## 7. Sign-off

- [ ] Rule updates: none (rules/05 already documents build.py).
- [ ] CHARTER.md version bump: NOT NEEDED.
- [ ] frozen-files.json re-bootstrap after commit.
