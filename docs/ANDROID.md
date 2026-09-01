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

## Setting it up

Run this:

```powershell
powershell -ExecutionPolicy Bypass -File tools/new_signing_key.ps1
```

It makes the signing key if there is not one, puts its base64 on your clipboard,
and opens your repository's secrets page. Then:

1. **New repository secret** (or Update, if it is already there)
2. Name: `ANDROID_KEYSTORE_BASE64`
3. Secret: **Ctrl+V**

Push any version tag. That is the whole setup.

Run the same command again whenever you need that value back on the clipboard -
it reuses the existing key rather than making a new one.

### Why only one secret

An alias and a password are worth protecting alongside the key they open, and
the key is the secret. Making them secrets too meant three values to paste into
a web form and three chances to mistype one - which is how this failed the first
time, on Godot's single message for two different mistakes:

    Release Username and/or Password is invalid for the given Release Keystore

They live in the workflow now, and `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD`
still override them if a different key is ever used.

### Replacing the key

```powershell
powershell -ExecutionPolicy Bypass -File tools/new_signing_key.ps1
```

**Read this first.** Android refuses an update signed by a different key, so
everyone who installed the old APK has to uninstall before they can update. The
script will not replace a key without `-Force` for that reason.

### Where the key lives

`signing/`, which `.gitignore` keeps out of the repository - by folder and by
extension, after an earlier key spent a while sitting one `git add -A` away from
being published. **Back it up somewhere you will not lose it**, because it is
deliberately not in git and nothing else is keeping a copy.

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
