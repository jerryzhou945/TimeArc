# Track B — Feature

**Goal.** Add a new capability to the app.

## Allowed

- New source files in any layer (see `rules/01-architecture.md` for placement).
- New QML pages and components (remember both shells — `rules/04` §1).
- New sampling sources — with a schema amendment (`rules/03`).
- New platform branches — with a `src/service/CMakeLists.txt` edit and an
  enum addition in the schema (`rules/02` §4, `rules/03`).
- New third-party deps — with full sign-off per `rules/06` §2.
- New QObject managers — following the existing four as template.

## Required

- Two-sided design. Feature work almost always crosses the UI/service seam.
  Before coding, write one paragraph **for each side** in the session log:
  what the service emits, what the UI consumes.
- Rule-file updates. If the feature changes what `rules/0X-*.md` claims, the
  rule update lands **in the same commit** as the code.
- `README.md` updates if the feature is user-visible.
- Change proposal (`templates/change-proposal.md`) if any frozen file moves.

## Entry — before-coding delta

On top of `checklists/before-coding.md`:

- [ ] Session log includes a "Service side / UI side" design paragraph pair.
- [ ] Confirm which rule files will need updating. List them.
- [ ] If schema or `data_bridge.h` change, change-proposal is filed first.

## Exit — before-commit delta

On top of `checklists/before-commit.md`:

- [ ] Both sides compile and run together. A feature that only lights up one
      side is a track-B session that isn't done yet.
- [ ] Rule files and `README.md` are updated. Grep for stale references.
- [ ] A quick manual smoke path is documented in the session log: "launch
      app, click X, see Y in journal".
- [ ] If a new platform or source was added, a matching entry exists in
      `state/open-issues.md` (or is removed from it — whichever applies).

## Commit message

First word is one of: `Add`, `Implement`, `Enable`, `Introduce`, `Support`.
Examples from the existing log that match: `Audio/Video tracking for macOS`,
`Build the basic framework of the service`.

## Journal slug

`YYYYMMDD-HHMM-B-<capability>` — e.g., `20260510-1400-B-sqlite-writer`.

## Concrete feature queue (see `state/open-issues.md`)

- Linux service: X11 + Wayland sampling, PipeWire audio, single-instance guard.
- macOS service main loop: mirror Windows `usage_tracker.c` contract.
- Windows SCM registration: Route A (user-session logon autostart) shipped in `win_service.c` (PR #37); Route B (true SCM Session-0 broker) deferred.
- SQLite writer + migrator (see the SQLite plan in `tracks/B-feature.md`
  §Playbook below).
- Memory Lake data model + UI.
- Third-party license page in QML.
- User-config JSON parser using bundled Parson.

## Playbook — SQLite migration (moved from rules/03)

1. Implement `timearc_storage_write_sqlite`, gated by the existing
   `use_sqlite` flag.
2. Ship a read-only SQLite consumer in `UsageStatManager`, feature-flagged.
3. Ship a one-shot migrator that produces `usage_records.jsonl.bak` and
   refuses to proceed if the row counts disagree.
4. Flip `use_sqlite` default-on; keep JSONL writing for N releases.
5. Retire JSONL after N releases; final `rules/03` amendment.
