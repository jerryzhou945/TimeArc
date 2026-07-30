# Session Log — i18n-confirm-dialog

## Metadata

- Agent / Author: Claude Code (Opus 5)
- Track: **C (Debug)** — observed defect, minimum necessary change.
- Date: 2026-07-29 04:35 → 07:10 (local)
- Branch: `development/macos-support`
- Baseline commit: `d2e1af7` (macOS bundle ID)
- Related error report(s):
  [`20260729-070603-C-i18n-confirm-dialog.md`](../errors/20260729-070603-C-i18n-confirm-dialog.md)

## Goal

Make the settings confirm card, the database backup card and the service
database location card read fully in the selected language (zh / en / ja).

## Plan

- Find why the buttons translate but the title and body do not.
- Fix the render site, then fill the dictionary holes it exposes.
- Convert runtime-built bodies to `sentence()` templates.
- Pin all three with a static test.

## What actually happened

- 04:35 — Traced the split dialog to three separate holes, not one: no `tr()`
  on the card's title/message, no `en`/`ja` entries for its strings, and
  bodies concatenated at runtime so they could never be dictionary keys.
  Full write-up in the error report §3.
- 04:38 — Preflight reported pre-existing frozen-file drift on `CMakeLists.txt`
  (see "Notes"). Unrelated to this diff; recorded, not fixed here.
- 04:40 — Found a fourth, latent hole while adding entries: the confirm label
  `"设置"` collides with the navigation entry of the same name, so it would
  have rendered "Settings" instead of "Set". Changed the source string to
  `"设置此目录"` rather than adding a second meaning to a shared key. This is
  the one zh-visible text change in the diff.
- 04:41 — Build clean; both changed files recompiled into the QML cache.
- 04:42–05:00 — Attempted runtime verification in the running app. The window
  never appeared on the capturable Space across three launch paths (direct
  binary, scratch `HOME`, `open -n`); driving or switching Spaces needs
  Accessibility, unauthorized here — same constraint as
  `20260729-0325-B-macos-menu-bar-design.md`. `scan_qt_log.py` recorded one L2,
  the pre-existing unsigned-build LaunchAgent warning
  (`qt-warning-19f33ebed5`); no QML warnings from this diff.
- 07:05 — Verified instead by loading the shipped `I18n.js` into Qt's own
  `qml` runtime and printing every affected string in zh/en/ja (§ Test plan).

## Outcome

**done** (code); runtime rendering unverified — see Notes.

- Commits landed: none yet (uncommitted).
- Files touched: `qml/desktop/pages/DesktopProfilePage.qml`,
  `qml/desktop/components/I18n.js`,
  `tests/i18n_settings_dialog_static_test.py` (new).
- Frozen files touched: **n**.
- Follow-ups: `ja` is ~183 entries against `en`'s 521, so most of the app reads
  as English in Japanese via the ja → en fallback; the toast path still
  concatenates untranslated C++ error text (`"无效备份：" + info.error`,
  `"迁移失败：" + res.error`); `en` carries duplicate keys (e.g. `恢复数据库`
  at two places) — all track-A, none filed as issues yet.

## Test plan

`tests/i18n_settings_dialog_static_test.py` (new) passes: 18 confirm-dialog
literals, 23 导入导出 card strings and 6 file-dialog strings all resolve in
both `en` and `ja`; render sites call `tr()`; the three dynamic bodies route
through `sentence()` with templates in both tables; no confirm label reuses
`"设置"`.

Runtime evidence came from a `qml`-runtime probe over the real
`qml/desktop/components/I18n.js`, not from looking at the app. All three
languages resolve end to end, including `t(lang, sentence(...))` on a
pre-composed body being the intended no-op:

```
en  Database Backed Up / Saved to:\n<path> / [Cancel] [Open Folder]
    Service Database Folder · Set Folder… · Set Service Database Folder [Set This Folder]
ja  データベースをバックアップしました / 保存先:\n<path> / [キャンセル] [フォルダを開く]
    サービスデータベースのフォルダ · フォルダを設定… · [このフォルダに設定]
zh  unchanged except the confirm label 设置 → 设置此目录
```

Not verified: on-screen layout of the longer en/ja strings inside the card and
inside `GhostBtn` (which elides past 190px) — needs a human pass.

## Notes for the next agent

Preflight fails pass 2 on `CMakeLists.txt`: the hash in
`.harness/state/frozen-files.json` predates `d2e1af7`, which added
`MACOSX_BUNDLE_GUI_IDENTIFIER`. The drift is already committed and is not from
this session, so it was left alone — it needs either a change proposal or a
`harness_check.py --bootstrap` re-seed, and until then every preflight in this
branch reports the same finding.

The dictionary is keyed by Chinese source text, so short generic labels are
shared vocabulary, not local strings. Before reusing a one- or two-character
label in a new dialog, check whether the word already has a meaning somewhere
else in `I18n.js` — `"设置"` in this session is the cautionary case.
