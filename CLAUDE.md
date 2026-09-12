# CLAUDE.md — WILDERHOLD (formerly Beast Road)

Project instructions. Read this at the start of every session, before touching
any code.

---

## 1. What this project is

A 2D action tower-defense roguelite in Godot 4.7.1. One hero defends four
lanes around a city riding on the back of a walking beast.

**The design spec is `docs/GDD_Master.docx` (v4.0).** It is authoritative. This
file contains working rules only — it does not restate the design. When the
two conflict, the GDD wins for *what* to build and this file wins for *how*.

`docs/Game_Design_v4.md` is the same document in markdown and is the one to
read — a `.docx` is awkward to grep. If the two ever disagree, the `.docx` is
the signed copy.

`docs/V4_CONFORMANCE.md` turns v4's LOCKED decisions into machine-checked rows.
`run_tool.gd -- audit` reports how much of v4 exists; `-- audit --todo` lists
only what is outstanding. **Run it before claiming a milestone is done.**

### The older GDDs

Superseded, but not worthless, and one of them is a trap:

- `docs/Game_Design_v3.md` was authoritative until 2026-08-13 and **is what the
  shipping code was built to**. When code and v4 disagree, v3 usually explains
  why the code is the way it is.
- `docs/Game_Design_v2.md` argues well for scope discipline. Read it before you
  cut or re-cut anything.
- `docs/Game Design.md` is v1, archived history. **Do not build from it.**

### Re-cuts of owner decisions

v3 §14 marks three things *"Un-cut. Owner's spec."* — decisions the owner
personally reversed against v2's cuts. v4 re-cuts two of them. That is an owner
decision being made a second time, so it needs an owner, not an agent.

| v3 §14 "Owner's spec." | v4 position | Status |
|---|---|---|
| Mid-combat tower placement | locked to Preparation | **DECIDED 2026-08-13: lock it. Build v4.** |
| Partial raid extraction | kept — two windows plus chieftain climax | no conflict |
| Chieftain capture → captive labour | replaced by Oathbound / ransom / standard | **DECIDED 2026-08-20: adopt v4's Oathbound framing.** |
| Run-scoped hero power (v4 §974) | — | **DECIDED 2026-08-20: hero level, attributes and loot now persist. See below.** |
| Co-op (v4 §54 cut) | cut for 1.0 | **DECIDED 2026-08-24: build two-player co-op. See below.** |
| Starting build capital (v4 §448) | one tower per road at start | **DECIDED 2026-08-27: no build capital. See below.** |
| Ranged weapons, ammo, blueprints, crafting (not in v4) | absent from the spec | **DECIDED 2026-08-31: build them. See below.** |
| Gear as the reason to replay (no loot loop in v4) | not in the spec | **DECIDED 2026-09-01: farm gear. See below.** |
| Companions as temporary spell effects (§54 cuts "party roster") | v4 keeps the cut | **DECIDED 2026-09-01: Wildlife Spirit Companions persist. See below.** |
| Disciplines as an anti-specialisation draft | every node open to everyone at once | **DECIDED 2026-09-09: the trees have paths. See below.** |
| Gear as a solo find (no player-to-player exchange in v4) | not in the spec | **DECIDED 2026-09-10: two players may trade. See below.** |
| Gear as a solo find, continued | no marketplace of any kind | **DECIDED 2026-09-10: the Long Ledger. See below.** |
| Three acts and a final ascent (v4 §8) | LOCKED at three | **DECIDED 2026-09-11: ten acts. See below.** |
| Tower levels 1-2, Forge to 5 (v4 §20, §23) | LOCKED | **DECIDED 2026-09-11: ten levels. See below.** |
| The town rides the beast; no standing hub (§54, IDEAS_REVIEW §4) | no hub | **DECIDED 2026-09-11: build the hub. See below.** |
| No dungeons, rifts, professions or ascension | absent | **DECIDED 2026-09-11: build them. See below.** |
| Disciplines are the card draft (IDEAS_REVIEW §4) | refuse a second pool | **DECIDED 2026-09-11: build Road Cards. See below.** |

**Mid-combat tower placement is settled.** Construction and upgrades belong to
Preparation; Command orders, doctrines, the horn and the hero carry in-combat
agency. Do not reopen it, and do not leave the v3 behaviour in place "just in
case" — a build path that only works in one of two designs is worse than either.

**The captive question is settled.** v4's framing is adopted: leaders are sworn,
ransomed or memorialised, never owned. The owner ruled on 2026-08-20.

It was held open because v4 makes *"no casualized slavery framing"* a
rating-target requirement (§2) and *"no unreviewed enslavement language ships"* a
release requirement (§57), and v3 §6.3 had flagged the framing as unsettled. That
is now decided rather than pending — but the §57 requirement is unchanged by the
decision. Player-facing strings still live in data (working rule 9), and any new
leader copy still has to be read before it ships. What has changed is that
Oathbound mechanics may now be built on, rather than parked.

**Two-player co-op is in scope, as of 2026-08-24.** The owner reversed v4 §54's
cut. Two players, cross-platform, defending one city. PvP, bigger parties and
daily challenges stay cut.

This is the one re-cut that changes the shape of the codebase rather than the
content of the game, so it comes with a standing rule: **co-op does not get to
quietly break working rules 5, 6 and 8.** `RunState` stays the single source of
truth - co-op answers *whose* copy is authoritative, it does not license a second
local cache. Systems still talk through `EventBus`, which is the seam the network
layer belongs at. The raid freeze still resumes exactly, now for two observers
instead of one. Where co-op genuinely cannot satisfy one of those rules, amend
the rule here, dated, in the same change - do not leave the codebase disagreeing
with this file.

**The run opens with no build capital, as of 2026-08-27.** This value has been
ruled on three times: one tower per road (v4 §448), nothing at all
(2026-08-24), and briefly a 150-Gold purse — which the owner then confirmed the
same day had been a co-op development aid rather than a design re-cut.
`Balance.STARTING_GOLD` is **0**, and tower money is taken off the enemies the
player kills. The confirmation is recorded in `ROAD_TO_RELEASE.md` §4b under
"Locked in §448 - production value restored".

**This paragraph said 150 until 2026-09-07**, and described a ceiling to move
the constant freely beneath. It was stale in the expensive direction:
`_test_opening_envelope` asserts `Balance.STARTING_GOLD == 0` outright, so an
agent following this file would have changed a constant a gate forbids and had
to work out why from the failure rather than from here. Recorded rather than
quietly overwritten, because this file is the first thing every session reads
and it is worth knowing it can be wrong.

The bound is the decision, not the number. What §448's teaching obligation was
ever protecting is that **the opening must ask something of the player before it
tests them**: a purse that covers every road hands over a finished defence and
asks nothing. So the gate asserts the two ends rather than a figure — wave 1
alone must not pay for a tower, and clearing the opening must pay for one by
wave 4, with every road covered by wave 12. Changing any of that is a design
change and should be argued in `_test_opening_envelope`, which is the one place
with an opinion about it.

**Gold is the only wallet that was zeroed**, and that is a decision rather than
an omission. Every tower carries a Gold price, so zero Gold already means zero
towers on the opening frame. What Wood, Food and Stone decide is *which element*
the first affordable tower may be — Fire is the one pure-Gold line — so emptying
them would not harden the opening, it would quietly force Fire for Act I. Wood
and Food also pay for town repair and hero tending, which are not tower capital.
If that reading is ever revisited, revisit it as a decision.

**Measured at zero.** The first tower lands on wave 3, which is when the second
road opens, and the four-road baseline on wave 8 — so the player fights alone
through the two single-road teaching waves and then buys a road at roughly the
rate roads arrive. Peak run pressure is unchanged either way, because starting
Gold was only around a tenth of a run's total income; what changed is the shape
of Act I, which used to sit at 0.02-0.19 through the opening and now ramps
0.06 → 0.48. The opening stopped being a formality.

Two things had to learn about the change and both are gates now. `curve_report`
models hero DPS as part of capability, because with no towers the hero *is* the
defence for the opening waves and a tower-only model divides by nothing there.
`balance_test` asserts the contract at both ends. Any harness that wants to
build without the economy being its subject must fund itself with
`RunState.gain_every_currency` — three of them were silently leaning on the old
390-Gold cache.

**The discipline trees have paths, as of 2026-09-09.** The owner reported the
skill tree as "not interesting or smart/intuitive" and asked for something closer
to a Diablo tree. That is a re-cut of a decision the code was making
deliberately, so it is recorded rather than quietly built.

**What it was.** Three disciplines of ten nodes, gated only by `mansion_tier` —
a *building* level, not anything the player chose. So all thirty were available
to everybody at the same time, and `refresh_discipline_offers` went further and
forced at least one off-discipline offer "rather than letting synergy turn into
a forced mono-build". A Blood hero differed from a Holy one only by which four
things happened to be slotted. There was no path, so no commitment, so no build.

**What it is.** A node now also wants *depth in its own discipline*: tier 1 opens
a tree, tier 2 wants one node already in it, tier 3 wants two. Nine nodes are
open at the start — three per tree — and training in one opens that one. Measured:
one Blood node takes Blood from 3 eligible to 6, two takes it to 8, while Holy
and Berserk stay at 3.

**The anti-mono-build rule stays, and stops being a straitjacket.** It was there
to prevent specialisation from being forced; now specialisation is *bought*, and
the rule only guarantees a visible alternative. Breadth is a real choice with a
real cost — three shallow trees instead of one deep one — rather than the only
option.

**Counted, not graphed.** A node names a depth rather than particular
predecessors. A count cannot author an unreachable node the way a hand-drawn
graph can, and this project has already lost `call_wolf` to exactly that failure
once. `discipline_check` no longer samples from a standing start either — it
*walks* each seed, taking an offer and seeing what the next road opens, favouring
each discipline in turn. Sampling from zero trained would have asserted the tree
away, because a tier-3 node is now supposed to be out of reach to a player who
has trained nothing.

**The bound is that depth buys access, never power.** Nothing here raises a
number. A deep tree opens *more nodes to choose from*; the nodes themselves are
the same nodes, on the same capped scales as levelling and gear (working rule 7).
If depth ever starts granting magnitude, that is a third power scale beside
levelling and gear and it needs its own decision.

**Stage two: synergies, as of 2026-09-10.** Pairs of trained effects that do
something together they do not do apart. Three ship: a Howler kill refills
Rising Fury, standing up near the Town Hall pays Command, and the revive shove
grants Hunter's Pulse.

**None of them raises a number, and that is a hard rule rather than restraint.**
The bound above says depth buys access and never magnitude; a synergy reading
"four Blood nodes, so Blood hits harder" is that same third power scale arriving
through a side door. So every synergy changes *when* an existing effect fires or
*what it fires on*, and the magnitudes stay the ones the nodes authored. The
price is still real - a synergy costs both its nodes, two skill points and two
lots of Food that could have bought breadth.

They are listed on the Mansion tree page from the first visit, with progress
counted, because a synergy discovered by accident is a coincidence rather than a
build.

`synergy_check` (inside `discipline_check`) holds four ways one can be a lie,
all with precedent here: authored and read by nothing, requiring an effect no
node carries, resting on one of the seventeen effects still owed, or requiring
two effects a hero cannot hold at once - the three finishers are all Attack-slot
and only one node sits in a slot, so a synergy between two of them could never
fire at all.

**Stage three is still open.** Whether the per-road draft should be replaced by
freely spending skill points has not been decided or built. Do not treat the
paths or the synergies above as that decision.

**Ranged combat, ammunition, blueprints and crafting are in scope, as of
2026-08-31.** None of them appears in v4. The owner asked for all four after
being told they were outside the spec, which makes this an addition to the
design rather than a misreading of it.

What that buys, and what it costs, stated plainly so the next argument about it
starts from the same place:

- **The hero gains an answer at range.** Every fight currently resolves by
  walking at something. A bow changes which enemy you deal with first, and that
  is the whole reason to build it.
- **Ammunition is the price.** Range without a cost is simply a better melee
  attack, so ammo is a run resource that is spent, found and crafted. It is
  *not* an inventory of stacks competing with loot — it has its own pool, per
  the same reasoning that keeps Marks off the tower economy (working rule 7).
- **Blueprints are permanent knowledge**, and the only thing in this group that
  touches `MetaState`. They unlock *recipes*, and are covered by the existing
  `unlocked` list rather than a new save shape — so working rule 7 is unchanged
  and no new persistence was sanctioned by this decision.
- **Crafting is bounded to what a blueprint names.** There is no research, no
  recipe modification and no ingredient sprawl; the materials are the four run
  currencies plus what enemies already drop.

The bound worth defending is that **melee remains the reliable default**. If a
run can be completed at range without ever closing, the trade this system exists
to create has collapsed and the ammo economy is decoration. `balance_test` owns
that question.

**Gear is what the player comes back for, as of 2026-09-01.** The owner's words:
"the game needs way more loot! Players should be farming a bunch of gear and
mostly playing to farm better gear to be able to get further in the game."

That is a statement about what the game *is between runs*, and v4 does not make
it - v4's between-run layer is unlocks and Sigils. It changes no rule; it changes
the volume. Battlefield gear went from 0.6% a kill to 2.4%, elites from 18% to
45%, a boss now leaves three pieces rather than one, and the stash holds 96
instead of 40. Fourteen new kinds were authored, so every slot has at least seven
and gear can raise all four attributes rather than three.

**The bound that must not move is working rule 7**, and it does not: gear still
grants *attribute points* on the same capped scale as levelling, so four times the
drops is four times the choosing and not four times the power. Capacity is
inventory, not power - three pieces are worn and the rest is shard stock.

The tiers now scale the odds as well as the numbers (`GEAR_TIER_ODDS_CEILING`),
because a Nightmare run that costs more and pays the same makes farming Normal
forever the correct play. `balance_test._test_gear_farming` holds the four
properties this rests on: a hundred kills usually pays, the top rarity stays an
event, every slot has real choices, and the stash outlives a haul.

**Wildlife Spirit Companions are a persistent collection, as of 2026-09-01.**
The owner asked, in detail, for every wildlife species to be bondable as a
companion at each rarity, with shiny variants, permanent progression, and no
lifetime timer. That is two amendments and both are recorded here rather than
left implicit in the code.

**It re-cuts §54's "multiple heroes, party roster".** `CompanionData` argued -
correctly, at the time - that a summon with a duration is a *spell effect* and
one that persists is a party member, which §54 cuts. A Spirit Companion has no
duration: it stays until defeated, unequipped or replaced. That is the cut being
reversed, and it was flagged three times before the owner ruled.

The bound that keeps §54 meaningful is **one active slot**. What was cut is a
*roster* the player commands - swapping between several bodies, ordering them
about. One companion that follows and fights on its own is a second presence,
not a second hero, and the player remains the character. The storage is a single
key rather than an array so that adding a slot later stays a deliberate decision
rather than a natural consequence.

**It amends working rule 7**, which lists what `MetaState` may persist and did
not include this. What persists is *which spirits have been met and bonded* and
nothing else: no spirit carries a level, no run currency is banked, and a bonded
spirit is no stronger for having been owned longer. Its power comes entirely
from the variant's rarity, which was fixed the moment the animal was placed.
Collection, not accumulation - the same distinction that keeps gear on the
capped attribute scale.

The save is additive: a file written before this has no `spirits` key and reads
as an empty collection, so `SAVE_VERSION` did not move and no migration exists
to get wrong.

**A bonded spirit also carries a personality, as of 2026-09-01.** The owner asked
that "two legendary foxes can actually feel different". Six traits live in
`data/spirit_traits/`; the living animal wears one, decided from its own serial
number, and bonding it banks *that animal's* temperament against the variant.

This is still collection rather than accumulation, which is what keeps it inside
the amendment above. A personality is fixed the moment the bond is made, never
levels, and is a property of the animal you happened to meet - exactly as its
rarity is. It rides the value of the existing `spirit_bonded` entry rather than
adding a key, so a bond written before this reads `true`, which loads as a bonded
spirit with no personality. `SAVE_VERSION` still has not moved.

**The bound is that no personality may be a damage upgrade.** A spirit's power is
already capped by `SPIRIT_APEX_POWER`; a trait that simply hit harder would be a
third scale beside levelling and gear that nobody is tuning against, and the best
trait would become the only one worth keeping. So every trait's damage is an
envelope that trades - stronger at your shoulder and weaker away from it,
stronger hurt and weaker whole - and the two that find things pay for it out of
the same envelope. `spirit_trait_check` holds the mean at one.

**And the road hunts, as of the same date.** Predators notice harmless wildlife
inside a fraction of their aggro radius, and prey bolts from predators. It is a
chase and never a meal: `Wildlife._strike` accepts a Hero or an Enemy and refuses
everything else, which is what stops the ecology from quietly eating a Spirit
Companion the player was three encounters from bonding. That bound is the whole
design and `wildlife_spawn_check` holds it.

**Enemies have nerve, as of 2026-09-02.** The owner's framing for a batch of
ideas was *"the Road is always telling you something - if you're paying
attention"*, and this is the clearest thing on the field under it: an ordinary
body breaks when the champion near it falls, runs back up the road for a couple
of seconds, and returns. A line coming apart is information the player reads
without a number being shown, and it makes killing the leader **first** the
readable play rather than a tip in a menu. A living champion holds the line,
which is the other half of the same sentence.

**The bound is that morale changes the shape of a fight and never its size.** A
routed body does not despawn, does not leave the group a wave is waiting on, and
pays out exactly what it always did. The three-act pressure curve is tuned
against how many bodies arrive; if breaking one removed it, every wave in the
game would quietly get easier and the curve would be measuring something that no
longer happens. Retreat is also always *back up the road* rather than away from
whatever caused it - "away from what frightened me" sends a body that broke on
the town side straight at the gate, which would turn breaking its nerve into
helping it arrive. `morale_check` holds all of it.

**Shiny odds now correct for a dry streak, as of the same date**, and nothing
new persists to do it. `SpiritBond.shiny_chance` derives the streak from the
encounter counts the journal already keeps - the gap between ordinary sightings
and shiny ones *is* the streak - so there is no pity counter and no new save key.
Nothing happens until a player is well past twice the expected gap, and the lift
is capped at four times base: a Common shiny is 2% and may reach 8%, never more.
The rare thing stays rare; what is prevented is only the tail where somebody
sees nothing for hundreds of sightings and has done nothing wrong.

**Gear can be marked kept.** A stash of 160 with two break-everything buttons in
it needed one, and the failure it prevents is silent and permanent. The rule
lives in `Stash.may_break`, asked by the button and by the gate, rather than as
conditions written inline where nothing could test them.

**Two players may trade gear, as of 2026-09-10.** The owner asked for
RuneScape-style trading between two players, and later for a marketplace built
on top of it. This is the first half only.

**It adds no persistence and it does change the economy.** Nothing new is saved
- a traded piece is a stash entry, which working rule 7 already sanctions, and
the only new field on one is a `uid` so that an offer can name a piece rather
than a position. What *is* new is that gear can now arrive from another player
rather than only from a drop, which is a change to the thing the owner called
"the reason to replay" on 2026-09-01. Recorded here rather than left implicit,
because a marketplace would multiply it and that decision should start from this
one being visible.

**The bound is that gear is never created.** A trade may fail, and a failed one
may cost a side what it offered - the failure direction is documented on
`TradeBooth.settle` - but no sequence of packets, disconnections or races may
end with a piece existing twice. Everything in the design is that invariant
being paid for: one authority, names rather than positions, validate-then-move
with no half-applied state, the stash locked against destruction while a trade
is open, and a received piece renamed on arrival. `trade_check` holds all of it
and each protection has been checked by removing it.

**And the marketplace is built, as of the same date.** The owner asked for it
directly - "build the grand exchange marketplace now" - after having asked for
it as an eventual want alongside the trade window.

**Prices are shared; custody is not.** That is the whole design and it is the
answer to the paragraph this one replaces, which said a marketplace "needs
somewhere for gear to live while it is neither player's". It turns out it does
not. There is no account server: the Supabase project behind the leaderboard
answers to an anonymous key every copy of the game carries, so anything a client
can write, any client can forge - and a forged *item* would end the loot economy
in an afternoon. So the Long Ledger publishes what pieces **sold for** and never
the pieces. The counterparty is the Ledger's own caravans, the escrow is local,
and the worst a forged row can do is make a guide price wrong for a day.

That is not the design cut down to fit. Posting at a price, walking away, and
coming back to money while the price moves because of what everybody else did is
what a grand exchange *is* to the people using one, and all of it survives.

**Two bounds keep it from eating the game, and both are gated.**

- **Buying is always dearer than vendoring.** The stash already sells a piece for
  Marks. If the Ledger could ever be bought from below that, buy-vendor-repeat
  prints Marks forever. `exchange_check` checks the cheapest reachable purchase
  against the vendor price for every rarity and level in the game, at both ends
  of what the price feed may ever do.
- **The Ledger cannot sell what nobody sold it.** Gear is "the reason to replay"
  (2026-09-01), and a shop with an infinite catalogue makes the road optional.
  Supply falls away steeply with rarity, and an Oathbound piece stays something
  you find.

**It adds one thing to the save, and it is gear.** A listed piece leaves the
stash and is carried by its order, so a save that did not write the board would
destroy everything a player had listed the moment they quit. This is not a new
*kind* of persistence - working rule 7 already sanctions owned gear and Marks,
and escrow is those two things parked in a second list while a caravan is on its
way - but it is a second place gear can be, and that is worth knowing about
before anything else iterates a stash and assumes it has found all of it.
Additive, so `SAVE_VERSION` did not move.

**Orders fill on road travelled and on nothing else.** Word travels with the
caravans, so distance is the clock: standing in town settles nothing and a long
run settles a lot. The Ledger pays for playing, never for leaving the game open,
and the screen is careful to say "about half a run of road left" rather than any
number of minutes.

Operations, the table's SQL and what every constant decides are in
`docs/EXCHANGE.md`. **A true player-to-player order book is still not built**,
and it is the same blocker as before: it needs real accounts and server-side
logic. If the project ever gains those, that is the decision to revisit first.

**The road announces itself between acts, as of 2026-09-10.** The owner asked
for the best of a large ideas document to be adapted; this is the one taken from
it, and it comes from Diablo IV's Infernal Hordes by way of that document.

When an act boss falls, three **portents** are offered and one is read. Each has
a bane and a boon, and it is **kept for the rest of the run and stacks with the
ones before it**. Ten are authored in `data/omens/`.

**Why this and not the twenty other things in that document.** Most of what was
proposed already exists here under other names - enemy affixes, branching roads
with voted difficulty, seeds, a chronicle, a run recap, weather, day and night,
traps, wildlife, travelling merchants, campaign tiers. Of what was genuinely
missing, this is the piece that multiplies what is already built rather than
adding a system beside it: it reaches every tower, every wave and every wallet
through numbers the game already has an opinion about, and it costs one resource
type and one screen path.

**The bound is that a portent may only move a number `Modifiers` already
resolves.** Both halves land in the same flat table relics and boss cores feed,
so nothing downstream learns that omens exist. A portent that added a *mechanic*
would be a content system wearing a card's clothes, and it would not be testable
against the curve the acts are tuned to.

**It is run-scoped and nothing persists.** Working rule 7 is untouched: an omen
is a modifier on the current road exactly as a socketed relic is, and
`omen_check` asserts that a fresh run clears them - portents that survived into
the next run would be an account-level difficulty setting nobody chose.

**The failure worth gating is a portent that charges nothing.** A misspelt effect
key lands in the table under a name nothing reads: the card still draws, still
says the words, and hands out the boon for free, so the run gets *easier* the
more you read. `omen_check` takes every omen for real, rebuilds the table and
reads the number back - and it caught one authored with its halves the wrong way
round on the first run.

The rest of that document is triaged in `docs/IDEAS_REVIEW_2026-09-10.md`, with
what is already built, what is worth building next, and what should be refused.

**Otherwise: do not silently implement a re-cut of anything in v3 §14.** Ask, or
leave the v3 behaviour in place and flag it.

**The game is called Wilderhold, as of 2026-09-11.** The owner renamed it from
Beast Road. What changed: the title (`config/name`), the export product names,
the wordmark art, the launcher's name and strings, the in-game title card and
credits, and the release title on GitHub.

What deliberately did **not** change, and why each is a decision rather than
an omission:

- **`user://` is pinned to `godot/app_userdata/Beast Road`** with
  `application/config/use_custom_user_dir`. Godot derives the user directory
  from the title, so an unpinned rename moves every existing save into a folder
  the game no longer reads, with no error and a fresh account on the menu. The
  lowercase `godot` is what makes one spelling match both Windows (which is
  case-insensitive) and the web build (which is not). `user_dir_check` holds
  the pin in both workflows. `MetaState.SAVE_PATH` is unchanged for the same
  reason.
- **The GitHub repository, the web origin `beastroad.arxangel.gg`, the Android
  package id and the launcher's install folder** stay as they are (owner
  ruling, 2026-09-11: dev-testing identifiers for now). Web saves are
  per-origin and an Android package id is the app's identity, so each of these
  is its own sequenced migration if it is ever revisited.
- **The release asset names** (`BeastRoad-windows.zip`, `BeastRoadLauncher.exe`,
  `BeastRoad-web.zip`, `BeastRoad.apk`) stay. The permanent launcher link and
  the Update Manager resolve them by exact name; renaming them breaks updates
  for everyone already installed unless the old names are published beside the
  new ones for at least one release.
- **The game executable inside the zip is still `BeastRoad.exe` this release.**
  Launcher 4 runs whichever of `Wilderhold.exe` / `BeastRoad.exe` it finds, and
  a launcher updates itself before it installs a game, so the export path may
  switch once every installed launcher has had one release to update.
- **The run title "The Beast Road" stays**, as fiction: the road the beast
  walks keeps its name. The game does not.
- Internal identifiers (`beast_road_*` metadata keys, the LAN beacon magic,
  the support-diagnostics format tag) and historical `docs/` prose are not
  player-facing and were left alone.

**The owner's directions of 2026-09-11, and where each one stands.** Alongside
the rename the owner asked for a large expansion: enhanced tutorials, ten acts,
more towers with ten upgrade levels, more wildlife, fishing ponds with consumable
fish, Ravenswatch- and Infernal-Hordes-style choices, card-style upgrades, a mana
bar with Focus governing it, more ranged spells, loot goblins, juicier damage
numbers, a skills revamp, Astonia-style dungeons, rifts, professions, a
gatekeeper ascension and a hub town, a maximum juice pass, optimisation, more
gear, more rarities and gear affixes with up to three stat bonuses. That is
months of work, and the owner's own advisor's rule for this month is the right
one: only what materially improves the launch is built now, and the rest is
recorded here so it is neither forgotten nor quietly built as a re-cut.

**Built in the 2026-09-11 session**, each gated and committed on its own:

- **Mana, governed by Focus.** Spells cost mana (`SpellData.mana_cost`, every
  spell authored), the pool refills slowly, and Focus deepens it, refills it
  faster, sharpens spell damage and shortens cooldowns up to a cap. This also
  closes a placebo: the Mansion had promised "spell power" for Focus since the
  attribute was authored and `HERO_FOCUS_SPELL_PER_POINT` was never read.
  `mana_check` holds it. Mana is a run resource on the hero, like health;
  nothing persists.
- **Loot goblins, as raccoons.** A hoarder flag on `WildlifeData`; the raccoon
  carries a sack of Gold, often gear, outruns a walking hero, and rifts away
  when its clock runs out. No new art. `wildlife_spawn_check` holds it.
- **Enhanced tutorials.** Nine more steps on nine new triggers (raid, gear,
  level, spells, bow, merchant, portents, town, spirits), all data.
- **Damage numbers** pop, arc, hang and tilt. **Seven more discipline nodes**
  do what their cards say. **Two builds refuse to play co-op together.** The
  **Update Manager** derives its pre-flight from the workflows.
- **Fishing**, with eleven fish and three ponds. See the note above; it is the
  one item in this batch that amends working rule 7.
- **Gear affixes**: one, two or three attribute bonuses by rarity, dividing the
  budget a piece already had.
- **Twenty-five more gear kinds** in the five thin slots, which also lifts the
  rarest slot from 6.8% of drops to 10.1%.

**Staged - compatible with v4, not built yet, in the order they should go:**

1. ~~Fishing ponds.~~ **Built 2026-09-11** - see the note above. Eleven fish,
   three ponds, a Consumables tab, and `fishing_check`.
2. ~~Gear affixes, up to three stat bonuses a piece, and more gear kinds.~~
   **Built 2026-09-11** - see the two notes above. The budget is divided, never
   added to, and the five thin slots went from five kinds each to ten.
3. More towers and more wildlife: data plus art, gated by PixelLab budget.
4. More ranged spells: `SpellData` kinds already cover it; content and icons.
5. The skills revamp: discipline stage three (freely spent skill points) is
   still an open owner question and should be answered before a revamp.

**~~Need an owner ruling before any code~~ - RULED ON 2026-09-11: build them
all.** See the note below for the ruling and the order. The list is kept as
written because the reasoning is what each one has to be built *against*:

- **Ten acts.** v4 §8 is three acts and a final ascent, and the pressure curve,
  the boss roster, the regional factions and the campaign tiers are all tuned
  against that shape. Ten acts is a second game's worth of regions, bosses and
  balance, not a constant.
- **Ten upgrade levels per tower.** `TOWER_BASE_LEVEL_CAP` and the Forge's
  mastery levels 3 to 5 are the design; ten levels changes the cost model in
  v4 §20 and the whole curve.
- **A hub town for matchmaking, trade and the exchange.** The town already
  rides the beast; a standing hub is the map grammar `IDEAS_REVIEW` §4 refused,
  and it needs the accounts the Ledger deliberately does without.
- **Dungeons, rifts, professions, a gatekeeper ascension, more rarities.** Each
  is a new persistent progression axis under working rule 7, or a new content
  system beside raids, and needs a decision on what it may persist.
- **Card-style upgrades and Infernal-Hordes choices** are what disciplines and
  omens already are; grow those rather than add a third draft.

**There are ponds off the roads, and fishing keeps a consumable between runs,
as of 2026-09-11.** The owner asked for procedurally placed ponds outside the
battlefield's paths, a catch that pays Food and health, fish of different
rarities with different effects, and a consumables tab in the stash. All of it
is built; two things about it are decisions rather than details.

**It amends working rule 7.** A fish is the first *consumable* in this project
that survives a run. The Tonic and the Draught live in `RunState` and are lost
with everything else; the pantry (`MetaState.fish`) is not. That is a new kind
of persistence and it is sanctioned here rather than left implicit in the code.

**The bound is `Balance.FISH_MEALS_PER_RUN`: the pantry persists, the appetite
does not.** A run allows three meals however deep the larder, so an hour of
fishing buys a deeper *choice* of meal and never more of them. Without that cap
a player with a full pantry cannot be killed, and the wounds, the Tonic and the
entire recovery economy become decoration. `fishing_check` asserts the cap
first and hardest, and it has been checked by removing it.

**And no fish grants a stat.** Levelling and gear are the two capped scales the
campaign tiers are tuned against; a consumable that raised an attribute would be
a third that nobody is tuning - the same objection that bounded spirit traits
and discipline depth. Every effect a fish carries is a *fraction of something
the hero already has*: health, a ward, mana. The gate reads the resource and
fails on any field that looks like a stat.

**"Procedural" here is placement, not layout.** v4 §54 cuts procedural
battlefield *layouts* and that cut stands: the map is still hand-authored and
the ponds are scattered on it, exactly as the treeline and the wildlife already
are. A pond may only sit on open ground, clear of every road by more than a
tower's inner reach - so water never takes a build spot that was worth having -
and **inside** the grid, which is where it differs from a tree: the hero is
clamped to the grid, so a pond outside it would be visible and unreachable.

**The cost of fishing was standing still on a battlefield** - and as of the
second cut (see below) it is standing still *and* a cast, a hook and a reel.
Moving or taking a blow still takes the line out, which is the tension raids
are built on. A pond holds four fish and then reads as fished out, so the
correct play is never "stand in a corner for the act".

**Both machines dig the same ponds and neither is told about them.** The scatter
comes from the run's own seeded stream, like the relic and omen offers, because
a fact that can be relayed is a fact that can be subtly wrong. One thing does
cross the wire: a guest's catch asks the host for its Food **by fish id, never
by amount**, so the host reads the number off its own content. A number in that
message would have been a currency printer.

**Gear carries up to three bonuses, as of 2026-09-11.** The owner asked for
Astonia's shape: "more item affixes, and up to 3 stat bonuses". A piece now
bonuses one, two or three attributes by rarity rather than always one.

**The total is exactly what it was, and that is the whole design.** Gear and
levelling are the two capped scales the campaign tiers are tuned against
(working rule 7), and `Stash.points` is how gear is measured - so a second and
third bonus *on top* of the first would raise the scale rather than enrich it.
`Stash.affixes` **divides** that budget; it can never add to it. What rarity
buys is breadth: an Oathbound piece dresses three attributes rather than
hitting harder, and the number of bonuses becomes a rarity tell a player reads
without the label.

`balance_test._test_gear_affixes` checks the total against the budget for every
kind at every rarity and every level, because the failure it catches is
arithmetic and would show at one combination and not another. It caught one
before the code ever ran: with a floor of one point per bonus, a piece worth two
points split three ways granted three. A piece too cheap to pay for its bonuses
now has fewer.

**Nothing was added to the save.** The secondary attributes are derived from the
piece's own `uid` - the name it already carries so a trade can refer to it - so
a piece is still `{kind, rarity, level, uid}` on disk, there is no migration,
and gear written before affixes grows them the moment it is read.

Two consequences of deriving them that are worth knowing:

- **The roll is arithmetic, not an RNG.** `RunState.attribute` asks
  `MetaState.gear_attribute_points` on every call and the hero asks that for
  movement, damage and mana several times a frame, so a
  `RandomNumberGenerator` per worn piece per call would have been an allocation
  in the hot path. A multiply and two remainders is not, and is exactly as
  deterministic.
- **A piece that had never been named is now named permanently.** `Stash.uid`
  assigns one in place when a piece lacks it, and `MetaState` used to leave that
  only in memory - so gear from before trading was renamed on every launch. That
  was survivable while a name meant "which piece is on the trade table"; it
  stopped being survivable when the bonuses started being rolled from it. The
  load now writes the names it hands out, once.

**Twenty-five more gear kinds, as of 2026-09-11**, all in the five slots that
were thin. Helmets, gloves, boots, rings and amulets go from five kinds each to
ten; weapons, armour and charms are unchanged.

**It is a drop-rate fix as much as a content addition, and that is why these
five slots and not the others.** `Stash.roll` picks by weight across *every*
kind rather than per slot, so how often a helmet drops is decided by how many
helmets exist relative to everything else. The five slots added on 2026-09-01
arrived with five kinds each against eighteen weapons, and the arithmetic of
that was a helmet on **6.8%** of drops against a weapon on 24.9% - so a player
hunting one waited nearly four times as long and nothing said why. The thinnest
slot is now **10.1%**, against an even share of 12.5%.

`balance_test` holds a floor at two thirds of an even share, as a share of the
*pool* rather than a count of kinds - that is the number a player feels, and a
slot can be starved either by having few kinds or by having light ones.

**The art is cold, and the first pass was not.** These were generated with the
warm painterly suffix the handoff records as "the style that matched this game",
which is true of omen icons and loot drops and false of gear: the 73 shipped
gear icons are blue-grey steel and near-black leather. The first 25 were
internally consistent, readable, and obviously from a different game the moment
they were put beside the existing ones. Caught by a three-row contact sheet -
new, corrected, shipped - and by nothing else, because no gate can see a
palette. The suffix that matches gear is recorded in the memory directory.

**The five held items are approved, as of 2026-09-11.** On 2026-09-11 this
file recorded five of the owner's requests as needing a ruling because each
re-cuts something v4 LOCKED or a working rule. The owner was shown that list
with the reasoning for each and answered: *"Continue with everything, build
them all."* That is the ruling. It is recorded here rather than acted on
silently, because the table above exists precisely so that a decision made
twice is visible the second time.

**What each one costs, stated plainly so the next argument about scope starts
from the same place.** None of these is a constant to flip; each is a body of
content and a curve to re-tune.

1. **Ten acts** (v4 §8 was three plus the ascent). Seven more regions, each
   wanting ground art, a backdrop, a faction, an enemy mix and a boss - and the
   three-act pressure curve re-derived over ten. The structural half is
   `Balance.ACT_COUNT` and the arrays keyed to it; the expensive half is the
   content, and it lands region by region.
2. **Ten tower levels** (v4 §20, §23 were 1-2 with the Forge reaching 5). The
   cost model and the per-level scaling both grow, and every tower's curve has
   to stay under the ceiling the acts are tuned against.
3. **A hub town** for matchmaking, trade and the Ledger. `IDEAS_REVIEW` §4
   refused this as "the grammar of a map you hold, and this map walks". The
   owner's version is a *lobby* rather than a second battlefield, which is the
   reading that keeps the walking town intact.
4. **Dungeons, rifts, professions and a gatekeeper ascension.** Each adds a
   persistent progression axis, so each needs its own answer to working rule 7
   about what it may save. They are built one at a time, each with its bound
   written down, exactly as spirits, gear and the pantry were.
5. **Road Cards.** Disciplines and omens already are a draft, which is why this
   was refused before. Built as a *third* pool it must not become a third power
   scale: the bound is the omen bound - a card may only move a number
   `Modifiers` already resolves.

**The order is dependency-first, not want-first.** Ten acts comes first because
regions, bosses, rarities and card pools all hang off how many acts there are;
the hub comes last because it is the largest piece of UI and nothing else waits
on it.

**And one thing does not move.** Every one of these is still held to working
rule 7 and to the capped scales: levelling and gear. If any of them starts
granting magnitude outside those, that is a new power scale and it needs its own
decision - the same bound that has held for spirit traits, discipline depth,
synergies, omens and fish.

**The road is ten acts long, as of 2026-09-11.** Seven regions were added after
the three that shipped - Hollow Marches, Rustwood, Saltpan, Iron Steppe, Glass
Fields, Ashen Reach and the Last Terrace, as acts 4 to 10. Jungle, desert and
snow keep acts 1 to 3 and were not renumbered, so every seed, save and screenshot
of the old campaign still means what it meant.

Each region brought a faction, a boss, eight relics and its own ground: that is
seven terrains, seven backdrops, seven boss sprites and fifty-six relic icons.
`Balance.ACT_COUNT` is the structural half and the arrays keyed to it -
`WAVE_ACT_COUNT_SCALE` and `BOSS_ACT_SCALE` - carry the curve out to ten.

**Eight relics per region is a rule, not a coincidence.** `balance_test` asserts
it, so adding an act means adding eight relics with it or failing the gate. That
assertion had been quietly dead: it counted into a hand-written `[0, 0, 0, 0]`,
so with ten acts it went out of bounds on region 4, aborted the function, and the
gate printed PASS having checked nothing. The array is now sized from
`ACT_COUNT`, and the sixty-five assertions it was skipping run again.

**Ten tower levels, as of the same date - and they are the same journey, not a
second one.** Every multiplier in `TOWER_LEVEL_DAMAGE`, `_RATE`, `_UTILITY` and
`_RANGE` was re-derived by reading the old four-step curve at the new cumulative
costs. So 280 Gold still buys about 1.88 damage and 1180 still buys about 3.20:
power per Gold is preserved, the acts already balanced did not have to be
re-tuned, and what changed is that the player now passes ten doors on the way
rather than four. The ladder continues a little past where it stopped - 1950 Gold
reaches level 10 at 3.97 damage.

**The obvious alternative was the wrong one, and the curve report says why.** Five
more levels each a further thirty percent would have been a second power scale
nobody tuned against, and unreachable besides: a whole ten-act run earns about
four thousand Gold in `curve_report`'s best case, so a level priced at a thousand
is a level nobody buys. The visual steps were halved with the level count too, so
a maxed tower is the size a maxed tower has always been rather than twice it.

**The Forge opens bands rather than single levels.** `TOWER_LEVEL_CAP_BY_FORGE`
is `[3, 5, 7, 10]` - a table, because `base + tier` with three Forge tiers could
only ever reach 6 and would have left four levels authored and unreachable. That
is the failure this project has already paid for once, with a discipline node no
seed could offer, so `balance_test` now walks every level and checks some
buildable Forge tier unlocks it.

**And later acts pay more, which is a change to the economy and not a tuning
nudge.** Kill spoils were `resource_value` and nothing multiplied them, while
enemy health rises sixteenfold across ten acts. Over three acts that was a
defensible simplification - `Enemy._on_died` says so in as many words, and hands
act scaling to experience instead. Over ten it is something the player feels:
`curve_report` showed capability dead flat from wave 62 to the end, because by
then the purse had bought every emplacement it would ever buy and each further
act paid exactly what Act I paid while asking four times as much. Gold stopped
being a decision halfway through the game.

`Balance.KILL_ACT_VALUE_SCALE` rises to 3.2 by Act 10 and is **1.0 for Acts 1 and
2 on purpose**: the opening envelope - wave 1 must not pay for a tower, clearing
the opening must, every road covered by wave 12 - is the one stretch of this
economy measured against a player learning the game, and
`balance_test._test_opening_envelope` owns it. Mean pressure over the ten-act run
is 0.426 against a band of 0.26-0.46, and the last wave sits at 0.72.

**`curve_report` now prints the purse.** It reports Gold earned, towers bought and
the level that purse reached, because a capability that stops climbing is either
out of Gold or out of levels and those two want opposite fixes. Reading that
column is what turned "ten acts fails the curve" into "the economy is flat", which
is a different bug with a different answer.

**Ten more portents, and two constants that had stopped describing the game, as
of 2026-09-11.** Ten acts read ten portents. Ten were authored, one leaves the
pool each time it is read, and `Run._offer_omens` refuses to open on fewer than
three cards - so by the ninth reading the pool held two and **Acts IX and X
offered no portent at all**, silently. That is the exact failure
`omen_check`'s own comment warns about: "a thin pool is a feature that silently
never appears".

The pool is twenty now, with `first_act` spread from 1 to 9 so the heavy ones
have somewhere late to belong, and `OmenData.first_act` may name any act rather
than only the first three. **The gate walks the campaign instead of counting the
pool**, taking one portent per act, because counting is what missed it: ten
looks ample until you notice that what is dealt leaves.

**And a portent may no longer grant a fraction of a countable thing.** `Tower`
reads `chain_targets` with `int()` and `RunState` rounds `wave_foresight`, so a
card granting 0.6 of a chain target charges its bane and hands out nothing. Two
entries were authored that way here before either reached disk;
`omen_check.COUNTED_KEYS` now refuses them.

`CROSSROADS_PER_ACT` and `CROSSROADS_PER_RUN` were 3 and 9 and **nothing read
either of them**. A crossroad is not scheduled - `Journey` fires one whenever the
beast crosses a `SEGMENT_DISTANCE` boundary - so the real figures were two an act
and twenty a run, and two constants had been quietly wrong in both directions.
They are derived from `SEGMENTS_PER_ACT` now rather than deleted, because
`V4_CONFORMANCE` probes one of them by name.

**Road Cards are built, as of 2026-09-11.** The owner asked for card-style
upgrades in the manner of Megabonk, Vampire Survivors and ARAM augments, and
`IDEAS_REVIEW` §4 had refused them on the grounds that disciplines and omens
already are a draft. That objection is correct, and it is what shapes the answer
rather than what blocks it.

**Twenty-four cards, three offered at every crossroad, a hand of five.** A card
carries one entry for `Modifiers` - the same flat table relics, boss cores and
portents feed - so nothing downstream learns that cards exist. That is the bound
the ruling names: a card may only move a number the game already has an opinion
about.

**What stops twenty crossroads from being twenty upgrades is two rules, and both
live in `RunState.take_road_card`** so that one function owns them and the gate
drives the real one rather than a copy:

- **The hand holds five.** Twenty crossroads deal sixty cards and five are kept,
  so the draft is mostly refusal - which is what makes it a decision. Once the
  hand is full, every later draw is a *replacement*, and the panel asks which
  card to leave behind.
- **One card per effect key.** Five Rare tower-damage cards would be +110% on one
  number; one is +22%. A better card for a key you already hold swaps it, so
  rarity is an upgrade path rather than a stack.

Between them the most a hand can ever be worth is five cards on five different
numbers - a quantity the curve can be read against, unlike an open-ended sum.
**Nothing persists**: a hand is run-scoped exactly as a socketed relic is, and
`road_card_check` asserts a fresh run deals a fresh one.

**The draft is a separate moment from the road, deliberately.** It opens after
the road is chosen rather than beside it, because the road is a decision about
where to go and the card is what the last one taught; on one screen neither
lands. Both travel as one co-op message carrying the take and the drop together
- sent separately, a disconnect between them leaves a hand of four, which is not
a state any screen can explain.

**Two more gear rarities, as of 2026-09-11.** Chainbroken and Beastcalled sit
above Oathbound - the chain is what the Chainmaker binds the beast with, and
what the beast itself has answered to is the last thing on the ladder.

**A longer ladder, deliberately not a steeper one.** Gear and levelling are the
two capped scales the campaign tiers are tuned against (working rule 7), so the
question a new top rarity has to answer is what it may add. The first four steps
of `Stash.RARITY_POINTS` are about 1.34 each; the two new ones are 1.22 and
1.18, so the top is 44% above Oathbound rather than the 80% a continued
geometric run would have handed over.

**What they mostly buy is breadth.** They are the only pieces that dress three
and four attributes (`GEAR_AFFIX_COUNT` ends `3, 4`), and the affix budget is
still *divided* rather than added to - the bound the affixes themselves were
built under on the same day. Four is the ceiling because a hero has four
attributes.

**And they must stay findable rather than buyable.** `EXCHANGE_BASELINE_SUPPLY`
falls to 0.02 and 0.005, and `exchange_check` already refuses a top rarity the
Ledger stocks often enough that finding one stops mattering.

**The failure worth gating was not the numbers but the tables.** Every array
keyed by rarity is read through a clamp, so a short one does not crash - it
silently gives the new rarity whatever the one below it was worth, and a rarity
that means nothing is indistinguishable from one that was never added.
`balance_test` now checks all nine tables against `RARITY_NAMES.size()`, that
value and sale price rise with rarity, that the Ledger's stock falls, and that
no rarity asks for more bonuses than a hero has places to put them.

**Seven more species, and an ecology that reaches Act X, as of 2026-09-11.**
Bog Crane, Iron Beetle, Saltpan Crab, Steppe Horse, Glass Moth, Ash Hound and
Terrace Goat, one for each region the road gained.

**The gap was not that the new regions were empty.** `WildlifeData.acts` is a
*preference*, not a gate - `roll_weight` makes a species several times likelier
in an act it lists and merely rare elsewhere - so nothing was missing in the way
a missing thing usually is. What was missing is that **no species listed an act
past 3**, so seven consecutive regions had no animal that belonged to them: the
same undifferentiated scatter each time, and a Marsh that reads exactly like a
Steppe. The twenty-three existing species now name the later acts they suit, and
the seven new ones give each region something that is only really at home there.

The raccoon matters more than the rest of that list. It is the loot goblin
(2026-09-11) and it was scoped to Acts I to III, so the one piece of the
wildlife system with treasure attached stopped appearing two thirds of the way
through the campaign it was built for.

**`wildlife_spawn_check` walked `[1, 2, 3]`**, which is the fourth hardcoded
three-act loop this campaign turned up, after the relic counter, the Chronicle's
`minimum_act` range and the campaign tiers' boss table. It walks `ACT_COUNT` now
and holds the same floor per rarity, per side, for every act on the road.

**The art is generated rather than posed**, unlike the boss frames of the same
day, and the difference is worth recording because it is a technique rather than
a preference: `animate_image` accepts a *URL* for its source frame, and every
PixelLab job already has a public no-auth download URL. So a sprite PixelLab
made can be fed straight back into PixelLab's animator by job id, with no image
data passing through an agent's context at all. That is what made eighty-two
frames across seven species a routine batch. The same route retires the caveat
on the boss frames whenever that is worth doing.

**Five ranged spells, and the two kinds that make them ranged, as of
2026-09-11.** Ember Fall and Stonefall are METEOR, Thorn Volley is VOLLEY, and
Frost Lance and Sky Lance are BEAM with a very short duration - a flash along
the aim rather than the channelled cone `beasts_breath` is.

**Every kind the game had resolved at the hero.** A nova, a drain, a shockwave
and a ward all happen where the caster is standing, and a beam is a line out of
their hands. Nothing struck a place the player had merely *pointed at*, which is
what "ranged" means in a game whose default answer to anything is to walk at it.

**The delay is the design, not a flourish.** A METEOR that resolved on the frame
it was cast would be a nova with a longer arm; the second it hangs is what the
bodies underneath it get to walk out of, and it is what makes aiming one a
prediction. Both kinds resolve through `_damage_area`, the helper the nova and
the shockwave already use, so nothing downstream learns they exist - the same
bound omens and Road Cards are built under.

**The telegraph is built from the damage's own numbers.** `Vfx.ring` is drawn at
exactly the radius the strike will use, over exactly the delay before it lands,
so the tell and the blow cannot disagree about where or when.

`spell_strike_check` holds five ways a ranged spell can be a lie, and **caught a
real one on its first run**: `clear_cooldowns` emptied the strikes in the air
and `cancel_channel` did not, so a fight that ended with a cast still falling
behaved differently from one that ended any other way - and the strike landed
on the Preparation screen, which is the one phase that is supposed to be safe.

Two things about that gate are worth knowing before writing another like it.
`EnemyField.enemies_near` casts every node in the group with `as Enemy`, so a
scripted stand-in in that group is skipped **in silence** - it reported three
working spells as dealing nothing. And a body at the aim point is hit by a
scattered volley about four times in five, which is a coin toss wearing a gate's
clothes; it stands under the first scattered strike instead.

**The second cut of fishing, and the first profession, as of 2026-09-11.**
The owner played the first cut and reported that it "did not happen
automatically while standing idle next to a fishing pond" and, in the same
breath, that it "should not be entirely automatic with no input but rather
require some degree of skill". Both are answered, and the second answer
retires a paragraph above: **the cost of fishing is no longer only standing
still.** It is a press to cast, a wait, a window to hook the bite, and a reel
held in a band while the fish fights - too tight and the line snaps, slack too
long and it is gone. `interact` is the action (T; Y on a pad; a thumb button
that wears the pond's own prompt), and it is the same action the rift gates
read.

Why the first cut "did not happen" is worth keeping: the beast's footfall
shoves the hero through `_beast_impulse`, the fishing code read the body's
whole velocity, and on a walking beast that never settled under the stillness
threshold. `Hero.own_speed` subtracts the shove. The same shove was playing
the hero's walk cycle on a stopped beast during Preparation, and the gait
itself kept rolling during Preparation - both fixed in the same change.

**Ponds are tilemaps now, at the edge of the field.** One sixteen-tile Wang
sheet per region, repacked into corner order by `tools/install_pond_tiles.py`
so `PondTiles` reads a texture and no metadata; a pond is a blob of water
nodes on a lattice, so every one is its own shape and size; and
`pond_water.gdshader` puts glints and rings on the water for a few sines and
a mask. The owner's ruling on placement - "beyond the city's paths, around
the edges of the playable map" - replaced the first cut's middle-of-the-field
bias, and it taught a lesson: **a random point in the outer band lands on
open ground about once in five hundred throws**, because that ground is four
corner pockets. Candidates are drawn from the band's open tiles now
(`Fishing.band_tiles`), and the clearance ring tolerates the border row - a
ring that refused it refused every corner, and the first run dug nothing in
any region. `fishing_check` digs every region and asserts the band.

**The Angler is the first profession, and it amends working rule 7.**
`MetaState.profession_xp` persists; the level is derived from it, capped at
`Balance.PROFESSION_MAX_LEVEL`, and only ids in `Balance.PROFESSIONS` are
read from a save or trained. **The bound is that a profession touches nothing
but its own craft**: the Angler waits less, hooks a wider window, reels a
wider band and tilts the rare fish a little. `fishing_check` maxes the Angler
and asserts every attribute is exactly what it was. More professions come one
at a time, each with its bound written here, exactly as this one is.

**Rifts and dungeons, as of 2026-09-11.** The raid's arena put to a second
use: `RiftArena extends RaidArena`. A rift is one stage - kills fill it, its
guardian steps through at full, the guardian falling closes it; a dungeon is
`Balance.DUNGEON_STAGES` of that with a door between them, where the player
goes deeper or leaves with what is banked; the clock collapses a stage and
pays only what was banked, and dying pays nothing, as it does in a camp.
Gates (`RiftGates`) are dug beside the ponds from `RIFT_FIRST_ACT`, with a
dungeon mouth every `DUNGEON_EVERY_ACTS`, and the run freezes the field for a
rift exactly as it does for a raid - allowed during Preparation as well,
because a rift is a detour and Preparation is when a player has time for one.

**The bound is that a rift pays what the road already pays**: run currency,
gear rolled on the same tables at the same tier, Shards, and a relic at the
bottom of a dungeon. Nothing new persists; `MetaState.rifts_closed` is a
statistic. `rift_check` names every key a reward may carry, so "and a
permanent +1" cannot arrive without failing it.

**The Gatekeeper's ascension, as of 2026-09-11.** Clearing the summit offers
the Warden a rank (`MetaState.ascension`, capped at `ASCENSION_MAX`) on the
results screen. **It is prestige and nothing else**: a title, a portrait on
the Hold's card, and a leaderboard multiplier read from the run summary. It
grants no level, no attribute, no card and no relic - levelling and gear stay
the only two scales. The score reads `summary["ascension"]` rather than the
autoload because `Score` is loaded by the headless tools.

**The Hold, as of 2026-09-11.** The hub the ruling approved, built as the
lobby reading rather than the second-battlefield one: a room with the
Warden's card - name, code, title, professions, Marks and Shards - and the
doors to the stash, the Ledger, the Chronicle, the codex and the board.
`HubScreen.adopt` moves each existing button into the room with its handler
intact, so the front door is New run, Co-op, The Hold, Settings, Quit and
nothing that worked stops working. Matchmaking is still the co-op screen and
the Ledger is still the Ledger; there are no accounts, so there is nothing
more a hub could honestly do.

**Twenty-one breeds for acts IV to X, and eight towers, as of 2026-09-11.**
Three breeds a region - a marcher, a vanguard, a warden or howler - with base,
four idle, four move and four attack frames each, every animation fed back
through PixelLab's animator by job URL. Each region's `enemy_ids` lists its
own three first and two veterans after, so the invader roll has something
familiar to reach; `WAVE_ACT_HP_SCALE`, `_DAMAGE_SCALE` and
`WAVE_INVADER_CHANCE` reach ten entries. **The first ten-entry table was
extrapolated and `curve_report` refused it** - mean pressure 0.70 against a
band of 0.26-0.46 - and the second was measured: the act multiplier past
III moves a percent a step, damage holds, and the extra bodies are the late
acts' teeth. The other half of that failure was the roster itself: the
report earns Gold from the average kill value of every breed, and twenty-one
new ones authored below the shipped average read as a harder game in every
act. Their values sit on that average now. Measured: mean 0.433 for one
player and 0.446 for four, last wave 0.75. The towers are two an element in the same Warden/Siege and
Skirmisher/Sniper pairing the ladder uses, each a combination the roster did
not have, and they join `ROSTER_UNLOCK_ORDER` ahead of the well.

**The soundtrack is a playlist, as of 2026-09-11.** Up to twelve songs an act
at `MusicPlayer.PLAYLIST_FORMAT`, dealt shuffled when the act opens and played
end to end, resumed from where they were on a scope change; a boss theme an
act at `BOSS_FORMAT`, arriving on a slow crossfade under a stinger and handing
back when the boss falls. **A slot with no file is not in the shuffle and
says nothing** - the soundtrack grows by dropping a file in - and an act with
no songs plays the regional track it always had. `docs/SFX_PROMPTS.md` names
all 140 recordings and marks the twelve synthesised placeholders that stand
in for the fishing and boss cues until they are recorded. `music_check` deals
through a documented seam (`MusicPlayer.test_slots`) because copying audio
around to prove the playlist would be a test of the importer.

**Yuri is the beast, and was redrawn, as of 2026-09-11.** The owner asked for
no baked shadows, a better-looking beast, and an idle beast during
Preparation. The new Worldstrider was generated from the owner's Scope 3
reference with PixelLab Pro, animated by URL, and installed with the feet on
the old ground line so `BEAST_FRAME_BASE_Y` did not have to move. A lesson
cost two template animations: **the Warden is the player and Yuri is the
beast**, and a session that confuses them spends generations on the wrong
subject. Read the design before generating a character.

**VFX are made the way PixelLab suggests, as of the same date.** A Pro sprite
sheet of concepts per family, the winners cropped and centred, then animated
with the constraint that the effect stays inside its own frame. The first
ripple was generated the naive way and walked off its canvas; the sheet route
gave the ripple, the splash, the cut, the burst and the embers in two calls.
The blade sweep is a tapered, feathered, additive strip now - `blade_shot`
photographed the old one and it had a hard straight edge where the swing
began and read as a shadow with a sword in it.

**`script_check` is a gate.** `--quit` compiles the autoloads and the main
scene; a parse error in a screen the menu has not opened sat there until a
player reached it, and `--script` cannot stand in because it has no autoloads.
The gate loads every `.gd` under the real autoloads and asks each whether it
can be instantiated.

### The three escape hatches — and why there are only three

The project is going all in on v4. That is the right call and it does not need
hedging: a runtime flag that keeps v3 behaviour alive doubles the surface that
has to be balanced, tested and understood, and the unused branch rots until it
is a liability rather than an option. **Do not add feature flags to preserve v3.**

What deserves reversibility is only what is *expensive or impossible* to
recreate. That is three things, and all three cost nothing to keep.

**1. `v3-final` — the last working v3 game.**
Branch at `v0.3.7`, pushed. A complete, released, verified-playable build: full
loop, 122/122 real assets, all gates green. If the migration stalls half-done,
this is what still runs. Never commit to it; it is a photograph, not a branch to
develop on.

**2. One gate, not scattered conditionals.**
A decision that could ever be revisited must be enforced in exactly one place.
Building is locked to Preparation via `RunState.can_build_now()` — every build
and upgrade path asks that one function, and nothing anywhere else tests the
phase inline. Reversing the decision is then a one-line change instead of an
archaeology exercise, and *that* is the escape hatch. It is also just better
code, which is why it costs nothing.

**3. The player's save.**
The only thing in this project git cannot restore. `MetaState` copies any save
whose version it cannot read to `user://beast_road_save.v<N>.bak.json` before
starting fresh, and never overwrites an existing backup — the first copy is the
valuable one, and a player bouncing between builds would otherwise lose the
original on the third launch. Verified by
`res://tools/save_backup_check.tscn`.

That check is **not** in CI: a discarded save legitimately emits a warning, and
the release gate fails on any warning. **Run it by hand before any release that
changes `SAVE_VERSION`.**

`References/` holds the owner's visual references, one per scope. They are the
target, not a mood board — check them before designing a screen.

---

## 2. Environment

| Thing | Path |
|-------|------|
| Repo root | `E:\Arxangel\GameDev\BeastRoad\` |
| Godot binary | `E:\Arxangel\GameDev\BeastRoad\Godot_v4.7.1-stable_win64.exe\` (this is a **folder**; the executable is inside it) |
| Godot project root | `E:\Arxangel\GameDev\BeastRoad\game\` |
| Launcher project | `E:\Arxangel\GameDev\BeastRoad\launcher\` (its own Godot project) |
| Design docs | `E:\Arxangel\GameDev\BeastRoad\docs\` |

Windows. Paths contain spaces — quote them in every shell command.

Verify the exact executable filename inside the Godot folder before running it;
do not assume.

### Godot version discipline

This is **Godot 4.7.1**. Your training data may predate it. Several
`Image`, `Resource`, and `TileMap` APIs changed across 4.2 → 4.7.

**Do not write GDScript from memory of an older version.** Before using any
API you are not certain about:

1. Check the local docs or run a one-line test script headless
2. If an API errors, read the actual error rather than guessing a replacement

Verify the project opens cleanly after every stage:

```
"<godot folder>\<Godot executable>" --headless --path "E:\Arxangel\GameDev\BeastRoad\game" --quit
```

Zero errors and zero warnings in that output is the bar. Not "it probably
works."

---

## 3. Working rules

1. **The target is the full game** (GDD §52 "Release Acceptance Checklist").
   Build toward a loop that closes: splash → menu → run → all scopes → three
   acts → summit → win/lose → payout → menu. Report honestly what is real and
   what is a stub.
2. **Never build anything in GDD §54 (Explicitly Out of Scope for 1.0).** If a
   system is on that list it was cut on purpose. §55 lists what is genuinely
   still OPEN, and none of it is gameplay.
3. **Data-driven, always.** Every tower, enemy, relic, spell, and terrain is a
   `Resource` (`.tres`) in `/data`. No hardcoded stat branches, no
   `if enemy_name == "bogkin"`. Adding content must mean adding a file.
4. **All tuning constants live in `game/scripts/Balance.gd`.** Every `[TUNE]`
   value in the GDD goes there as a named constant. No magic numbers in
   gameplay scripts.
5. **Systems talk through `EventBus`**, never direct cross-scope node
   references. The battlefield must not hold a reference to the city.
6. **`RunState` is the single source of truth for the current run.** No system
   caches run data locally.
7. **`MetaState` writes only what v4 sanctions, plus the hero.** Unlocked IDs,
   run statistics, settings, Tools, the four capped Sigil ranks, the Treasury
   cache (GDD §57) — **and, since 2026-08-20, hero level, experience, placed
   attributes and the campaign tier cleared.**

   That last clause is an owner re-cut of v4 §974, taken deliberately: the game
   is now a multi-run grind with Normal / Nightmare / Hell tiers, and a hero who
   resets every run cannot climb them. The amendment is recorded in GDD §54 and
   §974 with the same date.

   **The rest of the rule is unchanged and still binding.** No relic, tower
   level, run currency balance, building tier or Oathbound leader may persist.
   Hero power is now sanctioned; everything else on that list is still a design
   violation, and the answer is still to flag it rather than implement it.

   The bound that replaces §974's is `Balance.HERO_MAX_LEVEL`: hero growth is
   *capped*, not uncapped, and §54's cut of "uncapped permanent stats" survives
   intact. The stash has its own bound in `Balance.STASH_CAPACITY`, and gear
   grants *attribute points* rather than raw stats — so worn equipment is
   measured on the same capped scale as levelling and cannot out-run the curve
   the campaign tiers are tuned against.

   Gold, Wood, Food and Stone are still run currencies and still reset. Marks and
   Shards are account currencies and deliberately do not exchange with them: a
   stash purchase must never compete with the wall about to be overrun.

   **Amended 2026-09-11 (owner): the pantry persists.** Fish caught from the
   ponds are kept in `MetaState.fish` between runs - the first consumable in
   this project that survives one. Its bound is `Balance.FISH_MEALS_PER_RUN`,
   a run-scoped allowance spent from a persistent store, and no fish may grant
   an attribute point. See the fishing note in §1. Held items, ammunition and
   everything else listed above are unchanged and still reset.

   **Amended 2026-09-11 (owner): professions persist, and the ascension
   rank.** `MetaState.profession_xp` keeps how practised the Warden is at a
   craft, bounded by `Balance.PROFESSIONS` (only named crafts are read or
   trained) and `PROFESSION_MAX_LEVEL`; a profession may change how well the
   hero does its own thing and nothing about the fight. `MetaState.ascension`
   is a prestige rank capped at `ASCENSION_MAX`: a title, a portrait and a
   score multiplier, never power. Both notes are in §1.
8. **The battlefield freezes during a raid and resumes exactly as it was**
   (GDD §52, "Raid pause resumes the exact battlefield state"). It must
   therefore be suspendable as a unit — no system may keep ticking off a timer
   the battlefield does not own.
9. **Player-facing strings live in data, not in logic.** This matters most for
   the Oathbound leader system, whose framing v4 deliberately rewrote: leaders
   are sworn, ransomed or memorialised, never owned. **No enslavement language
   ships** (GDD §57), and that is a release requirement, not a preference.

---

## 4. Art pipeline — the rule that matters

**Every sprite path is derived from its resource `id` by convention.** A
`TowerData` with `id = "ember_spire"` loads
`res://art/towers/tower_ember_spire.png`. Nothing else.

This means: **replacing a placeholder with real art is overwriting a file.**
No code change, no manifest edit.

**But you must re-import.** Godot only re-imports changed art in the *editor*;
the runtime loads whatever `.godot/imported/` already holds, so a game or a tool
scene launched after overwriting a PNG keeps rendering the old texture — silently,
with no error. Every screenshot you take to check your art is a screenshot of the
previous version until you run:

```
"<godot folder>\<Godot executable>" --headless --path "E:\Arxangel\GameDev\BeastRoad\game" --import
```

CI already does this (`guard.yml`, "Import assets"), which is why builds were
right while local checks were stale. Verified art that disagrees with what the
game draws is this, every time.

- Placeholders live at the **exact final path and exact final pixel
  dimensions** listed in `docs/ASSET_MANIFEST.md`
- Every placeholder has pixel `(0,0)` set to pure magenta `#FF00FF` as a
  detection marker. Real art will not have this.
- `game/tools/asset_report.gd` scans `res://art/` and reports which files are
  still placeholders

If you add a new asset requirement, you must add it to
`docs/ASSET_MANIFEST.md` **and** regenerate its placeholder in the same
change. An asset that exists in code but not in the manifest is a bug.

Never draw art in code as a permanent solution. Placeholder PNGs only.

---

## 5. Code conventions

- GDScript, `snake_case` files and functions, `PascalCase` classes
- Static typing everywhere: `var speed: float = 200.0`, typed signal params,
  typed function returns
- `class_name` on every Resource script
- One node responsibility per script; no 400-line god scripts
- Comments explain *why*, not *what*
- No `get_node("../../..")` chains — use `@export` node references or EventBus

---

## 6. Two-person split

- **Person A — Combat:** hero, towers, enemies, waves, raid, fusion
- **Person B — Run layer:** city, crossroads, macro, meta, UI, save

`EventBus.gd` is the contract between them. When adding a signal, add it to
`EventBus.gd` with a typed signature and a one-line comment, and mention it in
your session report so the other side knows it exists.

---

## 7. Session report format

End every work session with:

```
DONE      — what now works, verifiable by running it
CONFORM   — the audit score before and after (run_tool.gd -- audit)
KILL Q    — the milestone's kill question (GDD §53) and your honest read on it
FILES     — created / modified
ASSETS    — any new placeholder requirements added to the manifest
BLOCKED   — anything needing a human decision
NEXT      — the single next step (do not start it)
```

Be honest in KILL Q. If a stage feels bad, say so — that is the entire point
of the gate.

CONFORM is a number, not a claim. A rising score means files and symbols now
exist; it says nothing about whether the feature is good. Never report a
milestone complete on the audit alone — §53's kill question is the real gate,
and the audit cannot answer it.

---

## 8. Shipping

Builds are made by GitHub Actions, never locally — no one needs Godot's export
templates on their machine. Publishing is pushing a tag:

```
tools\release.ps1 -Version 0.4.0
```

`.github/workflows/release.yml` exports the game and the launcher, zips the
game, and attaches both to a GitHub Release. The launcher reads
`releases/latest` and offers Install / Update / Play. Full details in
`docs/RELEASING.md`.

The repository must be **public** for the launcher to read the API without a
token. Never ship a token inside the launcher to work around that.
