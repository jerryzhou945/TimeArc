# Windows Autonomous Activity Parity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Windows count demonstrable foreground autonomous work as active, retain one logical session across idle/resume, align media and tray behavior with macOS, and restore Windows build/test conformance.

**Architecture:** Keep Win32 observation in platform adapters and place deterministic lease/session decisions in a Win32-free C state machine. `usage_tracker.c` orchestrates the active-app, process-tree, input, audio, and persistence ports; QML tray controls call the existing `pomodoroManager` directly.

**Tech Stack:** C11, Win32 Tool Help/process APIs, Qt 6 QML, CMake/CTest, Python static tests, project harness.

## Global Constraints

- A process being alive is never autonomous-activity evidence.
- CPU/I/O or foreground media evidence renews a 90,000 ms monotonic lease.
- Input idle becomes effective only after both the input threshold and activity lease expire.
- Idle keeps one logical foreground session open and pauses `active_sec` accumulation.
- Media absence ends immediately; there is no silence grace or periodic logical split.
- Existing SQLite tables and bridge signatures remain unchanged.
- Windows service code stays under `src/service/windows/`; UI code never calls Win32 tracking APIs.
- Every production behavior change starts with a failing test.
- Builds run only through `.harness/tools/build.py`.

---

### Task 1: Wrap-safe input idle and deterministic foreground state

**Files:**
- Create: `src/service/windows/tracker/foreground_state.h`
- Create: `src/service/windows/tracker/foreground_state.c`
- Create: `tests/windows_foreground_state_test.c`
- Modify: `src/service/windows/platform/idle_win.h`
- Modify: `src/service/windows/platform/idle_win.c`
- Modify: `CMakeLists.txt`

**Interfaces:**
- Produces: `uint32_t timearc_win_idle_delta_ms(uint32_t now_tick, uint32_t last_input_tick)`.
- Produces: `timearc_foreground_state_step(TimeArcForegroundState*, const TimeArcForegroundSample*, TimeArcForegroundClosedSession*)` returning whether a prior session closed.
- Produces: `timearc_foreground_state_shutdown(...)` for the final flush.

- [ ] **Step 1: Write the failing native tests**

```c
assert(timearc_win_idle_delta_ms(25u, UINT32_MAX - 24u) == 50u);

TimeArcForegroundState state;
timearc_foreground_state_init(&state, 90000);
step(&state, sample("codex.exe", 41, "Task", 0, 0, 1));
step(&state, sample("codex.exe", 41, "Task", 1000, 1, 0));
step(&state, sample("codex.exe", 41, "Task", 92000, 0, 0));
assert(state.mode == TIMEARC_FOREGROUND_IDLE);
step(&state, sample("codex.exe", 41, "Task", 93000, 1, 0));
assert(state.mode == TIMEARC_FOREGROUND_ACTIVE);
assert(state.active_ms == 92000);
```

- [ ] **Step 2: Configure and run the new target to verify RED**

Run: `cmake -S . -B build -DTIMEARC_ENABLE_WINDOWS_STATE_TEST=ON` then `.local-python\Python312\python.exe .harness/tools/build.py --track B --topic windows-foreground-state-red -- --target timearc_windows_foreground_state_test`

Expected: compilation fails because the new interfaces do not exist.

- [ ] **Step 3: Implement the minimal wrap helper and state machine**

```c
uint32_t timearc_win_idle_delta_ms(uint32_t now_tick,
                                   uint32_t last_input_tick) {
  return now_tick - last_input_tick;
}

typedef struct TimeArcForegroundSample {
  AppInfo app;
  int64_t wall_sec;
  uint64_t monotonic_ms;
  int input_active;
  int autonomous_active;
} TimeArcForegroundSample;
```

The state machine renews `lease_until_ms` on autonomous evidence, uses recent input immediately, updates active duration only while active, retains identity while idle, and closes on executable/PID/title change or shutdown.

- [ ] **Step 4: Build and run the native test to verify GREEN**

Run the wrapped build command above, then `ctest --test-dir build -R timearc_windows_foreground_state_test --output-on-failure`.

Expected: target builds and all rollover/state assertions pass.

- [ ] **Step 5: Commit the focused state-machine change**

```powershell
git add CMakeLists.txt src/service/windows/platform/idle_win.c src/service/windows/platform/idle_win.h src/service/windows/tracker/foreground_state.c src/service/windows/tracker/foreground_state.h tests/windows_foreground_state_test.c
git commit -m "Implement Windows foreground idle state machine"
```

### Task 2: Foreground process-tree CPU/I/O activity probe

**Files:**
- Create: `src/service/windows/platform/process_activity_win.h`
- Create: `src/service/windows/platform/process_activity_win.c`
- Modify: `src/service/CMakeLists.txt`
- Modify: `src/service/windows/tracker/usage_tracker.c`
- Modify: `src/service/windows/tracker/usage_tracker.h`
- Modify: `.harness/rules/02-platform-boundaries.md`
- Modify: `.harness/state/frozen-files.json`
- Test: `tests/windows_foreground_state_test.c`

**Interfaces:**
- Consumes: foreground PID from `AppInfo.process_id` and the Task 1 state machine.
- Produces: `timearc_win_process_activity_sample(TimeArcProcessActivityProbe*, uint32_t root_pid, TimeArcProcessCounters*)`.
- Produces: `timearc_win_process_activity_delta(...)`, returning true only when CPU or I/O deltas exceed named thresholds.

- [ ] **Step 1: Add failing delta/baseline tests**

```c
assert(!timearc_process_activity_delta(&probe, 41, counters(100, 1000)));
assert(!timearc_process_activity_delta(&probe, 41, counters(100, 1000)));
assert(timearc_process_activity_delta(&probe, 41,
                                      counters(100 + TIMEARC_CPU_ACTIVE_100NS,
                                               1000)));
assert(timearc_process_activity_delta(&probe, 41,
                                      counters(100, 1000 + TIMEARC_IO_ACTIVE_BYTES)));
assert(!timearc_process_activity_delta(&probe, 42, counters(500, 9000)));
```

- [ ] **Step 2: Run the native test to verify RED**

Expected: fails because process counter types/functions are absent.

- [ ] **Step 3: Implement snapshot and counter aggregation**

Use `CreateToolhelp32Snapshot`, `Process32FirstW`/`Process32NextW` to discover descendants, then `OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION)`, `GetProcessTimes`, and `GetProcessIoCounters`. Aggregate kernel+user 100 ns ticks and read+write+other bytes. Skip inaccessible/exited children; a snapshot failure returns an unavailable sample.

- [ ] **Step 4: Integrate activity observations into `usage_tracker.c`**

Poll active app before activity classification, poll audio once, derive `input_active`, process-tree delta, and matching foreground media, then pass the normalized sample to the Task 1 state machine. Persist `closed.active_ms / 1000` with the unchanged `update_frontmost` bridge.

- [ ] **Step 5: Build and run native tests to verify GREEN**

Run the harness build for both `time_arc_service` and `timearc_windows_foreground_state_test`, followed by the targeted CTest.

- [ ] **Step 6: Update the platform contract and frozen hashes**

Clarify in rule 02 that supported foreground work evidence may override input idle; regenerate `.harness/state/frozen-files.json` with the repository's documented hash workflow and run `harness_check.py`.

- [ ] **Step 7: Commit process activity integration**

```powershell
git add .harness/rules/02-platform-boundaries.md .harness/state/frozen-files.json src/service/CMakeLists.txt src/service/windows/platform/process_activity_win.c src/service/windows/platform/process_activity_win.h src/service/windows/tracker/usage_tracker.c src/service/windows/tracker/usage_tracker.h tests/windows_foreground_state_test.c
git commit -m "Add Windows foreground autonomous activity detection"
```

### Task 3: Immediate media boundaries and foreground-media evidence

**Files:**
- Modify: `src/service/windows/tracker/audio_tracker.h`
- Modify: `src/service/windows/tracker/audio_tracker.c`
- Create: `tests/windows_audio_tracker_static_test.py`

**Interfaces:**
- Produces: `int timearc_audio_tracker_has_foreground(const TimeArcAudioTrackerState*, const AppInfo*)`.
- Consumes: foreground `AppInfo` in `usage_tracker.c`.

- [ ] **Step 1: Write failing static behavior tests**

```python
require(header, "timearc_audio_tracker_has_foreground", "foreground media query")
reject(header, "TIMEARC_AUDIO_SILENCE_GRACE_SEC", "silence grace")
reject(header, "TIMEARC_AUDIO_FLUSH_INTERVAL_SEC", "periodic split")
reject(source, "last_seen_sec + 1", "delayed media end")
```

- [ ] **Step 2: Run the test to verify RED**

Run: `.local-python\Python312\python.exe tests/windows_audio_tracker_static_test.py`

Expected: fails on the missing foreground query and legacy grace constants.

- [ ] **Step 3: Implement immediate absence and the query**

Close any active session not seen in the successful current audio sample at `now_sec`; do not close sessions on enumeration failure. Remove periodic checkpoint splitting. Match foreground evidence by PID when available and executable path as fallback.

- [ ] **Step 4: Run static and native tests to verify GREEN**

Run the new Python test, build `time_arc_service`, and rerun the state-machine CTest.

- [ ] **Step 5: Commit media parity**

```powershell
git add src/service/windows/tracker/audio_tracker.c src/service/windows/tracker/audio_tracker.h tests/windows_audio_tracker_static_test.py src/service/windows/tracker/usage_tracker.c
git commit -m "Align Windows media session behavior"
```

### Task 4: Windows tray Pomodoro parity and light-theme verification

**Files:**
- Modify: `tests/pomodoro_global_static_test.py`
- Modify: `qml/desktop/memorylake/NotifierTray.qml`
- Modify: `qml/desktop/DesktopAppShell.qml`

**Interfaces:**
- Tray properties: `languageMode`, `pomodoroTimeText`, `pomodoroRunning`, `pomodoroPaused`, `pomodoroCanStart`.
- Tray signals: `pomodoroShowRequested`, `pomodoroPrimaryRequested`, `pomodoroResetRequested`.
- Shell consumes these signals and calls the existing `pomodoroLayer.show()`, `pomodoroManager.startTimer()`, `pauseTimer()`, and `resetTimer()`.

- [ ] **Step 1: Add failing tray assertions**

```python
for fragment in ("pomodoroTimeText", "pomodoroPrimaryRequested",
                 "pomodoroResetRequested", "pomodoroManager.startTimer()",
                 "pomodoroManager.pauseTimer()", "pomodoroManager.resetTimer()"):
    require(combined_source, fragment, "Windows tray Pomodoro parity")
```

- [ ] **Step 2: Run the static test to verify RED**

Run: `.local-python\Python312\python.exe tests/pomodoro_global_static_test.py`

Expected: fails because the tray has no Pomodoro state/actions.

- [ ] **Step 3: Add localized dynamic tray rows and shell bindings**

Bind tray properties from `pomodoroManager`, calculate paused as `!running && remain != total`, and route the three actions to the single shared manager. Use `root.tr(...)`-provided strings so Windows follows current language changes. Keep the macOS native status item hidden path unchanged.

- [ ] **Step 4: Run Pomodoro/about/desktop static tests to verify GREEN**

Run the three targeted Python tests. Manually smoke light and dark Windows tray/menu states during final verification.

- [ ] **Step 5: Commit tray parity**

```powershell
git add tests/pomodoro_global_static_test.py qml/desktop/memorylake/NotifierTray.qml qml/desktop/DesktopAppShell.qml
git commit -m "Add Windows tray Pomodoro controls"
```

### Task 5: Windows build wrapper, manifest path, and full verification

**Files:**
- Modify: `tests/windows_build_script_static_test.py`
- Modify: `tools/build-windows.ps1`
- Modify: `tests/desktop_ux_static_test.py`

**Interfaces:**
- `Build-Release` invokes the active Python executable with `.harness/tools/build.py --build-dir <dir> --track B --topic windows-release-build -- --config Release --parallel`.

- [ ] **Step 1: Re-run the two known failing tests to preserve RED evidence**

Run both Python static tests and confirm the build wrapper and Android manifest failures.

- [ ] **Step 2: Implement the minimal fixes**

Replace direct `cmake --build` orchestration with the harness script while retaining direct CMake configure/install operations. Change the desktop test read path to `android/AndroidManifest.xml`.

- [ ] **Step 3: Run targeted static tests to verify GREEN**

Run Windows build, desktop UX, Pomodoro, About, and audio tracker static tests.

- [ ] **Step 4: Build and run the full native suite**

Run `.local-python\Python312\python.exe .harness/tools/build.py --track B --topic windows-parity-final -- --config Release --parallel`, then `ctest --test-dir build -C Release --output-on-failure`.

- [ ] **Step 5: Runtime smoke and Qt log gate**

Run TimeArc on Windows, verify light/dark shell and tray, foreground Codex child work, foreground playback, true idle, and idle/resume. Stop the app and run `.local-python\Python312\python.exe .harness/tools/scan_qt_log.py`.

- [ ] **Step 6: Final harness and diff verification**

Run `git diff --check`, `.local-python\Python312\python.exe .harness/tools/harness_check.py`, and inspect `git diff --stat` plus `git status --short` to ensure unrelated user changes remain untouched.

- [ ] **Step 7: Commit conformance fixes**

```powershell
git add tools/build-windows.ps1 tests/windows_build_script_static_test.py tests/desktop_ux_static_test.py
git commit -m "Fix Windows build and test conformance"
```
