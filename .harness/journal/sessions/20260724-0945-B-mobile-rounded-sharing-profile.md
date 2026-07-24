# Mobile Rounded Sharing and Profile

## Scope

Introduce true rounded masking for mobile share artwork and a locally
persistent personal time archive in the Profile tab.

## Service side

`MobileUiService` accepts a user-selected avatar URI, copies it into the
application-private media directory, stores the resulting path through
`SettingsRepository`, and exposes a versioned local URL to QML. It emits one
change signal on import or clear. No usage records or service-database schema
change.

## UI side

QML consumes the avatar URL and the existing all-time dashboard. A reusable
`MultiEffect` mask renders app posters, monthly posters, and the avatar with
true antialiased rounded edges. Profile facts derive from `firstDateLocal` and
`activeDays`; the monthly share page uses the same neutral sheet hierarchy as
the app share preview.

## Rules

- `01-architecture.md`: no change; persistence remains in a UI QObject.
- `04-ui-conventions.md`: no change; QML does no blocking file I/O.
- `05-build-system.md`: no change; one new QML file is registered normally.
- No frozen files or data-contract files change.

## Manual smoke

Launch with `--mobile-preview`, open “我的”, tap the circular avatar and select
an image, then verify the image persists after reopening. Open an app share
preview and the June monthly report share page; confirm no square artwork
pixels appear outside either rounded poster.

