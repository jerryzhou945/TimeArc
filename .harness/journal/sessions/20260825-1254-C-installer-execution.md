# Track C — Windows installer execution

Goal: Fix the Windows test installer so double-clicking it executes the bundled installer script instead of opening that script as text.

Related error report(s): `.harness/journal/errors/20260825-045420-C-installer-opens-script.md`, `.harness/journal/errors/20260825-045420-C-python-path-sandbox.md`.

Expected changes: `tools/package-installer.ps1`, one focused packaging regression test, this session log, and the two related error reports. No application source, database contract, CMake file, or mobile code will change.

Outcome: Root cause confirmed against the official LZMA SDK documentation. The packager now uses configurable `7zSD.sfx` and sets `Directory=""` so system PowerShell is resolved. Static regression, executable SFX smoke, and final archive integrity checks pass; the corrected unsigned setup EXE was regenerated in `dist/`.
