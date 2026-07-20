# Track B Session — Mobile Wallpaper, Contrast, and Flip Polish

## Goal

Make the mobile QML preview reliably refresh and clear custom wallpapers,
preserve readable glass surfaces in both themes, show real app icons without
underlying abbreviations, and give the Home card a convincing 3D flip.

## Service side

The sampling process, Android UsageStats bridge, SQLite schema, and journal
contract remain unchanged. `MobileUiService` may change only its UI-private
wallpaper import lifecycle so each selected image receives a fresh URL and a
loaded image is never overwritten in place.

## UI side

`MobileAppShell` remains the single global wallpaper owner. Shared theme tokens
will provide stronger adaptive glass contrast, app-icon fallback content will
be hidden once the real image is ready, and `MobileFlipCard` will use
continuous two-sided Y-axis transforms with depth compression and shadow cues.

## Expected files

- `src/services/mobile/mobile_ui_service.cpp`
- `qml/mobile/MobileTheme.qml`
- `qml/mobile/MobileAppShell.qml`
- `qml/mobile/components/MobileAppIcon.qml`
- `qml/mobile/components/MobileFlipCard.qml`
- `tests/mobile_ui_static_test.py`

## Explicit non-scope

- Database and journal schemas
- Android usage collection
- Desktop UI
- Frozen CMake and harness policy files

## Rules

- `rules/01-architecture.md` applies to the UI-private wallpaper lifecycle.
- `rules/04-ui-conventions.md` applies to contrast and motion.
- No frozen file or rule text change is expected.
- Build only through `.harness/tools/build.py`.

## Manual smoke path

Launch `build/TimeArc.exe --mobile-preview`, import two same-extension
wallpapers in succession, restore the solid background, toggle light/dark mode
on every tab, verify real app icons have no abbreviation underneath, then flip
the Home card in both directions and scan the Qt/QML log.

## Result

- Wallpaper imports now use unique file URLs and the shell explicitly reloads
  on `wallpaperChanged`; clearing persists a non-null empty setting before the
  old file is removed.
- Light wallpaper mode uses a stronger page veil and three readable glass
  strengths; dark wallpaper mode keeps its transparent atmosphere with clearer
  secondary copy and separators.
- App abbreviations disappear as soon as a real icon is ready.
- Home card faces now move continuously around the Y axis with midpoint depth
  compression, cross-face opacity, shadow growth, and a one-way state request
  that avoids the previous binding loop. Both transforms explicitly use the
  pure `(0, 1, 0)` axis.
- Old wallpaper files are removed after the image source changes, retried once
  after Windows releases the decoder handle, and swept on the next launch if
  the retry still cannot remove them.
- The Unicode share filename sanitizer now uses valid letter/number classes.

## Verification

- Harness build: success (`20260720-123158-build.log`).
- `ctest --test-dir build --output-on-failure`: 1/1 passed.
- `tests/mobile_ui_static_test.py`: passed after a verified RED state.
- `tests/android_usage_static_test.py`: passed.
- Visible `--mobile-preview`: responsive after 8 seconds (PID 34892).
- Fresh Qt/QML scan: no log generated, so no runtime warnings were observed.
