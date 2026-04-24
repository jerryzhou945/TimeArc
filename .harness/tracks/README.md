# Tracks — Three Workflows

Every session belongs to exactly one of three tracks. Pick it **before**
writing code, name it in the session log's `Track:` field, and use it as a
commit-message prefix convention.

| Track            | Goal                             | Typical file    |
|------------------|----------------------------------|-----------------|
| **A. Stabilize** | Quality up, behavior unchanged   | [`A-stabilize.md`](A-stabilize.md) |
| **B. Feature**   | Add or enable a new capability   | [`B-feature.md`](B-feature.md)     |
| **C. Debug**     | Fix a known or observed error    | [`C-debug.md`](C-debug.md)         |

## How to pick

- Are you fixing something that is **wrong today**? → **C (Debug)**.
- Are you adding something that **didn't exist**? → **B (Feature)**.
- Is the result observationally identical but the code is cleaner, simpler,
  safer? → **A (Stabilize)**.
- Anything else? You're straddling. **Split the session.** One commit, one
  track.

## Why the split matters

The three tracks have different risk profiles, different review lenses, and
different journal conventions. Mixing them makes diffs un-reviewable:

- A **Debug** diff that quietly refactors an unrelated module hides both the
  fix and the refactor from review.
- A **Feature** diff that also fixes a bug makes the bug un-bisectable.
- A **Stabilize** diff that changes behavior is the single most common source
  of regressions in this repo's history — treat it as a ward.

## Cross-cutting rules (all three tracks)

- Record every error via `tools/record_error.py` (stub: hand-write the
  report + append to `errors.jsonl`).
- Obey `CHARTER.md` and the relevant `rules/*.md`.
- One session, one `journal/sessions/YYYYMMDD-HHMM-<track>-<slug>.md`.
- Commit message first word is the track's preferred verb (see each track
  file).

## Journal slug convention

Prefix the slug with the track letter:

- `journal/sessions/20260424-0900-A-utf8-escape-cleanup.md`
- `journal/sessions/20260424-1100-B-linux-service-bootstrap.md`
- `journal/errors/20260424-0912-C-qml-warning-memorylake.md`

This is a convention, not a hard check. `harness_check.py` will warn if the
slug is missing a track letter once that feature lands.
