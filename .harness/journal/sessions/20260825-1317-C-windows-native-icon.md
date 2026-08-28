# Change Proposal — windows-native-icon

## Metadata

- Author: Codex `/root`
- Track: **C (Debug)** — this corrects the confirmed generic-icon defect without adding product behavior.
- Date: 2026-08-25 13:17 (Asia/Shanghai)
- Session goal: Embed a native multi-resolution Windows icon in `TimeArc.exe` and integrate the verified fix into `dev`.
- Branch: `codex/windows-release-icons`
- Related error reports: `.harness/journal/errors/20260825-051533-C-windows-exe-icon-missing.md`

## 1. Frozen files touched

- `CMakeLists.txt` — append the Windows RC source to the GUI target only when `WIN32`.

## 2. Motivation

The installed executable has no PE `.rsrc` section, so Windows Explorer, shortcuts, and the taskbar fall back to a generic executable icon. Qt's runtime SVG window icon does not replace the native executable resource used by the Windows shell.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | None; the background service and its build inputs are unchanged. |
| Consumer | The GUI executable gains a native icon resource; runtime behavior and disk reads are unchanged. |

## 4. Migration plan

No on-disk impact. Existing data and settings remain valid; future builds simply contain the icon resource.

## 5. Rollback plan

Revert the icon-fix commit. No data restoration is necessary.

## 6. Test plan

- Pre-change reproduction: `objdump -h TimeArc.exe` has no `.rsrc`, and Windows displays a generic icon.
- Post-change verification: static wiring test passes; wrapped build passes; `objdump` reports `.rsrc` plus icon/group-icon resources.
- New test artifacts: `tests/windows_executable_icon_static_test.py`.

## 7. Sign-off and progress

- [x] Add RED regression test.
- [x] Add ICO/RC and conditional CMake wiring.
- [x] Build and inspect the executable resource table.
- [x] Update report/backlog/open issues.
- [-] Run final harness/diff gate, commit, PR to `dev`, merge, and clean branch.
- [ ] `rules/*.md` updated: not required; Rule 05 already defines source wiring.
- [ ] `CHARTER.md` version bumped: not required; no invariant changes.
- [x] `state/frozen-files.json` regenerated after the frozen-file edit.
- [ ] Main `README.md` updated: not required; no user workflow changes.

Completed: RED/green PE resource test, seven-size ICO generation, Windows RC wiring, wrapped build, artifact inspection, full focused verification matrix, and human-facing documentation.

Incomplete: Final harness/diff gate, commit, PR/merge, and branch cleanup.

Verification: Wrapped build passed; 6/6 CTest passed; PE icon test, installer configuration test, executable SFX smoke, dynamic Qt linkage, desktop UX, and stats layout checks passed; `objdump` shows `.rsrc`; ICO contains seven requested sizes.

Next: Run final harness/diff gate, then integrate into `dev` and clean the feature branch.

Risks: Windows icon caching can delay visual refresh on an already pinned shortcut; the executable resource test avoids treating cache state as build correctness.
