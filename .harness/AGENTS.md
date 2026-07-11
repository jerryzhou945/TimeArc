# AGENTS — Codex Entry Playbook

Read this file first, every session. It tells you **when to read what**.
Details live in `CHARTER.md`, `rules/*.md`, and `tracks/*.md`.

## 1. Project in one paragraph

TimeArc is a Qt6/QML time-tracking app with a **two-process** architecture:
a UI app (`TimeArc`) and a native background service (`time-arc-service`)
that stores foreground/audio history in a service-owned SQLite database plus a
JSON live snapshot. Target platforms: Windows (most complete), macOS (in
progress), Linux (not started). If this is new, stop and read `CHARTER.md` §1–2.

## 2. Pick your track

Every session belongs to **exactly one** of three tracks. Pick before
writing code. See `tracks/README.md` to disambiguate.

| Track            | When                                | Read                     |
|------------------|-------------------------------------|--------------------------|
| **A. Stabilize** | Behavior unchanged, code better     | `tracks/A-stabilize.md`  |
| **B. Feature**   | New capability                      | `tracks/B-feature.md`    |
| **C. Debug**     | Fix a known or observed error       | `tracks/C-debug.md`      |

One session, one track. If you catch yourself doing two, split the session.

## 3. Mandatory reading order

1. `CHARTER.md` — invariants + frozen files.
2. Your track file (`tracks/<letter>-*.md`).
3. Rule files matching what your diff touches:
   - `src/` C++/C/Swift → `rules/01-architecture.md`, `rules/02-platform-boundaries.md`
   - `usage_record.*` / `data_bridge.h` / `database_path.*` → `rules/03-data-contract.md`
   - `qml/` → `rules/04-ui-conventions.md`
   - any `CMakeLists.txt` → `rules/05-build-system.md`
   - new dep or license-relevant → `rules/06-licensing.md`
4. `checklists/before-coding.md` before writing code.

Do not read every rule every time. Read only what your diff touches.

## 4. Working loop — commands Codex MUST run

See `tools/README.md` for full CLI. Abbreviated contract:

1. **Session start** — MUST run:
   `python .harness/tools/preflight.py --track <A|B|C>`
   If exit != 0, STOP; fix drift before any code change.
2. **Plan** — write a session log at the path preflight printed on stdout.
3. **On every error** — MUST run:
   `python .harness/tools/record_error.py --level <L1|L2|L3> --track <A|B|C> --topic <slug> --summary "…"`
4. **Any build** — MUST go through
   `python .harness/tools/build.py` (wraps `cmake --build`, auto-files
   L1 on failure). Do NOT call `cmake --build` directly; bare builds
   miss errors.
5. **Before commit** — MUST run:
   `python .harness/tools/harness_check.py`
   If exit != 0, DO NOT commit. Either fix drift or file a change proposal.

## 5. Frozen files

Listed in `CHARTER.md` §3, mirrored in `state/frozen-files.json`. You may
not edit them without first copying `templates/change-proposal.md` into
`journal/sessions/` and filling it in. Enforcement is honor-system today
and hash-based once `harness_check.py` lands.

## 6. Error recording is mandatory

Every build failure, runtime assertion, QML error, linker error, or
agent-observed "I was wrong about X" MUST be captured via the command in
§4 step 3. Levels:

- **L1** — compile / link / lint.
- **L2** — runtime, QML warnings, service crashes, wrong on-disk data.
- **L3** — agent mistake (wrong premise, unexpected tool failure, rollback).
  Most valuable class over time.

`record_error.py` creates the report, appends the jsonl row, and updates
`INDEX.md` atomically. If it exits 2 (filesystem error), hand-write the
report and file an L3 next session. **No error escapes the journal.**

## 7. Before you commit

Run `checklists/before-commit.md`. In particular: no frozen-file diff
without change proposal; no new third-party dep without license update;
all session errors live in the journal.

## 7b. Token budget

See `OPTIMIZE.md` for how to use this harness cheaply. TL;DR: read on
demand, never the whole corpus; parse tool stderr for `DRIFT:` lines
rather than re-examining source; cite rules by anchor, not by paste.

## 8. What this harness is NOT

- Not a CI replacement. It cannot block a bad commit on its own.
- Not a test framework.
- Not human-facing architecture documentation — that lives in the main
  `README.md`. The harness only captures what must stay true for agents
  to behave. When in doubt, favor **writing something down**.
