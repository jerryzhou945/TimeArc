# Rule 05 — Build System

CMake structure rules. The build tree is small but has non-trivial invariants.

## 1. Layout

```
CMakeLists.txt                   ← project() + target + install
├── thirdparty/CMakeLists.txt    ← aggregates sqlite3 + parson → TIME_ARC_THIRDPARTY_LIBS
├── src/CMakeLists.txt           ← main-app sources → TIME_ARC_APP_SOURCES, TIME_ARC_INCLUDE_DIRS
│   └── service/CMakeLists.txt   ← standalone time_arc_service executable
├── qml/CMakeLists.txt           ← qml files → TIME_ARC_QML_FILES
└── resources/                  ← embedded list + functional desktop QRCs
```

Variables propagate up with `set(VAR ${VAR} PARENT_SCOPE)`. Preserve this idiom.

## 2. Minimum versions

- CMake `>= 3.16`
- Qt `>= 6.8` (`qt_standard_project_setup(REQUIRES 6.8)`)
- C standard: C11
- C++ standard: C++17
- macOS: Swift enabled via `enable_language(Swift)` when `APPLE`, with
  `cmake_policy(CMP0157 NEW)` when available.

Do not lower these. Do not raise them without a charter amendment — macOS
Swift interop to `data_bridge.h` requires careful CMake work and is fragile.

## 3. Two application targets

| Target              | Output name         | Kind        | Where                  |
|---------------------|---------------------|-------------|------------------------|
| `time-arc`          | `TimeArc`           | GUI exe     | root `CMakeLists.txt`  |
| `time_arc_service`  | `time-arc-service`  | console exe | `src/service/CMakeLists.txt` |

Both are installed by the root build. On macOS both executables live in
`TimeArc.app/Contents/MacOS`; elsewhere they share the runtime `bin` directory.

## 4. Adding a source file

- New C++/C UI source → list it in `src/CMakeLists.txt` under
  `TIME_ARC_APP_SOURCES`. If it introduces a new include root, extend
  `TIME_ARC_INCLUDE_DIRS`.
- New platform service source → list it in the matching branch of
  `src/service/CMakeLists.txt` (`if(APPLE) / elseif(WIN32) / elseif(UNIX)`).
- New shared service header/source → list it in
  `TIME_ARC_SERVICE_SHARED_COMMON_HEADERS` or
  `..._COMMON_C_SOURCES`. If the file must not be built on macOS, put it under
  `..._WINLINUX_*` instead (see existing `app_info.h` / `app_env.h`).
- New QML file → add to `qml/CMakeLists.txt` AND reference it from one of the
  existing shells.
- Small shell/license resource → `resources/CMakeLists.txt`; large GUI content
  → matching functional QRC (external desktop RCC, Android-embedded).

## 5. Qt LGPL requirement

Qt is linked today via `target_link_libraries(time-arc PRIVATE Qt6::...)`. For
distribution builds, Qt modules must be **dynamically** linked (LGPL-3.0).
The main README TO-DO already notes this. When the distribution story lands,
adjust `qt_add_executable` + link flags accordingly and update
`rules/06-licensing.md`.

Do not statically link Qt in any configuration without reading
`rules/06-licensing.md` first.

## 6. Windows-specific link deps

`time_arc_service` on Windows links `user32 psapi ole32 uuid` — required by
active-app probing, audio, and COM. Keep them. Adding more (e.g.,
`avrt.lib` for audio session-level work) is fine but must be listed in the
Windows branch of `src/service/CMakeLists.txt`.

## 7. Build hygiene

- `CMAKE_EXPORT_COMPILE_COMMANDS ON` is set at the root; do not remove.
- The `build/` directory is git-ignored. Nothing in it is source of truth.
- Never commit `*.autogen.*`, `compile_commands.json`, `CMakeCache.txt`, etc.
- Desktop packages require backgrounds/site-icons/monthly-recap RCCs; missing is fatal.

## 8. Hooking the harness into CMake

`.harness/tools/cmake/HarnessHooks.cmake` provides:

- `timearc_harness_enable()`: finds Python, registers the check target.
- `timearc_harness_add_check_target()`: adds a `harness-check` custom target
  (not in ALL) running `tools/harness_check.py`.
- `timearc_harness_record_build_target(<target> <track> <topic>)`:
  POST_BUILD marker for successful builds of a specific target.

For **build-failure** capture, wrap the build itself:

    python .harness/tools/build.py [-- <cmake extra args>]

`build.py` runs `cmake --build`, tees the log, and auto-files L1 errors on
non-zero exit. Prefer it over raw `cmake --build` in scripted use.

These are optional opt-ins; the build must continue to succeed without the
harness being installed. Do not make the harness a hard build dependency.
