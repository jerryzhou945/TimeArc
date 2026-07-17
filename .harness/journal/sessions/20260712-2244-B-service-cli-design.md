# Service CLI design

**Goal.** Specify the proposed next-generation `time-arc-service` command-line interface without implementing or changing runtime behavior.

**Service side.** The future service will expose explicit lifecycle, collector-autostart, status, configuration-validation, and diagnostic commands with stable text/JSON output, documented exit codes, idempotency, and compatibility aliases.

**UI side.** The Qt UI will consume versioned JSON status rather than substring-matching text; application autostart remains UI-owned and distinct from collector-only autostart exposed by the service CLI.

**Scope.** Touch `src/service/CLI.md` and this session record only. Do not touch service source, shared contracts, CMake, platform rules, the existing service README, or the user's macOS worktree changes. No rule file or schema update is required for a design-only document; no baseline build is needed because nothing is compiled.

**Outcome.** Added the proposed CLI contract, command semantics, output schemas, exit codes, platform mapping, and migration policy. `git diff --check` passed. The final harness audit is blocked only by pre-existing untracked macOS source files lacking a rules/README update; recorded as `20260712-144650-B-cli-doc-harness-drift.md`. Documentation only; implementation and runtime verification remain future work.
