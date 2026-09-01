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

Run this, then paste three values into GitHub. That is the whole job.

```powershell
.\tools\new_signing_key.ps1
```

It makes the key, **verifies the alias and password actually open it**, and puts
the base64 on your clipboard. Then, in GitHub under
**Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `ANDROID_KEY_ALIAS` | `beastroad` |
| `ANDROID_KEY_PASSWORD` | whatever the script printed |
| `ANDROID_KEYSTORE_BASE64` | paste — it is already on your clipboard |

Push any version tag and the APK attaches to that release.

`ANDROID_KEYSTORE_PASSWORD` is not read by the build: a PKCS12 keystore has one
password and Godot takes one. Harmless if it is set.

### Why a script rather than instructions

The first attempt failed with Godot's single message for two different mistakes:

    Release Username and/or Password is invalid for the given Release Keystore

which leaves you guessing which of two hand-typed values to re-enter. The script
chooses both, so there is nothing to remember, and it proves the pair opens the
keystore before printing anything. Two specific traps it removes:

* PKCS12 needs the store and key passwords to **match**. `keytool` lets you set
  two different ones at the prompts, and Godot then cannot open the result.
* The base64 must be one line with no trailing newline. Producing it and copying
  from Notepad appends a CRLF, which GNU `base64` rejects outright. The
  clipboard copy avoids the file entirely.

### Redoing it

Run the script again with `-Force`. **Read this first:** replacing the key means
anyone who installed the old APK has to uninstall before they can update, because
Android refuses an update signed by a different key. The script refuses to
overwrite without `-Force` for that reason.

### Where the key lives

`signing/`, which `.gitignore` keeps out of the repository - by folder and by
extension, after the first key spent a while sitting one `git add -A` away from
being published. **Back it up somewhere you will not lose it.** It is not in git
on purpose, so nothing else will.

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
