# Windows tracking recovery

Goal: restore automatic Windows collection after the macOS lifecycle merge and align the Windows reader with the current service configuration without changing the service database contract.

Related error report(s): `../errors/20260820-000934-C-windows-collector-not-running.md`.

Expected files: `src/main.cpp`, Windows service configuration/tracker files, focused tests, parity/release documentation. Frozen CMake, shared ABI, database schema, and database-path files are out of scope.

Completed: investigation; approved design; Windows tracking/config/status/UI parity fixes; teardown warning fix; parity/release docs; unsigned Windows tester ZIP; clean harness gate.
Incomplete: commit, PR/merge, and branch cleanup.
Verification: TDD REDs recorded; fresh build; CTest 4/4; all Python static/smoke tests pass (macOS binary smoke skipped on Windows); build and packaged binaries pass real UI/service smoke; isolated Qt run emits no warning log. ZIP SHA-256 `A68405BC501806A421FF3A1F5A68B9CF78B4FCFBC28185F7CF94E3FBAC68274E`.
Next: commit and present/execute the integration choice.
Risks: Windows runtime smoke under the managed sandbox cannot write the user's service DB; functional storage tests must redirect APPDATA to a writable fixture.
