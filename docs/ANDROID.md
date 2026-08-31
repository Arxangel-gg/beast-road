# Android / APK

Beast Road ships to Android as a **directly downloaded APK**, not through the
Play Store. The button on `beastroad.arxangel.gg` points at the newest release's
`BeastRoad.apk`, and `.github/workflows/android.yml` builds and signs it whenever
a version tag is pushed.

That choice has one cost, and it is worth knowing before anyone is asked to
install: Android blocks installs from outside the Play Store until the user
allows it for their browser, once, in a system dialog. There is no way to avoid
that prompt while distributing outside the store — the alternative is a Play
Store listing, which needs a developer account, a one-off fee, store assets and
review time.

---

## What the owner has to do, once

**Everything else is automated. This is the only manual part, and it exists
because the signing key must belong to a person rather than to a build.**

### 1. Generate a keystore

Run this on your own machine, not in CI. `keytool` comes with any JDK.

```bash
keytool -genkeypair -v -keystore beastroad-release.keystore -alias beastroad -keyalg RSA -keysize 4096 -validity 10000
```

It asks for a password and some identifying details. The details are cosmetic;
the password is not.

### 2. Back it up somewhere you will not lose it

**The signing key is permanent.** Every future update must be signed with the
same key, or Android refuses to install it over an existing copy — users would
have to uninstall first, losing their local data. Losing this file means losing
the ability to update the app for everyone who has it.

Keep it out of the repository. It is deliberately not in `.gitignore` as a
reminder that it should never be near the working tree at all.

### 3. Add four repository secrets

In GitHub: **Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | the keystore file, base64-encoded (below) |
| `ANDROID_KEY_ALIAS` | `beastroad`, or whatever `-alias` you used |
| `ANDROID_KEY_PASSWORD` | the password you chose |
| `ANDROID_KEYSTORE_PASSWORD` | the same password, unless you set a separate one |

To produce the base64 blob:

```bash
base64 -w0 beastroad-release.keystore > keystore.b64
```

On Windows PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("beastroad-release.keystore")) | Set-Content keystore.b64
```

Paste the contents of `keystore.b64` as the secret value, then delete that file.

### 4. Push a tag

`tools/release.ps1 -Version 0.4.x` as usual. The Android workflow runs alongside
the normal release and attaches `BeastRoad.apk` to it.

---

## Until those secrets exist

The workflow **skips itself and says so**, as a notice rather than a failure, and
nothing else about releasing changes. The download button still appears on the
site and will 404 until the first APK is attached — deliberately, because a
publish step that fails over a missing optional asset would be worse than a link
that does not work yet.

## Why the Android build is its own workflow

It is the one target that cannot be checked before it runs: it needs the Android
SDK, a JDK and Godot's Android export templates, none of which exist on the
machine the preset was written on. Inside the release pipeline, a wrong preset
key would stop the game shipping at all. On its own it can fail without taking
the Windows, web and launcher builds with it.

Expect the first run to need a correction. That is what it is shaped for.
