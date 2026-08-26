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
2. The host creates a WebRTC offer and posts it to the room.
3. The guest enters the room by code, reads the offer, and posts an answer.
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
