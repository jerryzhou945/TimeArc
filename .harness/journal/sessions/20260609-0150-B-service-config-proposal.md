# Change Proposal — service-config-file

> Filed per CHARTER before any service/contract change. Covers settings items that
> cannot be honestly implemented UI-only: G-IDLE, G-TRACK (true pause), G-CLEAR.

## Metadata
- Author: Claude Code (Opus 4.8, ultracode)
- Track: B (Feature)
- Date: 2026-06-09 01:50 (local)
- Session goal: Propose a UI→service disk-config channel so idle-timeout / tracking-pause
  settings reach the service, and decide history-deletion policy — without bypassing the
  disk contract.
- Branch: feat/settings-page-dark-glass
- Related: docs/settings-remaining-work.md (§二 D-9/10); settings-implementation-issues.md
  G-IDLE / G-TRACK / G-CLEAR; product decision A-TRACKPAUSE.

## 1. Frozen files touched
- **none directly.** The read path uses NON-frozen service files: `src/service/windows/main.c`,
  `src/service/windows/tracker/usage_tracker.{c,h}` (idle `#define` at usage_tracker.h:7).
- Filed anyway because it **extends the disk contract** (adds a new UI→service direction) and
  would **override A-TRACKPAUSE** (which chose UI-approximation) — both warrant sign-off.
- If a NEW service `.c/.h` is added → `src/service/CMakeLists.txt` (FROZEN) is touched → that
  variant strictly requires this proposal.

## 2. Motivation
`idle_timeout` and `track_running` currently only persist + UI-approximate; the service ignores
them (idle is the compile-time `TIMEARC_USAGE_IDLE_THRESHOLD_MS`; the service keeps sampling even
when the UI "pauses"). `删除历史` cannot delete (append-only). Users expect real effect.

## 3. Impact on the other process
| Side | Effect |
|------|--------|
| Producer (service) | `main.c` reads `<usageDir>/usage_config.json` at startup; applies `idle_threshold_ms` + `track_enabled` into the already-supported `TimeArcUsageTrackerConfig`; when `track_enabled=false`, skips writing new usage records. No schema change to `usage_records.jsonl`. |
| Consumer (UI) | Settings writes `usage_config.json` (UI→service, **disk-only — no IPC/socket/shm**, honors I1). Small JSON writer on a non-frozen `.cpp` (or reuse SettingsRepository). |

This is a **new data direction (UI→service)** — disk-based but a deliberate contract extension.

## 4. Migration plan
No on-disk impact to existing records. `usage_config.json` is new + optional: absent → service
uses compile-time defaults (today's behavior). Fully backward compatible.

## 5. Rollback plan
Delete `usage_config.json` or revert the service read code → service reverts to `#define`
defaults. `track_enabled=false` only **pauses** new sampling; it never deletes → no data to
restore.

## 6. Test plan
- Pre: idle fixed at 60s; UI pause hides records in UI but service keeps writing.
- Post: write `usage_config.json {idle_threshold_ms:300000, track_enabled:false}`; restart
  service; verify (a) idle uses 300s, (b) no new records while paused, (c) absent file → defaults.
- Artifacts: sample `usage_config.json`; service smoke covering config-read.
- **NOTE:** requires the SERVICE build/test pipeline (separate native process); NOT verifiable in
  the UI qml build loop → must be done by whoever builds the service.

## 7. Delete-history (G-CLEAR) — decision needed (NOT proposing a JSONL rewrite)
`usage_records.jsonl` is append-only (I2/D1). True deletion requires EITHER a CHARTER §2 amendment
(define delete/rotation policy) OR a stop-service + external purge/migration tool. Recommend
keeping A-CLEAR (UI-private cache only) unless product wants a purge tool. A JSONL rewrite is
rejected (breaks the append-only invariant + incremental readers).

## 8. Sign-off
- [ ] `rules/*.md` updated (new service-config rule) if approved.
- [ ] `CHARTER.md` notes the UI→service config channel as a sanctioned disk extension; records
      that idle/track override A-TRACKPAUSE.
- [ ] `state/frozen-files.json` regenerated if any frozen file ends up touched.
- [ ] `README.md` updated (idle/track now real) if implemented.

**Status: PROPOSED — awaiting maintainer sign-off. NOT implemented in this PR;** the UI keeps the
honest soft-pause + "受限" labels until approved.
