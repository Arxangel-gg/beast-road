# Beast Road - Update Manager
#
# A small window for publishing a game update. Type a version, write a note,
# press Publish. It commits anything outstanding, tags, pushes, then watches the
# GitHub Actions build and tells you when players can get it.
#
# WinForms rather than a second Godot app on purpose: the launcher is already
# 109 MB because Godot bundles its whole engine, and a publisher tool does not
# deserve another copy of that. This is ~20 KB and native to the machine.
#
# Run:  right-click publish.ps1 -> Run with PowerShell
#   or: tools\Update Manager.bat

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Owner    = 'Arxangel-gg'
$Repo     = 'beast-road'
. (Join-Path $PSScriptRoot 'publish_contract.ps1')

# --- palette, matched to the game -------------------------------------------
$cVoid   = [System.Drawing.Color]::FromArgb(11, 20, 22)
$cSlate  = [System.Drawing.Color]::FromArgb(30, 46, 51)
$cAmber  = [System.Drawing.Color]::FromArgb(232, 163, 61)
$cBone   = [System.Drawing.Color]::FromArgb(217, 205, 184)
$cRust   = [System.Drawing.Color]::FromArgb(140, 58, 43)
$cGreen  = [System.Drawing.Color]::FromArgb(122, 168, 108)

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'Beast Road - Update Manager'
$form.Size            = New-Object System.Drawing.Size(776, 700)
$form.StartPosition   = 'CenterScreen'
$form.BackColor       = $cVoid
$form.ForeColor       = $cBone
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 10)

$tabs                 = New-Object System.Windows.Forms.TabControl
$tabs.Location        = New-Object System.Drawing.Point(6, 6)
$tabs.Size            = New-Object System.Drawing.Size(752, 652)
$form.Controls.Add($tabs)

$pagePublish          = New-Object System.Windows.Forms.TabPage
$pagePublish.Text     = 'Publish'
$pagePublish.BackColor = $cVoid
$tabs.TabPages.Add($pagePublish)

function New-Label($text, $x, $y, $w, $size, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    # Height from the font, not a fixed 24. Every label shared one hardcoded
    # height, so the 20pt title - which needs about 34 pixels - was cropped
    # through the descenders while the 9pt lines it was written for were fine.
    $h = [int][Math]::Ceiling($size * 1.9) + 6
    if ($h -lt 24) { $h = 24 }
    $l.Size = New-Object System.Drawing.Size($w, $h)
    $l.Font = New-Object System.Drawing.Font('Segoe UI', $size)
    $l.ForeColor = $color
    $pagePublish.Controls.Add($l); return $l
}

New-Label 'BEAST ROAD' 24 18 400 20 $cAmber | Out-Null
New-Label 'Publish an update to every installed launcher' 26 62 520 10 $cBone | Out-Null

# --- current state -----------------------------------------------------------
$lblCurrent = New-Label 'Checking...' 26 88 680 9 ([System.Drawing.Color]::FromArgb(150, 160, 160))

# --- version -----------------------------------------------------------------
New-Label 'Version' 26 128 200 10 $cBone | Out-Null
$txtVersion           = New-Object System.Windows.Forms.TextBox
$txtVersion.Location  = New-Object System.Drawing.Point(26, 154)
$txtVersion.Size      = New-Object System.Drawing.Size(200, 30)
$txtVersion.BackColor = $cSlate
$txtVersion.ForeColor = $cBone
$txtVersion.BorderStyle = 'FixedSingle'
$txtVersion.Font      = New-Object System.Drawing.Font('Consolas', 12)
$pagePublish.Controls.Add($txtVersion)

# --- notes -------------------------------------------------------------------
New-Label 'What changed (shown on the release page)' 26 196 500 10 $cBone | Out-Null
$txtNotes             = New-Object System.Windows.Forms.TextBox
$txtNotes.Location    = New-Object System.Drawing.Point(26, 222)
$txtNotes.Size        = New-Object System.Drawing.Size(690, 90)
$txtNotes.Multiline   = $true
$txtNotes.BackColor   = $cSlate
$txtNotes.ForeColor   = $cBone
$txtNotes.BorderStyle = 'FixedSingle'
$pagePublish.Controls.Add($txtNotes)

# --- publish button ----------------------------------------------------------
$btn                  = New-Object System.Windows.Forms.Button
$btn.Text             = 'PUBLISH UPDATE'
$btn.Location         = New-Object System.Drawing.Point(26, 328)
$btn.Size             = New-Object System.Drawing.Size(240, 48)
$btn.BackColor        = $cRust
$btn.ForeColor        = $cBone
$btn.FlatStyle        = 'Flat'
$btn.Font             = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$btn.FlatAppearance.BorderColor = $cAmber
$pagePublish.Controls.Add($btn)

$lblStage = New-Label '' 286 340 430 10 $cAmber

# --- progress ----------------------------------------------------------------
#
# Owner-drawn rather than a WinForms ProgressBar, because a ProgressBar cannot
# carry text. Publishing takes five to eight minutes and spends most of it
# waiting on a machine you cannot see, so a bar that only fills is a bar that
# leaves you wondering whether anything is happening. This one says what step it
# is on, what percent it is at and how long it has left, on the bar itself.

$script:BarValue  = 0
$script:BarStage  = ''
$script:BarDetail = ''
$script:BarEta    = ''
$script:BarFailed = $false

$bar                  = New-Object System.Windows.Forms.Panel
$bar.Location         = New-Object System.Drawing.Point(26, 386)
$bar.Size             = New-Object System.Drawing.Size(690, 30)
$bar.BackColor        = [System.Drawing.Color]::FromArgb(8, 14, 16)
# Panels flicker badly when repainted this often; DoubleBuffered is protected,
# so reflection is the only way to reach it from PowerShell.
[System.Windows.Forms.Control].GetProperty(
    'DoubleBuffered', 'Instance,NonPublic').SetValue($bar, $true, $null)
$bar.Add_Paint({
    param($sender, $e)
    $g = $e.Graphics
    $g.SmoothingMode = 'AntiAlias'
    $w = $sender.ClientSize.Width
    $h = $sender.ClientSize.Height

    $fill = [int]([Math]::Round($w * ([Math]::Max([Math]::Min($script:BarValue, 100), 0) / 100.0)))
    if ($fill -gt 0) {
        $top = if ($script:BarFailed) { $cRust } else { $cAmber }
        $rect = New-Object System.Drawing.Rectangle(0, 0, $fill, $h)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect, $top, [System.Drawing.Color]::FromArgb(120, $top.R, $top.G, $top.B), 90.0)
        $g.FillRectangle($brush, $rect)
        $brush.Dispose()
    }

    $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(70, 62, 50))
    $g.DrawRectangle($pen, 0, 0, $w - 1, $h - 1)
    $pen.Dispose()

    # Percent on the left, step in the middle, time remaining on the right - so
    # each answers a different question and none of them move as the bar fills.
    $font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    $ink = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(232, 226, 212))
    $fmtL = New-Object System.Drawing.StringFormat
    $fmtL.LineAlignment = 'Center'
    $fmtC = New-Object System.Drawing.StringFormat
    $fmtC.Alignment = 'Center'; $fmtC.LineAlignment = 'Center'; $fmtC.Trimming = 'EllipsisCharacter'
    $fmtC.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
    $fmtR = New-Object System.Drawing.StringFormat
    $fmtR.Alignment = 'Far'; $fmtR.LineAlignment = 'Center'

    $box = New-Object System.Drawing.RectangleF(10, 0, ($w - 20), $h)
    $g.DrawString(("{0}%" -f [int]$script:BarValue), $font, $ink, $box, $fmtL)
    $middle = $script:BarStage
    if ($script:BarDetail) { $middle = "$middle  -  $($script:BarDetail)" }
    $g.DrawString($middle, $font, $ink, $box, $fmtC)
    if ($script:BarEta) { $g.DrawString($script:BarEta, $font, $ink, $box, $fmtR) }

    $font.Dispose(); $ink.Dispose()
})
$pagePublish.Controls.Add($bar)

# --- log ---------------------------------------------------------------------
$log                  = New-Object System.Windows.Forms.TextBox
$log.Location         = New-Object System.Drawing.Point(26, 420)
$log.Size             = New-Object System.Drawing.Size(690, 170)
$log.Multiline        = $true
$log.ScrollBars       = 'Vertical'
$log.ReadOnly         = $true
$log.BackColor        = [System.Drawing.Color]::FromArgb(8, 14, 16)
$log.ForeColor        = [System.Drawing.Color]::FromArgb(150, 170, 165)
$log.Font             = New-Object System.Drawing.Font('Consolas', 9)
$log.BorderStyle      = 'FixedSingle'
$pagePublish.Controls.Add($log)

$lblLink              = New-Object System.Windows.Forms.LinkLabel
$lblLink.Location     = New-Object System.Drawing.Point(26, 598)
$lblLink.Size         = New-Object System.Drawing.Size(690, 24)
$lblLink.LinkColor    = $cAmber
$lblLink.ActiveLinkColor = $cBone
$lblLink.Visible      = $false
$pagePublish.Controls.Add($lblLink)

function Write-Log($msg) {
    $log.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $msg))
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}
# How long each step usually takes, in seconds. Not guesses: these are what the
# publish log has been showing across the releases so far.
#
# A simple "elapsed / percent" extrapolation is useless here, because the steps
# are wildly uneven - tagging is instant and the GitHub build is five minutes -
# so early progress would predict a finish that never arrives. Weighting each
# step and then correcting by how the finished ones actually went gives an
# estimate that is roughly right at the start and accurate by the middle.
$script:StageWeights = [ordered]@{
    'check'    = 3
    'validate' = 150
    'commit'   = 6
    'push'     = 12
    'tag'      = 8
    'build'    = 330
    'verify'   = 20
}
$script:StageOrder   = @('check', 'validate', 'commit', 'push', 'tag', 'build', 'verify')
$script:StageStarted = @{}
$script:RunStarted   = $null
$script:StageKey     = ''


function Format-Duration([double]$seconds) {
    if ($seconds -lt 0) { $seconds = 0 }
    if ($seconds -lt 60) { return ('{0:N0}s' -f $seconds) }
    $m = [Math]::Floor($seconds / 60)
    $s = [int]($seconds - ($m * 60))
    return ('{0}m {1:00}s' -f $m, $s)
}


## Seconds still expected, from the weights and how the finished steps went.
function Get-EtaSeconds {
    if (-not $script:StageKey) { return -1 }
    $index = [Array]::IndexOf($script:StageOrder, $script:StageKey)
    if ($index -lt 0) { return -1 }

    $doneWeight = 0
    for ($i = 0; $i -lt $index; $i++) { $doneWeight += $script:StageWeights[$script:StageOrder[$i]] }

    $elapsed = ((Get-Date) - $script:RunStarted).TotalSeconds
    # Correction factor: this machine and this connection against the expected
    # pace. Clamped so one slow step cannot predict an absurd finish.
    $pace = 1.0
    if ($doneWeight -gt 0) {
        $inStage = ((Get-Date) - $script:StageStarted[$script:StageKey]).TotalSeconds
        $pace = [Math]::Max([Math]::Min((($elapsed - $inStage) / $doneWeight), 3.0), 0.4)
    }

    $remaining = 0
    for ($i = $index; $i -lt $script:StageOrder.Count; $i++) {
        $remaining += $script:StageWeights[$script:StageOrder[$i]]
    }
    $inCurrent = ((Get-Date) - $script:StageStarted[$script:StageKey]).TotalSeconds
    return [Math]::Max(($remaining * $pace) - $inCurrent, 0)
}


function Set-Stage($text, $pct, $key = '', $detail = '') {
    if ($key -and $key -ne $script:StageKey) {
        $script:StageKey = $key
        $script:StageStarted[$key] = Get-Date
        if (-not $script:RunStarted) { $script:RunStarted = Get-Date }
    }
    $lblStage.Text = $text
    $script:BarStage  = $text
    $script:BarDetail = $detail
    $script:BarValue  = [Math]::Min([Math]::Max($pct, 0), 100)

    $eta = Get-EtaSeconds
    if ($eta -ge 0 -and $script:BarValue -lt 100) {
        $script:BarEta = "about $(Format-Duration $eta) left"
    } elseif ($script:BarValue -ge 100) {
        $total = if ($script:RunStarted) { ((Get-Date) - $script:RunStarted).TotalSeconds } else { 0 }
        $script:BarEta = "done in $(Format-Duration $total)"
    }
    $bar.Invalidate()
    [System.Windows.Forms.Application]::DoEvents()
}

function Invoke-Git {
    param([string[]]$GitArgs)
    $out = & git -C $RepoRoot @GitArgs 2>&1
    return @{ Code = $LASTEXITCODE; Text = ($out -join "`n") }
}

# --- work out where we are ---------------------------------------------------
function Suggest-Version {
    $r = Invoke-Git @('tag', '--list', 'v*', '--sort=-v:refname')
    $tags = @($r.Text -split "`n" | Where-Object { $_ -match '^v\d' })
    if ($tags.Count -eq 0) { return '0.1.0', 'none yet' }
    $latest = $tags[0].Trim()
    if ($latest -match '^v(\d+)\.(\d+)\.(\d+)$') {
        return ("{0}.{1}.{2}" -f $Matches[1], $Matches[2], ([int]$Matches[3] + 1)), $latest
    }
    return '0.1.0', $latest
}

$suggested, $latestTag = Suggest-Version
$txtVersion.Text = $suggested
## What the finished package is likely to weigh.
##
## The packaging happens on GitHub, not here, so there is nothing local to
## measure while it runs. The previous release's asset sizes are the honest
## estimate - the archive changes by a megabyte or two between builds, not by an
## order of magnitude - and saying "about 89 MB, from v0.3.9" is far better than
## a progress bar that reveals the size only once there is nothing left to wait
## for.
$script:SizeEstimate = ''
$script:LastSizes = $null
try {
    $prev = Invoke-RestMethod -TimeoutSec 10 `
        -Uri "https://api.github.com/repos/$Owner/$Repo/releases/latest" `
        -Headers @{ 'User-Agent' = 'BeastRoadPublisher' }
    $pg = $prev.assets | Where-Object { $_.name -eq 'BeastRoad-windows.zip' } | Select-Object -First 1
    $pl = $prev.assets | Where-Object { $_.name -eq 'BeastRoadLauncher.exe' } | Select-Object -First 1
    if ($pg -and $pl) {
        $script:LastSizes = @{ Tag = $prev.tag_name; Game = $pg.size; Launcher = $pl.size }
        $script:SizeEstimate = ('about {0:N0} MB' -f (($pg.size + $pl.size) / 1MB))
    }
} catch {
    # No network, or a first release. The bar simply carries no estimate.
}

$dirty = (Invoke-Git @('status', '--porcelain')).Text.Trim()
$changeCount = if ($dirty) { @($dirty -split "`n").Count } else { 0 }
$lblCurrent.Text = "Latest local tag: $latestTag     Uncommitted changes: $changeCount"

# --- publish -----------------------------------------------------------------
$btn.Add_Click({
    $version = $txtVersion.Text.Trim().TrimStart('v')
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        [System.Windows.Forms.MessageBox]::Show(
            "Version must look like 0.2.0", 'Beast Road') | Out-Null
        return
    }
    $tag = "v$version"
    $btn.Enabled = $false
    $lblLink.Visible = $false
    $log.Clear()

    try {
        Set-Stage 'Checking the repository' 3 'check'
        $remote = (Invoke-Git @('remote', 'get-url', 'origin'))
        if ($remote.Code -ne 0) { throw "No 'origin' remote. Publish the repo in GitHub Desktop first." }
        Write-Log "remote: $($remote.Text.Trim())"

        $exists = Invoke-Git @('tag', '--list', $tag)
        if ($exists.Text.Trim() -eq $tag) { throw "$tag already exists. Pick a higher version." }
        $remoteTag = Invoke-Git @('ls-remote', '--tags', 'origin', "refs/tags/$tag")
        if ($remoteTag.Text.Trim()) { throw "$tag already exists on GitHub. Pick a higher version." }

        # Validate the exact working tree before it is committed and before an
        # immutable version tag is spent. These must run sequentially: two
        # local Godot processes can race while rotating the same AppData log.
        Set-Stage 'Validating the game and launcher' 8 'validate'
        $godotDir = Join-Path $RepoRoot 'Godot_v4.7.1-stable_win64.exe'
        $godot = Get-ChildItem -LiteralPath $godotDir -Filter '*_console.exe' -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $godot) { throw "Godot console executable not found in $godotDir" }
        $checks = @(
            @{ Name = 'game'; Args = @('--headless', '--path', (Join-Path $RepoRoot 'game'), '--quit') },
            @{ Name = 'production art'; Args = @('--headless', '--path', (Join-Path $RepoRoot 'game'), '--script', 'res://tools/run_tool.gd', '--', 'report') },
            @{ Name = 'structure animation art'; Args = @('--headless', '--path', (Join-Path $RepoRoot 'game'), 'res://tools/structure_art_check.tscn') },
            @{ Name = 'balance'; Args = @('--headless', '--path', (Join-Path $RepoRoot 'game'), 'res://tools/balance_test.tscn') },
            @{ Name = 'game runtime'; Args = @('--headless', '--path', (Join-Path $RepoRoot 'game'), 'res://tools/soak.tscn', '--', '--seconds=3', '--shots=100', '--build') },
            @{ Name = 'launcher updater'; Args = @('--headless', '--path', (Join-Path $RepoRoot 'launcher'), 'res://tests/release_pipeline_test.tscn') }
        )
        foreach ($check in $checks) {
            Write-Log "checking $($check.Name)..."
            $checkOutput = & $godot.FullName @($check.Args) 2>&1
            $checkText = $checkOutput -join "`n"
            if ($LASTEXITCODE -ne 0 -or $checkText -match '(?m)^(SCRIPT )?ERROR:|^WARNING:') {
                throw "$($check.Name) validation failed:`n$($checkOutput -join "`n")"
            }
        }
        Write-Log 'local validation passed'

        # Anything outstanding gets committed, so the build matches what is on
        # screen rather than the last time someone remembered to commit.
        $pending = (Invoke-Git @('status', '--porcelain')).Text.Trim()
        if ($pending) {
            Set-Stage 'Committing your changes' 30 'commit'
            $n = @($pending -split "`n").Count
            Write-Log "committing $n changed file(s)"
            $add = Invoke-Git @('add', '-A')
            if ($add.Code -ne 0) { throw "staging failed:`n$($add.Text)" }
            $msg = $txtNotes.Text.Trim()
            if (-not $msg) { $msg = "Update $tag" }
            $c = Invoke-Git @('commit', '-m', $msg)
            if ($c.Code -ne 0) { throw "commit failed:`n$($c.Text)" }
            Write-Log 'committed'
        } else {
            Write-Log 'nothing to commit, tree is clean'
        }

        Set-Stage 'Pushing to GitHub' 34 'push'
        $branch = (Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')).Text.Trim()

        # Take anything that landed while you were working, before pushing.
        #
        # Three people push to this branch: this window, and two agents. Without
        # this, a publish that began after somebody else's push is rejected as a
        # non-fast-forward - and it fails *after* committing your work, which
        # leaves you staring at an error with a commit you did not expect and no
        # obvious way forward.
        #
        # Rebase rather than merge: it replays your commits on top of theirs, so
        # the history stays a straight line and a release tag points at something
        # a human can read. Work on different files - which is the normal case
        # here, because the three of us own different directories - merges with no
        # interaction at all.
        Write-Log 'fetching before push...'
        $f = Invoke-Git @('fetch', 'origin', $branch)
        if ($f.Code -ne 0) { throw "could not reach GitHub:`n$($f.Text)" }

        $behind = (Invoke-Git @('rev-list', '--count', "HEAD..origin/$branch")).Text.Trim()
        if ($behind -and $behind -ne '0') {
            Write-Log "$behind commit(s) arrived while you were working - rebasing onto them"
            $r = Invoke-Git @('rebase', "origin/$branch")
            if ($r.Code -ne 0) {
                # Leave the repository exactly as it was found. A half-finished
                # rebase is a far worse thing to hand back than a clear refusal.
                [void](Invoke-Git @('rebase', '--abort'))
                throw ("your changes and the ones already pushed touch the same lines, " +
                    "so they cannot be combined automatically.`n`n" +
                    "Nothing was changed. Resolve it in a terminal, then publish again.`n`n" +
                    $r.Text)
            }
            Write-Log 'rebased cleanly'
        }

        $p = Invoke-Git @('push', 'origin', $branch)
        if ($p.Code -ne 0) {
            # One retry: somebody may have pushed in the seconds between the fetch
            # and the push. Losing a whole publish to a race that narrow would be
            # silly when trying again costs a second.
            Write-Log 'push rejected, someone pushed just now - retrying once'
            [void](Invoke-Git @('fetch', 'origin', $branch))
            $r2 = Invoke-Git @('rebase', "origin/$branch")
            if ($r2.Code -ne 0) {
                [void](Invoke-Git @('rebase', '--abort'))
                throw "push failed and the retry could not be combined automatically:`n$($r2.Text)"
            }
            $p = Invoke-Git @('push', 'origin', $branch)
            if ($p.Code -ne 0) { throw "push failed:`n$($p.Text)" }
        }
        Write-Log "pushed $branch"
        $commitSha = (Invoke-Git @('rev-parse', 'HEAD')).Text.Trim()

        Set-Stage 'Tagging the release' 38 'tag'
        $notes = $txtNotes.Text.Trim()
        if (-not $notes) { $notes = "Beast Road $tag" }
        $t = Invoke-Git @('tag', '-a', $tag, '-m', $notes)
        if ($t.Code -ne 0) { throw "tag failed:`n$($t.Text)" }
        $tp = Invoke-Git @('push', 'origin', $tag)
        if ($tp.Code -ne 0) { throw "tag push failed:`n$($tp.Text)" }
        Write-Log "pushed $tag - GitHub is building now"

        # --- watch the build ---
        Set-Stage 'Building on GitHub' 42 'build' $script:SizeEstimate
        if ($script:SizeEstimate) {
            Write-Log ("packaging - estimated {0} based on {1}" -f `
                $script:SizeEstimate, $script:LastSizes.Tag)
        }
        $api = "https://api.github.com/repos/$Owner/$Repo/actions/workflows/release.yml/runs?event=push&per_page=20"
        $headers = @{ 'User-Agent' = 'BeastRoadPublisher' }
        $done = $false
        $seenRun = $false
        $workflowConclusion = ''
        $workflowUrl = ''
        for ($i = 0; $i -lt 90; $i++) {
            Start-Sleep -Seconds 10
            try {
                $runs = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 20
                $run = $runs.workflow_runs | Where-Object {
                    $_.head_branch -eq $tag -and $_.head_sha -eq $commitSha
                } | Select-Object -First 1
            } catch {
                Write-Log 'waiting for GitHub...'
                continue
            }
            if (-not $run) {
                if ($i % 3 -eq 0) { Write-Log "waiting for the $tag build to start..." }
                continue
            }
            if (-not $seenRun) {
                Write-Log "watching build #$($run.run_number): $($run.html_url)"
                $seenRun = $true
            }

            if ($run.status -eq 'completed') {
                $workflowConclusion = [string]$run.conclusion
                $workflowUrl = [string]$run.html_url
                if ($run.conclusion -eq 'success') {
                    Write-Log 'build succeeded'
                } else {
                    # The web deployment is a separate job by design. GitHub can
                    # publish every file the installed launcher needs and then
                    # fail Pages because the repository's one-time Pages setting
                    # is off. v0.4.32 did exactly that: reporting the whole update
                    # as failed sent the owner back to republish an update players
                    # could already download. The release assets below are the
                    # player-facing authority; a failed auxiliary job becomes a
                    # visible warning only after those files are proved live.
                    Write-Log "workflow finished as '$($run.conclusion)' - checking the published files before deciding"
                }
                $done = $true
                break
            }
            Set-Stage "Building on GitHub ($($run.status))" `
                ([Math]::Min(42 + $i * 2, 92)) 'build' $script:SizeEstimate
        }
        if (-not $done) { throw 'timed out waiting for the workflow. Check the Actions tab.' }

        # A successful job is not the player-facing finish line. Confirm that
        # GitHub's release API can see both files the launcher depends on.
        Set-Stage 'Verifying the published files' 94 'verify'
        $releaseApi = "https://api.github.com/repos/$Owner/$Repo/releases/tags/$tag"
        $releaseReady = $false
        $releaseStatus = $null
        for ($i = 0; $i -lt 30; $i++) {
            try {
                $release = Invoke-RestMethod -Uri $releaseApi -Headers $headers -TimeoutSec 20
                $releaseStatus = Get-BeastRoadDesktopReleaseStatus `
                    -Release $release -WorkflowConclusion $workflowConclusion
                if ($releaseStatus.Ready) {
                    $gameAsset = $releaseStatus.GameAsset
                    $launcherAsset = $releaseStatus.LauncherAsset
                    $webAsset = $releaseStatus.WebAsset
                    $releaseReady = $true
                    break
                }
            } catch {
                # Release creation can trail the successful job by a moment.
            }
            Start-Sleep -Seconds 2
        }
        if (-not $releaseReady) {
            $detail = if ($workflowConclusion) {
                "The workflow finished as '$workflowConclusion'."
            } else {
                'The workflow did not report a conclusion.'
            }
            if ($workflowUrl) { $detail += "`n$workflowUrl" }
            throw ("GitHub did not publish both launcher-facing release files for $tag.`n" + $detail)
        }

        Set-Stage 'Published' 100 'verify'
        $totalMb = ($gameAsset.size + $launcherAsset.size) / 1MB
        $script:BarDetail = ('{0:N0} MB packaged' -f $totalMb)
        $bar.Invalidate()
        Write-Log ("verified game archive ({0:N1} MB) and launcher ({1:N1} MB) - {2:N0} MB total" -f `
            ($gameAsset.size / 1MB), ($launcherAsset.size / 1MB), $totalMb)
        if ($releaseStatus.AuxiliaryWarning) {
            $script:BarDetail = 'desktop update live; part of the build needs attention'
            $bar.Invalidate()
            Write-Log ''
            Write-Log "WARNING: the launcher update is published, but the workflow finished as '$workflowConclusion'."
            Write-Log 'Something else in the build needs attention; this does not block installed launchers.'
            if ($workflowUrl) { Write-Log $workflowUrl }
        }
        if ($script:LastSizes) {
            # The delta is the useful number: a package that suddenly grows by
            # fifty megabytes usually means something was committed that should
            # not have been.
            $delta = $totalMb - (($script:LastSizes.Game + $script:LastSizes.Launcher) / 1MB)
            Write-Log ("{0:+#,0.0;-#,0.0;0} MB against {1}" -f $delta, $script:LastSizes.Tag)
        }

        # The web build is built by the same workflow on the same tag, but
        # nothing downloads it on its own - it is a zip a person uploads. Said
        # out loud every time, because the alternative is remembering.
        Write-Log ''
        if ($webAsset) {
            Write-Log ("web build ready: BeastRoad-web.zip ({0:N1} MB)" -f ($webAsset.size / 1MB))
            Write-Log 'Upload it to Netlify to update the browser version - drag the zip'
            Write-Log 'straight onto the site, its index.html is already at the root:'
            Write-Log "https://github.com/$Owner/$Repo/releases/download/$tag/BeastRoad-web.zip"
        } else {
            Write-Log 'NOTE: this release carries no BeastRoad-web.zip, so the browser'
            Write-Log 'version is unchanged. Installed launchers are unaffected.'
        }

        Write-Log ''
        Write-Log "Players will be offered $tag the next time they open the launcher."
        Write-Log 'Game-only updates need no new launcher download.'
        Write-Log 'If this release changes launcher code, replace the launcher once using the link below.'
        $lblLink.Text = "https://github.com/$Owner/$Repo/releases/latest"
        $lblLink.Visible = $true
        $bar.ForeColor = $cGreen
    }
    catch {
        $script:BarFailed = $true
        Set-Stage 'Failed' $script:BarValue
        Write-Log ''
        Write-Log "ERROR: $_"
    }
    finally {
        $btn.Enabled = $true
        $suggested, $latestTag = Suggest-Version
        # A tag can exist even when its Actions build failed, so never label a
        # local tag as "published". The success path above verifies publication.
        $lblCurrent.Text = "Latest local tag: $latestTag"
    }
})

$lblLink.Add_LinkClicked({ Start-Process $lblLink.Text })


# ============================================================================
# TUNING TAB
# ============================================================================
#
# Every dev-side value in one window: gameplay constants from Balance.gd, the
# per-sound mix from Sfx.gd, and the handful of engine settings that belong in
# the same conversation.
#
# Values are read on open and written only when Save is pressed, so a mistyped
# number can be abandoned by closing the app. Writes are surgical - see
# tuning.ps1 - so nothing this parser does not understand is ever reformatted.

. (Join-Path $PSScriptRoot 'tuning.ps1')

$script:Editors = @{}
$script:Dirty = $false

function script:Load-TuningEntries {
    $entries = @()
    $entries += Read-BalanceEntries
    foreach ($src in $script:ExtraSources) {
        $entries += Read-BalanceEntries -Path $src.Path -ForcedSection $src.Section
    }
    $entries += Read-SfxEntries
    $entries += Read-ResourceEntries
    return $entries
}

function New-TuningTab {
    param($TabControl)

    $page = New-Object System.Windows.Forms.TabPage
    $page.Text = 'Tuning'
    $page.BackColor = $cVoid
    $TabControl.TabPages.Add($page)

    # --- filter ---
    $lblFind = New-Object System.Windows.Forms.Label
    $lblFind.Text = 'Filter'
    $lblFind.Location = New-Object System.Drawing.Point(14, 14)
    $lblFind.Size = New-Object System.Drawing.Size(50, 24)
    $lblFind.ForeColor = $cBone
    $page.Controls.Add($lblFind)

    $script:txtFind = New-Object System.Windows.Forms.TextBox
    $script:txtFind.Location = New-Object System.Drawing.Point(64, 11)
    $script:txtFind.Size = New-Object System.Drawing.Size(300, 26)
    $script:txtFind.BackColor = $cSlate
    $script:txtFind.ForeColor = $cBone
    $script:txtFind.BorderStyle = 'FixedSingle'
    $page.Controls.Add($script:txtFind)

    $script:lblCount = New-Object System.Windows.Forms.Label
    $script:lblCount.Location = New-Object System.Drawing.Point(376, 14)
    $script:lblCount.Size = New-Object System.Drawing.Size(340, 24)
    $script:lblCount.ForeColor = [System.Drawing.Color]::FromArgb(150, 160, 160)
    $page.Controls.Add($script:lblCount)

    # --- sections ---
    $script:tree = New-Object System.Windows.Forms.TreeView
    $script:tree.Location = New-Object System.Drawing.Point(14, 48)
    $script:tree.Size = New-Object System.Drawing.Size(230, 470)
    $script:tree.BackColor = $cSlate
    $script:tree.ForeColor = $cBone
    $script:tree.BorderStyle = 'FixedSingle'
    $script:tree.HideSelection = $false
    $page.Controls.Add($script:tree)

    # --- values ---
    $script:scroll = New-Object System.Windows.Forms.Panel
    $script:scroll.Location = New-Object System.Drawing.Point(254, 48)
    $script:scroll.Size = New-Object System.Drawing.Size(462, 470)
    $script:scroll.AutoScroll = $true
    $script:scroll.BackColor = [System.Drawing.Color]::FromArgb(8, 14, 16)
    $script:scroll.BorderStyle = 'FixedSingle'
    $page.Controls.Add($script:scroll)

    $lblHelp = New-Object System.Windows.Forms.Label
    $lblHelp.Location = New-Object System.Drawing.Point(14, 524)
    $lblHelp.Size = New-Object System.Drawing.Size(702, 40)
    $lblHelp.ForeColor = [System.Drawing.Color]::FromArgb(150, 165, 160)
    $lblHelp.Text = 'Changes are only written when you press Save. Publish afterwards to ship them.'
    $page.Controls.Add($lblHelp)

    $btnSave = New-Object System.Windows.Forms.Button
    $btnSave.Text = 'SAVE CHANGES'
    $btnSave.Location = New-Object System.Drawing.Point(14, 566)
    $btnSave.Size = New-Object System.Drawing.Size(200, 40)
    $btnSave.BackColor = $cRust
    $btnSave.ForeColor = $cBone
    $btnSave.FlatStyle = 'Flat'
    $btnSave.FlatAppearance.BorderColor = $cAmber
    $page.Controls.Add($btnSave)

    $btnReload = New-Object System.Windows.Forms.Button
    $btnReload.Text = 'Reload from disk'
    $btnReload.Location = New-Object System.Drawing.Point(226, 566)
    $btnReload.Size = New-Object System.Drawing.Size(160, 40)
    $btnReload.BackColor = $cSlate
    $btnReload.ForeColor = $cBone
    $btnReload.FlatStyle = 'Flat'
    $btnReload.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(70, 84, 90)
    $page.Controls.Add($btnReload)

    $script:lblSaved = New-Object System.Windows.Forms.Label
    $script:lblSaved.Location = New-Object System.Drawing.Point(400, 576)
    $script:lblSaved.Size = New-Object System.Drawing.Size(316, 24)
    $script:lblSaved.ForeColor = $cGreen
    $page.Controls.Add($script:lblSaved)

    # --- data ---
    $script:AllEntries = Load-TuningEntries

    function script:Rebuild-Tree {
        $script:tree.Nodes.Clear()
        $sections = $script:AllEntries | ForEach-Object { $_.Section } | Select-Object -Unique
        foreach ($s in $sections) {
            $count = @($script:AllEntries | Where-Object { $_.Section -eq $s }).Count
            $node = $script:tree.Nodes.Add(("{0}  ({1})" -f $s, $count))
            $node.Tag = $s
        }
        $projectNode = $script:tree.Nodes.Add(('Engine settings  ({0})' -f $script:ProjectSettings.Count))
        $projectNode.Tag = '__project__'
        $script:lblCount.Text = ("{0} values across {1} groups" -f $script:AllEntries.Count, $sections.Count)
        if ($script:tree.Nodes.Count -gt 0) { $script:tree.SelectedNode = $script:tree.Nodes[0] }
    }

    function script:Add-Row {
        param($Parent, [int]$Y, [string]$Label, [string]$Value, [string]$Help,
              [string]$Key, [string]$Kind, [bool]$ReadOnly, $Choices,
              [string]$SourcePath = '', [string]$SourceField = '')

        $name = New-Object System.Windows.Forms.Label
        $name.Text = $Label
        $name.Location = New-Object System.Drawing.Point(8, ($Y + 4))
        $name.Size = New-Object System.Drawing.Size(250, 22)
        $name.ForeColor = if ($ReadOnly) { [System.Drawing.Color]::FromArgb(110, 120, 120) } else { $cAmber }
        $name.Font = New-Object System.Drawing.Font('Consolas', 9.5)
        $Parent.Controls.Add($name)

        if ($Kind -eq 'bool') {
            $box = New-Object System.Windows.Forms.ComboBox
            $box.DropDownStyle = 'DropDownList'
            [void]$box.Items.AddRange(@('true', 'false'))
            $box.SelectedItem = if ($Value -eq 'true') { 'true' } else { 'false' }
        } elseif ($Kind -eq 'choice') {
            $box = New-Object System.Windows.Forms.ComboBox
            $box.DropDownStyle = 'DropDownList'
            [void]$box.Items.AddRange($Choices)
            foreach ($c in $Choices) { if ($c.StartsWith($Value)) { $box.SelectedItem = $c } }
            if ($null -eq $box.SelectedItem -and $box.Items.Count -gt 0) { $box.SelectedIndex = 0 }
        } else {
            $box = New-Object System.Windows.Forms.TextBox
            $box.Text = $Value
            $box.BorderStyle = 'FixedSingle'
        }
        $box.Location = New-Object System.Drawing.Point(262, $Y)
        $box.Size = New-Object System.Drawing.Size(160, 26)
        $box.BackColor = if ($ReadOnly) { [System.Drawing.Color]::FromArgb(18, 24, 26) } else { $cSlate }
        $box.ForeColor = $cBone
        $box.Font = New-Object System.Drawing.Font('Consolas', 10)
        $box.Enabled = -not $ReadOnly
        $box.Tag = @{ Key = $Key; Kind = $Kind; Original = $Value; Path = $SourcePath; Field = $SourceField }
        $Parent.Controls.Add($box)
        $script:Editors[$Key] = $box

        if ($Help) {
            $tip = New-Object System.Windows.Forms.ToolTip
            $tip.AutoPopDelay = 20000
            $tip.SetToolTip($box, $Help)
            $tip.SetToolTip($name, $Help)
        }
        return ($Y + 32)
    }

    function script:Show-Section {
        param([string]$Section)
        $script:scroll.Controls.Clear()
        $script:Editors = @{}
        $y = 8
        $filter = $script:txtFind.Text.Trim()

        if ($Section -eq '__project__') {
            foreach ($ps in $script:ProjectSettings) {
                $current = Read-ProjectValue -Key $ps.Key
                $y = Add-Row -Parent $script:scroll -Y $y -Label $ps.Label -Value $current `
                    -Help $ps.Key -Key ("proj::" + $ps.Key) -Kind $ps.Kind -ReadOnly $false -Choices $ps.Choices
            }
            return
        }

        $rows = $script:AllEntries | Where-Object { $_.Section -eq $Section }
        if ($filter) { $rows = $rows | Where-Object { $_.Name -like "*$filter*" } }

        foreach ($e in $rows) {
            if ($e.Source -eq 'sfx') {
                $header = New-Object System.Windows.Forms.Label
                $header.Text = $e.Name
                $header.Location = New-Object System.Drawing.Point(8, ($y + 4))
                $header.Size = New-Object System.Drawing.Size(430, 20)
                $header.ForeColor = $cBone
                $header.Font = New-Object System.Drawing.Font('Consolas', 9.5, [System.Drawing.FontStyle]::Bold)
                $script:scroll.Controls.Add($header)
                $y += 26
                foreach ($key in 'db', 'pitch', 'limit', 'gap') {
                    if (-not $e.Fields.ContainsKey($key)) { continue }
                    $label = switch ($key) {
                        'db' { '    level (dB)' }
                        'pitch' { '    pitch drift' }
                        'limit' { '    max at once' }
                        'gap' { '    min gap (s)' }
                    }
                    $y = Add-Row -Parent $script:scroll -Y $y -Label $label -Value $e.Fields[$key] `
                        -Help "$($e.Name) $key" -Key ("sfx::" + $e.Name + "/" + $key) `
                        -Kind 'float' -ReadOnly $false -Choices @()
                }
                $y += 6
            } elseif ($e.Source -eq 'resource') {
                $resourceKey = 'res::' + $e.Relative + '::' + $e.Field
                $y = Add-Row -Parent $script:scroll -Y $y -Label $e.Name -Value $e.Raw `
                    -Help $e.Help -Key $resourceKey -Kind $e.Kind -ReadOnly $false `
                    -Choices @() -SourcePath $e.Path -SourceField $e.Field
            } else {
                $y = Add-Row -Parent $script:scroll -Y $y -Label $e.Name -Value $e.Raw `
                    -Help $e.Help -Key ("bal::" + $e.Name) -Kind $e.Kind `
                    -ReadOnly $e.ReadOnly -Choices @() -SourcePath $e.Path
            }
        }
        if ($rows.Count -eq 0) {
            $none = New-Object System.Windows.Forms.Label
            $none.Text = 'Nothing matches the filter.'
            $none.Location = New-Object System.Drawing.Point(10, 10)
            $none.Size = New-Object System.Drawing.Size(400, 24)
            $none.ForeColor = [System.Drawing.Color]::FromArgb(140, 150, 150)
            $script:scroll.Controls.Add($none)
        }
    }

    $script:tree.Add_AfterSelect({
        if ($null -ne $script:tree.SelectedNode) { Show-Section -Section ([string]$script:tree.SelectedNode.Tag) }
    })
    $script:txtFind.Add_TextChanged({
        if ($null -ne $script:tree.SelectedNode) { Show-Section -Section ([string]$script:tree.SelectedNode.Tag) }
    })

    $btnReload.Add_Click({
        $script:AllEntries = Load-TuningEntries
        Rebuild-Tree
        $script:lblSaved.Text = 'Reloaded from disk.'
    })

    $btnSave.Add_Click({
        $balance = @{}
        $byPath = @{}
        $resourcesByPath = @{}
        $sfx = @{}
        $project = @{}
        $bad = New-Object System.Collections.ArrayList

        foreach ($key in $script:Editors.Keys) {
            $box = $script:Editors[$key]
            if (-not $box.Enabled) { continue }
            $meta = $box.Tag
            $text = if ($box -is [System.Windows.Forms.ComboBox]) { [string]$box.SelectedItem } else { $box.Text.Trim() }
            if ($text -eq $meta.Original) { continue }

            # Validate before writing anything, so a single bad field cannot leave
            # half the values applied.
            switch ($meta.Kind) {
                'int'   { if ($text -notmatch '^-?[0-9]+$') { [void]$bad.Add("$key must be a whole number") } }
                'float' { if ($text -notmatch '^-?[0-9]*\.?[0-9]+$') { [void]$bad.Add("$key must be a number") } }
                'bool'  { if ($text -notin @('true','false')) { [void]$bad.Add("$key must be true or false") } }
                'array' { if ($text -notmatch '^Array(?:\[[A-Za-z0-9_]+\])?\(\[.*\]\)$') { [void]$bad.Add("$key must be a Godot Array(...) value") } }
                'vector' { if ($text -notmatch '^Vector[234]\(.+\)$') { [void]$bad.Add("$key must be a Vector2/3/4(...) value") } }
                'color' { if ($text -notmatch '^Color\(.+\)$') { [void]$bad.Add("$key must be a Color(...) value") } }
            }
            if ($key.StartsWith('bal::')) {
                $balance[$key.Substring(5)] = $text
                # Remembered per file, because a constant may now live in
                # Balance.gd, ui_metrics.gd or graphics.gd and each has to be
                # written back to the file it actually came from.
                $owner = if ($meta.Path) { $meta.Path } else { $script:BalancePath }
                if (-not $byPath.ContainsKey($owner)) { $byPath[$owner] = @{} }
                $byPath[$owner][$key.Substring(5)] = $text
            }
            elseif ($key.StartsWith('sfx::')) { $sfx[$key.Substring(5)] = $text }
            elseif ($key.StartsWith('proj::')) { $project[$key.Substring(6)] = ($text -split ' ')[0] }
            elseif ($key.StartsWith('res::')) {
                if (-not $resourcesByPath.ContainsKey($meta.Path)) { $resourcesByPath[$meta.Path] = @{} }
                $resourcesByPath[$meta.Path][$meta.Field] = $text
            }
        }

        if ($bad.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(($bad -join "`r`n"), 'Fix these first') | Out-Null
            return
        }
        if ($balance.Count + $sfx.Count + $project.Count + $resourcesByPath.Count -eq 0) {
            $script:lblSaved.Text = 'Nothing changed.'
            return
        }

        # Grouped by the file each value came from, so a padding change writes to
        # ui_metrics.gd and a balance change writes to Balance.gd.
        $n1 = 0
        foreach ($path in ($byPath.Keys)) {
            $n1 += Write-BalanceValues -Changes $byPath[$path] -Path $path
        }
        $n2 = Write-SfxValues -Changes $sfx
        $n3 = 0
        foreach ($path in $resourcesByPath.Keys) {
            $n3 += Write-ResourceValues -Changes $resourcesByPath[$path] -Path $path
        }
        foreach ($k in $project.Keys) { Write-ProjectValue -Key $k -Value $project[$k] }

        $script:AllEntries = Load-TuningEntries
        if ($null -ne $script:tree.SelectedNode) { Show-Section -Section ([string]$script:tree.SelectedNode.Tag) }
        $script:lblSaved.Text = ("Saved: {0} constants, {1} sounds, {2} content values, {3} settings." -f $n1, $n2, $n3, $project.Count)
    })

    Rebuild-Tree
    Show-Section -Section ([string]$script:tree.Nodes[0].Tag)
}

New-TuningTab -TabControl $tabs

[void]$form.ShowDialog()
