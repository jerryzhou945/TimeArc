# Session Log — harmony-safe-start

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-08-02 10:31 → 10:45 (Asia/Shanghai)
- Branch: `codex/harmony-safe-start`
- Baseline commit: `98885e3d`

## Goal

Build a HarmonyOS Zhuoyitong-safe Android APK that reaches the mobile UI even when Android usage APIs or background scheduling are unavailable.

## Plan

- Add a failing static contract for safe startup behavior.
- Delay and guard Android platform initialization.
- Build, verify, and package an arm64-v8a diagnostic APK.

## What actually happened

- 10:31 — Reproduced from the user's Pura 90 Pro report; see [`../errors/20260802-023109-C-harmony-zhuoyitong-startup-exit.md`](../errors/20260802-023109-C-harmony-zhuoyitong-startup-exit.md).
- 10:31 — Created `codex/harmony-safe-start` directly in the main checkout; no worktree was created.
- 10:35 — Initial full Android target exposed the existing service-link failure; see [`../errors/20260802-023615-C-harmony-safe-start.md`](../errors/20260802-023615-C-harmony-safe-start.md).
- 10:36 — Two undersized shell timeouts and a denied CIM diagnostic were recorded in the L3 journal; the detached APK build itself completed successfully.
- 10:39 — Rebuilt the dedicated Android `apk` target after removing the complete AndroidX Startup provider; merged Manifest contains no Startup initializer.
- 10:41 — Windows build and CTest 4/4 passed. Full static checks found one unrelated `origin/dev` macOS build-script expectation failure; see [`../errors/20260802-024133-C-preexisting-macos-build-static-test.md`](../errors/20260802-024133-C-preexisting-macos-build-static-test.md).
- 10:45 — Verified package metadata, arm64-v8a ABI, debug v2 signature, copied the APK to `dist/`, and matched SHA-256 hashes.
- 10:46 — Initial harness audit exceeded the rolling INDEX line budget; trimmed only older index rows and the final 7/7 audit passed. See [`../errors/20260802-024609-C-harness-index-line-budget.md`](../errors/20260802-024609-C-harness-index-line-budget.md).
- 10:47 — Removed trailing whitespace copied into an auto-generated L1 report; see [`../errors/20260802-024743-C-generated-report-trailing-space.md`](../errors/20260802-024743-C-generated-report-trailing-space.md).
- 10:48 — A transient Git index-lock denial cleared on retry; see [`../errors/20260802-024824-C-git-index-lock-safe-start.md`](../errors/20260802-024824-C-git-index-lock-safe-start.md).

## Outcome

**done**

- Completed: Safe-start code, regression contract, Android/Windows builds, APK inspection and distribution artifact.
- Incomplete: Pura 90 Pro physical-device confirmation only.
- Verification: Android APK build passed; Windows build passed; CTest 4/4; relevant static tests passed; merged Manifest and APK metadata inspected; harness audit 7/7.
- Next: Install `TimeArc-1.0-android-arm64-v8a-harmony-safe-debug.apk` through Zhuoyitong and report whether the UI remains open.
- Risks: No direct logcat/HDC trace is available from Zhuoyitong; UsageStats may remain unsupported even if the UI starts.
- Commits landed: None.
- Files touched: Android manifest/Java bridges, QML startup shell, C++ Android/JNI startup path, static test, documentation and journal.
- Frozen files touched: n.
- Follow-ups spun out to `../state/open-issues.md`: Pura 90 Pro physical-device confirmation remains.

## Notes for the next agent

Do not create a worktree; D: space is constrained. The existing macOS build-script static baseline failure is unrelated to this Android fix.
