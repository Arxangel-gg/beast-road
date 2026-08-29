## Pure release-state logic shared by Update Manager and its regression test.
##
## GitHub reports one conclusion for the whole workflow, but the installed
## launcher only depends on two release assets. A failure elsewhere in the build
## must therefore be a warning after those two are proved live, not a false claim
## that the desktop update failed. v0.4.32 reported a whole update as failed over
## a Pages job, sending the owner back to republish something players could
## already download.
##
## The web build is a **third** asset and a different question. It does not reach
## anybody automatically - it is a zip a person uploads to Netlify - so a missing
## one must never block a desktop update, and a present one has to be *said out
## loud*, because otherwise the only signal that there is a new web build to
## deploy is remembering that there always is.

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
    $webAsset = $Release.assets | Where-Object {
        $_.name -eq 'BeastRoad-web.zip' -and $_.state -eq 'uploaded' -and $_.size -gt 0
    } | Select-Object -First 1

    [pscustomobject]@{
        # Deliberately the two desktop assets only. The web zip is not part of
        # readiness because nothing downloads it on its own.
        Ready = [bool]($gameAsset -and $launcherAsset)
        GameAsset = $gameAsset
        LauncherAsset = $launcherAsset
        WebAsset = $webAsset
        WebReady = [bool]$webAsset
        AuxiliaryWarning = [bool]($WorkflowConclusion -and $WorkflowConclusion -ne 'success')
    }
}


## Converts a successful HEAD response for a canonical release download into
## the same small asset shape returned by GitHub's release API. This is the
## publisher's rate-limit/cache fallback: the player-facing file can be live
## while the API watcher is temporarily unavailable or stale.
function ConvertTo-BeastRoadReleaseAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Response,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $status = [int]$Response.StatusCode
    if ($status -lt 200 -or $status -ge 300) { return $null }
    $rawLength = @($Response.Headers['Content-Length']) | Select-Object -First 1
    $size = 0L
    try { $size = [long]([string]$rawLength) } catch { $size = 0L }
    if ($size -le 0) { return $null }
    [pscustomobject]@{ name = $Name; size = $size; state = 'uploaded' }
}
