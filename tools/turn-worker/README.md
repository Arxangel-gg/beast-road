# The relay, and how to put one up

Beast Road connects players directly whenever it can. When it cannot — and for
a real share of players it cannot — the traffic has to bounce off a server both
sides *can* reach. That server is a TURN relay, and without one those players
do not connect at all.

## Why there is a worker here

Cloudflare will not issue long-lived TURN credentials, and it is right not to: a
secret shipped inside a browser game is not a secret. Instead a backend holds a
TURN Key and mints short-lived credentials for whoever asks.

That backend is `worker.js`. It has no state, no database and no dependencies,
because it does exactly one thing: swap a key the players never see for a
credential that expires by itself. It caches at the edge for an hour, so a
thousand players cost one API call rather than a thousand.

## Putting it up

1. **Make a TURN key.** Cloudflare dashboard → search "Realtime" → **TURN Keys**
   → create one. Keep the **Key ID** and the **API token** it shows you; the
   token is shown once.

2. **Deploy the worker.**

   ```
   npm install -g wrangler
   wrangler login
   wrangler deploy
   ```

   Run that from this directory. It prints a URL ending in `.workers.dev`.

3. **Give it the key**, as secrets rather than variables, so they are not in
   this repository and not in `wrangler.toml`:

   ```
   wrangler secret put TURN_KEY_ID
   wrangler secret put TURN_KEY_API_TOKEN
   ```

4. **Point the game at it.** In `game/scripts/systems/coop_webrtc.gd`:

   ```gdscript
   const RELAY_ENDPOINT: String = "https://beastroad-turn.<subdomain>.workers.dev"
   ```

## Checking it works

Open the worker URL in a browser. It should answer with JSON containing
`iceServers`, `turn.cloudflare.com` and a `username`. An error says which of the
two secrets is missing.

Then run `tools/room.sh` and read the end of the diagnostic line:

    ice 2/2/h1s1r1>h1s1r1
                  ^^ relay candidates

**The third number is what matters.** `r0` means no relay was offered and the
strict-router players are still stranded, whatever the configuration says.

## What it costs

Cloudflare gives 1,000 GB a month before charging, then $0.05/GB, and the
allowance is shared with their SFU (which this does not use).

Beast Road sends about 19 MB per hour of two-player co-op and about 101 MB per
hour with four, counting both directions — a relayed session is billed for the
traffic it carries. So the free allowance is roughly **53,000 hours** of relayed
two-player play, or **10,000 hours** of four-player, per month.

And most sessions never touch it. WebRTC only falls back to a relay when it
cannot find a direct path, so the relay carries the minority of connections that
would otherwise have failed. The allowance is not close to being a constraint.
