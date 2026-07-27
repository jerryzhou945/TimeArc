# SPDX-License-Identifier: GPL-3.0-or-later

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$action = "release"
$actionSet = $false

function Show-Usage {
  @'
Usage: pwsh -File tools/build-windows.ps1 [--release|--build|--test|--package]

  --release  Configure, build, test, deploy Qt, optionally sign, and create a ZIP.
             This is the default when no option is supplied.
  --build    Configure and build the Release configuration.
  --test     Configure, build, and run the Release tests.
  --package  Configure, build, deploy Qt, optionally sign, and create a ZIP.

Environment:
  TIMEARC_BUILD_DIR             Build directory (default: build-windows).
  TIMEARC_DIST_DIR              Release output directory (default: dist).
  TIMEARC_QT_PREFIX             Optional Qt installation prefix for CMake.
  TIMEARC_WINDEPLOYQT           Optional explicit windeployqt.exe path.
  TIMEARC_MINGW_BIN             Optional MinGW bin directory.
  TIMEARC_OBJDUMP               Optional explicit objdump.exe path.
  TIMEARC_CMAKE_GENERATOR       Optional CMake generator.
  TIMEARC_PYTHON                Python executable (default: python).
  TIMEARC_SIGNTOOL              Optional explicit signtool.exe path.
  TIMEARC_SIGN_CERTIFICATE_SHA1 Authenticode certificate thumbprint.
  TIMEARC_TIMESTAMP_URL         RFC 3161 timestamp URL.
  TIMEARC_REQUIRE_SIGNING=1     Reject an unsigned local package.
'@ | Write-Output
}

function Fail([string]$Message) {
  throw "build-windows: $Message"
}

function Note([string]$Message) {
  Write-Output "build-windows: $Message"
}

foreach ($argument in $args) {
  switch ($argument) {
    "--release" {
      if ($actionSet) { Fail "choose exactly one action" }
      $action = "release"
      $actionSet = $true
    }
    "--build" {
      if ($actionSet) { Fail "choose exactly one action" }
      $action = "build"
      $actionSet = $true
    }
    "--test" {
      if ($actionSet) { Fail "choose exactly one action" }
      $action = "test"
      $actionSet = $true
    }
    "--package" {
      if ($actionSet) { Fail "choose exactly one action" }
      $action = "package"
      $actionSet = $true
    }
    { $_ -in @("-h", "--help") } {
      Show-Usage
      exit 0
    }
    default {
      Fail "unknown option: $argument"
    }
  }
}

if ($env:OS -ne "Windows_NT") {
  Fail "this script requires Windows"
}

function Resolve-RepoPath([string]$Value) {
  if ([IO.Path]::IsPathRooted($Value)) {
    return [IO.Path]::GetFullPath($Value)
  }
  return [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $Value))
}

function Get-EnvironmentValue(
  [string]$Name,
  [string]$DefaultValue
) {
  $value = [Environment]::GetEnvironmentVariable($Name)
  if ([string]::IsNullOrWhiteSpace($value)) {
    return $DefaultValue
  }
  return $value
}

function Require-Command([string]$Name) {
  $command = Get-Command $Name -ErrorAction SilentlyContinue
  if (-not $command) {
    Fail "required command not found: $Name"
  }
  return $command.Source
}

function Invoke-Native(
  [string]$FilePath,
  [string[]]$ArgumentList
) {
  & $FilePath @ArgumentList
  if ($LASTEXITCODE -ne 0) {
    Fail "command failed with exit code $LASTEXITCODE`: $FilePath"
  }
}

$python = Get-EnvironmentValue "TIMEARC_PYTHON" "python"
$buildDir = Resolve-RepoPath (Get-EnvironmentValue "TIMEARC_BUILD_DIR" "build-windows")
$distDir = Resolve-RepoPath (Get-EnvironmentValue "TIMEARC_DIST_DIR" "dist")
New-Item -ItemType Directory -Force -Path $buildDir | Out-Null
New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$buildDir = (Resolve-Path $buildDir).Path
$distDir = (Resolve-Path $distDir).Path

function Remove-DistItem([string]$Target) {
  $fullTarget = [IO.Path]::GetFullPath($Target)
  $distPrefix = $script:distDir.TrimEnd([char[]]@(
      [IO.Path]::DirectorySeparatorChar,
      [IO.Path]::AltDirectorySeparatorChar
    )) + [IO.Path]::DirectorySeparatorChar
  if (-not $fullTarget.StartsWith(
      $distPrefix,
      [StringComparison]::OrdinalIgnoreCase
    )) {
    Fail "refusing to remove path outside dist: $fullTarget"
  }
  if (Test-Path $fullTarget) {
    Remove-Item -Recurse -Force $fullTarget
  }
}

function Configure-Release {
  $cmake = Require-Command "cmake"
  $arguments = @(
    "-S", $script:RepoRoot,
    "-B", $script:buildDir,
    "-DCMAKE_BUILD_TYPE=Release"
  )
  $generator = [Environment]::GetEnvironmentVariable(
    "TIMEARC_CMAKE_GENERATOR"
  )
  if (-not [string]::IsNullOrWhiteSpace($generator)) {
    $arguments += @("-G", $generator)
  }
  $qtPrefix = [Environment]::GetEnvironmentVariable("TIMEARC_QT_PREFIX")
  if (-not [string]::IsNullOrWhiteSpace($qtPrefix)) {
    $arguments += "-DCMAKE_PREFIX_PATH=$qtPrefix"
  }
  Note "configuring Release in $script:buildDir"
  Invoke-Native $cmake $arguments
}

function Build-Release {
  $pythonCommand = Require-Command $script:python
  Note "building through the project harness"
  Invoke-Native $pythonCommand @(
    (Join-Path $script:RepoRoot ".harness/tools/build.py"),
    "--build-dir", $script:buildDir,
    "--track", "B",
    "--topic", "windows-release-build",
    "--",
    "--config", "Release",
    "--parallel"
  )
}

function Run-Tests {
  $ctest = Require-Command "ctest"
  Note "running Release tests"
  Invoke-Native $ctest @(
    "--test-dir", $script:buildDir,
    "-C", "Release",
    "--output-on-failure"
  )
}

function Read-CMakeCacheValue([string]$Name) {
  $cachePath = Join-Path $script:buildDir "CMakeCache.txt"
  if (-not (Test-Path $cachePath -PathType Leaf)) {
    return $null
  }
  $pattern = "(?m)^" + [regex]::Escape($Name) + ":[^=]+=(.+)$"
  $match = [regex]::Match(
    (Get-Content $cachePath -Raw),
    $pattern
  )
  if (-not $match.Success) {
    return $null
  }
  return $match.Groups[1].Value.Trim()
}

function Find-WinDeployQt {
  $explicit = [Environment]::GetEnvironmentVariable("TIMEARC_WINDEPLOYQT")
  if (-not [string]::IsNullOrWhiteSpace($explicit)) {
    if (-not (Test-Path $explicit -PathType Leaf)) {
      Fail "TIMEARC_WINDEPLOYQT was not found: $explicit"
    }
    return (Resolve-Path $explicit).Path
  }

  $candidates = [Collections.Generic.List[string]]::new()
  $qtPrefix = [Environment]::GetEnvironmentVariable("TIMEARC_QT_PREFIX")
  if (-not [string]::IsNullOrWhiteSpace($qtPrefix)) {
    $candidates.Add((Join-Path $qtPrefix "bin/windeployqt.exe"))
  }
  $qtDir = Read-CMakeCacheValue "Qt6_DIR"
  if (-not [string]::IsNullOrWhiteSpace($qtDir)) {
    $inferredPrefix = [IO.Path]::GetFullPath((Join-Path $qtDir "../../.."))
    $candidates.Add((Join-Path $inferredPrefix "bin/windeployqt.exe"))
  }
  foreach ($candidate in $candidates) {
    if (Test-Path $candidate -PathType Leaf) {
      return (Resolve-Path $candidate).Path
    }
  }

  $command = Get-Command "windeployqt.exe" -ErrorAction SilentlyContinue
  if ($command) {
    return $command.Source
  }
  $qtPaths = Get-Command "qtpaths6.exe" -ErrorAction SilentlyContinue
  if ($qtPaths) {
    $qtBin = (& $qtPaths.Source --query QT_INSTALL_BINS | Select-Object -First 1)
    if ($LASTEXITCODE -eq 0) {
      $candidate = Join-Path $qtBin "windeployqt.exe"
      if (Test-Path $candidate -PathType Leaf) {
        return (Resolve-Path $candidate).Path
      }
    }
  }
  Fail "windeployqt.exe not found; set TIMEARC_WINDEPLOYQT"
}

function Find-MingwBin {
  $explicit = [Environment]::GetEnvironmentVariable("TIMEARC_MINGW_BIN")
  if (-not [string]::IsNullOrWhiteSpace($explicit)) {
    if (-not (Test-Path $explicit -PathType Container)) {
      Fail "TIMEARC_MINGW_BIN was not found: $explicit"
    }
    return (Resolve-Path $explicit).Path
  }
  $compiler = Read-CMakeCacheValue "CMAKE_CXX_COMPILER"
  if (-not [string]::IsNullOrWhiteSpace($compiler) -and
      (Split-Path $compiler -Leaf) -match "^(g\+\+|c\+\+)(\.exe)?$") {
    return (Split-Path $compiler -Parent)
  }
  return $null
}

function Find-Objdump([AllowNull()][string]$MingwBin) {
  $explicit = [Environment]::GetEnvironmentVariable("TIMEARC_OBJDUMP")
  if (-not [string]::IsNullOrWhiteSpace($explicit)) {
    if (-not (Test-Path $explicit -PathType Leaf)) {
      Fail "TIMEARC_OBJDUMP was not found: $explicit"
    }
    return (Resolve-Path $explicit).Path
  }
  if (-not [string]::IsNullOrWhiteSpace($MingwBin)) {
    $candidate = Join-Path $MingwBin "objdump.exe"
    if (Test-Path $candidate -PathType Leaf) {
      return (Resolve-Path $candidate).Path
    }
  }
  $command = Get-Command "objdump.exe" -ErrorAction SilentlyContinue
  if (-not $command) {
    $command = Get-Command "objdump" -ErrorAction SilentlyContinue
  }
  if ($command) {
    return $command.Source
  }
  Fail "objdump.exe not found; set TIMEARC_OBJDUMP"
}

function Get-ProjectVersion {
  $source = Get-Content (Join-Path $script:RepoRoot "CMakeLists.txt") -Raw
  $match = [regex]::Match(
    $source,
    "project\(\s*time-arc\s+VERSION\s+([^\s\)]+)"
  )
  if (-not $match.Success) {
    Fail "could not read project version from CMakeLists.txt"
  }
  return $match.Groups[1].Value
}

function Assert-DynamicQtLinkage(
  [string]$Executable,
  [string]$Objdump
) {
  if (-not (Test-Path $Executable -PathType Leaf)) {
    Fail "linkage input is missing: $Executable"
  }
  $dump = & $Objdump -p $Executable 2>&1
  if ($LASTEXITCODE -ne 0) {
    Fail "objdump failed for $Executable"
  }
  $matches = [regex]::Matches(
    ($dump -join "`n"),
    "DLL Name:\s*(Qt6\w+\.dll)",
    [Text.RegularExpressions.RegexOptions]::IgnoreCase
  )
  $imports = @(
    $matches |
      ForEach-Object { $_.Groups[1].Value } |
      Sort-Object -Unique
  )
  if ($imports.Count -lt 1) {
    Fail "no Qt6 DLL imports in $Executable; static Qt is not releasable"
  }

  $deploySupport = Join-Path $script:buildDir ".qt/QtDeploySupport.cmake"
  if (-not (Test-Path $deploySupport -PathType Leaf)) {
    Fail "Qt deployment metadata is missing: $deploySupport"
  }
  $supportText = Get-Content $deploySupport -Raw
  if ($supportText -notmatch '__QT_DEPLOY_IS_SHARED_LIBS_BUILD\s+"?ON"?') {
    Fail "configured Qt is not marked as a shared-libraries build"
  }
  Note ("dynamic Qt linkage verified: " + ($imports -join ", "))
}

function Get-WindowsArchitecture(
  [string]$Executable,
  [string]$Objdump
) {
  $dump = & $Objdump -f $Executable 2>&1
  if ($LASTEXITCODE -ne 0) {
    Fail "could not inspect package architecture"
  }
  $text = $dump -join "`n"
  if ($text -match "pei-aarch64|architecture:\s*aarch64") {
    return "win-arm64"
  }
  if ($text -match "pei-x86-64|architecture:\s*i386:x86-64") {
    return "win64"
  }
  if ($text -match "pei-i386|architecture:\s*i386") {
    return "win32"
  }
  Fail "unsupported Windows executable architecture"
}

function Ensure-CompilerRuntime(
  [string]$PackageDir,
  [AllowNull()][string]$MingwBin
) {
  $compiler = Read-CMakeCacheValue "CMAKE_CXX_COMPILER"
  $isMingw = (
    -not [string]::IsNullOrWhiteSpace($MingwBin) -or
    (
      -not [string]::IsNullOrWhiteSpace($compiler) -and
      $compiler -match "(mingw|g\+\+)"
    )
  )
  if (-not $isMingw) {
    return $false
  }
  if ([string]::IsNullOrWhiteSpace($MingwBin)) {
    Fail "MinGW build detected but its bin directory could not be found"
  }
  foreach ($name in @(
      "libgcc_s_seh-1.dll",
      "libstdc++-6.dll",
      "libwinpthread-1.dll"
    )) {
    $destination = Join-Path $PackageDir $name
    if (Test-Path $destination -PathType Leaf) {
      continue
    }
    $source = Join-Path $MingwBin $name
    if (-not (Test-Path $source -PathType Leaf)) {
      Fail "required MinGW runtime is missing: $source"
    }
    Copy-Item $source $destination
  }
  return $true
}

function Write-Notice(
  [string]$PackageDir,
  [string]$Version,
  [bool]$HasMingwRuntime
) {
  $runtimeNotice = if ($HasMingwRuntime) {
@'
--- MinGW GCC runtime ---
libgcc_s_seh-1.dll and libstdc++-6.dll are distributed under GPL-3.0
with the GCC Runtime Library Exception v3.1. libwinpthread-1.dll uses
the MinGW-w64 MIT-style terms. The corresponding texts are bundled.
'@
  } else {
@'
--- Compiler runtime ---
Required compiler runtime files are deployed as replaceable shared libraries
by Qt's Windows deployment tool under their applicable redistributable terms.
'@
  }

  $notice = @"
TimeArc $Version - THIRD-PARTY NOTICES
=======================================

TimeArc is licensed under GPL-3.0-or-later. The full text is in LICENSE.
Full license texts for bundled components are in the licenses directory.

--- Qt 6: LGPL-3.0 with applicable exceptions ---
Qt is dynamically linked. The Qt6*.dll files shipped beside TimeArc.exe are
separate and replaceable, allowing relinking with a compatible Qt build.

--- SQLite: public domain ---
SQLite is statically compiled into TimeArc.

--- Parson: MIT ---
Parson is statically compiled into TimeArc.

$runtimeNotice
--- D3Dcompiler_47.dll: Microsoft redistributable ---
When present, this Direct3D compiler component is deployed by windeployqt for
Qt's Windows rendering backend under Microsoft's redistributable terms.

This NOTICE.txt is generated by tools/build-windows.ps1.
"@
  Set-Content `
    -Path (Join-Path $PackageDir "NOTICE.txt") `
    -Value $notice `
    -Encoding UTF8
}

function Sign-Package([string]$PackageDir) {
  $thumbprint = [Environment]::GetEnvironmentVariable(
    "TIMEARC_SIGN_CERTIFICATE_SHA1"
  )
  if ([string]::IsNullOrWhiteSpace($thumbprint)) {
    if ((Get-EnvironmentValue "TIMEARC_REQUIRE_SIGNING" "0") -eq "1") {
      Fail "TIMEARC_SIGN_CERTIFICATE_SHA1 is required"
    }
    Note "Authenticode signing skipped; this is a local unsigned package"
    return
  }

  $signToolValue = [Environment]::GetEnvironmentVariable("TIMEARC_SIGNTOOL")
  if ([string]::IsNullOrWhiteSpace($signToolValue)) {
    $signTool = Require-Command "signtool.exe"
  } else {
    if (-not (Test-Path $signToolValue -PathType Leaf)) {
      Fail "TIMEARC_SIGNTOOL was not found: $signToolValue"
    }
    $signTool = (Resolve-Path $signToolValue).Path
  }
  $timestampUrl = Get-EnvironmentValue `
    "TIMEARC_TIMESTAMP_URL" `
    "http://timestamp.digicert.com"

  $signablePaths = @(
    (Join-Path $PackageDir "time-arc-service.exe"),
    (Join-Path $PackageDir "TimeArc.exe")
  )
  $signableFiles = @(Get-Item -Path $signablePaths)
  foreach ($file in $signableFiles) {
    Invoke-Native $signTool @(
      "sign",
      "/fd", "SHA256",
      "/sha1", $thumbprint,
      "/tr", $timestampUrl,
      "/td", "SHA256",
      $file.FullName
    )
  }
  foreach ($file in $signableFiles) {
    Invoke-Native $signTool @("verify", "/pa", "/all", $file.FullName)
  }
}

function Package-Release {
  $cmake = Require-Command "cmake"
  Require-Command "Compress-Archive" | Out-Null
  $winDeployQt = Find-WinDeployQt
  $mingwBin = Find-MingwBin
  $objdump = Find-Objdump $mingwBin
  $version = Get-ProjectVersion
  $stage = Join-Path $script:distDir ".timearc-windows-stage"
  Remove-DistItem $stage
  New-Item -ItemType Directory -Force -Path $stage | Out-Null

  Note "installing project-owned release content into staging"
  Invoke-Native $cmake @(
    "--install", $script:buildDir,
    "--prefix", $stage,
    "--config", "Release"
  )

  $installBin = Join-Path $stage "bin"
  $installedApp = Join-Path $installBin "TimeArc.exe"
  $installedService = Join-Path $installBin "time-arc-service.exe"
  if (-not (Test-Path $installedApp -PathType Leaf)) {
    Fail "staged TimeArc.exe is missing"
  }
  if (-not (Test-Path $installedService -PathType Leaf)) {
    Fail "staged time-arc-service.exe is missing"
  }
  foreach ($pack in @("backgrounds", "site-icons", "monthly-recap")) {
    $resource = Join-Path $installBin "assets/timearc-$pack.rcc"
    if (-not (Test-Path $resource -PathType Leaf)) {
      Fail "staged GUI resource pack is missing: timearc-$pack.rcc"
    }
  }

  Assert-DynamicQtLinkage $installedApp $objdump
  $architecture = Get-WindowsArchitecture $installedApp $objdump
  $packageName = "TimeArc-$version-$architecture"
  $packageDir = Join-Path $script:distDir $packageName
  $zipPath = Join-Path $script:distDir "$packageName.zip"
  Remove-DistItem $packageDir
  Remove-DistItem $zipPath
  New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
  Copy-Item -Path (Join-Path $installBin "*") -Destination $packageDir -Recurse

  Copy-Item `
    (Join-Path $script:RepoRoot "LICENSE") `
    (Join-Path $packageDir "LICENSE")
  Copy-Item `
    (Join-Path $script:RepoRoot "resources/licenses") `
    (Join-Path $packageDir "licenses") `
    -Recurse

  $pathParts = @((Split-Path $winDeployQt -Parent))
  if (-not [string]::IsNullOrWhiteSpace($mingwBin)) {
    $pathParts += $mingwBin
  }
  $env:Path = (($pathParts + @($env:Path)) -join [IO.Path]::PathSeparator)
  Note "deploying private Qt DLLs, plugins, QML modules, and compiler runtime"
  Invoke-Native $winDeployQt @(
    "--release",
    "--no-translations",
    "--no-opengl-sw",
    "--compiler-runtime",
    "--qmldir", (Join-Path $script:RepoRoot "qml"),
    (Join-Path $packageDir "TimeArc.exe")
  )

  $hasMingwRuntime = Ensure-CompilerRuntime $packageDir $mingwBin
  Write-Notice $packageDir $version $hasMingwRuntime
  Assert-DynamicQtLinkage (Join-Path $packageDir "TimeArc.exe") $objdump
  Sign-Package $packageDir

  Note "creating $zipPath"
  Compress-Archive -Path $packageDir -DestinationPath $zipPath -CompressionLevel Optimal
  if (-not (Test-Path $zipPath -PathType Leaf)) {
    Fail "ZIP creation did not produce $zipPath"
  }

  Remove-DistItem $stage
  Note "bundle -> $packageDir"
  Note "zip -> $zipPath"
}

try {
  Configure-Release
  Build-Release

  switch ($action) {
    "build" {}
    "test" { Run-Tests }
    "package" { Package-Release }
    "release" {
      Run-Tests
      Package-Release
    }
  }
} catch {
  Write-Error $_
  exit 1
}
