# Session Log - mainstream-site-aggregation

## Metadata

- Agent / Author: Codex
- Track: **C (Debug)**
- Date: 2026-06-14 10:38 -> 10:58 (local)
- Branch: codex/fix-mainstream-site-aggregation
- Baseline commit: dc46830

## Goal

Fix mainstream browser-hosted sites so they are counted as their own `site:*`
activities instead of being absorbed into Chrome or Edge.

Related error report:
[`20260614-023917-C-douyin-xhs-home-missing.md`](../errors/20260614-023917-C-douyin-xhs-home-missing.md).

## What Happened

SQLite evidence showed Douyin and Xiaohongshu foreground sessions existed, but
the UI aggregation could still choose the generic Chrome adapter before the site
catalog. The fix moved browser-hosted site matching into `site_catalog.h` and
made `activityGroupKey()` prefer that match before generic desktop browser
metadata.

## Outcome

Complete. `timearc_db_smoke` now covers Chrome-title site splitting for Douyin
and Xiaohongshu plus a native-app false-positive guard. Target smoke, executable
smoke, and full harness build passed after closing the running local
`build/TimeArc.exe` that was locking the linker output.
