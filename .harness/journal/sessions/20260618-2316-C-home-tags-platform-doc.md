# Session 20260618-2316 C home-tags-platform-doc

## Track

C Debug

## Goal

Fix the remaining English-mode Home tag leak, do a small packaging-prep pass,
and document Windows/macOS parity before packaging.

## Context

- User reported Home tags such as Social/Development still showing as Chinese
  in English mode.
- User asked for a pre-packaging review and a doc comparing macOS and Windows
  gaps and estimated catch-up speed.

## Changes

- `qml/desktop/pages/DesktopHomePage.qml`
  - Display Home add-project tag options through translated labels.
  - Preserve the original Chinese tag value when saving through
    `projectManager.addProject`.
- `src/service/README.md`
  - Correct stale service directory names from `win/` and `mac/` to
    `windows/` and `macos/`.
- `docs/platform-parity-packaging-gap.md`
  - Document current Windows/macOS UI, service, lifecycle, permissions, and
    packaging gaps.
  - Add practical catch-up estimates for one- and two-engineer paths.

## Related Error Reports

- `.harness/journal/errors/20260618-151714-C-home-tags-still-chinese.md`
- `.harness/journal/errors/20260618-151840-C-home-tag-combobox-red-test.md`
- `.harness/journal/errors/20260618-151714-C-sandbox-doc-search-createprocess.md`

## Verification

- Home tag ComboBox structural check passed.
- Node i18n label check for Home tag labels passed.
- `python .harness/tools/build.py` passed.
- `build/timearc_db_smoke.exe` passed.
- `git diff --check` passed with line-ending warnings only.
- `python .harness/tools/harness_check.py` passed.
