# TimeArc Adapter System

TimeArc adapter system is a lightweight support registry for turning raw activity signals into friendly, privacy-safe metadata.

It does not try to support every website or every desktop app on day one. The first version prioritizes high-frequency websites and desktop apps, then gives contributors a small pattern for adding more support over time.

## Goals

- Identify websites by domain, hostname, or URL pattern.
- Identify desktop apps by app identifier, process name, app name, or executable path signal.
- Return standardized metadata for UI and aggregation.
- Keep the original usage fields intact for compatibility.
- Treat adapter metadata as enhancement. Tracking must continue if adapter resolution fails.
- Avoid private content capture.

## Current Metadata

Adapter metadata can include:

- `sourceType`: `website` or `desktopApp`
- `identifier`: stable support id such as `site:youtube` or `app:vscode`
- `displayName`: friendly name for the UI
- `title`: window title or media title already present in the usage record
- `domain`: normalized website domain when known
- `iconUrl`: optional remote icon URL
- `iconPath`: local app path or repo/qrc icon path
- `iconLabel`: short fallback label
- `brandColor`: stable fallback color
- `category`: friendly category
- `supportsMediaDetection`: whether media playback signals are expected to help
- `confidence`: match confidence

The serialized metadata intentionally does not include a full URL.

## Privacy Principles

TimeArc records time outlines and basic metadata only.

Forbidden by design:

- Screen recording
- Screenshots
- Reading chat content
- Saving webpage body text
- Saving user input field contents
- Uploading private content
- Using IP address as a default identification strategy

Website recognition should use domain, hostname, and URL pattern. Desktop app recognition should use app identifier and process name. Window titles may be used only as a local, best-effort hint for already captured activity labels.

## Code Location

The adapter system lives under:

- `src/services/adapters/adapter_metadata.h`
- `src/services/adapters/activity_adapter_registry.h`
- `src/services/adapters/website_adapter_registry.h`
- `src/services/adapters/desktop_app_adapter_registry.h`
- `src/services/adapters/websites/*.h`
- `src/services/adapters/apps/*.h`

The implementation is header-only so this foundation can be added without touching frozen CMake files. If adapters later grow large enough, move them into compiled sources with a harness-approved build-system change.

## Data Flow

```text
usage_records.jsonl / usage_current.json
  -> UsageStatManager parses raw app/window/audio records
  -> adapter registry resolves metadata from app and website signals
  -> raw fields remain on the QVariantMap
  -> adapter fields are added as enhancement fields
  -> QML uses adapter fields first and falls back to raw fields
```

Current enhancement fields exposed to QML include:

- `adapterIdentifier`
- `sourceType`
- `adapterDisplayName`
- `adapterCategory`
- `adapterConfidence`
- `domain`
- `siteDomain`
- `iconUrl`
- `iconPath`
- `iconSource`
- `iconLabel`
- `brandColor`
- `supportsMediaDetection`

## Current Initial Support

Websites:

- YouTube
- Bilibili
- Spotify Web
- QQ Music Web

Desktop apps:

- Chrome
- Edge
- VSCode
- Spotify
- WeChat
- QQ

## High-Resolution Icons

TimeArc should prefer repo-local icons or high-resolution platform icons when available:

- Desktop apps: use the executable path and Qt app-icon image provider for native icons.
- Known websites: prefer repo-local qrc icons where licensing is acceptable.
- Future browser-extension support can provide `favIconUrl` or a selected high-resolution icon URL, but the adapter layer must not save the full sensitive URL by default.

For unknown websites, a fallback label and brand color are safer than storing a low-quality or privacy-sensitive icon source.

