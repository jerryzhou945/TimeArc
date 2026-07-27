# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-07-27T16:24:10Z | L1 | macos-rule-line... | Final harness audit found rules/02-platform-boundaries.md... | [report](errors/20260727-162410-B-macos-rule-line-budget.md) |
| 2026-07-27T16:22:39Z | L3 | macos-btm-dump-... | sfltool dumpbtm produced no output for roughly 35 seconds... | [report](errors/20260727-162239-B-macos-btm-dump-hang.md) |
| 2026-07-27T16:17:50Z | L2 | qt-warning-ce4a... | [WARNING] qrc:/qt/qml/time_arc/qml/main.qml:2 - qrc:/qt/q... | [report](errors/20260727-161750-C-qt-warning-ce4af83624.md) |
| 2026-07-27T16:17:50Z | L2 | qt-warning-882f... | [WARNING] :0 - QQmlApplicationEngine failed to load compo... | [report](errors/20260727-161750-C-qt-warning-882fece6aa.md) |
| 2026-07-27T16:17:50Z | L2 | qt-warning-5366... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260727-161750-C-qt-warning-536699d337.md) |
| 2026-07-27T16:17:50Z | L2 | qt-warning-ee1b... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260727-161750-C-qt-warning-ee1bf6d1ca.md) |
| 2026-07-27T16:17:49Z | L2 | qt-warning-ce4a... | [WARNING] qrc:/qt/qml/time_arc/qml/main.qml:2 - qrc:/qt/q... | [report](errors/20260727-161749-C-qt-warning-ce4af83624.md) |
| 2026-07-27T16:17:49Z | L2 | qt-warning-882f... | [WARNING] :0 - QQmlApplicationEngine failed to load compo... | [report](errors/20260727-161749-C-qt-warning-882fece6aa.md) |
| 2026-07-27T16:17:49Z | L2 | qt-warning-5366... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260727-161749-C-qt-warning-536699d337.md) |
| 2026-07-27T16:17:30Z | L3 | qt-log-rotation... | Required Qt log scan parsed historical warnings but could... | [report](errors/20260727-161730-B-qt-log-rotation-permission.md) |
| 2026-07-27T16:17:26Z | L2 | qt-warning-5366... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260727-161726-C-qt-warning-536699d337.md) |
| 2026-07-27T16:17:26Z | L2 | qt-warning-ee1b... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260727-161726-C-qt-warning-ee1bf6d1ca.md) |
| 2026-07-27T16:17:26Z | L2 | qt-warning-ce4a... | [WARNING] qrc:/qt/qml/time_arc/qml/main.qml:2 - qrc:/qt/q... | [report](errors/20260727-161726-C-qt-warning-ce4af83624.md) |
| 2026-07-27T16:17:26Z | L2 | qt-warning-882f... | [WARNING] :0 - QQmlApplicationEngine failed to load compo... | [report](errors/20260727-161726-C-qt-warning-882fece6aa.md) |
| 2026-07-27T16:17:25Z | L2 | qt-warning-ee1b... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260727-161725-C-qt-warning-ee1bf6d1ca.md) |
| 2026-07-27T16:17:25Z | L2 | qt-warning-ce4a... | [WARNING] qrc:/qt/qml/time_arc/qml/main.qml:2 - qrc:/qt/q... | [report](errors/20260727-161725-C-qt-warning-ce4af83624.md) |
| 2026-07-27T16:17:25Z | L2 | qt-warning-882f... | [WARNING] :0 - QQmlApplicationEngine failed to load compo... | [report](errors/20260727-161725-C-qt-warning-882fece6aa.md) |
| 2026-07-27T16:17:25Z | L2 | qt-warning-5366... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260727-161725-C-qt-warning-536699d337.md) |
| 2026-07-27T16:02:16Z | L1 | macos-hdiutil-d... | Repeated packaging reaches the signed app but hdiutil cre... | [report](errors/20260727-160216-B-macos-hdiutil-device-not-configured.md) |
| 2026-07-27T15:57:57Z | L3 | macos-package-i... | The interrupted packaging run reached hdiutil with an inv... | [report](errors/20260727-155757-B-macos-package-interrupted-dmg.md) |
| 2026-07-27T15:50:56Z | L2 | macos-launchage... | SMAppService reported NotFound at UI startup, leaving com... | [report](errors/20260727-155056-B-macos-launchagent-not-registered.md) |
| 2026-07-27T15:36:46Z | L3 | macos-generator... | The generator documentation patch used stale README line ... | [report](errors/20260727-153646-B-macos-generator-doc-context.md) |
| 2026-07-27T15:31:36Z | L3 | macos-build-scr... | The first repaired build-macos.sh run configured Ninja su... | [report](errors/20260727-153136-B-macos-build-script-yield.md) |
| 2026-07-27T15:30:03Z | L1 | macos-unsupport... | build-macos.sh defaulted to Unix Makefiles, which CMake c... | [report](errors/20260727-153003-B-macos-unsupported-cmake-generator.md) |
| 2026-07-27T15:10:30Z | L2 | stale-launchage... | Incremental TimeArc.app retained the old Contents/Resourc... | [report](errors/20260727-151030-B-stale-launchagent-resource.md) |
| 2026-07-27T15:10:08Z | L3 | macos-build-run... | The harness build stream ended at 99/120 without a succes... | [report](errors/20260727-151008-B-macos-build-runner-yield.md) |
| 2026-07-27T15:03:13Z | L3 | launchagent-doc... | A multi-file documentation patch used stale context for g... | [report](errors/20260727-150313-B-launchagent-doc-context.md) |
| 2026-07-27T15:01:21Z | L3 | launchagent-pro... | Applied a patch using context from the Windows session in... | [report](errors/20260727-150121-B-launchagent-proposal-edit.md) |
| 2026-07-27T07:49:57Z | L1 | macos-package-s... | Filtered Qt deployment completed, but the explicit deep s... | [report](errors/20260727-074957-B-macos-package-signature.md) |
| 2026-07-27T07:45:59Z | L3 | macos-qt-deploy... | The first generated Qt deployment attempt preserved two H... | [report](errors/20260727-074559-B-macos-qt-deploy-symlinks.md) |
| 2026-07-27T07:41:50Z | L1 | macos-package-l... | macdeployqt copied over-broad Homebrew Qt/QML dependencie... | [report](errors/20260727-074150-B-macos-package-linkage.md) |
| 2026-07-27T07:38:41Z | L1 | macos-release-b... | cmake --build exited 1 | [report](errors/20260727-073841-B-macos-release-build.md) |
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
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| ... | ... | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |
