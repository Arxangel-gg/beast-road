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
3. Exports the web build and zips it as `BeastRoad-web.zip`
4. Writes `launcher-version-<n>.txt`, naming the launcher's own version
5. Creates a GitHub Release named after the tag and attaches all four
6. Publishes the web build to GitHub Pages, in a separate job

The launcher notices the new tag on its next start and offers **Update** — and
updates *the game only*, unless the launcher version changed too.

### The web build

Same tag, same commit, no extra step. The release job exports the `Web` preset
alongside the Windows one, and a second job deploys it to Pages:

```
https://arxangel-gg.github.io/beast-road/
```

GitHub may reject the first automatic Pages enablement with `Resource not
accessible by integration`. If that happens, open repository **Settings →
Pages**, set **Source** to **GitHub Actions**, and rerun the failed Pages job or
publish the next patch. This is a one-time repository setting; subsequent tagged
releases deploy automatically.

It is a **separate job** on purpose. Deploying to Pages needs `pages: write` and
`id-token: write`, and publishing a release needs `contents: write`; the step
that writes to the public web has no business also being able to rewrite the
repository. It also means a Pages failure leaves the release published rather
than rolling the whole thing back.

Two constraints are load-bearing and are asserted in CI rather than remembered:

- **`variant/thread_support=false`.** A threaded web build only runs on a page
  served with COOP/COEP cross-origin-isolation headers, and Pages cannot set
  response headers at all. A threaded export writes `index.worker.js`; both
  workflows fail if that file appears.
- **`gl_compatibility`.** Already the project's renderer, and the only one that
  reaches WebGL2. Forward+ would need WebGPU.

The web build defaults to the **Medium** graphics preset rather than High. The
argument for High — a player who cannot run it will find the settings screen
within a minute — is a fair bet from someone who installed the game and a bad
one from someone who opened a tab.

The Update Manager runs the game, a short gameplay soak, and the launcher
release-contract test before it commits or tags anything. It then watches the
workflow for that exact tag and does not report desktop success until both
launcher-facing release assets are visible through GitHub's API. The web deploy
is a separate job: if only Pages fails, the manager reports the installed update
as published and shows a web-publishing warning instead of telling the owner to
spend another tag on files that are already live.

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

It installs and updates the game, and it keeps working across releases — a game
update no longer drags a launcher download along with it. See below.

> Windows SmartScreen will warn about an unsigned executable. That is expected
> for anything without a code-signing certificate; "More info" -> "Run anyway".
> Signing costs a few hundred a year and is worth it only near a store release.

Or send them the browser link, which needs no download and no SmartScreen
conversation:

```
https://arxangel-gg.github.io/beast-road/
```

Saves live in the browser's storage for that site, so a web save and an
installed save are separate games. Clearing site data erases it.

---

## Version numbering

The tag *is* the game's version. The launcher compares tags for equality and does
not try to order them, so `v0.4.0` -> `v0.3.9` is a valid rollback rather than an
error.

---

## The launcher's version is separate — bump it by hand

`LAUNCHER_VERSION` in `launcher/scripts/LauncherConfig.gd` is the launcher's own
version, and the only thing that makes a player download a new launcher.

**Change anything under `launcher/`? Bump it. Otherwise leave it alone.**

```gdscript
const LAUNCHER_VERSION: String = "2"
```

CI reads that constant and publishes a marker asset named after it. A running
launcher compares the marker against the version compiled into itself: same
version means the published launcher is the one already installed, so it skips
straight to updating the game.

This used to be the release tag, which moves every release — so every game
update also replaced the launcher, a fresh download and a restart for a launcher
that had not changed a line. On a metered connection that was most of the cost of
a patch that touched one `.tres` file.

Forgetting to bump it ships a launcher nobody installs; the fix is to bump it and
cut another release. Bumping it needlessly costs testers one download. Neither
breaks anything, which is the point of keeping it a hand-turned dial.

Digits and dots only — the release workflow fails the build on anything else,
because the launcher will not parse it.

---

## Where the game installs

`%LOCALAPPDATA%\\BeastRoad`, with an `installed.json` recording the tag. That
file is written **last**, so an interrupted install reports as "not installed"
rather than as a broken game.

To force a clean reinstall, delete that folder.

Downloads are staged beside this folder, retried up to three times, and checked
against the release asset's byte count and GitHub SHA-256 before extraction.
