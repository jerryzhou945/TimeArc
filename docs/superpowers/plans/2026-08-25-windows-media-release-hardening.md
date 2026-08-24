# Windows Media Release Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Record playing browser video and connected Discord voice accurately on Windows, validate Codex autonomous foreground work, and hide desktop Memory Recap for the beta.

**Architecture:** Keep the two-process and SQLite contracts unchanged. Extend the existing Windows audio probe with normalized GSMTC playback evidence and a pure session-inclusion policy, while leaving checkpointing and interval-union aggregation intact; gate Memory Recap only at desktop navigation boundaries.

**Tech Stack:** C11, Win32 WASAPI/GSMTC, Qt 6/QML, CTest, Python static UI checks.

**Spec:** `docs/superpowers/specs/2026-08-25-windows-bilibili-media-release-design.md`

## Global Constraints

- Chrome ordinary browsing remains frontmost-only.
- Known GSMTC `Playing` is authoritative for browser media; known non-playing states stop it; unavailable state falls back to audible WASAPI evidence.
- Only Discord receives the active, effectively-unmuted, zero-peak voice allowance.
- Codex must remain frontmost and needs changing official worker CPU/I/O; process presence alone never counts.
- Foreground/media overlap remains an interval union.
- Do not change schema, C ABI, mobile UI, NetEase behavior, checkpointing, or aggregation.
- Preserve all pre-existing uncommitted desktop statistics changes.

---

### Task 1: Lock the Windows media inclusion policy with RED tests

**Files:**
- Modify: `tests/windows_audio_title_policy_test.c`
- Modify after RED: `src/service/windows/platform/audio_win.h`
- Modify after RED: `src/service/windows/platform/audio_win.c`

**Interfaces:**
- Produces: `TimeArcWinPlaybackState` with `UNKNOWN`, `PLAYING`, `NOT_PLAYING`.
- Produces: `int timearc_win_should_record_audio_session(const char *path, int session_active, int muted, float volume, float peak, TimeArcWinPlaybackState playback_state)`.

- [ ] **Step 1: Add literal policy cases before production code**

Declare the wished-for function in the test and add cases asserting:

```c
assert(timearc_win_should_record_audio_session(
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_PLAYING));
assert(!timearc_win_should_record_audio_session(
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    1, 0, 1.0f, 0.7f, TIMEARC_WIN_PLAYBACK_NOT_PLAYING));
assert(timearc_win_should_record_audio_session(
    "C:\\Users\\Tester\\AppData\\Local\\Discord\\Discord.exe",
    1, 0, 1.0f, 0.0f, TIMEARC_WIN_PLAYBACK_UNKNOWN));
assert(!timearc_win_should_record_audio_session(
    "C:\\Apps\\background.exe", 1, 0, 1.0f, 0.0f,
    TIMEARC_WIN_PLAYBACK_UNKNOWN));
```

Add Discord inactive, muted, and zero-volume negatives plus an audible NetEase positive. These catch a wrong browser state branch, an overly broad silent-session allowance, and a regression in the existing audible fallback.

- [ ] **Step 2: Run the required wrapper and observe RED**

Run:

```powershell
.local-python\Python312\python.exe .harness/tools/build.py --track C --topic windows-media-policy-red --session .harness/journal/sessions/20260825-0024-C-windows-bilibili-media-release.md
```

Expected: link failure for the missing policy function; `build.py` records the expected L1 evidence.

- [ ] **Step 3: Implement the minimal pure policy**

Add the enum/signature to `audio_win.h`. In `audio_win.c`, keep path matching case-insensitive and implement this order:

```c
if (is_browser_path(path) && playback_state != TIMEARC_WIN_PLAYBACK_UNKNOWN)
  return playback_state == TIMEARC_WIN_PLAYBACK_PLAYING;
if (is_discord_path(path))
  return session_active && !muted && volume > 0.001f;
return session_active && !muted && volume > 0.001f &&
       peak > TIMEARC_AUDIO_PEAK_THRESHOLD;
```

- [ ] **Step 4: Build and run the focused native test GREEN**

Run the wrapper, then:

```powershell
ctest --test-dir build -R timearc_windows_audio_title_policy_test --output-on-failure
```

Expected: build succeeds and the focused test passes.

### Task 2: Feed real GSMTC playback state into the policy

**Files:**
- Modify: `src/service/windows/platform/audio_win.c`
- Test: `tests/windows_audio_title_policy_test.c`

**Interfaces:**
- Consumes: `TimeArcWinPlaybackState` and the policy from Task 1.
- Produces: cached media metadata containing source, title, artist, and normalized playback state.

- [ ] **Step 1: Add parser RED cases**

Add a wished-for `timearc_win_parse_playback_status()` declaration and literal cases: `Playing` → `PLAYING`; `Paused`, `Stopped`, `Closed` → `NOT_PLAYING`; empty/unknown → `UNKNOWN`. Run the wrapper and expect an undefined-reference RED.

- [ ] **Step 2: Implement the parser and extend GSMTC output**

Change the PowerShell GSMTC query to emit four tab-separated fields:

```powershell
$status = $session.GetPlaybackInfo().PlaybackStatus.ToString()
"$source`t$title`t$artist`t$status"
```

Replace `query_gsmtc_media_title` with a media-info helper that parses and caches the fourth field alongside the existing title. Treat timeout, malformed output, or no app match as `UNKNOWN`.

- [ ] **Step 3: Reorder WASAPI sampling around evidence, not peak**

For each audio control: obtain state/mute/volume/peak and PID/path first; query GSMTC for browser media; call the pure policy; only then construct `AppInfo`. Preserve title selection, deduplication, and COM release paths.

- [ ] **Step 4: Verify parser and policy GREEN**

Run the wrapper and focused CTest again. Mutation check: changing `Playing` to `NOT_PLAYING`, allowing all active silent apps, or letting known `Paused` fall back to peak must fail at least one literal case.

### Task 3: Validate the current Codex process topology without broadening it

**Files:**
- Modify: `tests/windows_foreground_state_test.c`
- Modify only if RED proves a gap: `src/service/windows/platform/process_activity_win.c`

**Interfaces:**
- Consumes: existing `timearc_process_activity_find_codex_roots`, aggregation, delta, and foreground lease behavior.
- Produces: regression coverage for the current packaged desktop topology.

- [ ] **Step 1: Add a current-process fixture**

Model `ChatGPT.exe` foreground family → sibling `codex.exe` → `codex-code-mode-host.exe` → `codex-command-runner-0.149.0-alpha.4.1.exe`. Hand-set counters prove descendants aggregate once; unchanged counters do not renew activity; changing command-runner CPU/I/O does.

- [ ] **Step 2: Run the focused foreground test**

Run the wrapper and:

```powershell
ctest --test-dir build -R timearc_windows_foreground_state_test --output-on-failure
```

Expected: PASS with current code. If it fails, change only the verified family-resolution gap and rerun; do not count background Codex when another app is frontmost.

### Task 4: Hide Memory Recap at every desktop navigation boundary

**Files:**
- Modify: `tests/desktop_ux_static_test.py`
- Modify: `qml/desktop/DesktopAppShell.qml`
- Modify: `qml/desktop/MacMenuBar.qml`

**Interfaces:**
- Produces: `memoryRecapEnabled: false` release gate exposed by the shell.
- Keeps: home route `memorylake` and all recap implementation/data files.

- [ ] **Step 1: Add UI gate RED assertions**

Require the shell to define the false release gate, filter `recap` from bottom navigation, and redirect a disabled `recap` request to `memorylake`; require the macOS menu item to bind visibility/enabled state to the same gate. Run:

```powershell
.local-python\Python312\python.exe tests/desktop_ux_static_test.py
```

Expected: FAIL because the gate is absent.

- [ ] **Step 2: Implement the release gate**

Add one shell property, filter only the bottom recap item, guard `menuNavigateTo("recap")`, and make the `currentPageSource` recap branch return the home page when disabled. Hide the macOS recap menu item through `hostShell.memoryRecapEnabled`. Do not remove `DesktopMemoryLakePage.qml` or `DesktopMonthlyRecapPage.qml`.

- [ ] **Step 3: Run the UI check GREEN**

Run the static test and the existing statistics layout check. Expected: both pass; the home dashboard stays present.

### Task 5: Full release verification and evidence

**Files:**
- Update: `.harness/journal/errors/20260824-163003-C-windows-media-activity-policy.md`
- Update: `.harness/journal/sessions/20260825-0024-C-windows-bilibili-media-release.md`
- Update only if facts changed: `README.md`, `docs/implementation-backlog.md`, `.harness/state/open-issues.md`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: build/test/runtime evidence without changing storage schema.

- [ ] **Step 1: Stop only the known hidden UI/service instances cleanly**

Use the service `--stop` verb, then stop the exact hidden `TimeArc.exe` PID if it still holds the build artifact. Do not kill unrelated processes.

- [ ] **Step 2: Run the required full build and test suite**

```powershell
.local-python\Python312\python.exe .harness/tools/build.py --track C --topic windows-media-release --session .harness/journal/sessions/20260825-0024-C-windows-bilibili-media-release.md
ctest --test-dir build --output-on-failure
```

Also run the Python/Node desktop statistics tests already modified on the branch.

- [ ] **Step 3: Run service/UI smoke and scan logs**

Start the newly built service in the interactive user session, launch the UI through the supported local launcher, and run:

```powershell
.local-python\Python312\python.exe .harness/tools/scan_qt_log.py
```

Expected: no new Qt/QML warning report.

- [ ] **Step 4: Inspect live data without modifying it**

With a Bilibili video playing, query recent `media_sessions` read-only and confirm new Bilibili rows advance at the 60-second checkpoint even through a silent segment; pause and confirm no later interval. Confirm Discord active/silent continues and ends after leaving voice. If interactive playback is unavailable, report this manual smoke as pending rather than claiming success.

- [ ] **Step 5: Close the harness and commit**

Fill error/session root cause, fix, prevention, and outcome; run:

```powershell
.local-python\Python312\python.exe .harness/tools/harness_check.py
git diff --check
```

Commit with a Track C message beginning with `Fix`, preserving unrelated user changes.
