# Error Report - macos-menu-bar-startup-language-fallback

## Metadata

- Level: **L2**
- Track: **B**
- Topic: macos-menu-bar-startup-language-fallback
- Recorded: 2026-07-29T14:28:09Z
- Session: `../sessions/20260729-0325-B-macos-menu-bar-design.md`
- Platform: macOS
- Tooling: QML console probe + lldb dump of the live NSMenu tree

## 1. What happened

MacMenuBar's lang fallback hardcoded zh, so every launch titled the menus in Chinese until shellLoader.item appeared. On a non-Chinese UI that window was long enough for AppKit to adopt the briefly-Chinese Edit menu, fill it with Chinese rows and keep that title, while View/Help matched nothing and got none of theirs.

## 2. Evidence

User report: in an English UI, 编辑 showed its three OS rows in Chinese while
显示 and 帮助 showed none. Probe at menu-bar creation, with the stored language
already `en`:

```
qml: PROBE lang -> zh
qml: PROBE MacMenuBar created: lang= zh  hasShell= false  db= en
qml: PROBE lang -> en
```

Live menu bar in that state — only the Edit menu is Chinese:

```
Apple, File, QtWindowMenu, 编辑, View, Window, Help
编辑 = Undo … Select All, 自动填充, 开始听写…, 表情与符号
```

After the fix, the same launch reports `lang= en  hasShell= false` and the QML
side never emits a Chinese title.

## 3. Root cause

- Immediate cause: `readonly property string lang: hasShell ? hostShell.languageMode : "zh"`.
  The menu bar is constructed before `shellLoader.item` exists, so that literal
  fallback ran on every launch regardless of the stored language.
- Underlying cause: a fallback invented for "no shell yet" was given a made-up
  value instead of the same source the shell itself reads
  (`settingsRepository.getValue("language_mode")`).
- Why the harness/checklists did not prevent it: invisible to static checks and
  to the QML runtime — the wrong title exists for a fraction of a second, and
  only AppKit, which samples titles in that window, ever sees it.

## 4. Fix

- Files changed: `qml/desktop/MacMenuBar.qml`, `tests/macos_menu_bar_static_test.py`
- Short description: the fallback now reads `language_mode` from
  `settingsRepository`, so the first title AppKit can observe is already in the
  user's language. The static test pins the new expression and forbids the
  hardcoded one.
- Commit: not applicable (uncommitted at time of writing)

## 5. Prevention

A default that stands in for "not ready yet" must come from the same store the
real value comes from, never from a literal. Worth stating in
`rules/04-ui-conventions.md`: in QML, a fallback for an object that has not
loaded yet reads the persisted setting, it does not guess.
