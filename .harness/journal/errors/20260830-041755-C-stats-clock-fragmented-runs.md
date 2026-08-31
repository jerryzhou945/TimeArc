# Error Report - stats-clock-fragmented-runs

## Metadata

- Level: **L2**
- Track: **C**
- Topic: stats-clock-fragmented-runs
- Recorded: 2026-08-30T04:17:55Z
- Session: (unknown)
- Platform: n-a
- Tooling: (fill in)

## 1. What happened

Category clock still renders too many separate runs; short category switches should be smoothed into a few meaningful time-positioned blocks while exact totals remain unchanged.

## 2. Evidence

Screenshot: `C:/Users/cangc/AppData/Local/Temp/codex-clipboard-74204c9c-d443-497e-b95e-e2a4e59dc509.png`.
The desired behavior existed in commit `9432032`: a half-day was divided into 72 ten-minute buckets, each bucket used its dominant category, one A-B-A bucket was absorbed, and equal neighboring buckets became a solid block.
RED: `node tests/stats_view_model_test.js` reported that `buildSmoothedCategoryClockSegments` was undefined.
GREEN: dominant-bucket, A-B-A, two-bucket-switch, 59/60-second, and PM fixtures pass after restoring that projection.

## 3. Root cause

- Immediate cause: the current page rendered denoised raw runs instead of the former fixed ten-minute category projection.
- Underlying cause: merge commit `def4c0f` selected the later ring implementation and removed `buildSmoothedCategoryClockSegments` from the `9432032` side.
- Why the harness/checklists did not prevent it: tests pinned run denoising but did not pin the historical fixed-bucket display contract.

## 4. Fix

- Files changed: `qml/desktop/pages/StatsViewModel.js`, `tests/stats_view_model_test.js`, `docs/stats-day-category-ring-redesign.md`
- Short description: restore 72 fixed ten-minute buckets per half-day, dominant-category assignment after 60 seconds, one-bucket A-B-A smoothing, and solid coalesced blocks; keep exact totals and current shared category colors.
- Commit: pending commit

## 5. Prevention

Behavioral fixtures now pin dominant mixed buckets, one- versus two-bucket switches, the 59/60-second boundary, PM coordinates, page wiring, and shared color-map wiring; no harness change needed.
