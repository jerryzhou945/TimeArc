# Session — H5 service-config channel (idle / true-pause)

- Track: B (Feature)
- Date: 2026-06-11 12:02 (local)
- Branch / PR: `docs/h5-service-config-channel-kickoff` → PR #42 (base `dev`).
- Kickoff: `docs/h5-service-config-channel-kickoff.md`
- Proposal (gate): `.harness/journal/sessions/20260609-0150-B-service-config-proposal.md`

## Gate / sign-off
The proposal was `PROPOSED — awaiting maintainer sign-off`. The maintainer
(repo owner Yonezawa-Akane) explicitly authorized starting H5 and committing
into PR #42 ("start H5 contents … go"). I treat that as the sign-off and record
it in the proposal's §8 + a CHARTER v0.4 amendment (the sanctioned UI→service
disk-config extension).

## Plan
S1 (service · non-frozen `usage_storage.{c,h}`, `usage_tracker.{c,h}`, `main.c`):
- `timearc_read_service_config(int64_t* idle_ms, int* track_enabled)` in
  usage_storage.c (declared in non-frozen usage_storage.h; `data_bridge.h` is
  frozen). Reuses D2's Parson path; reads `idle_threshold_ms` (clamped 1s–24h)
  and `track_enabled` (bool) from `usage_config.json`; only overwrites a
  caller default when the key is present + valid (fail-safe). Refactors the
  config-path build into a shared `make_usage_config_path` helper.
- `TimeArcUsageTrackerConfig` += `int track_enabled` (default **1** in every
  positional initializer — omitted-field zero-init would silently disable
  collection and break backward-compat).
- `main.c` fills config defaults, reads service config to override idle+track,
  echoes applied values to stderr.
- `usage_tracker.c` honors `track_enabled`: when 0, clears the live snapshot and
  returns early (no history / live / audio) → mutex released → `--status
  running=no`. True pause; startup-read, restart to resume (matches idle).

S2 (UI · non-frozen `database_manager.{cpp,h}`, `settings_repository.{cpp,h}`,
`DesktopProfilePage.qml`):
- Refactor D2's `writeDbPathPointer` onto a shared private
  `mergeUsageConfig(updates, removeKeys)` RMW helper; add
  `DatabaseManager::writeServiceConfig(idleMs, trackEnabled)` on the SAME helper
  so the two writers cannot clobber each other's keys (kickoff risk #1, made
  structurally impossible). NOTE deviation from kickoff (which said
  SettingsRepository) — co-locating with the D2 writer is the safer choice.
- `SettingsRepository::startBackgroundCollection()` (`--start`) to pair with the
  existing graceful `stopBackgroundCollection()`.
- QML: idle `onActivated` / track `onToggled` write SQLite AND `writeServiceConfig`;
  new "应用并重启采集" action (stop→start when tracking on, stop when off);
  drop the "（受限）" labels now that idle/track are real.

S3 — decision card: keep deferred (A-CLEAR UI-cache-only). No code.

Governance: CHARTER v0.4 (+frozen hash via `--bootstrap`), rules/03 note,
README idle/track-now-real, backlog §H5 + kickoff status, proposal §8.

## Verify
- Service smoke (real binary, isolated `LOCALAPPDATA` sandbox): idle=300000 +
  track=false → stderr echo + immediate exit + no new jsonl; track=true → stays
  up + idle echo; absent file → compile-time defaults.
- UI: `build.py`, PrintWindow-by-PID capture of the 追踪与应用 card, `scan_qt_log`.
- `harness_check.py` exit 0.

## Follow-up (2026-06-11, `20260611-1401-B-h5-gap-closing-charter-v04.md`)
A post-merge-prep audit closed the gaps this plan asserted: the **CHARTER v0.4** amendment
named above is now actually landed (I1 + §5 v0.4, frozen hash regenerated); the struct uses
**designated** initializers (not positional); write-failure is surfaced in the UI; and the
real-binary service smoke + `db_smoke` + `harness_check` are now artifact-backed
(`build-logs/20260611-135946-h5-service-smoke.log` ALL PASS, `…-140119-h5-db-smoke.log` exit 0,
`…-140135-h5-harness-check.log` clean).
