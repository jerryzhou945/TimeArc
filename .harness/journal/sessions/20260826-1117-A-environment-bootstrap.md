# Environment bootstrap

Goal: Restore the Windows desktop development environment without changing TimeArc product behavior or source contracts. Install Qt 6.11.0 MinGW 64-bit, MinGW 13.1, CMake, Ninja, and portable Node.js, while keeping the migrated repository at `C:\TimeArc\time-arc`.

Plan: Put Qt tools under `C:\TimeArc\QT`, preserve the existing `D:\TimeArc\QT` script contract with a directory junction, keep Node portable, then run the harness build wrapper, CTest, the statistics JavaScript test, and a UI/service runtime smoke.

Outcome: Complete. The existing Qt installation was verified as Qt 6.11.0 with MinGW 13.1.0, CMake 3.30.5, Ninja 1.12.1, and the required Qt Quick/SVG/SQL modules. Portable Node.js 24.20.0 (npm 11.19.0) was downloaded from nodejs.org and its SHA-256 was verified. The toolchain, local Python, and Node directories were added to the user PATH. A `D:\TimeArc\QT` junction now targets `C:\TimeArc\QT` so the migrated launch scripts retain their existing contract.

The first harness build exposed a migrated CMake cache that still referenced `D:\TimeArc\time-arc`. The generated directory was preserved as `build-migrated-from-D-20260826`, and a clean `C:\TimeArc\time-arc\build` was configured without changing product source. The harness build then succeeded. All six CTest cases passed, `tests/stats_view_model_test.js` passed under Node, and `harness_check.py` reported clean. Runtime smoke left one TimeArc UI process and one `time-arc-service` process running; no Qt/QML harness error log was produced.

Final verification caught that the first user-PATH update had not persisted because an in-place PowerShell array reversal returned no enumerable entries. The issue was recorded, the PATH update was reapplied without mutation-based reversal, and every required entry was verified both present on disk and present in the user environment.

One subsequent non-escalated check appeared to disagree because it executed as the isolated `CodexSandboxOffline` account and was denied access to that sandbox registry hive. A read under the real desktop identity `F1SH\cangc` confirmed Python, Node, CMake, Ninja, MinGW, and Qt are all present in the intended user PATH.

Follow-up consolidation moved all discovered development toolchains under `C:\code_env`: Qt 6.11.0/MinGW, Python 3.12.10, Node.js 24.20.0 LTS, Git for Windows 2.53.0.windows.2, Go 1.26.5, standalone CMake 4.3.0, and 7-Zip CLI 26.02. Eclipse Temurin JDK 21.0.12.1+1 LTS was downloaded from Adoptium and SHA-256 verified. Old TimeArc paths are junctions to the canonical directories. The real desktop user's PATH now uses canonical paths, with `JAVA_HOME`, `GOROOT`, `GOPATH`, and `GOCACHE` set under `C:\code_env`.

Post-migration verification passed the Track A preflight, harness build, all six CTest cases, the Node statistics test, and harness integrity. Runtime smoke confirmed one TimeArc UI process and one service process; the Qt/QML log scanner found no error log.

Final drive verification showed this computer no longer exposes a `D:` drive, so the former `D:\TimeArc\QT` compatibility path cannot be retained. Active path fallbacks in `run.cmd`, `launch.cmd`, `tools/verify-linkage.ps1`, and `tools/package-release.ps1` now use `C:\code_env\Qt-6.11.0-MinGW64` directly. Executing `run.cmd` after this change completed an incremental build and relaunched both TimeArc processes successfully.
