# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-06-13T21:48:14Z | L3 | sqlite-inspecti... | SQLite inspection printed media rows containing emoji to ... | [report](errors/20260613-214814-B-sqlite-inspection-output-encoding.md) |
| 2026-06-13T21:47:42Z | L3 | sqlite-query-in... | Inline python -c SQLite inspection command used escaped n... | [report](errors/20260613-214742-B-sqlite-query-inline-python-escape.md) |
| 2026-06-13T21:14:13Z | L2 | bilibili-icon-t... | build.py timed out at the tool limit while compiling Bili... | [report](errors/20260613-211413-B-bilibili-icon-timeriver-build-timeout.md) |
| 2026-06-13T20:57:23Z | L3 | gpp-smoke-journ... | Temporary g++ smoke source was written under .harness/jou... | [report](errors/20260613-205723-B-gpp-smoke-journal-source.md) |
| 2026-06-13T20:52:57Z | L1 | settings-export... | cmake --build exited 1 | [report](errors/20260613-205257-B-settings-export-ui-build-verbose.md) |
| 2026-06-13T20:52:28Z | L1 | settings-export... | cmake --build exited 1 | [report](errors/20260613-205228-B-settings-export-ui-build.md) |
| 2026-06-13T20:40:41Z | L3 | tdd-before-desi... | Loaded TDD skill before completing brainstorming approval... | [report](errors/20260613-204041-B-tdd-before-design-approval.md) |
| 2026-06-13T20:08:55Z | L3 | powershell-pyth... | Tried to run python with bash-style heredoc in PowerShell... | [report](errors/20260613-200855-C-powershell-python-heredoc.md) |
| 2026-06-13T20:07:50Z | L3 | shell-path-not-... | After writing User PATH, a new tool-launched PowerShell s... | [report](errors/20260613-200750-C-shell-path-not-reloaded.md) |
| 2026-06-13T20:06:41Z | L1 | cmake-not-in-path | cmake was not discoverable from PATH; D-drive Qt CMake ex... | [report](errors/20260613-200641-C-cmake-not-in-path.md) |
| 2026-06-13T19:49:58Z | L3 | switch-blocked-... | git switch -c codex/app-icon-normal-centered origin/dev w... | [report](errors/20260613-194958-C-switch-blocked-harness-edits.md) |
| 2026-06-13T19:47:09Z | L3 | error-report-pa... | apply_patch failed while filling app-icon-small-corner er... | [report](errors/20260613-194709-C-error-report-patch-context.md) |
| 2026-06-13T19:42:34Z | L3 | chained-shell-c... | Bundled multiple git show calls with semicolons instead o... | [report](errors/20260613-194234-C-chained-shell-command.md) |
| 2026-06-13T19:41:45Z | L1 | build-cmake-mis... | Baseline harness build failed because cmake executable wa... | [report](errors/20260613-194145-C-build-cmake-missing.md) |
| 2026-06-13T19:40:55Z | L2 | app-icon-small-... | Native software icon renders as a tiny pixel/detail in th... | [report](errors/20260613-194055-C-app-icon-small-corner.md) |
| 2026-06-13T19:40:29Z | L3 | rg-access-denie... | rg failed with Access is denied while searching for icon ... | [report](errors/20260613-194029-C-rg-access-denied-repeat.md) |
| 2026-06-13T19:39:51Z | L3 | wrong-session-t... | Tried to read .harness/templates/session.md; actual templ... | [report](errors/20260613-193951-C-wrong-session-template.md) |
| 2026-06-13T19:39:12Z | L3 | preflight-pytho... | System python/py launchers failed while running harness p... | [report](errors/20260613-193912-C-preflight-python-launcher.md) |
| 2026-06-13T10:30:19Z | L3 | app-icon-dpr-ce... | AppIconImageProvider transparent-padding crop used QPixma... | [report](errors/20260613-103019-B-app-icon-dpr-centering-regression.md) |
| 2026-06-13T10:07:03Z | L3 | gh-cli-missing | GitHub CLI is not available; using git push and connector... | [report](errors/20260613-100703-B-gh-cli-missing.md) |
| 2026-06-13T09:54:29Z | L3 | todo-checkbox-p... | CalendarSyncList patch failed around localized checkmark ... | [report](errors/20260613-095429-B-todo-checkbox-patch-context.md) |
| 2026-06-13T09:52:56Z | L3 | rg-access-denied | rg.exe access denied in current PowerShell session; using... | [report](errors/20260613-095256-B-rg-access-denied.md) |
| 2026-06-13T09:29:27Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260613-092927-B-build-failure.md) |
| 2026-06-13T09:29:11Z | L1 | build-cmake-not... | build.py failed before compilation because cmake was not ... | [report](errors/20260613-092911-B-build-cmake-not-found.md) |
| 2026-06-13T09:26:17Z | L3 | stash-apply-jou... | git stash apply for prior harness journal failed because ... | [report](errors/20260613-092617-B-stash-apply-journal-conflict.md) |
| 2026-06-13T09:25:41Z | L3 | powershell-stas... | git stash show stash@{0} failed because PowerShell split ... | [report](errors/20260613-092541-B-powershell-stash-ref-quoting.md) |
| 2026-06-13T09:23:04Z | L3 | white-icon-patc... | apply_patch failed because stats_white.svg content did no... | [report](errors/20260613-092304-B-white-icon-patch-context.md) |
| 2026-06-13T09:17:29Z | L3 | switch-blocked-... | git switch dev was blocked by preflight-updated .harness/... | [report](errors/20260613-091729-B-switch-blocked-current-track.md) |
| 2026-06-13T09:00:03Z | L3 | gh-cli-missing | gh CLI not found while trying to create PR for git workfl... | [report](errors/20260613-090003-A-gh-cli-missing.md) |
| 2026-06-11T11:11:51Z | L3 | f2-qrc-xhr-bloc... | F2 loader: kickoff's recommended pure-QML XMLHttpRequest ... | [report](errors/20260611-111151-B-f2-qrc-xhr-blocked-use-readtextfile.md) |
| 2026-06-09T11:00:22Z | L3 | env-fs-overlay-... | File tools (Edit/Write) landed in an overlay FS the compi... | [report](errors/20260609-110022-B-env-fs-overlay-wrong-branch.md) |
| 2026-06-08T07:23:43Z | L1 | powershell-plac... | Tried to read a preflight placeholder session path contai... | [report](errors/20260608-072343-B-powershell-placeholder-path.md) |
| 2026-06-08T07:18:42Z | L1 | remote-feature-... | git push origin --delete feature/adapter-support-system f... | [report](errors/20260608-071842-B-remote-feature-branch-absent.md) |
| 2026-06-08T07:00:04Z | L1 | desktop-adapter... | TDD red test: timearc_db_smoke failed after adding Chrome... | [report](errors/20260608-070004-B-desktop-adapters-red-test.md) |
| 2026-06-08T06:57:05Z | L1 | apply-patch-wor... | apply_patch defaulted to the primary workspace while edit... | [report](errors/20260608-065705-B-apply-patch-worktree-path.md) |
| 2026-06-08T06:56:13Z | L1 | rg-access-denied | rg --files failed with Access is denied in adapter suppor... | [report](errors/20260608-065613-B-rg-access-denied.md) |
| 2026-06-08T06:52:44Z | L1 | website-adapter... | timearc_db_smoke failed after adding website adapter expe... | [report](errors/20260608-065244-B-website-adapters-red-test.md) |
| 2026-06-08T06:48:40Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260608-064840-B-build-failure.md) |
| 2026-06-08T06:47:00Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260608-064700-B-build-failure.md) |
| 2026-06-08T06:45:52Z | L1 | worktree-mingw-... | CMake compiler test failed in linked worktree because Min... | [report](errors/20260608-064552-B-worktree-mingw-path-missing.md) |
| 2026-06-08T06:45:20Z | L1 | worktree-cmake-... | CMake configure in linked worktree failed because Ninja w... | [report](errors/20260608-064520-B-worktree-cmake-ninja-not-found.md) |
| 2026-06-08T06:44:46Z | L1 | worktree-build-... | build.py in the linked worktree failed before compiling b... | [report](errors/20260608-064446-B-worktree-build-cmake-not-found.md) |
| 2026-06-08T06:42:28Z | L3 | worktree-local-... | linked worktree does not contain untracked .local-python ... | [report](errors/20260608-064228-B-worktree-local-python-missing.md) |
| 2026-06-08T02:41:07Z | L3 | remote-branch-a... | git push origin --delete codex/site-icons-video-adapters ... | [report](errors/20260608-024107-B-remote-branch-already-deleted.md) |
| 2026-06-08T02:13:22Z | L3 | harness-index-line-budget-repeat | harness_check still counted INDEX above the 100-line budget after automatic compaction. | [report](errors/20260608-021322-B-harness-index-line-budget-repeat.md) |
| 2026-06-08T02:12:32Z | L3 | harness-index-line-budget | harness_check failed because INDEX exceeded the 100-line budget. | [report](errors/20260608-021232-B-harness-index-line-budget.md) |
| 2026-06-08T02:05:21Z | L2 | smoke-exit-empty | timearc_db_smoke.exe exited 1 without visible output until Qt/MinGW runtime PATH was added. | [report](errors/20260608-020521-B-smoke-exit-empty.md) |
| 2026-06-08T02:00:53Z | L1 | site-catalog-smoke-build-verbose | Smoke target build failed before MinGW runtime PATH was added. | [report](errors/20260608-020053-B-site-catalog-smoke-build-verbose.md) |
| 2026-06-08T02:00:10Z | L1 | site-catalog-smoke-build | Smoke target build failed before MinGW runtime PATH was added. | [report](errors/20260608-020010-B-site-catalog-smoke-build.md) |
| 2026-06-08T01:56:23Z | L3 | cmake-path-missing | build.py could not launch cmake because PATH missed CMake. | [report](errors/20260608-015623-B-cmake-path-missing.md) |
| 2026-06-08T01:55:53Z | L3 | build-target-arg-unsupported | Plan used unsupported build.py --target syntax. | [report](errors/20260608-015553-B-build-target-arg-unsupported.md) |
| 2026-06-08T01:43:48Z | L3 | icon-dir-wrong-path | Looked for qml/resources/icons before confirming resources/icons. | [report](errors/20260608-014348-B-icon-dir-wrong-path.md) |
| 2026-06-08T01:39:05Z | L3 | git-path-missing | Plain git was not on PATH in the current shell. | [report](errors/20260608-013905-B-git-path-missing.md) |
| 2026-06-08T01:39:05Z | L3 | rg-access-denied | rg --files docs failed with Access denied. | [report](errors/20260608-013905-B-rg-access-denied.md) |
| 2026-06-08T01:37:59Z | L2 | preflight-python-stub | Default python resolved to WindowsApps stub. | [report](errors/20260608-013759-B-preflight-python-stub.md) |
| ... | n/a | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |

## Session entries

Sessions are logged under `sessions/` when they capture frozen-file changes or
other high-signal context.

| Date | Kind | Slug | Link |
|------|------|------|------|
| 2026-06-11 | Frozen change (CHARTER v0.4) | h5-gap-closing-charter-v04 | [session](sessions/20260611-1401-B-h5-gap-closing-charter-v04.md) |
| 2026-06-11 | Feature session | h5-service-config-channel | [session](sessions/20260611-1202-B-h5-service-config-channel.md) |
| 2026-06-08 | Feature session | site-icons-video-adapters | [session](sessions/20260608-0938-B-site-icons-video-adapters.md) |
| 2026-05-31 | Frozen change | services-snake-case | [session](sessions/20260531-1138-B-services-snake-case.md) |

## Open issues

Live issues are tracked in [`../state/open-issues.md`](../state/open-issues.md).
