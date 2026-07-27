<#
.SYNOPSIS
  Reproducible release packaging (TimeArc F1-S3, Route A -out-of-tree).

  Replaces the hand-run windeployqt with a one-command, compliant portable package:
  windeployqt (bundle Qt DLLs + plugins) + MinGW runtime DLLs + the service exe +
  the functional GUI RCC packs + LICENSE + the whole resources/licenses/ tree + a generated NOTICE.txt (project GPL-3.0,
  Qt LGPL-3.0 relink statement, SQLite public-domain, Parson MIT, MinGW runtime exception),
  with the F1-S1 linkage assertion embedded (refuses to package a statically-linked Qt),
  then zips it.

  Touches NO frozen CMake (in-tree CMake deploy = Route B/S4, needs a change proposal).
  Build Release first: .harness/tools/build.py   (kill TimeArc.exe before building).

.EXAMPLE
  pwsh tools/package-release.ps1
  pwsh tools/package-release.ps1 -Version 0.1 -BuildDir build
#>
param(
  [string]$BuildDir = "build",
  [string]$QtBin    = "C:/Qt/6.11.1/mingw_64/bin",
  [string]$MingwBin = "C:/Qt/Tools/mingw1310_64/bin",
  [string]$OutRoot  = "dist",
  [string]$Version  = "0.1"
)
$ErrorActionPreference = "Stop"
$repo  = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tools = $PSScriptRoot

$app = Join-Path $repo (Join-Path $BuildDir "TimeArc.exe")
$svc = Join-Path $repo (Join-Path $BuildDir "time-arc-service.exe")
$guiAssetNames = @(
  "timearc-backgrounds.rcc",
  "timearc-site-icons.rcc",
  "timearc-monthly-recap.rcc"
)
$guiAssets = @($guiAssetNames | ForEach-Object {
  Join-Path $repo (Join-Path $BuildDir "assets/$_")
})
$deploySupport = Join-Path $repo (Join-Path $BuildDir ".qt/QtDeploySupport.cmake")
if (-not (Test-Path $app)) { Write-Error "missing $app -build Release first (.harness/tools/build.py)"; exit 1 }
if (-not (Test-Path $svc)) { Write-Error "missing required service: $svc"; exit 1 }
foreach ($guiAsset in $guiAssets) {
  if (-not (Test-Path $guiAsset)) { Write-Error "missing required GUI resource pack: $guiAsset"; exit 1 }
}

# 1. Linkage assertion (S1) on the BUILT exe -fail fast before doing any work.
& (Join-Path $tools "verify-linkage.ps1") -Exe $app -DeploySupport $deploySupport
if ($LASTEXITCODE -ne 0) { Write-Error "linkage assertion failed -refusing to package"; exit 1 }

# 2. Clean staging dir.
$pkgName = "TimeArc-$Version-win64"
$stage   = Join-Path $repo (Join-Path $OutRoot $pkgName)
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $app $stage
Copy-Item $svc $stage
New-Item -ItemType Directory -Force -Path (Join-Path $stage "assets") | Out-Null
foreach ($guiAsset in $guiAssets) {
  Copy-Item $guiAsset (Join-Path $stage "assets")
}

# 3. windeployqt: bundle Qt DLLs + QML + plugins (release, no translations to trim size).
#    --no-opengl-sw drops opengl32sw.dll (Mesa/llvmpipe, ~20 MB): Qt6 uses the Direct3D 11 RHI
#    backend on Windows so the pure-software GL rasterizer is unused here, and dropping it avoids
#    shipping Mesa/LLVM-licensed code that would otherwise need its own attribution (also
#    addresses the kickoff's windeployqt over-packaging risk).
$env:PATH = "$QtBin;$MingwBin;$env:PATH"
& (Join-Path $QtBin "windeployqt.exe") --release --no-translations --no-opengl-sw --compiler-runtime `
    --qmldir (Join-Path $repo "qml") (Join-Path $stage "TimeArc.exe")
if ($LASTEXITCODE -ne 0) { Write-Error "windeployqt failed"; exit 1 }

# 4. Ensure the three MinGW runtime DLLs are present (app + service both need them).
foreach ($d in @("libgcc_s_seh-1.dll", "libstdc++-6.dll", "libwinpthread-1.dll")) {
  $src = Join-Path $MingwBin $d
  $dst = Join-Path $stage $d
  if ((Test-Path $src) -and -not (Test-Path $dst)) { Copy-Item $src $dst }
}

# 5. Compliance files: LICENSE + the whole licenses/ tree + generated NOTICE.txt.
Copy-Item (Join-Path $repo "LICENSE") (Join-Path $stage "LICENSE")
Copy-Item -Recurse (Join-Path $repo "resources/licenses") (Join-Path $stage "licenses")

$notice = @"
TimeArc $Version - THIRD-PARTY NOTICES
=======================================

TimeArc itself is licensed under the GNU General Public License v3.0 or later
(GPL-3.0-or-later). The full text is in the bundled file LICENSE. Full license
texts for every component below are in the bundled licenses/ directory.

--- Qt 6 (6.11.1): GNU LGPL-3.0 (with exceptions); some tools/add-ons GPL-3.0 ---
Qt is used under the GNU Lesser General Public License version 3 and is
DYNAMICALLY LINKED: the Qt6*.dll libraries shipped alongside TimeArc.exe are
separate, replaceable files. As required by the LGPL, you may obtain the
corresponding Qt source from https://www.qt.io/ / https://download.qt.io/ and
RELINK or replace the bundled Qt DLLs with your own compatible build of the same
Qt version. No part of Qt is statically linked into TimeArc.exe (verified at
package time by tools/verify-linkage.ps1). License texts: licenses/qt-lgpl-3.0.txt
and licenses/qt-gpl-3.0.txt.

--- SQLite (3.51.3): Public domain ---
Statically compiled from thirdparty/sqlite3. SQLite is dedicated to the public
domain (no copyright, no license text); the author's blessing and an explicit
public-domain note are in licenses/sqlite-public-domain.txt.

--- Parson (1.5.3): MIT ---
Statically compiled from thirdparty/parson. License text: licenses/parson-mit.txt.

--- MinGW GCC runtime: libgcc_s_seh-1.dll, libstdc++-6.dll ---
Distributed under the GCC Runtime Library Exception v3.1 (GPL-3.0 + the runtime
exception). Text: licenses/mingw-runtime-exception.txt.

--- MinGW-w64 winpthreads: libwinpthread-1.dll - MIT (mingw-w64 project) ---
The bundled libwinpthread-1.dll is part of MinGW-w64 and is licensed under its
own MIT-style terms (NOT the GCC Runtime Library Exception). Text: licenses/mingw-w64-winpthreads.txt.

--- D3Dcompiler_47.dll: Microsoft redistributable ---
The Direct3D HLSL compiler (Microsoft Corporation), bundled by windeployqt for the
Direct3D 11 rendering backend, is redistributed under Microsoft's applicable
redistributable terms for the Direct3D / Windows SDK runtime components.

This NOTICE.txt is generated by tools/package-release.ps1.
"@
Set-Content -Path (Join-Path $stage "NOTICE.txt") -Value $notice -Encoding UTF8

# 6. Re-assert linkage on the STAGED exe (the bytes that actually ship).
& (Join-Path $tools "verify-linkage.ps1") -Exe (Join-Path $stage "TimeArc.exe") -DeploySupport $deploySupport
if ($LASTEXITCODE -ne 0) { Write-Error "staged linkage assertion failed"; exit 1 }

# 7. Zip.
$zip = Join-Path $repo (Join-Path $OutRoot "$pkgName.zip")
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $stage -DestinationPath $zip   # zip the folder so it unzips to $pkgName/

$qtCount = (Get-ChildItem $stage -Filter "Qt6*.dll").Count
Write-Output ""
Write-Output ("package-release: OK: staged {0} Qt6 DLLs + service + GUI assets + compliance files" -f $qtCount)
Write-Output ("package-release: dir  -> {0}" -f $stage)
Write-Output ("package-release: zip  -> {0}" -f $zip)
exit 0
