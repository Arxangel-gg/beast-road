# Co-op over WebRTC — the transport that works everywhere

Beast Road has two co-op transports. Neither is a fallback for the other; each
does something the other cannot, and both are live.

| | ENet (a port) | WebRTC (a room) |
|---|---|---|
| Runs in a browser | no — a browser cannot open a UDP socket | **yes** |
| Crosses a home router unconfigured | no | **yes**, via STUN |
| Needs the internet at all | **no** | yes, for the handshake |
| Needs a server | **no** | a table, for the introduction only |
| Latency | **lower** — nothing negotiated | good, one extra hop while connecting |
| What you share | a 10 or 16 character code carrying addresses | a **6 character** room code |

The rule of thumb the interface follows: **offer a room first**, because it is
the one that works for everybody; keep the port because it is the one that works
with the line down and is faster when it is available.

## What a room actually is

Two peers with fixed ids — the host is 1, the guest is 2 — and a short-lived
row in a table that exists only to let them describe themselves to each other.

1. The host opens a room. It gets back a six-character code and a secret token.
2. The guest enters the room by code and posts a WebRTC offer.
3. The host reads it and posts an answer.
4. Both post ICE candidates — the routes each might be reachable on — as their
   connection layer discovers them.
5. The moment the peer reports connected, **the room is deleted**. Nothing
   about a finished handshake is worth keeping.

Signalling is polled over REST rather than held on a socket. A handshake is a
dozen messages over a couple of seconds, so a one-second poll costs nothing, and
it avoids a second network protocol that would have to behave identically inside
a browser and outside one. The SQL is in `docs/MATCHMAKING.md`.

## Why nothing above the transport changed

`CoopRelay` speaks `SceneMultiplayer.send_bytes` on whatever `MultiplayerPeer`
is installed. It was written that way to be path-independent rather than to be
portable, and portability came free: the facts, the authority guard, the request
and refusal shapes, the entity interpolation and the two-process harness are all
untouched, and none of them can tell which transport carried a packet.

`Coop.host_room()` and `Coop.join_room()` build a peer and install it. That is
the whole integration.

## The desktop half needs a binary

A browser implements WebRTC itself and the engine binds straight to it. Desktop
Godot does not, and needs the official `webrtc_native` extension, which lives in
`game/addons/webrtc_native/` — Windows x86_64 only, debug and release, about
4 MB each.

Two consequences worth knowing:

- **The `.gdextension` lists only what is committed.** Adding a platform means
  adding its binary in the same change. A file listed and missing is a promise
  the repository does not keep.
- **The guest offers, and which side does is not arbitrary.**
  `WebRTCMultiplayerPeer` creates the data channels on the peer with the higher
  id and expects the lower one to receive them, so an offer from the host
  describes a connection with nothing in it. ICE and DTLS still complete, both
  connections report `STATE_CONNECTED`, and no channel ever opens — a failure
  that looks exactly like a network problem and is not one.
- **`CoopWebRTC.available()` initialises a connection rather than checking for a
  class name.** The engine defines `WebRTCPeerConnection` whether or not
  anything implements it, so `class_exists` answers true on a build with no
  extension — and the room button would be decoration. `tools/coop_check.tscn`
  fails if this build cannot really do it, and `release.yml` asserts the DLL is
  inside the shipped zip rather than inside the folder it was built from.

## What this does not cover

Connections are negotiated against public STUN servers, which is enough for the
large majority of home routers. It is **not** enough when both ends sit behind
a symmetric NAT at once. That case needs a TURN relay — a server that carries
the traffic rather than only the introductions, with a running cost to match. If
it turns out to matter, the place to add one is `ICE_SERVERS` in
`scripts/systems/coop_webrtc.gd`, and nothing else has to change.

Three STUN servers are listed rather than one. In the places where reaching a
friend is hardest, one of them being unreachable is the likely case rather than
the unlucky one.

## Two things that look like network faults and are not

Both cost an afternoon, and both present as a handshake that times out:

- **`get_connection_status()` on a mesh answers CONNECTED immediately**, because
  a mesh is connected to itself. Waiting on it succeeds instantly and installs a
  peer whose data channel is still closed; the first packet then fails with
  "DataChannel not open". Ask `get_peers()[id]["connected"]` instead — the state
  of the *other* peer, which is what both the transport and the harness now do.
- **`peer_connected` is emitted by a `MultiplayerAPI` driving the peer**, not by
  the peer on its own. A harness that polls a peer directly and waits for that
  signal waits forever, against two peers that connected in a fifth of a second.
  Read the state, not the announcement.

## Relays (TURN) — required, and currently not configured

`CoopWebRTC.STUN_SERVERS` is filled in. `CoopWebRTC.TURN_SERVERS` is **empty**,
and until it is not, some pairs of players cannot connect to each other at all.

STUN tells a peer what address its router is presenting. That is enough when
both routers cooperate — each side learns the other's public address and they
punch a hole through to each other. It is not enough for **symmetric NAT**,
which gives every destination a different port, and it is useless behind
**carrier-grade NAT**, where the player has no reachable public address at all.
CGNAT is the normal case on mobile networks and the default for entire
countries. For those pairs there is no direct route to discover, and the only
thing that works is bouncing the traffic through a relay both sides *can* reach.

Measured from a browser on 2026-08-26: STUN yields one `host` candidate and one
`srflx` candidate and no `relay`. That is exactly the `ice 2/2` a failing
session reports — both peers gathered everything they could and none of it was
a route to the other. The free public relay this would otherwise have borrowed,
`openrelay.metered.ca`, answered on none of its three ports.

The co-op screen says `no relay configured` while the list is empty, because
the alternative is players discovering it as a connection that works for some
friends and not others.

### Filling it in

See `tools/turn-worker/README.md`. Short version: Cloudflare mints short-lived
credentials from a key that must not ship in the client, so a small worker holds
the key and hands out credentials, and `RELAY_ENDPOINT` in `coop_webrtc.gd`
points at it.

Cloudflare's relay answers on UDP *and* on TCP/TLS over 443, which matters more
than it sounds: a network that blocks UDP outright will still pass TURN over
443, and those are exactly the networks this exists for.

Verify it with `tools/room.sh`, whose diagnostic line ends with candidate counts
in the form `h1s1r1>h1s1r1`. The third number is relay candidates. **If it is
zero the relay is not working**, whatever the configuration says.

