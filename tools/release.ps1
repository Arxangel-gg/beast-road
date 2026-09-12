<#
.SYNOPSIS
    Tags a release and pushes it, which is all it takes to publish a build.

.DESCRIPTION
    GitHub Actions does the rest: it exports the game and the launcher, zips the
    game, and attaches both to a new GitHub Release. Nothing is built locally,
    so you do not need Godot's export templates on this machine.

.EXAMPLE
    .\tools\release.ps1 -Version 0.4.0

.EXAMPLE
    .\tools\release.ps1 -Version 0.4.0 -DryRun
#>
[CmdletBinding()]
param(
    # Version without the leading "v" - 0.4.0, not v0.4.0.
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    # Show what would happen without tagging or pushing.
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$tag = "v$Version"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host ""
Write-Host "Wilderhold release $tag" -ForegroundColor Yellow
Write-Host ""

# A tag is a promise about a commit. Publishing one from a dirty tree means the
# build will not match what is on this machine.
$dirty = git status --porcelain
if ($dirty) {
    Write-Host "Uncommitted changes:" -ForegroundColor Red
    git status --short
    Write-Host ""
    Write-Host "Commit or stash first - the tag has to point at a real commit." -ForegroundColor Red
    exit 1
}

# Checked by listing rather than by asking for the URL: `git remote get-url` on
# a missing remote writes to stderr, and PowerShell 5.1 turns native stderr into
# a terminating error under $ErrorActionPreference = 'Stop'.
$remotes = @(git remote)
if ($remotes -notcontains 'origin') {
    Write-Host "No 'origin' remote. Create the GitHub repo, then:" -ForegroundColor Red
    Write-Host "  git remote add origin https://github.com/Arxangel-gg/beast-road.git"
    Write-Host "  git push -u origin main"
    exit 1
}
$remote = git remote get-url origin

$existing = git tag --list $tag
if ($existing) {
    Write-Host "Tag $tag already exists. Pick another version, or delete it:" -ForegroundColor Red
    Write-Host "  git tag -d $tag; git push origin :refs/tags/$tag"
    exit 1
}

$branch = git rev-parse --abbrev-ref HEAD
$commit = git rev-parse --short HEAD
Write-Host "  remote  $remote"
Write-Host "  branch  $branch"
Write-Host "  commit  $commit"
Write-Host ""

if ($DryRun) {
    Write-Host "Dry run. Would tag $tag and push it." -ForegroundColor Cyan
    exit 0
}

git tag -a $tag -m "Wilderhold $Version"
# git reports on stderr even when it succeeds ("Everything up-to-date"), and
# under 'Stop' Windows PowerShell 5.1 turns that line into a terminating
# NativeCommandError - which aborted a release after the tag was made and
# before it was pushed (2026-09-12). Exit codes are the truth here.
$ErrorActionPreference = 'Continue'
git push origin $branch 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { Write-Host "Pushing $branch failed." -ForegroundColor Red; exit 1 }
git push origin $tag 2>&1 | ForEach-Object { "$_" }
if ($LASTEXITCODE -ne 0) { Write-Host "Pushing $tag failed." -ForegroundColor Red; exit 1 }
$ErrorActionPreference = 'Stop'

$slug = $remote -replace '^.*github\.com[:/]', '' -replace '\.git$', ''
Write-Host ""
Write-Host "Pushed $tag. GitHub Actions is building it now:" -ForegroundColor Green
Write-Host "  https://github.com/$slug/actions"
Write-Host ""
Write-Host "When it finishes, the launcher link to share is:" -ForegroundColor Green
Write-Host "  https://github.com/$slug/releases/latest/download/BeastRoadLauncher.exe"
Write-Host ""
