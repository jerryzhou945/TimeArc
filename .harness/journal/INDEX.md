# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-06-14T09:54:42Z | L3 | errors-jsonl-po... | PowerShell Set-Content rewrote errors.jsonl with a non-UT... | [report](errors/20260614-095442-C-errors-jsonl-powershell-encoding.md) |
| 2026-06-14T09:42:55Z | L2 | zero-byte-timearc-exe | Runtime launch failed because build/TimeArc.exe was zero bytes after prior relink/start attempt | [report](errors/20260614-094255-C-zero-byte-timearc-exe.md) |
| 2026-06-14T09:41:46Z | L3 | qt-log-rotate-sandbox-denied | scan_qt_log.py could read and record the external Qt log but failed to rotate it under sandbox restrictions | [report](errors/20260614-094146-C-qt-log-rotate-sandbox-denied.md) |
| 2026-06-14T09:18:23Z | L1 | build-output-locked-timearc | Build failed because running TimeArc.exe locked the output binary; stop the app before relinking | [report](errors/20260614-091823-C-build-output-locked-timearc.md) |
| 2026-06-14T09:17:53Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260614-091753-B-build-failure.md) |
| 2026-06-14T09:14:12Z | L2 | app-friendly-name-red-test | TDD red test: timearc_db_smoke fails because WeChat/JianyingPro friendly app names are not registered yet | [report](errors/20260614-091412-C-app-friendly-name-red-test.md) |
| 2026-06-14T09:08:51Z | L2 | ui-app-label-icon-card-regressions | User-reported UI regressions: non-friendly app names, home overlay blocking cards, light sidebar icons white, missing app icons, stats overflow | [report](errors/20260614-090851-C-ui-app-label-icon-card-regressions.md) |
| 2026-06-14T09:07:47Z | L2 | python-windowsapps-placeholder | System python points to WindowsApps placeholder and exits non-zero; using repo .local-python instead | [report](errors/20260614-090747-C-python-windowsapps-placeholder.md) |
| ... | L2 | omitted | Older and duplicate Qt warning rows omitted from INDEX; see `errors.jsonl`. | |
