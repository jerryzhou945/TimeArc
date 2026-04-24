# Change Proposal — qt-runtime-capture

## Metadata

- Author: Codex
- Track: **B (Feature)** — adds new capability: L2 runtime error capture.
- Date: 2026-04-24 07:45 (local)
- Session goal: install a Qt message handler that tees Warning+ messages
  to a log file the harness can scan into L2 error reports.
- Branch: main
- Related error reports: (none yet)

## 1. Frozen files touched

- `src/CMakeLists.txt` — add `services/harnesslogger.cpp` to
  `TIME_ARC_APP_SOURCES`. No change to include dirs, no change to
  existing entries.

## 2. Motivation

AGENTS.md §6 requires every QML warning / Qt critical / fatal to be
journaled. Today agents must notice and hand-call `record_error.py`. This
proposal adds a passive capture path so agents cannot silently miss
runtime errors. The handler writes to disk; `tools/scan_qt_log.py` (to be
added alongside) converts log lines into L2 reports.

## 3. Impact on the other process

| Side     | Effect                                                      |
|----------|-------------------------------------------------------------|
| Producer | none — service is unchanged.                                |
| Consumer | UI installs one extra message handler. Zero overhead when  |
|          | no warnings fire. Log path: TimeArc/logs/harness-qt.log.    |

## 4. Migration plan

None. New file; no on-disk format change; no record schema change. The
log file is harness-internal; absent until first warning fires.

## 5. Rollback plan

Revert the three changes: new files `src/services/harnesslogger.{h,cpp}`,
`src/main.cpp` hook, and `src/CMakeLists.txt` entry. Re-bootstrap frozen
hashes.

## 6. Test plan

- Pre: run UI, trigger any QML warning, confirm it only goes to stderr.
- Post: same action produces a line in `TimeArc/logs/harness-qt.log`.
- Run `tools/scan_qt_log.py` and confirm one L2 report appears.

## 7. Sign-off

- [x] Rule updates: `rules/05-build-system.md` already covers hook model;
      no rule file needs editing here.
- [ ] `CHARTER.md` version bump — **NOT NEEDED** (this change does not
      amend any invariant in CHARTER §2; it adds a file listed under
      `src/CMakeLists.txt`).
- [ ] `state/frozen-files.json` regenerated after commit lands.
- [ ] Main `README.md` updated if user-visible — **NOT NEEDED**.
