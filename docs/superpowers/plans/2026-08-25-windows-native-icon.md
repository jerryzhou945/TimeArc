# Windows Native Icon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed the existing TimeArc brand artwork as a native multi-resolution Windows icon so Explorer, shortcuts, and the taskbar no longer use the generic executable icon.

**Architecture:** Keep `resources/app/TimeArc.svg` as the visual source of truth. Add a generated multi-resolution ICO and a minimal Windows RC file to the GUI target only; retain the existing Qt runtime SVG icon for window-level behavior. Verify both build configuration and the produced PE resource directory.

**Tech Stack:** Qt 6, CMake, MinGW windres, Windows PE resources, Python static tests.

**Spec:** `.harness/journal/sessions/20260825-1317-C-windows-native-icon.md`

## Global Constraints

- Do not change application behavior, database structures, service code, macOS assets, or Android assets.
- Preserve dynamic Qt linkage and current release packaging.
- File the frozen CMake change proposal before editing `CMakeLists.txt`.
- Push through a dedicated branch and target `dev`; leave `main` unchanged.

---

### Task 1: Add a failing Windows icon-resource regression

**Files:**
- Create: `tests/windows_executable_icon_static_test.py`

**Interfaces:**
- Consumes: repository CMake configuration and `resources/bundle/windows/TimeArc.rc`.
- Produces: a static gate requiring a Windows RC source and multi-resolution ICO.

- [x] Write a PE artifact test requiring native icon and group-icon resources.
- [x] Run the test and confirm it fails because the existing executable has no icon resource.

### Task 2: Embed the native icon

**Files:**
- Create: `resources/bundle/windows/TimeArc.ico`
- Create: `resources/bundle/windows/TimeArc.rc`
- Modify: `CMakeLists.txt`
- Modify: `.harness/state/frozen-files.json`

**Interfaces:**
- Consumes: existing `resources/app/TimeArc.svg` branding.
- Produces: Windows `RT_GROUP_ICON`/`RT_ICON` resources linked into `TimeArc.exe`.

- [x] Render the SVG geometry into ICO frames at 16, 24, 32, 48, 64, 128, and 256 pixels.
- [x] Reference the ICO from a minimal RC file.
- [x] Append the RC file to `TIME_ARC_APP_SOURCES` only under `WIN32`.
- [x] Build through `.harness/tools/build.py`.
- [x] Inspect the built executable and confirm its PE contains `.rsrc` and icon resources.

### Task 3: Document, verify, and integrate

**Files:**
- Create: `docs/windows-native-icon-fix-2026-08-25.md`
- Modify: `docs/implementation-backlog.md`
- Modify: `.harness/state/open-issues.md`
- Update: active session/error reports

**Interfaces:**
- Consumes: verified built executable and git diff.
- Produces: auditable release note and a clean PR into `dev`.

- [x] Run focused tests, CTest, linkage verification, and desktop static checks.
- [x] Keep installer execution and icon resources together as one revertible Windows release-readiness fix.
- [ ] Push the feature branch, open a PR targeting `dev`, merge after checks, and delete the feature branch.
- [ ] Confirm `origin/dev` contains the merge and leave `origin/main` unchanged.
