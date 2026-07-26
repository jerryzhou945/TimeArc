# Change Proposal — macos-bundle-icon

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-07-25 21:04 (local)
- Session goal: Bundle `resources/bundle/macos/TimeArc.icns` as the native macOS application icon.
- Branch: development/macos-support
- Related error reports: [`../errors/20260725-130504-B-cmake-icon-property-probe.md`](../errors/20260725-130504-B-cmake-icon-property-probe.md)

## 1. Frozen files touched

- `CMakeLists.txt` — add the `.icns` file to the macOS app bundle resources and set `CFBundleIconFile`.

## 2. Motivation

The macOS bundle currently emits an empty `CFBundleIconFile`, so Finder, Dock,
and bundle metadata cannot use the supplied native icon.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | None; `time-arc-service` sources, executable, and disk contract are unchanged. |
| Consumer | The UI executable is unchanged; its outer macOS application bundle gains a native icon resource and plist reference. |

Service side: the background service neither consumes nor ships the icon.

UI side: CMake copies `TimeArc.icns` into `TimeArc.app/Contents/Resources` and
sets the bundle icon filename; the in-app qrc SVG remains unchanged.

## 4. Migration plan

No on-disk impact.

## 5. Rollback plan

Revert the CMake lines; no data restoration is required.

## 6. Test plan

- Pre-change reproduction: `CFBundleIconFile` is empty and the `.icns` file is absent from the built bundle.
- Post-change verification: rebuild, inspect `Info.plist`, confirm the bundled file, run CTest and harness audit.
- New test artifacts: none.

## 7. Sign-off

- [x] No rule text changes are required; existing build/resource rules remain true.
- [ ] `CHARTER.md` version bumped (not applicable; no invariant changes).
- [x] `state/frozen-files.json` regenerated for the approved frozen-file edit.
- [x] README update is not required; this changes native bundle presentation only.

## Outcome

Done. `TimeArc.icns` is copied byte-for-byte to
`TimeArc.app/Contents/Resources`, `CFBundleIconFile` is `TimeArc.icns`, and
the harness build plus CTest pass.
