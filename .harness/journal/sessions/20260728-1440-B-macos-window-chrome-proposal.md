# Change Proposal — macOS sidebar window chrome

## Metadata

- Author: Codex `/root`
- Track: **B (Feature)**
- Date: 2026-07-28 14:40 (Asia/Shanghai)
- Session goal: Embed native macOS window controls in the desktop sidebar without changing other platforms.
- Branch: `development/macos-support` (`.git` is read-only; feature branch creation was blocked)
- Related error reports: `errors/20260728-064004-B-feature-branch-git-readonly.md`

## 1. Frozen files touched

None. The initial native-adapter approach was superseded by a QML-only
frameless implementation before completion, so the frozen source list has no
final diff.

## 2. Motivation

The desktop currently applies the Windows-oriented frameless QML caption
buttons to macOS. That gives macOS controls in the wrong corner. The requested
design places traffic-light controls directly in a borderless sidebar while
leaving Windows and mobile unchanged.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | None; the background service and its build inputs are unchanged. |
| Consumer | The macOS GUI uses QML traffic lights inside its frameless sidebar. |

## 4. Migration plan

No on-disk impact.

## 5. Rollback plan

Revert the QML platform branch, traffic-light component, and sidebar layout.
No data restoration is required.

## 6. Test plan

- Pre-change reproduction: launch on macOS and observe Windows-style controls at the top right.
- Post-change verification: native traffic lights appear in the expanded and collapsed sidebar; close, minimize, zoom/fullscreen, drag, resize, memo overlay, and restore paths work.
- New test artifacts: focused static platform-branch checks; macOS build and runtime log scan.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality (none required; this is an isolated desktop-shell presentation change).
- [ ] `CHARTER.md` version bumped (not applicable).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [x] Main `README.md` updated if user-visible.

## Completion facts

- Completed: Proposal filed; the final design avoided all frozen-file changes.
- Incomplete: None.
- Verification: Preflight, rule review, and harness builds passed.
- Next: Final harness audit.
- Risks: None to the service or disk contract.
