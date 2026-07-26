# Session Log — macos-tracking-mismatch-review

## Metadata

- Agent: Codex `/root`
- Track: A — read-only stabilization review
- Date: 2026-07-23 17:03 (Asia/Shanghai)
- Status: done

## Goal

Compare the current macOS tracking sources with the revised platform-neutral
tracking contract and list only remaining mismatches or correctness problems.

## Scope

Review build integration, tracking transitions, probe failure behavior,
persistence bridging, and validation coverage. Intentional architectural
choices identified by the user are excluded. No implementation changes.

## Outcome

The revised contract now matches macOS full-observation identity, ordinary
video-over-idle handling, immediate media retirement, and the absence of
periodic media flushing. Remaining findings:

- The macOS target still lists deleted legacy sources, excludes `Tracking/`,
  and has an entry point written against unavailable runtime types.
- A foreground session first observed while already idle starts active and can
  receive one polling interval of active time.
- A `.system` sleep assertion masks simultaneous video-like `.foreground`
  evidence for the same PID.
- Probe failure and genuine absence share `nil`, causing transient failures to
  close otherwise-continuing sessions.
- Database bridge return codes are discarded after state has advanced.
- Windows still closes foreground on idle, lacks video-over-idle behavior,
  compares partial foreground/media identity, and retains a three-second media
  silence grace.
- There are no tracking state-machine/coordinator tests. Swift frontend syntax
  parsing passes, but end-to-end macOS compilation remains blocked upstream.
