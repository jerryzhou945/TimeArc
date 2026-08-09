# Change Proposal — macos-service-status

## Metadata

- Author: Claude · Track: **B (Feature)** · Date: 2026-08-07 21:15 (local)
- Goal: implement `status`, and have the GUI check the service at every launch.
- Branch: feature/macos-service · Follows: `20260807-1423-B-macos-service-lifecycle.md`

## 1. Frozen files touched

- `src/service/CMakeLists.txt` — add the three `Diagnostics/` Swift sources. No new
  framework, flag, or target change.

## 2. Motivation

The previous change moved launch-agent ownership to the service, removing the old
behavior where opening the app re-registered the agent every time. That was
deliberate — a login item should follow from the user asking for one — but it left
the product unable to notice a collector that had stopped.

Noticing needs a read-only query, which is `status`. Its absence was also forcing
`SettingsRepository::autostartEnabled()` to report the last value it wrote rather
than the truth, so the Settings switch could drift from launchd.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | New `status` verb. Reports from the control file, the instance lock, and the autostart backend — deliberately not the control channel, so it still answers when the collector is wedged, which is when it is most needed. `enable` now waits briefly for the collector to take the lock, because launchd returns before that. |
| Consumer | Reads autostart from `status --json` on every query and stores no copy. At launch it restarts a registered-but-idle collector, and never registers one. |
| Disk | Unchanged, minus one retired GUI key (`macos_autostart_enabled`). |

## 4. Migration plan

None. `status` is additive. Existing installs keep a now-unread
`macos_autostart_enabled` row in `timearc.db`; nothing reads or writes it, so it is
inert rather than a second source of truth. An install whose registration was lost
will no longer self-repair, since nothing records that the user once asked for it.

## 5. Rollback plan

Revert. A reverted UI reads the stale KV row again, which may disagree with launchd
until the user toggles autostart once.

## 6. Test plan

- Exit-code matrix: running+enabled → 0, stopped+enabled → 12, stopped+disabled → 13,
  unreadable config → 10; `--json` and text both rendered.
- Startup repair, end to end: stop the collector behind the app's back, launch the
  app, confirm collection resumes and no registration is ever created.
- `tests/macos_service_status_static_test.py` pins the fields and codes to the README,
  asserts `status` never reaches for the control channel, and forbids a UI-side mirror;
  a smoke case covers the state matrix under a redirected HOME.

## 7. Sign-off

- [x] `rules/02` macOS section updated; no CHARTER change (the UI↔service boundary is
      unchanged: CLI invocation, as v0.14 already allows). `state/frozen-files.json`
      regenerated; `src/service/README.md` already specs this.

## Outcome

Done, verified end to end. `status` renders both formats and returns 0/12/13 across the matrix; conflicting
flags still exit 2 from the parser. The startup repair was proven by breaking the
registration behind the app's back and launching it, which restored collection.

Two findings. `enable` returned before launchd's collector had taken the lock, so a
`status` immediately after reported stopped and the UI's success toast was
premature; `enable` now waits, bounded, and still reports registration success
regardless. And under `-platform offscreen` the app segfaults between QML load and
`app.exec()`, in the status-bar wiring this change does not touch — headless runs
only, worth its own look.

**Bug found by the maintainer, fixed 2026-08-07 22:00.** "Apply & Restart" and the
startup check both left autostart on with nothing collecting. `enable` started a
collector only as a side effect of a *fresh* registration: `RunAtLoad` fires when
launchd loads a job, so re-registering an already-registered agent starts nothing.
`enable` now kickstarts the job when configuration says to collect and no instance
holds the lock. Reproduced on the installed app (8.2 s — the settle wait timing out
— then success with nothing started); kickstart verified on that registration.

Invisible to my own verification because it only occurs on the **bundled** backend,
which returns early when already registered. The user-level fallback re-bootstraps
its plist every time, restarting the collector incidentally — and the dev build can
only use that fallback. Future autostart changes must be exercised on a signed
install, not just on `build/`.

**Mirror dropped, maintainer's call.** The UI had kept `macos_autostart_enabled` in
`timearc.db` beside the launchd registration. Two records of one fact can disagree
and then neither is trustworthy, so the key is gone: `autostartEnabled()` asks
`status` every read, `setAutostartEnabled()` stores nothing, and the startup check
gates on the registration the service reports, not a remembered intent.

One capability goes with it. A vanished registration could previously be rebuilt,
because the stored flag recorded that the user had asked for it; now "missing" is
indistinguishable from "never wanted", so the app leaves it alone. That is the price
of a single source of truth, and it keeps the stronger rule: launching never creates
a login item. The check still repairs a registered agent whose collector is not
running. Watch for: `stop` no longer survives an app launch while autostart is on.
