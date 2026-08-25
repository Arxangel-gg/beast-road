# Two-player co-op — design note

Ruled in by the owner on 2026-08-24, reversing the co-op half of GDD §54. The
decision is recorded in `docs/Game_Design_v4.md` §54 and in `CLAUDE.md`; this
file is the design that follows from it, and the thing to read before touching
any netcode.

**Status: design settled; all six steps built.** Sections 1–4 are decided.
Section 8 is the build order and records what is done. Section 9 is what is
deliberately not in scope.

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

Each step is meant to be verifiable on its own, and each has a gate.

1. ~~**Lobby and transport.**~~ **Done 2026-08-25.** `game/autoload/Coop.gd`
   owns the peer and the session state machine — `host`, `join`, `leave`, and
   the one honest answer to "am I the host". `tools/coop_check.tscn` stands a
   host and a guest up in one process over a real loopback socket and is in
   `guard.yml`.

   Three things worth carrying forward from building it:

   - **`Coop` reads its own `multiplayer` property**, never
     `get_tree().get_multiplayer()`. A `MultiplayerAPI` is registered against a
     subtree path, so a Coop node parented under a custom-API subtree picks that
     API up. That single choice is why co-op can be tested on a push instead of
     needing two machines — keep it.
   - **A subtree's API is not polled by the loop that drives the default one.**
     The harness pumps both by hand each frame. Anything else standing up a
     non-default API has to do the same or the handshake simply never advances.
   - **`is_host()` answers true in single player**, deliberately. A lone player
     is the authority over their own run, so every downstream "may I do this"
     check reads identically in both modes and the single-player path cannot rot
     from being the branch nobody exercises. `is_networked()` is the question to
     ask when the answer really is "is anyone else here", and `player_count()`
     is built on whether a partner is *present* rather than on session state —
     a host listening alone still balances for one.

   New `EventBus` signals, per CLAUDE.md §6: `coop_state_changed(state: int)`,
   `coop_partner_joined(peer_id: int)`, `coop_partner_left(peer_id: int)`,
   `coop_failed(reason: String)`. New constants: `Balance.COOP_PORT`,
   `COOP_MAX_PLAYERS`, `COOP_MAX_GUESTS`, `COOP_CONNECT_TIMEOUT`.

   **Not built in this step, on purpose:** there is no lobby *screen* yet. The
   session is driveable from code and gated; putting a front end on it belongs
   with the UI pass, and building one now would mean building it twice.
2. ~~**The relay layer.**~~ **Done 2026-08-25.**
   `game/scripts/systems/coop_relay.gd` is the one place a message crosses the
   wire, built as a child of `Coop` so it is guaranteed to share the session's
   `MultiplayerAPI`. `coop_check.tscn` now covers it.

   The three-way traffic split from §4 is implemented as written: host-authored
   facts forwarded and re-emitted on the guest's own bus, guest requests
   travelling the other way as *requests*, and cosmetic signals not relayed at
   all. Cosmetic isolation is enforced by **omission** from the relay's binding
   table — there is no per-call-site decision anywhere to get wrong.

   - **Raw packets, not `@rpc`.** An `@rpc` call resolves by node path and needs
     the sender and receiver at the same path in their trees. The harness
     necessarily has a host and a guest at different paths in one tree, so a
     path-bound relay could not be tested in process — throwing away the one
     property step 1 was built to have. `SceneMultiplayer.send_bytes` is
     path-independent, verified against 4.7.1.
   - **`allow_object_decoding` is set false explicitly**, and `bytes_to_var` is
     left at its non-object default. A packet is data; letting one name a class
     to instantiate turns a corrupt or hostile message into code execution.
   - **The bus is injected, not reached for.** Two machines have two event
     buses. A harness simulating both in one process would otherwise share the
     single autoload, so the host's own emissions would arrive at the guest's
     relay without crossing a wire — echoing forever and tripping the guard on
     local traffic. A test that cannot tell the two machines apart cannot test
     the thing that separates them.
   - **The guard is the point.** A host-authored fact originating on a guest is
     caught at the moment of emission and named. It cannot be enforced by review:
     it only has to be broken once, in one system, for two machines to start
     disagreeing — and the desync would be debugged nowhere near the cause. It
     records rather than throws, because crashing a run in front of two players
     is worse than a loud log and a gate that fails on the next push.

   New `EventBus` signal, per CLAUDE.md §6:
   `coop_request_received(kind: int, args: Array, from_peer: int)` — host-side
   only, and a *request* rather than a fact.

   **Note for step 3 onward:** a new `class_name` script is not visible to
   autoloads until Godot has re-registered its global class cache
   (`--headless --editor --path game --quit`). `guard.yml` already does this as
   "Register gameplay resource classes"; a local run needs it by hand after
   adding one, or the failure reads as "type not found" in unrelated files.
3. ~~**Two heroes.**~~ **Done 2026-08-25.** `tools/coop_heroes_check.tscn`, in
   `guard.yml`. Separate from `coop_check` on purpose: that one is about the wire
   and needs no game, this one needs a real Run and has nothing to say about
   sockets.

   **The hero no longer reads `Input`.** It read it directly in five places —
   attack, dash, four spell slots, movement and aim — which is exactly right for
   one hero on one machine and wrong for two. The alternative was an "is this
   hero mine" test at each site: five decisions, five places to forget, and a
   partner's hero that twitches whenever the local player walks. Instead a hero
   asks its own `HeroInput` and never learns which kind it is.

   - `LocalHeroInput` holds the device-juggling moved out of `hero.gd` intact —
     stick over keys, touch over pad, both falling back to the previous aim. A
     player who has never heard of co-op must not be able to tell.
   - `RemoteHeroInput` holds the last snapshot. **Sticks are levels, buttons are
     edges**, and they are handled differently for that reason: a newer move
     vector simply replaces the older one, while presses are *latched* until
     read. Packets and physics frames do not line up, and assigning the button
     mask instead of OR-ing it drops the press that arrives in the gap — an
     attack that never comes out, every few seconds, for no visible reason.
   - The partner's hero is an ordinary `hero.tscn`. It walks, swings, dashes, is
     knocked about by the beast's step and dies through the same code, because a
     second implementation is a second place for bugs and only one of the two
     would ever be play-tested.

   **Hero state needed no new send path.** `CoopHeroes` emits `coop_hero_state`
   on its own bus and the relay forwards it exactly as it forwards a death. The
   authority guard therefore covers hero positions for free: a guest trying to
   author one is caught by the same check that catches a guest inventing a kill.

   **What is deliberately not solved yet.** The guest's own hero keeps simulating
   locally between state packets rather than freezing until the next one. That is
   naive prediction and it will visibly correct under latency. §2 already calls
   proper prediction a later refinement, and a hero that only moves when a packet
   arrives is worse than one that occasionally snaps.

   `battlefield.hero` still means *the hero this player drives* — the camera
   target, the HUD's subject, the one the damage vignette follows. Renaming it to
   mean "either hero" would have been the change that quietly broke all of those.
   `partner_hero()` and `heroes()` are the additions.
4. ~~**Enemies and towers over the wire.**~~ **Done 2026-08-25.**
   `scripts/systems/coop_world.gd`, gated by `coop_world_check.tscn` (meaning)
   and `coop_check.tscn` (wire). Two very different problems wearing one name:

   **Towers were almost free, and that is a dividend rather than luck.**
   `battlefield.gd` already rebuilt every tower node from `RunState` whenever
   `tower_changed` fired — building, selling, upgrading and a refunded fusion all
   arrive through that one signal. So a guest told "a level 2 Ember Spire stands
   at (3, 4)" writes it and the tower appears, with no tower-specific network
   code at all. `coop_world_check` asserts that property directly, because if it
   ever stops being true, towers need real replication and this needs rewriting
   rather than patching.

   **Enemies were not.** Fifty of them, moving every frame, with identity that
   has to survive a wire. They are mirrored as puppets — spawned on
   announcement, moved in a periodic batch, removed on command.

   - **Identity is an assigned integer, not a node name.** Names are unique
     within a parent, not across a wire, and Godot renames on collision — so two
     machines can disagree about which enemy is which without either being wrong
     locally.
   - **A puppet decides nothing.** No targeting, walking, striking, damage or
     payout. Everything else — sprite, facing, walk cycle, tint — runs through
     the same code as a real enemy, which is why a guest's field looks alive
     rather than like a slideshow. Its motion is *derived* from the positions it
     is sent, so facing uses the same `_motion` that was fixed for walking
     backwards rather than a second rule.
   - **Removals are computed by the host** comparing its own view against itself,
     never inferred by the guest from a missing batch entry — a guest deleting
     anything absent from a packet would empty the field the first time one
     arrived late. This also keeps `Enemy` free of any knowledge that a network
     exists, and catches every way an enemy can leave at once.
   - **A refusal is addressed, not broadcast.** It is the one message aimed at a
     person rather than describing the world; on both screens it would read as
     the game refusing them both. A grant needs no reply at all — it produces
     facts, and those are already on their way.

   **What the gate deliberately does not claim.** The build order asked for "a
   wave runs identically on both sides", and a harness in one process cannot
   honestly assert that: there is one `RunState` autoload per process, so a
   simulated guest shares the host's run state and the two cannot meaningfully
   disagree. What is gated instead is every piece identity rests on — a puppet
   deciding nothing, taking position and health from what it is told, leaving
   without paying, and a build request judged by the same `try_build` a local
   click uses. Two machines agreeing follows from those plus the wire. The
   remainder is a two-machine play test, which is on the road list.
5. ~~**Difficulty scaling.**~~ **Done 2026-08-25, and the naive answer was
   wrong.** Body count is the only thing the player count touches, exactly as §5
   required. `balance_test` gates *which knob* - that bodies scale and that
   health, damage and speed do not - because that part is not judgement. Whether
   the resulting curve feels right is pacing, and `curve_report` says in its own
   header that it is a report and never a gate.

   Measured with `curve_report -- --players=2` rather than reasoned about:

   | extra bodies per player | 1.00 | 0.70 | 0.60 | 0.50 | 0.30 | 0.00 |
   |---|---|---|---|---|---|---|
   | two-player peak pressure | 0.90 | 0.77 | 0.74 | 0.71 | 0.70 | 0.60 |

   One player peaks at 0.63. **Doubling the bodies made co-op 43% harder, not
   equal**, and the reason matters more than the number: the late game is
   *tower* dominated, so a second hero barely moves late capability - at zero
   extra bodies two players still measure 0.60 against a solo 0.63. Bodies scale
   threat linearly while a second player scales capability much less than
   linearly, because the tower count is capped and upgrades escalate.

   Settled at **0.5**, so two players face 1.5x the bodies and measure ~0.71.
   That sits above the solo curve on purpose: the model is blind to the biggest
   thing a second player brings - two lanes covered *at once*, where solo play
   must choose - and equally blind to latency and coordination costs. Those
   partly cancel, and a headless model cannot settle the balance of them.
   **Provisional until the two-machine play test.**

6. ~~**Disconnect behaviour.**~~ **Done 2026-08-25.**

   **Guest drops:** the host plays on. Difficulty rescales at the next wave
   rather than mid-wave, and that needed no code - `_wave_size` is only consulted
   when a wave begins, so a wave already walking is never resized under the
   survivor. `player_count()` keys off whether a partner is *present*, so it
   falls back on its own.

   **Host drops:** the guest's run is abandoned - **not** recorded as a defeat.
   `end_run(false)` would write a loss, raise the defeat screen and offer a score
   for a run nobody finished. The player did not lose; the session went away.

   The layering here was got wrong first and is worth recording. `Coop` initially
   called `goto_menu()` itself, which is the network layer driving navigation -
   against working rule 5. It announced itself immediately: it replaced the scene
   the co-op harness was running in, mid-test, and ended in a page of engine
   shutdown errors. `Coop` now reports the loss and `GameDirector` decides what
   it means. A layer that can delete its own caller belongs on its own side of
   the seam, and a test that has to destroy itself to run is telling you where
   that seam should be.
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

---

## 10. Open, and found while building

**Hero XP is per-account, but `RunState` holds one hero's.** Each player brings
their own persistent hero (§1), and hero level, XP and attributes persist per
account (CLAUDE.md working rule 7). But XP is granted in `Enemy._on_died`, which
runs only on the host, into the one `RunState.hero_xp` a run has.

So today a guest fights a whole run and their hero learns nothing from it. That
is not a bug in anything built here - it is a question the design did not ask,
and inventing an answer inside step 4 would have buried it. The shapes available:

- **Each player earns their own**, which means run-scoped hero state stops being
  a single field and becomes per-player. Most correct, most invasive, and it
  touches working rule 6's "single source of truth" in a way worth thinking
  about rather than patching.
- **Both earn the same**, credited to whoever is connected. Cheap, and it makes
  a guest's progression depend on the host finishing.
- **The guest earns nothing**, which is what happens now and is indefensible as
  a shipped answer, given that a persistent hero is the reason two heroes was
  the right call in the first place.

Needs an owner ruling before co-op is playable as more than a demo.
- Separate per-player economies, which the owner ruled against.
