## Pure release-state logic shared by Update Manager and its regression test.
##
## GitHub reports one conclusion for the whole workflow, but the installed
## launcher only depends on two release assets. A separate Pages failure must
## therefore be a warning after those assets are proved live, not a false claim
## that the desktop update failed.

function Get-BeastRoadDesktopReleaseStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Release,

        [string]$WorkflowConclusion = ''
    )

    $gameAsset = $Release.assets | Where-Object {
        $_.name -eq 'BeastRoad-windows.zip' -and $_.state -eq 'uploaded' -and $_.size -gt 0
    } | Select-Object -First 1
    $launcherAsset = $Release.assets | Where-Object {
        $_.name -eq 'BeastRoadLauncher.exe' -and $_.state -eq 'uploaded' -and $_.size -gt 0
    } | Select-Object -First 1

    [pscustomobject]@{
        Ready = [bool]($gameAsset -and $launcherAsset)
        GameAsset = $gameAsset
        LauncherAsset = $launcherAsset
        AuxiliaryWarning = [bool]($WorkflowConclusion -and $WorkflowConclusion -ne 'success')
    }
}
