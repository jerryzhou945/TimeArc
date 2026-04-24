# Harness Tools — Machine Interface for Codex

Contract between Codex and the harness. Each tool has a documented CLI and
exit code. Codex **MUST** treat a non-zero exit as a blocking signal.

Convention: `python` is Windows-friendly; Unix may need `python3`. All tools
are pure stdlib, no pip install. Stderr carries human prose; stdout is
machine-readable when anything useful is emitted.

## preflight.py

Session bootstrap. Run at the start of every session.

    python .harness/tools/preflight.py [--track A|B|C]

Runs `harness_check.py --fast`, prints open-issues hint, emits session-log
path. Exit: `0` clean / `1` drift / `2` internal.

## build.py

Wrap `cmake --build` so any non-zero exit is auto-logged as L1.

    python .harness/tools/build.py [--build-dir build] \
        [--track A|B|C] [--topic <slug>] [--session <file>] \
        [-- <extra cmake args>]

Success: exit 0 + log at `journal/build-logs/<ts>-build.log`.
Failure: same log + auto `record_error.py --level L1`. Exit mirrors build.

## record_error.py

Log one error into the journal.

    python .harness/tools/record_error.py \
        --level L1|L2|L3 --track A|B|C \
        --topic <kebab-slug>  # [a-z0-9-], <= 40 chars
        --summary "one line" \
        [--file path/to/log] [--platform windows|macos|linux|n-a] \
        [--session sessions/<file>.md]

Atomic per call: creates `journal/errors/<ts>-<track>-<topic>.md`, appends
one JSON row to `journal/errors.jsonl`, inserts one row in `INDEX.md`.
Prints the report path to stdout on success. Exit: `0` / `1` usage /
`2` filesystem.

## scan_qt_log.py

Drain the Qt message log written by `installHarnessLogger()` into L2
reports. One report per unique `(severity, file:line, message)` tuple.

    python .harness/tools/scan_qt_log.py [--log PATH] [--track C] [--dry-run]

Default log path mirrors `QStandardPaths::GenericDataLocation`
`/TimeArc/logs/harness-qt.log`. Rotates to `.consumed.<ts>` after.

## harness_check.py

Full audit. Run before commit.

    python .harness/tools/harness_check.py [--fast | --bootstrap]

Passes:
1. **line-budget** — `*.md` under `.harness/` ≤ 100 lines.
2. **frozen-file hashes** — `state/frozen-files.json` matches.
3. **CMake structure** — required variables present in each `CMakeLists.txt`.
4. **platform isolation** — no Qt under `src/service/`; no platform SDK in
   `src/service/shared/*.h`.
5. **journal hygiene** — `errors/*.md` ↔ `errors.jsonl` (empty md = tombstone).
6. **slug shape** — errors match `YYYYMMDD-HHMMSS-[ABC]-kebab.md`; sessions
   match `YYYYMMDD-HHMM-[ABC]-kebab.md`.
7. **track discipline** — `state/current-track` vs `git status`:
   A forbids new source, B requires rules/ or README update, C requires an
   errors/ link in the latest C-track session log.

`--bootstrap`: one-shot; writes current sha256 into `state/frozen-files.json`.
Use only after a charter amendment.

`--fast`: skip passes 3-7.

Exit: `0` clean / `1` drift / `2` internal.

## How Codex MUST treat failures

- `preflight.py` exit 1 → **stop** and fix drift before any code change.
- `record_error.py` exit 2 → journal broken; hand-write the report and file
  an L3 in the next session.
- `harness_check.py` exit 1 → **do not commit** until exit 0 or mark the
  drift as intentional in a change proposal.
