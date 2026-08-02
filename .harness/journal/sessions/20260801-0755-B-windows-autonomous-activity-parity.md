# Change Proposal — windows-autonomous-activity-parity

## Metadata

- Author: Codex `/root`
- Track: **B (Feature)**
- Date: 2026-08-01 07:55 (local)
- Session goal (one sentence): Bring Windows autonomous activity tracking, logical idle sessions, tray Pomodoro controls, and build/test behavior to parity with the merged macOS implementation.
- Branch: `codex/cross-sync-e1-cloud-auth`
- Related error reports: `20260731-233840-B-powercfg-requests-permission`, `20260731-233950-B-merged-desktop-static-manifest`, `20260731-234001-B-merged-windows-build-static`

## 1. Frozen files touched

- `.harness/rules/02-platform-boundaries.md` — clarify that foreground autonomous process-tree work, not only media playback, may override input idleness when supported by a platform adapter.
- `src/service/CMakeLists.txt` — register the Windows activity/state modules and their native test target.
- `CMakeLists.txt` — register or expose the Windows native test when required by the existing build topology.
- `.harness/CHARTER.md` — only if the rule clarification changes a charter invariant; if it does not, this file will remain untouched.
- `.harness/state/frozen-files.json` — regenerate hashes after the frozen-file changes land.

## 2. Motivation

The merged macOS tracker recognizes meaningful foreground work even without keyboard or mouse input and keeps a logical session open across idle periods. Windows currently closes a session as soon as input idle is detected, cannot distinguish autonomous work from true idle, and calculates input idle with a mixed 64/32-bit tick subtraction that fails around the Windows tick rollover. This undercounts Codex, builds, tests, and foreground playback, and fragments sessions. Windows also lacks the macOS status-bar Pomodoro controls, while two static tests expose Windows build-wrapper and manifest-path drift.

## 3. Impact on the other process

| Side | Effect |
|---|---|
| Producer | The Windows service observes foreground process-tree CPU/I/O and media evidence, applies a 90-second activity lease, and writes one completed logical session across idle/resume intervals. The on-disk schema is unchanged. |
| Consumer | The UI continues reading the same session schema. It receives more accurate `active_sec`/`idle_sec` values and fewer artificial session splits. The Windows tray forwards actions to the existing shared Pomodoro manager. |

## 4. Migration plan

No on-disk impact. Old and new records use the same fields and coexist. New records may span an idle/resume interval and therefore contain both active and idle duration, which the existing reader already supports.

## 5. Rollback plan

A code revert is sufficient. No database backup or restoration is required because no schema or stored-value interpretation changes.

## 6. Test plan

- Pre-change reproduction: leave Codex or a terminal running foreground child work without input and observe Windows close/pause it as idle; reproduce mixed tick arithmetic with a unit fixture around 32-bit rollover; run the two failing static tests.
- Post-change verification: qualifying foreground-tree work/media renews the 90-second lease, true inactivity expires it, idle/resume retains one session with correct counters, and tray actions operate the shared Pomodoro timer.
- New test artifacts: deterministic Windows C tests for tick arithmetic, activity deltas, lease/state transitions and failures; static QML tests for tray wiring; corrected build/desktop static tests.

## 7. Sign-off

- [ ] `rules/02-platform-boundaries.md` updated to reflect new reality.
- [ ] `CHARTER.md` version bumped if and only if a charter amendment is necessary.
- [ ] `state/frozen-files.json` regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible setup or operation changes.
