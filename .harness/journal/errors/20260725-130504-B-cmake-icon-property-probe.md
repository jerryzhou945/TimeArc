# Error Report - cmake-icon-property-probe

## Metadata

- Level: **L3**
- Track: **B**
- Topic: cmake-icon-property-probe
- Recorded: 2026-07-25T13:05:04Z
- Session: `20260725-2104-B-macos-bundle-icon.md`
- Platform: macOS
- Tooling: CMake 4.2 help

## 1. What happened

Queried MACOSX_BUNDLE_ICON_FILE as a CMake property, but this CMake exposes it through bundle template variables rather than the property help index

## 2. Evidence

`cmake --help-property MACOSX_BUNDLE_ICON_FILE` reported that no indexed
property exists; the installed plist template exposes it as a substitution.

## 3. Root cause

- Immediate cause: I assumed the plist substitution name was an indexed property.
- Underlying cause: CMake bundle templates accept directory variables not listed by property help.
- Why the harness/checklists did not prevent it: This was a harmless documentation probe.

## 4. Fix

- Files changed: none for the probe.
- Short description: Confirmed the installed CMake/Qt templates and used the standard pre-target variable.
- Commit: pending

## 5. Prevention

One-off; no harness change needed.

## 6. Lessons for agents (L3)

- Wrong assumption: Every bundle plist substitution has a corresponding CMake property help entry.
- Earlier signal available: The installed `MacOSXBundleInfo.plist.in` template.
- Rule file to update: none.
