# Change Proposal — service-config-v1

## Metadata

- Author: Claude (Claude Code), for maintainer sign-off
- Track: **B (Feature)** — extends the UI→service disk control contract.
- Date: 2026-08-05 21:43 (local)
- Session goal: approve the redesigned service configuration format
  (`service_config.json` v1) and update every document that states the old
  format as fact. **Documentation only — no code changes in this session.**
- Branch: `feature/config-redesign`
- Related error reports: none

## 1. Frozen files touched

- `.harness/CHARTER.md` — I1/I2 wording + new §5 version entry (v0.13).

Touched later, by the implementation session: `src/service/shared/database_path.{c,h}`
(config path + `db_dir` → `database.dir`), and `src/service/CMakeLists.txt` only if
the new reader lands as its own translation unit.

## 2. Motivation

`usage_config.json` is a flat three-key object (`db_dir`, `idle_threshold_ms`,
`track_enabled`) read by two independent parsers, with no version field and no
room for the collection controls the product needs. Failures it causes today:

- **Unit drift.** The UI stores minutes, the file stores ms, `src/service/README.md`
  specifies seconds. Already logged as risk #2 in `docs/h5-service-config-channel-kickoff.md` §5.
- **No sub-switches.** "Frontmost on, media off" is not expressible, although
  the macOS coordinator already has `enableFrontmost`/`enableMedia`.
- **Unbounded session loss.** Records are written only when a session ends
  (`usage_tracker.c:134-147`), so an unclean shutdown discards the entire open
  session. Nothing in the current format can bound that.
- **No version.** No safe way to change a key's meaning or unit.

The approved v1 format is specified in `src/service/README.md` §Configuration
File. This proposal records the decision and the overlap plan; it does not
claim the format is implemented.

## 3. Impact on the other process

| Side        | Effect                                                        |
|-------------|---------------------------------------------------------------|
| Producer    | Service reads the new path/keys, falls back to the legacy file during the overlap. New knobs: poll period, min/max session, frontmost & media sub-switches. Still startup-read, still disk-only (I1 holds). |
| Consumer    | UI writes only the new file; patches individual leaves so unknown keys survive. Minutes→seconds conversion moves to the UI edge. `database.dir` replaces the `db_dir` pointer; the UI still never writes the DB itself. |

## 4. Migration plan

Old records: `<config base>/TimeArc/usage/usage_config.json`, no
`schema_version`, keys `db_dir` / `idle_threshold_ms` / `track_enabled`.

New records: `<config base>/TimeArc/config/service_config.json`, `schema_version: 1`,
nested `tracking` / `database` sections. On Windows the root also moves from
`%LOCALAPPDATA%` to `%APPDATA%`.

Coexistence (one release minimum, per `rules/03` §3):

| Key | Maps to | Transform |
|---|---|---|
| `db_dir` | `database.dir` | verbatim |
| `idle_threshold_ms` | `tracking.frontmost.idle_threshold_sec` | `round(ms/1000)`, clamp 0-86400 |
| `track_enabled` | `tracking.enabled` | verbatim |
| `db_path` | — | already retired; ignored |

The reader tries the new path first and falls back to the legacy path. The
importer never writes the legacy file, so a rollback finds it intact. If both
exist, the new file wins outright — no key-level merge. No `timearc_service.db`
record is reinterpreted, so **history needs no migration**. Sharpest edge: a
stale `300000` read as seconds is a 3.5-day idle threshold that fails silently.
Guards — the key name changes, the 0-86400 range clamps visibly, and validation
fails if `idle_threshold_ms` appears in a v1 document.

## 5. Rollback plan

Code revert is sufficient. The legacy file is never modified or deleted by the
new writer, so reverting restores the old channel with its values intact. No
data restore is needed: no history record changes shape.

## 6. Test plan

- Pre-change reproduction: write `idle_threshold_ms: 90000` — the service
  rejects it and silently keeps 60s (`service_config.c:72-79`).
- Post-change verification: reader unit cases (absent / `{}` / out-of-range /
  wrong type / unknown keys / legacy mapping / corrupt→defaults); real-binary
  smoke (idle applied, `tracking.enabled:false` writes nothing, both
  sub-switches false exits 0, max_session_sec splits a long session into
  contiguous rows); `db_smoke` key-preservation round trip.
- New test artifacts: config-reader unit cases; `TIMEARC_SERVICE_CONFIG`
  redirect so tests stop writing into the real user profile.

## 7. Sign-off

- [x] `rules/*.md` updated: `03-data-contract.md` (config channel + migration),
      `02-platform-boundaries.md` (stale macOS helper description).
- [x] `CHARTER.md` version bumped — v0.13.
- [x] `state/frozen-files.json` regenerated (`harness_check.py --bootstrap`, 1 hash).
- [x] Main `README.md` updated (Data Location, Configuration, service section).
- [x] **Maintainer sign-off — granted 2026-08-05 (Jeff Zhang).** Implementation may
      proceed; the frozen-file edits listed in §1 are covered by this approval.
