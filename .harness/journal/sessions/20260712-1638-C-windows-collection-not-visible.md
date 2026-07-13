# Windows service collection not visible

**Goal.** Diagnose why a Windows build runs but automatic service collection is not visible in the UI.

**What happened.** Static inspection found that the service writer's SQLite DDL and every UI service-history query use incompatible column names, and that UI initialization never retries opening a service database which is absent during the startup race. Related error report: `errors/20260712-083856-C-windows-collection-not-visible.md`.

**Outcome.** Live Windows WAL records confirmed the service writer is healthy. Root cause is the UI's obsolete service-schema queries, compounded by a missing-database reopen race; product code remains unchanged and a targeted UI fix is required.
