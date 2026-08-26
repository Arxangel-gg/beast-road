# Download mirrors

The launcher fetches a build from GitHub. That works almost everywhere and fails
completely in a few places, because **the version check and the download are two
different hosts**: `api.github.com` answers, the launcher learns there is a patch,
and the asset itself comes from `release-assets.githubusercontent.com` — backed
by Azure blob storage, a different CDN on different addresses. Where that host is
filtered, the launcher used to sit at 0% forever.

Two things fix that, and both are in place:

1. **A stall watch.** No new bytes for twenty seconds means give up and move on.
   `HTTPRequest.timeout` alone cannot do this job: any deadline generous enough
   for ninety megabytes on a poor line is far too long to wait before trying
   somewhere else. Progress is watched instead, so a slow connection is never
   punished and a blocked one is caught quickly.
2. **Mirrors**, tried in order, GitHub always first.

## Adding a mirror

Mirrors live in `mirrors.json`, beside the launcher executable. No new build is
needed to add, move or drop one:

```json
[
  {
    "name": "Google Drive",
    "assets": {
      "BeastRoad-windows.zip": "https://drive.google.com/uc?export=download&id=FILE_ID"
    }
  },
  {
    "name": "Dropbox",
    "assets": {
      "BeastRoad-windows.zip": "https://www.dropbox.com/scl/fi/XXXX/BeastRoad-windows.zip?dl=1"
    }
  }
]
```

Only `http` and `https` URLs are used. Anything else in the file is ignored —
the list is a file on disk, and a `file://` entry would have the launcher
"download" from anywhere on the machine.

## The part that is easy to get wrong

**A direct download URL has to survive the next release.** Both services give a
link tied to the *file*, not to the name — so uploading a new zip and deleting
the old one produces a new link, and every launcher in the world is still
pointing at the old one.

Do this instead, once per asset:

- **Google Drive** — upload the zip once, then use *Manage versions → Upload new
  version* for every release after. The file ID never changes. Get the ID from
  the share link (`.../file/d/<ID>/view`) and use
  `https://drive.google.com/uc?export=download&id=<ID>`. Set sharing to *Anyone
  with the link*.
- **Dropbox** — upload once, then *replace* the file rather than deleting and
  re-uploading. Take the share link and change `dl=0` to `dl=1`.

**Drive refuses a direct download above about 100 MB**, interposing a virus-scan
warning page instead. `BeastRoad-windows.zip` is under that today at 88 MB;
`BeastRoadLauncher.exe` is 105 MB and is *not* a candidate for a Drive mirror.
Dropbox has no such limit.

## What this cannot fix

A mirror only helps a player who can reach the mirror. Both of these are widely
reachable, but neither is universal, and the launcher itself still has to be
downloaded from somewhere the first time. For a player who can reach none of
them, the answer is the web build — an ordinary page on an ordinary CDN, with no
download at all.

---

# The Dropbox mirror — what is automatic and what is not

Since v0.4.70 the release workflow does all of this on every tag, with nothing
to remember:

1. Uploads `BeastRoad-windows.zip` to `/BeastRoad/BeastRoad-windows.zip` in
   Dropbox, in **overwrite** mode.
2. Reuses the existing public link, or creates one the first time.
3. Writes that link into a `mirrors.json` published alongside the release.

The launcher fetches `mirrors.json` when it checks for an update and **caches
it**, so the day GitHub cannot be reached is not also the day the mirror list
becomes unreachable.

Overwrite mode is the whole trick. A Dropbox link belongs to the *file*, not to
the name, so deleting and re-uploading would hand out a new link and silently
break every launcher already in the world. Overwriting keeps one link alive for
ever.

## The one-time setup

Three repository secrets. After this, nothing needs touching again:

1. Go to <https://www.dropbox.com/developers/apps> → **Create app** → *Scoped
   access* → *App folder* is fine → name it anything.
2. On the **Permissions** tab tick `files.content.write`,
   `files.content.read`, `sharing.write` and `sharing.read`, then **Submit**.
   Do this *before* generating a token — a token only carries the permissions
   that existed when it was made.
3. On **Settings**, note the *App key* and *App secret*.
4. Get a refresh token. In a browser, visit — with your app key in place:

   ```
   https://www.dropbox.com/oauth2/authorize?client_id=APP_KEY&token_access_type=offline&response_type=code
   ```

   Approve, copy the code, then exchange it (once, from any terminal):

   ```
   curl -u APP_KEY:APP_SECRET -d code=THE_CODE -d grant_type=authorization_code \
     https://api.dropbox.com/oauth2/token
   ```

   The reply contains `refresh_token`.
5. In GitHub → *Settings* → *Secrets and variables* → *Actions*, add
   `DROPBOX_APP_KEY`, `DROPBOX_APP_SECRET` and `DROPBOX_REFRESH_TOKEN`.

**Refresh tokens do not expire.** The workflow exchanges one for a short-lived
access token on each run, so no long-lived credential is ever stored or printed.

If the secrets are missing the step prints a notice and the release continues —
a mirror is a convenience, and a release must never fail because a convenience
is unavailable.

## Why Google Drive was dropped

Drive refuses a direct download above roughly 100 MB, interposing a virus-scan
warning page that a launcher cannot answer. `BeastRoad-windows.zip` is 88 MB
today and rising, and a mirror that stops working at some unannounced future
size is worse than no mirror — it fails on exactly the release nobody tested.
Dropbox has no such limit.
