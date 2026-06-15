# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
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
| 2026-06-14T09:42:55Z | L2 | zero-byte-timearc-exe | Runtime launch failed because build/TimeArc.exe was zero bytes after prior relink/start attempt | [report](errors/20260614-094255-C-zero-byte-timearc-exe.md) |
| 2026-06-14T09:41:46Z | L3 | qt-log-rotate-sandbox-denied | scan_qt_log.py could read and record the external Qt log but failed to rotate it under sandbox restrictions | [report](errors/20260614-094146-C-qt-log-rotate-sandbox-denied.md) |
| 2026-06-14T09:18:23Z | L1 | build-output-locked-timearc | Build failed because running TimeArc.exe locked the output binary; stop the app before relinking | [report](errors/20260614-091823-C-build-output-locked-timearc.md) |
| 2026-06-14T09:17:53Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260614-091753-B-build-failure.md) |
| 2026-06-14T09:14:12Z | L2 | app-friendly-name-red-test | TDD red test: timearc_db_smoke fails because WeChat/JianyingPro friendly app names are not registered yet | [report](errors/20260614-091412-C-app-friendly-name-red-test.md) |
| 2026-06-14T09:08:51Z | L2 | ui-app-label-icon-card-regressions | User-reported UI regressions: non-friendly app names, home overlay blocking cards, light sidebar icons white, missing app icons, stats overflow | [report](errors/20260614-090851-C-ui-app-label-icon-card-regressions.md) |
| 2026-06-14T09:07:47Z | L2 | python-windowsapps-placeholder | System python points to WindowsApps placeholder and exits non-zero; using repo .local-python instead | [report](errors/20260614-090747-C-python-windowsapps-placeholder.md) |
| ... | L2 | omitted | Older and duplicate Qt warning rows omitted from INDEX; see `errors.jsonl`. | |
