# Windows Autonomous Activity and macOS Parity Design

Date: 2026-08-01

Track: B — Feature

Status: Proposed for user review

## 1. Goal

Bring the Windows desktop implementation to behavioral parity with the newly merged macOS work without changing the shared journal schema. The update covers four gaps:

1. distinguish genuinely idle foreground applications from applications doing autonomous work;
2. keep one logical foreground session open across idle periods while counting only active time;
3. expose the shared Pomodoro controls through the Windows tray;
4. restore Windows build/test conformance and verify the shared light-theme changes on Windows.

The key product rule is: **lack of keyboard or mouse input is not sufficient evidence of idleness when the foreground application is demonstrably working. Process existence alone is never sufficient evidence of activity.**

## 2. Confirmed activity semantics

At every service sample, Windows evaluates the foreground application in this order:

1. Recent keyboard or mouse input means active.
2. Otherwise, meaningful CPU or I/O activity from the foreground process or one of its descendants renews a 90-second work lease.
3. Foreground media playback also renews the same lease.
4. While the lease is valid, the foreground session remains active even without user input.
5. When there is neither recent input nor qualifying autonomous activity for 90 seconds, the session becomes idle.

The lease uses a monotonic clock. Merely keeping a process alive, holding an open handle, repainting at a negligible background rate, or producing activity outside the foreground process tree does not renew it.

Examples:

- Codex running a command, compiler, test runner, or other child process continues to count as active.
- A video or audio player in the foreground continues to count as active while playback is present.
- An editor left unchanged with no input and no meaningful foreground-tree activity becomes idle after 90 seconds.
- A background download in an unrelated process does not keep the foreground application active.

## 3. Architecture

### 3.1 Windows platform observation

Add a Windows-only activity probe under `src/service/windows/platform/`. It produces one normalized observation per sampling tick:

- foreground PID, executable path, process name, and window title;
- input-idle duration;
- cumulative CPU time and I/O byte counters for the foreground process tree;
- whether foreground media playback is currently present;
- monotonic sample timestamp.

The process tree is built from a Tool Help snapshot and parent-PID relationships. CPU time comes from `GetProcessTimes`; I/O counters come from `GetProcessIoCounters`. Processes that exit during a sample or deny query access are skipped. A partial or failed probe never invents activity.

The first observation for a process tree establishes a baseline and does not renew the lease by itself. Later positive deltas are compared with small named thresholds. Threshold values live beside the probe and are covered by unit tests so routine bookkeeping noise cannot keep an application active forever. The implementation records diagnostic counters for skipped or inaccessible processes without failing the tracker.

### 3.2 Monotonic input-idle calculation

Replace the current subtraction of `GetTickCount64()` and the 32-bit `LASTINPUTINFO.dwTime` with an explicit wrap-safe helper. The helper reconstructs elapsed input time in the same 32-bit tick domain and returns a bounded duration. It has deterministic tests around the 49.7-day rollover boundary.

### 3.3 Activity lease state machine

Extract the foreground state transition logic into a small C module that is independent of Win32 calls and SQLite. Its inputs are normalized observations; its outputs are transitions and elapsed active/idle deltas.

States:

- `active`: input is recent or the autonomous-work lease is valid;
- `idle`: the same logical foreground application remains selected, but active time is paused;
- `closed`: application identity changed or the service is shutting down.

Transition rules:

- active → idle keeps the logical session open and accumulates idle duration;
- idle → active resumes the same session;
- an identity change closes the old session and starts a new one;
- shutdown closes the current session;
- transient observation failure retains the last identity but cannot renew the lease.

Normalized foreground identity includes stable application identity, PID, and title. Activity state, timestamps, and accumulated counters are not identity fields. A title or foreground PID change therefore remains a real session boundary, matching the richer macOS observations.

The persistence contract remains unchanged: the writer emits the completed logical session at an actual identity boundary or shutdown, with `active_sec` excluding idle intervals and `idle_sec` containing them. No database migration is required.

### 3.4 Media integration

Refactor the Windows audio tracker so its current sample can answer whether the foreground PID/executable has active playback. That evidence feeds the shared activity lease.

At the same time, align media-session boundaries with the existing contract:

- remove the silence grace period;
- end media presence immediately when the platform reports it absent;
- remove periodic logical-session splitting;
- persist only at a real media identity boundary or shutdown.

This intentionally favors correct logical identity over mid-session partial visibility. No storage schema or reader change is required.

### 3.5 Windows tray Pomodoro parity

Extend `NotifierTray.qml` with the same user-visible Pomodoro operations available from the macOS status bar:

- current phase and remaining time;
- start;
- pause/resume;
- reset;
- open the application.

`DesktopAppShell.qml` wires these actions to the existing shared Pomodoro manager. The tray owns no timer state and introduces no second timer. Labels use the existing runtime i18n path. Light and dark icon/text states must be legible on Windows 10 and 11.

### 3.6 Shared light UI

The macOS branch's light-theme implementation is already shared QML and was merged without a Windows fork. This work does not duplicate those components. It adds Windows runtime verification for shell background, cards, text hierarchy, menus, tooltips, tray menu, and hover/pressed states. Any defect found is fixed in shared tokens/components unless the behavior is genuinely platform-specific.

### 3.7 Build and test conformance

`tools/build-windows.ps1` must delegate builds to `.harness/tools/build.py`, preserving the project harness as the only build entry. The desktop UX static test is corrected to the actual Android manifest location, `android/AndroidManifest.xml`.

New Windows C sources and native tests require CMake registration. Because the relevant CMake and platform-boundary files are frozen, a change proposal is filed before editing them.

## 4. Error handling and safety

- Process snapshot failure: do not renew autonomous activity; retain the last known identity for the current tick.
- Per-process access denied or process exit: skip that process and continue with remaining descendants.
- Counter reset, PID reuse, or negative delta: discard the delta and establish a new baseline.
- Media enumeration failure: provide no media evidence; never fabricate playback.
- Foreground window unavailable: close only after the existing debounce/normalization rules decide the identity is genuinely absent.
- Service shutdown: flush the current foreground and media logical sessions once.

The service remains unprivileged. It does not depend on `powercfg /requests`, elevation, ETW administration, or global process injection.

## 5. Test strategy

Implementation follows test-driven development.

Native deterministic tests cover:

- 32-bit input tick rollover;
- first-sample baseline behavior;
- CPU and I/O delta qualification;
- descendant-process activity;
- 90-second lease renewal and expiry;
- recent input and media overrides;
- process-only/no-delta idleness;
- active → idle → active accumulation in one session;
- identity change and shutdown flush;
- counter reset, process exit, and probe failure.

Static/QML tests cover:

- Windows tray exposes phase, remaining time, start, pause/resume, reset, and open actions;
- tray actions route to the single shared Pomodoro manager;
- Windows build script delegates to the harness;
- desktop UX test uses the real Android manifest path.

Integration verification includes:

1. project build through `.harness/tools/build.py`;
2. native and Python test suites;
3. Windows manual scenarios for Codex/terminal child work, foreground video, true idle, title change, and resume;
4. Windows light/dark UI smoke run followed by Qt log scanning;
5. final `.harness/tools/harness_check.py`.

## 6. Rollout and rollback

No schema migration or one-shot data rewrite is needed. New service sessions remain readable by existing UI code. Rollout is a normal Windows application/service update.

Rollback is a code revert. Records written by the new version remain valid because they use the existing session fields; they may simply contain longer logical spans with explicit idle duration. No database restoration is required.

## 7. Acceptance criteria

- A foreground Codex/terminal task with qualifying child CPU or I/O continues accumulating active time without input.
- A motionless foreground application with no qualifying work becomes idle after 90 seconds.
- Idle and resumed intervals remain one logical session, and idle time is excluded from `active_sec`.
- Foreground media playback overrides input idle, then stops overriding immediately when playback disappears.
- Long-running media is not split by a periodic timer.
- Windows tray controls the existing Pomodoro timer and matches macOS capabilities.
- Shared light UI is usable on Windows with no platform-only duplicate theme.
- Windows builds use the harness, all added/existing targeted tests pass, Qt logs scan clean, and the final harness check passes.
