# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-07-30T06:00:14Z | L3 | macos-gui-scree... | Screen Recording and Automation are not granted to the ag... | [report](errors/20260730-060014-B-macos-gui-screenshot-tcc-blocked.md) |
| 2026-07-29T16:54:54Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260729-165454-B-build-failure.md) |
| 2026-07-29T16:53:50Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260729-165350-B-build-failure.md) |
| 2026-07-29T16:02:06Z | L2 | macos-menu-lang... | On graceful quit the QML engine outlives SettingsReposito... | [report](errors/20260729-160206-B-macos-menu-language-pinned-at-teardown.md) |
| 2026-07-29T14:28:09Z | L2 | macos-menu-bar-... | MacMenuBar's lang fallback hardcoded zh, so every launch ... | [report](errors/20260729-142809-B-macos-menu-bar-startup-language-fallback.md) |
| 2026-07-29T14:23:25Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260729-142325-B-build-failure.md) |
| 2026-07-29T10:33:38Z | L1 | journal-index-l... | Harness audit found journal/INDEX.md at 102 lines after r... | [report](errors/20260729-103338-C-journal-index-line-budget.md) |
| 2026-07-29T10:32:55Z | L1 | desktop-ux-miss... | Desktop UX static test cannot start because android/src/m... | [report](errors/20260729-103255-C-desktop-ux-missing-android.md) |
| 2026-07-29T10:32:11Z | L2 | macos-memo-shor... | Memo Board help text displays Ctrl for shortcuts that use... | [report](errors/20260729-103211-C-macos-memo-shortcut-label.md) |
| 2026-07-29T10:19:30Z | L3 | journal-index-l... | Mandatory error reports pushed the rolling journal index ... | [report](errors/20260729-101930-C-journal-index-line-budget.md) |
| 2026-07-29T10:17:32Z | L3 | frozen-manifest... | After correcting the files list assumption, iterated the ... | [report](errors/20260729-101732-C-frozen-manifest-nesting.md) |
| 2026-07-29T10:17:27Z | L3 | frozen-manifest... | Assumed frozen-files.json stored a keyed object, but it s... | [report](errors/20260729-101727-C-frozen-manifest-shape.md) |
| 2026-07-29T10:04:44Z | L3 | clang-format-un... | clang-format is not installed in the macOS workspace, so ... | [report](errors/20260729-100444-C-clang-format-unavailable.md) |
| 2026-07-29T10:04:35Z | L1 | macos-build-scr... | The existing macos_build_script_static_test still expects... | [report](errors/20260729-100435-C-macos-build-script-static-baseline.md) |
| 2026-07-29T10:01:27Z | L2 | macos-app-menu-... | The native macOS TimeArc application menu stays English b... | [report](errors/20260729-100127-C-macos-app-menu-localization.md) |
| 2026-07-29T08:56:05Z | L2 | macos-double-cl... | The preference-aware sidebar double-click handler omitted... | [report](errors/20260729-085605-B-macos-double-click-fill.md) |
| 2026-07-29T08:43:17Z | L3 | unrelated-froze... | Final harness check found an unrelated concurrent CMakeLi... | [report](errors/20260729-084317-B-unrelated-frozen-cmake-drift.md) |
| 2026-07-29T08:38:01Z | L2 | macos-double-cl... | Sidebar double-click always maximized/restored instead of... | [report](errors/20260729-083801-B-macos-double-click-preference.md) |
| 2026-07-29T07:23:53Z | L2 | open-folder-uni... | _folderUrlOf prefixed file:/// unconditionally, which is ... | [report](errors/20260729-072353-C-open-folder-unix-file-url.md) |
| 2026-07-29T07:06:03Z | L2 | i18n-confirm-di... | Settings confirm card rendered titleText/msgText without ... | [report](errors/20260729-070603-C-i18n-confirm-dialog.md) |
| 2026-07-29T07:03:03Z | L2 | qt-warning-19f3... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260729-070303-C-qt-warning-19f33ebed5.md) |
| 2026-07-28T20:15:46Z | L3 | macos-menu-bar-... | MacMenuBar was given 'appWindow: appWindow'; the RHS reso... | [report](errors/20260728-201546-B-macos-menu-bar-self-bound-window.md) |
| 2026-07-28T19:53:05Z | L2 | qt-warning-19f3... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260728-195305-B-qt-warning-19f33ebed5.md) |
| 2026-07-28T18:06:39Z | L2 | qt-warning-c26e... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-180639-C-qt-warning-c26efcf9e0.md) |
| 2026-07-28T15:28:53Z | L3 | close-notificat... | Harness track-discipline check did not recognize the new ... | [report](errors/20260728-152853-C-close-notification-session-error-link.md) |
| 2026-07-28T15:27:33Z | L2 | macos-close-tra... | Closing the TimeArc window on macOS emits an unwanted sys... | [report](errors/20260728-152733-C-macos-close-tray-notification.md) |
| 2026-07-28T15:25:00Z | L3 | fullscreen-fix-... | Rolling-index trim patch used stale adjacent omission-row... | [report](errors/20260728-152500-C-fullscreen-fix-index-trim-context.md) |
| 2026-07-28T15:23:59Z | L3 | fullscreen-fix-... | Runtime verification could not launch the rebuilt GUI bec... | [report](errors/20260728-152359-C-fullscreen-fix-gui-launch-not-authorized.md) |
| 2026-07-28T15:21:10Z | L3 | fullscreen-fix-... | A source-discovery search included a nonexistent cmake di... | [report](errors/20260728-152110-C-fullscreen-fix-rg-missing-cmake-dir.md) |
| 2026-07-28T15:07:29Z | L3 | fullscreen-diag... | Harness fast check found journal/INDEX.md at 102 lines af... | [report](errors/20260728-150729-C-fullscreen-diagnosis-index-line-budget.md) |
| 2026-07-28T15:06:12Z | L3 | macos-status-ba... | Looked for macOS status-bar implementation under an incor... | [report](errors/20260728-150612-C-macos-status-bar-path-assumption.md) |
| 2026-07-28T15:05:42Z | L2 | macos-fullscree... | Closing the GUI while in macOS full-screen leaves a black... | [report](errors/20260728-150542-C-macos-fullscreen-close-black-screen.md) |
| 2026-07-28T14:29:36Z | L3 | qml-rule-path | Attempted to read a nonexistent rules/04-qml-runtime.md i... | [report](errors/20260728-142936-B-qml-rule-path.md) |
| 2026-07-28T09:55:35Z | L1 | macos-logo-cont... | cmake --build exited 1 | [report](errors/20260728-095535-C-macos-logo-container-only-resize.md) |
| 2026-07-28T09:54:52Z | L2 | macos-logo-cont... | The first sidebar fix enlarged the logo container only; t... | [report](errors/20260728-095452-C-macos-logo-container-only-resize.md) |
| 2026-07-28T09:47:21Z | L3 | gui-launch-not-... | Visual verification could not launch the newly built app ... | [report](errors/20260728-094721-C-gui-launch-not-authorized.md) |
| 2026-07-28T09:46:58Z | L3 | process-list-sa... | Visual-verification process-list check could not access m... | [report](errors/20260728-094658-C-process-list-sandbox.md) |
| 2026-07-28T09:45:59Z | L3 | build-track-def... | Invoked build.py without --track C, so its missing-build-... | [report](errors/20260728-094559-C-build-track-default.md) |
| 2026-07-28T09:41:07Z | L1 | swift-config-to... | Recreating the missing build directory failed because Swi... | [report](errors/20260728-094107-C-swift-config-toolchain-cache.md) |
| 2026-07-28T09:40:24Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260728-094024-B-build-failure.md) |
| 2026-07-28T09:39:36Z | L2 | macos-collapsed... | The macOS collapsed sidebar TimeArc logo is smaller and h... | [report](errors/20260728-093936-C-macos-collapsed-logo-alignment.md) |
| 2026-07-28T09:12:41Z | L2 | qt-warning-c26e... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-091241-C-qt-warning-c26efcf9e0.md) |
| 2026-07-28T09:12:41Z | L2 | qt-warning-19f3... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260728-091241-C-qt-warning-19f33ebed5.md) |
| 2026-07-28T09:12:40Z | L2 | qt-warning-c26e... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-091240-C-qt-warning-c26efcf9e0.md) |
| 2026-07-28T09:12:40Z | L2 | qt-warning-2766... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-091240-C-qt-warning-2766f01f44.md) |
| 2026-07-28T09:12:40Z | L2 | qt-fatal-f42b35... | [FATAL] :0 - QWidget: Cannot create a QWidget without QAp... | [report](errors/20260728-091240-C-qt-fatal-f42b357aa6.md) |
| 2026-07-28T09:12:40Z | L2 | qt-warning-2abb... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-091240-C-qt-warning-2abb77c1a6.md) |
| 2026-07-28T09:12:40Z | L2 | qt-warning-e1d2... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-091240-C-qt-warning-e1d2ce4a0b.md) |
| 2026-07-28T09:12:40Z | L2 | qt-warning-19f3... | [WARNING] :0 - Could not register the macOS LaunchAgent: ... | [report](errors/20260728-091240-C-qt-warning-19f33ebed5.md) |
| 2026-07-28T09:12:40Z | L2 | qt-warning-ee1b... | [WARNING] /Users/jz2025/Desktop/Development/TimeArc/src/m... | [report](errors/20260728-091240-C-qt-warning-ee1bf6d1ca.md) |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| 2026-07-28T08:24:16Z | L1 | desktop-static-... | desktop_ux_static_test.py could not run because android/s... | [report](errors/20260728-082416-C-desktop-static-missing-manifest.md) |
| 2026-07-28T08:23:14Z | L3 | qt-log-rotation... | Required post-run Qt log scan parsed the log but could no... | [report](errors/20260728-082314-C-qt-log-rotation-permission.md) |
| 2026-07-28T07:59:03Z | L1 | hover-index-lin... | Final non-dimming hover audit found the rolling journal i... | [report](errors/20260728-075903-B-hover-index-line-budget.md) |
| 2026-07-28T07:49:34Z | L1 | final-index-lin... | Final title-bar-free AppKit audit found the rolling journ... | [report](errors/20260728-074934-B-final-index-line-budget.md) |
| 2026-07-28T07:25:27Z | L1 | appkit-harness-... | Final AppKit audit found journal/INDEX.md over its rollin... | [report](errors/20260728-072527-B-appkit-harness-drift.md) |
| 2026-07-28T07:24:27Z | L3 | qt-log-scan-app... | The required escalated Qt log scan was not approved, so t... | [report](errors/20260728-072427-B-qt-log-scan-approval.md) |
| 2026-07-28T07:21:56Z | L3 | swift-flag-list... | Configured CMAKE_Swift_FLAGS with a semicolon, which CMak... | [report](errors/20260728-072156-B-swift-flag-list-separator.md) |
| 2026-07-28T07:21:40Z | L1 | build-failure | cmake --build exited 127 | [report](errors/20260728-072140-B-build-failure.md) |
| 2026-07-28T07:21:03Z | L1 | swift-config-cache | CMake regeneration failed because Swift could not write t... | [report](errors/20260728-072103-B-swift-config-cache.md) |
| 2026-07-28T07:20:23Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260728-072023-B-build-failure.md) |
| 2026-07-28T07:04:35Z | L1 | open-issues-lin... | Second harness audit passed the journal trim but open-iss... | [report](errors/20260728-070435-B-open-issues-line-budget.md) |
| 2026-07-28T07:04:00Z | L3 | index-trim-context | The first rolling INDEX trim patch used an expanded summa... | [report](errors/20260728-070400-B-index-trim-context.md) |
| 2026-07-28T07:03:40Z | L3 | chained-error-r... | Used a semicolon to combine two record_error invocations ... | [report](errors/20260728-070340-B-chained-error-report-command.md) |
| 2026-07-28T07:03:27Z | L1 | macos-chrome-li... | Final harness audit found journal/INDEX.md at 109 lines a... | [report](errors/20260728-070327-B-macos-chrome-line-budget.md) |
| 2026-07-28T07:03:27Z | L3 | harness-topic-l... | The first harness line-budget error report used a topic l... | [report](errors/20260728-070327-B-harness-topic-length.md) |
| 2026-07-28T07:02:22Z | L3 | qt-log-scan-san... | Post-run scan re-read stale prior macOS launch warnings a... | [report](errors/20260728-070222-B-qt-log-scan-sandbox-repeat.md) |
| 2026-07-28T07:00:06Z | L3 | macos-sidebar-e... | Second visual pass still exposed a title-bar-like top ban... | [report](errors/20260728-070006-B-macos-sidebar-edge-to-edge.md) |
| 2026-07-28T06:56:36Z | L3 | macos-sidebar-t... | First implementation retained a native title-bar region a... | [report](errors/20260728-065636-B-macos-sidebar-titlebar-misread.md) |
| ... | ... | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |
