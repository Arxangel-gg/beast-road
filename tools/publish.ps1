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

# --- palette, matched to the game -------------------------------------------
$cVoid   = [System.Drawing.Color]::FromArgb(11, 20, 22)
$cSlate  = [System.Drawing.Color]::FromArgb(30, 46, 51)
$cAmber  = [System.Drawing.Color]::FromArgb(232, 163, 61)
$cBone   = [System.Drawing.Color]::FromArgb(217, 205, 184)
$cRust   = [System.Drawing.Color]::FromArgb(140, 58, 43)
$cGreen  = [System.Drawing.Color]::FromArgb(122, 168, 108)

$form                 = New-Object System.Windows.Forms.Form
$form.Text            = 'Beast Road - Update Manager'
$form.Size            = New-Object System.Drawing.Size(760, 660)
$form.StartPosition   = 'CenterScreen'
$form.BackColor       = $cVoid
$form.ForeColor       = $cBone
$form.Font            = New-Object System.Drawing.Font('Segoe UI', 10)

function New-Label($text, $x, $y, $w, $size, $color) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.Size = New-Object System.Drawing.Size($w, 24)
    $l.Font = New-Object System.Drawing.Font('Segoe UI', $size)
    $l.ForeColor = $color
    $form.Controls.Add($l); return $l
}

New-Label 'BEAST ROAD' 24 18 400 20 $cAmber | Out-Null
New-Label 'Publish an update to every installed launcher' 26 56 520 10 $cBone | Out-Null

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
$form.Controls.Add($txtVersion)

# --- notes -------------------------------------------------------------------
New-Label 'What changed (shown on the release page)' 26 196 500 10 $cBone | Out-Null
$txtNotes             = New-Object System.Windows.Forms.TextBox
$txtNotes.Location    = New-Object System.Drawing.Point(26, 222)
$txtNotes.Size        = New-Object System.Drawing.Size(690, 90)
$txtNotes.Multiline   = $true
$txtNotes.BackColor   = $cSlate
$txtNotes.ForeColor   = $cBone
$txtNotes.BorderStyle = 'FixedSingle'
$form.Controls.Add($txtNotes)

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
$form.Controls.Add($btn)

$lblStage = New-Label '' 286 340 430 10 $cAmber

# --- progress ----------------------------------------------------------------
$bar                  = New-Object System.Windows.Forms.ProgressBar
$bar.Location         = New-Object System.Drawing.Point(26, 390)
$bar.Size             = New-Object System.Drawing.Size(690, 18)
$bar.Style            = 'Continuous'
$bar.Maximum          = 100
$form.Controls.Add($bar)

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
$form.Controls.Add($log)

$lblLink              = New-Object System.Windows.Forms.LinkLabel
$lblLink.Location     = New-Object System.Drawing.Point(26, 598)
$lblLink.Size         = New-Object System.Drawing.Size(690, 24)
$lblLink.LinkColor    = $cAmber
$lblLink.ActiveLinkColor = $cBone
$lblLink.Visible      = $false
$form.Controls.Add($lblLink)

function Write-Log($msg) {
    $log.AppendText(("[{0}] {1}`r`n" -f (Get-Date -Format 'HH:mm:ss'), $msg))
    $log.SelectionStart = $log.TextLength
    $log.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}
function Set-Stage($text, $pct) {
    $lblStage.Text = $text
    $bar.Value = [Math]::Min([Math]::Max($pct, 0), 100)
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
$dirty = (Invoke-Git @('status', '--porcelain')).Text.Trim()
$changeCount = if ($dirty) { @($dirty -split "`n").Count } else { 0 }
$lblCurrent.Text = "Latest published: $latestTag     Uncommitted changes: $changeCount"

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
        Set-Stage 'Checking the repository...' 5
        $remote = (Invoke-Git @('remote', 'get-url', 'origin'))
        if ($remote.Code -ne 0) { throw "No 'origin' remote. Publish the repo in GitHub Desktop first." }
        Write-Log "remote: $($remote.Text.Trim())"

        $exists = Invoke-Git @('tag', '--list', $tag)
        if ($exists.Text.Trim() -eq $tag) { throw "$tag already exists. Pick a higher version." }

        # Anything outstanding gets committed, so the build matches what is on
        # screen rather than the last time someone remembered to commit.
        $pending = (Invoke-Git @('status', '--porcelain')).Text.Trim()
        if ($pending) {
            Set-Stage 'Committing your changes...' 15
            $n = @($pending -split "`n").Count
            Write-Log "committing $n changed file(s)"
            Invoke-Git @('add', '-A') | Out-Null
            $msg = $txtNotes.Text.Trim()
            if (-not $msg) { $msg = "Update $tag" }
            $c = Invoke-Git @('commit', '-m', $msg)
            if ($c.Code -ne 0) { throw "commit failed:`n$($c.Text)" }
            Write-Log 'committed'
        } else {
            Write-Log 'nothing to commit, tree is clean'
        }

        Set-Stage 'Pushing to GitHub...' 30
        $branch = (Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')).Text.Trim()
        $p = Invoke-Git @('push', 'origin', $branch)
        if ($p.Code -ne 0) { throw "push failed:`n$($p.Text)" }
        Write-Log "pushed $branch"

        Set-Stage 'Tagging the release...' 40
        $notes = $txtNotes.Text.Trim()
        if (-not $notes) { $notes = "Beast Road $tag" }
        $t = Invoke-Git @('tag', '-a', $tag, '-m', $notes)
        if ($t.Code -ne 0) { throw "tag failed:`n$($t.Text)" }
        $tp = Invoke-Git @('push', 'origin', $tag)
        if ($tp.Code -ne 0) { throw "tag push failed:`n$($tp.Text)" }
        Write-Log "pushed $tag - GitHub is building now"

        # --- watch the build ---
        Set-Stage 'Building on GitHub (this takes a few minutes)...' 50
        $api = "https://api.github.com/repos/$Owner/$Repo/actions/runs?per_page=1"
        $headers = @{ 'User-Agent' = 'BeastRoadPublisher' }
        $done = $false
        for ($i = 0; $i -lt 90; $i++) {
            Start-Sleep -Seconds 10
            try {
                $runs = Invoke-RestMethod -Uri $api -Headers $headers -TimeoutSec 20
                $run = $runs.workflow_runs[0]
            } catch {
                Write-Log 'waiting for GitHub...'
                continue
            }
            if (-not $run) { continue }

            if ($run.status -eq 'completed') {
                if ($run.conclusion -eq 'success') {
                    Set-Stage 'Published.' 100
                    Write-Log 'build succeeded'
                    $done = $true
                } else {
                    throw "build finished as '$($run.conclusion)'. Open the run and read the failing step:`n$($run.html_url)"
                }
                break
            }
            Set-Stage "Building on GitHub... ($($run.status))" ([Math]::Min(50 + $i * 3, 95))
        }
        if (-not $done) { throw 'timed out waiting for the build. Check the Actions tab.' }

        Write-Log ''
        Write-Log "Players will be offered $tag the next time they open the launcher."
        Write-Log 'They do NOT need to download the launcher again.'
        $lblLink.Text = "https://github.com/$Owner/$Repo/releases/latest"
        $lblLink.Visible = $true
        $bar.ForeColor = $cGreen
    }
    catch {
        Set-Stage 'Failed.' 0
        Write-Log ''
        Write-Log "ERROR: $_"
    }
    finally {
        $btn.Enabled = $true
        $suggested, $latestTag = Suggest-Version
        $lblCurrent.Text = "Latest published: $latestTag"
    }
})

$lblLink.Add_LinkClicked({ Start-Process $lblLink.Text })

[void]$form.ShowDialog()
