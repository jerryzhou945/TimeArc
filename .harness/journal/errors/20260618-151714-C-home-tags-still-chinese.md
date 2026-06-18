# Error Report - home-tags-still-chinese

## Metadata

- Level: **L2**
- Track: **C**
- Topic: home-tags-still-chinese
- Recorded: 2026-06-18T15:17:14Z
- Session: `.harness/journal/sessions/20260618-2316-C-home-tags-platform-doc.md`
- Platform: Windows
- Tooling: local QML review, structural PowerShell checks, Node i18n check

## 1. What happened

Home page tag/category labels such as Social and Development could still appear
as raw Chinese labels in English mode.

## 2. Evidence

```text
DesktopHomePage.qml:
ComboBox {
    model: fixedTags
}

onClicked:
    projectManager.addProject(nameText, tagBox.currentText)
    selectedTag = tagBox.currentText
```

## 3. Root cause

- Immediate cause: the Home add-project ComboBox displayed the raw `fixedTags`
  array instead of a translated label model.
- Underlying cause: tag values are stored as canonical Chinese labels, while the
  UI needs localized display labels. The ComboBox path was not separated into
  display text and saved value.
- Why the harness/checklists did not prevent it: previous checks covered common
  Home display paths, but did not include the add-project ComboBox.

## 4. Fix

- Files changed: `qml/desktop/pages/DesktopHomePage.qml`
- Short description: add translated `{ value, text }` tag options and save the
  canonical tag value instead of translated display text.
- Commit: pending

## 5. Prevention

One-off, no harness change. The structural check from this session can be reused
when touching Home tag editing again.
