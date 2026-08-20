# Windows tracking and platform parity progress

- [x] Restore automatic Windows collector startup.
- [x] Read current `service_config.json` on Windows.
- [x] Preserve disabled-tracking and zero-idle semantics.
- [x] Align Windows service state and start-now behavior with macOS.
- [x] Run Windows build, tests, and redirected service smoke.
- [x] Update Win/macOS parity and beta-tester release material.
- [-] Commit, review, open PR, merge to `dev`, and clean the branch.

Completed: root-cause investigation; implementation; verification; parity/release documentation; unsigned Windows tester ZIP; clean harness gate.
Incomplete: commit, PR/merge, and branch cleanup.
Verification: fresh build; CTest 4/4; all Python static/smoke tests pass (macOS binary smoke skipped on Windows); build and packaged binaries pass real-process smoke; isolated Qt run has no warning log. ZIP SHA-256 `A68405BC501806A421FF3A1F5A68B9CF78B4FCFBC28185F7CF94E3FBAC68274E`.
Next: commit and present/execute the integration choice.
Risks: macOS binary/runtime verification requires a Mac and remains a release gate.
