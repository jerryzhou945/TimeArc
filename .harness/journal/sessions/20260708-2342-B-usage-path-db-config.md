# Change Proposal - usage-path-db-config

## Metadata

- Author: Codex
- Track: B (Feature)
- Date: 2026-07-08 23:42 CST
- Session goal (one sentence): Refine the shared service DB-path resolver so `get_database_path` reads `usage_config.json` `db_path` first and otherwise returns the platform default database path.
- Branch: development/macos-support
- Related error reports: `errors/20260708-153858-B-preflight-drift.md`, `errors/20260708-154240-B-cmake-path-rg-miss.md`, `errors/20260708-154942-B-stale-text-rg-escape.md`, `errors/20260708-155119-B-build-failure.md`, `errors/20260708-155636-B-build-failure.md`, `errors/20260708-155833-B-ctest-qstandardpaths-sandbox.md`

## 1. Frozen files touched

- `src/service/shared/usage_paths.h` - keep a single public C function: `get_database_path`.
- `src/service/shared/usage_paths.c` - implement config-first DB path resolution using Parson and platform-specific config/default locations.
- `src/service/CMakeLists.txt` - include the macOS media Swift files that the current AppEnv implementation references so the service target can build.

## 2. Motivation

The current shared path implementation exposes the desired header shape but its implementation still resolves a usage directory, while Windows storage carries a duplicate DB-path resolver and still calls older path helpers. The service needs one shared DB-path function that honors `usage_config.json` `db_path` and falls back predictably. The current macOS service target also omits new media Swift files referenced by `AppEnv`.

## 3. Impact on the other process

| Side | Effect |
|------|--------|
| Producer | The service resolves SQLite through `get_database_path`; configured `db_path` wins, otherwise the DB defaults beside `usage_config.json` under the platform usage directory. The macOS service target compiles the media helper files already referenced by `AppEnv`. |
| Consumer | The Qt UI remains a disk consumer and mirrors the same `usage_config.json`-first/default path resolution in `DatabaseManager::databasePath`. |

## 4. Migration plan

No `usage_records.jsonl` or `usage_current.json` schema impact. Existing `usage_config.json` files with `db_path` keep working. When the key is absent, new service writes may land at the new platform fallback path; old DB files are not rewritten.

## 5. Rollback plan

A code revert restores the prior service path behavior. No data rewrite is required; any DB created at the new default can remain in place or be copied by a later migration if the UI/service default contract is changed again.

## 6. Test plan

- Pre-change reproduction: build or inspect Windows storage and see calls to removed `timearc_get_usage_*` helpers plus a duplicated `make_db_path`; macOS build fails because `MediaIdentifying` is not in the service target.
- Post-change verification: harness build succeeds with one shared DB-path function, no stale `timearc_get_usage_*` callers, and all referenced macOS Swift files in the service target.
- New test artifacts: none planned.
- Result: `python .harness/tools/build.py --track B --session .harness/journal/sessions/20260708-2342-B-usage-path-db-config.md` succeeded after rerunning outside the sandbox for Swift module-cache access; `ctest --test-dir build --output-on-failure` passed after rerunning outside the sandbox for Qt's `~/.qttest` directory.

## 7. Sign-off

- [x] `rules/*.md` updated to reflect new reality: `rules/03-data-contract.md`, `rules/05-build-system.md` read; no rule text change needed for the CMake source-list update.
- [ ] `CHARTER.md` version bumped (if charter amendment; not changed in this session).
- [ ] `state/frozen-files.json` will be regenerated after the commit lands.
- [ ] Main `README.md` updated if user-visible.
