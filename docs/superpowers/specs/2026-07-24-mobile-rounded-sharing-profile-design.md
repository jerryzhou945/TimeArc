# Mobile Rounded Sharing and Personal Archive Design

## Goal

Make rounded share previews genuinely rounded at the pixel level, present the
monthly keepsake in the same neutral share-sheet language as an app keepsake,
and add a local personal time archive to the Profile tab.

## True rounded rendering

`clip: true` only clips QML children to a rectangular item boundary. A new
`MobileRoundedFrame` composites its children into a layer and applies a
`QtQuick.Effects.MultiEffect` mask sourced from an antialiased rounded
rectangle. The same component masks:

- the app keepsake poster;
- the monthly keepsake poster;
- the profile avatar.

The frame owns its border so artwork and the hairline share one edge without
leaking square pixels into the corners.

## Monthly share sheet

The sixth monthly-story page becomes a bottom sheet matching the app-sharing
flow. It has a 22 px rounded surface, a short “分享预览” header, neutral space
around the 9:16 keepsake, and the existing unified share bar. The seasonal
story remains visible only behind the rounded top of the sheet.

Export continues to capture the 9:16 keepsake item at 1080 × 1920. The sheet
itself is not included in the exported file.

## Personal time archive

The Profile tab gains a leading archive panel with:

- an 80 px circular avatar;
- a local-image picker opened by tapping the avatar;
- a TimeArc “T” fallback when no image exists;
- “开始记录” from `firstDateLocal`;
- “已陪伴” as the inclusive calendar span from the first record to today;
- “实际记录” from `activeDays`.

No nickname, following count, token count, or invented social data is added.
Preview mode uses the same sample archive values already shown on Home.

## Avatar persistence

`MobileUiService` exposes `avatarUrl`, `importAvatar()`, and `clearAvatar()`.
An accepted PNG/JPEG/WebP is copied into the existing private mobile-media
directory with a versioned `avatar-*` filename. The settings repository stores
only the resulting local path. Replacing or clearing an avatar removes the
previous file after the image provider has released it.

The avatar never enters a share image automatically and is not uploaded.

## Accessibility and errors

- Avatar and sharing controls keep 44 px or larger touch targets.
- The profile facts use primary and secondary theme colors in both modes.
- Failed avatar imports surface `MobileUiService.lastError`.
- Empty history shows “尚未开始” and zero-day values without fabricated dates.

## Verification

- Static checks cover the mask component, both keepsake consumers, profile
  facts, and avatar service contract.
- A build validates `QtQuick.Effects` and QML signal bindings.
- Mobile preview checks the Profile panel and both share surfaces.

