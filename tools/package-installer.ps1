<#
.SYNOPSIS
  Builds an unsigned per-user TimeArc test installer with the configurable 7-Zip LZMA SDK SFX.

.DESCRIPTION
  Embeds the verified portable ZIP plus a PowerShell installer. The payload is
  expanded to %LOCALAPPDATA%\Programs\TimeArc, Start Menu and desktop shortcuts
  are created, and TimeArc is launched. No elevation is required.

  The default local tool directory is intentionally ignored by Git. Populate it
  with official 7-Zip 26.02 7za.exe and LZMA SDK 7zSD.sfx, or pass explicit paths.
#>
param(
  [string]$Version = "0.1",
  [string]$OutRoot = "dist",
  [string]$SevenZip = ".local-toolchains/7zip-26.02/extra/x64/7za.exe",
  [string]$SfxModule = ".local-toolchains/7zip-26.02/lzma/bin/7zSD.sfx"
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
function Resolve-RepoPath([string]$path) {
  if ([IO.Path]::IsPathRooted($path)) { return $path }
  return Join-Path $repo $path
}
$sevenZipPath = Resolve-RepoPath $SevenZip
$sfxPath = Resolve-RepoPath $SfxModule
$zipName = "TimeArc-$Version-win64.zip"
$zip = Join-Path $repo (Join-Path $OutRoot $zipName)
$setup = Join-Path $repo (Join-Path $OutRoot "TimeArc-$Version-win64-setup.exe")
if (-not (Test-Path $zip -PathType Leaf)) { Write-Error "missing portable package: $zip"; exit 1 }
if (-not (Test-Path $sevenZipPath -PathType Leaf)) {
  Write-Error "7za.exe not found: $sevenZipPath (download official 7-Zip Extra or pass -SevenZip)"
  exit 1
}
if (-not (Test-Path $sfxPath -PathType Leaf)) {
  Write-Error "7zSD.sfx not found: $sfxPath (download the official LZMA SDK or pass -SfxModule)"
  exit 1
}

$work = Join-Path ([IO.Path]::GetTempPath()) ("timearc-installer-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work | Out-Null
try {
  Copy-Item $zip (Join-Path $work $zipName)
  $installer = @'
$ErrorActionPreference = "Stop"
$packageDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$zip = Get-ChildItem -LiteralPath $packageDir -Filter "TimeArc-*-win64.zip" | Select-Object -First 1
if (-not $zip) { throw "TimeArc payload is missing." }
$installRoot = Join-Path $env:LOCALAPPDATA "Programs\TimeArc"
$unpack = Join-Path $env:TEMP ("timearc-unpack-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $installRoot,$unpack | Out-Null
try {
  Expand-Archive -LiteralPath $zip.FullName -DestinationPath $unpack -Force
  $payload = Get-ChildItem -LiteralPath $unpack -Directory | Select-Object -First 1
  if (-not $payload -or -not (Test-Path (Join-Path $payload.FullName "TimeArc.exe"))) {
    throw "TimeArc payload layout is invalid."
  }
  Copy-Item -Path (Join-Path $payload.FullName "*") -Destination $installRoot -Recurse -Force
} finally {
  if (Test-Path $unpack) { Remove-Item -LiteralPath $unpack -Recurse -Force }
}
$shell = New-Object -ComObject WScript.Shell
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\TimeArc.lnk"
$desktop = Join-Path ([Environment]::GetFolderPath("Desktop")) "TimeArc.lnk"
foreach ($shortcutPath in @($startMenu, $desktop)) {
  $shortcut = $shell.CreateShortcut($shortcutPath)
  $shortcut.TargetPath = Join-Path $installRoot "TimeArc.exe"
  $shortcut.WorkingDirectory = $installRoot
  $shortcut.IconLocation = (Join-Path $installRoot "TimeArc.exe") + ",0"
  $shortcut.Save()
}
Start-Process -FilePath (Join-Path $installRoot "TimeArc.exe") -WorkingDirectory $installRoot
'@
  $installScript = Join-Path $work "install.ps1"
  Set-Content -LiteralPath $installScript -Value $installer -Encoding UTF8
  $archive = Join-Path $work "payload.7z"
  & $sevenZipPath a -t7z -mx=9 $archive $installScript (Join-Path $work $zipName)
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $archive)) {
    Write-Error "7-Zip failed to create the installer payload"
    exit 1
  }
  $configText = @"
;!@Install@!UTF-8!
Title="TimeArc $Version Test Installer"
BeginPrompt="Install TimeArc $Version for the current Windows user?"
Directory=""
RunProgram="powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1"
;!@InstallEnd@!
"@
  $config = [Text.UTF8Encoding]::new($false).GetBytes($configText)
  if (Test-Path $setup) { Remove-Item -LiteralPath $setup -Force }
  $output = [IO.File]::OpenWrite($setup)
  try {
    foreach ($source in @($sfxPath, $archive)) {
      $bytes = [IO.File]::ReadAllBytes($source)
      $output.Write($bytes, 0, $bytes.Length)
      if ($source -eq $sfxPath) { $output.Write($config, 0, $config.Length) }
    }
  } finally {
    $output.Dispose()
  }
  if (-not (Test-Path $setup -PathType Leaf) -or (Get-Item $setup).Length -le (Get-Item $archive).Length) {
    Write-Error "SFX assembly failed: $setup"
    exit 1
  }
  Write-Output "package-installer: OK -> $setup"
} finally {
  if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
