# Session — F1 release Qt LGPL/GPL posture (S1 linkage assert + S3 packaging)

- Track: B (Feature)
- Date: 2026-06-11 20:47 (local)
- Branch: `feat/f2-in-app-licenses-page` (same branch/PR as F2 — **PR #43**; maintainer asked to land the
  whole F-arc in one PR). Kickoff: `docs/f1-release-dynamic-link-qt-kickoff.md` (Route A).
- Change proposal: **none** (Route A is out-of-tree; no frozen CMake touched).

## Context
F1-S2 (vendored license texts) already landed earlier in this PR as F2's dependency. This session
completes the rest of F1: **S1** (prove + de-stale) and **S3** (packaging). Per the kickoff, the backlog
description was stale — Qt is *already* dynamic; F1 = prove + de-stale + package, **not** a relink.

## What I did
### S1 — linkage assertion + de-stale docs (Route A, no frozen file)
- New `tools/verify-linkage.ps1`: objdump-asserts the shipped `TimeArc.exe` imports `Qt6*.dll`
  (dynamic; a static Qt build would have zero Qt6 imports → fail), and that
  `build/.qt/QtDeploySupport.cmake` marks `__QT_DEPLOY_IS_SHARED_LIBS_BUILD ON`. Green on the shipped exe
  (6 imports: Core/Gui/Qml/Quick/Sql/Widgets).
- De-staled the 3 self-contradicting docs (all claimed "Qt not yet dynamic"): `open-issues.md` Build/
  distribution entry, `rules/06 §1` Qt row (`must be dynamic | README TO-DO` → `dynamic` + verify-linkage
  pointer), `README:583-584` roadmap (`[ ]`→`[x]`) + `README:620` table (`dynamic (planned)`→`dynamic`).

### S3 — reproducible packaging (Route A, out-of-tree)
- New `tools/package-release.ps1`: embeds the S1 assertion (refuses to package static Qt) → stages
  `TimeArc.exe` + `time-arc-service.exe` → `windeployqt --release --no-translations --compiler-runtime
  --qmldir qml` → ensures the 3 MinGW runtime DLLs → copies `LICENSE` + whole `resources/licenses/` →
  generates `NOTICE.txt` (project GPL-3.0; Qt LGPL-3.0 **relink statement**; SQLite public-domain; Parson
  MIT; MinGW runtime exception) → re-asserts linkage on the staged exe → zips.
- `.gitignore`: added `/dist*/` + `*.zip` (only the scripts are tracked; package output is not).

## Verify (kickoff §6 — all green)
- **Linkage assertion**: `verify-linkage.ps1` PASS on shipped exe (6 Qt6 DLL imports, shared-libs build).
- **Package contents**: `dist/TimeArc-0.1-win64/` = 37 `Qt6*.dll` + both exes + 3 MinGW runtime DLLs +
  qml plugins + `LICENSE` + `licenses/` (all 6 texts) + `NOTICE.txt`; `.zip` produced. `package-release.ps1` exit 0.
- **Clean-machine sim**: launched the packaged exe with PATH stripped to System32/Windows only (no Qt/MinGW
  on PATH) → ran on bundled DLLs alone (PID stayed up past QML load). Self-contained.
- **Encoding bug caught + fixed**: PowerShell 5.1 read the UTF-8 `.ps1` as ANSI/GBK and mangled `—`/`→` in
  NOTICE + script messages → made both scripts pure ASCII; regenerated NOTICE renders clean.
- `harness_check.py` exit 0; backlog §F1 → `[x]`; S4 (in-tree CMake deploy) left gated (needs proposal).

## Adversarial review (3 dims + verify) — legal gaps found in windeployqt auto-bundling, fixed
The scripts/de-stale were judged sound (verify-linkage correctly FAILS on a zero-Qt-import proxy; no frozen
CMake; no PS5.1 incompat). But `windeployqt --compiler-runtime` auto-adds binaries the kickoff's component
list never anticipated, all shipping un-attributed — 3 real findings, all fixed:
- **opengl32sw.dll (Mesa/llvmpipe, ~20 MB)** shipped with no Mesa/LLVM attribution → **dropped via
  `--no-opengl-sw`** (Qt6 uses the Direct3D 11 RHI on Windows, so the software-GL rasterizer is unused;
  also addresses the kickoff §5 over-packaging risk).
- **D3Dcompiler_47.dll (Microsoft redistributable)** unacknowledged → added a NOTICE section (kept; the D3D11
  backend needs it).
- **libwinpthread-1.dll mis-attributed** — it is MinGW-w64 winpthreads (MIT), NOT the GCC Runtime Library
  Exception → vendored `resources/licenses/mingw-w64-winpthreads.txt` + split the NOTICE MinGW section.
- Also: zip now contains a top-level folder (clean unzip). Re-ran packaging: opengl32sw gone, 7 license texts,
  NOTICE accurate, linkage assert green, exit 0.

## Note — test-induced service blip (handled)
The clean-machine launch test spawned the bundled `time-arc-service.exe` (child of the packaged app); it
outlived the killed parent and took over collection from the user's original service. I killed the orphan and
restored the user's collection by relaunching the canonical `build/time-arc-service.exe` (detached, no args,
matching `main.cpp::startUsageService`). Subsequent package verification was inspection-only (no app launch).
