# Claude Code Entry For TimeArc

Read this file first when using Claude Code in this repository.

## Required Start

This repo already has an agent harness. Follow it exactly.

1. Read `AGENTS.md`.
2. Read `.harness/AGENTS.md`.
3. Pick exactly one track:
   - `A`: stabilize, no behavior change.
   - `B`: feature, product docs, new capability.
   - `C`: debug, fix known/observed error.
4. Run:

```powershell
python .harness/tools/preflight.py --track <A|B|C>
```

If preflight fails, stop and fix/report the drift before editing.

## Project Context

TimeArc is a Qt6/QML desktop/mobile time-tracking app plus a separate native
background service. The service samples foreground apps and audio activity,
writes disk records, and the UI reads those records. Two processes, one disk
contract.

Do not bypass the disk contract. Do not add IPC, sockets, shared memory, or
direct links from UI managers into service internals.

## Product Context

For card, AI, Memory Lake, or mobile planning work, read:

- `docs/life-timeline-product-direction.md`
- `docs/card-ai-development-spec.md`
- `docs/future-coding-harness.md`
- `.harness/rules/07-product-ai-cards.md`

Product principle:

> TimeArc records time context, not private content. AI summarizes only after
> local filtering and user confirmation.

Hard boundaries:

- No chat content.
- No screenshots/OCR in MVP.
- No raw audio.
- No default browser history or URL capture.
- No AI over raw logs.

Implementation rule:

> Prefer the smallest runnable vertical slice with acceptable quality. Avoid
> broad detours, unrelated refactors, premature mobile-stack choices, and AI
> work before local deterministic cards exist.

## Claude-Specific Notes

Claude Code project memory is advisory; the project harness is authoritative.
If this file conflicts with `AGENTS.md` or `.harness/CHARTER.md`, follow the
harness and mention the conflict.

Do not edit frozen files listed in `.harness/CHARTER.md` unless a change
proposal has been filed first.

Use PowerShell-safe commands on Windows. The workspace path contains a space:
`F:\Git Proj\TimeArc`.

## Before Finishing

Run:

```powershell
python .harness/tools/harness_check.py
```

If any build, runtime, QML, or agent mistake happened, record it with:

```powershell
python .harness/tools/record_error.py --level <L1|L2|L3> --track <A|B|C> --topic <slug> --summary "..."
```
