# Session Log — macos-tracking-probes

## Metadata

- Agent / Author: Codex
- Track: **B (Feature)**
- Date: 2026-07-18 20:08 → 20:13 (local)
- Branch: development/macos-support
- Baseline commit: aec4316

## Goal

Implement the macOS tracking port protocols in their corresponding `*Probe.swift` files without changing non-probe production files.

## Plan

- Compare each protocol and probe stub with the existing macOS implementations.
- Implement only the six corresponding probe source files.
- Build through the harness and run focused structural checks.

## Service side

The macOS service will obtain idle time, frontmost-app metadata, window titles, application metadata, media type, and media title through concrete probe adapters while preserving the existing state-machine and SQLite bridge contracts.

## UI side

The UI continues consuming the same service-owned SQLite records; this probe implementation does not change schemas, fields, paths, or UI behavior.

## Rule-file impact

No rule-file updates are expected because the change fills existing macOS platform ports without changing architecture, platform obligations, or the disk contract. Frozen files, CMake files, protocol/coordinator/state-machine files, and UI files remain untouched.

## What actually happened

- 20:08 — Preflight passed and the existing dirty macOS refactor was identified as user work to preserve.
- 20:08 — Recorded an L3 report for an inspection command that used shell control operators: [`../errors/20260718-120844-B-chained-read-command.md`](../errors/20260718-120844-B-chained-read-command.md).
- 20:09 — Recorded an L3 report after a multi-file line-range inspection produced misleading output: [`../errors/20260718-120921-B-concatenated-sed-range.md`](../errors/20260718-120921-B-concatenated-sed-range.md).
- 20:09 — Baseline build was blocked before Swift compilation by the existing stale CMake path for moved macOS sources: [`../errors/20260718-120959-B-macos-tracking-probes-baseline.md`](../errors/20260718-120959-B-macos-tracking-probes-baseline.md).
- 20:11 — The first focused Swift typecheck was blocked by the default cache sandbox and active SDK/toolchain mismatch: [`../errors/20260718-121148-B-swift-probe-typecheck.md`](../errors/20260718-121148-B-swift-probe-typecheck.md).
- 20:12 — Focused typecheck passed using the installed macOS 15.4 SDK and a writable temporary module cache.
- 20:13 — Final harness check exposed the rolling index at 104 lines; the error was recorded, five already-omitted historical rows were trimmed, and the rerun passed: [`../errors/20260718-121331-B-harness-index-line-budget.md`](../errors/20260718-121331-B-harness-index-line-budget.md).

## Outcome

**done**

- Commits landed: none
- Files touched: `AppInformationProbe.swift`, `FrontmostAppProbe.swift`, `InputActionProbe.swift`, `MediaTitleProbe.swift`, `MediaTypeProbe.swift`, `WindowTitleProbe.swift`, plus mandatory harness session/error records
- Frozen files touched: no
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

The probe set typechecks, but the full build remains blocked by pre-existing stale macOS source paths in the frozen service CMake manifest; it was intentionally left unchanged to honor the requested scope.
