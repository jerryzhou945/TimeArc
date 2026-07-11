# Journal Index

Rolling, human-friendly index of recent notable reports. The authoritative
machine-readable log is `errors.jsonl`; older rows may be omitted here to keep
the harness line budget intact.

## Error entries

| Date (UTC) | Lvl | Topic | Summary | Report |
|------------|-----|-------|---------|--------|
| 2026-07-11T14:17:14Z | L1 | live-snapshot-r... | cmake --build exited 2 | [report](errors/20260711-141714-B-live-snapshot-retirement-ui-build.md) |
| 2026-07-11T14:16:33Z | L1 | live-snapshot-r... | cmake --build exited 1 | [report](errors/20260711-141633-B-live-snapshot-retirement-ui-build.md) |
| 2026-07-11T14:09:40Z | L3 | missing-bridge-... | Inspection assumed a macOS bridging-header filename that ... | [report](errors/20260711-140940-B-missing-bridge-header-path.md) |
| 2026-07-11T13:54:48Z | L3 | unlisted-frozen... | Changed a stale comment in frozen database_path.c before ... | [report](errors/20260711-135448-B-unlisted-frozen-comment.md) |
| 2026-07-11T13:54:30Z | L2 | db-smoke-idempo... | DB smoke test failed on the pre-existing legacy project m... | [report](errors/20260711-135430-B-db-smoke-idempotence.md) |
| 2026-07-11T13:51:09Z | L3 | stale-patch-con... | A multi-file documentation patch failed because the Track... | [report](errors/20260711-135109-B-stale-patch-context.md) |
| 2026-07-11T13:43:30Z | L1 | baseline-build | cmake --build exited 2 | [report](errors/20260711-134330-B-baseline-build.md) |
| 2026-07-11T13:39:37Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260711-133937-B-build-failure.md) |
| 2026-07-11T13:38:01Z | L3 | git-readonly-br... | Creating the required feature branch failed because the s... | [report](errors/20260711-133801-B-git-readonly-branch.md) |
| 2026-07-11T13:37:36Z | L3 | missing-dev-branch | Git workflow check assumed a local dev branch, but this c... | [report](errors/20260711-133736-B-missing-dev-branch.md) |
| 2026-07-10T13:58:47Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260710-135847-B-build-failure.md) |
| 2026-07-09T10:11:45Z | L3 | shell-backtick-... | Ran rg with unescaped Markdown backticks in the shell pat... | [report](errors/20260709-101145-B-shell-backtick-pattern.md) |
| 2026-07-09T10:01:09Z | L2 | preflight-froze... | Preflight failed because frozen files src/service/shared/... | [report](errors/20260709-100109-B-preflight-frozen-drift.md) |
| 2026-07-09T10:00:39Z | L2 | preflight-drift | preflight failed because frozen-file hash drift exists in... | [report](errors/20260709-100039-B-preflight-drift.md) |
| 2026-07-09T09:38:53Z | L2 | remaining-froze... | harness_check after database_path comments still fails on... | [report](errors/20260709-093853-B-remaining-frozen-drift.md) |
| 2026-07-09T09:37:20Z | L2 | preflight-drift | Preflight before database_path comments is blocked by exi... | [report](errors/20260709-093720-B-preflight-drift.md) |
| 2026-07-09T09:35:21Z | L2 | remaining-froze... | Final harness_check after database_path rename still fail... | [report](errors/20260709-093521-B-remaining-frozen-drift.md) |
| 2026-07-09T09:34:43Z | L2 | frozen-hash-drift | harness_check failed after database_path rename because f... | [report](errors/20260709-093443-B-frozen-hash-drift.md) |
| 2026-07-09T09:27:31Z | L2 | preflight-drift | Track B preflight reported existing harness drift before ... | [report](errors/20260709-092731-B-preflight-drift.md) |
| 2026-07-09T09:27:20Z | L3 | wrong-track | Initial Track A classification was too narrow because req... | [report](errors/20260709-092720-A-wrong-track.md) |
| 2026-07-09T09:26:50Z | L2 | preflight-drift | Preflight reported existing harness drift before coding, ... | [report](errors/20260709-092650-A-preflight-drift.md) |
| 2026-07-08T16:51:32Z | L3 | ctest-home-over... | Setting HOME to /private/tmp did not move macOS QStandard... | [report](errors/20260708-165132-B-ctest-home-override-ineffective.md) |
| 2026-07-08T16:51:13Z | L2 | ctest-qstandard... | ctest failed because QStandardPaths test mode tried to cl... | [report](errors/20260708-165113-B-ctest-qstandardpaths-sandbox.md) |
| 2026-07-08T16:50:31Z | L3 | build-escalatio... | Escalated harness build request was rejected by approval ... | [report](errors/20260708-165031-B-build-escalation-rejected.md) |
| 2026-07-08T16:32:55Z | L2 | preflight-drift | Preflight blocked by existing harness/frozen-file drift b... | [report](errors/20260708-163255-B-preflight-drift.md) |
| 2026-07-08T16:13:28Z | L1 | preflight-drift | Preflight failed due to existing harness drift before db_... | [report](errors/20260708-161328-B-preflight-drift.md) |
| 2026-07-08T16:09:23Z | L3 | chained-read-co... | Used a chained read-only shell command while gathering fi... | [report](errors/20260708-160923-A-chained-read-command.md) |
| 2026-07-08T16:05:30Z | L1 | preflight-drift | Preflight failed due to existing harness drift in journal... | [report](errors/20260708-160530-A-preflight-drift.md) |
| 2026-07-08T15:58:33Z | L2 | ctest-qstandard... | ctest timearc_db_smoke failed in sandbox because Qt test ... | [report](errors/20260708-155833-B-ctest-qstandardpaths-sandbox.md) |
| 2026-07-08T15:56:36Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260708-155636-B-build-failure.md) |
| 2026-07-08T15:51:19Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260708-155119-B-build-failure.md) |
| 2026-07-08T15:49:42Z | L3 | stale-text-rg-e... | A stale-text rg search used an invalid backslash escape w... | [report](errors/20260708-154942-B-stale-text-rg-escape.md) |
| 2026-07-08T15:42:40Z | L3 | cmake-path-rg-miss | Exploratory rg included a non-existent cmake directory wh... | [report](errors/20260708-154240-B-cmake-path-rg-miss.md) |
| 2026-07-08T15:38:58Z | L1 | preflight-drift | Preflight failed due to existing harness drift in .harnes... | [report](errors/20260708-153858-B-preflight-drift.md) |
| 2026-07-08T15:31:16Z | L3 | preflight-drift | Preflight reported existing harness drift before a read-o... | [report](errors/20260708-153116-A-preflight-drift.md) |
| 2026-07-08T15:26:44Z | L1 | preflight-drift | Preflight failed due to existing harness drift: journal i... | [report](errors/20260708-152644-A-preflight-drift.md) |
| 2026-07-07T15:24:15Z | L3 | qtpaths-option-... | qtpaths6 option probes for overriding application name fa... | [report](errors/20260707-152415-A-qtpaths-option-probe.md) |
| 2026-07-07T15:22:37Z | L3 | missing-macos-b... | Lookup included IDE tab path src/service/macos.backup, bu... | [report](errors/20260707-152237-A-missing-macos-backup-path.md) |
| 2026-07-07T15:21:30Z | L2 | preflight-drift | Preflight failed before investigation: .harness/journal/I... | [report](errors/20260707-152130-A-preflight-drift.md) |
| 2026-07-07T11:17:47Z | L3 | sqlite-schema-s... | Search included a nonexistent macOS backup directory whil... | [report](errors/20260707-111747-A-sqlite-schema-search-path.md) |
| 2026-07-07T09:40:08Z | L3 | missing-optiona... | Checked optional macos.backup/cmake paths that do not exi... | [report](errors/20260707-094008-B-missing-optional-paths.md) |
| 2026-07-06T10:26:59Z | L3 | qt-path-probe-c... | Temporary Qt path probe compile failed because the comman... | [report](errors/20260706-102659-A-qt-path-probe-cxx-standard.md) |
| 2026-07-06T10:25:33Z | L3 | qt-python-bindi... | Optional PySide6/PyQt6 probe was unavailable while checki... | [report](errors/20260706-102533-A-qt-python-binding-probe.md) |
| 2026-07-02T17:36:45Z | L3 | data-bridge-imp... | Looked for src/service/shared/data_bridge.c, but the data... | [report](errors/20260702-173645-A-data-bridge-implementation-path.md) |
| 2026-07-02T16:46:53Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260702-164653-B-build-failure.md) |
| 2026-07-02T16:38:16Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260702-163816-B-build-failure.md) |
| 2026-06-19T07:57:02Z | L2 | recursive-selec... | A recursive Select-String audit tried to read directories... | [report](errors/20260619-075702-A-recursive-select-string-directories.md) |
| 2026-06-18T21:27:51Z | L2 | staged-diff-tra... | git diff --cached --check found trailing whitespace in th... | [report](errors/20260618-212751-B-staged-diff-trailing-whitespace.md) |
| 2026-06-18T21:25:26Z | L2 | open-issues-lin... | harness_check failed because .harness/state/open-issues.m... | [report](errors/20260618-212526-B-open-issues-line-budget.md) |
| 2026-06-18T21:21:18Z | L1 | build-failure | cmake --build exited 1 | [report](errors/20260618-212118-B-build-failure.md) |
| 2026-06-18T21:08:16Z | L2 | gh-cli-not-found | gh CLI is not available in this workspace; PR creation wi... | [report](errors/20260618-210816-B-gh-cli-not-found.md) |
| 2026-06-18T21:03:47Z | L2 | open-issues-lin... | harness_check failed because .harness/state/open-issues.m... | [report](errors/20260618-210347-B-open-issues-line-budget.md) |
| 2026-06-18T21:02:30Z | L2 | swiftc-not-avai... | Windows workspace has no swiftc, so macOS helper compile/... | [report](errors/20260618-210230-B-swiftc-not-available-on-windows.md) |
| 2026-06-18T20:56:20Z | L2 | rg-access-denied | rg was denied by Windows while running red structural che... | [report](errors/20260618-205620-B-rg-access-denied.md) |
| 2026-06-18T20:51:19Z | L3 | stale-superpowe... | Attempted to read Superpowers brainstorming/writing-plans... | [report](errors/20260618-205119-B-stale-superpowers-skill-cache-path.md) |
| 2026-06-18T16:38:03Z | L3 | chrome-mcp-rele... | Chrome MCP failed to connect while attempting to open the... | [report](errors/20260618-163803-B-chrome-mcp-release-ui-unavailable.md) |
| 2026-06-18T16:33:35Z | L3 | env-enumeration... | PowerShell Get-ChildItem Env: failed with duplicate key w... | [report](errors/20260618-163335-B-env-enumeration-duplicate-key.md) |
| 2026-06-18T16:26:50Z | L3 | timearc-adapter... | Final structural check treated TimeArc display text as a ... | [report](errors/20260618-162650-B-timearc-adapter-check-overstrict.md) |
| 2026-06-18T16:24:31Z | L1 | timearc-db-smok... | After clearing the Qt test data directory, timearc_db_smo... | [report](errors/20260618-162431-B-timearc-db-smoke-test-dir-create.md) |
| 2026-06-18T16:23:39Z | L3 | get-process-no-... | Get-Process timearc_db_smoke returned non-zero while chec... | [report](errors/20260618-162339-B-get-process-no-db-smoke.md) |
| 2026-06-18T16:23:20Z | L1 | timearc-db-smok... | After fixing TimeArc adapter matching, ctest still failed... | [report](errors/20260618-162320-B-timearc-db-smoke-test-data-dir.md) |
| 2026-06-18T16:20:45Z | L1 | timearc-db-smok... | ctest --test-dir build --output-on-failure reported timea... | [report](errors/20260618-162045-B-timearc-db-smoke-ctest.md) |
| 2026-06-18T16:17:38Z | L3 | get-process-no-... | Get-Process TimeArc returned non-zero while checking for ... | [report](errors/20260618-161738-B-get-process-no-timearc-before-build.md) |
| 2026-06-18T16:16:17Z | L2 | timearc-adapter... | Expected red structural check confirmed TimeArc is not ye... | [report](errors/20260618-161617-B-timearc-adapter-red-test.md) |
| ... | ... | omitted | Older rows omitted from INDEX; see `errors.jsonl`. | |
