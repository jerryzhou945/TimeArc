# Mobile Report Release and APK

## Scope

Fix local-avatar refresh, publish completed reports on a deterministic schedule,
add an unread report indicator, remove simulated status chrome, integrate via
PR, and package an Android APK.

## Service side

`MobileUsageService` emits a local-time release status containing the latest
released month, latest annual key, and a stable combined token. Memory Lake
queries exact dates for the released month. The service database and sampling
contract remain unchanged.

## UI side

Profile explicitly refreshes the rounded avatar layer after
`MobileUiService.avatarChanged`. The shell compares the release token with a
SettingsRepository seen token and drives a red Memory Lake badge. The existing
status-bar placeholder becomes zero-height and renders no fake phone state.

## Rules

- `01-architecture.md`: unchanged; release aggregation stays in the UI service.
- `04-ui-conventions.md`: unchanged; QML persists only seen state through the
  repository.
- `05-build-system.md`: unchanged unless Android packaging discovers a required
  kit-only configuration.
- No frozen file or data-contract change is planned.

## Manual smoke

Import an avatar and see it update immediately. Launch on 2026-07-24 and see
June as the latest report. Open Memory Lake and see its red dot clear. Confirm
the fake 9:41 and battery glyph are absent.

