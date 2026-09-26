# What Wilderhold sends, and to whom

**Draft of 2026-09-26, for the owner to review before any public release.** It
is written from the code, not from intent: every network call in the game is
listed here, and `privacy_check` fails the build if the code gains a host this
file does not name. It is not legal advice, and a store listing or a regional
law may want more than this says.

## The short version

Wilderhold has no accounts, no analytics, no advertising and no tracking. It
sends something over the network only when you use a feature that is about
other people: posting to the leaderboard, trading on the Long Ledger, or
playing co-op online. Everything else stays on your machine.

## What leaves your machine, feature by feature

### The leaderboard: only when you press Submit

At the end of a run the results screen offers to post it. Nothing is sent
unless you press Submit. A post carries:

- the name you type in that field (trimmed and length-limited),
- the difficulty, score, act, wave, Warden level and run duration,
- whether the run was won, the run's seed, and the game's version,
- a random id that stops the same post being counted twice.

The board is public: anyone with the game can read it. The game cannot edit or
delete a posted row. To have a row removed, contact the developer.

A post that could not be sent waits on your machine and is tried again the next
time the game starts or you open the board.

Where it goes: a Supabase database at `xscyioampvjfqcciccie.supabase.co`.

### The Long Ledger: prices, never pieces

When a piece you listed on the Ledger sells, the game publishes what it sold
for: its rarity, the price, and what a vendor would have paid. It never sends
who you are, which piece it was, or anything about your stash. Opening the
Ledger reads recent prices back.

Where it goes: the same Supabase database.

### Co-op online

- **Your own network.** While you host, the game announces it once a second
  on your local network, so a second machine in the same house can see it: the
  game name you enter, the port, how many players are in it, the game's
  version and a random id. A broadcast is not routed, so it never leaves your
  local network.
- **Listing a game.** Hosting a public game puts one row in a lobby list: a
  room code, the game name you enter, how many players are in it, and a
  password if you set one. The row is removed when the game starts, when you
  stop hosting or when the game closes.
- **Joining.** Two machines introduce themselves through the same database: the
  room code, a random token, and each machine's connection offer. A connection
  offer contains your network addresses, which is how two machines find each
  other.
- **Playing.** Once connected, the two machines talk to each other directly.
  As in any peer-to-peer game, the other players' machines learn your IP
  address.
- **Finding a route.** To get through home routers, the game asks public STUN
  servers what your address looks like from outside: `stun.l.google.com`,
  `stun1.l.google.com` and `stun.cloudflare.com`. They see your IP address and
  nothing else.
- **Showing you your address.** When you host and your router does not answer
  a UPnP request, the game asks `api.ipify.org` for your public address so the
  co-op screen can show it to you. That request carries nothing.
- **Opening a port.** When you host by port rather than by room code, the
  game asks your router over UPnP to forward one UDP port to your machine. It
  asks for it to be closed again when you stop hosting or quit, and asks for a
  one-day lease so a crash cannot leave it open for longer. (Before 2026-09-26
  the port was left open until the router restarted.)

### Support and crash reports: never sent

Settings › Data can prepare a support report. It stays on screen until you copy
it yourself, and nothing is sent. If the game closed unexpectedly last time,
the report also carries that session's error lines, with your folder names
removed. The marker the game uses to notice a crash stays on your machine.

### The launcher

The launcher asks GitHub (`api.github.com`) for the newest release, and
downloads it from GitHub when you choose to install or update.

## What stays on your machine

Your save (your Wardens, stash, pen, stable, settings and statistics), the
personal-best board, queued leaderboard posts, the game's logs and the crash
marker. All of it lives in the game's own folder under your user data
directory and never leaves it unless you copy it yourself.

## Children

Wilderhold asks for no age, email address or real name. The leaderboard name
is whatever the player types; a public board is the one place a child could
reveal something about themselves. The name is length-limited and stripped of
control characters, but it is **not** filtered for words: whether it should be
is an open question below.

## Open questions for the owner

- A contact address for removal requests.
- Whether the leaderboard should stay public, or be limited to friends (see the
  release ledger's "Leaderboard integrity").
- Whether a store or region needs a formal privacy policy beyond this note.
- Whether leaderboard names should be filtered for offensive words or personal
  details before they are posted.
