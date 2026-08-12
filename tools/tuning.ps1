# Beast Road - Tuning library
#
# Reads and writes the game's dev-side values. Kept separate from publish.ps1 so
# the parsing can be reasoned about (and fixed) without touching the publisher.
#
# Two sources, because the game keeps its numbers in two shapes:
#
#   Balance.gd   `const NAME: type = value`, grouped by `# ===` banners, each
#                documented by the `##` lines above it.
#   Sfx.gd       the MIX dictionary: one row per sound, four fields each.
#
# Writes are surgical. Only the value on a matched line is replaced, so comments,
# ordering, grouping and anything this parser does not understand survive
# untouched. That property matters more than completeness: a tuning tool that
# reformats a source file is a tuning tool nobody dares run twice.

$script:BalancePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\scripts\Balance.gd'
$script:SfxPath     = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\autoload\Sfx.gd'
$script:ProjectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\project.godot'

function Get-ValueKind {
    param([string]$Type, [string]$Raw)
    if ($Type -eq 'bool') { return 'bool' }
    if ($Type -eq 'int') { return 'int' }
    if ($Type -eq 'float') { return 'float' }
    if ($Type -eq 'Color') { return 'color' }
    if ($Type -like 'Array*') { return 'array' }
    if ($Type -eq 'Vector2') { return 'vector2' }
    if ($Raw -match '^-?[0-9]+$') { return 'int' }
    if ($Raw -match '^-?[0-9]*\.[0-9]+$') { return 'float' }
    return 'text'
}


# Set-Content -Encoding UTF8 writes a BOM on PowerShell 5.1 and uses CRLF. Both
# are wrong here: the .gd files are BOM-less with LF endings, and a tuning tool
# that rewrites the encoding of every file it touches produces a diff full of
# noise and, in Godot's case, a leading BOM in a script.
function Save-SourceLines {
    param([string]$Path, [string[]]$Lines)
    $text = ($Lines -join "`n") + "`n"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $text, $utf8NoBom)
}

# --- Balance.gd -------------------------------------------------------------

function Read-BalanceEntries {
    if (-not (Test-Path $script:BalancePath)) { return @() }
    $lines = Get-Content -LiteralPath $script:BalancePath -Encoding UTF8
    $entries = New-Object System.Collections.ArrayList
    $section = 'General'
    $doc = New-Object System.Collections.ArrayList

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # `# ==== ` banner, then the next comment line is the section name.
        if ($line -match '^#\s*={10,}') {
            if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^#\s*(.+?)\s*$') {
                $candidate = $Matches[1].Trim()
                if ($candidate -notmatch '^={5,}$' -and $candidate.Length -gt 2) {
                    # Drop the "- GDD SS3.1" suffix: useful in source, noise in a
                    # list of tuning groups.
                    $section = ($candidate -split '\s+[-\u2014]\s+')[0].Trim()
                }
            }
            $doc.Clear()
            continue
        }
        # `# ---- ` sub-banner names a group too, but only if it looks like a title.
        if ($line -match '^#\s*-{10,}') { $doc.Clear(); continue }

        if ($line -match '^##\s?(.*)$') { [void]$doc.Add($Matches[1].Trim()); continue }
        if ($line -match '^#\s*(.*)$') { continue }

        if ($line -match '^const\s+([A-Z0-9_]+)\s*:\s*([A-Za-z0-9\[\]]+)\s*=\s*(.+?)\s*$') {
            # Captured into locals immediately: $Matches is global, and any later
            # -match in this iteration would overwrite it before it is read.
            $constName = $Matches[1]
            $constType = $Matches[2]
            $raw = $Matches[3]
            # Skip aliases like `const A: float = B` - editing them is meaningless.
            $isAlias = $raw -match '^[A-Z][A-Z0-9_]*$'
            [void]$entries.Add([pscustomobject]@{
                Source  = 'balance'
                Section = $section
                Name    = $constName
                Type    = $constType
                Raw     = $raw
                Kind    = (Get-ValueKind -Type $constType -Raw $raw)
                Help    = ($doc -join ' ')
                Line    = $i
                ReadOnly = $isAlias
            })
            $doc.Clear()
            continue
        }
        if ($line.Trim().Length -gt 0) { $doc.Clear() }
    }
    return $entries
}

function Write-BalanceValues {
    param([hashtable]$Changes)
    if ($Changes.Count -eq 0) { return 0 }
    $lines = Get-Content -LiteralPath $script:BalancePath -Encoding UTF8
    $written = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^const\s+([A-Z0-9_]+)\s*:\s*([A-Za-z0-9\[\]]+)\s*=\s*(.+?)\s*$') { continue }
        $name = $Matches[1]
        if (-not $Changes.ContainsKey($name)) { continue }
        $type = $Matches[2]
        # Rebuild only the value; the const, name, type and any trailing comment
        # position are preserved by construction.
        $lines[$i] = "const {0}: {1} = {2}" -f $name, $type, $Changes[$name]
        $written++
    }
    Save-SourceLines -Path $script:BalancePath -Lines $lines
    return $written
}

# --- Sfx.gd MIX ------------------------------------------------------------

function Read-SfxEntries {
    if (-not (Test-Path $script:SfxPath)) { return @() }
    $lines = Get-Content -LiteralPath $script:SfxPath -Encoding UTF8
    $entries = New-Object System.Collections.ArrayList
    foreach ($index in 0..($lines.Count - 1)) {
        $line = $lines[$index]
        if ($line -notmatch '^\s*"(sfx_[a-z0-9_]+)":\s*\{(.+)\},?\s*$') { continue }
        # Captured before the field loop below starts overwriting $Matches.
        $id = $Matches[1]
        $body = $Matches[2]
        $fields = @{}
        foreach ($key in 'db', 'pitch', 'limit', 'gap') {
            if ($body -match ('"{0}":\s*(-?[0-9.]+)' -f $key)) { $fields[$key] = $Matches[1] }
        }
        [void]$entries.Add([pscustomobject]@{
            Source  = 'sfx'
            Section = 'Sound mix'
            Name    = $id
            Fields  = $fields
            Line    = $index
        })
    }
    return $entries
}

function Write-SfxValues {
    param([hashtable]$Changes)
    if ($Changes.Count -eq 0) { return 0 }
    $lines = Get-Content -LiteralPath $script:SfxPath -Encoding UTF8
    $written = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^(\s*)"(sfx_[a-z0-9_]+)":\s*\{(.+?)\}(,?)\s*$') { continue }
        $indent = $Matches[1]; $id = $Matches[2]; $body = $Matches[3]; $comma = $Matches[4]
        $touched = $false
        foreach ($key in 'db', 'pitch', 'limit', 'gap') {
            $composite = "$id/$key"
            if (-not $Changes.ContainsKey($composite)) { continue }
            $value = $Changes[$composite]
            $pattern = ('"{0}":\s*-?[0-9.]+' -f $key)
            if ($body -match $pattern) {
                $body = [regex]::Replace($body, $pattern, ('"{0}": {1}' -f $key, $value))
                $touched = $true
            }
        }
        if ($touched) {
            $lines[$i] = "{0}`"{1}`": {{{2}}}{3}" -f $indent, $id, $body, $comma
            $written++
        }
    }
    Save-SourceLines -Path $script:SfxPath -Lines $lines
    return $written
}

# --- project.godot ---------------------------------------------------------
#
# A handful of engine settings belong in the same window as the gameplay values,
# because "make it fullscreen" and "make the view wider" are the same kind of
# request as "make the hero faster".

$script:ProjectSettings = @(
    [pscustomobject]@{ Key = 'display/window/size/mode'; Label = 'Window mode'; Kind = 'choice'
        Choices = @('0 = windowed', '2 = maximised', '3 = fullscreen', '4 = exclusive fullscreen') }
    [pscustomobject]@{ Key = 'display/window/size/viewport_width'; Label = 'Viewport width'; Kind = 'int'; Choices = @() }
    [pscustomobject]@{ Key = 'display/window/size/viewport_height'; Label = 'Viewport height'; Kind = 'int'; Choices = @() }
    [pscustomobject]@{ Key = 'display/window/vsync/vsync_mode'; Label = 'VSync (0 off, 1 on)'; Kind = 'int'; Choices = @() }
)

function Read-ProjectValue {
    param([string]$Key)
    if (-not (Test-Path $script:ProjectPath)) { return '' }
    $escaped = [regex]::Escape($Key)
    foreach ($line in Get-Content -LiteralPath $script:ProjectPath -Encoding UTF8) {
        if ($line -match ('^{0}\s*=\s*(.+?)\s*$' -f $escaped)) { return $Matches[1] }
    }
    return ''
}

function Write-ProjectValue {
    param([string]$Key, [string]$Value)
    $lines = @(Get-Content -LiteralPath $script:ProjectPath -Encoding UTF8)
    $escaped = [regex]::Escape($Key)
    $found = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^{0}\s*=' -f $escaped)) {
            $lines[$i] = "$Key=$Value"; $found = $true; break
        }
    }
    if (-not $found) {
        # New keys go in the section they belong to, creating it if absent.
        $section = '[' + $Key.Split('/')[0] + ']'
        $at = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i].Trim() -eq $section) { $at = $i; break } }
        if ($at -ge 0) {
            $lines = $lines[0..$at] + @("$Key=$Value") + $lines[($at + 1)..($lines.Count - 1)]
        } else {
            $lines += @('', $section, '', "$Key=$Value")
        }
    }
    Save-SourceLines -Path $script:ProjectPath -Lines $lines
}
