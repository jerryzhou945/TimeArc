# Track B — Windows build and release entry point

## Goal

Add `tools/build-windows.ps1` with the same default `--release` and explicit
`--build`, `--test`, and `--package` interface as the macOS entry point.

## Scope

- Service side: the script builds and packages the existing
  `time-arc-service.exe`; it does not change service behavior or disk output.
- UI side: the script builds and packages `TimeArc.exe`, its three functional
  RCC packs, private Qt runtime, and offline license material.
- Files: new Windows script/static test plus release documentation and Rule 05.
- Keep untouched: frozen CMake files, schemas, source code, and the existing
  `package-release.ps1` / `verify-linkage.ps1` scripts.

## Progress

- [x] Implement the standalone Windows configure/build/test/package pipeline.
- [x] Verify the CLI contract and project harness audit.

## Outcome

Added the four-mode Windows entry point, inline Qt-linkage and packaging gates,
optional Authenticode signing, portable ZIP output, static regression coverage,
and release documentation. Static tests and the full harness audit pass; an
actual package run requires a Windows host with Qt and PowerShell.
