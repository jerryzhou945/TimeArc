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
- [x] **Maintainer approval:** repo owner (Yonezawa-Akane) authorized H5 implementation into PR #42
      on 2026-06-11 ("start H5 contents … go"). Treated as the sign-off; implemented this session.
- [x] `rules/03-data-contract.md` updated: a "Service config (H5)" paragraph documents the
      `idle_threshold_ms` / `track_enabled` keys, the UI→service direction, and key coexistence with
      the D2 `db_path` (shared atomic RMW). A-TRACKPAUSE override recorded there + in the backlog.
- [x] `state/frozen-files.json` — CHARTER.md is frozen; its hash was regenerated via
      `harness_check.py --bootstrap` after the v0.4 amendment (1 hash updated). No service TU was added,
      so `src/service/CMakeLists.txt` stays untouched; harness_check pass 2 clean.
- [x] **CHARTER amended to v0.4** (follow-up 2026-06-11): I1 now names `usage_config.json` as the
      sanctioned UI→service control file, and §5 v0.4 records the idle/track keys + the A-TRACKPAUSE
      supersession as a charter invariant (v0.3 had sanctioned the file's transport; v0.4 records the new
      *control* semantic). `rules/03` tagged `CHARTER` v0.4.
- [x] `README.md` updated (idle/track now real — settings section).

**Status: APPROVED + IMPLEMENTED (H5 S1+S2, PR #42).** idle-timeout + true-pause now reach the service
via `usage_config.json`; the UI dropped the "受限" labels. Verified (artifacts under
`.harness/journal/build-logs/`): real-binary service smoke `20260611-135946-h5-service-smoke.log`
(idle applied / paused = self-exit + no new records / absent = defaults) + `db_smoke`
`20260611-140119-h5-db-smoke.log` (H5 write + bidirectional key-preservation + corrupt-guard) +
settings-card capture (`h5-tracking-1280/1680.png`). **G-CLEAR (delete history) remains deferred** per §7 (append-only; a purge
tool + charter amendment is a separate session if product wants it).
