# Error Report — <topic>

> Copy this to `.harness/journal/errors/YYYYMMDD-HHMMSS-<topic>.md`.
> Also append a matching one-line record to `.harness/journal/errors.jsonl`:
>
> ```json
> {"timestamp":"<ISO8601>","level":"L1|L2|L3","topic":"<topic>","summary":"<one line>","file":"<path/to/this/report>"}
> ```

## Metadata

- Level: **L1 / L2 / L3** (keep one)
- Track: **A / B / C** (see `../tracks/README.md`) — the track of the session
  that found the error; debug fixes usually land under track C.
- Topic: <short-slug>
- Session: `journal/sessions/YYYYMMDD-HHMM-<track>-<slug>.md`
- Platform: windows / macos / linux / n-a
- Tooling: cmake / qt / qml / swift / bash / …

## 1. What happened

One paragraph. The shortest possible factual description of the failure mode.
No speculation.

## 2. Evidence

Paste the relevant build log, runtime log, or QML error verbatim. Trim to the
signal, but keep enough context that a future reader can match it.

```
<log excerpt>
```

## 3. Root cause

Fill this in only after you actually understand the failure. If you patched
before fully understanding, say so — that is itself information.

- Immediate cause:
- Underlying cause:
- Why the harness/checklists did not prevent it:

## 4. Fix

- Files changed:
- Short description of the fix:
- Commit (if landed):

## 5. Prevention

What, if anything, should be added to the harness so this class of error is
harder next time? Options:

- A new item in a checklist — specify which.
- A new assertion / build check — specify where.
- A new frozen file — if so, this report implies a charter amendment.
- Nothing — some errors are genuinely one-offs. Say so.

## 6. Lessons for agents (L3 only)

If this was an L3 (agent self-observed), answer in plain English:

- What assumption did I make that turned out wrong?
- What could I have read or checked earlier to avoid the wrong assumption?
- Is there a rule file or section of `AGENTS.md` that should be updated so the
  next agent does not repeat this?
