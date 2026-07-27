# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-07-27T06:53:49Z | L2 | stale-single-rc... | Incremental macOS bundle retained obsolete timearc-gui-as... | [report](errors/20260727-065349-B-stale-single-rcc-bundle-artifact.md) |
| 2026-07-27T06:27:49Z | L3 | index-trim-patc... | Journal index trim patch used an inexact truncated summar... | [report](errors/20260727-062749-B-index-trim-patch-context.md) |
| 2026-07-27T06:27:29Z | L1 | gui-resource-fi... | Final harness audit passed code/frozen checks but the req... | [report](errors/20260727-062729-B-gui-resource-final-index-line-budget.md) |
| 2026-07-27T06:22:31Z | L1 | desktop-static-... | desktop_ux_static_test.py failed before feature assertion... | [report](errors/20260727-062231-B-desktop-static-manifest-path.md) |
| 2026-07-27T06:22:26Z | L3 | binary-rcc-list... | Used rcc --list on an already-binary RCC; that option par... | [report](errors/20260727-062226-B-binary-rcc-list-probe.md) |
| 2026-07-27T06:18:38Z | L3 | qt-rcc-path-ass... | Assumed Homebrew Qt exposed rcc at opt/qt/bin/rcc; the ex... | [report](errors/20260727-061838-B-qt-rcc-path-assumption.md) |
| 2026-07-26T06:12:31Z | L3 | macos-icon-cmak... | Initially assumed the top-level CMake icon wiring was mis... | [report](errors/20260726-061231-C-macos-icon-cmake-premise.md) |
| 2026-07-26T06:12:31Z | L2 | macos-runtime-i... | QGuiApplication::setWindowIcon loads the qrc SVG on macOS... | [report](errors/20260726-061231-C-macos-runtime-icon-override.md) |
| 2026-07-25T13:07:13Z | L1 | macos-icon-froz... | Post-change harness audit found the approved CMakeLists.t... | [report](errors/20260725-130713-B-macos-icon-frozen-hash-drift.md) |
| 2026-07-25T13:05:04Z | L3 | cmake-icon-prop... | Queried MACOSX_BUNDLE_ICON_FILE as a CMake property, but ... | [report](errors/20260725-130504-B-cmake-icon-property-probe.md) |
| 2026-07-25T12:59:52Z | L1 | resource-follow... | Mandatory Track C error entry pushed the rolling journal ... | [report](errors/20260725-125952-C-resource-followup-index-line-budget.md) |
| 2026-07-25T12:57:56Z | L2 | stale-resource-... | Runtime and documentation references still target removed... | [report](errors/20260725-125756-C-stale-resource-branding-license-paths.md) |
| 2026-07-25T12:48:30Z | L3 | resource-reorg-... | Resource path rule expansion and mandatory error-index en... | [report](errors/20260725-124830-A-resource-reorg-harness-line-budget.md) |
| 2026-07-25T12:45:45Z | L3 | build-poll-sess... | Polled the harness build through a yielded nested command... | [report](errors/20260725-124545-A-build-poll-session-handle.md) |
| 2026-07-25T12:45:02Z | L1 | desktop-static-... | desktop_ux_static_test.py expects android/src/main/Androi... | [report](errors/20260725-124502-A-desktop-static-manifest-path.md) |
| 2026-07-24T09:07:04Z | L3 | chained-read-co... | Combined git diff --check and a scoped git diff with a sh... | [report](errors/20260724-090704-C-chained-read-command.md) |
| 2026-07-24T08:04:26Z | L1 | harness-index-l... | harness_check found .harness/journal/INDEX.md at 101 line... | [report](errors/20260724-080426-C-harness-index-line-budget.md) |
| 2026-07-24T08:01:06Z | L1 | swift-module-cache | Swift type-check could not write the Clang module cache u... | [report](errors/20260724-080106-C-swift-module-cache.md) |
| 2026-07-23T19:41:56Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260723-194156-B-build-failure.md) |
| 2026-07-23T19:40:20Z | L3 | journal-index-l... | The required macOS main error report pushed the rolling j... | [report](errors/20260723-194020-C-journal-index-line-budget-main.md) |
| 2026-07-23T19:39:50Z | L1 | macos-main-miss... | macOS service type-check fails because TimeArcService ref... | [report](errors/20260723-193950-C-macos-main-missing-runner.md) |
| 2026-07-23T09:00:51Z | L3 | tracking-semant... | Documentation amendment exceeded harness line limits and ... | [report](errors/20260723-090051-B-tracking-semantics-harness-drift.md) |
| 2026-07-23T09:00:23Z | L3 | markdown-search... | A documentation grep used Markdown backticks inside a dou... | [report](errors/20260723-090023-B-markdown-search-quoting.md) |
| 2026-07-23T08:06:00Z | L3 | title-probe-tra... | The traversal-limit edit was initially classified as Trac... | [report](errors/20260723-080600-A-title-probe-track-discipline.md) |
| 2026-07-23T08:05:14Z | L1 | title-probe-typ... | Targeted Swift type-check could not start because the sel... | [report](errors/20260723-080514-A-title-probe-typecheck-toolchain.md) |
| 2026-07-23T07:23:09Z | L3 | journal-index-l... | harness_check found journal/INDEX.md at 102 lines after t... | [report](errors/20260723-072309-A-journal-index-line-budget-after-reaudit.md) |
| 2026-07-23T07:22:14Z | L3 | build-report-tr... | The sanctioned build correctly recorded its failure but l... | [report](errors/20260723-072214-A-build-report-track-from-index.md) |
| 2026-07-23T07:21:54Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260723-072154-B-build-failure.md) |
| 2026-07-19T13:03:40Z | L3 | harness-index-l... | harness_check failed because required session error entri... | [report](errors/20260719-130340-B-harness-index-line-budget.md) |
| 2026-07-19T13:02:58Z | L1 | sleep-probe-typ... | Isolated Swift typecheck failed because the default compi... | [report](errors/20260719-130258-B-sleep-probe-typecheck.md) |
| 2026-07-19T13:02:11Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260719-130211-B-build-failure.md) |
| 2026-07-19T13:01:58Z | L3 | chained-read-co... | Combined several read-only inspection commands in one she... | [report](errors/20260719-130158-B-chained-read-command.md) |
| 2026-07-18T12:13:31Z | L1 | harness-index-l... | Final harness check found journal/INDEX.md at 104 lines a... | [report](errors/20260718-121331-B-harness-index-line-budget.md) |
| 2026-07-18T12:11:48Z | L1 | swift-probe-typ... | Focused Swift typecheck failed before source diagnostics ... | [report](errors/20260718-121148-B-swift-probe-typecheck.md) |
| 2026-07-18T12:09:59Z | L1 | macos-tracking-... | cmake --build exited 1 | [report](errors/20260718-120959-B-macos-tracking-probes-baseline.md) |
| 2026-07-18T12:09:21Z | L3 | concatenated-se... | Used one sed line range across multiple files, so the req... | [report](errors/20260718-120921-B-concatenated-sed-range.md) |
| 2026-07-18T12:08:44Z | L3 | chained-read-co... | Combined read-only inspection commands with shell control... | [report](errors/20260718-120844-B-chained-read-command.md) |
| 2026-07-18T08:22:25Z | L1 | harness-index-l... | harness_check found journal/INDEX.md at 101 lines after t... | [report](errors/20260718-082225-B-harness-index-line-budget.md) |
| 2026-07-18T08:21:35Z | L1 | idle-continuity... | Patch context for the stale macOS idle sentence no longer... | [report](errors/20260718-082135-B-idle-continuity-patch-context.md) |
| 2026-07-17T08:49:30Z | L2 | macos-media-ses... | MediaManager.updateTrackedSessions rebuilds background Ap... | [report](errors/20260717-084930-B-macos-media-session-start-reset.md) |
| 2026-07-17T08:11:46Z | L3 | argument-parser... | Sandbox DNS blocked a read-only fetch of Swift Argument P... | [report](errors/20260717-081146-B-argument-parser-source-network.md) |
| 2026-07-17T08:05:55Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260717-080555-B-build-failure.md) |
| 2026-07-14T15:17:15Z | L3 | missing-cli-des... | Assumed src/service/CLI.md from the earlier CLI design se... | [report](errors/20260714-151715-B-missing-cli-design-file.md) |
| 2026-07-12T14:46:50Z | L1 | cli-doc-harness... | harness_check is blocked by pre-existing untracked macOS ... | [report](errors/20260712-144650-B-cli-doc-harness-drift.md) |
| 2026-07-12T12:51:24Z | L2 | qt-warning-2cf2... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Mem... | [report](errors/20260712-125124-C-qt-warning-2cf241971f.md) |
| 2026-07-12T12:51:13Z | L3 | qt-log-rotate-s... | scan_qt_log.py could read the Qt log but sandbox permissi... | [report](errors/20260712-125113-B-qt-log-rotate-sandbox.md) |
| 2026-07-12T12:51:02Z | L2 | qt-warning-2cf2... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Mem... | [report](errors/20260712-125102-C-qt-warning-2cf241971f.md) |
| 2026-07-12T12:50:18Z | L1 | open-issues-lin... | harness_check found .harness/state/open-issues.md at 102 ... | [report](errors/20260712-125018-B-open-issues-line-budget.md) |
| 2026-07-12T12:43:37Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260712-124337-B-build-failure.md) |
| 2026-07-12T09:39:48Z | L2 | db-smoke-legacy... | Updated service-schema smoke built successfully, but full... | [report](errors/20260712-093948-C-db-smoke-legacy-state.md) |
| 2026-07-12T09:39:03Z | L1 | ui-service-sche... | cmake --build exited 1 | [report](errors/20260712-093903-C-ui-service-schema-read.md) |
| 2026-07-12T09:30:01Z | L3 | preflight-froze... | Track C preflight still fails solely because the already-... | [report](errors/20260712-093001-C-preflight-frozen-hash.md) |
| 2026-07-12T09:24:43Z | L3 | stale-error-rep... | Error-report evidence patch failed because its context re... | [report](errors/20260712-092443-C-stale-error-report-patch.md) |
| 2026-07-12T09:24:01Z | L3 | sqlite-cli-missing | Direct inspection of copied timearc_service.db could not ... | [report](errors/20260712-092401-C-sqlite-cli-missing.md) |
| 2026-07-12T09:20:12Z | L3 | service-output-... | Assumed the service binary would be emitted under build/s... | [report](errors/20260712-092012-C-service-output-location-assumption.md) |
| 2026-07-12T08:40:01Z | L3 | missing-cmake-p... | Diagnostic rg included nonexistent CMakePresets.json and ... | [report](errors/20260712-084001-C-missing-cmake-presets.md) |
| 2026-07-12T08:38:56Z | L2 | windows-collect... | On Windows, the app builds and runs but service-collected... | [report](errors/20260712-083856-C-windows-collection-not-visible.md) |
| 2026-07-12T08:38:48Z | L3 | preflight-drift | Preflight failed during Windows collection diagnosis: ope... | [report](errors/20260712-083848-C-preflight-drift.md) |
| 2026-07-12T08:31:49Z | L3 | rg-option-pattern | Read-only inspection search failed because an rg pattern ... | [report](errors/20260712-083149-A-rg-option-pattern.md) |
| 2026-07-12T08:30:45Z | L3 | preflight-drift | Preflight failed during read-only Windows service inspect... | [report](errors/20260712-083045-A-preflight-drift.md) |
| 2026-07-12T07:58:45Z | L2 | preflight-drift | Preflight found open-issues.md over 100 lines and frozen ... | [report](errors/20260712-075845-A-preflight-drift.md) |
| 2026-07-12T07:49:15Z | L1 | build-failure | cmake --build exited 2 | [report](errors/20260712-074915-B-build-failure.md) |
| 2026-07-12T07:36:52Z | L3 | git-branch-perm... | Creating feat/shared-service-data-bridge failed because t... | [report](errors/20260712-073652-B-git-branch-permission.md) |
| 2026-07-12T07:36:33Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260712-073633-B-build-failure.md) |
| 2026-07-11T14:17:14Z | L1 | live-snapshot-r... | cmake --build exited 2 | [report](errors/20260711-141714-B-live-snapshot-retirement-ui-build.md) |
| 2026-07-11T14:16:33Z | L1 | live-snapshot-r... | cmake --build exited 1 | [report](errors/20260711-141633-B-live-snapshot-retirement-ui-build.md) |
| 2026-07-11T14:09:40Z | L3 | missing-bridge-... | Inspection assumed a macOS bridging-header filename that ... | [report](errors/20260711-140940-B-missing-bridge-header-path.md) |
| 2026-07-11T13:54:48Z | L3 | unlisted-frozen... | Changed a stale comment in frozen database_path.c before ... | [report](errors/20260711-135448-B-unlisted-frozen-comment.md) |
| 2026-07-11T13:54:30Z | L2 | db-smoke-idempo... | DB smoke test failed on the pre-existing legacy project m... | [report](errors/20260711-135430-B-db-smoke-idempotence.md) |
| 2026-07-11T13:51:09Z | L3 | stale-patch-con... | A multi-file documentation patch failed because the Track... | [report](errors/20260711-135109-B-stale-patch-context.md) |
| 2026-07-11T13:43:30Z | L1 | baseline-build | cmake --build exited 2 | [report](errors/20260711-134330-B-baseline-build.md) |
| 2026-07-11T13:39:37Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260711-133937-B-build-failure.md) |
| 2026-07-11T13:38:01Z | L3 | git-readonly-br... | Creating the required feature branch failed because the s... | [report](errors/20260711-133801-B-git-readonly-branch.md) |
| 2026-07-11T13:37:36Z | L3 | missing-dev-branch | Git workflow check assumed a local dev branch, but this c... | [report](errors/20260711-133736-B-missing-dev-branch.md) |
| 2026-07-10T13:58:47Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260710-135847-B-build-failure.md) |
| 2026-07-09T10:11:45Z | L3 | shell-backtick-... | Ran rg with unescaped Markdown backticks in the shell pat... | [report](errors/20260709-101145-B-shell-backtick-pattern.md) |
| 2026-07-09T10:01:09Z | L2 | preflight-froze... | Preflight failed because frozen files src/service/shared/... | [report](errors/20260709-100109-B-preflight-frozen-drift.md) |
| 2026-07-09T10:00:39Z | L2 | preflight-drift | preflight failed because frozen-file hash drift exists in... | [report](errors/20260709-100039-B-preflight-drift.md) |
| 2026-07-09T09:38:53Z | L2 | remaining-froze... | harness_check after database_path comments still fails on... | [report](errors/20260709-093853-B-remaining-frozen-drift.md) |
| 2026-07-09T09:37:20Z | L2 | preflight-drift | Preflight before database_path comments is blocked by exi... | [report](errors/20260709-093720-B-preflight-drift.md) |
| 2026-07-09T09:35:21Z | L2 | remaining-froze... | Final harness_check after database_path rename still fail... | [report](errors/20260709-093521-B-remaining-frozen-drift.md) |
| 2026-07-09T09:34:43Z | L2 | frozen-hash-drift | harness_check failed after database_path rename because f... | [report](errors/20260709-093443-B-frozen-hash-drift.md) |
| 2026-07-09T09:27:31Z | L2 | preflight-drift | Track B preflight reported existing harness drift before ... | [report](errors/20260709-092731-B-preflight-drift.md) |
| 2026-07-09T09:27:20Z | L3 | wrong-track | Initial Track A classification was too narrow because req... | [report](errors/20260709-092720-A-wrong-track.md) |
| 2026-07-09T09:26:50Z | L2 | preflight-drift | Preflight reported existing harness drift before coding, ... | [report](errors/20260709-092650-A-preflight-drift.md) |
| 2026-07-08T16:51:32Z | L3 | ctest-home-over... | Setting HOME to /private/tmp did not move macOS QStandard... | [report](errors/20260708-165132-B-ctest-home-override-ineffective.md) |
| 2026-07-08T16:51:13Z | L2 | ctest-qstandard... | ctest failed because QStandardPaths test mode tried to cl... | [report](errors/20260708-165113-B-ctest-qstandardpaths-sandbox.md) |
| 2026-07-08T16:50:31Z | L3 | build-escalatio... | Escalated harness build request was rejected by approval ... | [report](errors/20260708-165031-B-build-escalation-rejected.md) |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| ... | ... | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |
