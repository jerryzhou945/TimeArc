# Session Log — wechat-autonomous-lease

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-08-25 05:18 → in progress (local)
- Branch: `codex/stats-period-layout`
- Baseline commit: `b86d5907`

## Goal

Prevent ordinary foreground applications such as WeChat from renewing idle
time through background CPU/I/O while preserving the official Codex work lease
and all existing media/Discord behavior.

Related error report:

- [`../errors/20260824-211826-C-wechat-autonomous-lease.md`](../errors/20260824-211826-C-wechat-autonomous-lease.md)

## Plan

- Add a failing policy regression for generic apps versus packaged Codex.
- Restrict process-based autonomous evidence to the packaged Codex frontend.
- Build, run Windows tracking tests, and inspect the resulting behavior.

## What actually happened

- 05:16 — live database evidence showed 2,854 active seconds and only 41 idle seconds for WeChat today.
- 05:18 — source inspection found generic process deltas renewing the foreground work lease.
- 05:19 — the new policy regression failed at link time before the helper existed.
- 05:20 — autonomous roots were restricted to packaged Codex worker processes.
- 05:21 — build and all 6 CTest targets passed; the rebuilt service started as PID 24100.

## Outcome

**done** — generic foreground process churn no longer defeats the 60-second idle threshold.

- Commits landed: none
- Files touched: Windows process activity sampler/header, foreground policy tests, report and harness records
- Frozen files touched: no
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

Keep Discord/audio policy unchanged and preserve unrelated statistics-page edits.
