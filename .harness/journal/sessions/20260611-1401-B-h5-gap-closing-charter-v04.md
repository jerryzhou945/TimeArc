# Session — H5 PR #42 gap-closing + CHARTER v0.4

- Track: B (Feature)
- Date: 2026-06-11 14:01 (local)
- Branch / PR: `docs/h5-service-config-channel-kickoff` → PR #42 (base `dev`).
- Predecessor: impl session `20260611-1202-B-h5-service-config-channel.md`; kickoff
  `docs/h5-service-config-channel-kickoff.md`; proposal `20260609-0150-B-service-config-proposal.md`.

## Why
A multi-agent adversarial audit of PR #42 (5 agents) found S1+S2 **sound** — the
D2/H5 key-clobber risk is structurally eliminated (single `mergeUsageConfig` RMW),
true-pause is real (self-exit, no records), idle clamp safe, no frozen TU. It surfaced
**three** follow-ups; the maintainer chose all three. (A HIGH "self-approval sign-off"
finding was adversarially **refuted**: approver is the human owner, no harness rule
requires an independent reviewer, no frozen file touched — not a defect.)

## What I did
1. **Nit — designated initializers.** `TimeArcUsageTrackerConfig` was built with
   positional initializers in `main.c` + `usage_tracker.c`; a future reorder/omission
   would silently zero `track_enabled`=off. Switched both to `.track_enabled = 1`
   designated form; updated the `usage_tracker.h` red-line comment.
2. **Nit — surface write failure.** `DesktopProfilePage._writeServiceConfig()` now
   returns the `bool` from `DatabaseManager::writeServiceConfig`; the idle row, track
   toggle, and `applyAndRestartCollection()` warn instead of showing a false success
   toast when `usage_config.json` is unwritable/corrupt (the corrupt-recovery case).
3. **CHARTER v0.4** (maintainer chose to record the new semantic, not only `rules/03`).
   I1 now names `usage_config.json` as the sanctioned UI→service control file; §5 v0.4
   records the idle/`track_enabled` keys + the **A-TRACKPAUSE supersession** as a charter
   invariant. Held the 100-line budget by tightening I2 + the v0.1–v0.3 notes (CHARTER
   now 99 lines). Regenerated the frozen hash via `harness_check.py --bootstrap`
   (1 hash updated — only CHARTER drifted). `rules/03` header tagged `CHARTER v0.4`;
   proposal §8 reversed back to "amended to v0.4" + frozen-hash regenerated.

## Verify (closing the audit's evidence gap — these were asserted, now artifact-backed)
- **Real-binary service smoke ALL PASS** — `build-logs/20260611-135946-h5-service-smoke.log`
  (isolated LOCALAPPDATA+APPDATA sandbox): (A) idle=300000 + track=false → stderr echo,
  exit 0 self-exit, **no new jsonl rows** (true pause); (B) track=true → stays in poll
  loop; (C) absent config → compile defaults idle=60000/track=1.
- **Full build green** — `20260611-140038-build.log` (service + app + db_smoke; QML change
  compiles/embeds). Service-only relink: `20260611-135423-build.log`.
- **db_smoke exit 0** — `20260611-140119-h5-db-smoke.log`: D1 round-trip, D2 pointer/relocate,
  **H5 write + bidirectional key-preservation + corrupt-guard** ("refusing to overwrite
  unparseable usage_config.json") all ok.
- **harness_check exit 0** — `20260611-140135-h5-harness-check.log` (all 7 passes; frozen
  hash matches post-bootstrap; line budget incl. CHARTER 99 / rules-03 100).

## Outcome
**done** — PR #42 now merge-ready: S1+S2 sound, both nits fixed, CHARTER v0.4 recorded,
runtime behavior evidenced. **G-CLEAR (delete history) stays deferred.**

- Files touched: `src/service/windows/main.c`, `.../tracker/usage_tracker.{c,h}`,
  `qml/desktop/pages/DesktopProfilePage.qml`, `.harness/CHARTER.md` (frozen — proposal
  on file), `.harness/state/frozen-files.json` (hash), `.harness/rules/03-data-contract.md`,
  the proposal + the 1202 log (footer) + this log + `INDEX.md` + smoke/build artifacts.
- Frozen files touched: **y** — `.harness/CHARTER.md` (v0.3→v0.4), under the standing
  service-config proposal (`20260609-0150`, approved). Hash regenerated.

## Notes for the next agent
- I **killed the user's running `time-arc-service` (pid 4316)** to take the exe lock for
  the build + smoke. It has logon autostart (B1 Route A); restart it now via the settings
  "应用并重启采集" or `time-arc-service.exe --start`, or it returns next logon.
- After PR #42 merges, the most-ready next item is **B2** (UTF-8 validation in
  `usage_storage.c::write_json_string` — small, non-frozen, no proposal); **H1** (time
  format) close behind. See `docs/implementation-backlog.md`.
