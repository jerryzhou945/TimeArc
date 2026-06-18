# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-06-18T16:33:35Z | L3 | env-enumeration... | PowerShell Get-ChildItem Env: failed with duplicate key w... | [report](errors/20260618-163335-B-env-enumeration-duplicate-key.md) |
| 2026-06-18T16:26:50Z | L3 | timearc-adapter... | Final structural check treated TimeArc display text as a ... | [report](errors/20260618-162650-B-timearc-adapter-check-overstrict.md) |
| 2026-06-18T16:24:31Z | L1 | timearc-db-smok... | After clearing the Qt test data directory, timearc_db_smo... | [report](errors/20260618-162431-B-timearc-db-smoke-test-dir-create.md) |
| 2026-06-18T16:23:39Z | L3 | get-process-no-... | Get-Process timearc_db_smoke returned non-zero while chec... | [report](errors/20260618-162339-B-get-process-no-db-smoke.md) |
| 2026-06-18T16:23:20Z | L1 | timearc-db-smok... | After fixing TimeArc adapter matching, ctest still failed... | [report](errors/20260618-162320-B-timearc-db-smoke-test-data-dir.md) |
| 2026-06-18T16:20:45Z | L1 | timearc-db-smok... | ctest --test-dir build --output-on-failure reported timea... | [report](errors/20260618-162045-B-timearc-db-smoke-ctest.md) |
| 2026-06-18T16:17:38Z | L3 | get-process-no-... | Get-Process TimeArc returned non-zero while checking for ... | [report](errors/20260618-161738-B-get-process-no-timearc-before-build.md) |
| 2026-06-18T16:16:17Z | L2 | timearc-adapter... | Expected red structural check confirmed TimeArc is not ye... | [report](errors/20260618-161617-B-timearc-adapter-red-test.md) |
| 2026-06-18T16:05:06Z | L3 | select-string-p... | Select-String pattern array was quoted incorrectly around... | [report](errors/20260618-160506-B-select-string-pattern-quoting.md) |
| 2026-06-18T16:05:06Z | L3 | adapter-registr... | Looked for activity_adapter_registry.cpp, but the adapter... | [report](errors/20260618-160506-B-adapter-registry-path.md) |
| 2026-06-18T16:04:22Z | L3 | dist-missing-probe | Probed dist/ directly before checking existence; Get-Chil... | [report](errors/20260618-160422-B-dist-missing-probe.md) |
| 2026-06-18T16:03:59Z | L3 | powershell-sear... | Used Get-ChildItem with multiple bare positional paths an... | [report](errors/20260618-160359-B-powershell-search-syntax.md) |
| 2026-06-18T16:03:19Z | L3 | rg-access-denied | rg was approved but failed to execute with Access is deni... | [report](errors/20260618-160319-B-rg-access-denied.md) |
| 2026-06-18T16:02:35Z | L3 | python-entrypoint | Assumed bare python would run harness, but it resolved to... | [report](errors/20260618-160235-B-python-entrypoint.md) |
| 2026-06-18T15:45:48Z | L3 | app-icon-resolv... | After adding icon resolver, the structural check still fa... | [report](errors/20260618-154548-C-app-icon-resolver-check-mismatch.md) |
| 2026-06-18T15:43:19Z | L2 | app-icon-resolv... | Expected red structural check confirmed AppIconImageProvi... | [report](errors/20260618-154319-C-app-icon-resolver-red-test.md) |
| 2026-06-18T15:43:19Z | L2 | home-english-ca... | Expected red test confirmed I18n.smartText leaves Chinese... | [report](errors/20260618-154319-C-home-english-category-list-red-test.md) |
| 2026-06-18T15:41:14Z | L3 | stats-service-f... | Looked for non-existent src/services/StatsService.cpp whi... | [report](errors/20260618-154114-C-stats-service-filename-case.md) |
| 2026-06-18T15:40:18Z | L3 | rg-access-denie... | ripgrep failed with Access denied while locating remainin... | [report](errors/20260618-154018-C-rg-access-denied-english-icons-mac-doc.md) |
| 2026-06-18T15:39:40Z | L2 | stats-app-icons... | Stats app lists frequently show initial-letter placeholde... | [report](errors/20260618-153940-C-stats-app-icons-fallback-initials.md) |
| 2026-06-18T15:39:40Z | L2 | home-english-ge... | English Home generated summary text still contains raw Ch... | [report](errors/20260618-153940-C-home-english-generated-tags-chinese.md) |
| 2026-06-18T15:18:40Z | L2 | home-tag-combob... | Expected red structural check confirmed Home add-project ... | [report](errors/20260618-151840-C-home-tag-combobox-red-test.md) |
| 2026-06-18T15:17:14Z | L2 | home-tags-still... | Home page tags/categories such as 社交 and 开发 still appear ... | [report](errors/20260618-151714-C-home-tags-still-chinese.md) |
| 2026-06-18T15:17:14Z | L3 | sandbox-doc-sea... | A parallel Select-String documentation search failed with... | [report](errors/20260618-151714-C-sandbox-doc-search-createprocess.md) |
| 2026-06-18T07:20:07Z | L3 | get-process-no-... | Get-Process TimeArc returned non-zero while checking for ... | [report](errors/20260618-072007-C-get-process-no-timearc-after-scan.md) |
| 2026-06-18T07:19:43Z | L3 | harness-check-s... | harness_check failed because the new C session log linked... | [report](errors/20260618-071943-C-harness-check-session-link.md) |
| 2026-06-18T07:19:24Z | L2 | qt-warning-60b8... | [WARNING] :0 - Retrying to obtain clipboard. | [report](errors/20260618-071924-C-qt-warning-60b8e32bf0.md) |
| 2026-06-18T07:15:59Z | L1 | remaining-engli... | build.py failed after remaining English copy and heatmap ... | [report](errors/20260618-071559-C-remaining-english-heatmap-build-failure.md) |
| 2026-06-18T07:10:59Z | L2 | remaining-engli... | English mode still shows Chinese generated keywords/card-... | [report](errors/20260618-071059-C-remaining-english-keywords-heatmap.md) |
| 2026-06-18T06:45:44Z | L3 | get-process-aft... | After stopping TimeArc, a follow-up Get-Process check ret... | [report](errors/20260618-064544-C-get-process-after-stop-nonzero.md) |
| 2026-06-18T06:45:11Z | L1 | build-exe-permi... | Build failed at link because TimeArc.exe could not be ove... | [report](errors/20260618-064511-C-build-exe-permission-denied.md) |
| 2026-06-18T06:36:42Z | L3 | rg-access-denie... | ripgrep failed with Access denied while locating remainin... | [report](errors/20260618-063642-C-rg-access-denied-copy-heatmap.md) |
| 2026-06-18T06:35:37Z | L2 | english-copy-he... | English mode still shows Chinese in Home card backs/timel... | [report](errors/20260618-063537-C-english-copy-heatmap-gaps.md) |
| 2026-06-18T04:19:53Z | L3 | remote-branch-a... | After PR #36 merged, GitHub had already deleted the remot... | [report](errors/20260618-041953-C-remote-branch-already-deleted.md) |
| 2026-06-18T04:11:58Z | L2 | qt-warning-d5e3... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Gla... | [report](errors/20260618-041158-C-qt-warning-d5e39ad0f2.md) |
| 2026-06-18T04:11:58Z | L2 | qt-warning-f827... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Gla... | [report](errors/20260618-041158-C-qt-warning-f8277923d2.md) |
| 2026-06-18T04:11:57Z | L2 | qt-warning-f827... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Gla... | [report](errors/20260618-041157-C-qt-warning-f8277923d2.md) |
| 2026-06-18T04:11:56Z | L2 | qt-warning-f827... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Gla... | [report](errors/20260618-041156-C-qt-warning-f8277923d2.md) |
| 2026-06-18T04:05:54Z | L3 | powershell-quot... | A Select-String command used an invalid quoted pattern wh... | [report](errors/20260618-040554-C-powershell-quote-pattern.md) |
| 2026-06-18T04:04:14Z | L3 | rg-access-denied | ripgrep failed with Access denied while scanning QML for ... | [report](errors/20260618-040414-C-rg-access-denied.md) |
| 2026-06-18T04:03:22Z | L2 | english-copy-gaps | English language mode still shows Chinese copy in home th... | [report](errors/20260618-040322-C-english-copy-gaps.md) |
| 2026-06-18T04:03:03Z | L3 | stale-skill-cac... | Attempted to read superpowers skill files from stale plug... | [report](errors/20260618-040303-C-stale-skill-cache-path.md) |
| 2026-06-15T07:55:35Z | L3 | qt-log-file-gon... | After scan_qt_log recorded warnings, attempted to read th... | [report](errors/20260615-075535-C-qt-log-file-gone-read.md) |
| 2026-06-15T07:54:50Z | L2 | qt-warning-215b... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Gla... | [report](errors/20260615-075450-C-qt-warning-215b10b9d6.md) |
| 2026-06-15T07:54:49Z | L2 | qt-warning-215b... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/memorylake/Gla... | [report](errors/20260615-075449-C-qt-warning-215b10b9d6.md) |
| 2026-06-15T07:20:42Z | L3 | powershell-angl... | Used a PowerShell -Filter pattern containing angle bracke... | [report](errors/20260615-072042-C-powershell-angle-filter.md) |
| 2026-06-15T07:20:04Z | L2 | i18n-residual-c... | English language mode still shows Chinese residual copy a... | [report](errors/20260615-072004-C-i18n-residual-chinese-copy.md) |
| 2026-06-15T07:03:29Z | L1 | remote-branch-a... | Attempted to delete origin/codex/global-runtime-i18n afte... | [report](errors/20260615-070329-B-remote-branch-already-deleted.md) |
| 2026-06-15T07:01:58Z | L1 | gh-cli-missing | GitHub CLI was not available while trying to publish the ... | [report](errors/20260615-070158-B-gh-cli-missing.md) |
| 2026-06-15T06:55:30Z | L1 | build-timeout-g... | build.py timed out after 124 seconds while rebuilding aft... | [report](errors/20260615-065530-B-build-timeout-global-i18n.md) |
| 2026-06-15T06:51:18Z | L2 | qt-warning-7dbd... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/components/I18... | [report](errors/20260615-065118-C-qt-warning-7dbd33b2ee.md) |
| 2026-06-15T06:51:17Z | L2 | qt-warning-220c... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/DesktopAppShel... | [report](errors/20260615-065117-C-qt-warning-220cf9a712.md) |
| 2026-06-15T06:51:17Z | L2 | qt-warning-4107... | [WARNING] qrc:/qt/qml/time_arc/qml/main.qml:71 - qrc:/qt/... | [report](errors/20260615-065117-C-qt-warning-41071e1aed.md) |
| 2026-06-15T06:51:17Z | L2 | qt-warning-882f... | [WARNING] :0 - QQmlApplicationEngine failed to load compo... | [report](errors/20260615-065117-C-qt-warning-882fece6aa.md) |
| 2026-06-15T06:48:19Z | L3 | ui-rule-line-bu... | harness_check failed because .harness/rules/04-ui-convent... | [report](errors/20260615-064819-B-ui-rule-line-budget.md) |
| 2026-06-15T05:46:42Z | L3 | remote-branch-a... | After PR #32 merge, git push origin --delete fix/ui-stats... | [report](errors/20260615-054642-C-remote-branch-already-deleted.md) |
| 2026-06-15T05:33:14Z | L2 | qt-warning-2d52... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/DesktopAppShel... | [report](errors/20260615-053314-C-qt-warning-2d5254925d.md) |
| 2026-06-15T05:31:18Z | L3 | process-check-n... | After stopping TimeArc, the follow-up Get-Process check r... | [report](errors/20260615-053118-C-process-check-nonzero.md) |
| 2026-06-15T05:30:19Z | L1 | ui-followup-bui... | Harness build failed after UI follow-up commits; inspecti... | [report](errors/20260615-053019-C-ui-followup-build-failure.md) |
| 2026-06-15T05:30:05Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260615-053005-B-build-failure.md) |
| 2026-06-15T05:15:18Z | L3 | missing-adapter... | Looked for a non-existent adapter_registry.cpp; desktop a... | [report](errors/20260615-051518-C-missing-adapter-registry-cpp.md) |
| 2026-06-15T05:13:56Z | L3 | powershell-sele... | Used Select-Object -Index with a string range; PowerShell... | [report](errors/20260615-051356-C-powershell-select-index-range.md) |
| 2026-06-15T05:12:24Z | L2 | ui-stats-memory... | Stats heatmap underfills its card, monthly top apps overf... | [report](errors/20260615-051224-C-ui-stats-memorylake-language-followups.md) |
| 2026-06-15T05:11:52Z | L3 | rg-access-denied | rg.exe failed with Access is denied while searching UI re... | [report](errors/20260615-051152-C-rg-access-denied.md) |
| 2026-06-14T09:59:59Z | L3 | gh-cli-missing-... | GitHub publish flow requested but gh is not available in ... | [report](errors/20260614-095959-C-gh-cli-missing-for-pr-flow.md) |
| 2026-06-14T09:54:42Z | L3 | errors-jsonl-po... | PowerShell Set-Content rewrote errors.jsonl with a non-UT... | [report](errors/20260614-095442-C-errors-jsonl-powershell-encoding.md) |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| 2026-06-14T09:41:46Z | L3 | qt-log-rotate-sandbox-denied | scan_qt_log.py could read and record the external Qt log but failed to rotate it under sandbox restrictions | [report](errors/20260614-094146-C-qt-log-rotate-sandbox-denied.md) |
| 2026-06-14T09:18:23Z | L1 | build-output-locked-timearc | Build failed because running TimeArc.exe locked the output binary; stop the app before relinking | [report](errors/20260614-091823-C-build-output-locked-timearc.md) |
| 2026-06-14T09:17:53Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260614-091753-B-build-failure.md) |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| ... | L2 | omitted | Older and duplicate Qt warning rows omitted from INDEX; see `errors.jsonl`. | |
