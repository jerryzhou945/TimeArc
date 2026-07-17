# TimeArc Service

TimeArc uses separate service implementations per platform, but all of them share the same CLI and write the same service-owned database.

> The service CLI design has not been implemented yet.

- `shared/`: shared protocol, app snapshots, environment interfaces, SQLite
  database storage, and path helpers.
- `windows/`: Windows implementation in C.
- `macos/`: macOS implementation in Swift.
- `linux/`: Linux implementation in C.

## Command-Line Interface

The service CLI is designed to be used by the TimeArc GUI but also supports direct invocation. It controls the service lifecycle, reports its state, and manages autostart registration.

```text
time-arc-service [run]
time-arc-service enable
time-arc-service disable
time-arc-service start
time-arc-service stop
time-arc-service restart
time-arc-service status [--text|--json] [--verbose]
time-arc-service doctor [--text|--json] [--verbose]
time-arc-service help|-h|--help
time-arc-service version|-v|--version
```

### Command Descriptions

#### `run`

Starts the service in the foreground. This is the default command if no other command is specified. It runs the service in the current process and blocks until the service is stopped. If configuration has tracking disabled, the command exits with code 0. Otherwise, the command returns 0 after a clean shutdown with pending sessions flushed, or code 3/4/5/6 if it fails.

#### `enable`

Registers the service for autostart on login.

#### `disable`

Removes every autostart registration backend known to the platform.

#### `start`

Starts the service in the background. It launches the service in a new process and waits until the tracking process reaches a stable state. If configuration has tracking disabled, the command exits with code 0. Otherwise, the command exits with code 0 if the service starts successfully or is already running, or code 3/4/5 if it fails.

#### `stop`

Requests a graceful shutdown of the service. The command exits with code 0 if no service process is running, or code 3 if it fails.

#### `restart`

Restarts the service. It waits for the service to stop and then start it with a fresh configuration. The command exits with code 0 if the service starts successfully or has been disabled in configuration, or code 3/4/5 if it fails.

#### `status`

Queries the service state and prints it in the requested format. The default format is text, but JSON is also supported with the `--json` flag. The `--verbose` flag adds additional information about the service database, executable and process to JSON output. A successful query exits with code 0 if the service is running and enabled in configuration, or a non-zero code depending on the state of the service. If the state cannot be queried reliably, the command exits with code 10.

Status descriptions:

- **`platform`**: The operating system (`windows`, `macos`, or `linux`).
- **`tracking.running`**: Whether the service is actively tracking.
- **`tracking.enabled`**: Whether tracking is enabled in the configuration.
- **`tracking.frontmost.enabled`**: Whether frontmost app tracking is enabled.
- **`tracking.media.enabled`**: Whether media tracking is enabled.
- **`autostart.enabled`**: Whether the service is registered for autostart on login.
- **`autostart.backend`**: The backend used for autostart registration, which is platform-specific. If the service is not registered for autostart, it is `null`.

Text output example:

```text
TimeArc Service 0.1.0 on macOS

Tracking: running
Frontmost apps: enabled (idle threshold 60s)
Media sessions: enabled
Autostart: enabled (launch agent)
```

JSON output example:

```json
{
  // Default
  "schema_version": 1,
  "command": "status",
  "platform": "macos",
  "tracking": {
    "running": true,
    "enabled": true,
    "frontmost": {
      "enabled": true,
      "idle_threshold_sec": 60
    },
    "media": {
      "enabled": true
    }
  },
  "autostart": {
    "enabled": true,
    "backend": "launch-agent"
  },
  // Verbose
  "database": {
    "path": "/Users/steve/Library/Application Support/TimeArc/service/timearc_service.db",
    "size_bytes": 16384
  },
  "executable": {
    "version": "0.1.0",
    "path": "/Applications/TimeArc.app/Contents/MacOS/time-arc-service"
  },
  "process": {
    "pid": 2026,
    "start_unix_sec": 1776070400,
    "uptime_sec": 8086,
    "command": [
      "/Applications/TimeArc.app/Contents/MacOS/time-arc-service",
      "run"
    ]
  }
}
```

#### `doctor`

Examines the service configuration, database, autostart registration, and tracking availability. The default format is text, but JSON is also supported with the `--json` flag. The `--verbose` flag adds detailed information about each check to JSON output. A successful examination exits with code 0 if the overall status is `healthy`, or a non-zero code depending on the status. If the result cannot be queried reliably, the command exits with code 20.

Status descriptions:

| **Capability Status** | **Meaning**                                           |
| --------------------- | ----------------------------------------------------- |
| **`pass`**            | The check is reliable and the capability is working.  |
| **`warn`**            | The check is reliable but the capability is degraded. |
| **`fail`**            | The check is reliable but the capability is broken.   |
| **`skip`**            | The check is not applicable.                          |

| **Overall Status** | **Meaning**                |
| ------------------ | -------------------------- |
| **`healthy`**      | All checks passed.         |
| **`degraded`**     | At least one check warned. |
| **`failed`**       | At least one check failed. |

Text output example:

```text
TimeArc Service 0.1.0 on macOS

Overall: healthy (8 pass, 0 warn, 0 fail, 0 skip)
Configuration:
  [pass] Service configuration file path is valid.
  [pass] Service configuration file schema is valid.
Database:
  [pass] Service database directory is valid.
  [pass] Service database schema is valid.
Autostart:
  [pass] Service autostart registration is valid.
  [pass] No duplicate autostart registrations found.
Availability:
  [pass] Necessary permissions are granted.
  [pass] Tracking information is accessible.
```

JSON output example:

```json
{
  "schema_version": 1,
  "command": "doctor",
  "platform": "macos",
  "report": {
    "generated_at_unix_sec": 1776070400,
    "overall": "healthy",
    "counts": {
      "pass": 8,
      "warn": 0,
      "fail": 0,
      "skip": 0
    }
  },
  "sections": [
    {
      "id": "configuration",
      "status": "pass",
      "checks": [
        {
          // Default
          "id": "configuration.path",
          "status": "pass",
          "summary": "Service configuration file path is valid.",
          // Verbose
          "details": {
            "path": "/Users/steve/Library/Application Support/TimeArc/usage/usage_config.json",
            "exists": true,
            "readable": true,
            "writable": true
          }
        },
        {
          // Default
          "id": "configuration.schema",
          "status": "pass",
          "summary": "Service configuration file schema is valid.",
          // Verbose
          "details": {
            "schema_version": 1,
            "unknown_keys": [],
            "missing_default_keys": [],
            "invalid_value_keys": []
          }
        }
      ]
    },
    {
      "id": "database",
      "status": "pass",
      "checks": [
        {
          // Default
          "id": "database.directory",
          "status": "pass",
          "summary": "Service database directory is valid.",
          // Verbose
          "details": {
            "path": "/Users/steve/Library/Application Support/TimeArc/service",
            "exists": true,
            "readable": true,
            "writable": true,
            "platform_default": true,
            "size_bytes": 16384,
            "free_bytes": 1234567890
          }
        },
        {
          // Default
          "id": "database.schema",
          "status": "pass",
          "summary": "Service database schema is valid.",
          // Verbose
          "details": {
            "user_version": 1,
            "sqlite_version": "3.51.3",
            "unexpected_tables": [],
            "tables": {
              "apps": {
                "exists": true,
                "missing_columns": [],
                "unexpected_columns": []
              },
              "frontmost_sessions": {
                "exists": true,
                "missing_columns": [],
                "unexpected_columns": []
              },
              "media_sessions": {
                "exists": true,
                "missing_columns": [],
                "unexpected_columns": []
              }
            }
          }
        }
      ]
    },
    {
      "id": "autostart",
      "status": "pass",
      "checks": [
        {
          // Default
          "id": "autostart.registration",
          "status": "pass",
          "summary": "Service autostart registration is valid.",
          // Verbose
          "details": {
            "enabled": true,
            "backend": "launch-agent",
            "label": "com.timearc.service",
            "path": "/Applications/TimeArc.app/Contents/Library/LaunchAgents/com.timearc.service.plist",
            "command": [
              "/Applications/TimeArc.app/Contents/MacOS/time-arc-service",
              "run"
            ]
          }
        },
        {
          // Default
          "id": "autostart.duplicates",
          "status": "pass",
          "summary": "No duplicate autostart registrations found.",
          // Verbose
          "details": {
            "duplicate_backends": []
          }
        }
      ]
    },
    {
      "id": "availability",
      "status": "pass",
      "checks": [
        {
          // Default
          "id": "availability.permissions",
          "status": "pass",
          "summary": "Necessary permissions are granted.",
          // Verbose
          "details": {
            "permissions": [
              {
                "name": "Accessibility",
                "granted": true,
                "capabilities": [
                  "frontmost_app",
                  "window_title",
                  "idle_state",
                  "media_session",
                  "media_title"
                ]
              }
            ]
          }
        },
        {
          // Default
          "id": "availability.information",
          "status": "pass",
          "summary": "Tracking information is accessible.",
          // Verbose
          "details": {
            "information": {
              "frontmost_app": {
                "required": true,
                "available": true
              },
              "window_title": {
                "required": true,
                "available": true
              },
              "idle_state": {
                "required": true,
                "available": true
              },
              "media_session": {
                "required": true,
                "available": true
              },
              "media_title": {
                "required": true,
                "available": true
              }
            }
          }
        }
      ]
    }
  ]
}
```

#### `help`

Prints the command usage and exits with code 0.

#### `version`

Prints the version information and exits with code 0.

### Exit Codes

| **Exit Code** | **Meaning**                                                   |
| ------------: | ------------------------------------------------------------- |
|           `0` | Command completed successfully.                               |
|           `1` | Command failed due to a generic internal error.               |
|           `2` | Invalid command or arguments.                                 |
|           `3` | Command failed due to a platform error.                       |
|           `4` | The service failed to start because of a configuration error. |
|           `5` | The service failed to start because of a database error.      |
|           `6` | A second instance of the service is already running.          |
|          `10` | Service state could not be queried reliably.                  |
|          `11` | Service is running but not enabled in configuration.          |
|          `12` | Service is not running but enabled in configuration.          |
|          `13` | Service is not running and not enabled in configuration.      |
|          `20` | Doctor results could not be queried reliably.                 |
|          `21` | Doctor overall status is `degraded`.                          |
|          `22` | Doctor overall status is `failed`.                            |

### Platform Mapping

#### Windows

Scheduled task with user logon trigger (`scheduled-task`). Falls back to HKCU (`hkcu`).

#### macOS

Bundled launch agent (`launch-agent`).

#### Linux

Systemd user service (`systemd`). Falls back to XDG autostart (`xdg-autostart`).

## Database Structure

The service SQLite database is resolved by `shared/database_path.*`. Its locked filename is `timearc_service.db`. `shared/database_storage.*` owns the SQLite connection, schema, statements, transactions, and table writes. `shared/data_bridge.c` exposes the public table-write bridge around that storage API. The Qt app opens that database read-only for history.

### Table Descriptions

#### `apps`

Map of app identifiers to human-readable app information.

| **Column**            | **C Type**    | **Swift Type** | **Meaning**                                           |
| --------------------- | ------------- | -------------- | ----------------------------------------------------- |
| **`app_id`**          | `const char*` | `String`       | Stable app identifier.                                |
| **`platform`**        | `const char*` | `String`       | The producer platform: `windows`, `macos` or `linux`. |
| **`display_name`**    | `const char*` | `String`       | Localized app name.                                   |
| **`icon_path`**       | `const char*` | `String`       | Path to the app icon.                                 |
| **`executable_path`** | `const char*` | `String`       | Path to the app executable.                           |
| **`created_at`**      | `int64_t`     | `Int64`        | App record creation time in Unix seconds.             |
| **`updated_at`**      | `int64_t`     | `Int64`        | App record last update time in Unix seconds.          |

#### `frontmost_sessions`

Records of frontmost app sessions.

| **Column**           | **C Type**    | **Swift Type** | **Meaning**                                         |
| -------------------- | ------------- | -------------- | --------------------------------------------------- |
| **`app_id`**         | `const char*` | `String`       | Stable app identifier.                              |
| **`window_title`**   | `const char*` | `String`       | Active window title captured for the usage session. |
| **`start_unix_sec`** | `int64_t`     | `Int64`        | Session start time in Unix seconds.                 |
| **`end_unix_sec`**   | `int64_t`     | `Int64`        | Session end time in Unix seconds.                   |
| **`duration_sec`**   | `int64_t`     | `Int64`        | Generated column: `end_unix_sec - start_unix_sec`.  |
| **`active_sec`**     | `int64_t`     | `Int64`        | Active time in seconds.                             |
| **`idle_sec`**       | `int64_t`     | `Int64`        | Generated column: `duration_sec - active_sec`.      |

#### `media_sessions`

Records of media sessions.

| **Column**           | **C Type**    | **Swift Type** | **Meaning**                                        |
| -------------------- | ------------- | -------------- | -------------------------------------------------- |
| **`app_id`**         | `const char*` | `String`       | Stable app identifier.                             |
| **`media_type`**     | `const char*` | `String`       | Media type: `audio`, `video`, or `unknown`.        |
| **`media_title`**    | `const char*` | `String`       | Media title.                                       |
| **`start_unix_sec`** | `int64_t`     | `Int64`        | Session start time in Unix seconds.                |
| **`end_unix_sec`**   | `int64_t`     | `Int64`        | Session end time in Unix seconds.                  |
| **`duration_sec`**   | `int64_t`     | `Int64`        | Generated column: `end_unix_sec - start_unix_sec`. |

### Platform Mapping

#### Windows

**Default path**: `%APPDATA%\TimeArc\service\timearc_service.db`

- **`platform`**: `windows`.
- **`app_id`**: Normalized executable path.
  - **Note**: Version information is stripped from the path to ensure a stable identifier.
- **`display_name`**: Package display name (for packaged apps).
  - **Fallback**: FileDescription/ProductName (executable metadata); Start menu shortcut name; Executable file name.
- **`icon_path`**: Full executable path.
- **`executable_path`**: Full executable path.

#### macOS

**Default path**: `~/Library/Application Support/TimeArc/service/timearc_service.db`

- **`platform`**: `macos`.
- **`app_id`**: Bundle identifier.
- **`display_name`**: Localized name.
- **`icon_path`**: Bundle URL.
- **`executable_path`**: Bundle URL.

#### Linux

**Default path**: `${XDG_DATA_HOME:-~/.local/share}/TimeArc/service/timearc_service.db`

- **`platform`**: `linux`.
- **`app_id`**: Desktop file ID.
- **`display_name`**: Localized name from the `.desktop` file.
- **`icon_path`**: Icon from the `.desktop` file.
  - **Note**: If the icon is specified as a name, it should be resolved to a full path by the GUI.
- **`executable_path`**: Full executable path.
