# Change Proposal — root-agents-entry

## Metadata

- Author: Codex
- Track: **B (Feature)** — adds a new file (`AGENTS.md` at project
  root) and extends the frozen list to include it.
- Date: 2026-04-24 08:00
- Session goal: make the harness discoverable to Codex CLI by its
  default convention.
- Branch: main

## 1. Frozen files touched

- `.harness/CHARTER.md` §3 — add `AGENTS.md` (root) to the frozen list.
  No other §2 invariant changes.

## 2. Motivation

Codex CLI's default entry discovery is the project-root `AGENTS.md`.
Without one, Codex starts a session without reading any harness
content, silently bypassing every MUST. This proposal adds a thin
root-level AGENTS.md that summarizes the MUST-commands and points
Codex to `.harness/AGENTS.md` for full detail.

## 3. Impact on the other process

| Side     | Effect                                                 |
|----------|--------------------------------------------------------|
| Producer | none                                                   |
| Consumer | none — agent-facing doc only                           |

## 4. Migration plan

None. New file; no schema change; no code change.

## 5. Rollback plan

Delete root `AGENTS.md`, revert CHARTER.md §3 edit, re-bootstrap.

## 6. Test plan

- Pre: no AGENTS.md at project root; Codex CLI `ls` does not find one.
- Post: root AGENTS.md present, <= 100 lines, frozen, and lists the
  five MUST commands in the same order as `.harness/AGENTS.md`.

## 7. Sign-off

- [ ] CHARTER.md §3 edit lands in the same commit.
- [ ] `state/frozen-files.json` re-bootstraps after commit.
- [ ] Rule updates: none.
- [ ] README.md — optional; will mention root AGENTS.md if a
      subsequent session touches it.
