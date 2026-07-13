# TimeArc Background Service

TimeArc uses separate service implementations per platform, but all of them
write the same service-owned usage database.

- `shared/`: shared protocol, app snapshots, environment interfaces, SQLite
  database storage, and path helpers.
- `windows/`: Windows implementation in C using Windows API.
- `macos/`: macOS implementation scaffold in Swift.
- `linux/`: Linux implementation scaffold in C.

The service SQLite database is resolved by `shared/database_path.*`. Its locked filename is `timearc_service.db`. `shared/database_storage.*` owns the SQLite connection, schema, statements, transactions, and table writes. `shared/data_bridge.c` exposes the public table-write bridge around that storage API. The Qt app opens that database read-only for history.

## Database Structure

### Apps

**`apps`**: Map of app identifiers to human-readable app information.

| **Column**            | **C Type**    | **Swift Type** | **Meaning**                                           |
| --------------------- | ------------- | -------------- | ----------------------------------------------------- |
| **`app_id`**          | `const char*` | `String`       | Stable app identifier.                                |
| **`platform`**        | `const char*` | `String`       | The producer platform: `windows`, `macos` or `linux`. |
| **`display_name`**    | `const char*` | `String`       | Localized app name.                                   |
| **`icon_path`**       | `const char*` | `String`       | Path to the app icon.                                 |
| **`executable_path`** | `const char*` | `String`       | Path to the app executable.                           |
| **`created_at`**      | `int64_t`     | `Int64`        | App record creation time in Unix seconds.             |
| **`updated_at`**      | `int64_t`     | `Int64`        | App record last update time in Unix seconds.          |

### Frontmost Sessions

**`frontmost_sessions`**: Records of frontmost app sessions.

| **Column**           | **C Type**    | **Swift Type** | **Meaning**                                         |
| -------------------- | ------------- | -------------- | --------------------------------------------------- |
| **`app_id`**         | `const char*` | `String`       | Stable app identifier.                              |
| **`window_title`**   | `const char*` | `String`       | Active window title captured for the usage session. |
| **`start_unix_sec`** | `int64_t`     | `Int64`        | Session start time in Unix seconds.                 |
| **`end_unix_sec`**   | `int64_t`     | `Int64`        | Session end time in Unix seconds.                   |
| **`duration_sec`**   | `int64_t`     | `Int64`        | Generated column: `end_unix_sec - start_unix_sec`.  |
| **`active_sec`**     | `int64_t`     | `Int64`        | Active time in seconds.                             |
| **`idle_sec`**       | `int64_t`     | `Int64`        | Generated column: `duration_sec - active_sec`.      |

### Media Sessions

**`media_sessions`**: Records of media sessions.

| **Column**           | **C Type**    | **Swift Type** | **Meaning**                                        |
| -------------------- | ------------- | -------------- | -------------------------------------------------- |
| **`app_id`**         | `const char*` | `String`       | Stable app identifier.                             |
| **`media_type`**     | `const char*` | `String`       | Media type: `audio`, `video`, or `unknown`.        |
| **`media_title`**    | `const char*` | `String`       | Media title.                                       |
| **`start_unix_sec`** | `int64_t`     | `Int64`        | Session start time in Unix seconds.                |
| **`end_unix_sec`**   | `int64_t`     | `Int64`        | Session end time in Unix seconds.                  |
| **`duration_sec`**   | `int64_t`     | `Int64`        | Generated column: `end_unix_sec - start_unix_sec`. |

## Platform Mapping

### Windows

**Default path**: `%APPDATA%\TimeArc\service\timearc_service.db`

- **`platform`**: `windows`.
- **`app_id`**: Normalized executable path.
  - Note: Version information is stripped from the path to ensure a stable identifier.
- **`display_name`**: Package display name (for packaged apps).
  - Fallback: FileDescription/ProductName (executable metadata); Start menu shortcut name; Executable file name.
- **`icon_path`**: Full executable path.
- **`executable_path`**: Full executable path.

### macOS

**Default path**: `~/Library/Application Support/TimeArc/service/timearc_service.db`

- **`platform`**: `macos`.
- **`app_id`**: Bundle identifier.
- **`display_name`**: Localized name.
- **`icon_path`**: Bundle URL.
- **`executable_path`**: Bundle URL.

### Linux

**Default path**: `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db`

- **`platform`**: `linux`.
- **`app_id`**: Desktop file ID.
- **`display_name`**: Localized name from the `.desktop` file.
- **`icon_path`**: Icon from the `.desktop` file.
  - Note: If the icon is specified as a name, it should be resolved to a full path by the GUI.
- **`executable_path`**: Full executable path.
