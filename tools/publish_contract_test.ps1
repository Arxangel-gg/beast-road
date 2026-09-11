$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'publish_contract.ps1')

function New-Asset([string]$Name, [int]$Size = 1024, [string]$State = 'uploaded') {
    [pscustomobject]@{ name = $Name; size = $Size; state = $State }
}

$complete = [pscustomobject]@{ assets = @(
    (New-Asset 'BeastRoad-windows.zip'),
    (New-Asset 'BeastRoadLauncher.exe'),
    (New-Asset 'BeastRoad-web.zip')
) }
$missingLauncher = [pscustomobject]@{ assets = @(
    (New-Asset 'BeastRoad-windows.zip')
) }
$emptyGame = [pscustomobject]@{ assets = @(
    (New-Asset 'BeastRoad-windows.zip' 0),
    (New-Asset 'BeastRoadLauncher.exe')
) }
$noWeb = [pscustomobject]@{ assets = @(
    (New-Asset 'BeastRoad-windows.zip'),
    (New-Asset 'BeastRoadLauncher.exe')
) }
$emptyWeb = [pscustomobject]@{ assets = @(
    (New-Asset 'BeastRoad-windows.zip'),
    (New-Asset 'BeastRoadLauncher.exe'),
    (New-Asset 'BeastRoad-web.zip' 0)
) }

$ok = Get-BeastRoadDesktopReleaseStatus -Release $complete -WorkflowConclusion 'success'
if (-not $ok.Ready -or $ok.AuxiliaryWarning) {
    throw 'A successful workflow with both desktop assets must be ready without a warning.'
}
if (-not $ok.WebReady -or $ok.WebAsset.name -ne 'BeastRoad-web.zip') {
    throw 'A release carrying the web zip must report it, so the owner knows there is one to deploy.'
}

$pagesFailed = Get-BeastRoadDesktopReleaseStatus -Release $complete -WorkflowConclusion 'failure'
if (-not $pagesFailed.Ready -or -not $pagesFailed.AuxiliaryWarning) {
    throw 'A Pages-only failure must preserve desktop readiness and show an auxiliary warning.'
}

# A web build that did not upload must never hold back a desktop update: the
# launcher does not read it and players are not waiting on it.
foreach ($release in @($noWeb, $emptyWeb)) {
    $status = Get-BeastRoadDesktopReleaseStatus -Release $release -WorkflowConclusion 'success'
    if (-not $status.Ready) {
        throw 'A missing or empty web zip must not block a desktop update.'
    }
    if ($status.WebReady) {
        throw 'A missing or empty web zip must not be reported as deployable.'
    }
}

foreach ($release in @($missingLauncher, $emptyGame)) {
    $failed = Get-BeastRoadDesktopReleaseStatus -Release $release -WorkflowConclusion 'failure'
    if ($failed.Ready) {
        throw 'Missing or empty launcher-facing assets must never be reported as published.'
    }
}

$head = [pscustomobject]@{
    StatusCode = 200
    Headers = @{ 'Content-Length' = @('4096') }
}
$direct = ConvertTo-BeastRoadReleaseAsset -Response $head -Name 'BeastRoad-windows.zip'
if (-not $direct -or $direct.size -ne 4096 -or $direct.state -ne 'uploaded') {
    throw 'A live canonical download must recover release readiness when the API watcher is stale.'
}
$emptyHead = [pscustomobject]@{
    StatusCode = 200
    Headers = @{ 'Content-Length' = @('0') }
}
if (ConvertTo-BeastRoadReleaseAsset -Response $emptyHead -Name 'empty.zip') {
    throw 'A zero-byte direct download must never be treated as a published asset.'
}

# A green local publisher must cover every gate that would otherwise fail
# only after consuming a tag on GitHub. The manager no longer lists gates by
# hand - a hand-kept list rots while CI grows - it runs tools/sweep.sh, which
# derives the list from the workflows. So what is asserted here is that it
# still does, for both sweeps, and that it lists no gate of its own that could
# drift out of step with them. Read source; never open the manager UI.
$repoRoot = Split-Path -Parent $PSScriptRoot
$manager = Get-Content -LiteralPath (Join-Path $repoRoot 'tools/publish.ps1') -Raw
if ($manager -notmatch "tools/sweep\.sh") {
    throw 'tools/publish.ps1 must run tools/sweep.sh before tagging.'
}
foreach ($which in @('release', 'guard')) {
    if ($manager -notmatch "'$which'") {
        throw "tools/publish.ps1 must run the $which sweep."
    }
}
# Only the publish path is held to that. The Tuning tab runs balance_test on
# its own, which is a feature rather than a pre-flight list.
$publishStart = $manager.IndexOf('$btn.Add_Click({')
$publishEnd = $manager.IndexOf("Write-Log 'local validation passed'")
if ($publishStart -lt 0 -or $publishEnd -le $publishStart) {
    throw 'tools/publish.ps1 no longer has the publish block this test reads.'
}
$publishBlock = $manager.Substring($publishStart, $publishEnd - $publishStart)
if ([regex]::Matches($publishBlock, [regex]::Escape('res://tools/')).Count -ne 0) {
    throw 'tools/publish.ps1 must not name gates in its pre-flight; the sweep derives them from the workflows.'
}
if (-not (Test-Path (Join-Path $repoRoot 'tools/sweep.sh'))) {
    throw 'tools/sweep.sh is missing.'
}
foreach ($source in @('.github/workflows/guard.yml', '.github/workflows/release.yml')) {
    $body = Get-Content -LiteralPath (Join-Path $repoRoot $source) -Raw
    foreach ($gate in @('chronicle_goal_check', 'support_diagnostics_check', 'gdd_audit_check', 'menu_layout_check', 'town_click_check', 'merchant_check', 'user_dir_check', 'save_backup_check')) {
        $count = [regex]::Matches($body, [regex]::Escape("res://tools/$gate.tscn")).Count
        if ($count -ne 1) {
            throw "$source must run $gate exactly once; found $count."
        }
    }
}

Write-Output '[publisher] PASS - desktop asset contract, stale API recovery, non-blocking web, and the sweep-derived pre-flight'
