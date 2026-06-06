<#
.SYNOPSIS
    Install this repo's tracked git hooks (tools/git-hooks/*) into .git/hooks.
    Run once per clone. Hooks are NOT shared by git automatically, so each
    clone that wants the launch-script contribution guard must run this.

.EXAMPLE
    pwsh -File tools/install-hooks.ps1
#>
$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$src = Join-Path $RepoRoot 'tools/git-hooks'
$gitDir = (& git -C $RepoRoot rev-parse --git-dir).Trim()
if (-not [System.IO.Path]::IsPathRooted($gitDir)) { $gitDir = Join-Path $RepoRoot $gitDir }
$dst = Join-Path $gitDir 'hooks'

New-Item -ItemType Directory -Force -Path $dst | Out-Null
Get-ChildItem -File $src | ForEach-Object {
    Copy-Item $_.FullName (Join-Path $dst $_.Name) -Force
    Write-Host "[install-hooks] installed $($_.Name) -> $dst"
}
Write-Host "[install-hooks] Done."
