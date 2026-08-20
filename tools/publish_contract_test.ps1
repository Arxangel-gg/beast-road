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

Write-Output '[publisher] PASS - desktop assets are authoritative; web zip is reported but never blocking; auxiliary failure remains visible'
