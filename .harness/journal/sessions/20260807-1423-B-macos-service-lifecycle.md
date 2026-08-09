# Change Proposal — macos-service-lifecycle

## Metadata

- Author: Claude · Track: **B (Feature)** · Date: 2026-08-07 14:23 (local)
- Goal: give the macOS service `start`/`stop`/`enable`/`disable`, a
  service-to-service control channel, and ownership of its own launch agent.
- Branch: feature/macos-service · Baseline: af520b0 · Error reports: none

## 1. Frozen files touched

- `.harness/CHARTER.md` — **amendment**, §1 and I1 (see §2).
- `src/service/CMakeLists.txt` — add `Control/` and `Autostart/`; link `ServiceManagement`.
- `CMakeLists.txt` (top level) — drop `src/services/macos/macos_launch_agent.mm`
  and the GUI's now-unused `ServiceManagement` link; registration leaves the UI.

## 2. Motivation

Seven of ten CLI verbs still exit 1. Four land here, and both blockers are
structural rather than missing code.

**No way to reach a running instance.** `stop` must make a *running* helper flush
and exit; `status`/`doctor` will need its live state too.

**`KeepAlive: true` collapses `stop` into `disable`.** The agent restarts the
helper on any exit, so a clean shutdown is indistinguishable from a crash and
"stopped" is not expressible. It becomes `{SuccessfulExit: false}`.

**The UI owns registration.** `src/main.cpp:218` registers the agent on every app
launch, while `SettingsRepository::{start,stop}BackgroundCollection` are no-ops and
`autostartSupported()` is false on macOS — so the service can only be started by a
login and the Settings controls are dead. Ownership moves to the service; the UI
invokes its CLI, as Windows already does via `runServiceVerb`.

**Charter amendment.** §1 forbade IPC globally; `stop` needs a socket. The
amendment scopes the prohibition to the boundary it was written to protect:
**UI↔service stays disk + CLI; IPC is permitted between `time-arc-service`
instances** — same program, shipped together, so no cross-language or
cross-release contract is created, and the channel refuses any peer that is not
this same executable. I1 also still cited `src/main.cpp::startUsageService`,
already forbidden by test; it now says the UI drives the service through its CLI.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | Owns its lifecycle: `enable`/`disable` register the launch agent (bundled via SMAppService, falling back to a user-level agent), `start`/`stop` control a running instance over a per-user unix socket. Records unchanged. |
| Consumer | Stops registering the agent and stops being the lifecycle owner; the macOS Settings controls now work by shelling out to the service CLI. Windows behavior is untouched. |
| Disk | Unchanged. The socket and lock are service-private runtime files. |

## 4. Migration plan

No on-disk data change. One user-visible change: registration no longer happens
implicitly at app launch, so an install that relied on it shows autostart off
until the user enables it. The previously registered agent keeps working until
`disable` removes it; label and plist name are unchanged.

## 5. Rollback plan

Revert and restore `KeepAlive: true`; the UI regains its registration call. A
user-level agent written by `enable` survives the revert and must be removed by
hand (`launchctl bootout gui/$UID/com.timearc.service`, then delete
`~/Library/LaunchAgents/com.timearc.service.plist`) — the reverted build has no
`disable` to do it.

## 6. Test plan

- Spike (done): from `Contents/MacOS/`, `Bundle.main` resolves to `TimeArc.app`
  and finds the bundled plist, so the helper can drive SMAppService — but on this
  ad-hoc/linker-signed build its status is `notFound`, so **the user-level backend
  is the working path until Developer ID signing lands**.
- `start` idempotence; `stop` live, idle, and `restart`; `enable`/`disable` round
  trip against `launchctl print`; peer rejection from a non-service binary.
- KeepAlive pair: after `stop` the job stays stopped; after `kill -9` it restarts.
- New `macos_service_control_static_test.py`; `gui_service_startup_static_test.py`
  inverted; start/stop cases added to the config smoke test.

## 7. Sign-off

- [x] `CHARTER.md` §1 + I1 amended, bumped to v0.14; `rules/01` §2 and `rules/02` §3
      scoped; `state/frozen-files.json` regenerated; `src/service/README.md` unchanged.

## Outcome

Done, verified on the real binary and on launchd.
`enable` → `user-launch-agent` (SMAppService `notFound` on this ad-hoc build, as
the spike predicted), wrote `KeepAlive {SuccessfulExit: false}`, bootstrapped it,
launchd started the collector. `disable` unloaded it — note `bootout` also
terminates the job, so on macOS `disable` implicitly stops: platform behavior.
After `stop` the job stayed stopped; after `kill -9` launchd restarted it (32229 →
32637). `stop` exits 0, unlinks the socket, no-ops when idle; `start` is idempotent;
a same-user impostor was refused with no reply.

Two corrections while verifying: liveness comes from the instance lock, not the
socket, so `stop` works against an instance older than the channel (the first
attempt returned 3 — signalled, then `KeepAlive: true` restarted it, the exact bug
this removes); and `start` skips launchd when the control file is redirected, since
a launchd job does not inherit the caller's environment. Followed by
`20260807-2115-B-macos-service-status.md`.

