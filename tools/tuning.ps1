# Beast Road - Tuning library
#
# Reads and writes the game's dev-side values. Kept separate from publish.ps1 so
# the parsing can be reasoned about (and fixed) without touching the publisher.
#
# The game keeps its numbers in several shapes:
#
#   Balance.gd   `const NAME: type = value`, grouped by `# ===` banners, each
#                documented by the `##` lines above it.
#   Sfx.gd       the MIX dictionary: one row per sound, four fields each.
#   data/*.tres  exported numeric, boolean and compact collection properties.
#
# Writes are surgical. Only the value on a matched line is replaced, so comments,
# ordering, grouping and anything this parser does not understand survive
# untouched. That property matters more than completeness: a tuning tool that
# reformats a source file is a tuning tool nobody dares run twice.

$script:BalancePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\scripts\Balance.gd'
$script:SfxPath     = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\autoload\Sfx.gd'
$script:ProjectPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\project.godot'
$script:DataPath    = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\data'

# Balance.gd is no longer the only file holding tunable constants. These carry
# the same `const NAME: type = value` shape and are just as much dev-side values
# somebody wants to nudge - the UI padding especially, which gets argued about a
# pixel at a time and should not need a code edit to try.
#
# Deliberately not every file with constants in it: only ones whose values can
# change without also changing code that reasons about them.
$script:ExtraSources = @(
    @{ Path    = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\scripts\systems\ui_metrics.gd'
       Section = 'UI padding' }
    @{ Path    = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\scripts\systems\graphics.gd'
       Section = 'Graphics quality' }
    @{ Path    = Join-Path (Split-Path -Parent $PSScriptRoot) 'game\scripts\systems\parallax_band.gd'
       Section = 'Beast parallax shape' }
)

# Deliberately NOT added, and worth writing down so nobody adds them later
# thinking it was an oversight: weather_veil.gd, snow_cover.gd, cloud_shadows.gd
# and foliage.gd each hold their shader as `const SHADER_CODE: String = """..."""`.
# The const matcher would happily take that as a one-line text value and offer it
# for editing, and writing it back would replace an entire shader with a single
# line. A tuning tool that can destroy a shader is one nobody dares run.
#
# Everything genuinely tunable in those files already lives in Balance.gd, which
# is where it belongs anyway.

function Get-ValueKind {
    param([string]$Type, [string]$Raw)
    if ($Type -eq 'bool') { return 'bool' }
    if ($Type -eq 'int') { return 'int' }
    if ($Type -eq 'float') { return 'float' }
    if ($Type -eq 'Color') { return 'color' }
    if ($Type -like 'Array*') { return 'array' }
    if ($Type -eq 'Vector2') { return 'vector' }
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
    param([string]$Path = '', [string]$ForcedSection = '')
    if (-not $Path) { $Path = $script:BalancePath }
    if (-not (Test-Path $Path)) { return @() }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $entries = New-Object System.Collections.ArrayList
    $section = 'General'
    $doc = New-Object System.Collections.ArrayList

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # `# ==== ` banner, then the next comment line is the section name.
        if ($line -match '^#\s*={10,}') {
            if ($i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^#\s*(.+?)\s*$') {
                $candidate = $Matches[1].Trim()
                if ($candidate -notmatch '^={5,}$' -and $candidate.Length -gt 2 `
                        -and -not $ForcedSection) {
                    # Drop the "- GDD SS3.1" suffix: useful in source, noise in a
                    # list of tuning groups.
                    #
                    # Skipped entirely for the extra sources, which are given one
                    # section name by the caller - a banner inside them would
                    # otherwise rename the group half way down.
                    $section = ($candidate -split '\s+[-\u2014]\s+')[0].Trim()
                }
            }
            $doc.Clear()
            continue
        }
        # `# --- Loot ---` sub-banners are the human-facing groups used in
        # Balance.gd. They used to clear the documentation without changing the
        # section, which put touch UI values under the last distant `# ===`
        # banner (and battlefield gear under another unrelated group) in Update
        # Manager. Read the inline title so every new production control lands
        # where a tuner expects it.
        if ($line -match '^#\s*-{5,}\s*$') {
            $candidate = ''
            if ($i + 2 -lt $lines.Count -and $lines[$i + 1] `
                    -match '^#\s*([A-Za-z0-9].+?)\s*$') {
                $candidate = $Matches[1].Trim()
            }
            if ($candidate -and $lines[$i + 2] -match '^#\s*-{5,}\s*$' `
                    -and -not $ForcedSection) {
                $section = $candidate
            }
            $doc.Clear()
            continue
        }
        if ($line -match '^#\s*-{3,}\s+([A-Za-z0-9].*?)\s+-{3,}\s*$') {
            if (-not $ForcedSection) { $section = $Matches[1].Trim() }
            $doc.Clear()
            continue
        }
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
                Path    = $Path
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
    param([hashtable]$Changes, [string]$Path = '')
    if ($Changes.Count -eq 0) { return 0 }
    if (-not $Path) { $Path = $script:BalancePath }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
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
    Save-SourceLines -Path $Path -Lines $lines
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

# --- data resources --------------------------------------------------------

function Get-ResourceValueKind {
    param([string]$Raw)
    if ($Raw -in @('true', 'false')) { return 'bool' }
    if ($Raw -match '^-?[0-9]+$') { return 'int' }
    if ($Raw -match '^-?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:[eE][+-]?[0-9]+)?$') { return 'float' }
    if ($Raw -match '^Array(?:\[[A-Za-z0-9_]+\])?\(\[.*\]\)$') { return 'array' }
    if ($Raw -match '^Vector[234]\(.+\)$') { return 'vector' }
    if ($Raw -match '^Color\(.+\)$') { return 'color' }
    return ''
}

function Read-ResourceEntries {
    if (-not (Test-Path $script:DataPath)) { return @() }
    $entries = New-Object System.Collections.ArrayList
    $files = Get-ChildItem -LiteralPath $script:DataPath -Filter '*.tres' -File -Recurse | Sort-Object FullName
    foreach ($file in $files) {
        $relative = $file.FullName.Substring($script:DataPath.Length).TrimStart('\')
        $folder = Split-Path -Parent $relative
        if (-not $folder) { $folder = 'General' }
        $section = 'Content / ' + ($folder -replace '\\', ' / ')
        $resourceSection = $false
        $lines = Get-Content -LiteralPath $file.FullName -Encoding UTF8
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\[(.+)\]\s*$') {
                $resourceSection = $Matches[1] -eq 'resource'
                continue
            }
            if (-not $resourceSection -or $line -notmatch '^([a-z][a-z0-9_]*)\s*=\s*(.+?)\s*$') { continue }
            $field = $Matches[1]
            $raw = $Matches[2]
            if ($field -in @('script', 'id', 'display_name', 'description', 'summary')) { continue }
            $kind = Get-ResourceValueKind -Raw $raw
            if (-not $kind) { continue }
            [void]$entries.Add([pscustomobject]@{
                Source   = 'resource'
                Path     = $file.FullName
                Relative = $relative
                Section  = $section
                Name     = ('{0} / {1}' -f $file.BaseName, $field)
                Field    = $field
                Raw      = $raw
                Kind     = $kind
                Help     = ('{0}: {1}' -f $relative, $field)
                Line     = $i
                ReadOnly = $false
            })
        }
    }
    return $entries
}

function Write-ResourceValues {
    param([hashtable]$Changes, [string]$Path)
    if ($Changes.Count -eq 0 -or -not (Test-Path $Path)) { return 0 }
    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $resourceSection = $false
    $written = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\[(.+)\]\s*$') {
            $resourceSection = $Matches[1] -eq 'resource'
            continue
        }
        if (-not $resourceSection -or $lines[$i] -notmatch '^([a-z][a-z0-9_]*)\s*=\s*(.+?)\s*$') { continue }
        $field = $Matches[1]
        if (-not $Changes.ContainsKey($field)) { continue }
        $lines[$i] = ('{0} = {1}' -f $field, $Changes[$field])
        $written++
    }
    if ($written -gt 0) { Save-SourceLines -Path $Path -Lines $lines }
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
    $slash = $Key.IndexOf('/')
    if ($slash -lt 1) { return '' }
    $section = $Key.Substring(0, $slash)
    $relative = $Key.Substring($slash + 1)
    $escaped = [regex]::Escape($relative)
    $inside = $false
    foreach ($line in Get-Content -LiteralPath $script:ProjectPath -Encoding UTF8) {
        if ($line -match '^\[(.+)\]\s*$') {
            $inside = $Matches[1] -eq $section
            continue
        }
        if (-not $inside) { continue }
        if ($line -match ('^{0}\s*=\s*(.+?)\s*$' -f $escaped)) { return $Matches[1] }
    }
    return ''
}

function Write-ProjectValue {
    param([string]$Key, [string]$Value)
    $slash = $Key.IndexOf('/')
    if ($slash -lt 1) { throw "Project key must include its section: $Key" }
    $sectionName = $Key.Substring(0, $slash)
    $relative = $Key.Substring($slash + 1)
    $lines = [System.Collections.ArrayList]@(Get-Content -LiteralPath $script:ProjectPath -Encoding UTF8)
    $escaped = [regex]::Escape($relative)
    $found = $false
    $sectionAt = -1
    $insertAt = -1
    $inside = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\[(.+)\]\s*$') {
            if ($inside) { $insertAt = $i; break }
            $inside = $Matches[1] -eq $sectionName
            if ($inside) { $sectionAt = $i; $insertAt = $i + 1 }
            continue
        }
        if (-not $inside) { continue }
        $insertAt = $i + 1
        if ($lines[$i] -match ('^{0}\s*=' -f $escaped)) {
            $lines[$i] = "$relative=$Value"; $found = $true; break
        }
    }
    if (-not $found) {
        if ($sectionAt -ge 0) {
            $lines.Insert($insertAt, "$relative=$Value")
        } else {
            [void]$lines.Add('')
            [void]$lines.Add("[$sectionName]")
            [void]$lines.Add('')
            [void]$lines.Add("$relative=$Value")
        }
    }
    Save-SourceLines -Path $script:ProjectPath -Lines @($lines)
}
