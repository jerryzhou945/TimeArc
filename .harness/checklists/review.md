# Checklist — Review

For the reviewer (human or agent) looking at someone else's diff.
Designed to take ~10 minutes on a normal PR.

## 1. Understand

- [ ] Read the session log in `journal/sessions/` for this change. If there
      is none, ask the author to add one before continuing.
- [ ] Restate the change goal in your own words. If you cannot, it's not
      reviewable yet.

## 2. Architecture

- [ ] Layering per [`../rules/01-architecture.md`](../rules/01-architecture.md)
      is intact.
- [ ] No new dependency from `src/services/*.cpp` on anything under
      `src/service/` (note singular vs. plural — the UI manager dir is
      `services/`, the background-service dir is `service/`).
- [ ] Managers remain small, QObject-shaped, and independently usable.

## 3. Data contract

- [ ] Records still validate against the JSON Schema (spot-check a line of
      new `usage_records.jsonl` output if sampling behavior changed).
- [ ] No implicit semantic change to `source`, `duration_sec`, segmentation
      rules, or idle handling without an accompanying amendment.

## 4. Platform work

- [ ] Windows sources guarded under `if(WIN32)`. macOS under `if(APPLE)`.
      Linux under `if(UNIX AND NOT APPLE)`.
- [ ] If macOS `TimeArcService.swift` was extended, the loop mirrors the
      Windows tracker contract (see
      [`../rules/02-platform-boundaries.md`](../rules/02-platform-boundaries.md) §2).
- [ ] If Linux got any code, the single-instance guarantee is still present.

## 5. UI work

- [ ] New pages declare the five theme properties (or derive them).
- [ ] Day/night both look reasonable at a glance.
- [ ] No new hardcoded pixel sizes that will break the desktop/mobile shell
      switch at width 720.
- [ ] No blocking I/O in QML.

## 6. Build

- [ ] `CMakeLists.txt` diffs are limited to the files listed in
      [`../rules/05-build-system.md`](../rules/05-build-system.md) §4 for the
      kind of change being made.
- [ ] Qt linkage remains dynamic-eligible (no new static-only Qt dep).

## 7. Journaling

- [ ] Each error encountered during this change is in
      `journal/errors/` with root cause filled in.
- [ ] `journal/INDEX.md` is updated (or will be auto-updated by
      `record_error.py` when it lands).
- [ ] If this was an L3 (agent-self-reported) error, the lesson is
      summarized in the report so future sessions benefit.

## 8. Licensing

- [ ] No new deps without the documentation described in
      [`../rules/06-licensing.md`](../rules/06-licensing.md).
- [ ] New sources carry SPDX headers.

## 9. Final sanity

- [ ] Would this diff be safely revertible as a single commit? If not,
      should it be split?
- [ ] Is there anything you want to know about this diff that is not in the
      diff, the session log, or the rule files? That's a documentation gap
      — file it as an L3 error with topic `doc-gap`.

Approve only when every non-waived box is ✅.
