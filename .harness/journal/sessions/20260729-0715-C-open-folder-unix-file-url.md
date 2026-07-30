# Session Log — open-folder-unix-file-url

## Metadata

- Agent / Author: Claude Code (Opus 5)
- Track: **C (Debug)** — user-reported defect, minimum necessary change.
- Date: 2026-07-29 07:15 → 07:30 (local)
- Branch: `development/macos-support`
- Baseline commit: `d2e1af7` (macOS bundle ID)
- Predecessor: `20260729-0435-C-i18n-confirm-dialog.md`
- Related error report(s):
  [`20260729-072353-C-open-folder-unix-file-url.md`](../errors/20260729-072353-C-open-folder-unix-file-url.md)

## Goal

Make the "Open Folder" button in the settings save-confirmation actually open
the file manager on macOS and Linux, not only on Windows.

## Plan

- Reproduce with the exact URL the button builds.
- Fix `_folderUrlOf` to derive the prefix from the path shape.
- Pin it with a static test covering both platform shapes.

## What actually happened

- 07:15 — Read `_folderUrlOf` and found `"file:///" + dir`, correct only for a
  Windows drive path. Two other sites in the tree (`MacMenuBar.qml:354`,
  `MobileAppIcon.qml:26`) already had the cross-platform idiom, which made the
  diagnosis unambiguous. `DesktopCalenderPage.qml:256` looks similar but is
  guarded by a drive-letter regex and is correct.
- 07:18 — Confirmed against the real call rather than by reading: the built
  URL returns `false` from `Qt.openUrlExternally`, the fixed one `true`.
  Full evidence in the error report §2.
- 07:20 — While fixing, found two more defects in the same four lines: no
  `encodeURI` (the default service directory contains a space), and `i > 0`
  handing back a root-level file as its own parent. Both fixed in place; both
  are the same "written for Windows path shape" root cause, so this stayed
  inside track C rather than becoming a separate cleanup.
- 07:22 — Also stopped discarding the `openUrlExternally` return value. That
  discard is why the bug presented as nothing happening at all, with no log
  line to go on.
- 07:23 — Build clean. Both static tests pass.

## Outcome

**done**

- Commits landed: none yet (uncommitted, together with the i18n session).
- Files touched: `qml/desktop/pages/DesktopProfilePage.qml`,
  `qml/desktop/components/I18n.js`, `tests/file_url_static_test.py` (new).
- Frozen files touched: **n**.
- Follow-ups: none new. The follow-ups listed in the predecessor session
  (partial `ja` coverage, untranslated C++ error text in toasts, duplicate
  `en` keys) still stand.

## Test plan

`tests/file_url_static_test.py` (new) passes: rejects a bare `"file:///" + …`
return, requires the conditional prefix, `encodeURI`, the root-level-file
branch and the checked return value, and pins the two already-correct sites.
`tests/i18n_settings_dialog_static_test.py` still passes.

Runtime evidence came from Qt's `qml` runtime over a verbatim copy of the new
function body — seven path shapes, all correct:

```
macOS               /Users/…/Downloads/x.db  -> file:///Users/…/Downloads
macOS w/ space      …/Application Support/…  -> file:///…/Application%20Support/…
macOS non-ASCII     /Users/…/文稿/x.json      -> file:///Users/…/%E6%96%87%E7%A8%BF
Linux               /home/jz/backups/x.db    -> file:///home/jz/backups
Unix root-level     /timearc.db              -> file:///
Windows drive       C:/Users/…/Downloads/…   -> file:///C:/Users/…/Downloads
Windows backslashes C:\Users\…\My Files\…    -> file:///C:/Users/…/My%20Files
```

Not verified: the button clicked inside the running app, for the reason in the
predecessor session (Accessibility unauthorized). The Windows and Linux rows
above are reasoned from the function output, not from those platforms.

## Notes for the next agent

Platform-specific logic is not confined to `src/service/`. This one lived in
shared desktop QML as a slash count, where nothing marks it as platform
-dependent. When touching anything that builds a `file:` URL, path, or
separator in QML, check the path shape rather than assuming a leading slash is
or is not present — and prefer `encodeURI`, since real user directories on
macOS contain spaces by default.
