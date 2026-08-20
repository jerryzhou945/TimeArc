# Error Report - windows-collector-not-running

## Metadata

- Level: **L2**
- Track: **C**
- Topic: windows-collector-not-running
- Recorded: 2026-08-20T00:09:34Z
- Session: `20260820-0805-C-windows-tracking-recovery.md`
- Platform: Windows 11
- Tooling: process/status probes, Git history, service foreground run

## 1. What happened

Windows TimeArc UI runs without time-arc-service after cross-platform startup removal; service database stopped updating on 2026-08-01

## 2. Evidence

```
TimeArc.exe running since 2026-08-20 05:52; time-arc-service absent.
time-arc-service --status: autostart=off, running=no.
timearc_service.db WAL last write: 2026-08-01 08:09:48.
git log -S startUsageService: commit 620f6022 removed the shared helper while replacing macOS startup with LaunchAgent registration.
Manual --start changes status to running=yes, confirming the Windows collector can still launch.
```

The foreground probe also produced `attempt to write a readonly database`
under the managed Codex sandbox. ACL inspection shows `CodexSandboxUsers` has
read/execute only while the interactive Lenovo account has full control, so
that message is an isolated test-environment constraint rather than evidence
of the user's normal desktop token failing to write.

## 3. Root cause

- Immediate cause: launching the Windows UI no longer starts `time-arc-service.exe`.
- Underlying cause: commit `620f6022` removed the cross-platform `startUsageService()` while migrating macOS to a LaunchAgent, unintentionally deleting the Windows branch as well.
- Why the harness/checklists did not prevent it: existing static startup coverage validated the macOS registration path but did not assert the Windows UI-to-service startup contract or a live Windows status transition.

## 4. Fix

- Files changed: pending design approval.
- Short description: pending.
- Commit: pending.

## 5. Prevention

Add a Windows startup regression that requires an app-launch collector trigger and validates the current `service_config.json` path rather than the retired `usage_config.json`.
