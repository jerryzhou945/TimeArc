# Journal Index

Rolling index of recent reports. `errors.jsonl` is authoritative; older rows are
omitted here to preserve the harness line budget.

## Error entries

| Date (UTC) | Lvl | Topic | Report |
|---|---|---|---|
| 2026-08-25T05:43:02Z | L1 | post-merge-icon... | Post-merge native icon verification used a positional EXE... | [report](errors/20260825-054302-C-post-merge-icon-test-cli.md) |
| 2026-08-25T05:35:37Z | L2 | native-icon-ind... | Windows icon debug reports expanded the rolling journal I... | [report](errors/20260825-053537-C-native-icon-index-budget.md) |
| 2026-08-25T05:28:22Z | L1 | windows-native-... | cmake --build exited 1 | [report](errors/20260825-052822-C-windows-native-icon-build.md) |
| 2026-08-25T05:27:41Z | L3 | build-wrapper-d... | The first wrapped build omitted --track C, so build.py au... | [report](errors/20260825-052741-C-build-wrapper-default-track.md) |
| 2026-08-25T05:27:41Z | L1 | stale-windows-r... | CMake regeneration kept a stale F: drive windres path in ... | [report](errors/20260825-052741-C-stale-windows-rc-compiler.md) |
| 2026-08-25T05:26:08Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260825-052608-B-build-failure.md) |
| 2026-08-25T05:24:11Z | L3 | ico-preview-uns... | Local image viewer could not decode the generated ICO dir... | [report](errors/20260825-052411-C-ico-preview-unsupported.md) |
| 2026-08-25T05:23:35Z | L3 | icon-check-afte... | Chained icon inspection commands ran after generation fai... | [report](errors/20260825-052335-C-icon-check-after-generate-failure.md) |
| 2026-08-25T05:23:34Z | L1 | windows-icon-ge... | Windows icon generator passed integer sizes to Pillow ICO... | [report](errors/20260825-052334-C-windows-icon-generator-sizes.md) |
| 2026-08-25T05:21:12Z | L3 | cairosvg-unavai... | Bundled workspace Python has Pillow but not CairoSVG, so ... | [report](errors/20260825-052112-C-cairosvg-unavailable.md) |
| 2026-08-25T05:20:57Z | L2 | windows-icon-re... | Expected RED: built TimeArc.exe has no native RT_ICON res... | [report](errors/20260825-052057-C-windows-icon-resource-red.md) |
| 2026-08-25T05:19:53Z | L3 | tdd-test-guide-... | TDD skill referenced writing-good-tests.md beside SKILL.m... | [report](errors/20260825-051953-C-tdd-test-guide-missing.md) |
| 2026-08-25T05:15:33Z | L2 | windows-exe-ico... | Installed TimeArc.exe has no Windows PE icon resource, so... | [report](errors/20260825-051533-C-windows-exe-icon-missing.md) |
| 2026-08-25T04:59:55Z | L2 | installer-index... | Final harness check found journal INDEX at 105 lines afte... | [report](errors/20260825-045955-C-installer-index-budget.md) |
| 2026-08-25T04:57:29Z | L2 | installer-power... | Minimal corrected-module SFX smoke test exited 1 because ... | [report](errors/20260825-045729-C-installer-powershell-lookup.md) |
| 2026-08-25T04:56:10Z | L2 | installer-outpu... | Repackaging could not replace the old setup EXE because t... | [report](errors/20260825-045610-C-installer-output-locked.md) |
| 2026-08-25T04:55:33Z | L2 | installer-regre... | Installer packaging regression test failed as expected be... | [report](errors/20260825-045533-C-installer-regression-red.md) |
| 2026-08-25T04:54:20Z | L3 | python-path-san... | System Python invocation exited silently in the managed s... | [report](errors/20260825-045420-C-python-path-sandbox.md) |
| 2026-08-25T04:54:20Z | L2 | installer-opens... | Windows self-extracting installer opens install.ps1 as te... | [report](errors/20260825-045420-C-installer-opens-script.md) |
| 2026-08-25T04:16:01Z | L2 | main-fetch-head... | Non-escalated git fetch could not write .git/FETCH_HEAD b... | [report](errors/20260825-041601-B-main-fetch-head-denied.md) |
| 2026-08-25T04:14:47Z | L2 | commit-after-di... | PowerShell command sequencing allowed git commit to run a... | [report](errors/20260825-041447-B-commit-after-diff-check.md) |
| 2026-08-25T04:13:47Z | L2 | merged-dev-inde... | Merged-dev verification errors pushed the rolling journal... | [report](errors/20260825-041347-B-merged-dev-index-budget.md) |
| 2026-08-25T04:12:47Z | L3 | release-ui-clos... | TimeArc had no CloseMainWindow handle while locking the r... | [report](errors/20260825-041247-B-release-ui-close-window.md) |
| 2026-08-25T04:12:20Z | L1 | merged-dev-rele... | cmake --build exited 1 | [report](errors/20260825-041220-B-merged-dev-release-gate-green.md) |
| 2026-08-25T04:11:18Z | L1 | merged-dev-rele... | cmake --build exited 1 | [report](errors/20260825-041118-B-merged-dev-release-gate.md) |
| 2026-08-25T04:08:50Z | L2 | release-index-b... | New installer packaging errors pushed harness journal IND... | [report](errors/20260825-040850-B-release-index-budget.md) |
| 2026-08-25T04:06:50Z | L2 | sfx-size-assertion | The valid SFX output was smaller than the source ZIP beca... | [report](errors/20260825-040650-B-sfx-size-assertion.md) |
| 2026-08-25T04:05:15Z | L3 | sevenzip-output... | 7zr extraction received a split -o switch for the local t... | [report](errors/20260825-040515-B-sevenzip-output-switch.md) |
| 2026-08-25T04:04:05Z | L3 | iexpress-help-b... | IExpress help invocation opened an interactive process an... | [report](errors/20260825-040405-B-iexpress-help-blocked.md) |
| 2026-08-25T04:03:09Z | L2 | iexpress-quoted... | IExpress still failed after quoting target/source paths; ... | [report](errors/20260825-040309-B-iexpress-quoted-path-red.md) |
| 2026-08-25T04:02:34Z | L1 | iexpress-instal... | Initial IExpress SED exited without producing the Windows... | [report](errors/20260825-040234-B-iexpress-installer-red.md) |
| 2026-08-25T03:57:02Z | L2 | release-git-ind... | git add could not create .git/index.lock under the manage... | [report](errors/20260825-035702-B-release-git-index-denied.md) |
| 2026-08-25T03:56:03Z | L3 | release-process... | PowerShell could not stop the running TimeArc UI/service ... | [report](errors/20260825-035603-B-release-process-stop-denied.md) |
| 2026-08-25T03:54:36Z | L3 | readme-trailing... | README rewrites left an extra blank line at EOF and git d... | [report](errors/20260825-035436-B-readme-trailing-blank.md) |
| 2026-08-25T03:33:35Z | L1 | autostart-atomi... | Expected RED: repository ignored autostart decision-marke... | [report](errors/20260825-033335-B-autostart-atomic-marker-red.md) |
| 2026-08-25T03:28:46Z | L1 | release-default... | Final harness check found INDEX at 112 lines and current-... | [report](errors/20260825-032846-B-release-defaults-harness-drift.md) |
| 2026-08-25T03:28:00Z | L3 | rg-access-denie... | rg.exe launch was denied while locating scoped review sym... | [report](errors/20260825-032800-A-rg-access-denied-review.md) |
| 2026-08-25T03:27:45Z | L1 | game-basename-red | Expected RED: substring game detection incorrectly accept... | [report](errors/20260825-032745-B-game-basename-red.md) |
| 2026-08-25T03:27:22Z | L3 | harness-preflig... | preflight blocked by existing harness drift: .harness/jou... | [report](errors/20260825-032722-A-harness-preflight-drift.md) |
| 2026-08-25T03:21:59Z | L1 | native-autostar... | cmake --build exited 1 | [report](errors/20260825-032159-B-native-autostart-registry-green.md) |
| 2026-08-25T03:20:48Z | L1 | native-autostar... | Expected RED: production autostart code still used QSetti... | [report](errors/20260825-032048-B-native-autostart-registry-red.md) |
| 2026-08-25T03:18:33Z | L1 | sqlite-autostar... | Read-only SQLite marker query had PowerShell quoting synt... | [report](errors/20260825-031833-B-sqlite-autostart-query-quoting.md) |
| 2026-08-25T03:14:57Z | L1 | release-default... | cmake --build exited 1 | [report](errors/20260825-031457-B-release-defaults-game-clock-full.md) |
| 2026-08-25T03:14:04Z | L1 | build-wrapper-t... | Focused build target arguments require a double-dash sepa... | [report](errors/20260825-031404-B-build-wrapper-target-separator.md) |
| 2026-08-25T03:11:14Z | L1 | rg-access-denie... | Bundled rg.exe was denied while inspecting release defaul... | [report](errors/20260825-031114-B-rg-access-denied-release-defaults.md) |
| 2026-08-25T03:09:29Z | L1 | game-clock-ui-red | Expected TDD RED: StatsViewModel lacks compact clock lane... | [report](errors/20260825-030929-B-game-clock-ui-red.md) |
| 2026-08-25T03:09:22Z | L1 | release-default... | cmake --build exited 1 | [report](errors/20260825-030922-B-release-defaults-game-clock-red.md) |
| 2026-08-25T03:05:58Z | L3 | tdd-test-guide-... | TDD skill referenced writing-good-tests.md beside SKILL.m... | [report](errors/20260825-030558-B-tdd-test-guide-path.md) |
| 2026-08-25T02:57:53Z | L3 | impeccable-cont... | Impeccable context command referenced a repository-local ... | [report](errors/20260825-025753-B-impeccable-context-path.md) |
| 2026-08-25T02:53:45Z | L1 | custom-name-ind... | Pre-commit harness check found journal INDEX.md at 105 li... | [report](errors/20260825-025345-B-custom-name-index-budget.md) |
| 2026-08-25T02:48:29Z | L1 | rg-execution-de... | Bundled rg.exe was denied by Windows while locating build... | [report](errors/20260825-024829-B-rg-execution-denied.md) |
| 2026-08-25T02:47:21Z | L1 | custom-name-lib... | Green attempt showed StatsViewModel.buildAppLibrary drops... | [report](errors/20260825-024721-B-custom-name-library-propagation.md) |
| 2026-08-25T02:46:19Z | L3 | custom-name-cha... | A custom display-name inspection chained PowerShell comma... | [report](errors/20260825-024619-B-custom-name-chained-inspection.md) |
| 2026-08-25T02:43:14Z | L1 | custom-display-... | Expected TDD failures: settings exposes only custom ID AP... | [report](errors/20260825-024314-B-custom-display-name-ui-red.md) |
| 2026-08-25T02:43:08Z | L1 | custom-display-... | cmake --build exited 1 | [report](errors/20260825-024308-B-custom-display-name-red.md) |
| 2026-08-25T02:41:41Z | L3 | display-name-se... | PowerShell Select-String pattern quoting split a combined... | [report](errors/20260825-024141-B-display-name-search-quoting.md) |
| 2026-08-25T02:29:21Z | L2 | app-identity-in... | A new recorded diagnostic returned rolling INDEX.md to 10... | [report](errors/20260825-022921-B-app-identity-index-recheck.md) |
| 2026-08-25T02:28:56Z | L3 | chained-git-dia... | Pre-commit read-only diagnostics chained three git comman... | [report](errors/20260825-022856-B-chained-git-diagnostics.md) |
| 2026-08-25T02:28:11Z | L2 | app-identity-st... | Exact-file staging was blocked by a stale .git/index.lock... | [report](errors/20260825-022811-B-app-identity-stale-index-lock.md) |
| 2026-08-25T02:26:15Z | L2 | app-identity-in... | Pre-commit harness audit found journal INDEX.md at 110 li... | [report](errors/20260825-022615-B-app-identity-index-budget.md) |
| 2026-08-25T02:21:36Z | L2 | qt-warning-60b8... | [WARNING] :0 - Retrying to obtain clipboard. | [report](errors/20260825-022136-B-qt-warning-60b8e32bf0.md) |
| 2026-08-25T02:21:35Z | L2 | qt-warning-60b8... | [WARNING] :0 - Retrying to obtain clipboard. | [report](errors/20260825-022135-B-qt-warning-60b8e32bf0.md) |
| 2026-08-25T02:21:29Z | L1 | scan-qt-log-opt... | scan_qt_log.py only accepts --log/--track/--dry-run; reru... | [report](errors/20260825-022129-B-scan-qt-log-options.md) |
| 2026-08-25T02:20:23Z | L1 | app-identity-ui... | cmake --build exited 1 | [report](errors/20260825-022023-B-app-identity-ui-build-green.md) |
| 2026-08-25T02:18:15Z | L1 | app-identity-ui... | cmake --build exited 1 | [report](errors/20260825-021815-B-app-identity-ui-build.md) |
| 2026-08-25T02:16:36Z | L1 | app-identity-qm... | Expected TDD failure: settings page has no persisted app ... | [report](errors/20260825-021636-B-app-identity-qml-red.md) |
| 2026-08-25T02:16:05Z | L1 | qml-static-test... | Patch context used the wrong variable name for representa... | [report](errors/20260825-021605-B-qml-static-test-patch-context.md) |
| 2026-08-25T02:13:55Z | L1 | app-identity-ma... | Expected TDD failure: UsageStatManager does not yet expos... | [report](errors/20260825-021355-B-app-identity-manager-red.md) |
| 2026-08-25T02:12:01Z | L1 | app-identity-po... | cmake --build exited 1 | [report](errors/20260825-021201-B-app-identity-policy-red.md) |
| 2026-08-25T02:11:13Z | L2 | rg-access-denie... | Bundled rg.exe was denied by Windows while inspecting db_... | [report](errors/20260825-021113-B-rg-access-denied-app-identity.md) |
| 2026-08-25T02:11:00Z | L2 | rg-stderr-redir... | Combined PowerShell diagnostic used stderr redirection th... | [report](errors/20260825-021100-B-rg-stderr-redirection.md) |
| 2026-08-25T02:05:33Z | L3 | settings-header... | Implementation-plan inspection used SettingsRepository.h ... | [report](errors/20260825-020533-B-settings-header-path-case.md) |
| 2026-08-25T02:03:06Z | L3 | git-index-write... | Sandbox denied .git/index.lock while committing the appro... | [report](errors/20260825-020306-B-git-index-write-denied.md) |
| 2026-08-25T01:55:33Z | L3 | sqlite-apps-las... | Read-only icon investigation query assumed a non-existent... | [report](errors/20260825-015533-B-sqlite-apps-last-seen-assumed.md) |
| 2026-08-25T01:44:35Z | L3 | sqlite-agent-co... | Read-only Codex session query used obsolete title/timesta... | [report](errors/20260825-014435-C-sqlite-agent-columns-assumed.md) |
| 2026-08-25T01:42:44Z | L3 | rg-access-denie... | Bundled rg.exe was denied while locating Codex agent leas... | [report](errors/20260825-014244-C-rg-access-denied-agent-overcount.md) |
| 2026-08-25T01:42:25Z | L2 | codex-post-task... | Codex agent time continued increasing after the five-minu... | [report](errors/20260825-014225-C-codex-post-task-overcount.md) |
| ... | L1/L2/L3 | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |
