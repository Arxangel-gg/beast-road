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
    $l.Size = New-Object System.Drawing.Size($w, 24)
    $l.Font = New-Object System.Drawing.Font('Segoe UI', $size)
    $l.ForeColor = $color
    $pagePublish.Controls.Add($l); return $l
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
$bar                  = New-Object System.Windows.Forms.ProgressBar
$bar.Location         = New-Object System.Drawing.Point(26, 390)
$bar.Size             = New-Object System.Drawing.Size(690, 18)
$bar.Style            = 'Continuous'
$bar.Maximum          = 100
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
    $script:AllEntries = @()
    $script:AllEntries += Read-BalanceEntries
    $script:AllEntries += Read-SfxEntries

    function script:Rebuild-Tree {
        $script:tree.Nodes.Clear()
        $sections = $script:AllEntries | ForEach-Object { $_.Section } | Select-Object -Unique
        foreach ($s in $sections) {
            $count = @($script:AllEntries | Where-Object { $_.Section -eq $s }).Count
            $node = $script:tree.Nodes.Add(("{0}  ({1})" -f $s, $count))
            $node.Tag = $s
        }
        $projectNode = $script:tree.Nodes.Add('Engine settings  (4)')
        $projectNode.Tag = '__project__'
        $script:lblCount.Text = ("{0} values across {1} groups" -f $script:AllEntries.Count, $sections.Count)
        if ($script:tree.Nodes.Count -gt 0) { $script:tree.SelectedNode = $script:tree.Nodes[0] }
    }

    function script:Add-Row {
        param($Parent, [int]$Y, [string]$Label, [string]$Value, [string]$Help,
              [string]$Key, [string]$Kind, [bool]$ReadOnly, $Choices)

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
        $box.Tag = @{ Key = $Key; Kind = $Kind; Original = $Value }
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
            } else {
                $y = Add-Row -Parent $script:scroll -Y $y -Label $e.Name -Value $e.Raw `
                    -Help $e.Help -Key ("bal::" + $e.Name) -Kind $e.Kind `
                    -ReadOnly $e.ReadOnly -Choices @()
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
        $script:AllEntries = @()
        $script:AllEntries += Read-BalanceEntries
        $script:AllEntries += Read-SfxEntries
        Rebuild-Tree
        $script:lblSaved.Text = 'Reloaded from disk.'
    })

    $btnSave.Add_Click({
        $balance = @{}
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
            }
            if ($key.StartsWith('bal::')) { $balance[$key.Substring(5)] = $text }
            elseif ($key.StartsWith('sfx::')) { $sfx[$key.Substring(5)] = $text }
            elseif ($key.StartsWith('proj::')) { $project[$key.Substring(6)] = ($text -split ' ')[0] }
        }

        if ($bad.Count -gt 0) {
            [System.Windows.Forms.MessageBox]::Show(($bad -join "`r`n"), 'Fix these first') | Out-Null
            return
        }
        if ($balance.Count + $sfx.Count + $project.Count -eq 0) {
            $script:lblSaved.Text = 'Nothing changed.'
            return
        }

        $n1 = Write-BalanceValues -Changes $balance
        $n2 = Write-SfxValues -Changes $sfx
        foreach ($k in $project.Keys) { Write-ProjectValue -Key $k -Value $project[$k] }

        $script:AllEntries = @()
        $script:AllEntries += Read-BalanceEntries
        $script:AllEntries += Read-SfxEntries
        if ($null -ne $script:tree.SelectedNode) { Show-Section -Section ([string]$script:tree.SelectedNode.Tag) }
        $script:lblSaved.Text = ("Saved: {0} balance, {1} sounds, {2} settings." -f $n1, $n2, $project.Count)
    })

    Rebuild-Tree
    Show-Section -Section ([string]$script:tree.Nodes[0].Tag)
}

New-TuningTab -TabControl $tabs

[void]$form.ShowDialog()
