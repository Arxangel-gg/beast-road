# Two-player co-op — design note

Ruled in by the owner on 2026-08-24, reversing the co-op half of GDD §54. The
decision is recorded in `docs/Game_Design_v4.md` §54 and in `CLAUDE.md`; this
file is the design that follows from it, and the thing to read before touching
any netcode.

**Status: design settled, not yet built.** Nothing in `game/` implements this
yet. Sections 1–4 are decided. Section 8 is the build order. Section 9 is what
is deliberately not in scope.

---

## 1. The three decisions the owner made

| Question | Ruling |
|---|---|
| What does player 2 control? | **A second hero.** Both players field their own persistent hero and both fight. |
| How far does it reach? | **Desktop to desktop, for now.** The web build stays single-player. |
| Shared or separate economy? | **One shared pool.** Both players draw on the same Gold, Wood, Food and Stone. |

Each of these narrows the work enormously, and the second one most of all — see
§3.

### Why two heroes fits the rest of the game

It is the shape that agrees with everything else decided this month. Hero level,
attributes and gear persist per account (CLAUDE.md working rule 7), so each
player arrives with a hero they have grown. An asymmetric split where one player
never fights would leave that player's hero permanently at level one, and it
would sit badly against the zero-capital start, which exists precisely to make
fighting the thing that funds the run.

It does **not** reopen §54's cut of "multiple heroes, party roster, or hero
swapping". That line governs how many heroes *one* player commands, and the
answer is still one.

---

## 2. Authority: host-authoritative, not lockstep

**The host simulates. The guest sends input and draws what it is told.**

This is the decision everything else hangs off, so the reasoning is worth
writing down rather than assuming.

Lockstep is superficially attractive here because the game is already
deterministic under a seed, and `tools/seed_reproduction_check.tscn` gates that.
It is still the wrong choice:

- Seeded reproduction was built to make a **replay** reproducible on one machine.
  Keeping two live machines in agreement is a different problem, and the gap
  between them is most of the work.
- Lockstep requires bit-identical float behaviour on both machines for the whole
  simulation. That is a promise nobody should make across different CPUs,
  drivers and builds, and a single divergence desyncs the run silently.
- Lockstep couples frame rate to the slower machine. One player on a weak laptop
  would drag the other's game down.

Host-authoritative costs the guest some input latency on their own hero, which
is the standard trade and is fixable with local prediction later if it is felt.
It cannot desync, because there is only ever one simulation.

### What this means for working rule 6

`RunState` remains the single source of truth. Co-op answers the question rule 6
never had to: **the host's `RunState` is the one that exists.** The guest's copy
is a read-only mirror, fed from the host, and nothing on the guest may write to
it except through a request that the host grants.

That is a strengthening of rule 6, not an exception to it, and it is the reason
the rule survives co-op intact. A guest that writes locally would be a second
source of truth by another name.

---

## 3. Transport: ENet, and what that decision buys

Verified against this exact engine (Godot 4.7.1) rather than recalled:

| Thing | Present |
|---|---|
| `ENetMultiplayerPeer` — `create_server`, `create_client`, `close`, `get_connection_status`, `set_bind_ip` | yes |
| `MultiplayerAPI` implementation | `SceneMultiplayer` |
| Signals — `peer_connected`, `peer_disconnected`, `connected_to_server`, `connection_failed`, `server_disconnected` | yes |
| Authentication hooks — `peer_authenticating`, `peer_authentication_failed` | yes |
| `MultiplayerSpawner`, `MultiplayerSynchronizer`, `SceneReplicationConfig` | yes |
| `WebSocketMultiplayerPeer`, `WebRTCMultiplayerPeer` | present, unused for now |

A server stands up on an ephemeral port and reports connected. The transport is
not a risk.

**ENet does not work in web exports.** That is the whole reason the owner's
second ruling matters: choosing desktop-to-desktop removes the need for a relay
host, a signalling service, and an ongoing bill. The web build keeps working
exactly as it does today, as a single-player game.

The two peer classes needed for a future cross-platform pass already exist in the
engine, so this is a door left open rather than one nailed shut. Should it be
revisited, `WebSocketMultiplayerPeer` behind the same authority model is the
smaller change; the cost is hosting, not architecture.

---

## 4. The seam is EventBus, and it is already in the right place

Working rule 5 — systems talk through `EventBus`, never direct cross-scope
references — turns out to be exactly the shape a network boundary wants. The
signals already describe *facts about the run* rather than node plumbing, which
is what has to cross a wire.

What `EventBus` has never had to carry is **authority and ordering**. A signal
that is fine locally is not automatically fine remotely, and the difference is
worth being precise about:

- **Host-authored facts** — `enemy_died`, `wave_cleared`, `boss_defeated`,
  `lane_pressure_changed`, phase changes, resource changes. These are emitted on
  the host and relayed to the guest, which re-emits them locally so guest-side
  systems keep working unchanged. The guest must never originate one.
- **Guest requests** — build this tower, use this order, blow the horn, ride on.
  These travel guest → host as requests. The host validates against the same
  rules a local click goes through, and the result comes back as a host-authored
  fact. There is no path where the guest's UI decides an outcome.
- **Purely cosmetic signals** — camera shake, hit sparks, sound. These stay local
  and are never relayed. Sending them would double the traffic to reproduce
  something each client can derive from the facts it already has.

The practical consequence: **one relay point, not a hundred call sites.** A thin
layer subscribes to the host-authored set and forwards it; nothing in the
battlefield, town or beast scope learns that a network exists.

### Working rule 8, the raid freeze

The battlefield freezes for a raid and resumes exactly. With two players this
becomes: **the host decides when it freezes, and both observe the same freeze.**
Since the host owns the simulation, "resumes exactly" is already true for the
authoritative copy — the guest simply stops receiving updates and stops drawing
motion.

The genuinely new question was what the *other* player does while one is in a
raid. **Ruled by the owner on 2026-08-25: both players go.**

The alternative — one goes, one holds — was rejected for the reason that made it
look tempting in the first place. The battlefield is frozen while a raid runs, so
the holding player would have a still image to look at. Making that interesting
means letting the battlefield tick during a raid, and that breaks working rule 8
outright.

So: **a raid is entered by either player and both are taken into it.** Concretely:

- Either player may trigger the raid; it is a request to the host like any other,
  and the host validates the charge and the phase exactly as a local trigger does.
- The freeze is host-authored and both clients observe it. Rule 8 is untouched —
  the authoritative battlefield state is suspended as a unit and resumes exactly,
  now with two observers instead of one.
- Both heroes are placed in the raid arena. The raid's own layout already builds
  300 camps and is gated (`tools/raid_layout_check.gd`), so two heroes is a
  spawn-point question rather than a layout one.
- **The extraction windows are shared.** Partial extraction is v3 §14's un-cut
  owner's spec and v4 keeps it, so a raid has two windows plus the chieftain
  climax. With two players those are a joint decision, not a per-player one:
  splitting them would mean one player extracting while the other fights on,
  which is the "one holds" problem moved inside the raid.
- If a player drops mid-raid, §7 applies — the host finishes the raid, the
  guest's banked account progress survives.

---

## 5. Difficulty scaling for two players

The director's threat budget is already data-driven and tuned per act, so
scaling *for* a second player is a tuning exercise rather than a rewrite. Two
things must change and one must not.

**Must change:**

- **Body count**, scaled by player count. Two heroes clear a wave roughly twice
  as fast; a wave sized for one is a formality for two.
- **Kill income**, which follows body count automatically — more bodies, more
  Gold — into a shared pool. This wants watching: two players on a shared pool
  with double the bodies could out-earn the curve, so the per-body rate may need
  to fall in co-op even as the count rises.

**Must not change:**

- **Individual enemy health and damage.** Scaling those instead makes each enemy
  spongier, which is the classic mistake: it does not add pressure, it adds
  duration, and it invalidates the dodge windows the whole combat design is
  built on.

The measurement already exists. `tools/curve_report.tscn` now models hero DPS as
part of capability — added for the zero-capital start, and the same term is what
makes a two-hero capability line meaningful. A co-op pass is that report run with
two heroes and the player-count scalar applied, held against the same peak
pressure the single-player curve reaches (0.63 at wave 51 today).

---

## 6. What actually has to synchronise

Ordered by how much they matter, not by how hard they are.

| Thing | Direction | Notes |
|---|---|---|
| Hero position, facing, animation state | host → both | The guest's own hero is authoritative on the host; prediction is a later refinement, not a launch requirement. |
| Hero input (move, aim, attack, dash, abilities) | guest → host | Small, frequent, unreliable-ordered. |
| Enemy spawn, position, death | host → guest | The bulk of the traffic. `MultiplayerSynchronizer` per enemy is the obvious first attempt; measure before assuming it scales to a 52-body wave. |
| Tower build, upgrade, sell, repair | guest → host as request | Host validates against `RunState.can_build_now()` exactly as a local click does. |
| Resources, all four wallets | host → guest | Shared pool, so this is one authoritative set. |
| Phase, wave number, act, distance | host → guest | Drives both HUDs. |
| Command orders, war horn | guest → host as request | |
| Raid entry and the freeze | host → both | See §4. |
| Loot pickup | host | Guest's hero touching a drop is a host-side collision like any other. |
| Camera, VFX, sound, screen shake | local only | Never relayed. |

---

## 7. Disconnects

- **Guest drops.** The host continues alone. Difficulty rescales down to one
  player at the next wave boundary rather than mid-wave, so the change is never
  the thing that kills the run. The guest may rejoin.
- **Host drops.** The run ends for both. The host's save is written as normal;
  the guest keeps whatever account-level progress they had banked (hero XP,
  gear), because that is host-authored and already relayed. **Host migration is
  out of scope** — it is a large amount of work for a two-player game where one
  player is by definition the owner of the run.
- **Neither player loses account progress to a disconnect.** Hero XP and gear
  earned before the drop are already facts the guest received.

---

## 8. Build order

Each step is meant to be verifiable on its own, and each has a gate. Nothing
here is started yet.

1. **Lobby and transport.** Host, join by address, connection status, clean
   disconnect. Gate: a headless harness stands up a server and a client in one
   process and completes a handshake.
2. **The relay layer.** The host-authored `EventBus` set forwarded and re-emitted
   on the guest, with the guest-request path returning host-authored results.
   Gate: a harness asserts a guest never originates a host-authored signal.
3. **Two heroes.** A second hero in the scene, driven by relayed input. Gate:
   both heroes exist, move independently, and neither can act during a phase the
   other cannot.
4. **Enemies and towers over the wire.** Gate: a wave runs identically on both
   sides; a guest build request is granted, refused, and refused for the right
   reason.
5. **Difficulty scaling.** Gate: `curve_report` with two heroes lands inside the
   same pressure envelope as one.
6. **Disconnect behaviour.** Gate: guest drop leaves a playable single-player
   run; host drop ends and saves cleanly.

---

## 9. Explicitly out of scope

Cut here so it does not creep back in:

- More than two players.
- PvP of any kind — still cut by §54, and the owner's ruling did not touch it.
- Daily online challenges — still cut.
- Host migration.
- Cross-platform with the web build, until and unless the hosting question is
  answered.
- Matchmaking, lobbies-as-a-service, friend lists, invites. Join by address.
- Voice chat.
- Separate per-player economies, which the owner ruled against.
