# TimeArc Usage Record Protocol

`usage_record` is the normalized cross-platform protocol for completed app
usage sessions. Windows and macOS may collect activity differently, but both
services map the same fields into SQLite history and the live JSON snapshot.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `platform` | string | The producer platform: `windows` or `macos`. |
| `source` | string | Optional activity source: `foreground` for active-window usage, `audio` for audio playback. Missing values are treated as `foreground`. |
| `app_id` | string | Stable app identifier. Windows uses the full exe path; macOS uses the bundle id. |
| `app_name` | string | Short app name, such as `chrome.exe` or `Safari`. |
| `window_title` | string | Active window title captured for the usage session. |
| `path` | string | Windows full exe path or macOS app path. |
| `start_unix_sec` | int64 | Session start time in Unix seconds. |
| `duration_sec` | uint64 | Session duration in seconds. |

## Service SQLite Database

`timearc_service.db` is the service-owned primary history store. The service is
the only writer; the Qt app opens it read-only.

`database_storage.*` owns SQLite lifecycle, schema, statements, transactions,
and table writes. `data_bridge.c` only adapts the public C bridge functions to
the storage API.

### `apps`

| Column | Type | Meaning |
| --- | --- | --- |
| `app_id` | text | Stable app identifier. |
| `platform` | text | Producer platform: `windows`, `macos`, or `linux`. |
| `display_name` | text | Localized app name. |
| `icon_path` | text | Path to the app icon. |
| `executable_path` | text | Path to the app executable. |
| `created_at` | int64 | App record creation time in Unix seconds. |
| `updated_at` | int64 | App record last update time in Unix seconds. |

### `frontmost_sessions`

| Column | Type | Meaning |
| --- | --- | --- |
| `app_id` | text | Stable app identifier. |
| `window_title` | text | Active window title captured for the usage session. |
| `start_unix_sec` | int64 | Session start time in Unix seconds. |
| `end_unix_sec` | int64 | Session end time in Unix seconds. |
| `duration_sec` | int64 | Generated column: `end_unix_sec - start_unix_sec`. |
| `active_sec` | int64 | Active time in seconds. |
| `idle_sec` | int64 | Generated column: `duration_sec - active_sec`. |

### `media_sessions`

| Column | Type | Meaning |
| --- | --- | --- |
| `app_id` | text | Stable app identifier. |
| `media_type` | text | Media type: `audio`, `video`, or `unknown`. |
| `media_title` | text | Media title. |
| `start_unix_sec` | int64 | Session start time in Unix seconds. |
| `end_unix_sec` | int64 | Session end time in Unix seconds. |
| `duration_sec` | int64 | Generated column: `end_unix_sec - start_unix_sec`. |

## Platform Mapping

Windows:

- `platform`: `windows`
- `source`: `foreground` for foreground-window tracking; audio tracking uses `audio`. Older writers may omit this field.
- `app_id`: full executable path
- `app_name`: executable file name
- `window_title`: foreground window title
- `path`: full executable path

macOS:

- `platform`: `macos`
- `source`: `foreground` for active app tracking. Writers that have not adopted this field yet may omit it.
- `app_id`: bundle identifier
- `app_name`: localized app name or process name
- `window_title`: active window title when available
- `path`: app bundle path

## `app_info` vs `usage_record`

`app_info` is a snapshot of the currently active app/window. It describes what
the platform API sees at one moment.

`usage_record` is a completed stored session. The tracker compares app snapshots
over time, decides when a session starts and ends, then writes one
`usage_record`.

The intended flow is:

```text
platform API -> app_info -> tracker -> usage_record -> storage
```

## Source And Interval Union

`source` keeps foreground usage and audio playback separate at capture time.
For backwards compatibility, readers should treat a missing `source` as
`foreground`.
The same app can be both foreground and playing audio during the same wall-clock
period. Qt statistics should avoid double counting by merging intervals for the
same app:

```text
end_unix_sec = start_unix_sec + duration_sec
```

For example, if one app has `foreground` from 10:00-10:05 and `audio` from
10:00-10:10, its combined active duration is 10 minutes, not 15 minutes.

## Why Keep Both `app_id` And `path`

`app_id` is the stable identity used for grouping statistics. On Windows the
best stable identifier is currently the executable path, so `app_id` and `path`
may be the same.

On macOS, `app_id` should be the bundle id, while `path` should be the app path.
Keeping both fields avoids platform-specific meaning leaking into the Qt stats
layer.

## Derived End Time

The end time is derived as:

```text
end_unix_sec = start_unix_sec + duration_sec
```

The bridge carries `start_unix_sec` and `duration_sec`; SQLite stores
`end_unix_sec` and derives `duration_sec` as a generated column.

## Idle Mapping

Idle detection is tracker control logic. If the user becomes idle, the tracker
closes the current session and writes its active duration. SQLite stores
`active_sec` and derives `idle_sec` as a generated column.

## Bridge Function Shape

The public C bridge uses `const char*` string parameters instead of fixed-size
arrays:

- Swift can call it more easily.
- C callers can pass normal strings.
- The implementation can still copy into `TimeArcUsageRecord` internally.
- The ABI stays small and stable.

## Live Snapshot Example

```json
{"platform":"windows","source":"foreground","app_id":"C:/Program Files/Google/Chrome/Application/chrome.exe","app_name":"chrome.exe","window_title":"YouTube - Google Chrome","path":"C:/Program Files/Google/Chrome/Application/chrome.exe","start_unix_sec":1713386400,"duration_sec":60,"live":1,"updated_unix_sec":1713386460}
```
