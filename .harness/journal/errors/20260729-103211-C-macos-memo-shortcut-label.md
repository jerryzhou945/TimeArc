# Error Report - macos-memo-shortcut-label

## Metadata

- Level: **L2**
- Track: **C**
- Topic: macos-memo-shortcut-label
- Recorded: 2026-07-29T10:32:11Z
- Session: `journal/sessions/20260729-1832-C-macos-memo-shortcut-label.md`
- Platform: macos
- Tooling: qml

## 1. What happened

Memo Board help text displays Ctrl for shortcuts that use Command on macOS.

## 2. Evidence

```qml
"Ctrl+C 复制 / Ctrl+V 粘贴"
"可 Ctrl+Z 撤销"
```

## 3. Root cause

- Immediate cause: Two translated help sentences embed `Ctrl+` as literal text.
- Underlying cause: Qt remaps shortcut objects and modifier events on macOS, but cannot platform-localize arbitrary UI strings.
- Why the harness/checklists did not prevent it: Existing static checks cover shortcut behavior but not platform-correct shortcut guidance.

## 4. Fix

- Files changed: `qml/desktop/memorylake/MemoOverlay.qml`, `tests/macos_memo_shortcut_label_static_test.py`
- Short description: Translate the guidance first, then replace `Ctrl+` with `⌘` only on macOS.
- Commit: pending

## 5. Prevention

Add a static assertion covering the macOS-only shortcut-label substitution.
