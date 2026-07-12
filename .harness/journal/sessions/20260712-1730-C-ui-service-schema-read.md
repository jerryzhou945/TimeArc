# Fix UI service-history reads

**Goal.** Make the UI read the current service-owned SQLite schema with the smallest consumer-only change.

**What happened.** Updated `UsageStatManager` and the two service-history repositories to read `app_id`, `display_name`, `icon_path`, generated `duration_sec`, and session `rowid`; added late read-only connection opening; changed the existing DB smoke fixture to mirror the authoritative service DDL. Related error: `errors/20260712-083856-C-windows-collection-not-visible.md`.

**Outcome.** `timearc_db_smoke` target and full `time-arc` UI target build successfully. The smoke binary passes the updated real service-schema guard but later hits an unrelated pre-existing legacy-migration assertion; isolated execution of every changed SQL query against the current generated-column schema passes. The service writer and on-disk schema were not changed; Windows runtime confirmation remains for the user.
