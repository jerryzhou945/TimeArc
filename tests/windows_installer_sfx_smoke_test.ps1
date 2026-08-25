param(
  [string]$SevenZip = ".local-toolchains/7zip-26.02/extra/x64/7za.exe",
  [string]$SfxModule = ".local-toolchains/7zip-26.02/lzma/bin/7zSD.sfx"
)
$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sevenZipPath = Join-Path $repo $SevenZip
$sfxPath = Join-Path $repo $SfxModule
$work = Join-Path ([IO.Path]::GetTempPath()) ("timearc-sfx-smoke-" + [guid]::NewGuid().ToString("N"))
$marker = Join-Path $work "executed.marker"
New-Item -ItemType Directory -Path $work | Out-Null
try {
  $script = Join-Path $work "install.ps1"
  Set-Content -LiteralPath $script -Encoding UTF8 -Value "Set-Content -LiteralPath '$marker' -Value executed"
  $archive = Join-Path $work "payload.7z"
  & $sevenZipPath a -t7z -mx=1 $archive $script | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "failed to create smoke payload" }

  $configText = @'
;!@Install@!UTF-8!
Progress="no"
Directory=""
RunProgram="powershell.exe -NoProfile -ExecutionPolicy Bypass -File install.ps1"
;!@InstallEnd@!
'@
  $config = [Text.UTF8Encoding]::new($false).GetBytes($configText)
  $sfx = Join-Path $work "smoke.exe"
  $output = [IO.File]::OpenWrite($sfx)
  try {
    foreach ($source in @($sfxPath, $archive)) {
      $bytes = [IO.File]::ReadAllBytes($source)
      $output.Write($bytes, 0, $bytes.Length)
      if ($source -eq $sfxPath) { $output.Write($config, 0, $config.Length) }
    }
  } finally {
    $output.Dispose()
  }

  $process = Start-Process -FilePath $sfx -Wait -PassThru
  if ($process.ExitCode -ne 0) { throw "smoke SFX exited with $($process.ExitCode)" }
  if (-not (Test-Path $marker)) { throw "Installer Config did not execute install.ps1" }
  Write-Output "windows_installer_sfx_smoke_test: OK"
} finally {
  if (Test-Path $work) { Remove-Item -LiteralPath $work -Recurse -Force }
}
