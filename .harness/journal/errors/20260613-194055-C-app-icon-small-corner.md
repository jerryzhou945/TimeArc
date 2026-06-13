# Error Report - app-icon-small-corner

## Metadata

- Level: **L2**
- Track: **C**
- Topic: app-icon-small-corner
- Recorded: 2026-06-13T19:40:55Z
- Session: `.harness/journal/sessions/20260614-0339-C-app-icon-small-corner.md`
- Platform: windows
- Tooling: Codex bundled Python for harness tools; PowerShell source check because CMake is missing on PATH

## 1. What happened

Native software icon renders as a tiny pixel/detail in the top-right instead of centered at normal size.

## 2. Evidence

```
User report: native software icon was changed into a tiny top-right pixel/detail and should return to the normal centered style.

Recent related commits:
- cc3bd92 fix(E5): center native app icon content
- 29194d4 fix(UI): center high-DPI native app icons

RED source regression check before fix:
RED: provider still contains normalizePixmap crop path
```

## 3. Root cause

- Immediate cause: `AppIconImageProvider` cropped native icon transparent bounds via `normalizePixmap()` before returning the pixmap to QML.
- Underlying cause: provider-side pixel-bound normalization treated native Windows/high-DPI icon internals as content geometry, so the QML centered slot no longer received the normal app icon pixmap.
- Why the harness/checklists did not prevent it: no automated visual or provider-level regression test exists for `image://appicon/<exe path>`, and the prior change was also mislabeled under E5.

## 4. Fix

- Files changed: `src/services/app_icon_image_provider.cpp`, `src/services/app_icon_image_provider.h`, `docs/implementation-backlog.md`.
- Short description: removed provider-side transparent-bound crop/normalize path, restored direct `QIcon::pixmap(side, side)` output, and moved classifier long-tail backlog from E5 to G4.
- Commit: pending commit.

## 5. Prevention

Add a future visual/provider smoke for native app icons once Qt/CMake test execution is available on the machine; for this session, a source-level red/green check guards removal of the crop path.
