# Matchmaking — the public lobby list

Beast Road offers three ways into a game, in the order most people will use
them: the **local lobby** (games on your own network, found with a UDP beacon,
no server involved), the **public lobby list** (this document), and a
**connect code** pasted by hand.

The public list is one small table in Supabase. It holds one row per game that
is *currently open* and nothing else — no accounts, no history, no chat. A row
is created when somebody hosts, updated every twenty seconds while they wait,
and deleted the moment the pair enters a run. **When nobody is looking for a
game the table is empty**, which is the state it should spend most of its life
in.

## What a row contains

Only what a stranger needs to join, and nothing that identifies a machine or a
person:

| column | what it is |
|---|---|
| `id` | the row's own identifier |
| `code` | the connect code, carrying both addresses and the port |
| `name` | the host's hero class and level, e.g. `Warden · level 9` |
| `players` | 1 while waiting, 2 once a partner has arrived |
| `owner_token` | a secret the host generated; never leaves that machine except to prove it owns this row |
| `created_at` | when it was listed, for ordering and for the age shown in the list |
| `heartbeat` | last time the host said it was still there |

The name is deliberately the hero, not the player: no machine name, no account
name, nothing typed by a person.

## Why the client never writes to the table

The anon key is in the client, which is what an anon key is for — it identifies
the project and grants nothing on its own. What matters is what it can reach.

Anonymous clients have no identity, so any `delete` policy permissive enough to
let a host remove its own row is permissive enough to let anybody remove every
row. So the table takes **no direct writes at all**. It is reached through three
`security definer` functions, each of which requires the token handed back when
the row was created, and read through a view that does not expose that token.

## The SQL

**[`matchmaking.sql`](matchmaking.sql) is the whole thing, and it is safe to
re-run.** Paste the file into the Supabase SQL editor. It reaches the finished
state from any starting point: an empty project, or one part-way through an
earlier version.

It used to be a sequence of blocks in this document, applied in order and never
again - a changelog wearing a script's clothes. That breaks the moment anybody
runs it twice, and the errors do not point at the cause: `create or replace
view` refuses to reorder or drop a column, so an older block against a newer
database fails with *cannot drop columns from view*, and `create or replace
function` matches on the argument list, so a function that gained a parameter
quietly becomes *two* functions with the same name.

Both of those are only reachable when something already exists - which is
exactly the case that testing against a fresh project cannot see.

Run this once in the Supabase SQL editor. It is safe to re-run.

*(The SQL lives in [`matchmaking.sql`](matchmaking.sql) — one script, safe to re-run. It is not repeated here, because a copy in prose is a copy that drifts.)*

## How the row is removed

Four ways, so no single one has to be reliable:

1. **The run begins.** `GameDirector.start_run` withdraws it. A party that is
   playing is not looking for anybody.
2. **Hosting stops.** `Coop.leave` withdraws it.
3. **The game closes.** `CoopDirectory._exit_tree` withdraws it, best effort.
4. **Nothing at all happens.** The heartbeat lapses, the row stops appearing in
   `lobbies_public` within 75 seconds, and the next write from anybody sweeps it.

## What happens before the SQL is applied

Nothing breaks. Every call fails quietly, the public list stays empty, and the
local lobby and the connect code work exactly as they do now. The game never
blocks on this table and never shows an error about it.

---

# Rooms and signalling — how the web build plays

The lobby table above answers *"who is open right now"*. This second pair of
tables answers *"how do these two machines reach each other"*, and it is what
makes co-op work **in a browser** and **through a home router nobody
configured**.

Two peers cannot start a WebRTC connection without something in the middle to
pass notes: each has to tell the other what it looks like from the outside
(an SDP offer or answer) and which routes might work (ICE candidates). That is
all a signalling server does, and it is out of the picture the moment the two
are talking directly. Here it is a table, polled over the same REST client the
lobby list uses — a handshake is a handful of messages over a couple of seconds,
so polling costs nothing and avoids a second protocol that would have to behave
identically inside a browser and outside one.

**A room is deleted the instant both sides connect.** Nothing about a finished
handshake is worth keeping.

## The SQL

Run this after the lobby SQL above. Safe to re-run.

*(The SQL lives in [`matchmaking.sql`](matchmaking.sql) — one script, safe to re-run. It is not repeated here, because a copy in prose is a copy that drifts.)*

## What a room does not contain

No IP address, no port, no machine name. The SDP and ICE payloads describe how
to reach a peer and are visible only to the other side of that room, for the few
seconds the handshake lasts, and go with the room when it is deleted.

## STUN, and the case this does not cover

Connections are negotiated against public STUN servers, which is enough for the
great majority of home routers. It is **not** enough for a symmetric NAT at both
ends at once — that needs a TURN relay, which is a server that carries the
traffic rather than just the introductions, and therefore a running cost. If
that turns out to matter in practice the place to add it is `ICE_SERVERS` in
`coop_webrtc.gd`; nothing else has to change.

---

# Passwords, matchmaking and friends

Everything above shipped with v0.4.66-70. This section is the v0.4.73 additions,
and like the rest it is safe to re-run.

*(The SQL lives in [`matchmaking.sql`](matchmaking.sql) — one script, safe to re-run. It is not repeated here, because a copy in prose is a copy that drifts.)*

## Why a friends list has no accounts

Signing in would mean holding passwords, resetting them, and storing something
worth stealing — for a game whose entire social feature is "let me play with the
person I am already talking to".

So each player gets a **play code**: six characters, generated once, kept in
their save. You give it to a friend the way you would give them a phone number.
The only thing the service ever stores against it is a heartbeat and, if they
are hosting, the room they are in — so a friends list is "which of these codes
answered in the last two minutes", and a row leaks nothing its owner did not
hand out.

Presence is asked about **by code and never listed**, which is the difference
between looking up a friend and enumerating every player online.
