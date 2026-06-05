# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC)           | Lvl | Topic        | Summary                                         | Report |
|----------------------|-----|--------------|-------------------------------------------------|--------|
| 2026-06-05T09:51:50Z | L3 | combined-git-co... | Combined git add and commit command failed with windows s... | [report](errors/20260605-095150-B-combined-git-command-sandbox.md) |
| 2026-06-05T09:48:06Z | L3 | list-docs-super... | Get-ChildItem recursive docs/superpowers listing failed w... | [report](errors/20260605-094806-B-list-docs-superpowers-sandbox.md) |
| 2026-06-05T09:39:18Z | L3 | audio-indent-pa... | Attempted indentation-only patch in audio_win.c failed be... | [report](errors/20260605-093918-B-audio-indent-patch-miss.md) |
| 2026-06-05T09:37:55Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260605-093755-B-build-failure.md) |
| 2026-06-05T09:36:01Z | L3 | accidental-web-... | Accidentally invoked web tool with an empty call while in... | [report](errors/20260605-093601-B-accidental-web-call.md) |
| 2026-06-05T09:35:35Z | L1 | build-failure | cmake --build exited 2 | [report](errors/20260605-093535-B-build-failure.md) |
| 2026-06-05T09:34:47Z | L1 | build-failure | cmake --build exited 2 | [report](errors/20260605-093447-B-build-failure.md) |
| 2026-06-05T09:34:44Z | L3 | recursive-build... | Recursive icacls on build granted several directories but... | [report](errors/20260605-093444-B-recursive-build-acl-partial.md) |
| 2026-06-05T09:34:08Z | L1 | build-failure | cmake --build exited 2 | [report](errors/20260605-093408-B-build-failure.md) |
| 2026-06-05T09:33:27Z | L1 | build-failure | cmake --build exited 2 | [report](errors/20260605-093327-B-build-failure.md) |
| 2026-06-05T09:25:50Z | L3 | icacls-escalate... | Even escalated icacls could not grant modify permission o... | [report](errors/20260605-092550-B-icacls-escalated-denied.md) |
| 2026-06-05T09:25:36Z | L3 | icacls-access-d... | Quoted icacls grant was syntactically valid but failed wi... | [report](errors/20260605-092536-B-icacls-access-denied.md) |
| 2026-06-05T09:25:23Z | L3 | icacls-quote | icacls grant failed because PowerShell parsed unquoted (O... | [report](errors/20260605-092523-B-icacls-quote.md) |
| 2026-06-05T09:24:35Z | L3 | icacls-sandbox | icacls permission repair command failed with windows sand... | [report](errors/20260605-092435-B-icacls-sandbox.md) |
| 2026-06-05T09:24:05Z | L3 | build-log-permi... | Harness build still failed with PermissionError opening b... | [report](errors/20260605-092405-B-build-log-permission-escalated.md) |
| 2026-06-05T09:23:39Z | L3 | build-log-permi... | Baseline harness build failed before compiling because bu... | [report](errors/20260605-092339-B-build-log-permission.md) |
| 2026-06-05T09:22:46Z | L3 | get-content-pip... | Get-Content piped to Select-Object failed with windows sa... | [report](errors/20260605-092246-B-get-content-pipe-sandbox.md) |
| 2026-06-05T09:22:32Z | L3 | select-string-s... | Select-String failed with windows sandbox spawn setup ref... | [report](errors/20260605-092232-B-select-string-sandbox.md) |
| 2026-06-05T09:13:08Z | L3 | final-line-numb... | Final parallel Select-String line-number lookup failed wi... | [report](errors/20260605-091308-C-final-line-number-sandbox.md) |
| 2026-06-05T09:12:08Z | L3 | session-log-pat... | Session log patch failed because expected context did not... | [report](errors/20260605-091208-C-session-log-patch-miss.md) |
| 2026-06-05T08:45:30Z | L3 | wrong-usagestat... | Looked for src/services/UsageStatManager.cpp, but the rep... | [report](errors/20260605-084530-C-wrong-usagestatmanager-path.md) |
| 2026-06-05T08:40:26Z | L3 | select-string-q... | Select-String pattern quoting failed while gathering fina... | [report](errors/20260605-084026-C-select-string-quote.md) |
| 2026-06-05T08:39:34Z | L3 | harness-jsonl-d... | harness_check found an invalid errors.jsonl fragment duri... | [report](errors/20260605-083934-C-harness-jsonl-drift.md) |
| 2026-06-05T08:38:09Z | L3 | rg-access-denied | rg.exe access denied during repo search while gathering s... | [report](errors/20260605-083809-A-rg-access-denied.md) |
| 2026-06-05T08:36:23Z | L3 | sandbox-spawn-r... | Parallel file read failed with windows sandbox spawn setu... | [report](errors/20260605-083623-C-sandbox-spawn-refresh.md) |
| 2026-06-05T08:33:57Z | L3 | wrong-usagestat... | Looked for src/services/UsageStatManager.cpp but the actu... | [report](errors/20260605-083357-C-wrong-usagestatmanager-path.md) |
| 2026-06-05T08:33:10Z | L3 | rg-access-denied | ripgrep failed with Access denied even after escalation w... | [report](errors/20260605-083310-C-rg-access-denied.md) |
| 2026-06-05T08:32:42Z | L2 | wechat-voice-du... | Reported WeChat voice usage duration appears inaccurate; ... | [report](errors/20260605-083242-C-wechat-voice-duration.md) |
| 2026-05-31T08:21:45Z | L3 | git-revert-inde... | git revert failed to create .git/index.lock with Permissi... | [report](errors/20260531-082145-B-git-revert-index-lock.md) |
| 2026-05-31T07:51:29Z | L1 | build-failure | cmake --build exited 2 | [report](errors/20260531-075129-B-build-failure.md) |
| 2026-05-31T07:16:13Z | L3 | rg-access-denied | rg.exe failed with Access is denied while searching qml f... | [report](errors/20260531-071613-B-rg-access-denied.md) |
| 2026-05-31T07:15:41Z | L3 | default-python-... | Default python.exe failed to start during preflight/error... | [report](errors/20260531-071541-B-default-python-launch.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-d7b0... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-d7b0a0f08c.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-7c15... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-7c158ce944.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-8802... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-8802bf6d43.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-b53b... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-b53b5739cc.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-9663... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-96633e7177.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-8909... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-89090b3e3c.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-8cd2... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-8cd225532b.md) |
| 2026-05-31T03:32:44Z | L2 | qt-warning-edae... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033244-C-qt-warning-edaef72713.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-ccc8... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-ccc8e93194.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-a88e... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-a88e5eaecd.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-2495... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-2495f869b5.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-3e22... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-3e22a561f6.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-2780... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-278097f1fa.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-19ca... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-19caff1ea4.md) |
| 2026-05-31T03:32:43Z | L2 | qt-warning-d789... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033243-C-qt-warning-d789f8158d.md) |
| 2026-05-31T03:32:42Z | L2 | qt-warning-29ba... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033242-C-qt-warning-29ba07740f.md) |
| 2026-05-31T03:32:42Z | L2 | qt-warning-61da... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopS... | [report](errors/20260531-033242-C-qt-warning-61da977e22.md) |
| 2026-05-31T03:32:41Z | L2 | qt-warning-61da... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopS... | [report](errors/20260531-033241-C-qt-warning-61da977e22.md) |
| 2026-05-31T03:32:41Z | L2 | qt-warning-bf36... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033241-C-qt-warning-bf369e3bb3.md) |
| 2026-05-31T03:32:41Z | L2 | qt-warning-cd63... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033241-C-qt-warning-cd630d5a2c.md) |
| 2026-05-31T03:32:40Z | L2 | qt-warning-2c3b... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033240-C-qt-warning-2c3b3d0fe0.md) |
| 2026-05-31T03:32:40Z | L2 | qt-warning-d109... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033240-C-qt-warning-d10940b19b.md) |
| 2026-05-31T03:32:40Z | L2 | qt-warning-203d... | [WARNING] qrc:/qt/qml/time_arc/qml/desktop/pages/DesktopC... | [report](errors/20260531-033240-C-qt-warning-203d9a37ce.md) |
| ... | L2 | omitted | Older L2 rows omitted from INDEX; see `errors.jsonl`. | |
| ... | ... | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |

## Session entries

Sessions are logged under `sessions/` when they capture frozen-file changes or
other high-signal context.

| Date          | Kind               | Slug                                  | Link |
|---------------|--------------------|---------------------------------------|------|
| 2026-05-31    | Frozen change      | services-snake-case                   | [session](sessions/20260531-1138-B-services-snake-case.md) |

## Open issues

Live issues are tracked in [`../state/open-issues.md`](../state/open-issues.md).
en issues

Live issues are tracked in [`../state/open-issues.md`](../state/open-issues.md).
