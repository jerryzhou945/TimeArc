# TimeArc Android Launcher Icon and Launch Experience Design

Date: 2026-08-02

Track: B — Feature

Status: Approved

## 1. Goal

Give the Android build a recognizable TimeArc launcher identity and a calm,
non-blocking launch transition. The result must preserve the existing TimeArc
mark, work with Android launcher masks, avoid a blank native startup window,
and remain consistent with the mobile “Pocket Time Album” design system.

## 2. Visual direction

The icon keeps the existing dark TimeArc `T` glyph and cyan-to-violet brand
field. Its mobile treatment adds restrained enamel depth, a soft top highlight,
and clearer edge separation without text, neon, glass clutter, or a copied iOS
shape. The foreground stays inside Android's adaptive-icon safe zone so circle,
squircle, rounded-square, and vendor masks preserve the complete mark.

The system splash uses the same mark over the mobile dark canvas. Once QML is
ready, a short in-app transition reveals the shell: the mark settles while one
time arc rotates and the surface fades away. Motion lasts under 1.2 seconds,
does not delay an already constructed shell, cannot loop indefinitely, and is
disabled when the mobile reduced-motion preference is active.

## 3. Android packaging

Add Android-native resources under `android/res/`:

- adaptive foreground and background resources for API 26+;
- round and standard launcher declarations;
- legacy density PNGs for older launchers;
- a base application theme and a dependency-free API 31+ splash theme;
- explicit `android:icon`, `android:roundIcon`, and activity theme references.

No third-party runtime dependency is introduced. The existing Qt Android
package source directory remains the build boundary.

## 4. QML launch transition

Add `MobileLaunchOverlay.qml` as a mobile-only shell layer. It consumes
`MobileTheme`, uses the existing embedded TimeArc brand asset, blocks accidental
touches only while visible, then destroys its visual presence after the reveal.
`MobileAppShell` starts it after loading the saved theme preference so dark/light
and reduced-motion behavior are correct on the first frame.

The overlay is presentation only. It does not represent data synchronization,
usage permission, database readiness, or service state. Those flows retain
their existing behavior and are never mislabeled as loading.

## 5. Accessibility and failure behavior

- Reduced motion skips rotation and transitions directly to the app.
- The native splash background and icon remain legible in dark and light system
  launch conditions.
- The in-app overlay has a bounded lifetime and cannot trap the user.
- Missing generated raster assets fail static verification and packaging rather
  than silently falling back to the Qt default icon.
- Android usage collection and the two-process desktop contract are unchanged.

## 6. Verification

Test-driven static checks cover manifest references, resource existence,
adaptive-icon safe structure, QML registration, bounded animation, and reduced
motion. Final verification includes the project harness build, CTest/Python
tests, Android package assembly, APK integrity/badging inspection, and a manual
launch smoke when an emulator or device is available.

## 7. Rollback

Rollback removes the Android resource/theme overrides and the mobile overlay.
No database, settings, or usage-record migration is involved.
