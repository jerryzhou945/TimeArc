# Rule 01 — Architecture Boundaries

The project has **three layers**. A change that crosses a layer boundary should
be rare and conscious. If a diff crosses a layer, mention it in the commit
message.

```
┌───────────────────────────────────────────────────────────────┐
│  UI layer  (src/ + qml/)                                      │
│    ├─ C++ QObject managers (services/*manager.*)              │
│    ├─ main.cpp — starts the service, wires managers into QML  │
│    └─ QML pages + components under qml/desktop | qml/mobile   │
├───────────────────────────────────────────────────────────────┤
│  Shared contract  (src/service/shared/)                       │
│    ├─ data_bridge.h — C ABI for trackers                      │
│    ├─ usage_record.h/.schema.json — on-disk record            │
│    ├─ database_path.h/.c — service DB path resolver           │
│    └─ app_info.h / app_env.h — sampling structs               │
├───────────────────────────────────────────────────────────────┤
│  Service layer  (src/service/<platform>/)                     │
│    ├─ tracker/ — foreground + audio sampling loops            │
│    ├─ platform/ — OS-specific probes (active app, idle, audio)│
│    ├─ storage/ — JSONL + live-snapshot writer                 │
│    └─ service/ — OS service registration (Windows: TODO)      │
└───────────────────────────────────────────────────────────────┘
```

---

## 1. Allowed includes

| From                  | May include                                                |
|-----------------------|------------------------------------------------------------|
| `src/main.cpp`        | `services/*.h`, Qt headers                                 |
| `src/services/*.cpp`  | Qt headers, its own `.h`, other `services/*.h`. **NO** service-layer headers. |
| `src/service/shared/*.h`| C stdlib only. **No** Qt, **no** platform headers (clients include these). |
| `src/service/shared/*.c`| May switch on `#ifdef _WIN32` etc. internally (see `database_path.c`). |
| `src/service/windows/*`| `service/shared/*`, Windows SDK headers                   |
| `src/service/macos/*` | `service/shared/*`, Cocoa/Foundation/etc.                  |
| `src/service/linux/*` | `service/shared/*`, POSIX/X11/Wayland headers              |

Concrete anti-examples — if you see these, reject the diff:

- A `#include <QObject>` anywhere under `src/service/`.
- A `#include <windows.h>` anywhere under `src/service/shared/`.
- A `#include "../windows/..."` from `src/service/macos/`.
- A `services/usage_stat_manager.cpp` opening a raw socket to the service.

## 2. Data-flow direction

The service is the **producer**. The UI is the **consumer**. Data flows one
way: service → disk → UI. Do not reverse this. If the UI needs to influence
sampling (e.g., pause, filter), introduce a control file in
`~/.timearc/control/` and define it in `rules/03-data-contract.md` — do not
open a pipe.

## 3. UI managers and repositories

UI-facing managers are registered as QML context properties in `src/main.cpp`.
They stay small, synchronous where possible, and delegate persistence to the
repository layer.

| Component | Source of truth | Notes |
|-----------|-----------------|-------|
| `CalendarManager` | `SettingsRepository` / SQLite settings | Todos, day photos, selected date. Legacy QSettings is fallback/migration input only. |
| `ProjectManager` | `ManualProjectRepository` / SQLite | Manual projects, timer sessions, archive-hidden deletes, range aggregation. |
| `TimerManager` | in-memory | Manual stopwatch. Commits through `ProjectManager`. |
| `UsageStatManager` | journal files on disk | Reads service JSONL/current snapshot for the legacy usage surface. |
| `StatsService` | service DB read repos + GUI DB manual repo | Aggregates foreground, media, and manual project data for desktop summaries. |

`AppIconImageProvider` is a passive `image://appicon/<path>` provider.

Do not add new cross-manager signals without a short note in
`rules/04-ui-conventions.md`.
## 4. Adding a new subsystem

A "new subsystem" (say, keyboard-input heatmap) lands as:

1. A new sampling module under the correct platform folder.
2. A new source string in `usage_record.schema.json` **if** it produces records
   — this is a data-contract change (see rule 03).
3. A new aggregation path in `UsageStatManager` or a new manager.
4. A new QML page wired through `*AppShell.qml`.

If your new subsystem does not fit this shape, reread `CHARTER.md` §1 before
implementing.
