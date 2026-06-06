# Checklist — Before Commit

Run top-to-bottom. Do not commit until every item is ✅ or explicitly waived
in the commit message body.

## 1. Scope

- [ ] The session stayed on **one track** (A / B / C). If it drifted, split
      the commit. See [`../tracks/README.md`](../tracks/README.md).
- [ ] Run the track-specific exit delta in `../tracks/<letter>-*.md`.
- [ ] Diff size is justified by the session goal stated in
      `journal/sessions/`. No unrelated drive-by edits.
- [ ] If the diff touches a frozen file, a matching change proposal exists in
      `journal/sessions/` with motivation, migration plan, and rollback plan.
- [ ] No accidentally committed files: `build/`, `CMakeCache.txt`,
      `compile_commands.json`, IDE state, `.tmp`, `.bak`.

## 2. Architecture compliance

- [ ] Include graph respects [`../rules/01-architecture.md`](../rules/01-architecture.md).
      (No Qt under `src/service/`. No platform headers under
      `src/service/shared/`. No cross-platform service includes.)
- [ ] Platform gating in `src/service/CMakeLists.txt` is intact.
- [ ] If you added a new manager or QML page, the shells
      (`DesktopAppShell` + `MobileAppShell`) know about it.

## 3. Data contract

- [ ] Nothing written to disk violates
      [`../rules/03-data-contract.md`](../rules/03-data-contract.md).
- [ ] If `usage_record.h`, `usage_record.schema.json`,
      `data_bridge.h`, or `usage_paths.*` changed, there is a charter
      amendment and a data migration note.
- [ ] If you added a new `source` value (beyond `foreground|audio`), it is in
      the schema enum **and** handled by `UsageStatManager`.

## 4. Build

- [ ] `cmake --build` succeeds on at least one configured platform.
- [ ] No new warnings on your platform's default warning level. (If there
      are, file an L1 error report instead of ignoring them.)
- [ ] `time-arc` and `time_arc_service` both still build.

## 5. Runtime sanity

- [ ] If you changed the UI, the app launches, navigates to your changed
      page, and does not emit QML warnings to the console.
- [ ] If you changed a **full-bleed page** (记忆湖/日历/回顾), check it at the
      **window minimum (1280×720) and maximized** — these pages use fixed pixel
      sizes and have overlapped/overflowed at the extremes (see error report
      `20260606-162309-C-memorylake-responsive-minmax`). Capture both via the
      non-intrusive PrintWindow harness (own instance, by PID).
- [ ] If you changed the service, it starts, writes at least one record to
      `usage_records.jsonl`, and exits cleanly on Ctrl+C.
- [ ] If runtime assertions or QML warnings fire, record them via
      `../tools/record_error.py --level L2`.

## 6. Licensing

- [ ] No new third-party dep without updating
      [`../rules/06-licensing.md`](../rules/06-licensing.md) **and** the main
      `README.md` *Third-Party Components* section.
- [ ] New source files that stand on their own carry the SPDX + copyright
      header described in `rules/06-licensing.md` §6.

## 7. Harness hygiene

- [ ] New errors this session are in `journal/errors/` and in
      `journal/errors.jsonl`.
- [ ] Session log in `journal/sessions/` is updated with outcome (done /
      partial / rolled back).
- [ ] If the harness itself needed patching to fit your change, the patch is
      part of this commit (and `CHARTER.md` is updated if the amendment is
      to a frozen file).

## 8. Commit message

- [ ] Imperative mood, English, matches the existing commit style (see
      `git log --oneline`). Examples: `Update audio tracker silence grace`,
      `Fix JSONL escaping for CR`.
- [ ] First line ≤ 72 chars. Body wraps at 72 when present.
- [ ] References the relevant rule(s) if the change is subtle.

When every box is checked, commit.
