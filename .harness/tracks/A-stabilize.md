# Track A — Stabilize

**Goal.** Raise code quality without changing observable behavior.

## Allowed

- Renaming locals / parameters / private methods.
- Extracting helpers, inlining single-use helpers.
- Comment cleanup, doc comments, `TODO` housekeeping.
- Dead-code removal.
- Compiler-warning fixes (with no semantic change).
- Whitespace / formatting aligned with the surrounding file.
- Splitting an oversize file into two files **without** changing the include
  graph seen by other modules.

## Forbidden

- New third-party dependencies.
- Edits to any frozen file (see `CHARTER.md` §3).
- New QML pages, new managers, new sampling sources, new `source` enum values.
- New platform branches in `src/service/CMakeLists.txt`.
- Behavior changes disguised as cleanup (e.g., "while I was there I also
  lowered the idle threshold").

If you find yourself wanting any of the above, stop and switch to track B.

## Entry — before-coding delta

On top of `checklists/before-coding.md`:

- [ ] Name three specific sub-areas you will touch. Scope creep is the single
      biggest risk of this track.
- [ ] Predict the diff size in lines. If > ~300 net, split the session.
- [ ] Build the baseline; note any pre-existing warnings — fixing those is
      in-scope, introducing new ones is not.

## Exit — before-commit delta

On top of `checklists/before-commit.md`:

- [ ] **No-behavior-delta statement** in the commit body: "Observable behavior
      unchanged; journal output byte-identical on smoke test."
- [ ] Smoke test: run UI + service for ≥ 60 s, diff the first N lines of
      `usage_records.jsonl` against a pre-change run. Differences must be
      explainable by timestamps alone.
- [ ] No new warnings on the default build configuration.

## Commit message

First word is one of: `Refine`, `Clean up`, `Polish`, `Simplify`, `Rename`,
`Reorder`. Examples from the existing log that match this track style:
`Refine service structure`, `Strengthen cream mint background gradient`.

## Journal slug

`YYYYMMDD-HHMM-A-<area>` — e.g., `20260501-0930-A-audio-tracker-rename`.

## Typical wins in this repo right now

- UTF-8 escaping and validation in `usage_storage.c` (comment TODO already
  there; mechanical cleanup fits here, behavioral fix is track C).
- Consolidating color constants in the three big QML pages
  (`DesktopHomePage`, `DesktopStatsPage`, `DesktopCalenderPage`).
- Extracting the repeated `copy_string` helper family.
- Splitting `DesktopHomePage.qml` (1554 lines) into components.
