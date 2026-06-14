# Change Proposal - site-icon-qrc

## Metadata

- Author: Codex
- Track: **B (Feature)**
- Date: 2026-06-14 11:38 (local)
- Session goal: Add newly refreshed local site icon assets to the Qt resource bundle.
- Branch: codex/app-list-icons-highres
- Related error reports: none

## 1. Frozen files touched

- `resources/CMakeLists.txt` - update the Qt resource file list so newly
  refreshed website icons are available through qrc URLs.

## 2. Motivation

The UI can only display local website icons when they are included in the Qt
resource bundle. New or upgraded assets for Xiaohongshu, iQIYI, AcFun, Netflix,
and several previously blank mainstream sites would otherwise resolve to missing
qrc paths.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | None; the background service writes the same app/session records. |
| Consumer | The UI can load the added local icon resources from qrc. |

## 4. Migration plan

No on-disk impact. Existing records keep the same identifiers and are rendered
with refreshed icons at read time.

## 5. Rollback plan

A code/resource-list revert is sufficient. No data restore is required.

## 6. Test plan

- Pre-change reproduction: qrc paths for the new assets are not in the resource
  bundle.
- Post-change verification: build succeeds and `timearc_db_smoke` passes with
  updated catalog icon suffix expectations.
- New test artifacts: updated smoke icon assertions.

## 7. Sign-off

- [ ] `rules/*.md` updated to reflect new reality (not needed).
- [ ] `CHARTER.md` version bumped (not a charter amendment).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible (not needed for asset refresh).
