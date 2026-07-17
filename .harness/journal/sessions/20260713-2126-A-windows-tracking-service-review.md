# Windows tracking service review

**Goal.** Trace and explain the current Windows tracking service behavior without changing product code or observable behavior.

**What happened.** Traced entry-point lifecycle, startup-only configuration, foreground and audio sampling, SQLite writes, UI launch behavior, legacy autostart controls, and graceful shutdown against the current source.

**Outcome.** Read-only review completed; no product source, build, runtime, or observable behavior changed.
