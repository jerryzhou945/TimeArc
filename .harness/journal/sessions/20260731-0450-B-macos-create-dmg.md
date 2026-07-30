# Session Log — 20260731-0450-B-macos-create-dmg

## Metadata

- Agent / Author: Claude Code (Opus 5)
- Track: **B (Feature)**
- Date: 2026-07-31 04:50 → (open)
- Branch: `development/macos-support`
- Baseline commit: `00c2a7a`

## Goal

Produce a styled macOS DMG via `create-dmg` when that tool is on PATH, with the
current `hdiutil` output preserved unchanged when it is not.

## Two-sided design

N/A for this session. The diff touches packaging tooling only
(`tools/build-macos.sh`); it crosses neither the UI/service seam nor the disk
contract, and no rule file claims anything about DMG layout.

## Plan

- Split the DMG step in `package_release` into `create_dmg_package` and
  `hdiutil_package`; keep signing / `hdiutil verify` / notarization shared.
- Select the tool in `select_dmg_tool`, overridable via `TIMEARC_DMG_TOOL`.
  Guard against `sindresorhus/create-dmg`, which shares the binary name but
  takes an unrelated CLI, by probing `--help` for `--app-drop-link`.
- Move the `/Applications` symlink into the `hdiutil` path only —
  `create-dmg` makes its own drop link via `--app-drop-link`.
- Normalize the background image to the Finder window size before use.

## What actually happened

- 04:50 — preflight `--track B` clean.
- 04:52 — confirmed `/opt/homebrew/bin/create-dmg` is `create-dmg/create-dmg`
  1.3.0: supports `--app-drop-link`, `--volicon`, `--overwrite`.
- 04:53 — found `resources/bundle/macos/dmg_background.png` is 1643x957, not
  the specified 720x420. `create-dmg` copies the background verbatim (line 532
  of the tool); Finder does not scale it, so a 720x420 window would show only
  the image's top-left corner. Added a `sips` normalization step that resizes
  to the window size when the dimensions disagree.

- 04:55 — first styled build failed: Finder `-10006`, see
  [`../errors/20260730-205724-B-create-dmg-dotfile-background.md`](../errors/20260730-205724-B-create-dmg-dotfile-background.md).
  Restaged the background into a hidden directory under a visible filename.
- 04:56 — rebuilt; DMG produced, layout verified on the mounted volume.
- 04:57 — diff review caught `note()` writing to the stdout that
  `select_dmg_tool` uses for its return value, see
  [`../errors/20260730-205733-B-create-dmg-note-stdout-capture.md`](../errors/20260730-205733-B-create-dmg-note-stdout-capture.md).

## Verification

Ran against a dummy `TimeArc.app` in the scratchpad, not a full build:

- `create-dmg` path: mounted the result and read it back through Finder —
  volume `TimeArc`, `.VolumeIcon.icns` present,
  `.background/dmg-background.png` present, icon size 112, text size 14,
  `TimeArc.app` at (180, 200), `Applications` drop link at (540, 200).
  No leftover `rw.*.dmg` or staging directory in `dist`.
- `hdiutil` path: unchanged output, `/Applications` symlink still made by us.
- `select_dmg_tool`: auto/present, auto/absent, forced hdiutil, forced
  create-dmg while absent (dies), bogus value (dies) — all as intended.

Not covered: a full `--package` run, and the Finder window bounds
(200,120 720x420), which a read-only mount reports as 0,0,0,0 because no
Finder window is open.

## Outcome

**done** (pending a full `--package` run on a real build).

- Commits landed: (uncommitted)
- Files touched: `tools/build-macos.sh`
- Frozen files touched: n

## Notes for the next agent

`create-dmg` drives Finder through AppleScript, so it needs a GUI session and
Automation permission for the calling terminal. Set `TIMEARC_DMG_TOOL=hdiutil`
on headless CI (or add `--skip-jenkins` if the styled path is still wanted
there). Exporting the background asset at exactly 720x420 removes the runtime
`sips` resize.
