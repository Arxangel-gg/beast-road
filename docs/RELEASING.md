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

That completes desktop release setup. `GITHUB_TOKEN` is provided to Actions
automatically; the standard release needs no additional secret. Enable Pages
as described below for automatic browser deployment. Optional Dropbox mirrors
and the separate Android workflow have their own configuration.

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

6. Deploys the browser build to GitHub Pages in a separate job

The launcher notices the new tag on its next start and offers **Update** — and
updates *the game only*, unless the launcher version changed too.

### The web build

Same tag, same commit, no extra step. The release job exports the `Web` preset
alongside the Windows one and attaches **`BeastRoad-web.zip`** to the release.

**The zip is the deployment.** Its `index.html` sits at the root, which is the
shape a static host takes directly.

**Since 2026-08-26 the release also publishes it to GitHub Pages by itself**, at

    https://beastroad.arxangel.gg

The subdomain, not the apex: `arxangel.gg` serves the Carrd page and pointing
the root at Pages would replace it. `beastroad` is a CNAME to
`arxangel-gg.github.io`, and the `CNAME` file is written into the artifact by
the release job rather than being left to the repository's Pages settings - a
deployment should carry everything that decides where it is served, so no
redeploy can lose it. `https://arxangel-gg.github.io/beast-road/` keeps working
as well.

Browser hosting therefore needs no manual deployment after a successful tag
workflow. The drag-a-zip route below remains an alternate-host fallback, and
the release still attaches the zip either way.

This works **only because the export is single-threaded**. Pages cannot send
COOP/COEP headers, so a threaded build would load and then refuse to start; the
build job fails outright if `variant/thread_support` is ever switched back on,
which is what that check is guarding.

One-time setup, if Pages has never been enabled on the repository: **Settings →
Pages → Source → GitHub Actions**. Until that is done the `pages` job fails and
the rest of the release still succeeds — the desktop build, the launcher and the
zip are all unaffected.

Update Manager prints the archive size and direct download link when it can
verify the web zip. A successful tag workflow also confirms the Pages
deployment. If the workflow fails after publishing the desktop assets, the
manager reports the installed update as available and directs you to the
browser job; desktop readiness does not prove browser readiness.

To deploy to an alternate host:

1. Download `BeastRoad-web.zip` from the release.
2. Netlify → **Sites** → drag the zip onto the drop area (or `netlify deploy
   --prod --dir=<unzipped folder>`).
3. Netlify gives back a URL like `https://<name>.netlify.app`.
4. In Carrd, add an **Embed** element, set it to *Code*, and paste an iframe
   pointing at that URL.

`_headers` is written into the bundle for hosts such as Netlify that read it.
All files use `Cache-Control: no-cache`: browsers may store them but must
revalidate before reuse. The exported filenames are fixed across releases, so
year-long immutable caching could serve an old wasm or pck beside a new shell.
Pages ignores this host-specific file and uses its own caching policy.

An iframe that runs the game wants its own size and the keyboard:

```html
<iframe src="https://<name>.netlify.app"
        style="width:100%;aspect-ratio:16/9;border:0"
        allow="autoplay; fullscreen; gamepad"
        allowfullscreen></iframe>
```

A canvas only receives key events once it has focus, and inside an iframe that
means the player has to click the game before typing — which they do anyway to
start it, because browsers will not begin audio without a gesture either.

Two constraints are load-bearing and are asserted in CI rather than remembered:

- **`variant/thread_support=false`.** A threaded web build only runs on a
  cross-origin-isolated page, and a cross-origin-isolated document will not
  embed in an iframe that is not — which is exactly where this build is going.
  Netlify *could* send COOP/COEP headers, unlike Pages, and it still must not.
  A threaded export writes `index.worker.js`; both workflows fail if it appears.
- **`gl_compatibility`.** Already the project's renderer, and the only one that
  reaches WebGL2. Forward+ would need WebGPU.

Two platform behaviours are handled where they have to be, not where it would
have been convenient:

- **The window mode** is overridden to windowed for the web in `project.godot`
  (`window/size/mode.web=0`). Mode 3 is fullscreen and the engine applies it at
  boot *before any script runs*, so the build opened by asking a browser for
  fullscreen and being refused — a warning on every single load. A feature-tagged
  project setting is the only place early enough to prevent it.
- **The Fullscreen button still works** in a browser. A first attempt blocked
  the whole display path on the web, which stopped the boot-time request (the
  bug) and also killed the settings button (not the bug). Fullscreen is legal
  from inside a user gesture, and a click is one.

The web build defaults to the **Medium** graphics preset rather than High. The
argument for High — a player who cannot run it will find the settings screen
within a minute — is a fair bet from someone who installed the game and a bad
one from someone who opened a tab.

The Update Manager runs the game, a short gameplay soak, and the launcher
release-contract test before it commits or tags anything. It then watches the
workflow for that exact tag and does not report desktop success until both
launcher-facing release assets are verified through GitHub's API or their
canonical download links. The web deploy
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

The Dropbox mirror is optional and runs only for tag releases. If it fails,
the workflow discards that attempt's generated mirror metadata and warns in
Actions while continuing to publish the GitHub downloads. Branch rehearsals
never overwrite the production mirror. Repair the mirror separately; do not
spend another game version merely because the backup mirror was unavailable.

### Rehearsing without publishing

Actions tab -> Release -> *Run workflow*, with a branch selected. It builds and
uploads artifacts without creating a release or deploying Pages. The current
workflow publishes only when its selected ref is a `v*` tag; the optional `tag`
text input does not select or check out a tag.

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

Or send them [the browser game](https://beastroad.arxangel.gg), which needs no
download, or the Carrd page embedding it.

Saves live in the browser's storage for that site, so a web save and an
installed save are separate games. Clearing site data erases it, and so does
switching to a different domain or host URL — storage is per-origin, so keep
the site address across releases.

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
