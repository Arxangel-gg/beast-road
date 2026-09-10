# Beast Road — handoff

Written 2026-09-10, at the end of a long Claude Code session, for a fresh
session picking the project up cold.

**Read `CLAUDE.md` first, not this.** That file is the project's working rules
and its record of owner decisions, it is checked into the repo, and it is
authoritative. This document is a snapshot of *where things stand* and what a
new session would otherwise have to rediscover. Where the two disagree,
`CLAUDE.md` wins and this file is stale.

**Verify before you trust.** Every claim here was true when written and some of
it is judgement. The project has already been bitten once by `CLAUDE.md` naming
a value a gate forbids outright, and the lesson is in the memory file
`claude-md-can-be-stale-check-it-against-the-gate`. Check the code.

---

## 1. Current project state

**Beast Road is a 2D action tower-defense roguelite in Godot 4.7.1.** One hero
defends four lanes around a city riding on the back of a walking beast. Windows,
web and Android builds ship from GitHub Actions.

**It is a finished, released, playable game**, not a prototype. v0.10.1 is
published, downloadable, and has been smoke-tested by downloading the release
zip and playing it. The loop closes: splash → menu → run → all scopes → three
acts → a final ascent → win or lose → payout → menu.

**The numbers, as of this writing:**

| | |
|---|---|
| v4 conformance audit | 46 of 46 automatable checks (5 rows need a human) |
| Guard gates | 76, green locally and on CI |
| Release gates | 57, green |
| Manifest assets | 1678, all present, all real art, no placeholders |
| Latest release | v0.10.1 |

### Implemented and working

Towers with four elements and fusion; enemies with affixes, morale and
formations-by-champion; waves and a wave director; bosses and a boss director;
the hero with melee, ranged weapons, ammunition, dash and spells; disciplines
(three trees with depth gating, plus synergies); relics and boss cores; the
city with buildings and a Town Hall; raids with partial extraction; crossroads
with roads, voted difficulty and per-road relic rewards; the journey across
three acts and a final ascent; weather, day/night, wildlife with an ecology and
Spirit Companions with personalities; travelling merchants who settle; captives
and the Oathbound framing; blueprints and crafting; traps and barricades; the
stash, Marks, Shards and gear across eight slots and five rarities; the codex,
the chronicle and objectives; a Supabase leaderboard; two-player cross-platform
co-op over WebRTC with a lobby, local beacon and connect codes; save migration;
key rebinding; colourblind modes; touch/mobile layout; a launcher.

**Added in this session:** player-to-player trading, the Long Ledger
marketplace, and Road Omens. See §2.

### Partially implemented

- **Discipline effects: 7 of 24 are real.** `discipline_effects.gd` holds
  `IMPLEMENTED` (7 keys) and `DECLARED_ONLY` (17). Every one of the seventeen
  has a sentence in its `.tres` promising a behaviour and an `effect_value`
  sized for it, and **nothing reads them**. These are not design questions;
  they are unwritten implementations. This is the single largest honest gap in
  the game and `discipline_check` enforces that a key sits in exactly one list,
  so nothing new can quietly join the inert pile.
- **The Long Ledger's price feed** works offline and has never talked to a live
  table, because the table does not exist yet. `docs/EXCHANGE.md` has the SQL.
  The offline path is the one every gate exercises and the one most players will
  be on.

### Not implemented

- A true player-to-player order book (offers that outlive a session with real
  custody). Blocked on the same thing it has always been blocked on: real
  accounts and server-side logic. See §5.
- Everything in `docs/IDEAS_REVIEW_2026-09-10.md` under "worth building next"
  and "refuse".

### The gameplay loop

Pick a tier and a seed → the beast walks → waves arrive down one to four roads →
build and upgrade towers during Preparation only → fight as the hero during the
wave → reach a crossroad, choose a road and its difficulty, draft a discipline
node → optionally spend a raid charge to freeze the battlefield and hit an
off-road camp → an act boss → read a portent → repeat for three acts → the
final ascent and the Chainmaker → payout in Marks, Shards, gear, Tools and
progress → back to the menu, where the stash, the Ledger, the codex and the
chronicle live.

---

## 2. Work completed in this session

In commit order, most recent last.

1. **Raid enemies navigate to the player.** `EnemyField.objective_position` is
   a virtual; `RaidArena` overrides it to the nearest hero. `enemy.gd` had three
   `town_position()` fallbacks that made every raid a march to the map centre.
2. **The co-op crossroad deadlock.** `_choose` set `_resolving`, which gated
   `cast_vote`, `_tick_vote` and `_resolve_votes` — so a host voting locked the
   run at one of two votes. Extracted `host_vote`, which uses `_await_votes`
   (UI dim only). Testable now because `_choose` branches on a live peer.
3. **The VFX world was never reclaimed after a raid.** One root cause behind
   three separate reports: missing new VFX, and weapon swings drawing nothing
   after returning from a raid. Each scope now calls `claim_effects()` on
   activation.
4. **Arrows hit without hurting.** `hero_arrow.launch` ignored the hero's
   `damage_multiplier()`. Two probe attempts were wrong before the real cause
   was found; the report was never reproduced as originally described.
5. **Healing orbs and supply crates**, tuned to the dropping enemy's rarity and
   power, bounded so they cannot pay for a mistake. They ride the existing
   `LootDrop` currency path, so co-op replication came free.
6. **Healing wells as towers.** `TowerData.well_heal` / `is_well()`;
   `tower.gd` pours into the thirstiest hero in range.
7. **Two-player trading**, RuneScape-style: invite, offer, accept, a second
   confirmation screen, and any change withdrawing both acceptances.
8. **The trade window shows the gear** — art, rarity, slot, level, attribute,
   Marks, KEPT — with per-side totals.
9. **The free-sword bug.** `_seed_starting_gear`'s flag was not declared in the
   `MetaState.settings` defaults, and `_read_settings` keeps only declared keys —
   so **every launch granted another starting weapon**. Third time that
   dictionary has caused this. New gate `save_round_trip_check` asserts the
   general form. Found by diffing the owner's save either side of a tool run.
10. **`save_guard_check` now scans instead of listing.** Its hand-kept list of
    gates that edit `MetaState` had rotted; **24 tools were writing to the
    player's real save**. All hold saves now. `codex_check` is the one exemption
    and restores the file instead.
11. **`Stash.new_uid` was 62 bits and the save is JSON**, which has no integers:
    394 of 400 names did not survive a round trip. 52 bits now, gated.
12. **The Long Ledger** — the grand exchange. See §5 and `docs/EXCHANGE.md`.
13. **Road Omens** — bane/boon portents read between acts. See §5.
14. **`GearRow`**, so a piece looks identical in the stash, the trade window and
    the Ledger.
15. **Both trade and Ledger windows fit the display they are on.**
    `menu_layout_check` caught the Ledger overflowing a 430-tall phone.

**Two faults my own gates caught before they shipped**, worth knowing because
they show what these gates are for: an omen authored with its halves reversed
(charging nothing), and an omen offer rolled host-only on the unseeded global
RNG (which would have left a guest playing without its partner's modifiers).
The first version of the test for the second one *passed with the bug in place*,
because `set_seed` seeds the global stream too.

---

## 3. In-progress work

**One uncommitted change at the time of writing:** `game/scenes/ui/town_panel.gd`
adds the Long Ledger to the Hero Mansion's Gear section, beside "Open the stash".
It compiles, boots clean and passes `menu_layout_check`. It is being committed
with the release below; if `git status` shows it modified, it did not land.

**Nothing else is half-done.** Every system listed in §2 is complete, gated and
committed.

### Dangerous to redo

- **Do not rebuild anything in `docs/IDEAS_REVIEW_2026-09-10.md` §1.** A third
  of the owner's brainstorm documents describe systems this game already has
  under other names — crossroads, affixes, seeds, the chronicle, day/night,
  traps, merchants, raids-as-creep-camps. A session handed those documents cold
  will build them a second time.
- **Do not "fix" `Balance.STARTING_GOLD` to a non-zero value.** It is 0 by owner
  decision, three times ruled on, and `balance_test._test_opening_envelope`
  forbids otherwise.
- **Do not put items in the Ledger's Supabase table.** See §5.
- **Do not add feature flags to preserve v3 behaviour.** `CLAUDE.md` §"The three
  escape hatches" explains why there are exactly three.

---

## 4. Development backlog

Honest categories. **Most of the brainstormed material is not a 1.0
requirement**, and saying so is the point of this section.

### BLOCKER / required for 1.0

Nothing is currently blocking. The game builds, ships, runs and completes.

### MUST HAVE for 1.0

- **The 17 inert discipline effects.** Every one is described to the player in
  its own `.tres` and does nothing. This is a promise the game makes and does not
  keep, seventeen times, and it is the clearest 1.0 obligation on the list.

### STRONG CANDIDATE for 1.0

- **The Last Stand.** The city about to fall triggers thirty seconds rather than
  a loss screen. Cheap; converts the worst moment into the memorable one.
- **Perfect-wave momentum.** A zero-damage wave builds a meter that breaks on a
  hit. One counter and one HUD element; restores tension while strong.
- **Camp difficulty signalling for raids.** Raids already are the "leave the line
  for a prize" system; what they lack is a readable "too big for you yet" before
  committing.
- **Create the `exchange_sales` Supabase table**, so the Ledger's guide prices
  become a real player economy rather than the authored standing rate. SQL is in
  `docs/EXCHANGE.md`. Owner action, not a code change.

### POLISH

- Controller parity, 60 FPS at 1920×1080 on a minimum-spec machine, and night
  playable at minimum brightness. **All three are audit rows that need a human**
  and none has been verified on hardware of that class. `MINIMUM_SPEC.md`'s
  targets are explicitly unverified.
- 112 GDScript lines with flattened line continuations (see §10).
- Conditional NPC lines that remember how a previous run ended.
- Treasure creatures; rare "what was *that*" background events.

### POST-LAUNCH

- Elemental reactions between towers. **The highest-leverage idea available**,
  and genuinely not small: a reaction table, a gate proving every pair is
  reachable and none strictly best, and VFX for each. Season 1's headline.
- Enemy formations drawn as squads by the spawner.
- Prestige cosmetics, tower skins, banners, titles.
- A true player-to-player order book, if accounts ever exist.

### EXPERIMENTAL / brainstorming — not approved

Everything in `docs/IDEAS_REVIEW_2026-09-10.md` §4, with a reason per item:
Road Cards as a second upgrade layer (disciplines already are that), hero
augments (that is what synergies are), build evolutions (that is fusion),
outposts and faction territory (an RTS layer), Pack-a-Punch (a third power
scale), safe rooms and mystery boxes (the grammar of a map you hold, and this
map walks), ultimate abilities and hero ability branches (overlaps disciplines).

---

## 5. Design decisions already made

`CLAUDE.md` holds these in full with dates and reasoning. This is the index, so
a new session knows what *not* to reopen.

### CONFIRMED — do not reopen without the owner

| Decision | Date |
|---|---|
| Mid-combat tower placement is locked to Preparation | 2026-08-13 |
| Oathbound / ransom / memorial framing; no enslavement language | 2026-08-20 |
| Hero level, attributes and loot persist (re-cut of v4 §974), capped | 2026-08-20 |
| Two-player co-op is in scope; PvP and bigger parties stay cut | 2026-08-24 |
| The run opens with **zero** build capital | 2026-08-27 |
| Ranged weapons, ammunition, blueprints and crafting are in scope | 2026-08-31 |
| Gear is the reason to replay; farm it | 2026-09-01 |
| Wildlife Spirit Companions persist; one active slot; personalities | 2026-09-01 |
| Enemies have morale; it changes a fight's shape, never its size | 2026-09-02 |
| Discipline trees have paths (depth buys access, never power) | 2026-09-09 |
| Discipline synergies (stage two) — none may raise a number | 2026-09-10 |
| Two players may trade gear; **gear is never created** | 2026-09-10 |
| The Long Ledger: **prices are shared, custody is not** | 2026-09-10 |
| Road Omens: run-scoped, stacking, may only move existing modifiers | 2026-09-10 |

### The bounds that matter most

- **Working rule 7.** `MetaState` persists only what is sanctioned. Hero power
  is capped. Marks and Shards do not exchange with run currencies.
- **Gear is never created.** Trading conserves; the Ledger escrows; buying is
  always dearer than vendoring so Marks cannot be laundered.
- **Prices are shared, custody is not.** There is no account server. The
  Supabase project answers to an anonymous key every copy of the game carries.
  A forged leaderboard row is graffiti; a forged item ends the loot economy.
  **Never put items in that table.**
- **Depth buys access, never power** (disciplines). **No trait is a damage
  upgrade** (spirits). **Morale never changes a wave's size.**

### LIKELY / preferred

- The finishing month framing: ship 1.0, then Season 1. This is the owner's own
  advisor's recommendation and it is right.
- Omens as the shape future run-modifier content takes, rather than a second
  card pool.

### STILL UNDECIDED — owner's call

- **Discipline stage three:** whether the per-road draft should be replaced by
  freely spending skill points. Asked for, never decided, never built.
- Whether players should be able to open a road *early* for a reward. Compatible
  with the design, but it moves the wave-pressure curve three acts are tuned
  against, so it is a balance project.
- Whether omens deserve icons. They currently have none, deliberately — see
  `omen_data.gd`.

---

## 6. Recent system ideas — status

| Idea | Status |
|---|---|
| Road Omens (bane/boon) | **BUILT.** `data/omens/`, 10 authored, `omen_check` |
| Enemy affixes | **BUILT**, 8 of them, long before this session |
| Optional camps / objectives | **BUILT** as raids and `data/objectives/` |
| Mystery cache / mystery box | Refused — see §4 |
| Road Cards | Refused — disciplines are the card draft |
| Major augments / quest augments | Refused as a new system; grow synergies |
| Build evolutions | Refused — that is fusion, and fusion is v4 LOCKED |
| Elemental synergies between towers | **Recommended, post-launch.** Highest leverage on the list |
| Expanding / unlockable routes, spawn manipulation | Deferred; it is a balance project |
| Weapon mastery | Not assessed; overlaps gear levels and rarities |
| Settlement specialists | Overlaps merchants-who-settle and captives |
| Rare world events and secrets | Polish; cheap and high-delight |
| Road Rifts / corruption altars | Not assessed |
| World / frontier progression | Overlaps campaign tiers |

Full reasoning per item: `docs/IDEAS_REVIEW_2026-09-10.md`.

---

## 7. Architecture

### The shape

- **Autoloads** are the spine: `Balance` (every tuning constant), `EventBus`
  (every cross-system signal), `ContentDB` (all `.tres` loaded from `data/`),
  `MetaState` (the save), `RunState` (the single source of truth for a run),
  `Modifiers` (relics, boss cores and omens flattened into one table),
  `GameDirector`, `Coop`, `TradeBooth`, `Exchange`, plus audio, VFX and display.
- **Systems** (`scripts/systems/`) are mostly `RefCounted` classes with no
  autoload reach, so gates can drive them without a scene. `TradeSession`,
  `ExchangeMarket`, `ExchangeOrder`, `Stash`, `SpiritBond`, `Score` and
  `CoopRelay` are the important ones.
- **Resources** (`scripts/resources/`) define content types; every one is
  data-driven and **adding content means adding a file** (working rule 3).
- **Scenes** are the scopes: battlefield, town, raid, crossroad, menu.

### The rules that keep it together

1. **Systems talk through `EventBus`.** The battlefield holds no reference to
   the city.
2. **`RunState` is the only source of truth for a run.** Nothing caches run data.
3. **Every sprite path derives from a resource `id`.** Replacing placeholder art
   is overwriting a file — but you must run `--import` or the runtime keeps
   drawing the old texture, silently.
4. **Co-op is host-authoritative.** `CoopRelay` carries Requests (guest→host),
   Facts (host→all) and Refusals. **Where possible, derive rather than relay:**
   the relic offer and the omen offer are both computed independently on each
   machine from the run's seeded stream. Adding a fact is adding a thing that
   can be subtly wrong.

### Brittle or worth watching

- **`hud.gd` is over 2500 lines.** It works and is gated, but it is the biggest
  single file and the least pleasant to change.
- **`coop_relay.gd` has ~50 fact types and ~23 request types**, hand-numbered.
  The numbers are wire format: **never renumber an existing one**.
- **`MetaState.settings` silently drops undeclared keys on load.** This has
  caused three separate shipped bugs. `save_round_trip_check` now catches it,
  but the shape is still a trap: a new setting must be declared in the defaults
  dictionary or it will appear to save and vanish.
- **Godot enums do not cross class boundaries cleanly.** An enum declared in one
  class, used as a variable's type in another, is not the same type to the
  checker. `ExchangeMarket.fill_rate` takes an `int` for exactly this reason.

---

## 8. Save and persistence

- One file: `user://beast_road_save.json`, `SAVE_VERSION = 7`, migratable from
  1–6. An unreadable save is **copied to a versioned backup before** the account
  starts fresh, and an existing backup is never overwritten.
- **`res://tools/save_backup_check.tscn` is deliberately not in CI** (a
  discarded save legitimately warns, and the release gate fails on warnings).
  **Run it by hand before any release that changes `SAVE_VERSION`.**
- **Persisted:** unlocked ids, run statistics, settings, Tools, Sigil ranks, the
  Treasury cache, hero level/experience/attributes/tier cleared, the stash,
  Marks, Shards, spirits, the leaderboard block, and **the Ledger's escrowed
  orders**. That last one is the newest and the only one holding gear outside
  the stash — see `ExchangeOrder` for why.
- **Not persisted, by design:** relics, tower levels, run currencies, building
  tiers, Oathbound leaders, omens.
- **Risk:** JSON has no integers. Anything above 2^53 is silently rounded on
  load. `Stash.new_uid` is 52 bits for this reason and `trade_check` round-trips
  400 of them. Any new identifier must respect it.
- **Risk:** any gate or tool that edits `MetaState` must call
  `MetaState.hold_saves()`. `save_guard_check` scans `res://tools/` and enforces
  it, with one documented exemption.

---

## 9. Art and PixelLab

- **1678 manifest assets, all present, all real.** `run_tool.gd -- report`
  reports zero placeholders and zero orphans, and it runs in CI.
- **Conventions:** every path derives from a resource `id`
  (`TowerData id = "ember_spire"` → `art/towers/tower_ember_spire.png`).
  Placeholders sit at the exact final path and pixel dimensions from
  `docs/ASSET_MANIFEST.md`, with pixel (0,0) set to `#FF00FF` as the marker.
- **Adding an asset requirement means adding a manifest row and generating its
  placeholder in the same change.** Naming an asset in prose with backticks in
  the manifest has failed a release once, because backticks are read as a
  listing.
- **After overwriting any PNG, run `--import`.** The runtime never re-imports;
  every screenshot you take is of the previous version until you do.
- **The art is painterly, not pixel art.** A pixel-art tool means restyling all
  of it. PixelLab is used for VFX sheets and specific sprites, not a global
  restyle.
- **Remaining PixelLab budget was around 96 generations** at the time of
  writing, resetting 2026-09-18. Omens deliberately have no icons partly for
  this reason.

---

## 10. Known bugs, debt and risks

**Open and unexplained:**

- **`menu_layout_check` has SIGSEGV'd and timed out on Linux CI**, three times
  in one day, on commits touching no menu code. Bare re-runs pass. Recorded as
  *a timeout first*, with the hypothesis that it sits near the 240s ceiling.
  **The experiment to confirm that has not been run.**

**Known and bounded:**

- **17 inert discipline effects** (§1, §4).
- **112 GDScript lines have flattened line continuations** — a `\` + newline
  replaced by two literal tabs mid-line, damage from shell heredocs in past
  agent sessions. It all compiles; it reads badly. Scan for mid-line `\t\t`
  outside comments and strings.
- **Three audit rows need a human and none has been verified on hardware**:
  controller parity, 60 FPS at 1920×1080 on minimum spec, and night at minimum
  brightness.
- **The Ledger's price feed has never talked to a live table.** Only the offline
  path has ever run.

**Lessons that have already cost time** (full versions in the memory directory):

- A passing layout gate cannot see wrong content; a passing art gate cannot see
  quality. Look at screenshots.
- Godot's `--quit` check does not mean scripts compile.
- Derive the local sweep from CI; a hand-kept gate list rots. Three publishes
  died on gates a hand list never ran.
- Random events make layout gates flaky; force probabilities to 1.0 to reproduce.
- HTTP 200 is not evidence a game runs.

---

## 11. Git

- Branch **`main`**, and the project releases from tags on it.
- Last commit at the time of writing: `492b5dd` "The road announces itself, and
  the ideas documents are triaged".
- **`v3-final` (at `v0.3.7`) is a photograph of the last working v3 game.**
  Never commit to it.
- `game/addons/webrtc_native/lib/` can accumulate `~`-prefixed DLL copies when
  the Windows editor cannot replace a file it has open. They are gitignored now;
  if one appears, it is not a real file.
- **Do not commit or discard anything on the owner's behalf without asking.**

---

## 12. Recommended next steps for the new session

1. **Read `CLAUDE.md` in full.** Then `docs/Game_Design_v4.md` §§52–55, then
   this file, then `docs/IDEAS_REVIEW_2026-09-10.md` §1 so you do not rebuild
   what exists.
2. **Verify rather than trust.** Run `run_tool.gd -- audit`, `-- report`, and
   both local sweeps (guard and release). Confirm the numbers in §1 still hold.
   If they do not, this document is stale and the code is right.
3. **Do the release-readiness audit the owner is asking for**, without modifying
   anything: blockers, must-have, polish, post-launch, and specifically *what
   will become painful or expensive in the final month if not fixed now*.
4. **Then, if implementing, start with the 17 inert discipline effects.** It is
   the one item in the backlog that is a promise the game currently breaks.
5. **Reproduce the `menu_layout_check` Linux failure before touching it.** The
   hypothesis is written down and unrun.

---

## 13. Source material

| Path | What it is |
|---|---|
| `CLAUDE.md` | **Authoritative working rules and owner decisions.** Read first |
| `docs/Game_Design_v4.md` | The design spec (`GDD_Master.docx` is the signed copy) |
| `docs/Game_Design_v3.md` | What the shipping code was originally built to |
| `docs/Game_Design_v2.md` | Argues well for scope discipline. Read before cutting |
| `docs/V4_CONFORMANCE.md` | v4's LOCKED decisions as machine-checked rows |
| `docs/IDEAS_REVIEW_2026-09-10.md` | **The triage of both brainstorm documents** |
| `docs/ChatGPT_More_Ideas.md` | The owner's first ChatGPT brainstorm (raw) |
| `docs/ChatGPT_More_Ideas_2.md` | The owner's second, larger brainstorm (raw) |
| `docs/ChatGPT_TransitionHandoff` | The owner's model-strategy conversation and the spec this document answers |
| `docs/EXCHANGE.md` | The Long Ledger: table SQL, constants, what each decides |
| `docs/RELEASING.md` | How a build is published |
| `docs/ASSET_MANIFEST.md` | Every asset, its path and its pixel dimensions |
| `docs/ROAD_TO_RELEASE.md` | Release history and locked-in values |
| `docs/MINIMUM_SPEC.md` | Provisional performance targets — **unverified** |
| `docs/COOP_DESIGN.md`, `COOP_WEBRTC.md`, `MATCHMAKING.md` | Co-op architecture |
| `docs/LEADERBOARD.md` | Supabase operations |
| `References/` | The owner's visual references, one per scope. The target |
| `C:\Users\Hamed\.claude\projects\E--Arxangel-GameDev-BeastRoad\memory\` | Durable lessons from past sessions, indexed by `MEMORY.md` |
