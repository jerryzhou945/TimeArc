# TimeArc Harness

A lightweight harness for AI coding agents (primarily Codex) and human reviewers
working on the **TimeArc** project. The harness exists to:

1. **Converge** agent behavior onto the project's real architecture so that
   refactors do not drift.
2. **Review** every change against a consistent checklist, regardless of who
   authors it.
3. **Remember** every error — build, runtime, or agent self-report — in a
   durable, grep-able journal.

## Layout

```
.harness/
├── README.md                     ← this file
├── AGENTS.md                     ← Codex entry playbook (MUST READ)
├── CHARTER.md                    ← untouchable invariants + frozen files
├── tracks/                       ← A/B/C workflows: stabilize, feature, debug
├── rules/                        ← topic rules referenced from AGENTS.md
├── checklists/                   ← before-coding / before-commit / review
├── templates/                    ← change proposals, error reports, session logs
├── journal/                      ← error + session journal (md + jsonl)
├── tools/                        ← record_error.py, harness_check.py, cmake hooks
└── state/                        ← frozen-files hash lock, open issues
```

**Every markdown file in this harness must stay ≤ 100 lines.** If you need
more room, split by concern into an adjacent file and link. Keeping them
short is what makes Codex actually read them.

## How to use

- **Agents (Codex etc.)**: start by reading [`AGENTS.md`](AGENTS.md).
- **Human reviewers**: skim `CHARTER.md`, then pick the checklist that matches
  the stage (`before-coding`, `before-commit`, `review`).
- **Error recording**: invoke `tools/record_error.py` — the CLI appends to
  `journal/errors.jsonl` and writes a human-readable report under
  `journal/errors/`.

## Status

| Component        | Status      | Notes                                                       |
|------------------|-------------|-------------------------------------------------------------|
| Playbook docs    | bootstrap   | v0.1 skeleton — refine as the project evolves               |
| Checklists       | bootstrap   | covers the v0.1 architecture; update alongside code changes |
| `record_error.py`| implemented | Atomic md + jsonl + INDEX update                            |
| `harness_check.py`| implemented| 7-pass audit with `--bootstrap`                             |
| CMake hooks      | implemented | `timearc_harness_enable()` + harness-check target           |

See [`journal/INDEX.md`](journal/INDEX.md) for the error log.
