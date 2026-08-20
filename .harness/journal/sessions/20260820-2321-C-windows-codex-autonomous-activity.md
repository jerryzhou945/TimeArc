# Session Log — windows-codex-autonomous-activity

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-08-20 23:21 → 23:52 (Asia/Shanghai)
- Branch: `codex/windows-tracking-parity`
- Baseline commit: `fda13258`

## Goal

Fix Windows Codex autonomous command timing without counting an open but inactive Codex process as active, then produce a test-release audit and refreshed Windows package.

## Plan

- Reproduce the foreground/worker sibling-tree gap with a failing unit test.
- Implement conservative Codex worker-subtree CPU/I/O evidence and verify idle behavior.
- Build, test, package, audit, and commit the scoped release candidate.

## What actually happened

- 23:23 — confirmed the foreground UI and command backend live in sibling process branches; see [`../errors/20260820-152419-C-windows-codex-sibling-activity.md`](../errors/20260820-152419-C-windows-codex-sibling-activity.md).
- 23:23 — non-admin CIM inspection was denied and retried read-only with approval; see [`../errors/20260820-152317-C-codex-process-tree-cim-access.md`](../errors/20260820-152317-C-codex-process-tree-cim-access.md).
- 23:24 — bundled `rg.exe` execution was denied; PowerShell search fallback used; see [`../errors/20260820-152408-C-bundled-rg-access-denied.md`](../errors/20260820-152408-C-bundled-rg-access-denied.md).
- 23:25 — GitHub API audit needed approved network access; see [`../errors/20260820-152558-C-github-api-sandbox-network.md`](../errors/20260820-152558-C-github-api-sandbox-network.md).
- 23:29 — corrected a PowerShell session-log read pipeline; see [`../errors/20260820-152923-C-recent-session-pipeline.md`](../errors/20260820-152923-C-recent-session-pipeline.md).
- 23:33 — completed valid RED→GREEN cycles for multi-root aggregation, packaged-family detection and case-insensitive paths; Release assertions are active.
- 23:37 — isolated UI/service smoke initially hit the existing global UI instance, then passed after closing it; see [`../errors/20260820-153750-C-windows-service-runtime-smoke.md`](../errors/20260820-153750-C-windows-service-runtime-smoke.md).
- 23:47 — code review found first-match multi-backend risk; added a failing two-backend test and collected every qualifying Codex root.
- 23:50 — final harness build, CTest 4/4 and all Python test scripts passed.
- 23:51 — generated and smoke-tested `TimeArc-0.1.0-alpha.3-win64.zip`; final SHA-256 recorded in the release audit.
- 23:54 — real foreground/service shutdown added one session (8,830 → 8,831) without reading title data; Qt log scan had no new log.
- 23:55 — full harness check clean after compacting `open-issues.md` to its line budget.

## Outcome

**done**

- Completed: Codex sibling/multi-backend activity fix, Release assertion repair, review, full local verification, package and release audit.
- Incomplete: Git commit/PR/merge and external 24-hour/manual idle soak.
- Verification: harness build; CTest 4/4; all Python test scripts; final packaged UI/service runtime smoke; linkage and SHA-256 checks.
- Next: harness check, scoped commit, then publish through PR when authorized.
- Risks: unsigned portable ZIP; real idle + 90-second soak remains manual; no build/test CI.
- Commits landed: None.
- Files touched: Windows process probe/tracker test plus release/audit/harness documentation.
- Frozen files touched (n): no.
- Follow-ups spun out to `../state/open-issues.md`: signing, installer/update, clean-machine QA, build/test CI and advanced Windows config.

## Notes for the next agent

Mac uses evidence-based idle overrides (audio/sleep assertion). The Windows equivalent remains evidence-based CPU/I/O with a bounded lease; never whitelist process presence.
