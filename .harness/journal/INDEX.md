# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
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
| 2026-06-08 | Feature session | site-icons-video-adapters | [session](sessions/20260608-0938-B-site-icons-video-adapters.md) |
| 2026-05-31 | Frozen change | services-snake-case | [session](sessions/20260531-1138-B-services-snake-case.md) |

## Open issues

Live issues are tracked in [`../state/open-issues.md`](../state/open-issues.md).
