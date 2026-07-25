# Session Log — release-bundle-architecture-review

## Metadata

- Agent / Author: Codex
- Track: **A (Stabilize)**
- Date: 2026-07-25 20:13 → 20:32 (local)
- Branch: development/macos-support
- Baseline commit: da6ecdc

## Goal

Review the release design, then reorganize existing resources and update their references without changing product behavior.

## Plan

- Inventory the CMake target, install, deployment, signing, and packaging design.
- Compare current platform paths with Qt deployment and native service requirements.
- Reorganize the resource tree, update its manifest and consumers, and verify the build.

## What actually happened

- 20:13 — Started a read-only Track A architecture review; preserved pre-existing untracked icon assets.
- 20:18 — Audited the target graph, platform selection, install rules, Windows packaging script, Android package source, and service startup paths.
- 20:23 — Inspected the current macOS build artifact: arm64-only, Homebrew Qt references, placeholder bundle ID, no icon/helper embedding, and ad-hoc signing.
- 20:30 — Compared the design with current Qt deployment, Android packaging, Apple Service Management/notarization, CPack, and AppImage guidance.
- 20:38 — Audited the 22 MB `resources/` tree, its qrc registrations, runtime consumers, unregistered native icons, and apparently unused artwork.
- 20:42 — Baseline harness build passed.
- 20:44 — Moved all existing resources into `app/`, `features/`, `legal/`, and `bundle/` categories and updated CMake/runtime/documentation paths.
- 20:45 — Mobile static checks passed; desktop static test hit a pre-existing manifest-path defect, see [`../errors/20260725-124502-A-desktop-static-manifest-path.md`](../errors/20260725-124502-A-desktop-static-manifest-path.md).
- 20:45 — Build polling lost its yielded session handle while the build continued, see [`../errors/20260725-124545-A-build-poll-session-handle.md`](../errors/20260725-124545-A-build-poll-session-handle.md).
- 20:48 — Incremental harness build and CTest passed.
- 20:48 — Initial harness check exposed Markdown line-budget drift, see [`../errors/20260725-124830-A-resource-reorg-harness-line-budget.md`](../errors/20260725-124830-A-resource-reorg-harness-line-budget.md); compacted the rolling index and active resource rule.
- 20:49 — Final harness check passed.

## Outcome

**done**

- Commits landed: none
- Files touched: resource assets and manifest; resource consumers in C++/QML/tests; packaging script; active documentation and resource rules; harness journal
- Frozen files touched: n
- Follow-ups spun out to `../state/open-issues.md`: none

## Notes for the next agent

Resources now use one tree with `app/`, `features/`, `legal/`, and `bundle/`. The qrc shipping set is unchanged; bundle inputs remain outside qrc. Build, mobile static checks, CTest, and the final harness audit pass. The unrelated desktop static test still references the wrong Android manifest location.
