# Releasing

Everything is built by GitHub Actions. **You do not need Godot's export
templates on your machine** — CI downloads them.

---

## One-time setup

1. Create the repository on GitHub. It must be **public**, or the launcher
   cannot read `releases/latest` without a token and your friend cannot
   download it.

   The name has to match `launcher/scripts/LauncherConfig.gd`:

   ```gdscript
   const REPO_OWNER: String = "Arxangel-gg"
   const REPO_NAME: String = "beast-road"
   ```

2. Point the local repo at it and push:

   ```bash
   git remote add origin https://github.com/Arxangel-gg/beast-road.git
   git push -u origin main
   ```

That is the whole setup. `GITHUB_TOKEN` is provided to Actions automatically —
there is no secret to configure.

---

## Publishing a build

```bash
git tag v0.4.0
git push origin v0.4.0
```

That triggers `.github/workflows/release.yml`, which:

1. Exports the game to `BeastRoad.exe` and zips it as `BeastRoad-windows.zip`
2. Exports the launcher to `BeastRoadLauncher.exe`
3. Creates a GitHub Release named after the tag and attaches both

The launcher notices the new tag on its next start and offers **Update**.

The Update Manager runs the game, a short gameplay soak, and the launcher
release-contract test before it commits or tags anything. It then watches the
workflow for that exact tag and does not report success until both release
assets are visible through GitHub's API.

### If a build fails

Tags are immutable release identifiers. Leave the failed tag in place, fix the
cause, and publish the next patch version. For example, if `v0.1.12` fails,
publish `v0.1.13`; do not move or force-push `v0.1.12`.

The workflow retries transient GitHub/CDN download failures automatically. If
it still fails, open the build link shown by Update Manager and read the first
failed step before publishing another tag.

### Rehearsing without publishing

Actions tab -> Release -> *Run workflow*. It builds and uploads artifacts but
does not create a release.

---

## What to send your friend

The launcher's permanent download link — it always points at the newest one:

```
https://github.com/Arxangel-gg/beast-road/releases/latest/download/BeastRoadLauncher.exe
```

They run it once. It installs the game, and from then on it updates itself.

> Windows SmartScreen will warn about an unsigned executable. That is expected
> for anything without a code-signing certificate; "More info" -> "Run anyway".
> Signing costs a few hundred a year and is worth it only near a store release.

---

## Version numbering

The tag *is* the version. The launcher compares tags for equality and does not
try to order them, so `v0.4.0` -> `v0.3.9` is a valid rollback rather than an
error.

---

## Where the game installs

`%LOCALAPPDATA%\\BeastRoad`, with an `installed.json` recording the tag. That
file is written **last**, so an interrupted install reports as "not installed"
rather than as a broken game.

To force a clean reinstall, delete that folder.

Downloads are staged beside this folder, retried up to three times, and checked
against the release asset's byte count and GitHub SHA-256 before extraction.
