<#
.SYNOPSIS
  Gets the Android APK building. Run it, paste one value, done.

.DESCRIPTION
  Makes an Android signing key if there is not one yet, puts its base64 on your
  clipboard, and opens the page where it goes. Run it again any time you need
  that value back on the clipboard - it reuses the existing key rather than
  making a new one.

  There is exactly one secret to set, ANDROID_KEYSTORE_BASE64. The alias and
  password are built into the workflow, because an alias and a password are only
  worth protecting alongside the key they open - and making them secrets too
  meant three values to paste into a web form and three chances to mistype one.
  That is how this failed the first time, on a message from Godot that would not
  say which of them was wrong.

  Two traps this removes for good:
    * PKCS12 keystores need the store and key passwords to MATCH. keytool lets
      you set two different ones at its prompts, and Godot then cannot open the
      result.
    * The base64 has to be one unbroken line. Producing it and copying out of
      Notepad appends a CRLF, which GNU base64 rejects as a non-alphabet
      character.

.EXAMPLE
  .\tools\new_signing_key.ps1
  # Put the existing key's base64 back on the clipboard and open the page.

.EXAMPLE
  .\tools\new_signing_key.ps1 -Force
  # Replace the key. Anyone who installed the old APK must then uninstall
  # before they can update, so it will not do this by accident.
#>
param(
    [string]$Alias = "beastroad",
    [string]$Password = "beastroad-dev",
    [string]$Out = "signing/beastroad-release.keystore",
    [switch]$Force
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path -Parent $PSScriptRoot)

$keytool = (Get-Command keytool -ErrorAction SilentlyContinue).Source
if (-not $keytool) {
    $guess = Get-ChildItem "C:\Program Files\*\jdk*\bin\keytool.exe" -ErrorAction SilentlyContinue |
             Select-Object -First 1
    if (-not $guess) { throw "keytool not found. Install a JDK (Microsoft OpenJDK or Temurin) and run this again." }
    $keytool = $guess.FullName
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Out) | Out-Null

$reuse = (Test-Path $Out) -and (-not $Force)
if ($reuse) {
    Write-Host "Reusing the key at $Out." -ForegroundColor DarkGray
} else {
    if (Test-Path $Out) { Remove-Item $Out -Force }
    & $keytool -genkeypair -v -keystore $Out -alias $Alias `
        -keyalg RSA -keysize 4096 -validity 10000 -storetype PKCS12 `
        -storepass $Password -keypass $Password `
        -dname "CN=Beast Road, OU=Arxangel, O=Arxangel, C=GB" 2>&1 | Out-Null
    Write-Host "New key written to $Out." -ForegroundColor DarkGray
}

# Proves the alias and password actually open it. A key that cannot be opened is
# found out here rather than in CI ten minutes later.
& $keytool -list -keystore $Out -storepass $Password -alias $Alias 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "The key at $Out does not open with alias '$Alias'. Run again with -Force to make a fresh one."
}

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Out)))
[IO.File]::WriteAllText((Join-Path (Get-Location) "signing/keystore.b64.txt"), $b64)

$copied = $false
try { Set-Clipboard -Value $b64; $copied = $true } catch { }

$url = "https://github.com/Arxangel-gg/beast-road/settings/secrets/actions"

Write-Host ""
Write-Host "===================================================================" -ForegroundColor Green
Write-Host "  ONE THING TO DO" -ForegroundColor Green
Write-Host "===================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  A browser tab is opening on your repository's secrets page."
Write-Host ""
Write-Host "    1. Click  New repository secret   (or Update if it is there)"
Write-Host "    2. Name:  ANDROID_KEYSTORE_BASE64"
if ($copied) {
    Write-Host "    3. Secret: press Ctrl+V   - it is on your clipboard now"
} else {
    Write-Host "    3. Secret: open signing/keystore.b64.txt and copy all of it" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Then push any version tag. That is everything." -ForegroundColor Green
Write-Host ""
Write-Host "  Nothing else to set. The alias and password live in the workflow," -ForegroundColor DarkGray
Write-Host "  because they are worthless without this key." -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Back up $Out - every future update must be" -ForegroundColor Yellow
Write-Host "  signed with this same key or Android refuses to install over it." -ForegroundColor Yellow
Write-Host ""

try { Start-Process $url | Out-Null } catch { Write-Host "  Open $url yourself." -ForegroundColor Yellow }
