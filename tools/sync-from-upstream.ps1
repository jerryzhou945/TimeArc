<#
.SYNOPSIS
    Down-sync: merge upstream/dev into a fresh sync branch off origin/dev, while
    KEEPING this fork's own run.cmd / launch.cmd (the drive-independent versions).

.DESCRIPTION
    run.cmd / launch.cmd are fork-local. Upstream's copies hardcode the
    maintainer's paths, so a plain merge of upstream/dev would replace this
    fork's working launch scripts with upstream's. A git `merge=ours` attribute
    does NOT help here: when only upstream changed the file (the normal case),
    git fast-forwards it to upstream's blob and the driver never runs.

    The robust fix is deterministic: after staging the merge, force the two
    launch scripts back to origin/dev's version. This script does exactly that.
    If the merge has conflicts in OTHER files, it stops so you can resolve them
    (the launch scripts are already pinned to ours by then).

.EXAMPLE
    pwsh -File tools/sync-from-upstream.ps1
#>
[CmdletBinding()]
param(
    [string]$Branch = "sync/upstream-dev-$(Get-Date -Format yyyyMMdd)"
)

$ErrorActionPreference = 'Stop'
$RepoRoot  = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$ForkRepo  = 'Yonezawa-Akane/TimeArc'
$PinFiles  = @('run.cmd', 'launch.cmd')

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)] $GitArgs)
    $out = & git -C $RepoRoot @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "git $($GitArgs -join ' ') failed (exit $LASTEXITCODE)" }
    return $out
}

$dirty = Invoke-Git status --porcelain --untracked-files=no
if ($dirty) { throw "[sync] Working tree has uncommitted tracked changes; commit/stash first." }

Write-Host "[sync] Fetching origin + upstream..."
Invoke-Git fetch origin  | Out-Null
Invoke-Git fetch upstream | Out-Null

Write-Host "[sync] Branch '$Branch' off origin/dev, merging upstream/dev..."
Invoke-Git checkout -b $Branch origin/dev | Out-Null

# Stage the merge without committing so we can override the launch scripts first.
& git -C $RepoRoot merge --no-commit --no-ff upstream/dev
$mergeExit = $LASTEXITCODE

# Force OUR (fork-local) launch scripts regardless of what the merge produced.
Invoke-Git checkout origin/dev -- @PinFiles | Out-Null
Write-Host "[sync] Pinned $($PinFiles -join ', ') back to this fork's version."

if ($mergeExit -ne 0) {
    Write-Host "[sync] The merge has conflicts in OTHER files. Resolve them, then:"
    Write-Host "         git commit       (launch scripts are already pinned to ours)"
    Write-Host "         git push -u origin $Branch"
    Write-Host "         gh pr create --repo $ForkRepo --base dev --head $Branch"
    exit 1
}

Invoke-Git commit -m "Merge upstream/dev into $Branch (keep fork-local launch scripts)" | Out-Null
Invoke-Git push -u origin $Branch | Out-Null
Write-Host "[sync] Merged + pushed. Open the PR into your fork's dev:"
Write-Host "         gh pr create --repo $ForkRepo --base dev --head $Branch"
