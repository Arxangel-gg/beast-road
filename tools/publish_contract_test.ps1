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

$ok = Get-BeastRoadDesktopReleaseStatus -Release $complete -WorkflowConclusion 'success'
if (-not $ok.Ready -or $ok.AuxiliaryWarning) {
    throw 'A successful workflow with both desktop assets must be ready without a warning.'
}

$pagesFailed = Get-BeastRoadDesktopReleaseStatus -Release $complete -WorkflowConclusion 'failure'
if (-not $pagesFailed.Ready -or -not $pagesFailed.AuxiliaryWarning) {
    throw 'A Pages-only failure must preserve desktop readiness and show an auxiliary warning.'
}

foreach ($release in @($missingLauncher, $emptyGame)) {
    $failed = Get-BeastRoadDesktopReleaseStatus -Release $release -WorkflowConclusion 'failure'
    if ($failed.Ready) {
        throw 'Missing or empty launcher-facing assets must never be reported as published.'
    }
}

Write-Output '[publisher] PASS - desktop assets are authoritative; auxiliary failure remains visible'
