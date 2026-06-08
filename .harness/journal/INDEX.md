# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
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
