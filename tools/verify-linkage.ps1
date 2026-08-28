<#
.SYNOPSIS
  Release-time linkage assertion (TimeArc F1-S1).

  Proves the SHIPPED TimeArc.exe links Qt DYNAMICALLY (CHARTER I6: "Qt must be
  dynamically linked"), never statically. A static Qt build would have NO Qt6*.dll
  imports in the PE import table, so the presence of Qt6*.dll imports is the
  positive proof; their absence fails the build. Also asserts the Qt that
  configured the build is a shared-libs install (QtDeploySupport.cmake).

  Run pre-release / inside package-release.ps1. Exit 0 = dynamic OK; non-zero = fail.

.EXAMPLE
  pwsh tools/verify-linkage.ps1
  pwsh tools/verify-linkage.ps1 -Exe dist/TimeArc-0.1-win64/TimeArc.exe
#>
param(
  [string]$Exe = "build/TimeArc.exe",
  [string]$DeploySupport = "build/.qt/QtDeploySupport.cmake",
  [string]$Objdump = "objdump"
)
$ErrorActionPreference = "Stop"
function Fail($m) { Write-Error "verify-linkage: FAIL - $m"; exit 1 }

if (-not (Test-Path $Exe)) { Fail "exe not found: $Exe (build Release first via .harness/tools/build.py)" }

# Resolve objdump: explicit path/PATH, then common project toolchain locations.
$od = Get-Command $Objdump -ErrorAction SilentlyContinue
if (-not $od) { $od = Get-Command "D:/TimeArc/QT/Tools/mingw1310_64/bin/objdump.exe" -ErrorAction SilentlyContinue }
if (-not $od) { $od = Get-Command "C:/code_env/Qt-6.11.0-MinGW64/Tools/mingw1310_64/bin/objdump.exe" -ErrorAction SilentlyContinue }
if (-not $od) { $od = Get-Command "C:/Qt/Tools/mingw1310_64/bin/objdump.exe" -ErrorAction SilentlyContinue }
if (-not $od) { Fail "objdump not found; pass -Objdump with the MinGW toolchain path" }

# PE import table -> Qt6*.dll names. Dynamic linkage = these imports exist.
$dump = & $od.Source -p $Exe
$qt = @($dump | Select-String -Pattern 'DLL Name:\s*(Qt6\w+\.dll)' -AllMatches |
        ForEach-Object { $_.Matches } | ForEach-Object { $_.Groups[1].Value }) |
        Sort-Object -Unique
if ($qt.Count -lt 1) {
  Fail "no Qt6*.dll imports in $Exe - Qt is NOT dynamically linked (static Qt would violate CHARTER I6)"
}
Write-Output ("verify-linkage: dynamic Qt OK ({0} imports): {1}" -f $qt.Count, ($qt -join ", "))

# Secondary guard: the configured Qt is a shared-libs install.
if (Test-Path $DeploySupport) {
  if (-not (Select-String -Path $DeploySupport -Pattern '__QT_DEPLOY_IS_SHARED_LIBS_BUILD\s+"?ON"?' -Quiet)) {
    Fail "$DeploySupport does not mark __QT_DEPLOY_IS_SHARED_LIBS_BUILD ON (static Qt install?)"
  }
  Write-Output "verify-linkage: QtDeploySupport shared-libs build OK"
} else {
  Write-Output "verify-linkage: note - $DeploySupport absent; skipped shared-libs assert"
}

Write-Output "verify-linkage: PASS"
exit 0
