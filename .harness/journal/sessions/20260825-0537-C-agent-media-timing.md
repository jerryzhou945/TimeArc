# Session Log — agent-media-timing

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-08-25 05:37 → 06:08 (local)
- Branch: `codex/stats-period-layout`
- Baseline commit: `b86d5907`

## Goal

Make Windows count verified Codex task work outside the foreground window,
retain long Bilibili playback attribution, and extend Discord's silent voice
policy to Oopz and KOOK without counting ordinary background processes.

Related error reports:

- [`../errors/20260824-213645-C-codex-media-under.md`](../errors/20260824-213645-C-codex-media-under.md)
- [`../errors/20260824-204236-C-bilibili-browser-site-attribution.md`](../errors/20260824-204236-C-bilibili-browser-site-attribution.md)

## Plan

- Add focused failing tests for long-lived site hints, voice-app policy, and
  background Codex task leases.
- Implement the minimum Windows sampler/state changes without changing DDL.
- Run focused tests, the full harness build, CTest, and Qt log scan.

## Outcome

**implemented and automatically verified; interactive replay pending**

- Codex: independent 90-second worker lease, sibling ChatGPT-tree discovery,
  60-second checkpoints, and contract-safe `unknown`/`Codex task` persistence.
- Media: 10-minute Bilibili site continuity; Oopz/KOOK/KaiHeiLa use Discord's
  Active + unmuted + nonzero-session-volume rule.
- Verification: build wrapper passed; CTest 6/6; Python 30/30; Node 4/4;
  focused red→green tests passed; final Qt scan found no active log.
- Limitation: Codex tool-launched services cannot access the interactive Windows
  foreground (`foreground=0`), so a user-session Bilibili/Codex replay remains
  the final release-candidate smoke test.
- Commit: pending
