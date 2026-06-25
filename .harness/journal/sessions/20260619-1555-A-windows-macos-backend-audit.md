# 2026-06-19 A Windows/macOS backend audit

## Goal

Create a precise backend parity document that explains what Windows already
implements, what macOS source code currently implements, and what still needs
Mac-host compile/runtime proof.

## Scope

Documentation-only audit. No behavior change, no source edits except the new
human-facing report and harness records.

## Areas checked

- `src/service/CMakeLists.txt`
- `src/service/windows/*`
- `src/service/macos/*`
- `src/main.cpp`
- existing parity docs and harness rules

## Expected output

- `docs/windows-macos-backend-parity-audit.md`

## Verification

- Audited `src/service/CMakeLists.txt`, Windows service/tracker/storage files,
  macOS Swift helper files, and `src/main.cpp`.
- `git diff --check` passed.
- `python .harness/tools/harness_check.py` passed.
- No source behavior changed; documentation only.
