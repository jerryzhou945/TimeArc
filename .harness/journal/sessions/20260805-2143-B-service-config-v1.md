# Change Proposal — service-config-v1

## Metadata

- Author: Claude (Claude Code), for maintainer sign-off
- Track: **B (Feature)** — extends the UI→service disk control contract.
- Date: 2026-08-05 21:43 (local)
- Session goal: adopt `service_config.json`, update every document stating the old
  format as fact, and implement the UI writer + DB pointer. Service-side
  `tracking.*` reader deferred to backlog A3.
- Branch: `feature/config-redesign` · Related error reports: none

## 1. Frozen files touched

- `.harness/CHARTER.md` — I1/I2 wording + new §5 version entry (v0.13).
- `src/service/shared/database_path.{c,h}` — config path moves to
  `TimeArc/config/service_config.json`; pointer key `db_dir` → `database.dir`.

`src/service/CMakeLists.txt` is untouched: the reader folded into the existing
translation unit, so no new source file was added.

## 2. Motivation

`usage_config.json` is a flat three-key object (`db_dir`, `idle_threshold_ms`,
`track_enabled`) read by two independent parsers, with no version field and no
room for the collection controls the product needs. Failures it causes today:

- **Unit drift.** UI stores minutes, file stores ms, `src/service/README.md` says
  seconds. Risk #2 in `docs/h5-service-config-channel-kickoff.md` §5.
- **No sub-switches.** "Frontmost on, media off" is not expressible, although
  the macOS coordinator already has `enableFrontmost`/`enableMedia`.
- **Unbounded session loss.** Records are written only when a session ends
  (`usage_tracker.c:134-147`), so an unclean shutdown discards the entire open
  session. Nothing in the current format can bound that.
- **No version.** No safe way to change a key's meaning or unit. Format spec:
  `src/service/README.md` §Configuration File.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | Service reads the new path/keys only — no legacy fallback. New knobs: poll period, min/max session, frontmost & media sub-switches. Still startup-read, still disk-only (I1 holds). |
| Consumer | UI writes only the new file; patches individual leaves so unknown keys survive. Minutes→seconds conversion moves to the UI edge. `database.dir` replaces the `db_dir` pointer; the UI still never writes the DB itself. |

## 4. Migration plan

Old: `<config base>/TimeArc/usage/usage_config.json`, unversioned, flat `db_dir` /
`idle_threshold_ms` / `track_enabled`. New:
`<config base>/TimeArc/config/service_config.json`, `schema_version: 1`, nested
`tracking` / `database`. On Windows the root also moves `%LOCALAPPDATA%` → `%APPDATA%`.

**Clean break, no overlap** (maintainer decision, 2026-08-05, superseding the
coexistence plan first filed here). The retired file is never read, written, or
imported. Hand-migration mapping, for anyone who needs it:

| Key | Maps to | Transform |
|---|---|---|
| `db_dir` | `database.dir` | verbatim |
| `idle_threshold_ms` | `tracking.frontmost.idle_threshold_sec` | `round(ms/1000)`, clamp 0-86400 |
| `track_enabled` | `tracking.enabled` | verbatim |
| `db_path` | — | already retired; ignored |

No `timearc_service.db` record is reinterpreted, so **history needs no migration**
— but the *pointer* to it is not carried over. An install that had relocated its
database resolves to the platform default on first run and the service creates a
fresh empty DB there; the old database is untouched on disk and comes back when the
user re-selects the directory in Settings. **Release-note item.** The v0 unit trap
(a stale `300000` read as seconds) cannot fire: the key name changed, so no v0
value is reachable at all.

## 5. Rollback plan

Code revert is sufficient. The retired file is never modified or deleted, so a
revert restores the old channel with its values intact — a pointer the user
re-selected in the meantime stays in the new file and is simply not read. No data
restore is needed: no history record changes shape.

## 6. Test plan

- Pre-change reproduction: write `idle_threshold_ms: 90000` — the service
  rejects it and silently keeps 60s (`service_config.c:72-79`).
- Done (`db_smoke`, green): pointer resolve / absent / corrupt / unusable-dir wins;
  retired `db_dir` ignored even as the only file present; relocate + restore-default
  round trip; idle in seconds, `idleSec<0` omits while `0` is written; unknown
  sections preserved; both writers preserve each other's keys; corrupt file refused
  byte-intact; retired file never created.
- Pending with the service-side reader (A3): real-binary smoke — idle applied,
  `tracking.enabled:false` writes nothing, both sub-switches false exits 0,
  `max_session_sec` splits a long session into contiguous rows. Plus a
  `TIMEARC_SERVICE_CONFIG` redirect so those tests stay out of the user profile.

## 7. Sign-off

- [x] `rules/*.md` updated: `03-data-contract.md` (config channel + migration),
      `02-platform-boundaries.md` (stale macOS helper description).
- [x] `CHARTER.md` version bumped — v0.13.
- [x] `state/frozen-files.json` regenerated (`harness_check.py --bootstrap`).
- [x] Main `README.md` updated (Data Location, Configuration, service section).
- [x] **Maintainer sign-off — granted 2026-08-05 (Jeff Zhang).** Implementation may
      proceed; the frozen-file edits listed in §1 are covered by this approval.
