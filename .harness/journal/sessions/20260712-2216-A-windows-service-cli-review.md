# Windows service CLI review

**Goal.** Inspect the Windows collector lifecycle implementation and describe its command-line interface design without changing product behavior.

**What happened.** Traced argument dispatch, Task Scheduler/HKCU registration, process launch and stop signaling, status output, and the Qt caller integration.

**Outcome.** Read-only review completed; no source, build, or runtime behavior changed.
