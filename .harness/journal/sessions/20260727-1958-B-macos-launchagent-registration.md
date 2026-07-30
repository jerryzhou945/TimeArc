# Change Proposal — macOS LaunchAgent registration

## Metadata

- Author: Codex `/root`
- Track: **B (Feature)**
- Date: 2026-07-27 19:58 CST
- Session goal: Embed a production LaunchAgent and helper using Apple's
  `SMAppService` bundle layout and register it when the macOS UI launches.
- Branch: `development/macos-support`
- Related errors: `20260727-150121-B-launchagent-proposal-edit.md`,
  `20260727-150313-B-launchagent-doc-context.md`,
  `20260727-151008-B-macos-build-runner-yield.md`, and
  `20260727-151030-B-stale-launchagent-resource.md`,
  `20260727-155056-B-macos-launchagent-not-registered.md`.

## 1. Frozen files touched

- `CMakeLists.txt` — enable Objective-C++, embed the plist under
  `Contents/Library/LaunchAgents`, keep the helper in `Contents/MacOS`, and link
  the UI registration adapter from `src/services/macos` with ServiceManagement.

## 2. Motivation

The initial absolute-path/launchctl approach does not follow Apple's embedded
service model. `BundleProgram` plus `SMAppService` preserves registration when
the containing app moves and avoids writing a second plist into the user home.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | launchd starts `Contents/MacOS/time-arc-service`. |
| Consumer | UI registers the embedded plist through `SMAppService`. |

## 4. Migration plan

No database or record impact. Existing legacy/test LaunchAgents are not removed;
the embedded service becomes the production registration source.

## 5. Rollback plan

Revert the CMake/UI/template changes and boot out the user LaunchAgent; no data
restoration is required.

## 6. Test plan

- Pre-change: plist is under Resources and UI writes an absolute-path copy.
- Post-change: inspect both embedded paths and `SMAppService` adapter location.
- New artifact: static LaunchAgent registration test.

## 7. Sign-off

- [x] Rules 01, 02, and 05 updated.
- [x] Charter unchanged; no amendment is required.
- [x] Frozen hashes regenerated after the CMake edit.
- [x] README updated.

## Outcome

The UI now registers the embedded plist through an Objective-C++ adapter under
`src/services/macos`. The installed app contains only
`Contents/Library/LaunchAgents/com.timearc.service.plist` and
`Contents/MacOS/time-arc-service`; its `BundleProgram` uses that relative path.
Release build, installed-bundle inspection, focused checks, CTest, and audit
pass. Live verification found that treating the initial `NotFound` status as a
terminal error skipped the registration call; the adapter now attempts
registration from both unregistered states and reports native error details.
The packaged app then registered `com.timearc.service`; `launchctl` reported it
running under ServiceManagement and `ps` showed the helper with launchd as its
parent.
