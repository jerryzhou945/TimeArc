# Session Log — Codex post-task overcount

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-08-25
- Branch: `codex/stats-period-layout`

## Goal

Explain why Windows Codex agent time continues increasing after a command ends,
using the live service database and the current activity-state implementation.

Related error report:

- [`../errors/20260825-014225-C-codex-post-task-overcount.md`](../errors/20260825-014225-C-codex-post-task-overcount.md)

## Plan

- Inspect the Codex process-activity lease and close boundary.
- Compare it with consecutive live `Codex task` database rows.
- Report the root cause without changing policy in this diagnostic-only turn.

## Outcome

Root cause confirmed: the Windows agent session renews a 90-second lease on each
CPU/I/O signal and exports the current wall time when that lease expires. A new
Codex request arriving inside the lease keeps the database rows continuous, so
the user's read/reply gap is counted as work. No production code was changed.
