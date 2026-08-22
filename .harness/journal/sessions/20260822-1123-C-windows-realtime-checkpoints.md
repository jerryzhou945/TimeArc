# Change Proposal — windows-realtime-checkpoints

## Metadata

- Author: Codex `/root`
- Track: **C (Debug)** — fixes an observed Windows freshness and browser attribution defect.
- Date: 2026-08-22 11:23 (local)
- Session goal: Make Bilibili playback and Codex autonomous work appear in SQLite-backed statistics within 60 seconds while leaving Discord behavior unchanged.
- Branch: `codex/stats-daily-prototype`
- Related error reports: `../errors/20260822-032357-C-windows-open-session-realtime-staleness.md`, `../errors/20260822-034839-C-qt-warning-56c05b9bc3.md`

## 1. Frozen files touched

- `CMakeLists.txt` — add focused Windows tracker test sources to the existing Windows test target; production build wiring is unchanged.

## 2. Motivation

Windows leaves foreground and audio sessions only in memory until identity change, absence, or shutdown. Codex and long Bilibili playback therefore look stale for tens of minutes. Existing CTest does not exercise audio checkpoint behavior.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | Test target gains real tracker coverage; production service gains bounded checkpoints in non-frozen platform files. |
| Consumer | No build or disk-contract change; the UI sees new contiguous rows sooner. |

## 4. Migration plan

No on-disk schema or interpretation change. Old long rows and new contiguous checkpoint rows coexist; D5 interval union already handles adjacency.

## 5. Rollback plan

Revert the checkpoint, title-priority, configuration, test, and CMake changes. Existing rows remain valid and require no restoration.

## 6. Test plan

- Pre-change reproduction: current state/audio APIs produce no row while an unchanged session remains open.
- Post-change verification: checkpoint at 60 seconds exports the elapsed segment, resets its counters/start time, preserves logical identity/mode/lease, and audio continues from the boundary.
- New test artifacts: extend `tests/windows_foreground_state_test.c`; add `tests/windows_audio_tracker_test.c`; update Windows configuration/runtime coverage.

## 7. Sign-off

- [x] No rule update required; CHARTER v0.12 already permits checkpoints.
- [x] No charter amendment or version bump required.
- [ ] `state/frozen-files.json` will be regenerated only with maintainer approval after commit.
- [ ] Main README update not required for this bug fix; the diagnosis report documents behavior.

## Outcome

Windows now checkpoints unchanged foreground and audio observations every 60 seconds without changing logical identity. Foreground checkpointing preserves active/idle mode and the Codex work lease; browser audio prefers the matching foreground title so hosted-site markers survive, while native music still keeps GSMTC metadata. Discord sampling was not changed. Six CTests and both Windows static checks pass, and an interactive runtime probe wrote a 60-second row before the foreground identity ended.

The statistics-page runtime scan also exposed an undefined `Cursor.text()`
helper. The search overlay now uses Qt's native `Qt.IBeamCursor`; a static
regression check rejects the invalid helper and the follow-up Qt scan produced
no warning log.
