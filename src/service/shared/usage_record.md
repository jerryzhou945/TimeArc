# TimeArc Usage Record Protocol

`usage_record` is the stored cross-platform protocol for completed app usage
sessions. Windows and macOS may collect app activity differently, but both
services should write records with the same 7 fields so JSONL, SQLite, and the
Qt statistics layer can share one format.

## Fields

| Field | Type | Meaning |
| --- | --- | --- |
| `platform` | string | The producer platform: `windows` or `macos`. |
| `app_id` | string | Stable app identifier. Windows uses the full exe path; macOS uses the bundle id. |
| `app_name` | string | Short app name, such as `chrome.exe` or `Safari`. |
| `window_title` | string | Active window title captured for the usage session. |
| `path` | string | Windows full exe path or macOS app path. |
| `start_unix_sec` | int64 | Session start time in Unix seconds. |
| `duration_sec` | uint64 | Session duration in seconds. |

## Platform Mapping

Windows:

- `platform`: `windows`
- `app_id`: full executable path
- `app_name`: executable file name
- `window_title`: foreground window title
- `path`: full executable path

macOS:

- `platform`: `macos`
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

## Why Keep Both `app_id` And `path`

`app_id` is the stable identity used for grouping statistics. On Windows the
best stable identifier is currently the executable path, so `app_id` and `path`
may be the same.

On macOS, `app_id` should be the bundle id, while `path` should be the app path.
Keeping both fields avoids platform-specific meaning leaking into the Qt stats
layer.

## Why `end_unix_sec` Is Not Stored

The end time is derived as:

```text
end_unix_sec = start_unix_sec + duration_sec
```

Keeping only `start_unix_sec` and `duration_sec` avoids inconsistent records
where the end time disagrees with the duration. Query code can derive the end
boundary when needed.

## Why `idle` Is Not Stored

Idle detection is tracker control logic. If the user becomes idle, the tracker
closes the current session and writes the active duration. Storage does not need
to know why the session ended for the first version.

## Bridge Function Shape

The public C bridge uses `const char*` string parameters instead of fixed-size
arrays:

- Swift can call it more easily.
- C callers can pass normal strings.
- The implementation can still copy into `TimeArcUsageRecord` internally.
- The ABI stays small and stable.

## JSONL Example

```json
{"platform":"windows","app_id":"C:/Program Files/Google/Chrome/Application/chrome.exe","app_name":"chrome.exe","window_title":"YouTube - Google Chrome","path":"C:/Program Files/Google/Chrome/Application/chrome.exe","start_unix_sec":1713386400,"duration_sec":60}
```
