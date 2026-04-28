# AGENTS — Project Root Entry

**Codex, read this first — and then read `.harness/AGENTS.md` for the
full playbook.** This file is the root-level entry point that Codex CLI
(and other agents following the AGENTS.md convention) discovers
automatically. The authoritative details live under `.harness/`; this
file exists only so the harness is not bypassed.

## Project in one sentence

TimeArc is a Qt6/QML time-tracking desktop/mobile app with a separate
native background service that samples foreground apps and audio into
a journal; the UI reads that journal. Two processes, one disk contract.

## You MUST, every session

Each command is a hard gate — non-zero exit blocks the step.

1. **Session start**:
   `python .harness/tools/preflight.py --track <A|B|C>`
2. **On any error** (build, runtime, self-observed mistake):
   `python .harness/tools/record_error.py --level <L1|L2|L3> --track <A|B|C> --topic <slug> --summary "..."`
3. **Any build**:
   `python .harness/tools/build.py` (NOT bare `cmake --build`)
4. **After a Qt/QML run**:
   `python .harness/tools/scan_qt_log.py`
5. **Before commit**:
   `python .harness/tools/harness_check.py`

## Pick exactly one track per session

- **A Stabilize** — quality up, behavior unchanged. `tracks/A-stabilize.md`
- **B Feature** — new capability. `tracks/B-feature.md`
- **C Debug** — fix a known error. `tracks/C-debug.md`

## Required reading (in order, on demand — do not bulk-read)

1. `.harness/AGENTS.md` — full playbook (this file's authoritative parent)
2. `.harness/CHARTER.md` — invariants + frozen-files list
3. `.harness/tracks/<your-track>.md`
4. `.harness/rules/0X-*.md` — only the ones your diff touches
5. `.harness/OPTIMIZE.md` — how to keep context cost low

## Do not edit frozen files without a change proposal

Frozen files are listed in `.harness/CHARTER.md` §3 and hash-locked in
`.harness/state/frozen-files.json`. Editing one without a matching
`.harness/journal/sessions/YYYYMMDD-HHMM-<track>-<slug>.md` filed first
will be caught by `harness_check.py` pass 2.

## This file is itself frozen

Changing it requires a change proposal, same as `.harness/AGENTS.md`.
