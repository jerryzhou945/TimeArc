# Session Log — <slug>

> Copy to `.harness/journal/sessions/YYYYMMDD-HHMM-<slug>.md` at session start.
> Update throughout. Close out at commit time.

## Metadata

- Agent / Author:
- Track: **A (Stabilize) / B (Feature) / C (Debug)** — pick one; see `../tracks/README.md`.
- Date: YYYY-MM-DD HH:MM → HH:MM (local)
- Branch:
- Baseline commit:

## Goal

One sentence. Same sentence used in `checklists/before-coding.md`.

## Plan

Short bullet list of the intended steps. This is a plan, not a diary — it is
allowed to be stale by the time the session ends, but should be readable.

-
-
-

## What actually happened

Rough chronological narrative. Each time something unexpected happens, link
to the error report:

- HH:MM — <did X>
- HH:MM — build failed, see [`../errors/YYYYMMDD-HHMMSS-<topic>.md`](../errors/YYYYMMDD-HHMMSS-<topic>.md)
- HH:MM — fixed and rebuilt
- …

## Outcome

One of: **done / partial / rolled back / abandoned**.

- Commits landed:
- Files touched:
- Frozen files touched (y/n — if y, link to change-proposal header):
- Follow-ups spun out to `../state/open-issues.md` (list):

## Notes for the next agent

Anything worth knowing that is not already captured in the commit message or
the rule files. Keep it short; if it's important, update a rule file instead
and note that here.
