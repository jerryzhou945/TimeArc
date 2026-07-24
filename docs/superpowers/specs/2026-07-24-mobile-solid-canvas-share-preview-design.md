# Mobile Solid Canvas and Share Preview Design

## Goal

Make TimeArc feel intentional when no custom wallpaper is configured, balance
the monthly-report entry, and make both monthly and app share previews visibly
rounded and truly representative of the exported image.

## Default canvas

The default remains a code-rendered background rather than a bundled wallpaper.
Dark mode uses a quiet blue-gray to lake-green atmospheric gradient; light mode
uses mist white to pale lake gray. The gradient has no obvious geometric shapes,
keeps contrast restrained, and extends beneath all four tabs.

Transparent panels remain tonal and readable over this canvas. When no wallpaper
is configured, a small “添加自定义壁纸” action appears in the Home header. It
invokes the existing local wallpaper picker and disappears as soon as a
wallpaper becomes active. Failure feedback uses the existing mobile UI service
error state.

## Monthly report entry

The Memory Lake entry keeps its month-specific illustration and an 18 px outer
radius. A single glass treatment replaces the visually nested frame. The title
and summary occupy the upper content area. A bottom footer aligns a quiet month
descriptor on the left and a 44 px “打开完整月报” action on the right.

## Monthly share preview

The last monthly-story page contains an explicit 9:16 keepsake preview with a
22 px radius, a subtle inner hairline, seasonal artwork, the report statement,
and factual summary data. The share action captures this preview item—not the
entire story page—at 1080 × 1920.

## App-card share preview

The app keepsake preview uses the same 22 px poster radius and a visible inner
hairline. The sheet provides enough surrounding neutral space for the corners to
read clearly. Export still captures only the poster, preserving transparent
rounded corners.

## Constraints

- Do not add bundled wallpaper or illustration assets.
- Keep current data models, privacy filtering, gallery save, and social-channel
  handoff unchanged.
- Keep text and controls WCAG AA-readable in dark and light modes.
- Respect reduced-motion settings and existing 44 px touch targets.

## Verification

- Static UI checks assert the default atmospheric canvas, wallpaper prompt,
  balanced report footer, explicit monthly preview capture, and shared poster
  radius.
- Build through the project harness.
- Launch the Mobile preview and scan Qt logs after the preview exits.

