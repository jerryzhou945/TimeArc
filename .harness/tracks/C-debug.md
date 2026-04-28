# Track C — Debug

**Goal.** Fix a known or freshly discovered bug. Minimum necessary change.

## Entry rule

**Every debug session must correspond to an error report** in
`journal/errors/`. If one does not exist, create it first via
`tools/record_error.py` (or by hand using `templates/error-report.md` while
the tool is a stub). The report's filename is referenced from the session
log's `Related error report(s):` field.

This is the most important rule of this track: **no ghost fixes**. If you
cannot write down what is wrong, you are not ready to fix it.

## Allowed

- Targeted code changes that address the root cause identified in the report.
- Adding an assertion or a narrow logging line where the bug surfaced.
- Updating a single rule file if the root cause exposes a documentation gap.

## Forbidden

- "While I was there" cleanups — that is track A, file a separate session.
- Adding features — that is track B.
- Changing the data contract without filing a change proposal first (even if
  the bug is a schema bug, the proposal comes first).
- Silencing the error without explaining why (e.g., deleting a `qWarning`).

## Entry — before-coding delta

On top of `checklists/before-coding.md`:

- [ ] Open the error report and fill §1 (what happened) and §2 (evidence) if
      the bug was just found.
- [ ] Reproduce the bug locally. Record the exact repro steps in §2.
- [ ] Propose a hypothesis in §3 before touching code. "I don't know yet" is
      a valid hypothesis — say so.

## Exit — before-commit delta

On top of `checklists/before-commit.md`:

- [ ] Error report §3 (root cause) is filled with your actual finding, not
      your initial hypothesis if they differ.
- [ ] Error report §4 (fix) lists the files changed and the commit SHA (or
      "pending commit").
- [ ] Error report §5 (prevention) names one concrete harness upgrade, or
      explicitly says "one-off, no harness change needed".
- [ ] The original repro no longer triggers. Attach the verification output.
- [ ] `journal/INDEX.md` has a new row at the top (auto or manual).

## Commit message

First word is `Fix`. Existing log has several: none yet, so this is the
seed — future agents, match this style.

## Journal slug

`YYYYMMDD-HHMM-C-<topic>` — e.g., `20260430-1030-C-jsonl-cr-escape`.

## L3 (agent self-report) sub-case

If the "bug" is an agent mistake — wrong premise, bad tool call, rollback —
track C still applies, with two tweaks:

- The fix may well be a **harness change** (rule file, checklist, template),
  not a code change. That's fine; treat the rule file as the code.
- Error report §6 must be filled with the honest lesson, in plain English,
  with a pointer to which rule should now prevent the mistake.

## Current bug candidates (cross-reference `state/open-issues.md`)

- UTF-8 validation TODO in `usage_storage.c` (behavioral bug potential).
- Windows `remove`+`rename` race on `usage_current.json` under crash.
- `DesktopMemoryLakePage` placeholder showing as functional (UX bug).
