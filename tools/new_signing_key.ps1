<#
.SYNOPSIS
  Makes an Android signing key and prints the exact four values to paste into
  GitHub, so nobody has to remember what they typed six weeks ago.

.DESCRIPTION
  The first attempt at this failed with:

      Release Username and/or Password is invalid for the given Release Keystore

  which is Godot's single message for two different mistakes, on credentials a
  person chose by hand at a prompt. This script chooses them, so what to paste is
  never in doubt - it prints the alias, the password and the base64 blob.

  Two details that bite and are handled here:
    * PKCS12 keystores need the store and key passwords to MATCH. keytool will
      happily let you set two different ones, and Godot then cannot open it.
    * The base64 must be one line with no trailing newline. Producing it in
      Notepad appends a CRLF, which GNU base64 rejects as a non-alphabet
      character. (The workflow strips whitespace anyway, but this avoids it.)

  The keystore is written to signing/, which .gitignore keeps out of the
  repository. It is a real signing key: back it up, because every future update
  must be signed with the same one or Android refuses to install over the app.

.EXAMPLE
  .\tools\new_signing_key.ps1
  .\tools\new_signing_key.ps1 -Password "something-else" -Force
#>
param(
    [string]$Alias = "beastroad",
    [string]$Password = "beastroad-dev",
    [string]$Out = "signing/beastroad-release.keystore",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
    $guess = Get-ChildItem "C:\Program Files\*\jdk*\bin\keytool.exe","C:\Program Files\*\*\bin\keytool.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $guess) { throw "keytool not found. Install a JDK (Temurin or Microsoft OpenJDK) and retry." }
    $keytool = $guess.FullName
} else { $keytool = $keytool.Source }

if ((Test-Path $Out) -and -not $Force) {
    throw "$Out already exists. Pass -Force to replace it - but read this first: replacing the key means anyone who installed the old APK must uninstall before they can update."
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null
if (Test-Path $Out) { Remove-Item $Out -Force }

& $keytool -genkeypair -v -keystore $Out -alias $Alias `
    -keyalg RSA -keysize 4096 -validity 10000 -storetype PKCS12 `
    -storepass $Password -keypass $Password `
    -dname "CN=Beast Road, OU=Arxangel, O=Arxangel, C=GB" | Out-Null

# Proves the pair actually opens it, which is the failure this script exists to
# prevent. A key that cannot be opened is found out here, not in CI.
& $keytool -list -keystore $Out -storepass $Password -alias $Alias | Out-Null
if ($LASTEXITCODE -ne 0) { throw "The key was written but the alias and password do not open it." }

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Out)))
$b64File = "signing/keystore.b64.txt"
[IO.File]::WriteAllText((Join-Path $root $b64File), $b64)

Write-Host ""
Write-Host "Key written to $Out and verified." -ForegroundColor Green
Write-Host ""
Write-Host "Paste these into GitHub -> Settings -> Secrets and variables -> Actions:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ANDROID_KEY_ALIAS         $Alias"
Write-Host "  ANDROID_KEY_PASSWORD      $Password"
Write-Host "  ANDROID_KEYSTORE_BASE64   <- already on your clipboard"
Write-Host ""
Write-Host "  (ANDROID_KEYSTORE_PASSWORD is not read by the build - a PKCS12"
Write-Host "   keystore has one password and Godot takes one. Harmless if set.)"

# On the clipboard rather than in a file to open: copying 5,760 characters out
# of Notepad is where the CRLF came from last time, and selecting all of a long
# line by hand is the step most likely to go wrong.
try {
    Set-Clipboard -Value $b64
    $copied = $true
} catch {
    $copied = $false
}
if (-not $copied) {
    Write-Host ""
    Write-Host "  (clipboard unavailable - paste from $b64File instead)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Then push any version tag. The APK attaches to that release and the" -ForegroundColor Cyan
Write-Host "Download button on the site starts working." -ForegroundColor Cyan
Write-Host ""
Write-Host "Back up $Out somewhere safe - every future update must be signed" -ForegroundColor Yellow
Write-Host "with this same key or Android will refuse to install over the app." -ForegroundColor Yellow
