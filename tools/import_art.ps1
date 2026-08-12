<#
    Installs finished art from art_inbox/ into the game.

    Usage:
        tools\import_art.ps1          # import everything in the inbox
        tools\import_art.ps1 -DryRun  # report what would happen, change nothing
#>
[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$gameDir = Join-Path $repo 'game'

$godotDir = Get-ChildItem -Path $repo -Directory -Filter 'Godot_v*_win64.exe' | Select-Object -First 1
if (-not $godotDir) { throw "Could not find the Godot folder in $repo" }
$godot = Get-ChildItem -Path $godotDir.FullName -Filter '*_console.exe' | Select-Object -First 1
if (-not $godot) { $godot = Get-ChildItem -Path $godotDir.FullName -Filter '*.exe' | Select-Object -First 1 }
if (-not $godot) { throw "No Godot executable inside $($godotDir.FullName)" }

$toolArgs = @('--headless', '--path', $gameDir, '--script', 'res://tools/run_tool.gd', '--', 'import')
if ($DryRun) { $toolArgs += '--dry' }

& $godot.FullName @toolArgs
$code = $LASTEXITCODE

if ($code -eq 0 -and -not $DryRun) {
    Write-Host ''
    Write-Host 'Re-importing in Godot so the new textures are picked up...'
    & $godot.FullName --headless --path $gameDir --editor --quit | Out-Null
    Write-Host 'Done. Run tools\release.ps1 -Version x.y.z when you want to ship it.'
}
exit $code
