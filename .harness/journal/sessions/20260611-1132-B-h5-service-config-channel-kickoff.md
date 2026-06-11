# Session Log — h5-service-config-channel-kickoff

> H5 kickoff/execution-plan authored. Planning only — no implementation code, no
> service/UI behavior change. H5 stays gated on the (already-filed) change proposal.

## Metadata

- Agent / Author: Claude (Opus 4.8) + maintainer
- Track: **B (Feature)** — H5 turns the设置页 honest soft-pause labels (G-IDLE /
  G-TRACK) into real service-side effect, and decides G-CLEAR.
- Date: 2026-06-11 11:32 → (local)
- Branch: sync/contribution-20260610
- Baseline: D2 S1+S2 landed (PR #41); D1 (PR #40), A1 (PR #38) merged.

## Goal

Expand `docs/implementation-backlog.md §H5` from a backlog line into a dependency-aware,
per-session execution plan — referencing the docs, past PRs (D1/D2), and the filed
service-config change proposal — **without touching any code**.

## What actually happened

- Read the inputs: backlog §H5 (line 128); the filed change proposal
  `20260609-0150-B-service-config-proposal.md` (**PROPOSED — awaiting sign-off**, covers
  G-IDLE / G-TRACK / G-CLEAR, extends the disk contract UI→service, overrides A-TRACKPAUSE);
  D2 kickoff + session logs (`20260610-1620/1705/1730/1824`).
- **Key finding — D2 already built every primitive H5 needs** (why H5 is now cheap):
  (1) fixed `usage_config.json` in the usage dir; (2) service reads it via vendored **Parson**
  (`usage_storage.c::read_config_db_path`, zero CMake change); (3) UI atomic RMW writer
  (`DatabaseManager::writeDbPathPointer`, QSaveFile + key-preserving); (4) service lifecycle
  control (`SettingsRepository::stopBackgroundCollection` / `--start` via `runServiceVerb`)
  so the UI can "write config → restart collection → take effect now".
- **Key fact — `TimeArcUsageTrackerConfig` already carries `idle_threshold_ms`** (non-frozen
  `usage_tracker.h`); `main.c` fills it from a `#define` today. So idle wiring = `main.c` reads
  config into that existing field — **tracker untouched**. Track pause needs one new field
  `track_enabled` on the same (non-frozen) struct → skip persistence when false (true pause).
- Authored `docs/h5-service-config-channel-kickoff.md` (D2/D1-style, 7 sections): staging
  S1 (service reads config → applies idle/track, fail-safe defaults) → S2 (UI writes config +
  wires the设置页 selumn/toggle + "apply & restart" + drops the「受限」labels) → S3 (G-CLEAR
  decision card — default deferred; no JSONL rewrite). File redlines, invariants, risk register.
- Synced `implementation-backlog §H5` `[ ]`→`[~]` + kickoff link. README §78 left as-is: its
  "honest placeholders" prose stays accurate while H5 is gated (no roadmap checkbox to flip).

## Outcome

**done** (kickoff/plan only; H5 implementation gated — see kickoff §1 + §3).

- Files touched: `docs/h5-service-config-channel-kickoff.md` (new), this session log (new),
  `docs/implementation-backlog.md` (§H5 marker + link).
- Frozen files touched: **n**. (S1 is engineered to stay on non-frozen TUs — folds into
  `usage_storage.c` / `main.c` / `usage_tracker.{c,h}`; a NEW service `.c/.h` would touch the
  frozen `src/service/CMakeLists.txt` and is forbidden.)
- Follow-ups: **get the change proposal signed off** before any S1 code — it extends the disk
  contract (UI→service) and overrides A-TRACKPAUSE. D2's `db_path` and H5's
  `idle_threshold_ms`/`track_enabled` share `usage_config.json` → both writers MUST RMW-preserve
  the other side's keys.

## Notes for the next agent

- Do NOT start S1 code until the service-config proposal is signed. The proposal is the gate,
  not the kickoff.
- Unit mismatch trap: UI `idle_timeout` is **minutes**, service wants **ms** ("5"→300000) —
  convert + clamp on both sides.
- `track_enabled=false` is a **pause of new sampling**, never a retro-delete. Append-only
  (I2/D1) holds. True G-CLEAR deletion would need a CHARTER §2 amendment or a stop-service purge
  tool — out of scope unless product asks.
- Verification is **service-side** (real `time-arc-service.exe` smoke, like D2) — the UI qml
  loop cannot verify the producer process.
