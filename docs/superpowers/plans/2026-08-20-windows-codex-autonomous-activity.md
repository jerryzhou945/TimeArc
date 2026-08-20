# Windows Codex Autonomous Activity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Windows Codex foreground sessions active while its command workers produce meaningful CPU/I/O, while an open but inactive Codex still becomes idle.

**Architecture:** Preserve the existing foreground PID-tree probe and bounded 90-second work lease. For the installed OpenAI Codex desktop package only, locate the related `codex.exe` backend under the same desktop-app process family and add only that backend subtree's changing CPU/I/O counters; process existence alone remains insufficient evidence.

**Tech Stack:** C11, Win32 Toolhelp/process APIs, CTest, PowerShell release tooling.

**Spec:** User-approved design in the 2026-08-20 Codex task; portable work-evidence contract in `.harness/rules/02-platform-boundaries.md` §2.4.

## Global Constraints

- Work directly in `D:/TimeArc/time-arc`; do not create a worktree.
- Do not modify frozen CMake, ABI, database, or schema files.
- Do not treat an existing process as activity; require CPU or I/O delta.
- Keep the existing 90-second bounded lease and generic behavior for non-Codex apps.
- Build only through `.harness/tools/build.py`.

---

### Task 1: Reproduce the sibling-tree gap with unit tests

**Files:**
- Modify: `tests/windows_foreground_state_test.c`
- Modify: `src/service/windows/platform/process_activity_win.h`

**Interfaces:**
- Consumes: synthetic `TimeArcProcessEntry` snapshots.
- Produces: a test-facing resolver that selects related Codex worker roots without using process existence as activity.

- [x] **Step 1: Add a failing Codex process-family test**

  Model `ChatGPT.exe` as the foreground branch and `codex.exe -> pwsh.exe -> command-runner.exe` as its sibling branch. Assert that the selected counters include foreground plus the Codex backend subtree but exclude an unrelated sibling.

- [x] **Step 2: Add an idle counter test**

  Feed identical combined counters twice and assert the second delta is inactive; then add meaningful worker CPU/I/O and assert activity.

- [x] **Step 3: Run the focused Windows test and verify RED**

  Run the configured `windows_foreground_state_test` target. Expected: compile/assertion failure because related-worker aggregation does not exist.

### Task 2: Implement the minimal Codex-related work probe

**Files:**
- Modify: `src/service/windows/platform/process_activity_win.h`
- Modify: `src/service/windows/platform/process_activity_win.c`
- Modify: `src/service/windows/tracker/usage_tracker.c`

**Interfaces:**
- Consumes: foreground PID plus its executable path and Toolhelp snapshot entries.
- Produces: combined counters from the foreground subtree and eligible Codex command subtree.

- [x] **Step 1: Extend snapshot entries with executable basename**

  Copy `PROCESSENTRY32W.szExeFile` into a fixed-size entry field for family selection.

- [x] **Step 2: Resolve the Codex family conservatively**

  Activate the sibling rule only when the foreground executable path belongs to the `OpenAI.Codex_` Windows package and the family contains `codex.exe`. Select its subtree, not every Electron/ChatGPT sibling.

- [x] **Step 3: Aggregate changing counters, never presence**

  Combine counter totals and continue using `timearc_process_activity_delta`; unchanged totals yield no autonomous evidence.

- [x] **Step 4: Run the focused test and verify GREEN**

  Expected: all Windows foreground-state assertions pass.

### Task 3: Verify, package, and publish the test-release audit

**Files:**
- Modify: `.harness/journal/errors/20260820-152419-C-windows-codex-sibling-activity.md`
- Modify: `.harness/journal/sessions/20260820-2321-C-windows-codex-autonomous-activity.md`
- Modify: `.harness/state/open-issues.md`
- Modify: `docs/implementation-backlog.md`
- Create: `docs/windows-test-release-audit-2026-08-20.md`
- Regenerate: `dist/TimeArc-0.1-win64.zip` (untracked release artifact)

**Interfaces:**
- Consumes: verified binaries and Git/GitHub state.
- Produces: reproducible test ZIP, checksum, and prioritized known-issues report.

- [x] **Step 1: Run the full harness build and tests**

  Use `.harness/tools/build.py`, CTest, relevant Python tests, and a packaged executable smoke test.

- [x] **Step 2: Run idle-versus-command runtime verification**

  Confirm an inactive Codex worker snapshot does not renew work and an executing worker does. Record limitations if automation cannot observe the foreground window reliably.

- [x] **Step 3: Regenerate and inspect the Windows ZIP**

  Run `tools/package-release.ps1`, verify linkage, executable presence, signatures, and SHA-256.

- [x] **Step 4: Update release audit and tracking docs**

  List blockers, acceptable beta warnings, macOS parity facts, rollback path, and deferred work.

- [x] **Step 5: Run `harness_check.py` before commit**

  Expected: all passes clean; then stage only scoped files and commit the fix.
