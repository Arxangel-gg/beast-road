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
| One authored battlefield; procedural layouts cut (v4 §54) | cut for 1.0 | **DECIDED 2026-09-23: map modes in the settings, Random included. See below.** |

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

**Stage three is built, as of 2026-09-15.** The owner approved replacing the
per-road draft with freely spent points, and `eligible_discipline_nodes` is one
function now: the draft picks three of them to suggest and the training door
allows any of them, so the two can no longer disagree about what is trainable.
Four bounds survive and the gate drives each rather than reading a constant - a
skill point, its Food, `discipline_cap()`, and depth in the node's own tree. The
Mansion page lists the whole open tree under the road's three suggestions,
because copy saying "spend them on any node" over a page showing three is the
same failure as an effect nothing reads.

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
5. ~~The skills revamp.~~ Discipline stage three - freely spent skill points -
   was the open question this waited on, and it was answered and built on
   2026-09-15. See the note above.

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

**The soundtrack is a playlist, as of 2026-09-11.** Up to
`Balance.MUSIC_PLAYLIST_SLOTS` songs an act - twelve when this was written and
twenty-four since Acts II and III were recorded - at
`MusicPlayer.PLAYLIST_FORMAT`, dealt shuffled when the act opens and played
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

**The road has outskirts, and camps on them, as of 2026-09-12.** The owner
asked for the paths extended to the map's cardinal edges, camps split off
each entry path that patrol, leash and regenerate like a MOBA's jungle, a
fork that opens when both camps on a road fall, a war camp between the forks
that opens a dungeon, and the jungle expanded to cover it all.

**The core map is untouched; the outskirts are laid around it.** `BattleGrid`
pastes the authored 45x45 core at an offset inside a 75x75 grid, and lays the
outskirts from a template in lane-local coordinates - so every authored
route, build spot and pond rule still means what it meant, and the map grew
rather than changed. The near spawn of every road is its fork junction; the
two far spawns are the ends of the legs beyond it, barred until the fork
opens. **A route ends at the gate ring**, one node before the town, which is
what put the wall back in reach: a body at the gate hits the gate.

**A camp is a body in camp mode** (`Enemy.make_camp_mob`): no route, a full
aggro circle, a leash back to its home, regeneration while it walks back, a
patrol while nothing is near. It is not counted by `enemy_count`, so a wave
is never waiting on a camp to be cleared, and it pays more than a road body
and drops better - which is the reason to go and look for it. `Camps` owns
the state machine (locked, alive, razed, respawning), the props on the
ground, the barriers, the fork, and the war camp's dungeon mouth.
`camps_check` walks all of it through the real battlefield.

**Fishing's third cut, and swimming, as of the same date.** The owner played
the second cut and wanted a hold-to-cast that can miss the pond, depth that
matters, a band that drifts, bubbles that hold the rarer fish and bite a
swimmer, and a hero who swims rather than walks on water. All built: the
pond's depth is a field (`PondTiles.depth_at`, blue in the mask) deeper at
the middle, the safe band drifts by the fish's rarity against the Angler's
skill, bubble spots are a `PondBubbles` layer with their own rarer draws, and
the hero reads `Battlefield.water_depth_at` every frame. **The hero asks the
field, never the ponds**, because it stands in an arena as often as on the
road and an arena is dry. A swimmer draws over the water because every pond
root sits below the sorted layer; the submerged half is a `SwimCover` band
rather than a second sprite, because `animate_image` from a standing frame
does not swim - it was tried and it stood there waving. `swim_check` and
`fishing_check` hold it.

**Legendary gear wears affixes, as of the same date.** `GearAffixData` moves
one `Modifiers` key by one amount - the bound omens and Road Cards are built
under - and a piece rolls them from its own `uid`, so the same sword wears
the same affixes on every read and nothing was added to the save. The count
is by rarity (`GEAR_LEGENDARY_COUNT`) and the ordinary rarities wear none;
`GEAR_LEGENDARY_CEILING` bounds how far any one affix may move a scaled key.
`gear_affix_check` refuses a key `Modifiers` has no constant for, a fraction
on a counted key, and a roll that changes between reads.

**Achievements are statistics with thresholds, as of the same date, and this
is why they add nothing to working rule 7.** `MetaState.stat` is the one
reader; an `AchievementData` names a key and a number and grants nothing - no
power, no unlock, no currency. The statistics themselves (camps razed, forks
opened, swims, and the rest) are run statistics, which rule 7 already
sanctions. `guide_check` keeps a mirror of the reader's keys and refuses an
achievement naming one it does not answer, because a misspelt key reads zero
forever and nobody would ever know.

**The Guide, as of the same date.** A section of the main menu with the
lore, the how-tos with pictures, the resources, the items, a glossary, the
progress and the achievements - all `GuideSectionData`, `LoreEntryData` and
`AchievementData` in `data/`. **The pictures are photographs, not drawings**:
`tools/guide_shots.gd` drives the real run through every state a section
explains and writes `art/guide/<id>.png`, so a screen that changes is a tool
run away from a picture that matches. `guide_check` refuses a section whose
picture is not on disk.

**New players run the tutorial before co-op opens.** `tutorial_done` is set
when the coach reaches the first crossroad; the co-op button waits for it.

**Raids and rifts are a party decision in co-op, as of the same date.** The
owner's brief: a player taking a raid or a rift prompts the rest with a
timer; declining keeps them where they are; everyone is told who accepted and
who declined; the proposer decides when it is not unanimous; those who accept
enter together; when everyone goes the battlefield stays paused until the
first returns; otherwise the event runs beside the road, which goes on for
those who stayed.

**The host counts the votes and announces the outcome** (`PartyEvents`). A
guest proposes, votes, decides, returns and steps away by *asking* the host
(Requests 26-31), and what happened comes back as facts (53-58), so four
machines agree on who went because they were all told the same thing. Alone,
none of this happens: a solo raid is entered on the press.

**The field runs on with a hero absent.** This is the one place co-op touched
working rule 8, and it is an amendment rather than a break: the raid freeze
still resumes exactly *when everyone went*; when some stayed, the field is
not frozen at all - the absent hero is taken out of the world
(`Battlefield.set_hero_away`), hidden and stilled on every other machine, and
put back when its event ends. A fork waits for the party to be whole
(`_road_is_busy` counts an absent seat as a pack on the field), because a
road is a decision for everyone on it. A guest's event is its own arena, and
its reward is asked of the host **by result, never by amount**: kills capped,
stages capped, the numbers read off the host's own tables.
`party_events_check` drives the conversation with three seats and no network.

**The maze under a rift, as of the same date.** The owner asked for
Astonia's mazes and Diablo's rifts, a timed collapse with damage and a way
out, a progress bar, a chest with a loot burst and an exit portal.
`DungeonLayout` cuts corridors and rooms through rock on the raid's own
lattice - a wall is a `Cell.WALL` at the top level, so the raid's terrain,
cliffs and stepping rule draw and enforce it unchanged - with the vault at
the end of the longest walk. A rift is the same cut looser. Bodies appear on
floor a walk away and are steered by a flow field from the hero's tile
(`RiftArena.route_hint`), because a body told to walk at the hero through
rock stands against it. **A body's feet land on the tile they were dealt**:
`Enemy._ready` lowers the node by its feet anchor after the position is set,
which on a plain is harmless and in a maze puts the feet in the rock under a
corridor, from where no step is legal. `RiftArena._spawn` puts them back.

The clock no longer ends a stage on the frame it runs out: the stage
**collapses** - the exit opens where the hero came in, the ground bites a
fraction of their health a second, and they have `DUNGEON_COLLAPSE_SECONDS`
to reach it with what is banked. A fallen guardian leaves a **chest**: the
stage's currency bursts on the floor as drops, its gear is named and banked,
and the exit then pays that stage's currency *no second time* - the chest
changes where a stage is paid, never how much (working rule 7 is untouched).
`dungeon_check` holds the floor and the steering; `rift_check` the clock, the
chest, the doors and the reward.

**The polish pass of 2026-09-12, second half.** The owner played the camps
build and sent eleven screenshots with a long list. What follows is the part
of it that is a decision rather than a fix, and the fixes are in the commit.

**The road is fogged, and there is a map.** `FogOfWar` is one small image over
the field - a cell a tile, luminance for what has ever been seen and alpha for
what is seen now - stamped on the CPU ten times a second and drawn through a
shader whose bilinear read is what makes the edge soft. Heroes, companions,
towers and the town give vision; a body in the fog is not *drawn*, which is
the whole difference between a fog of war and a tint. `Minimap` darkens with
**that same texture** rather than a second copy, so the two can never disagree
about where the party has been, and M toggles it.

**It is generic on purpose, and that is what makes a dungeon fresh.** The
battlefield hands it the grid's extent and the road's vision; a raid or a rift
hands it the arena's and the hero alone, and every stage stands a new one up -
so going deeper is discovery again rather than a map you already own.
`fog_check` holds all of it, and it caught the one thing a hand test would
have missed: the town sees far enough that ground near it stays lit after the
hero walks off, which is correct and makes a careless test read as a bug.

**The bound is that the fog hides and never helps.** Nothing about targeting,
spawning, pathing or reward reads it: an enemy the player cannot see can still
see them. A fog that fed the AI would be a difficulty setting nobody chose, and
`Graphics.KEY_FOG` turns the drawing off without changing a single number.

**Every painted plant in the game was redrawn and every one of them breathes.**
The owner reported foliage with "cut off edges" that "appears low res from being
scaled up too much". Both halves were true and had the same cause: the art was
drawn at 48x64 and the field scales it 1.15 to 2.35 times. Eighty plants across
ten regions were regenerated at twice the canvas with an explicit margin, and
`Foliage.painted_scale` divides the new height by the kind's old one - so the
field's *stature* is exactly what it was and only the resolution changed. Then
each one was animated from its own PixelLab job URL, three frames apiece.

**`Foliage.kind_of` was reading the wrong thing for seven regions.** It took
everything after the first underscore, so "plant_hollow_marches_fern" had a
kind of "marches", which is in no table - and every plant in Hollow Marches,
Iron Steppe, Glass Fields, Ashen Reach and the Last Terrace swayed like the
default instead of like a fern. It matches against the known kinds now.

**The health ceiling moved to 16.** It was put at 9 the same day to stop a
five-minute enemy, and `elite_check` immediately failed: an elite with two
affixes came out the same as one with one, because the clamp was below what a
champion legitimately reaches. The ceiling is there to catch a *product* of
multipliers running away, not to flatten the ranks the curve is tuned on.

**A screen that cannot be seen is not waited on.** The dungeon's collapse is
now shown - rock, shake, dust and a shader fade - and `RiftArena._finish`
returns the reward on the frame when `DisplayServer` is headless. Without that
every gate that finishes a rift waits on an animation nobody is watching.

**The owner's second play report, 2026-09-13.** Eleven more screenshots and
a long list. What follows is the part of it that is a decision; the rest is in
the commits.

**A front-facing sprite is never mirrored.** Four separate reports of enemies
"facing backwards" turned out to be one fault: the field flips a body to face
its travel, which is right for a sprite drawn in profile and wrong for one
drawn head-on - mirroring moves the lantern into the other hand and the shield
onto the other arm. A contact sheet of all thirty-nine breeds and eleven bosses
says most of this roster is front-facing. `EnemyData.art_facing` names it, and
only the twelve genuinely in profile flip.

**The same mistake in the air.** A moth and a butterfly are painted head-up
from above, and the field was flipping them horizontally and adding a banking
roll - which leaves a top-down sprite pointing north however it flies.
`WildlifeData.art_top_down` turns them onto their heading instead. The ambient
butterfly had its own version of this: a "side" sheet that is a top view at an
angle, used whenever travel was mostly horizontal.

**A foe is a foe, not "somebody is alive".** `Enemy._foe_stands` asked the
field whether *any* hero lived, so a body kept walking at a hero who had gone
into a raid - present in the tree, hidden and stilled. That is the "enemies get
stuck targeting something invisible" report, and it is `Hero.set_present`'s
distinction one layer further out.

**Food is trimmed at the door, not at a source.** The owner reached Act III
with eight hundred Food. The Wheat Farm, the crates, the rations and the
pantry were each defensible and the sum was not, so
`Balance.CURRENCY_YIELD_SCALE` trims at `RunState.gain_currency` with a
fractional carry. **Gold is deliberately not trimmed there**: its problem is
late abundance rather than a wrong rate, and the opening envelope
`balance_test` guards is measured against today's income. Gold is answered
with sinks - trap levels now, tower specialisation next.

**One well, priced as itself.** It answered the whole recovery economy - the
Tonic, the rations, the pantry and the wounds - at a Warden's price, and a
second made that answer permanent. One a road, its own Gold and Stone price,
a level-one draught at 46% of what it was, and a slower refill. The scaling
with level is untouched, so a player who invests gets most of it back.

**A companion is fed, and it answers what is actually hunting you.** A bonded
bear watched a wolf pack take its owner apart, because the only thing a
companion ever looked for was an `Enemy` and a wolf is wildlife;
`Wildlife.threat_to` is the door it asks through now. And it eats: a meal to
call, a trickle to keep, and it goes home on its own when the larder is empty.
That is what makes the Wheat Farm a decision again rather than a number that
only goes up, and it is a toggle so a player can choose the Food instead.

**Towers ignore a sleeping camp.** Camp bodies patrol their own ground and
never take the road, so a tower in reach farmed one forever for spoils the
player never earned. They are invisible to a tower until something provokes
them - a camp roused and chasing a player home still meets the defence it is
running into.

**An unlocked slot the hero cannot fill is a dead slot.** Power opens on Act
II and Ultimate on Act III, both drawn from the same three-a-road rotation as
everything else, and a player who kept taking what was in front of them
reached Act V with a tier-three Mansion and two empty slots. One of the three
offers now fills an empty unlocked slot whenever the pool holds one.

**Music encodes at Vorbis q1.** Eighty-eight songs at q4 were 222 MB of a
300 MB game. Under combat, weather and a war horn, q1 is not the thing anybody
hears; sound effects stay at q5 because they are short and exposed.

**And the second half of that report.** An act now *ends*: the kill flashes
and slows, `boss_fall.gdshader` drains the colour and inks the field away, and
the thing that was killed is held up full-screen with its name and its act
before the road ahead is offered. Every act, not once a boss -
`MilestoneCinematics` already owns the once-ever beats and marks them seen,
and this is the punctuation at the end of every act, which has to land every
time or it is not punctuation.

**A blow is felt where it lands.** Every shake in the game was a fixed
magnitude wherever it happened, so a tower firing on the far road rattled the
screen as hard as something hitting the hero. `EventBus.camera_impact` carries
a position and a weight, and the rig scales it by distance from what the
camera is watching. It is emitted from `Enemy.take_damage` - the one funnel
every blow in the game goes through - with the weight taken from what the blow
removed, so a shot that chips a boss is a tremor and one that halves a runner
is a hit.

**Over-farming is answered by the species.** Kill enough of one animal inside
a window and a savage elite of that kind is sent to hunt the hunter: bigger,
tougher, rabid-behaved, and worth six times the bounty. It is a consequence
rather than a punishment - a player who wants the fight can start one on
purpose. The window is what makes it about farming: a dozen deer over an act
is a road lived on, a dozen in two minutes is a cull.

**A fish can be given away.** To the spirit at your shoulder, which heals it
and stops it eating for a while, or to a player beside you who is hurt. **The
meal cap counts fish rather than mouths** - otherwise feeding the bear is a
way round the one bound the pantry has, and the recovery economy goes with
it. The rarer fish carry a short damage-and-speed buff for whoever ate it.

**Rustwood and Ashen Reach were fishing in lava.** Their pond tilesets were
generated as molten rock, which against Rustwood's red autumn ground is
invisible - reported as "Act 5's ponds aren't there but their foliage is".
Both are water now. `tools/install_pond_tiles.py` is back and documents the
rule the lost version got wrong: a tile's place on the sheet comes from its
own `bounding_box`, never from its `wang_N` name or its `original_position`.

**A tower chooses what it becomes, as of 2026-09-13.** Ten levels was a
ladder; the owner asked for a split at five and something of its own at ten,
so that a road of eight towers is eight builds rather than eight numbers.

Two paths on every element, which is what makes them learnable: **Focus** is
fewer, harder, further; **Spread** is more, faster, wider. The names differ by
element - a concentrating Fire tower is a Lance, a Water one an Icespear - and
the mechanics do not. The choice is free, made once, at the moment the fifth
level is bought; the capstone arrives with the tenth and is decided by the
path already taken.

**The bound is the one every addition here is held to: a path may only move a
number the tower already has.** Damage, rate, reach, targets and blast all
exist and all are in the curve `balance_test` measures. A path that added a
*mechanic* would be a content system wearing an upgrade's clothes, and the
ten-act pressure curve could not be read against it.

`tower_path_check` measures rather than asserts the constants - it reads the
tower's own numbers before and after - and it caught the hole on its first
run: the choice could be taken the moment a tower was built, which skips the
ladder the split exists to put a decision on.

**An act boss fights, as of 2026-09-13.** The owner walked up to the Act IV
boss and was not attacked. It was true of all eleven: a boss authored
`contact_damage` and nothing else, walked at 46 units a second toward the
town, and swung only at whatever it happened to touch - a player standing two
body-lengths away was in no danger at all.

Every boss now has two things the roster does not: a **slam** it telegraphs
and lands in a circle, and a **volley** it throws at whoever it can see. Both
are authored per boss on `EnemyData`, with eleven different shapes - the
Gatekeeper slams hardest and barely throws, the Drowned Choir throws five and
barely slams - so no boss is a branch in code (working rule 3) and a boss with
neither authored fights exactly as it did.

**The bound is that both are `contact_damage`-scaled and go through the same
`take_damage` every other blow does**, so nothing downstream learns that
bosses have abilities. `curve_report` reads 0.433-0.446 mean pressure across
party sizes, unchanged: a boss fight is not wave pressure, and the curve the
ten acts are tuned to is measuring waves.

**The well is drunk from, as of the same date.** A full well shows a gauge
and prompts; the draught is taken with Interact by a hero who is hurt, and
a hero who is fine walks past a full well and leaves it full.

**There is a fifth attribute, Resolve, as of 2026-09-13.** The owner asked for
"a new 5th stat attribute for our player and gear for more build diversity".
Four attributes had four fantasies - hit hard, have a lot of health, move and
swing fast, cast - and the gap between them was the difference between a
*bigger* pool and a pool that is *harder to empty*. Vigour is the first.

**Resolve is what does not break.** Blows land softer up to a hard ceiling,
wards given to the hero are worth more, and the spirit at their shoulder is
tougher, because it stands where they stand. Every one of those numbers already
existed: `Health.damage_scale` is what Iron Roar has always used, `add_shield`
is what Aegis has always granted, and a spirit's health has always been its
damage times a constant. A fifth attribute that introduced a *mechanic* would
be a content system wearing an attribute's clothes - the bound omens, Road
Cards, spirit traits and tower paths are all built under.

**It adds no points, and that is the whole argument for it being safe.** A
level still grants one point, and gear still grants what the budget pays for
(working rule 7); five attributes is the same power spread five ways rather
than four. Nothing in `curve_report` or the campaign tiers had to move, and
`attribute_check` asserts the "one point a level" contract first and hardest,
by *taking* a level rather than by reading a constant.

**Vigour and Resolve are not the same answer.** Vigour is a bigger pool;
Resolve is a pool that empties slower, and it multiplies every heal, every
draught and every fish in the game. Mitigation is therefore the one number here
that is capped rather than merely scaled - uncapped it compounds with the pool
and with healing into something nobody is tuning.

**Sixteen kinds of gear favour it, two in every slot.** Reachable only as a
*secondary* bonus is reachable only by accident, and nobody builds for an
accident. Two a slot rather than sixteen in one, because `Stash.roll` picks by
weight across every kind rather than per slot: piling them into one slot would
quietly make that slot commoner and every other rarer, which `balance_test`
already caught once. The top two rarities now dress four and five attributes
(`GEAR_AFFIX_COUNT` ends `4, 5`) and the budget is still *divided* - five is
the ceiling because a hero has five places to put it.

**Resolve is last in the enum on purpose.** `hero_attributes` is positional on
disk, so a save written before this reads its four numbers into the first four
slots and arrives with Resolve at zero. Nothing migrates, `SAVE_VERSION` did
not move, and `attribute_check` drives a four-entry hero through the real load
path to prove it. **Never reorder that enum.**

One consequence worth knowing: widening `Stash.ATTRIBUTE_COUNT` re-draws the
*secondary* attributes of every piece already in a stash, because the pool a
piece's name draws from got bigger. The primary is the kind's own and does not
move, and the budget is untouched, so no piece became stronger or weaker - but
a player's Oathbound sword may dress different attributes than it did. That is
the price of deriving affixes from the name rather than storing them, which is
what keeps them out of the save.

**Ranged enemies throw five different things, as of 2026-09-13.** The owner
reported that "the ranged enemies all have one attack and the same one". They
did, literally: `role == HOWLER` built one `EnemyProjectile` and nothing else
varied, so fourteen breeds across ten regions posed one question between them
and a player who learned to sidestep in Act I had learned the whole ranged
game.

**What separates the five is the verb that answers them.** Sidestep a BOLT,
spread out against a SPRAY, leave the circle a LOB marked, step off a LANCE's
line, outrun a HEX. Authored per breed on `EnemyData.shot` (working rule 3), so
another shooter is a file rather than a branch, and a breed that authors nothing
throws the bolt every breed threw before this.

**The bound is that a shot changes the shape of a blow and never its size.** A
fan *divides* the strike it rolled between its three shots; a mortar and a lance
land that one strike on whoever is standing there; a hex trades part of its
damage for mana. Nothing multiplies `contact_damage`, which is what lets the
ten-act pressure curve still be read against the same numbers - `curve_report`
models a ranged enemy as its contact damage and would never have noticed.
`enemy_shot_check` **measures** that rather than reading it back, by firing each
shot at a body with a known pool.

The hex is the only one whose threat depends on *who you are* rather than where
you are standing, and that is deliberate: mana is the one resource that matters
to a caster and not at all to a swordhand, so the five shots vary along two axes
instead of one.

**Two real faults fell out of gating it, and both predated the change.** A shot
only ever resolved where its *destination* was, which was invisible while every
shot was aimed at a body - so the boss volley added on the same day, which aims
at points either side of its target, flew straight past whoever it was thrown at
and burst at the far end of its range. And an area blow drawn from chest height
struck nobody, because `strike_the_players` measures from a body's feet. Ground
blows are laid on the ground now, and a shot hits what it passes through.

**"Everything of the player's" has one definition.** `EnemyGroundStrike.strike_the_players`
is it: heroes and their spirits, never the town and never a tower. The boss slam
had its own copy and now calls this one, because two copies of that rule is how
one of them ends up forgetting about companions. A shooter whose target *is* the
wall falls back to an ordinary bolt, so a siege breed does not quietly stop being
able to besiege.

**A blow already thrown lands even if its thrower does not.** `EnemyGroundStrike`
is a node under the battlefield rather than a timer on the enemy, so it survives
the death of whatever threw it - otherwise the correct play against every mortar
breed is to kill it after it commits, and the telegraph becomes a reward rather
than a warning. Living under the battlefield is also what freezes it for a raid
(working rule 8) with nothing having to know it exists.

**Three more crafts, and the ground they work, as of 2026-09-13.** The owner
asked for woodcutting, mining, smithing and fishing as skills that persist
across runs, with resource nodes of different rarities and cooldowns, gems out
of the ground, a chance at rarity when a practised smith sets a gem, a place to
smith, and **nothing at all in the store on a new account**. The framing was
"there isn't enough to do in the game".

**The Angler was the shape; these follow it.** A craft touches nothing but its
own craft (2026-09-11). A maxed Woodcutter fells faster and gets a little more
out of the same tree; they do not hit harder, move faster or carry more health.
`gathering_check` maxes all four and fills the store, then reads every attribute
back.

**It amends working rule 7 once more: materials persist.** `MetaState.materials`
is the wood, ore and gems the road gave up, and the bound is one sentence - **a
material is an input to the Smithy and nothing else.** It grants no attribute,
buys no tower, pays no wave and does not exchange for a run currency. What it
makes is *gear*, which is already on the capped scale levelling shares, rolled
on the same `Stash` tables a drop is. So the third power scale this project
keeps refusing does not arrive through the back of a mine. Additive, like the
pantry and the spirits: a save written before this has no `materials` key and
reads as an empty store, which is also what a new account is. `SAVE_VERSION` did
not move.

**Where the nodes go is the owner's other instruction and it is the interesting
half.** They sit beyond the inner square the four roads make - the same outer
band the ponds and the rift gates use, drawn from `Fishing.band_tiles` because
open ground out there is four corner pockets - and **the further out a spot is,
the rarer the node it may grow**. Practice is the second gate: a rare node is
not drawn at all until the craft can work it. So the ground near the city grows
common wood forever, the good seams are past the camps, and a Duskstone geode is
not merely rare - it is somewhere a new Warden would not have found it and could
not have broken it open.

A node holds a few swings and comes back on its own clock by rarity, so a region
is never a fixed budget emptied in Act I and walked past for nine more acts.
Working one is a thing you stop to do: walking away takes you off it, exactly as
it takes the line out of the water.

**The forge is in the Hold, beside the stash**, because materials persist and a
run does not. Wood and ore decide how good a piece it may attempt; the gem
decides how often the piece climbs a rung of rarity, and the Smith adds to that.
**The odds are drawn on the screen before anything is spent** - a forge that hid
its chances would be a slot machine.

**A gem is a lottery ticket rather than a promise**, and that bound is gated: a
maxed Smith setting the best gem in the game must never reach the top rarity, or
the rarest gear stops being found and starts being bought - the same failure
`exchange_check` exists to prevent on the other side of the economy. The forge
validates, then spends, then makes, in that order, and puts materials back if a
later step fails; the scarce half of the price is the gem, and a forge that ate
one on a race nobody can reproduce is worse than one that refuses.

**The hero visibly works, and it is the heavy swing sheet.** That is a choice
rather than a gap: the Warden's frames came from a PixelLab character that no
longer exists in the account, so a new eight-direction state is not a generation
away, and at 168x160 an axe into a trunk and a two-handed sword into a body are
the same body doing the same thing. `Hero.play_work_swing` is one function and a
dedicated chop or mine sheet drops into it by name.

**The six nodes that did nothing now do what their cards say, as of
2026-09-13.** The owner played the tree and reported that "the skills were all
boring". A third of it was worse than boring: `DisciplineEffects` had listed six
`effect_id`s since 2026-09-09 as authored, described to the player, priced at a
skill point and a lot of Food, and **read by nothing at all**.

- **No Ground Given** - a perfect evade is this game's block, and it empowers
  the next *finisher* rather than every swing after it. Spent by that blow
  whether or not it lands.
- **Open Vein** - a body with nothing else within a body-length is a body you
  have time to place a blow on. Rolled per body, because a crowd has no isolated
  enemy in it by definition and a roll per swing would hand the crowd one
  verdict.
- **Blood Remembers** - the Tempest takes the brands with it, one extra blow per
  branded body, the whole burst capped so a road of forty marked bodies is not a
  one-cast wipe.
- **Break the Host** - an elite falling while a channel runs buys it a moment
  more, up to the hard cap its own card promises.
- **Unbroken Oath** - a ward puts a shield on the walls near it. A shield rather
  than health, which is the card's own distinction: "never permanent tower HP".
- **Dawn Bell** - the towers fire faster for a while. The window lives on
  `RunState` rather than on each tower, so a tower built during it is hasted and
  one sold during it leaves no timer behind, and it counts down on the
  battlefield, which is the thing that freezes for a raid.

**`DECLARED_ONLY` is empty, and the list stays.** A future node that cannot be
wired in the same change belongs there, visibly, rather than quietly missing
from both lists.

**And "implemented" is now checked rather than trusted.** `DisciplineEffects`
said in as many words that a key added to `IMPLEMENTED` without a consumer "is
the exact lie this file exists to prevent, and `discipline_check` cannot detect
it". It can: every key on that list must be named by some script other than the
ledger. A grep is a weak proof of behaviour and a strong proof of *wiring*,
which is the half that was silently false for twenty-one effects. Checked by
adding a key nothing reads, which the gate refused.

**There is a fourth discipline, the Arcane, as of 2026-09-13.** The owner asked
for "a wizard spec more ranged caster type build". Everything a caster needs
already existed - Focus, a mana pool, five ranged spells, a meteor and two
lances - and the skill tree had nothing to say about any of it: three trees, all
melee, a bruiser and a paladin and a berserker, all three of which answer every
question by walking at it.

**Ten nodes, the same shape as the other three**, and half of them simply hand
the player a ranged spell that was already in the game and that nothing in the
tree wanted. The other five are what make it a build, and every one of them
moves a number the caster already has: the pool, a reach, a cooldown, a ward,
and a spell's own damage.

- **Wellspring** gives mana back on a kill, as a *share* of the pool rather than
  a number - a flat refund is everything at level one and nothing at level a
  hundred, which is the shape that makes a node feel dead by Act III.
- **The Long Reach** throws everything further. Reach rather than damage,
  because damage is what every other tree already sells and where you are
  standing is a caster's whole advantage.
- **Siphoning Veil** leaves a ward behind a cast, deepened by Focus.
- **Quickening** takes a share off the *next* cooldown, in a window that closes
  the moment the player stops casting. A cast that shortened its own cooldown
  would be a rate increase; one that shortens the next is a reward for casting.
- **Echo of the Weave** casts twice, sometimes, the second for a fraction. The
  `_echoing` flag is what stops an echo echoing - without it a one-in-four
  chance is a geometric series rather than one extra cast, and the tail of that
  series is where a build stops being balanceable.

**`DISCIPLINE_NAMES` is the one list now.** Three screens kept their own
three-entry array of tree names, which is three chances to add a fourth and
remember twice.

**The gate caught the change that added it, which is the point of the gate.**
`arcane_reach` was read through a helper on `DisciplineEffects`, so the key was
named nowhere a consumer could be seen and the new "implemented means named in
code" check refused it by name. The reach is computed at the caster now, in one
function every throw in that file goes through - a reach applied at four of five
call sites is a node that works on some spells.

**Gold has somewhere to go for the whole run, as of 2026-09-13.** The owner
reported that gold "generates too much and becomes meaningless as there is no
reason to have so much" and asked for it to "stay hard earned with continual
sinks". Both halves are here, and the complaint was measured before it was
believed: `curve_report` prints the purse, and a ten-act run earned about 7,700
Gold while capability went flat from wave 48 - the last third of the road paid
for nothing at all.

**The income came down a little.** `KILL_ACT_VALUE_SCALE` now tops out at 2.76
rather than 3.20. That is a 6% smaller purse at wave 72 and **no change to the
curve at all** - mean pressure moved 0.433 to 0.434 - which is itself the proof
that the surplus was never buying anything.

**The Quartermaster is the sink**, and it is three standing orders taken as
often as the player likes during Preparation: mend the wall, mend the towers,
rearm every trap. One button on the bar offers whichever of the three would
actually do something, cheapest worry first.

Three rules make it a sink rather than a shop, and `balance_test` holds all
three:

- **It never runs out.** The price is geometric and unbounded. A sink with a
  ceiling stops being a sink the moment it is reached.
- **It always gets dearer.** A price that stops rising turns a big purse into a
  second economy.
- **It buys nothing new.** Every order returns something the player already had
  and already paid for. If one ever granted power it would be a gold-priced
  power scale the acts were never tuned against.

Wood is still the cheap way to mend a wall and there is still only so much of
it. Gold is the way there is always more of, and it gets dearer.

**A raid camp's elevation can be seen, as of 2026-09-13.** The owner asked for
"raids to be overhauled, especially the stairs and the upper levels" and for "an
elevation tileset for this so it looks correct".

**The elevation itself was never the problem.** A camp has had ledges, ramps, a
stepping rule and cliff collision since it was built, and all of it is real -
`can_step` is one function and the hero genuinely cannot walk up a bank. What it
did not have is any way to *see* the height: a raised plate was the region's own
ground with a two-pixel line round it, which reads as a paint mark on flat earth
rather than as something you are standing on top of.

So the south edge of every ledge has a face now - the exposed earth bank under
it, grass overhanging the top - and a ramp has steps cut into that same face.
**South only**, and that is not a shortcut: the camera looks down and slightly
along, so the south side is the only face a player can ever see, and a north
face would be drawn behind the plate that owns it.

**Drawn, not baked**, and the first cut got that wrong. The plates are baked
into one texture at half a texel per world unit, which is right for ground; a
bank authored 64 pixels tall blended into that bake came out 21 pixels and was
then scaled back up on screen. It read as a coloured stripe - exactly the "low
res from being scaled up" the owner reported about the foliage. The faces are
one `Node2D` and one `_draw` now: a few hundred textured quads on a single
canvas item, which is the same argument the plates were baked under.

**One bank is authored and ten regions use it**, tinted to the region's own mean
ground colour and darkened, because a face is the side the sun is not on. Left
untinted, a Saltpan ledge is the same brown earth as a Rustwood one and a snow
camp has a summer bank in it.

**The scope column wraps on a short screen, as of 2026-09-13.** A landscape
phone is 592 tall; six thumb-sized squares with their gaps are 592. So on that
one shape the scope column was the entire screen height and its last button sat
on an ability slot - which is what `layout (phone landscape)` failed on the
moment the sweep reached it.

**Wrapped rather than shrunk, and that is the second time.** Shrinking was tried
on 2026-09-12 and reverted: it produced 49px targets under the 92px a thumb
needs, which trades one layout fault for a worse one. A second column keeps
every square the size it has to be and takes another 92px of width - which a
landscape phone has and an upright one does not need, so it only ever appears
where it is the answer. The bar is a `GridContainer` of one column now, because
a box cannot become two without being rebuilt.

`HUD.nav_column_width` is an instance method that asks the bar, and
`one_nav_column` is the static answer for callers with no HUD to ask -
`TouchInput` reserves the thumb zone before the HUD exists.

**And one number was quietly wrong the whole time.** `ACTION_BUTTON_COUNT` said
five while the action bar had six buttons, and every phone layout measures its
bottom band from that constant. It is hand-kept because `_action_band_height` is
static and runs before the bar exists, which makes it exactly the kind of number
that drifts - so `_build_action_bar` asserts the two agree now, and the next one
fails loudly instead of under-measuring a row.

**Everything regional is re-laid in one function, as of 2026-09-13.**
`Battlefield.refresh_terrain` re-skins the ground, the roads, the water, the
rift gates and the camps when an act changes. Two things were not in that list.

The **gather nodes** were left out when they were added on the same day, so from
Act II onward the road would have grown Act I's trees, in Act I's places,
preferring Act I's region. And the **treeline** was never in it at all - a run
that began in the Verdant Maw walked through jungle canopy in the snow for nine
acts.

Found by reading the function rather than by anything failing, which is the
argument for the list living in one function: the comment inside it already
warns that a second path listening to a signal is a second path that can be
right when this one is wrong, and it names a real case - a snowfield with green
jungle ponds in it.

`gathering_check` drives the real `refresh_terrain` rather than calling
`scatter()` itself, because the failure is an *omission from a list* and a test
that scatters by hand passes with the omission still in place. Checked by
removing the line, which the gate refused by name.

**Two Arcane nodes were authored against the wrong enum, found 2026-09-13.**
`Role` is `ATTACK, DEFENSE, POWER, PASSIVE, ULTIMATE, AUGMENT` - Ultimate is
**4** - and `slot_index()` maps it to slot **3**. The tree was written against
the slot numbers, so Sky Lance and Stonefall landed on PASSIVE carrying a spell.
A passive is trained and never slotted, so both spells were content that could
never reach the combat bar.

`discipline_check` refuses a `spell_id` on a node that sits in no slot now. It
is the same failure as a misspelt effect key one layer up: the node trains, the
card draws, and the thing it promised is unreachable. Checked by putting one of
them back, which the gate named.

**And the dead-slot guarantee only ever filled one slot.** The fix of earlier
the same day wrote every role into `discipline_offers[size - 1]`, so with Power
*and* Ultimate empty the Power offer was written and immediately overwritten by
the Ultimate one - half the state the owner screenshotted was still unreachable.
Each role takes its own place from the back now, and index 0 is never taken so
the draft always keeps one offer that is not dictated by a dead slot.

The gate that caught it tests the state that was actually reported - trained for
five acts, just never into an active slot - rather than an empty hero. A hero
with nothing trained has depth zero everywhere and genuinely cannot be offered a
tier-three Ultimate, which is the tree working rather than a slot being dead.

**And it took a third cut, because a served role did not spend its place.** The
second cut skipped a role the shuffle had already covered on its own, which is
correct - and skipped it *without taking that offer's index out of play*, so the
write position stayed on the back offer and the Ultimate write landed on top of
the very Power node that had satisfied the check. The offer proving the slot was
served was the one destroyed. The two ways a role gets served - dealt by the
shuffle, or placed deliberately - now agree about which index is spent.

**It failed on CI and passed here, and that half is the more useful lesson.**
The gate called `RunState.reset()`, which rolls a *fresh* seed, so it read a
different three offers on every run; the fault needs a Power node dealt into last
place, which is about one road in six. Measured at 7 of 40 seeds. That is the
fourth time this project has shipped a gate whose verdict was a coin toss - after
the scattered volley, the 34% banner and the unseeded fishing stream - and the
answer is the same one every time: **a guarantee is a property of every road or
it is not a guarantee.** It walks 24 fixed roads now and names each one that
breaks it.

**Twelve tutorial steps fired on the wrong thing, found 2026-09-13.** A step
names its trigger by index; `TutorialStepData.Trigger` gained `RAID_AVAILABLE`
at position seven after the data was written, and every step from there on
shifted by one. A new player was told about raids when they found gear, about
gear when they levelled, about levelling when they cast - and never about rift
gates at all, because the last step named index 19 in an enum of nineteen.

**Nothing failed and nothing could have.** Godot does not clamp an out-of-range
enum on a resource, the coach simply never matched it, and the tutorial is the
one system whose audience cannot tell that it is wrong. It was found by walking
every `.tres` in the project against its own script's enums - the same sweep
that caught the Arcane roles an hour earlier.

`tutorial_check` holds four things: every step's trigger is in range, every
trigger has a step, every trigger is fired by some script, and every step says
something for long enough to read. The first two together are exactly what the
shift broke - an out-of-range index at one end and a gap at the other - and
putting the fault back names both.

**The lesson is about enums that data indexes by number.** `Role` and `Trigger`
both grew a member in the middle of their life, and both left content pointing
at the wrong thing in perfect silence. Appending is not enough on its own: what
makes it safe is a gate that walks the data against the enum, and there are two
of those now.

**The earth's wrath, as of 2026-09-14.** The owner asked for the elements to
answer the road: lightning that chains further in a flood, floods that slow
and stop the dash, tornadoes that tear towers down, wildfires that spread
through the foliage and scorch the ground, meteors drawn by fire, earthquakes
by magnitude - and, from the ChatGPT notes they forwarded, charged ground,
telegraphs and compound disasters. What follows is the part that is a decision.

**Wrath is hidden, and that is the design.** `WeatherSky.wrath()` is a floor
that only rises for the run plus a heat that decays, fed by wildlife killed by
players and enemies and never by other wildlife - that is the cycle. There is
no readout and there must never be one: the signs are the `data/wrath/unrest_N`
lines - the birds, the ground, the sky - said once each time the anger climbs
a step. An act eases it by `WRATH_ACT_CARRY` and never resets it (owner,
2026-09-14: "may reduce earth's wrath accumulation but not reset it
completely").

**Every event goes through the doors every other blow uses** - `take_damage`,
`strike_the_players`, `Wildlife.wound_within`, `Tower.hurt` - so nothing
downstream learns the earth exists, and every one is rolled from a seeded
stream on the host and told to the guest as a fact (`CoopRelay` 53-61). The
guest draws and never hurts; `wrath_check` holds that for each of them.

**Charged ground is one number on a figure the tower already has.** A strike
leaves a storm core, a blaze or a stone burning ground, a flood at the knee a
basin, a quake a fault; the towers of that element standing on it deal
`ZONE_TOWER_BUFF` more, falling toward the edge, for `ZONE_SECONDS`, no more
than `ZONE_MAX` at once, and the same kind over the same ground renews rather
than doubles. That is the bound omens, Road Cards and tower paths are all
built under, and it is what lets the ten-act curve still be read: a zone that
added a *mechanic* would be a content system wearing a buff's clothes.

**A wildfire is bounded three ways, because an unbounded one burned 193
plants and was still going.** Spread decays by generation, `WILDFIRE_MAX_FIRES`
burn at once, and one blaze lights `WILDFIRE_MAX_LIT` plants before it can
only burn down; a heatwave lifts the last. A woodcutting tree it reaches never
grows back; a plant grows back with the next act's scatter.

**Major disasters are telegraphed.** A quake hums for `QUAKE_WARNING_SECONDS`
- the line, a rising tremor, every animal running - and a tornado's dust
streaks in for `TORNADO_WARNING_SECONDS` before the funnel is born. The
meteor's warning is its shadow. A blow from nowhere is the thing the notes
warned against, and the gate asserts the warning is not the event.

**What was taken from the notes and what was not.** Taken: charged ground
(their "hotspots"), telegraphs, the tiers as world signs rather than a bar,
fire whirls (a funnel through a fire carries it), dry lightning (a strike with
no rain lights the brush, more under a heatwave), conductive floods (already
the chain rule), and the historic trace (scorch, fault cracks). Not taken, and
why: volcanic fissures, sinkholes, landslides, hail, dust storms, mudslides,
geysers, floods that freeze and supercells are each a new terrain state or a
new movement rule rather than a number the game already has an opinion about,
and would arrive as content systems beside the six that exist. The right time
to argue for any of them is after the six have been played.

**The flood is drawn as water, not as a colour.** `flood_sheen.gdshader` reads
the frame beneath it (`hint_screen_texture`), bends it by the surface's slope,
cools and darkens it by depth, and lays foam along the shore, glints on the
crests and rain rings on the sheet. `Graphics.KEY_WATER_REFRACTION` is the
low-end switch back to a flat sheet, and it is off headless, where there is no
frame to read. Like every shader here it cannot be seen by a gate:
`shader_lint_check` holds the grammar and `sky_shot` photographs it.

**The ground has its own weather, as of 2026-09-14.** The owner forwarded a
second set of notes - a coarse environmental grid, event-driven, staggered,
replicated only on threshold crossings, never visually square - with six
foundation requirements attached. `Climate` is that grid, and each
requirement is a rule here rather than a preference.

**A cell is eight tiles a side and carries a heat, a wetness, a soil byte and
whether it is awake.** The heat is degrees above or below the sky's; the
wetness runs from tinder to standing water; the soil byte is *reserved* -
only NORMAL is written - so lava, ice, mud, ash and the rest plug in as
values of a byte that already exists rather than as a second grid. A cell
with nothing happening to it is asleep and costs nothing.

**Sources add, with falloff.** `add_heat` and `add_wet` spread a source over
the cells within a radius, most at the centre, and stack: three fire towers
side by side make a hotter spot than one, which is the whole reason to have
cells rather than a number. A fire tower's shot warms its ground, a water
tower's cools and wets it, a burning plant warms and dries, a strike and a
stone warm, rain and flood wet everything.

**Nothing on screen or in play shows the square.** Every read is a bilinear
sample across the four nearest cells, the picture is one texel a cell drawn
through a linear filter and broken up by noise, and the guest *eases* toward
a band it is told rather than snapping to it. `climate_check` measures the
slope between two cells and the ease on a mirror.

**Only band crossings travel.** `NORMAL -> HOT`, `WET -> FLOODED`: a cell is
told once when it crosses and never while it stays. The gate counts.

**The things that read the sky read the ground now.** The wildfire's spread
asks the dryness under the plant, a well evaporates by the temperature it
stands in, dry lightning refuses soaked ground, and the earth's own wildfire
refuses a soaked point. `wrath_check` and `sky_check` reset the climate dry
after every rain they make, because the ground remembers rain the way the
sky does not.

**Interactions are one line each in `_tick`.** Heat dries wet ground; that is
the one this pass ships. Wind on the fire, cold freezing the wet, moisture
suppressing ignition further - each is a line beside it, not a system.

**F7 shows the cells** - band colours, figures, awake markers - for tuning,
and is not rebindable (the pad is full). The player is never shown a number.

**One consequence worth knowing:** a blaze heats the ground it burns on, and
hot ground lifts the wildfire's own bound (`WILDFIRE_HOT_LIT_SCALE`), so a
fire grows its own weather. That is the design - "wildfire produces more
heat" was in the notes - and `wrath_check` holds the hot bound rather than
the cool one.

**The earth keeps a ledger, as of 2026-09-14 (third pass).** The owner's
own idea and the notes behind it: the rarer the animal the sharper the
cost, a legendary a shock, and wrath as the world's answer to ecological
imbalance rather than to tower use alone. Six things, each a decision.

**A kill costs by the species' rarity, sharply.** `WRATH_RARITY_SCALE` is
1, 3, 8, 24 - a legendary is not eight rabbits and a bit, it is a different
order of thing - and a shiny or an elite multiplies on top. The signal
carries the rarity (`wildlife_killed` grew three arguments; the sky is its
only listener).

**A legendary is a moment the world notices, and a window.** The wind stops
for `WRATH_STILL_SECONDS`, the light goes strange for a beat, the ambience
drops and comes back, every animal runs, and the line is said
(`data/wrath/legendary_slain`) - on every machine, through the same relay
the telegraphs use. For `WRATH_SHOCK_SECONDS` the earth's events roll
`WRATH_SHOCK_HAZARD` times as often. Not a certainty: "uncertainty makes it
scarier" was the owner's own note, and the gate asserts the boost and
never an event.

**A living legendary is an anchor.** `Wildlife.living_legendaries()`
divides every hazard by `1 + n * WRATH_ANCHOR_CALM` and speeds the floor's
recovery. Killing it is a strong reward, a shock, *and* the loss of that
for the run - which is what turns the kill from "rare mob" into "you
removed one of the things holding the region together".

**Borrowed power is debt, and debt can be paid down.** The floor, which
used to only rise within an act, eases at `WRATH_FLOOR_RECOVERY_PER_SECOND`
once the road has been quiet - nothing killed, felled or burnt - for
`WRATH_QUIET_SECONDS`. Slow, capped at nothing, and never a thing to farm:
there is no action that *reduces* wrath, only the absence of the ones that
raise it.

**Strain has a personality per element.** Fire's ember cools, faster in
rain; air's gale spikes and drops; water's tide drains unless a flood
stands; earth's tremor settles slowly. Each feeds the heat by its share of
full (`WRATH_STRAIN_PER_SECOND`), so hammering one element is one strain at
full. Clear-cutting is more than `WRATH_FELL_FREE` timber fells in a window;
a forest burnt by a fire *the player lit* (`Wildfire.burnt_by_player`,
tracked from the tower's shot through every spread) costs per plant; the
earth's own lightning fires do not, because that is the cycle.

**The wind is a vector.** `WeatherSky.wind()`: the weather's own wind along
the road, wandering on a slow clock and gusting, published to
`RunState.wind`; a wildfire spreads downwind and a funnel leans with it.
Deterministic from the sky's clock rather than a stream, so it costs no
roll and the guest's copy is cosmetic.

**What none of this is:** a number the player is shown. `wrath_check`
(133 checks) measures the rarity curve, the shock and its passing, the
anchor's calm, the quiet floor, the free fells, the player's fire, the four
strains and their clocks, and the wind - on the heat, because `wrath()`
clamps and a legendary alone reaches the ceiling.

**Wet, and spells that touch the world, as of 2026-09-14 (fourth pass).**
The owner forwarded a complete spellcasting design (`docs/ChatGPT_More_Ideas_4.md`).
Two pieces of it multiply what exists and were built; the rest is triaged in
`docs/IDEAS_REVIEW_2026-09-14.md`.

**Wet is a status, and it shapes a blow.** `Enemy.apply_wet` for
`WET_SECONDS` from water that hits a body (a water tower's shot, a water
spell's area); rain past `WET_RAIN_FROM` and a flood at the knee wet
everybody without a timer. Three reactions, one number each: lightning hits
a wet body `WET_SHOCK_DAMAGE` harder and a chain leaving a wet body reaches
`WET_CHAIN_RANGE` further (conductive); chill fills `WET_CHILL_SCALE` faster
on it (flash freeze); fire on a soaked body steams the wet away and does
not burn, while rain-wet halves the burn (steam). Water on a burning body
puts it out. `reaction_check` measures all of it on bodies with deep pools,
because the first cut's strike killed both bodies outright and "took the
same from each".

**The bound is the one every status is held to: Wet changes the shape of a
blow and never adds a source of damage.** Every multiplier lands on a blow
that was already being dealt, through `take_damage`, so `curve_report`
still reads the same waves. A puppet never decides its own wet.

**A spell of an element works the world the way a tower of it does.**
`SpellData.element` is authored per spell (nine of nineteen carry one); on
resolve, `SpellCaster._touch_the_world` warms or wets and cools the ground
where the spell lands by the mana it spent and feeds that element's strain
- one aggregated event per cast, never per particle (the document's own
rate-limiting rule). A water spell leaves what it hits wet.

**Refused: a second tree.** A Spellcasting skill with its own discipline
points beside the four disciplines is the third draft this project keeps
refusing. The Arcane discipline *is* the caster's tree.

**Every tower stands square on the grid, and every road body walks on eight
frames, as of 2026-09-14.** The owner's report: some towers were built on a
diagonal, isometric base "that doesn't align with our game's grid system",
and four-frame walks read as low quality.

**A contact sheet found the seven.** Ash Thrower, Barrow Stake, Glacier,
Hailcaster, Rime Ward, Rootcrusher and Scree Gun sat on a rotated square
while the other thirty stood front-on with a slight top-down angle. They
were regenerated as PixelLab Pro Flash *objects* with `view: low top-down`
and a style image of a tower that was already right, then each was
animated from its own result by URL for three idle and three attack frames.
Same file names, same 192px, no manifest change - which is the whole point
of the art convention (§4).

**The perspective rule, stated so it is not re-learned:** a Wilderhold
structure is drawn from the front with a slight top-down angle, its base
flat and straight-on to the camera. Never an isometric corner, never a
diamond base. Say so in the prompt, in capitals if need be; the model's
default for "tower" is isometric.

**Eight-frame walks.** `GameData.load_move_frames` had loaded up to eight
frames since it was written and every breed had four. All thirty-nine
breeds, the six elites, the squirrel and the rabbit were animated from
their base sprite by its public raw-GitHub URL (`animate_image`, 192px,
eight frames, "moving forward in its natural gait ... facing exactly as
drawn"). The stride is distance-driven, so `ENEMY_WALK_CYCLE_FRAMES` scales
the phase by the frames on disk against the four the constants were
authored for: a cycle still covers the same ground in the same time. Bosses
are 384px, over the animator's 256 cap, and keep their four.

**Twenty concurrent jobs is PixelLab's limit**, so a batch of forty-seven
is submitted in waves; every job id is kept in `docs/ART_JOB_LEDGER.json`
by frame path, which is what makes a frame re-fetchable and an animation
re-doable without the base going through the conversation.

**A blow is felt by what it lands on, as of 2026-09-14.** From the fifth
forwarded list's "give every hit exceptional feedback": `EnemyData.hide` -
FLESH, ARMOUR, STONE, SPIRIT - authored per breed, read by `HeroAttack` off
the first body a swing struck and carried on `hero_attack_landed`. Flesh
cracks with a warm spray; armour rings, throws more and brighter sparks with
a small ring, and holds the blade a beat longer (`HIDE_HITSTOP_SCALE`);
stone chips and dusts; a spirit takes the flesh sound softer and a few pale
wisps. The three impact recordings had been on disk since the audio pass
and played *at random* under one "impact" group - a hit on a stone golem
could crack like meat. `Sfx.hit_group_for` is the one place that picks.

**The bound is the one every feel change is held to: nothing about damage
moves.** The blow is the same blow; only its sound, its sparks and its
hitstop follow the hide. `hit_feel_check` drives the real `_strike` against
an armoured body and a fleshy one and reads the hide and the hitstop back,
because a hide authored on every breed and read by nothing would pass a
data walk.

**The debrief says what the road paid and what the earth did, as of
2026-09-14.** From the fifth forwarded list: "failure should produce stories
instead of frustration", "make death screens informative". `RunState.kept` is
counted where each gain is banked - XP and levels in `gain_hero_xp`,
materials in `gain_material`, fish in `take_fish`, gear in `receive_gear`,
bonds in `record_spirit_encounter`, craft XP in `gain_profession_xp` - and
`RunState.earth_events` where each of the earth's events is *seen*, so a
guest's debrief agrees with the host's. Both ride the run summary; the
results screen says "KEPT · the road ends, this does not" on a loss and names
what the earth did only when it did something. `debrief_check` feeds every
counter through its real path and reads the screen back, because a counter
authored and never fed would say "nothing this time" after a run that
levelled twice. Nothing new persists: the counters are of things that
already do.

**The economy is tested like a hostile player, and the budgets are enforced
where they say they are, as of 2026-09-14.** Two gates from the fifth list.
`exploit_check` drives the real doors: a tower sold never pays back what it
cost at any level, a drop pays once however often it is collected and never
to a puppet, the stash never overfills and the overflow is salvage, XP stops
at the cap, a material at its ceiling. `budget_check` holds the caps inside
the ceilings the frame was measured under (`ENEMY_CEILING` and the rest are
its constants - raising one is a perf run, not an edit), that the director
*waits* at the enemy cap with its queue intact, that the wildlife stops
arriving at its own, and that nothing crossing the wire is on a per-frame
clock. A cap authored and read by nothing is the frame going away, which is
why the director and the wildlife are driven rather than their constants
read. Frame timing stays `perf_check`'s, on the release, with a renderer.

**The raccoon is a thief with an AI, as of 2026-09-14.** The owner's brief
from the third play report: the loot indicator more apparent, not every
raccoon carrying, and a raccoon that searches, steals, hides. `WildlifeData`
grew `hoard_chance` (the raccoon is born with its sack 45% of the time) and
`steals`; three states joined `Wildlife.State` - SCAVENGING, HIDING,
FORAGING - and `_tick_thief` runs them on the host: every half second it
looks for loot on the ground within reach of its nose and goes for the
*richest* (gear by rarity, then Gold by the coin), takes it
(`LootDrop.steal`, which removes the drop from every machine and pays
nobody), runs it to the nearest tree standing far from every hero and lies
low there half-seen, breaks cover and bolts when a hero comes close, and
with nothing in its sack forages the foliage for Gold. The sack is the tell:
bigger, and it glints - never while hiding. What it took falls when it dies
and goes with it when it rifts.

**Two bounds.** A piece a player put down on purpose is never taken
(`player_dropped`), and neither is a crate, an orb, a spark or a blueprint -
a thief carries what a thief can carry. And a guest's puppet decides nothing:
the host tells it its sack and its cover (`coop_wildlife_sack`, Fact 63),
and `coop_loot_taken` already removes the drop. `raccoon_check` measures each
part on the real field, stopping the road first, because a wave walking past
frightens a thief mid-errand exactly as it should.

**The act is warm before it is fought, as of 2026-09-14.** `perf_check` on
an RTX 3070 Ti: the average frame on vsync and **12.5 hitches a minute over
33 ms against a budget of 3**, worst 146 ms. Nothing preloaded anything: the
first spawn of every breed loaded its thirteen frames from disk mid-wave,
every animal did the same on arrival, and every shader compiled on the first
frame that drew it. `RosterWarmup.warm_act` loads the region's breeds, its
elites, its boss, every wildlife kind and every tower before the act, and
`warm_shaders` draws every shader once on a speck; the battlefield calls it
in `_ready` and in `refresh_terrain`, the one function everything regional
goes through. `warmup_check` proves every frame the act can draw hands back
the *same instance* on a second load - `ResourceLoader.has_cached` answers
by a texture's remapped import path and says no to the path anyone asks
for, which is the wrong tool for this. `perf_check` keeps a hitch ledger
now: each hitch with the nodes and the texture memory that arrived in its
frame, so a load, a spawn and script time are told apart. **Measured after:
0 hitches in the same two minutes, worst frame 26 ms, p99 19.5 ms** - the
stutter the owner would have felt in every first wave of every act was the
loader, and nothing else.

**Loops close on their own pose, as of the same date.** An audit of all 250
frame sequences measured the jump from the last frame back to the first
against the mean step between frames. The idle loops play the base sprite
as frame zero and the worst of them - heron, hedgehog, hawk, raven, bog
crane, frost elk, steppe horse, glass moth, swallowtail - jumped four times
a step back onto it; the walks that were regenerated on 2026-09-14 (glass
singer, ice hauler, horde shieldman, fog lantern, pack howler, snowhide
brute, frost elk, squirrel) did not return to their own first frame. All
seventeen were re-animated with `animate_image`'s `last_frame_url` pinned
to the base sprite, which is the one instruction that makes a loop a loop;
idles install three frames and drop the pinned fourth, walks keep all eight
with the pinned base as the contact pose. The audit script is worth
keeping in mind before generating another cycle: a walk is judged last-to-
first, an idle base-to-first, and `holes` counts the gaps between limbs, so
only *pinholes* - enclosed specks under a dozen pixels - mean a fault.

**The things that can be worked say so from across the road, as of
2026-09-14.** A gather node glints every few seconds - ore a mineral spark
upward, timber a leaf drifting down, more sparks a rarity step - and
breathes a ring in its material's colour while the hero stands in reach; a
rift gate lets motes rise and breathes; a fish surfaces in every pond now
and then. All of it is drawn and none of it is read (`Gathering._tick_tell`,
`RiftGates._tick_gate`, `Fishing._tick_water`), on the decoration's own
dice rather than the run's stream. And the HUD's four resource icons were
regenerated in the style of the loot drops, with each drop as the style
image, because a counter and the thing it counts should be one thing drawn
twice. `juice_shot` photographs the three tells.

**The deep looks like the deep, as of 2026-09-14.** The maze under a rift
had been drawn as the raid draws a camp: the region's ground on raised plates
with a line round each, which reads as paint marks on flat earth. Photographed
first (`dungeon_shot`), then rebuilt as a place.

**The floor and the rock are one tile sheet.** `DungeonTiles` is the ponds'
trick the other way round - the floor is what was cut *out of* the rock, so
the rock is the upper terrain and corner value 1 - one `TileMapLayer` on a
dual grid, a 64px PixelLab Wang sheet per kind repacked by
`tools/install_dungeon_tiles.py`, the rock continuing past the rim so the
camera never sees where it stops. A missing sheet leaves the plates as they
were: the maze is never invisible. Collision and `can_step` still answer from
the layout; this is what the place looks like, never what it is.

**The dark is the deep's own.** An arena had no CanvasModulate - the
battlefield's is hidden with the battlefield - so a rift was played in whatever
light the sun happened to give, which underground is wrong at noon and wrong at
midnight. `DayNight.set_underground` publishes deep night to every light and
tint (`darkness` 1, a tint of the kind's own) **while the sun's own reading is
kept for `is_night()`, the difficulty and the wave count** - the night's teeth
stay on the road rather than following the player down - and the arena carries
a CanvasModulate that is visible only while a stage is open. Then the maze is
*lit*: iron sconces every few tiles of wall, each a `Flame` and a pool on the
floor, every third carrying a real `PointLight2D` for the same reason only
every second lane torch does. Measured at play zoom on the 3070 Ti: 4.5 ms
mean, 8.3 ms p99, 13 lights.

**A raid is lit by the same node**, and that closes a gap that predates the
deep: a camp had been fought in noon light at midnight, because the only
CanvasModulate in the game was the battlefield's. `RaidArena._tint_node`
follows `DayNight` exactly as the field's does - the sun's tint for a raid,
the deep's for a rift - and is visible only while the arena runs, so it never
stands beside the field's. A night raid is dark and its fires light the
banks (`raid_shot -- night close`).

**The rest is what a place has and a picture does not.** Rubble, puddles and
bones on a dungeon's flagstones; crystal, stalagmite and rubble in a rift's
cavern; a rune circle on the vault's floor that brightens as the rift fills
and flares when the guardian steps through, so the player is told the guardian
is near by the floor and never by a number; dust hanging in the corridors and
water dripping from a ceiling nobody can see, embers rising in a rift; and the
place *groans* for `DUNGEON_TREMOR_WARNING` seconds before its clock runs out -
a shudder and a pebble, harder as it nears - because a collapse from nowhere is
the blow from nowhere the telegraph rule refuses. The collapse itself sheds
rock (`FallingRock`: a chunk, a growing shadow, dust, a stone knock and a
distance-weighted shake on landing) rather than dust alone.

**None of it is read.** The dressing draws its own dice by run and stage so
where a body appears cannot depend on where the rubble fell; a sconce blocks
nothing; the runes are a picture of the fill. `dungeon_check` holds the sun
staying the sun, every corner tile laid and the rim solid, sconces on faces
with floor at their foot and spaced, a few carrying light, every piece on open
floor, the runes on the vault, the air moving, no rock before the warning and
rock on every bite.

**The road home, as of 2026-09-14.** From the fifth list's fourth priority:
"push another Act?" as a decision with rising stakes. The stakes were already
in the game and nobody was asked about them: a run pays `RUN_MARKS_REWARD`
Marks an act, and a fall pays `RUN_MARKS_LOSS_SHARE` of it. So once an act's
boss is down, the pass behind the party is offered on the crossroad screen -
**turn for home** and bank the run's Marks in full, or **push on** for
another act's worth and fall for the share. The card shows what a return pays
now, what the next act would pay, and what a fall keeps, read off the same
arithmetic the end uses (`Run.homecoming_marks`) so the card and the purse
cannot disagree.

**A return is the third ending.** `GameDirector.return_home` settles the run
as `returned` - not a victory, which only the summit is, so the Sigil and the
victory Tools stay the summit's; and not a fall, so the Marks are whole and
the debrief reads "Home again". It travels to a guest as a second flag on the
run's end, and a host that does not send one ended the run the old way.

**The host decides.** The run is one shared thing and the host's to end; a
guest is told the outcome, not shown the card. A headless run is never held
on the pass - `Run.ask_homecoming` is off there unless a gate says it will
answer - which is what keeps every gate that fells a boss from hanging on a
question. `homecoming_check` holds the stakes, the pass, pushing on and the
return.

**A guest can rejoin a live run, as of 2026-09-14.** From the fifth list's
multiplayer hardening: drop-in, and rejoin after a disconnect.
`docs/COOP_DESIGN.md` §7 had said "the guest may rejoin" since the co-op
decision, and the session layer always allowed it - reconnecting is the same
code path as connecting - but nothing told the rejoined guest what it had
missed: every tower, body, phase and purse is a fact sent once, on change, so
a guest arriving in Act IV stood on an empty road with the right seed.

**The welcome.** Three pieces, each the smallest thing that closes the gap:
a peer connecting while the host's run is live is sent `RUN_STARTED` with
the seed, **addressed to it alone** (`CoopRelay.tell`) - told to everybody it
would start every other guest's run again; the guest's `Run` asks for the
world once its field is up (`Request.WELCOME`), because facts that arrive
before the field exists land on nothing; and the host answers with
`CoopWorld.compose_welcome` - the run itself (seed, wave, phase), then the
clock, the phase, every purse and the wall, then every tower, barricade and
trap, every *announced* body and animal, and every drop with an identity -
each as the fact the guest already knows how to apply, so no second
application path exists to drift; a boss out on the field arrives as a boss,
in the phase it has reached.

**Host migration is still out of scope**, and stated: the run is the host's,
and a host that drops ends it for both. `rejoin_check` composes the welcome
from a real field and feeds it back through the relay's own receive path as
a guest; `coop_check` proves the wire tells a late arrival the seed, once,
and tells the host nothing.

**The Farmer, as of 2026-09-14.** The fifth craft, and the one the ideas
review put first among the new ones because it reads the climate grid - "the
skill that ties the simulation to the player". The six crops had been in the
tree since the grid was built, drawn by nothing.

**What it is.** The road lays a few tilled plots on the outskirts when a run
begins, and every region grows a few of its own crops wild among them. Seeds
are taken from the wild plants, a seed goes into a bare plot, and the crop
grows **by road walked** - never by the clock, so a beast standing still
farms nothing - at the pace the ground under it allows: `Farming.fit_for`
reads the crop's temperature and wetness bands against `Climate`, whole
inside them and falling to nothing over the Farmer's tolerance outside. Off
its ground a crop wilts - droops, browns - and `FARM_WILT_DISTANCE` of road
later it dies with its seed. The Warden plants the seed that fits the ground
best of those held, which is the craft's knowledge read *for* the player
rather than shown as a number, and the prompt says why a crop is failing.
So an ember pepper wants the desert, a heatwave, or a cluster of fire towers
warming the ground; a glowcap wants rain, a flood or a water tower; and a
frost root planted in the snow becomes a decision when the road reaches the
Saltpan, because the plots stay and the region does not.

**The bound is the Angler's, and it is gated.** A craft touches nothing but
its own craft: a practised Farmer's crops tolerate ground further from their
band, grow faster, pay more Food, and give a seed back more often. No
attribute moves. **Nothing new persists**: seeds are the run's
(`RunState.seeds`), plots are the run's, and only the practice is kept -
working rule 7 is unchanged. Farming is personal in co-op exactly as
gathering is - both machines dig the same plots from the seed and each Warden
works its own - and only the Food, which is the run's, crosses the wire,
asked by crop id and never by amount. `farming_check` holds all of it,
including that the clock grows nothing.

The first plot the hero stands by opens a coach step (`Trigger.CROP_NEAR`,
appended to the enum, never inserted - the data indexes it by number), the
Guide has "Plots and crops" with a photograph from `guide_shots`, and the
map marks the plots. Fixed in passing: the rift's coach step fired on *any*
interact prompt, so it used to open at a tree; it opens on the gate's own
button now.

**The frame, re-measured after the outskirts, as of 2026-09-14.** `perf_check`
at 1920x1080, High, vsync off, on the RTX 3070 Ti: **18.5 ms (54 fps)** on the
built field, against the 7.8 ms recorded on 2026-09-08. Not one thing: the
map is 2.8 times the area since the outskirts, with a hundred torches on its
roads, camps with fires, ponds, gates, nodes and plots, the fog, the climate,
the weather veil and the wrath. Every `--off=` switch moved the frame by a
millisecond or less and Low quality was still 16.2 ms, so the cost is
simulation and canvas, not the gated visuals. `perf_bisect` at eight seconds
a script (three is noise) put `flame.gd` first at 5.2 ms: a hundred flames,
each in view rebuilding three polygons every frame. Flames redraw at
`FLAME_REDRAW_HZ` (30) now and a pond's bubbles at `POND_BUBBLE_HZ` (20) and
only in view - the clocks still run at frame rate, only the drawing is
sampled. **Measured after: 16.6 ms (60 fps), the bisect's fighting baseline
17.7 to 13.2 ms.** The budget is met on this machine with no headroom to
speak of; the next millisecond is in the long tail (enemies, torches,
foliage, the veil, the climate, the fog), and the minimum-spec question is
still open.

**The Rootshield was drawn disagreeing with itself, and every tower's frames
are locked to its base, as of 2026-09-14 (sixth facing report).** The owner
reported the green shield-bearers "still facing backwards in all their
states" for the fifth and sixth time. The flag was right and the art was
wrong: the sprite's *face* looked right while its *shield* hung left, so
whichever way `art_facing` pointed, half of the body walked backwards - the
2026-09-14 rule "a shield-bearer faces its shield" turned the shield the right
way and the head the wrong way. No flag can fix art that disagrees with
itself. The breed was regenerated as a clear left-facing profile (face, chest
and shield all leading), re-animated by job URL, and the flag stayed LEFT.
**The lesson is a check, not a rule:** before setting `art_facing`, confirm
the head and the leading prop agree; when they do not, redraw. `facing_shot`
now reveals the fog and saves a crop around the body, because the first cut
photographed a road the fog had emptied and nobody noticed.

**Tower frames drift and shed their foundations, and the base is the master.**
The owner's screenshots: barrow stakes shifting a pixel in their idle, scree
guns losing rubble and growing transparent holes at the foot between frames.
Measured across all 222 frames: the animator re-renders the whole sprite, so
masonry drifts by one or two pixels, foundation pebbles are re-invented or
dropped, and fine detail smooths away - none of which is animation.
`tools/lock_tower_frames.py` aligns each frame to its base by silhouette and
keeps the frame's pixels only in connected regions that differ strongly (a
glow, water, ice, a discharge) or that add pixels the base has none of (a
splash, a flash); everywhere else the base's own pixels stand, so the loop
closes on the base exactly. Run it after any tower animation is regenerated.
A tower whose frames were already the base (Deep Freeze) is untouched by it.

**Every tower has a look of its own, as of 2026-09-14.** The owner's brief:
"ensure all towers including the newest additions all have game juice vfx
catered to each tower properly and perfectly". Every effect a tower had was
decided by its element - four muzzle flashes, four shots, four impacts, four
airs for thirty-seven towers - so a Barrow Stake flashed the same orange-brown
as a Rootcrusher and a Rime Lance threw the same bolt as a Tide Caller.

`TowerData` authors four things per tower: a **shot style** (`Shot`: a bolt,
a lob on an arc with a shadow and a heavy landing, a lance's long streak, a
spray's fan of pellets, a chain's jagged crackle), an **air** (`Ambient`:
embers, smoke, drips, frost, grit, motes, gusts, sparks, glints, or none),
a **colour** (`shot_tint`, for the towers whose art is not their element's
colour) and a **kick** (`juice_scale`, the recoil and flash size). All
thirty-seven are authored, snipers lance and siege pieces lob or spray, and
the well has an air though it never fires.

**The bound is that a style is a look and never a fact.** A lob's picture
rises off the straight path while the node that hits stays on it; a lance is
the same speed drawn longer; a spray's pellets touch nothing and the one real
shot lands; a chain's jitter is in the ribbon. `tower_juice_check` builds one
tower of each style on the real field, fires it at a standing body, and reads
the damage back - the shot's own against the tower's range, and the body's
pool after it lands. The pressure curve is untouched because no number is.

**It caught a bug older than itself.** The field positions a projectile
*after* adding it, so `_ready` took its heading from the world origin: every
shot in the game left its tower pointing somewhere else and curved round in
the first tenth of a second, and a tower far from the origin threw shots that
flew away from the body before homing back. The heading is taken on the
first tick now. The gate saw it as a spray whose shot went the wrong way.

**A gate that polls for a short-lived node is a coin toss.** The first cut
looked for the shot each frame and read it while it flew; a shot born and
landed inside one slow frame was never there. It is caught on
`child_entered_tree` and read on `tree_exiting` now, which is the pattern for
anything that lives less than a frame might last.

**Where the players fell, as of 2026-09-14.** The owner's brief, first of
three stages: on an actual collapse, one marker at the recorded death
position; a stone falls from above, lands with a restrained knock, dust and a
settle, stands while the player needs recovery, and dissolves with a shader
when they are up; the remains stay on that spot until the act ends, as
scenery; solo deaths, co-op downs, the solo clock, a partner's revive and a
team wipe all covered; a stable identity so no message can plant a second
stone; a death in an arena marks the arena and never the road.

**The markers watch the heroes; they do not listen for a message.**
`DeathMarkers` is a node under each scope's sorted layer - the field's and
each arena's - and every frame each hero under that scope is either standing
or not; a change is a fall or a rise. That one decision is most of the brief:
every death path arrives through `Hero.is_alive()` without a signal per path,
a hero has at most one stone so nothing can plant a second, a death in a
dungeon marks the dungeon because only the dungeon's markers watch the
dungeon's hero, and a raid's freeze holds a stone in the air because the node
freezes with the scope (working rule 8). In co-op each machine draws its own
stones from the downs it already mirrors; nothing crosses the wire.

**What a stone is and is not.** `DeathStone` is presentation: it reads the
hero through the markers and is read by nothing. It falls from
`DEATH_STONE_FALL_HEIGHT` over `DEATH_STONE_FALL_SECONDS` under a growing
shadow, lands with `sfx_hit_stone_1` at `DEATH_STONE_SOUND_DB`, dust and a
`camera_impact` weighted by distance, and dissolves through
`stone_dissolve.gdshader` - a crumble from a noise field with a lit edge,
not a fade. Revived during the fall it dissolves where it is rather than
landing on somebody standing. Drowned, it lands with a splash and leaves no
bones: the river keeps the body. Two deaths on one spot stand
`DEATH_MARKER_OVERLAP` apart. Nothing persists.

`ReviveBar` used to plant its own stone for a downed partner and delete it
on the revive, co-op only; that is gone with `fallen_marker.png`, because two
stones on one body is one too many. `death_marker_check` (44 checks) drives
every path through the real doors - a lethal blow and the wound clock,
`go_down` said three times, `revive_in_place`, `respawn_from_wipe`, a
drowning, `Battlefield.suspend`, `act_started`, and the raid arena's own hero
- and `death_marker_shot` photographs the fall, the stand, the dissolve and
the bones.

**Eight towers an element, as of 2026-09-14.** The owner's brief, second of
three stages: the roster to eight per element with the ten fusions kept, five
arrivals with levels, both paths, a capstone, an unlock, a description,
authored art and effects. Fire had six, the others seven; the five are the
Flash Kiln and the Bellows Forge (fire), the Stillwater Mirror (water), the
Mason Shrine (earth) and the Wind Relay (air), and they join
`ROSTER_UNLOCK_ORDER` after every gun and ahead of the well.

**Four of the five fire nothing, and each does one thing for its neighbours
on a number they already have.** `TowerData.support` names it: the Forge
opens a `support_window` every `support_interval` in which the towers in
reach fire `support_strength` faster; the Relay carries its neighbours'
reach by its strength while it stands; the Shrine mends each damaged tower
in reach by its strength every interval; the Mirror swallows
`support_capacity` hostile shots that cross its reach and recovers one an
interval. The Kiln shoots: a short-reach burst with `windup_seconds` of open
shutters first, and a ring at its target the size of the blast for exactly
that long, so the tell and the blow cannot disagree.

**The bounds, each gated by `tower_support_check` on the real field.** A
window is never a standing gift and two forges give less than twice one
(`TOWER_SUPPORT_HASTE_CAP`); a relay never carries another relay and a
fallen relay carries nothing (`TOWER_SUPPORT_REACH_CAP`); a shrine mends
never past whole and **stone that has fallen stays fallen** - `Tower.repair`
refuses a dead tower and that refusal is the rule; a mirror emptied is a
basin until its clock fills it, and a shot out of its reach is not swallowed.
Every one moves a rate, a reach, a pool or a shot the fight already had, so
`curve_report` reads the same waves - the same bound paths, omens, cards and
airs are all held to. The field reads the forges, relays and mirrors once a
frame (`Battlefield._refresh_support`) rather than every tower asking every
other on every call to its reach.

**Co-op.** Tower health never crossed the wire and still does not; a support
tower's clock runs on both machines, the guest's towers are told their shots
as before, and a hostile shot is a local picture on a guest, so a mirror's
charges are local too. Nothing new is sent and nothing persists.

**And the "six Earth and Air options" the owner saw is the unlock order, not
a fault.** The build sheet lists `ContentDB.unlocked_base_towers()`; an
account that has bought the roster up to the Hailcaster holds six of Air's
seven and seven of Earth's, with the Gale Lance, the Barrow Stake and the
well still to buy with Tools. The five join that ladder rather than the
starting set, for the same reason the well is last: a player meets one new
tower at a time.

**Eight wire numbers were shared by two names, found 2026-09-14.** Adding a
fact for the families meant reading the `CoopRelay` enums, and both had
collisions: the party events had been hand-numbered 53-58 straight into the
weather block, and `Request.WELCOME` shared 32 with `DROP_GEAR`.

**A duplicate does not error - it hands one name's traffic to the other.**
`_receive` and `CoopWorld._on_request` are `match` statements on the number,
and a match takes the **first** arm with that value. The party arms are
written first, so a guest received every `SKY_CLOCK`, `LIGHTNING`,
`EARTHQUAKE`, `WILDFIRE_LIT`, `TORNADO_SPAWNED`, `TORNADO_MOVED` and
`METEOR_INCOMING` as a party event: **a guest saw no weather and no earth at
all**, and most of it was then dropped by the arity check, which is why
nothing ever errored. On the other side, a guest putting gear on the ground
composed an entire welcome and dropped nothing.

**Renumbered, and the invariant is checked rather than trusted.** The party
events moved to 65-70 and `GEAR_DROPPED` to 71; `Request.WELCOME` moved to
34. Two builds already refuse to play together on a version mismatch, so no
live pairing spans the change. `coop_check._test_every_wire_number_is_its_own`
walks both enums and names any two entries that share a value - checked by
putting the 53 back, which it named.

**Why no gate saw it.** Every co-op gate drives the *signals* either side of
the relay, which is the right seam for "does the guest apply this fact"; none
of them drove the numbered `match` for two facts at once, and no single fact
is wrong on its own. The lesson is about hand-numbered enums that are a wire
format: the numbers are content, they drift exactly as `Role` and `Trigger`
drifted, and the answer is the same - walk the table rather than read it.

**The road raises families, and the Wildblight takes them, as of
2026-09-14.** The owner's brief, third of three stages, with a forwarded
design behind it. Every part of it is presentation and ecology: **nothing
here persists and nothing here is a new power scale.**

**Every animal is four independent things**, which is the brief's own first
rule and the one that keeps the rest honest: a rarity, a shine, a stage of
growth and a state of health. A cub may be a Shiny Rare and still be weaker
than its mother; being taken by the blight upgrades nothing.

**A rarity now belongs to the animal, not to the species.** That is the trap
the brief names by name and it was real: `WildlifeData.rarity` is shared by
every animal of a kind, so writing a cub's upgrade onto it would have made
every deer on the road rarer for the rest of the run.
`WildlifeFamilies.rarity_of` reads the animal's own, and the collection, the
reward, the wrath and the wire all go through it.

**Courtship is stages that can be interrupted, and one appraisal that can
refuse.** Seeking, approaching, assessing, mating, carrying, cooldown; a
fright, a fight, a flood, a parting or a death ends it wherever it got to.
Only the *appraisal* rolls - the brief's own note is that four chained coin
flips make a birth something nobody ever sees - so a pair left alone usually
succeeds, and what makes births rare is the budget rather than the odds.

**Inheritance climbs slowly and never twice.** Equal parents bear their own
rarity, or one rung above it rarely (4%, 2%, 0.5%, never for Legendary);
unequal parents bear the *lower* rarity three times in four and one above it
otherwise - so a Common and a Legendary bear a Common or an Uncommon, never a
Legendary. A shiny birth is the variant's own chance lifted by the parents
that shone and capped at 20%, and deliberately **not** joined to the
account's dry-streak lift, which belongs to what the road shows a player and
would otherwise be farmable by breeding.

**Births are bounded twice**: an act's budget (`WILDLIFE_BIRTHS_PER_ACT`) and
the population cap the arrivals already respect. They pay no Food, no
experience, no gear and unlock no companion; collection credit is one per
birth event and variant rather than one per identical sibling, and offspring
are wildlife - never an extra companion.

**Growth is four numbers and a sprite.** A baby is smaller, softer, slower,
stays nearer home and is worth a fraction; an adolescent is between; an adult
is the animal the roster was tuned on. The antlered species have their own
young art, because a fawn wearing a full rack reads as a shrunken stag.
Parents wait for a baby rather than wandering off, and answer something near
it by their authored `protection`: a deer guides its young away, a badger
puts itself between, a wolf hunts.

**The Wildblight is the frenzy, and it is fictional on purpose.** Rabies is a
mammal's disease and this roster is birds, reptiles and insects too, so the
condition is invented and every species may carry one. Healthy, warning
(3-5s, a symbol and an unsettled idle), frenzied (30-60s, attacks heroes,
companions, road enemies and other wildlife including its own kind),
collapsing, dead. **Bounded at every end**: rolled rarely on arrival, one
natural outbreak an act, a ceiling by campaign tier on how many may be sick
at once, never in Preparation or the opening waves, never on a newborn in its
grace. A species with no bite of its own is lent one, or a turned rabbit is a
light show - and the gate turns a rabbit and watches it draw blood. Contagion
is a bounded extension: only a landed bite, once per pair, one secondary per
carrier, and a secondary spreads no further.

**A mercy is not a hunt.** Putting down something the blight has taken pays
no wrath and counts toward no hunting-retaliation tally. The animal was dying
anyway, and a consequence for ending it would read as the world punishing the
player for the only sensible answer to a frenzy. That is a decision, and the
gate holds both halves - a healthy kill still pays everything it always did.

**Two faults came out of building it, and both predated the gate.** A birth
was being placed at the *arrival* entry point fifteen hundred units off the
edge and walking back, so a cub was never beside its mother and a family
could not form. And **the field walks its animals backwards through its
list**, so in every pair the male reached the end of the mating first and
ended the courtship for both - no female ever conceived, on any frame. The
seeker ends it now and moves the pair on together.

**Nothing new persists, and nothing new is rolled twice.** A companion's sex
is decided once a run from the run's seed and kept in
`RunState.companion_sex`, so dismissing it, re-equipping it and reconnecting
all read the same answer and no packet carries it. `coop_wildlife_family` and
`coop_wildlife_born` tell a guest what happened; a guest rolls nothing and
draws everything.

**Towers never target frenzied wildlife. Owner ruling, 2026-09-14.** The
forwarded design proposed letting them, and the owner ruled the other way in
as many words: "Wildlife with rabies should still not get targeted by
towers." So the 2026-09-13 rule stands unchanged and unconditioned - a tower
sees road bodies and provoked camp bodies, and no animal, whatever is wrong
with it.

**It is also the right answer, and the reason is the economy.** A blighted
animal pays Food and experience like any other kill. A tower that could shoot
one would farm an outbreak from behind the wall at no risk, which turns the
Wildblight from a thing that happens *to* the player into a thing they set up
and harvest - and the encounter the frenzy exists to create is one the player
has to answer in person. The bound is therefore: **a frenzy is answered by
the hero, the companions and the road's own bodies, never by the defence.**

**One piece of the brief is deliberately not built.** A companion does not
court a wild animal: the courtship machine pairs two wildlife *records* and a
companion is a node, so letting one pair needs the machine to handle both
kinds. Recorded here rather than half-built.

`wildlife_family_check` (150 checks) measures the inheritance tables over
forty thousand rolls rather than reading them back, proves one animal's
rarity never moves another's, drives a real pair through every stage to a
birth, interrupts one with a fright, spends the act's budget, grows a cub,
re-applies a host's word to prove nothing rerolls, runs the blight to its
collapse, turns a rabbit and watches it bite, kills a blighted animal and
hears the earth stay quiet, and suspends the whole of it with the field.
`wildlife_family_shot` photographs the hearts, a hind with her fawns, the
warning and the frenzy.

**The wind blows, and you can feel it, as of 2026-09-15.** The owner asked for
"an aesthetically appealing wind system that can blow in any cardinal direction
and can change its strength" that "can affect movement speed for all characters
slowing them against the wind or speeding them up in its direction", with
"optimized coop replication" and foliage "simulated on each client from the
replicated wind updates".

**This is the one addition in a long line that is allowed to move a gameplay
number**, so the bound moves from "a look, never a number" to the shape of the
number. Four properties, all held by `wind_check`:

- **Symmetric.** One function, `RunState.wind_push`, and the same dot product
  and the same cap for a hero, an enemy, an animal and a companion.
- **Capped** at `Balance.WIND_PUSH_MAX` either way and clamped, so no
  combination of gust and weather exceeds it. A crosswind costs exactly nothing.
- **It averages to nothing.** The heading settles on a quarter, holds about
  fifty seconds and turns at a constant rate - a quarter in seven seconds, a
  reversal in fourteen - and reaches every quarter of the compass over a run.
  With four roads facing four ways there is no free ride in it, and
  `balance_test` reads the same 28,988 assertions.
- **Never felt indoors.** `RunState.wind_sheltered` is set beside
  `DayNight.set_underground`, because a rift having no sky and no weather is one
  fact rather than two.

**Two numbers cross the wire and nothing a leaf does.** The host sends the wind
when the heading has turned `WIND_RELAY_DEGREES` or the strength moved
`WIND_RELAY_STRENGTH`, never more often than `WIND_RELAY_INTERVAL`; a guest
eases toward it and leans every plant on its own field. **The gust is
deliberately not in `wind()`**: it breathes fast enough to cross the threshold
several times a second, which made the relay a clock wearing a threshold's
clothes - measured at two messages a second over ten minutes. A gust is also
the one part of the wind nobody needs to agree about, so the settled wind is
the fact and the gust is drawn locally. **Still air is silent** for the same
reason: a heading is undefined with no wind, and the fallback fired for ever.

**And the walk has the wind in it too.** `ParallaxScatter.sway_material` puts
the foliage's own shared material on the beast scope's woods and brush, which
had been plain sprites since they were built - so the one view whose subject is
travelling through weather was the only still thing in the game.

**What the earth is doing is visible from the road, as of 2026-09-15.** The
owner asked for the battlefield's disasters to show in the beast scope: a
funnel over the base, fire for a wildfire, water pouring off the castle base on
Yuri's back when it floods, a world shake for a quake "that also shakes Yuri
too", and lightning.

`BeastOmens` is that readout, and **the bound is that a readout reads**: it
listens to the facts the earth already publishes - the same ones relayed to a
guest - reads `RunState` for the standing conditions, and changes no number,
rolls no die and sends no message. Turn the node off and the run is identical,
which is the fog of war's bound in a second place. It draws on the carried town
rather than in a corner, because a corner icon is a notification and this is
weather. `beast_omens_check` snapshots the run and drives every event through
it; the quake moves the camera **and** the beast, and the gate refuses a build
where only the camera moves.

**The interface answers being touched, as of 2026-09-15.** Holograms on hover,
focus and tap: scanlines, a one-shot sweep, a rim, and a tear on a press.
**Additive, and that is a safety rule rather than a look** - `UiTint` may grade
frames and may never touch text, and an additive layer can only add light, so
over dark plates and pale lettering no glyph loses contrast. `ui_juice_check`
reads the blend mode and the ceiling off the shader and refuses `blend_mix`.
The pad and the thumb get the same answer as the mouse, and the sweep is driven
rather than looped: a hover is an event, and a shimmer that loops for ever is a
screensaver behind a button.

**The main menu is a place, as of 2026-09-15.** Painted corner foliage with
three vines, three leaf sprays and three fruits or flowers hanging off them,
all graded to the corner they hang in; painted branches with their own variety,
laid along the very curve the strands are rooted on so the two cannot drift
apart; fireflies that each keep their own clock; four species of tiny bird; and
the Warden in the bottom-right corner on a dark outcrop with a campfire, a
lantern and a fire horse, arranged differently every visit.

**The figure makes the beast colossal by being small**, which is the one design
decision in that list: a foreground person at a believable size would be the
biggest thing on screen and would take the scale away from Yuri.

**Three faults in that work are worth remembering because they are one fault.**
The birds were graded from the dark upper sky and came out near-black on
near-black; the Warden was graded the way the beast is and came out black on
black; and the vines rolled an index from 0 to 8 against sets of three, so most
strands drew nothing and the corner silently fell back to its silhouettes. In
every case the numbers all said the feature was working and a photograph said
it was not. **Grading a near-silhouette by the ground it stands on is the
recurring mistake**: the beast survives that grade because it is painted in
mid-tones, and nothing else here is.

**The mythical wildlife proposal is triaged rather than built.** The owner
forwarded 112 creatures, a Mythic classification, evidence-and-tracking
encounters, mythic materials and a sanctuary. `docs/IDEAS_REVIEW_2026-09-15.md`
is the triage. The short of it: the best idea in the document is not a creature
but **Evidence -> Tracking -> Encounter**, which multiplies the wrath system,
the fog and the raccoon's hiding rather than adding a system beside them; the
document assumes an extraction game, which this is not, so the egg-theft beat
translates to the homecoming pass or not at all; a werewolf with a blood moon
is the Wildblight built a second time and should be a **Cursed** variant of it;
and the ocean creatures want water this game does not have. Five are
shortlisted - Moonstag, Griffon, Glimmerfox, Hollowhorn, Phoenix - and dragons
are a world-event system rather than a creature. **Nothing is built and no
ruling is assumed.**

**There is no cooking system, and that is a decision, as of 2026-09-15.** The
owner listed "No cooking system" among a batch of work and, asked which of the
two readings they meant, answered: *"Don't build cooking, yet? If you think it's
better for our game to have it then implement it as you see best."* So the call
is recorded here rather than left as an item that gets re-asked every few
sessions.

**The design space cooking would occupy is already occupied.** The Angler
catches eleven fish across three ponds; the pantry keeps them between runs; the
rarer ones carry a short damage-and-speed buff; a fish can be given to a spirit
or to a hurt player beside you. Whatever a cooking craft would *do* - turn a
caught thing into a better consumable - is a second lever on the same fish.

**And the lever it would pull is the one bound the recovery economy has.**
`Balance.FISH_MEALS_PER_RUN` is why a deep pantry buys a better *choice* of meal
and never more of them; without it a player with a full larder cannot be killed
and the wounds, the Tonic and the well are decoration. Cooking makes each of
those three meals stronger, which is exactly the pressure that cap exists to
resist - so it would arrive either as a power scale nobody is tuning, or as a
craft deliberately built to do nothing much, and neither is worth a sixth
profession.

**What would make it worth building** is the thing it is not: a reason to
combine *several* materials into something the road cannot drop. If cooking ever
returns, it should take wood or ore or a crop alongside the fish and produce an
effect that is not "more health" - and it still has to answer
`FISH_MEALS_PER_RUN` before it gets a line of code.

**The road to the first boss was measured against a lie, as of 2026-09-15.**
The owner reported "the path to the first act 1 boss was too short!" for the
second time, with the gate that guards the opening green. Both were true, and
what sat between them was three faults in the two models that measure this
game.

**`curve_report` was averaging camp lords into what a road body pays.** Its
Gold-a-body figure is described in its own docstring as "across the enemies that
actually walk on", and that was true of every non-boss enemy until the second
and third camps were given breeds of their own and the war camp a lord - eleven
resources that live in a camp, never take a route, and are worth several times a
road body *because* going to find one is meant to be worth the detour. Averaged
in, a body paid 8.88 against the 3.64 a road actually pays: **a 143% error in
the modelled purse**, two and a half times the towers, and mean pressure
reported at 0.227 against a band of 0.26-0.46. Nothing failed, because that
report is advisory. Corrected, the curve reads 0.403-0.407 across party sizes,
which is what it read before the camps existed. *Nothing about the game had
moved.*

**And `balance_test` counted one lane and called it a wave.** The spawn queue is
one queue for every road, so what sets how long a wave takes to walk on is the
whole formation; the opening act measured sixteen waves where the road holds
thirteen. `curve_report._mean_pressure_for` divided by `ACT_DISTANCE` and so did
not know Act I is longer than the others. Both walk the road the same way now.

**With the purse telling the truth, the first cut reached the Act I boss on wave
13 holding four level-one towers** - one a road, bought the wave before, nothing
upgraded. `ACT_OPENING_EXTRA_DISTANCE` goes 170 to 390: the boss is met on wave
17 with eight, which is two a road, and Act I's mean pressure goes 0.31 to 0.33
against a run mean of 0.41.

The envelope's margin went with it. It asked for two waves between a defence
becoming affordable and the boss, and passed at 170 honestly - its ramp is a
best case that never spends, so "affordable since wave 11" means affordable to
somebody who bought nothing. Four waves is what the difference between a purse
and a defence costs.

**The lesson is about advisory reports.** `curve_report` prints rather than
fails, which is right - a curve is a judgement - but it means a model that
starts lying says so only to whoever reads it, and this one had been lying on
every release since the camps landed. When a report and a gate disagree about
the same fact, one of them is wrong and it is worth finding out which before
tuning anything.

**Five things walked backwards and eleven nobody had judged, as of 2026-09-15.**
The owner's sixth and seventh facing reports. The canine is the **Ash Hound** -
a black wolf with an orange fire crest, drawn facing left and authored
`art_faces_right = true` since the day it was made. Nothing could have caught
it: `enemy_facing_check` keeps a ledger of every breed's facing and wildlife
carried its own flag with no ledger at all. **It has one now**, and that gate
holds both rosters.

The horn-bearer is two of them: `crown_herald` blows a horn to the right and
`howler` a megaphone to the right, and both were FRONT, which never mirrors - so
on a road running the other way they shot out of the back of their own heads.
Their torsos really are square to the camera, which is the reading that put them
there; what it missed is that **the horn is the weapon**, which is the
shield-bearer rule of 2026-09-14 applied to a muzzle. `shard_wight` was
over-corrected to FRONT in that same batch and is a clean running profile;
`cinder_runner` had never been read at size at all.

**And the gate was red on main before any of it.** The camps' own breeds and the
camp lords - three strangers, four dragons, four wyverns - were authored with no
`art_facing` line, so eleven bodies defaulted to FRONT and were in no ledger.
The system worked; nobody had run it. `tools/facing_sheet.py` makes the reading
one command: the whole roster at 210px beside the flag that flips it, wildlife
and enemies, by the same category rule the game derives sprite paths with - so
elites and bosses are on it, which every one-off script before it missed.

**The riders throw something on the way in, as of 2026-09-15.** The owner: "they
also need more variety in their ranged abilities. So do the ones on the horses."
The horn-bearers already grew a repertoire on 2026-09-13; the mounted breeds
could not answer at all, because all three are VANGUARD - they charge and touch
you and do nothing else - while all three are *painted* with a javelin raised
overhand.

So a breed that closes may now let one thing go on the approach
(`EnemyData.thrown_shot_id`). It is not a repertoire and it makes a Howler of
nothing: one throw, once every several seconds, and then the body keeps coming.

**The bound is the bound every shot in this game is held to, applied to a body
that is not a shooter: it changes the shape of a blow and never its size.**
`thrown_share` is a *fraction* of the breed's contact damage, so a rider who
opens at range hits softer when it arrives; it throws only at a person, only
while out of melee reach, and only once a cooldown - so it can never be added to
an exchange the body is already winning by touching you.

Two things fell out of building it. **A throw beyond `ENEMY_HERO_AGGRO_RANGE`
never happens**, because outside that a body's target is the town and a javelin
is never aimed at the town - the first cut authored 700 against an aggro of 210
and threw nothing at all. And an interrupted wind-up used to *bank* the throw,
so the body's next swing would have loosed a javelin instead of landing the
sword; it is dropped on any state change now, and the cooldown is spent when the
javelin leaves the hand rather than when the arm goes back.

**No two deer are the same deer, as of 2026-09-15.** The owner: "Wildlife should
also all generate with some random variations using shaders appropriately for
all wildlife with seeds ... companion made alive wildlife should keep the seed
for the duration of its lifespan."

Thirty-nine species share one painting each, so a field of six deer was one deer
drawn six times. `Phenotype` derives a coat from the animal's own serial - the
number `SpiritBond.trait_for` already reads a temperament off - and sets it on
the material the sprite already wears. Every species gets a small shift of hue,
lightness and saturation for free; twenty carry markings as well, chosen from
the paintings rather than from a list of animals.

**The first bound is that a coat may never be mistaken for a rarity.** The rank
sheen says what an animal is worth, in light, on a ladder that climbs to a
legendary shiny; a hue wide enough to turn a fox blue makes that ladder
unreadable. `PHENOTYPE_HUE_CEILING` is about twenty degrees and
`phenotype_check` refuses a species that authors past it.

**The second is working rule 7 and it is untouched.** Nothing persists: a wild
animal's coat lives as long as the animal, and a bonded spirit's is derived from
the run's own seed and its variant key - so it is the same companion for the
whole run, agrees on both machines without a packet, and is gone with the run.

**And a phenotype is a look.** Nothing reads one - not rarity, not the
collection, not the hunt, not loot, not the wrath the earth keeps - and
`Graphics.KEY_PHENOTYPE` turns every one of them off with no number moving. Same
bound as the fog and the rank sheen, and the same reason: it can be given away
on a weak machine.

The markings are laid out in **source pixels** rather than in UV. The art is
pixel art; a pattern computed in smooth UV space is an airbrush over hard pixels
and reads as a smudge at every zoom the camera has.

**And the title screen wears no wound, as of the same date.** The red health
vignette lives on a `CanvasLayer` that `Vfx` owns, and `Vfx` is an autoload - so
it survives every scene change and the only thing that ever takes it off is
somebody choosing to. It was cleared when a run was *settled*, which misses
every way of leaving one that settles nothing: quitting from the pause menu, and
a co-op host going away. Cleared where the invariant lives - the screen that
must never show it - rather than at each door, and a health report that lands
after the run has ended may no longer set it. Deliberately **not** on every
scope change: a raid must not wipe the warning that the hero is nearly dead,
which is why `Vfx.clear` and `Vfx.clear_vignette` are two functions.

**The interface is allowed to be dimmer than the art it sits on, as of
2026-09-15.** `ui_tint_check` held one rule since it was written: the tint the
interface is painted with may never be worth less than one, "and the darkest
hours are exactly when a player can least afford it". That reasoning is about
*readability* and was being enforced as *brightness*, and the two are not the
same thing - so a menu at midnight kept its plates at the pale lavender they
were authored at and read as an interface pasted over a painting. The owner
reported it twice as the buttons being "too bright".

`UiTint._normalised` takes them down now, and **the gate's bound moves from a
number to a floor**: a plate may be darkened to `SHADE_FLOOR * PLATE` of what it
was painted and no further, read off those constants rather than typed into the
gate. At those values a midnight menu is about three fifths of its authored
brightness - clearly dimmer than the art, nowhere near dark enough to stop being
a button. The other half of the old rule is untouched and is the half that was
ever about readability: **a frame is tinted and a font is not**, which is the
next test in that file.

This is recorded rather than quietly changed because amending a gate's
invariant is the one kind of change that makes every later run of it agree with
the bug it was built to catch.

**Four gates were red on main and nobody had run them, found by the release
sweep of 2026-09-15.** Worth writing down as a pattern rather than as four
fixes, because three of the four landed the same day they were caught and none
of them announced itself:

- **`ui_tint_check`** - the decision above, made in code and not in the gate.
- **`enemy_walk_check`** - five idle frames of the camp breeds and one wyvern
  drift off their base's ground line by more than two pixels. The animator
  re-renders the whole sprite, so the feet wander; `tools/lock_animation_region.py
  --align-ground` translates a frame back onto the base's foot without
  repainting a generated pixel, and that is the repair for this every time.
- **`enemy_facing_check`** - the Moonstag had no recorded facing, which is the
  ledger added hours earlier working exactly as intended on the first animal
  added after it.
- **`enemy_shot_check`** - passing its own checks and printing three ERROR
  lines, which the *release* bar fails on and a casual read of the PASS line
  does not. Two real faults behind them, and both are the same shape: **a
  connection that outlives the thing that made it.**

  `Battlefield._ready` connected `EventBus.weather_changed` to
  `PathBlend.set_weather`, which is **static**, so Godot has no object to drop
  the connection with when the battlefield is freed - every later battlefield in
  the same process errors with "already connected". And three scopes -
  the battlefield, the raid arena and the beast scope - followed `DayNight` with
  a *lambda*, which captures what it reads; when the scope goes, the capture is
  freed and every later tick of the sun prints "Lambda capture at index 0 was
  freed" and then assigns a colour on nothing. **Guarding inside the lambda does
  not fix that** - the engine complains at the call, before the body runs. A
  named method does, because its connection belongs to a real object that Godot
  drops. All three are methods now.

  A game builds one of each per process and never sees either; a gate that
  stands up two runs sees both immediately.

**The lesson is about when a sweep is run.** A gate is only as good as the last
time somebody ran it, and the three gates above went red the day their subject
was authored. The release sweep is the thing that finds them, so it belongs
*before the tag and after the last edit* - which also means a sweep started
before the work is finished is wasted, because every later commit invalidates
it.

**Half the roster lays rather than bears, as of 2026-09-15.** The owner
forwarded an essay on egg and nesting ecology. The families built on 2026-09-14
place a cub beside its mother, which is right for a wolf and wrong for a crane -
and worse, of this roster's birds, reptiles and insects only the Copper Pheasant
and the Reed Frog ever paired at all, so the half of the ecology that should
have been leaving clutches on the ground was not reproducing.

Sixteen species lay now, and thirteen of them breed for the first time. A laying
pair leaves a **nest**: the clutch is rolled by the same `_roll_clutch` a litter
is - the same inheritance, the same shiny rules, the same act budget - and then
it sits there and hatches by **road walked**, never by the clock, for the same
reason a crop grows that way. A beast standing still hatches nothing.

**And it can be robbed.** `IDEAS_REVIEW_2026-09-15` triaged the forwarded
proposal's best beat - steal the egg and be hunted all the way out - and found
that this game's translation is the homecoming pass rather than an extraction.
This is the honest smaller version: take an egg and that species comes for you
for the rest of the act, wherever you go. `Wildlife.rouse_species` is a third
reason an animal attacks, beside being a hunter by nature and being taken by the
Wildblight, and it goes through the same branch - what separates it is the
target. A frenzy attacks everything living including its own kind; a robbed
parent wants the people who robbed it.

**Three bounds, each one something else here is already held to.**

- **An egg is never a power scale.** It pays Food, which is a run currency, and
  credits the *sighting* of that variant, which is the credit a birth already
  pays. No attribute, no bond, no gear.
- **A robbed parent's bite is its own.** `WildlifeFamilies.blight_bite` is the
  helper that already answers "what does an animal that never fought hit with",
  and nothing here multiplies damage.
- **Nothing persists.** A nest is the run's, like a plot and a trail, and a
  grudge is forgotten when the act changes - a species angered in Act I hunting
  the party in Act X would be a difficulty setting picked up by accident.

**And an egg is carried home rather than banked, as of the same date** - which
is the imprinted-companion half of the owner's brief. `RunState.carried_eggs`
holds up to `EGGS_CARRIED_MAX`; reaching home, by the pass or by the summit,
opens them and each bonds its variant **outright**. A run that falls loses them.

**That is a real shortcut and it is paid for in the open.** A bond normally
wants many sightings; an egg writes the key in one. What it costs is the road
home, a species hunting the party for the act, and a pack that holds four - and
the ecology itself bounds the rest, because a Legendary clutch needs Legendary
parents and a shiny one needs shiny parents.

**`MetaState.bond_from_egg` writes the key a sighting eventually would and
nothing else** - no level, no stat, no second kind of spirit - so working rule 7
is exactly where it was and a raised companion is no stronger than a met one.
The pack is personal, like a caught fish and a craft's practice: it is one
machine's list, never relayed, so one player's theft cannot fill another's
journal.

**Co-op needs three wire entries and they are all "by name, never by amount".**
A clutch crosses as a species, a count and a place (`Fact.WILDLIFE_NESTED`);
what the eggs *become* is the host's decision and arrives later as an ordinary
birth, so a guest never rolls a clutch of its own. A theft crosses as the nest's
new count and the species that is now hunting (`Fact.WILDLIFE_ROBBED`). And a
guest taking an egg **asks** (`Request.TAKE_EGG`) with the species id, because
the Food is the run's and the run is the host's - the rule the fish and the crop
are already asked under, and the reason a number in that message would have been
a currency printer.

**Something enormous crosses the sky, as of 2026-09-15.** The owner asked for
dragons breathing fire in their land and flying states, affecting the
environment, with world events the map knows about.
`docs/IDEAS_REVIEW_2026-09-15.md` staged them *after* the trail and as **a
world-event system rather than a creature** - "they should be the rarest thing
in the game and the map should know one is there". `DragonPass` is that event.

It is rolled beside the quake, the funnel, the stone and the blaze, off the same
hidden wrath - and on the **cube** of the anger rather than the square, which is
what separates "what a hard road costs" from "what emptying a region costs". A
quiet run will never see one.

**It is warned, and it strikes nothing.** The line is said and every animal
bolts before the shadow arrives, which is the rule every disaster here obeys.
What it does on the way over is light the foliage through `Wildfire.ignite_near`
and warm the ground through `Climate.add_heat`, and *nothing else*: the fire it
leaves spreads by dryness, is bounded by `WILDFIRE_MAX_FIRES`, and costs the
player no wrath, because a fire they did not light is the cycle rather than the
debt. A dragon that dealt damage of its own would be a power scale nobody is
tuning, arriving from the sky.

**And it needs no new wire numbers.** The warning travels on `wrath_warned`,
which the quake and the tornado already use; every plant it lights travels as
`coop_wildfire_lit`, which the wildfire already sends. A guest draws the same
shadow from the same warning and burns the same plants when told.

The art is the one view the whole event is: drawn from directly above, so the
same painting is the shadow on the ground and the thing casting it.

**And the walk sees it, which is the half the brief actually asked for.** "The
map should know one is there" is a sentence about the beast scope, so the shadow
crosses the sky above the carried town there too - the whole width of it, once,
over exactly the seconds the pass itself takes, darkest at the middle of the
crossing so it reads as passing rather than as appearing. It is drawn as a
silhouette rather than as the painting: from that distance a person sees a shape
blotting out the light, and a hundred and ninety pixels of detail at that size is
detail nobody can resolve. `BeastOmens` obeys the bound it was built under - it
listens to `dragon_overhead`, changes no number, rolls no die and sends no
message - and the pass says the word once, as it comes over, so the road and the
walk cannot disagree about how long the light was out.

**Four more things the world answers with, as of 2026-09-15.** The owner
forwarded `ChatGPT_More_Ideas_5.md` - three long brainstorms, with their own
caveat that it was written without access to the project. The caveat turned out
to be the most important fact about it and the triage is
`docs/IDEAS_REVIEW_2026-09-15b.md`.

**Roughly half of the document is already built here**, under other names: the
mythic trail *is* its "creature territories with clues at the borders", the
homecoming pass *is* its "deep-extraction temptation", `EnemyData.hide` *is* its
"material-aware impacts", `camera_impact` *is* its "localized camera shake", and
so on for thirty-odd entries. A further large slice assumes a different genre -
body recovery at a death site, secure pouches, forward outposts, rival AI
parties, settlement districts - and is refused rather than adapted, for the same
reason the egg-theft beat was refused as written.

**Six gaps were named to the owner and two of them were wrong.** A body *does*
recoil along the blow that hit it (`SpriteAnimator.recoil`, wired at
`Enemy.take_damage` since it was written), and a fallen tower *does* shed debris
and mark the ground (`Tower._leave_rubble`). Both were missed by searching for
the wrong words. **Recorded because it is the recurring shape of this mistake**:
a grep for a plausible name is not a survey, and this project has a habit of
having built the thing already under a better one.

**The four that were real, all presentation, all gated by `feel_check`:**

- **Sound knows where it is.** `Sfx.play_at` quietens by distance from what the
  camera is watching and drops a sound entirely past `SFX_CUTOFF`, which also
  hands its voice back to something audible. Six of `Sfx`'s own signal handlers
  had been *given* a world position since the day they were written and thrown
  it away - the underscore in front of `_at` was the tell - so a partner
  swinging across the map, a tower on the far road and a body dying two camps
  over were all exactly as loud as the thing at the player's feet. The camera
  has scaled its shake by distance since 2026-09-13; the audio finally agrees.
- **A tower leans at what it is about to shoot.** A lean and a small shift
  rather than a turret rotation, and that is the perspective rule rather than a
  shortcut: a Wilderhold structure is drawn front-on with a slight top-down
  angle, so one turned to face a flank is lying on its side. It reads the same
  `_acquire_targets` the shot does, because a tell that asked its own question
  could point at a body the tower is not firing on.
- **A tower is built rather than placed.** It comes up out of its own
  foundation over a third of a second. The rise rides on top of the idle exactly
  as the fire kick does - two systems assigning one sprite property is a bug
  this project has already shipped once.
- **A body comes apart by what finished it.** Fire chars and smokes, water
  shatters, air throws it, earth drops it and shakes the ground. The element is
  *marked* rather than threaded through `take_damage`, which would have touched
  the thirty places that deal a blow, most of which have no element to offer. It
  is a window rather than a flag, because the blow that kills is often not the
  one that carried the element.

**The bound is the one every feel change here is held to: nothing about damage
moves.** Every one of these is the last thing its caller does, and `feel_check`
proves it rather than asserting it - a sound dropped past the cutoff leaves the
run byte-identical, an expiring element mark takes no health, a marked body
still counts as a kill, and leaning does not resize a tower.

**One check in that gate matters to every other gate in this project.** Headless
there is no camera and therefore no ear, so `play_at` must be exactly `play`.
An ear that attenuated anyway would have a hundred gates quietly measuring a
different game from the one that ships, and a missing sound errors nowhere. The
first cut of the gate did not catch that - it was found by planting the fault
and watching it pass - so there is now a check that plays a sound from nine
times the cutoff with nobody listening and insists it starts a voice.

**Two of the document's ideas need an owner and got one.** Named legendary
individuals and Notorious elites are both new persistence axes under working
rule 7. **Owner ruling, 2026-09-15: neither is built for 1.0.** They are
recorded in the triage as the strongest 1.1 candidates, and if either is ever
taken up it needs its bound written down first, exactly as spirits, the pantry,
professions and materials each did.

**And the second rank is deferred rather than refused** (owner, same date):
persistent footprints, boss entrance behaviours, post-battle settling and
anticipation audio on the telegraphs. All four are content rather than systems
and none of them is blocked - they wait until the four above have been played.

**Four more mythics, and the trail is a system rather than an animal, as of
2026-09-15.** `IDEAS_REVIEW_2026-09-15` shortlisted five creatures out of a
forwarded document of a hundred and twelve, on the grounds that the good idea in
that document was **Evidence -> Tracking -> Encounter** rather than any of the
creatures. The Moonstag was built with the trail; the Griffon, the Glimmerfox,
the Hollowhorn and the Phoenix are the other four.

**They cost the system nothing, and that is the test the trail had to pass.** A
mythic is a `WildlifeData` with `mythic = true` and five `TrailSignData` signs;
`MythicTrail._choose` takes whichever one belongs to the act. No code changed to
add four of them, which is working rule 3 doing its job - adding content meant
adding files.

**One legend a run, spread down the road.** `trail_first_act` runs 2, 3, 5, 6, 8
so the later acts have more to choose between rather than the same animal every
time, and a road still carries exactly one trail: three legends on one road is
none.

**Two of them fight and three of them flee**, which is the variety the first one
could not have on its own. The Griffon and the Hollowhorn are TERRITORIAL and
hold their ground; the Glimmerfox is the fastest thing on the road and the
Phoenix leaves. Every one of them is still an ordinary animal to the rarity
ladder, the sheen, the population cap, the wrath and the bond.

**And a lesson about the artefact cleaner**, because it nearly cost something:
`animator-invents-bright-blobs` says dark additions are motion and bright ones
are artefacts, and that rule is right for a griffon and **wrong for a creature
painted in light**. Stripping bright specks off the silhouette took the
Phoenix's embers with them - the effect was the sprite. The cleaner is run per
species, never over the roster.

**The crowd grid stopped reaching as far as the widest body on it, found
2026-09-15.** `crowd_check` went red on CI - eight of the widest non-boss body
stacked, and two of them ended 4.5 units inside each other and stayed there.

**The cause is the fourth instance of the same failure this project keeps
paying for.** `EnemyField.separate_crowd` buckets bodies into `CROWD_CELL`
squares and compares each against the eight cells around it, which is correct
only while a pair's combined contact radius fits inside one cell. It did, for as
long as the widest body on the road was an ordinary breed at 26. Then the camps
gained lords - `dragon_stone` is 58 - and a pair of them wants 116 units between
them against a 96-unit cell. Two sitting 111 apart land **two** cells apart, are
never compared, and stand inside each other for the rest of the run. Nothing
errored; the bodies simply overlapped, which is the thing the whole function
exists to prevent.

**Derived, not hand-kept.** `_crowd_reach` takes the widest body actually on the
field and searches however many cells that needs. A wave of ordinary breeds
still scans nine cells and pays exactly what it paid before; a camp with a lord
in it scans twenty-five for those few frames; and the roster may grow a wider
body without anybody having to remember this file. Raising `CROWD_CELL` instead
would have fixed today and re-broken on the next big thing, which is precisely
how it broke the first time.

**And the gate caught it by luck, which is not the same as catching it.** The
eight-body stack only fails when two of the eight happen to settle two cells
apart. `_test_the_grid_reaches_the_widest_body` is the fault on purpose: two of
the widest bodies astride a cell boundary, overlapping, and further apart than
one whole cell. With the old neighbourhood put back it reads `overlap 10.000 ->
10.000` - not one unit of movement - and names the reason.

**A body cannot be held still by swinging faster, as of 2026-09-15.** The
owner: *"even with enough swiftness players should not be able to hit/stunlock
enemies from constant fast attacks ... including shield bearing enemies to be
able to have an even higher chance of enduring/countering/blocking player hits
and having a chance to stand their ground, or reduce knockback"*.

**The hitstun was already capped and the knockback was not, and the knockback is
the lock.** `ENEMY_HITSTUN_GAP` has held a body to at most 30% of its time
locked since it was written, however fast it is hit - so the report read as
false against the code and was true on the field. `HERO_ATTACK_KNOCKBACK` is 170
units against an `ENEMY_KNOCKBACK_DECAY` of 900: a shove lasts about a fifth of
a second, so a hero swinging faster than five times a second keeps a body at
arm's length for ever and never stuns it once. **Swiftness bought spacing, not
stun**, which is why looking at the stun constants said nothing.

**So every body carries a footing.** Each blow that would flinch or shove it
adds `1 / stagger_tolerance` to a stagger load; what a blow's flinch and shove
are *worth* is scaled from full down to `STAGGER_MIN_SCALE` by that load; and
the load drains over `STAGGER_WINDOW` of not being hit. A fresh body is knocked
about exactly as it always was. A body already reeling plants itself. Leave it
alone for a second and it can be knocked about again.

**Damage never moves, and that is the whole bound.** A blow at a full load
takes the same health it always took - `balance_test` reads the same 29,003
assertions and `curve_report` the same band - because what changed is *where the
body is standing* and nothing else. That is the same bound the shots, the
statuses, the hides and the tower paths are all held to.

**Shield-bearers plant, and a plant is a refusal rather than a counter.** Past
`BRACE_AT` a body with a shield may set itself: no flinch, no shove, a ring of
its own, and whoever is standing on it is pushed off. It **deals nothing** - a
body that hit back here would be a source of damage arriving out of a fight the
player was winning, and nothing in `curve_report` models one. What it costs the
player is the spacing the spam was buying, and the body is then free to swing
because nothing interrupted it. `BRACE_REFRACTORY` is longer than
`BRACE_SECONDS`, which is the only thing between "a moment" and "a body that can
never be moved again".

**Both numbers are derived from what each body already declared** rather than
typed into sixty-seven files: its hide, its behaviour, its category and the
knockback resistance somebody already tuned. A boss endures one blow and then
walks through the combo; an anchor two and plants 45% of the time; stone two;
plate two and a half; an ordinary body five. Sixteen of the roster carry a
shield. Adding a breed gives it a defensible footing without anybody having to
remember a table.

**`stagger_check` (188 checks) drives all of it on the real field**, and three
things about writing it are worth keeping:

- **Every probe is kept alive between blows.** The first cut did not, the body
  died three blows into a twelve-blow flurry, and the gate then measured a
  corpse's last shove and reported the system as broken. A probe that dies
  mid-measurement reads exactly like a feature that does not work.
- **The drain went in the wrong tick.** It was added beside the brand's decay,
  and `_tick_brand` returns early unless a body is branded - so the footing
  never recovered and a plant never ended, for every body that was not branded,
  which is nearly all of them. It ticks beside the hitstun now.
- **The brace is forced to a certainty** by duplicating the resource, because a
  chance is a coin toss wearing a gate's clothes and this project has shipped
  four of those.

**Ten matched sets, as of 2026-09-15.** The owner: *"set items similar to
Diablo's style which grant extra bonuses at appropriate increments in wearing
enough of the set pieces. A wide variety of sets that are perfect and polished
for our game! Wearing a full set should have a visual vfx game juicy effect on
players!"*

**A set tier moves a number `Modifiers` already resolves and nothing else** -
the omen bound, the Road Card bound and the legendary-affix bound, applied once
more. Every tier lands in the same flat table a socketed relic feeds, so a tower
asking for `tower_damage` gets one number and nothing downstream learns that
sets exist.

**What a set costs is choice, and that is the honest answer to "extra".** Gear
grants attribute points on the capped scale levelling shares (working rule 7),
and a set changes none of that - every piece still grants exactly what its kind,
rarity and level say. What the player gives up is the freedom to pick: five of
eight slots locked to *particular kinds* is five slots where you cannot chase
the attribute you wanted, the rarity you found, or the affixes you were hunting.
`gear_set_check` measures the whole set against what the affix ceiling would
have allowed in those same slots, rather than asserting a figure, so the day
either ceiling moves the comparison still means what it says.

**Rarity is deliberately not a member condition.** A Common Ashfall Glaive still
counts toward Emberwind. A set that only assembled at the top rarity would be a
second lottery on top of the drop tables; the thing to hunt is the *match*,
which the road can actually give you.

**Nothing was added to the save.** A piece is still `{kind, rarity, level,
uid}`; whether it belongs to a set is a property of its *kind*, read from
`data/gear_sets/`. Gear found before sets existed belongs to one the moment it is
read, there is no migration, and `SAVE_VERSION` did not move. Every member is a
kind that already drops - thirty-seven of the hundred and fourteen - so no art
and no manifest row came with this.

**And a finished set turns at the feet.** `SetAura` is a ring of motes in the
set's own authored colour, flattened because the camera looks down and slightly
along and a true circle at the feet reads as a hoop standing up. It is read by
nothing, `Graphics.particle_scale` gives it away, and it *asks* `Modifiers`
rather than listening for a signal - equipment cannot change during a run, so a
wire for that event would be a wire for something that happens nowhere.

**The legendary-weapon half of that brief was already built**, and is recorded
here so it is not built twice: `Vfx._swing_signature` has graded the swing by the
worn weapon's rarity since it was written - motes along the arc in the weapon's
attribute colour, more of them at higher rarity, a ring on the finisher - and
`weapon_vfx_check` holds it. The gap was the *set* aura, which is what was
added.

**The fault worth remembering is a typing one.** `members` was written into the
`.tres` as a `PackedStringArray` against an `Array[String]` export, and Godot
**drops a mismatched typed assignment in silence** - so all ten sets loaded with
no members and could never be worn, while every file looked right. That is the
same family as `PackedStringArray([...])` not being a constant expression and as
data indexing an enum by number: a typed container in a `.tres` has to match the
export exactly, and nothing says so when it does not.

**There is a pen, and what is in it can be lost, as of 2026-09-15.** The
owner asked for living companions kept at a pen with idle, roaming and resting
animations, a cap with the option to release one to make room, a choice of which
one to take on an expedition, and - the important half - *"alive companions that
are removed from a pen will stay with the player for expeditions until the
player safely places them back in the pen outside of runs if the companion has
not died during the run it was taken into"*.

**This amends working rule 7, and the amendment is one sentence: the bond is
permanent and the animal is not.** `MetaState.pen` is a roster of *individual
living creatures* - `{uid, species, rarity, shiny, trait}` - capped at
`PEN_CAPACITY`. `spirit_bonded` is untouched by any of it, so an animal dying on
the road costs the player **that creature** and never a line in the journal: the
same variant can be raised again, and the entry that says they raised one stands.
A gate that let those two get confused would be a gate that let a death eat
discovery, which nothing else in this project does.

**A raised animal does not re-form, and that is the entire stake.** A bonded
spirit has come back after being beaten since companions were un-cut - that is
what `SpiritBond.recovery_seconds` is for and it stays exactly as it was.
`Companion.from_pen` is the one flag that separates them: a raised creature that
goes down is gone, told once on the field and *settled when the run ends*,
because a run still being played might yet be abandoned and the pen is not a
run's to edit.

**Lost only if it actually died.** A Warden who fell on the road did not get
their animal killed, so a lost run brings the creature home. That is a reading
of the owner's own conditional - "if the companion has not died during the run" -
rather than of "because of a successful extraction", which would also support
losing it on any failure. **Recorded as a reading rather than a certainty**: it
is one condition in `GameDirector._settle_run` if it is ever meant the other way.

**And the pen cannot be edited during a run.** Swapping the animal out the
moment it starts to look like dying is the decision being made after the risk
instead of before it, which is the whole thing taking a favourite out is
supposed to cost. `pen_take` refuses outside `Phase.ENDED`.

**One at a time, still.** What §54 cut is a *roster the player commands*, and a
raised animal walks in the same single slot a bonded spirit does - it is not a
stronger companion, it is the same variant at the same rarity on the same power
scale. It simply happens to be *that creature*.

**Additive, like everything before it.** A save written before the pen has no
`pen` key and reads back as an empty pen, which is also what a new account is.
`SAVE_VERSION` did not move and there is no migration to get wrong. A malformed
row - a species the roster does not have - is dropped rather than trusted,
because that list is the one place a bad row would put a companion with nothing
to draw on the road.

**And the pen is drawn rather than listed.** `PenYard` stands one sprite per
kept creature, each with **its own clock**, so a pen of twelve is never twelve
copies of one animation - they graze, wander somewhere and lie down on their own
schedules, and the gate drives forty seconds and refuses a yard where every
animal is doing the same thing. Their coats come from `Phenotype` off each
animal's own name, so the fox in the pen is the fox that walks out of it. The
yard is a *picture*: it writes nothing, and every button on `PenScreen` calls a
door on `MetaState` and re-reads the answer, so the cap, the one-at-a-time and
the mid-run refusal live in one place and a screen cannot disagree with them.

`pen_check` (71 checks) holds the cap, the release, the one-at-a-time, the
mid-run refusal, the dangling name, the malformed row, the read-back, and -
hardest - that losing an animal leaves the collection exactly the size it was.

**The road can be put down and picked up, as of 2026-09-15.** The owner
proposed 100 waves an act across ten acts - a thousand-wave campaign - with
extraction at crossroads and act ends that banks the world so the next run
resumes it. Two decisions came out of that and they are recorded separately
because they have very different costs.

**The wave count is deferred, and it is deferred on a measurement.** A full
ten-act campaign today is **79 waves**, and `curve_report` ends it holding **40
emplacements at level 2-3** on a purse of 7,510 Gold - with capability already
*flat* from wave 72, because by then the board is bought. Maxing the whole board
is roughly 78,000 Gold. At a thousand waves the purse is some thirteen times
larger: every tower reaches level 10 somewhere in Act VIII and there are then two
hundred waves in which the player can buy **nothing at all** while pressure keeps
climbing. That is the exact failure measured on 2026-09-13 - "capability went
flat from wave 48, the last third of the road paid for nothing" - three times
longer.

**Owner ruling, 2026-09-15: build the library first, then set the count by
measuring what it supports.** A count set first and filled in later is how an act
becomes a hundred repetitions of one loop.

**And the measurement corrected the argument above, in the owner's favour.** The
paragraph before this read "capability goes flat at wave 72, so the board is
bought" and concluded that a thousand waves would leave two hundred with nothing
to purchase. **That was wrong.** Flat capability at waves 72-73 is the model
converting *breadth into depth* - it holds 40 emplacements at level **2**, and
the ladder runs to **10**. Reading "flat" as "finished" is the mistake.

Measured properly: the ten upgrade rungs cost **2,475 Gold a tower**, so a fully
maxed board of forty is about **103,000 Gold** against the **5,846** a 79-wave
campaign now earns - a **17.7x** gap. Income rises with the act, so the true
figure is under a linear 1,400 waves and comfortably over a few hundred. **A
thousand waves is approximately where a fully-upgraded board lands**, which is
the number the owner proposed.

So the blocker was never the economy. The library is still worth having - a
hundred waves of one formation is a hundred repetitions whatever the purse is
doing - but it is a *variety* requirement rather than a *headroom* one, and the
wave count may rise as far as the content supports it.

**Expedition persistence is built, and it is independent of all of that.** It
works at 79 waves exactly as it would at a thousand.

**Two layers, and the split is the whole design.** *Persistent*: the seed, the
act, the wave, every tower with its level, its path and **how damaged it is**,
the run's currencies and the wall. *Regenerated*: the wildlife, the foliage, the
corpses, the drops, the weather. `Battlefield.refresh_terrain` already **is**
that second half - it is the one function everything regional goes through - so
coming back is the road being alive again rather than a battlefield frozen in
amber since Tuesday.

**It carries the road and never the account, and that is why it is not a second
save game.** No hero level, no gear, no attribute, no unlock: working rule 7's
list is untouched. Everything a snapshot holds already reset every run and none
of it has ever been allowed to persist. What changed is what a *run* is - a road
put down and picked up. `balance_test`'s save-key guard now names `expedition`
with that reasoning written beside it, and `expedition_check`'s hardest assertion
is that banking and restoring a front leaves the account byte-identical.

**A damaged fortification comes back damaged.** Owner ruling: extraction that
healed the board would make "leave the moment anything is damaged" the correct
play and attrition would stop existing. Tower health lives on the node and has
never been in `RunState` - it does not cross the wire either - so the snapshot
leaves the ratio in `RunState.tower_health_restore`, which `Tower._ready` reads
**once and erases**. A tower rebuilt for any other reason - a guest's welcome, a
re-sync - is whole; only the one an expedition actually restored is hurt.

**A wipe does not clear the front.** That is the anti-frustration rule and it is
the difference between pushing deeper being exciting and being horrifying:
everything before the last extraction is banked, everything since is at risk.
The gate drives a reset and refuses a build where the frontier goes with it.

**Momentum is bought by refusing to bank, and may never reach a fight.** Each
crossroad passed without extracting raises `RunState.momentum` toward
`MOMENTUM_MAX`; it feeds `kill_resources` and `resource_rate` and **nothing
else**. A damage stack bought by declining to save would be a power scale nobody
is tuning, and `curve_report` would be measuring a game that only exists for
players who never extract. `expedition_check` walks six forbidden keys and
refuses any movement in them - checked by adding `hero_damage`, which it named.

**Refused from the same proposal**, and recorded so they are not re-argued:
a third resource pool beside the stash and the vault (an expedition's currencies
are the *run's* currencies coming home, which is a flag rather than an
inventory); and crossroads that sometimes cannot be extracted from, because the
whole system rests on trusting the crossroads and the proposal's own "use very
rarely" is the shape of a feature that is either invisible or infuriating.

**The road pays less and asks more, as of 2026-09-15.** The owner: *"Reduce
all gold income and rewards and loot and make everything more expensive and
increase enemy counts and difficulty ... and make everything more balanced."*

**Three multipliers pointing the same way, so it was done as passes against
`curve_report` rather than as one edit.** Measured before: mean pressure
0.390-0.406 across party sizes, last wave 0.77, purse 7,510 Gold. Measured
after: **mean 0.501-0.506, spread 1%, last wave 0.99, acts ramping 0.42 to
0.72.** `balance_test` reads 29,005 assertions unchanged.

**The band moved, and that is the decision rather than the numbers.** This file
recorded a target of 0.26-0.46 mean pressure, arrived at over ten acts of
tuning. The owner has asked for a harder game, so the band is **0.44-0.58**
now, with a last wave allowed to approach 1.0 - a campaign that ends at the edge
of what a best-case defence can answer is a climax; one that passes it is a wall.
The old band is not wrong, it described a different game.

**And the release sweep caught the half of that which was only written down.**
`curve_report.PARTY_PRESSURE_FLOOR` and `_CEILING` still held 0.26 and 0.46, so
the report judged the re-tune against the game it replaced - printing PASS on
escalation and exiting non-zero on the band, which only a sweep reads. **A bound
recorded in prose here and enforced by a constant in a tool is two places to
change and one place to forget**, and the constant is the one that decides.

**Where the income cut was taken matters more than how big it was.** The first
cut trimmed Gold at `CURRENCY_YIELD_SCALE` alongside Food, Wood and Stone, and
`balance_test` refused it twice in one run: *a drop must pay exactly the amount
printed on it*, and *an order the Quartermaster calls affordable must be
payable*. Both are the game not lying to the player, and neither is worth a rate
cut - which is precisely why 2026-09-13 left Gold out of that table. **The cut
lives at the kill instead** (`KILL_RESOURCE_SCALE` 0.5 to 0.36), where a player
reads it as "bodies are worth less" rather than as arithmetic nobody can see.

- **Income**: a body pays 72% of what it did; the late-act ladder tops out at
  2.20 rather than 2.76; the road's passive trickle is down a fifth; Food, Wood
  and Stone are trimmed harder at the door.
- **Costs**: a tower costs about a third more to place, and every rung of the
  ten-level ladder is about a quarter dearer. The *shape* of the ladder is
  preserved - each step is still around a third more than the last - so a player
  still passes ten doors and each one simply costs more road.
- **Loot**: a body drops gear on 1.9% of kills rather than 2.4%, an elite on
  32% rather than 45%, a boss leaves two pieces rather than three, and a chest
  pays 44% rather than 55%. The floor is `_test_gear_farming`'s promise, not the
  constant: *a hundred ordinary kills must pay more often than not*. The first
  cut at 0.017 missed 18% of the time and the gate named it.
- **Pressure**: more bodies an act, more health, more invaders, and elites on
  17% of waves rather than 13%.

**And the act-end spike was eased where the spike is.** With a bigger count
table underneath it, `ACT_BOSS_RAMP_COUNT` and `_STATS` pushed the campaign's
last wave to 1.09 - past what a best-case defence answers. They are 0.10 and
0.14 now. The peak is still wanted; its *sharpness* is what had to give, which is
the same conclusion that table's own comment reached the first time.

**Marks for all ten acts, as of 2026-09-15.** The owner asked for *"more
unique enemy behaviors and trait's and abilities etc for all acts"*, and the
roster had **eight affixes with `from_act` capped at 3** - on a ten-act road. So
acts IV to X drew from exactly the pool Act I did, and a promotion stopped
meaning anything two thirds of the way along. **That is the fifth hardcoded
three-act range this project has found**, after the relic counter, the
Chronicle's `minimum_act`, the campaign tiers' boss table and
`wildlife_spawn_check`.

**Twenty-two marks now, spread from Act II to Act X**, and six new things a mark
may do - each moving a number the fight already has:

- **`spawn_guard`** - born wearing a ward, through the same `grant_guard` an
  anchor's shelter uses. It has to be hit twice to be hit once.
- **`on_hit_mana_burn`** - takes mana off a caster and is worth *nothing at all*
  against a swordhand. The same two axes the five shots vary along, and the only
  threat in the game whose weight depends on who the player decided to be.
- **`aura_radius` with `aura_speed` and `aura_resistance`** - the bodies around
  it move faster, or break harder. An aura is a **reason to kill this one
  first**, which is the readable play morale already makes of a champion.
- **`death_mends_allies`** - and the opposite decision: a body whose death mends
  its company is one to leave for *last*. Both exist so that "which of these do
  I hit" has more than one answer.

**Auras take the best rather than the sum**, which is the rule `_affix_best`
already follows a layer down: two marks multiplying would approach immunity, and
a body nothing can hurt is not a mark, it is a wall.

**And `elite_check` now holds both halves of what went wrong.** Every act must
draw from a pool of its own and the pool must *grow* across the campaign - the
three-act cap made the last act wear the first act's set. And **every field a
mark may carry must be named by some script outside the resource**: a field
authored and read by nothing is the `DisciplineEffects` lie in a second place -
the mark draws, the codex describes it, and it does nothing. Checked by adding a
field nothing reads, which the gate named.

**The wave library reaches all ten acts, as of 2026-09-15.** Building it was
the owner's ruling, and it turned out to be half built and capped:
**`WaveArchetypeData.minimum_act` was `@export_range(1, 3)` on a ten-act road**,
so acts IV to X drew from exactly the ten formations Act I did. **That is the
sixth hardcoded three-act range in this project**, after the relic counter, the
Chronicle's `minimum_act`, the campaign tiers' boss table, `wildlife_spawn_check`
and the enemy affixes. Every one of them was silent: a range that is too small
does not error, it simply never deals what nobody authored for the acts it
excludes.

**Most of the forwarded library was already expressible**, which is worth
recording so it is not built twice. An elite hunt is `extra_elites` with a low
`count_scale`; a horde is the reverse; a siege is a signature breed carrying
`targets_towers`, which six breeds already do; a pincer, a false front and a
delayed surge all exist. **Fourteen more formations** were authored across acts
III to X out of that same vocabulary.

**One kind was genuinely new: a wave with nothing in it.** `calm` sends no
bodies. The road still advances, the clock still runs and the trickle still pays,
and the player gets the stretch to build, gather, fish, work a seam or walk out
to a camp - which is what the outskirts are for and the one thing a wave every
ninety seconds leaves no room for.

**Its price is the purse it does not earn.** A calm wave pays no kill income at
all, so taking one costs a wave of income against a boss ramp that keeps
climbing. That is what stops it being a strictly better wave, and the gate holds
it.

**It ends through the same door every wave ends through.** A wave closes when its
queue is empty and nothing stands; a calm wave has an empty queue by
construction, so it closes on the next tick and nothing had to learn that a wave
can be quiet. **That is also the worst failure available here** - a wave with
nothing in it that cannot end is a run that cannot continue - so
`wave_library_check` drives a real director and fails if one is still running
after three seconds.

**And the first cut of that gate reported exactly that failure, wrongly.**
`WaveDirector._process` returns on its first line while the director is stopped,
and the gate had stopped it to clear the road before hand-ticking - so it
measured nothing and called it a wave that never ends. The harness, not the
director. A gate that drives a system by hand has to start it first.

**The opening act's extra road was never walked, found 2026-09-15.** The owner
reported *"the path to the first act 1 boss was too short"* twice. Twice
`ACT_OPENING_EXTRA_DISTANCE` was raised - 170, then 390 - and twice every model
agreed the fix had landed. **The game never read it.**

`Journey` closed an act on `_segment_index % SEGMENTS_PER_ACT`, which is a flat
act length. `Balance.act_end_distance()` is the one function that knows the
opening act is longer than the rest, and it is what `curve_report`,
`balance_test` and `RunState.distance_to_boss()` all ask. **The walk asked none
of them.** Driven on the real node: the Act I boss was called at distance **400**
while the readout on screen still promised **390 units** of road, and the models
all reported the act as 790 long. Every act was 390 units shorter in the game
than in every measurement of it.

**`distance_to_boss()`'s own comment is the bitter part.** It says it exists
because "a correctly-working boss trigger looks like a bug" with nothing counting
down. What it actually did was the exact inverse: it counted down honestly to a
number the walk had no opinion about.

**And a crossroad decided the act as well**, by dividing distance by
`ACT_DISTANCE` - a second answer to a question `resume_after_boss` already
answers, disagreeing with `act_end_distance` for every act on the road. It
matched the *walk* only because the walk had the same fault. An act now begins in
exactly one place: when its predecessor's boss falls.

**Why `balance_reach_check` could not see it, which is the transferable half.**
That gate holds every `Balance` constant to being read by something, and
`ACT_OPENING_EXTRA_DISTANCE` *was* read - by `act_end_distance`. **A constant read
only by a function the game never calls is exactly as dead as one nothing reads,
and it is far harder to see**, because every report built on that function
cheerfully says the feature works. It is the `DisciplineEffects` lie one layer
out: there, a key was implemented and named by no consumer; here, a consumer
existed and the game never reached it.

`journey_check` (81 checks) drives the real `Journey` for a whole campaign and
reads the distances back off it - never computing an act boundary a second way,
since having two answers is the fault. It holds where each boss is called, that
the countdown is spent when one arrives, that an act is announced once and only
after the act before it finished, that every act still forks, and that the
opening act is the long one **in the walk** rather than only in the table.
Checked by putting the original `% SEGMENTS_PER_ACT` back, which it named for all
ten acts and for the readout.

**The road is 622 waves long, as of 2026-09-15.** The owner proposed a hundred
waves an act across ten acts and ruled: **build the wave library first, then set
the count by measuring what it supports.** The library is built and this is the
measurement being acted on.

**The measurement overturned the objection I had made to it.** I had told the
owner that a thousand waves would leave two hundred with nothing to buy, reading
`curve_report`'s flat capability at wave 72 as "the board is bought". That was
wrong: flat capability there is the model converting breadth into depth, holding
forty emplacements at **level 2 of 10**. Ten tower levels were the owner's own
decision of 2026-09-11 - and **eight of them could not be reached in a complete
ten-act campaign.** The game was showing the player a ladder, pricing it, and
ending the road two rungs up it.

Maxing a board of forty costs about **103,000 Gold** against the **4,865** a
79-wave campaign earned. The economy was never the blocker; it was the argument
for a longer road.

**622 waves, ramped 36 to 106 an act, not a flat hundred.** Act I draws from
about ten formations and Act X from twenty-four, so one wave count is a
procession at the front of the road and a campaign at the back. Act I is also
the one act that opens with nothing built, and ninety minutes of it before a new
player meets a boss is a tutorial nobody finishes. Measured after, **on a new
account**: mean pressure **0.479-0.563** across party sizes against the
0.44-0.58 band, acts ramping 0.23 to 0.70, last wave 0.90, and the board
finishing at **level 8** on a purse of 52,709 - so the ladder is nearly climbed
on Normal and the last two rungs are what Nightmare and Hell are for.

**`ACT_ROAD_DISTANCE` is the one place the shape of the campaign is stated**, and
`act_end_distance` sums it. That is the whole change: a table the owner can dial.

**The three per-wave growth rates are scaled rather than re-tuned**, which is the
decision worth defending. `WAVE_HP_GROWTH`, `WAVE_DAMAGE_GROWTH` and
`WAVE_COUNT_GROWTH` each carry a long argument in `Balance.gd` about the curve
they were solved into - after the map gained buildable ground, after free
placement removed the slot ceiling, after the hero could reach +105% damage.
Rewriting those numbers would throw all of it away. Dividing them by the length
of the road keeps the shape exactly and changes only how many steps it takes to
walk it, so the reasoning above each constant still describes it.
`WAVE_SPEED_GROWTH` needed nothing: it already climbed with `journey_ratio()`.

**Height and length are separate knobs, and conflating them was the first cut's
mistake.** Setting the growth span to the old 79 waves reproduces the old
campaign's difficulty spread over the new road - and measured **0.15** mean
pressure, because threat stood still while a road eight times longer earned eight
times the purse. `WAVE_GROWTH_REFERENCE_RUN` is how far the curve *climbs*,
stated in waves of the old campaign, and it is 296 because a board that can now
reach level 8 is about five times the capability the old road ever bought.

**Per wave and not per unit of road, deliberately.** Expressing growth against
`journey_ratio()` would be tidier and would let a player who lingers - fishing,
working a seam, clearing camps - fight unbounded waves at a difficulty that never
moves. Waves getting harder while you stand still is what closes that door.

**A campaign is now about ten and a half hours, and that is what expedition
persistence is for.** The road is put down at a crossroad and picked up next
time, so ten hours is ten evenings and never a ten-hour sitting. An act is
33 to 98 minutes - a sitting each. Crossroads moved to every 560 units, about ten
waves, because at 200 a road this long would fork 189 times and a decision taken
every three waves is not a decision.

**Four things had remembered the old road and none of them errored.**

- **`balance_test` probed the wave curves at typed distances**, 1200 and 2550 -
  and 2550 for "Act 3" was a position on the *three-act* road before that, so it
  had been reading Act VI's stretch and calling it Act III ever since the
  campaign went to ten. Its "late-run enemies must move faster" check only ever
  passed because that distance was two thirds along a road three acts long;
  asked in Act III on the real road it reads a fifth of a campaign. Probes say
  how far through which act they want to stand now, and the speed check is asked
  at the end of the road, which is what it says.
- **"Iron Steppe must deliver the largest packs" wanted 1.25x** while its two
  probes sat at act-waves 12 and 22 of acts about seven waves long - so most of
  that ratio was the gap between two arbitrary indices rather than between two
  regions. Compared at the same point of each act, `WAVE_ACT_COUNT_SCALE` steps
  adjacent acts by about a seventh and the whole campaign by 2.3 times, which is
  the ramp it is authored as.
- **The Ledger became a vending machine.** An order fills over 540 units of road,
  authored as about nine minutes of walking - an eighth of the old campaign and a
  seventieth of this one. `exchange_check` named it. Re-authored as a share of
  the road at 2,400 units.
- **Three drawings of the road divided by `ACT_DISTANCE` to find an act
  boundary**, which finds none at all once the acts differ: the act progress bar,
  the beast scope's route ticks and their act markers. All three are `_draw`, so
  the fault was purely that the player was shown a road nobody walks.

**`ACT_DISTANCE` survives as the mean act and nothing may find a boundary with
it.** `CROSSROADS_PER_ACT` and `CROSSROADS_PER_RUN` are derived off the road now
rather than off `SEGMENTS_PER_ACT`, which stopped being an act's length - and
`balance_reach_check` immediately refused to let `CROSSROADS_PER_ACT` stay on its
unread list once the road-card gate started reading it, which is that gate
working exactly as intended.

**`curve_report` reads the account, and a whole session was tuned against the
wrong one, found 2026-09-15.** The release sweep measured mean pressure at 0.504
where the same commit measured 0.481 by hand, and put four players outside the
band. Neither number was wrong.

**The report is perfectly deterministic** - three runs against one profile agree
to the digit - and it reads the **save**. A levelled hero and worn gear are
capability it counts, so the owner's account (level 81, 37 gear points, 32 towers)
measures about **five percent easier** than a fresh one. The sweep points
`APPDATA` at a scratch directory, so CI has always judged the band against a new
account, and every measurement taken by hand this session judged it against the
owner's.

**The sweep's number is the one that matters**, for two reasons: it is the harder
case, and it is the game a new player is handed. The span was re-solved against a
new account and reads 0.479-0.563.

**Printed rather than fixed.** Measuring a veteran's road is a legitimate thing to
want; the failure was never knowing which one was on screen. `curve_report` now
opens with the account it modelled - "measured on a NEW account" or "a PLAYED
account", with the level, the gear points and the unlocked towers - and says
plainly when the band below is held against a different one. **To measure the way
the gate does, point the profile somewhere empty:**

    APPDATA=/tmp/empty LOCALAPPDATA=/tmp/empty godot --headless --path game ...

**The first cut of that line called a fresh profile "played"**, because it tested
for no gear and no towers. A new account is not an empty one: it opens with eight
towers unlocked and the run hands out a starting weapon, so those are never zero.
It keys on the hero's level, which cannot be baseline above one.

**This is the same family as the clean-profile lesson already in the memory
directory** - a CI profile has no bonded spirit, so a panel never drew and its
overlaps went unseen - and the same family as the camp lords in the road purse.
**A model that reads state measures whatever state it was handed**, and it will
not tell you which unless it is made to.

**A road may begin at any act you have reached, as of 2026-09-16.** The owner
asked whether players who reach an act should be able to start there
selectively, and whether the resources should be chosen or preset. **Owner
ruling: any act reached, and an authored baseline split into four doctrines.**

**It is not the expedition, and keeping those apart is most of the design.** An
expedition is *your* road, banked at a crossroad and picked up where you left it,
damage and all. An act start is a *new* road that happens to begin further along:
a different seed, a different world, an untouched wall. They are separate doors
and neither consumes the other - the menu says so in as many words, because
confusing them costs a player a banked front.

**Why it earns its place now.** With 622 waves, a wiped expedition otherwise
costs five hours of walking to stand where you were standing, and gear is "the
reason to replay" (2026-09-01) - so being unable to go to the act that drops what
you are hunting makes the hunt a formality.

**Two doors already existed, and that is why this cost so little.**
`Expedition.apply` knows how to put a road down before the field is built, and
`try_build` knows how to buy a tower. So `ActStart.begin` puts the road down in
exactly the place `Expedition.apply` is called, and the doctrine *spends* the
baseline through the same function a player's own build calls. **The board an act
start leaves is a board the road could have produced, at prices the road
charges** - no second placement path, and no economy rule had to learn that act
starts exist.

**The budget is measured, never authored.** `curve_report` prints the purse at
every wave, so what a Warden who walked to Act VII actually holds is a number the
model already knows. `ACT_START_BUDGET` is read off that report **on a new
account**, which is the account the band is held against. It is re-measured by
hand rather than re-derived by the gate, deliberately: a gate that recomputed the
purse would be a second copy of `curve_report`'s model, and two models of one
thing is the fault this project keeps paying for.

**"Shape, never size" is literally true rather than a convention.** Every
doctrine spends the same budget and hands over whatever it does not spend, so
`act_start_check` measures the whole outfit - what was built plus what is in the
purse - against what it was given. No doctrine can be worth more than another by
hoarding, and nothing is created at the door.

**Nothing persists, and working rule 7 is untouched.** Which acts are open is
*derived* from `best_distance`, a run statistic the save already keeps - a new
key would have been a second answer to a question the save can already answer. So
there is no migration and `SAVE_VERSION` did not move.

**Three faults came out of building it and every one was mine.**

- **Breadth was a share of the purse, so the card lied.** Bulwark favours the
  Earth wardens, which are dear, so the widest doctrine in the game stood up a
  *narrower* board than the balanced one. Sorting the choices by cost helped and
  did not fix it, because a preference is worth more than a tie-break. **Breadth
  names a count now** - `ACT_START_BOARD_MIN` to `_MAX` - and the element decides
  only *which* towers stand there, which is what it was always meant to decide.
  The gate holds the widest doctrine against every other, not merely against the
  narrowest, because the first version of that check passed while the lie stood.
- **The harness cleared the board after resetting the run**, so
  `RunState.towers` was already empty and every previous doctrine's emplacements
  stayed standing on the live field. Later doctrines then found no free anchors,
  and the widest measured as the narrowest. The harness, not the feature - the
  same shape as the quiet wave that "never ended".
- **The screen put Close off the bottom of a landscape phone, twice.**
  `UiMetrics` inflates a button to a thumb on a touch layout, so two stacked
  buttons pin 240 pixels of a 430-tall screen before anything else gets a pixel.
  The body scrolls and the buttons share one row now. A sideways
  `ScrollContainer` for the act row was refused by `menu_check` for a better
  reason than height: **every menu scroll surface shares one interaction
  contract**, and disabling the axis `prepare_scroll` mandates breaks it. Ten
  acts want to wrap, not scroll.

**And `balance_reach_check` was right twice in one pass.** `ACT_START_SPEND_CEILING`
was authored and read by nothing - the bound it described is real and is held by
the gate *measuring* the outcome, which needs no constant, so it was deleted
rather than wired. And naming `RESOURCE_PER_DISTANCE` in a comment took it off
the unread list, which was the gate asking a fair question: the other three
wallets are derived from the road's own trickle over the distance walked now,
rather than from a share of a Gold figure they have nothing to do with.

**The tail was never receiving the beast's grade, found 2026-09-16 on the
seventh report.** The owner has reported Yuri's tail as not colour-graded like
the body seven times, and six passes were spent on it. **Every one of those
passes measured the two paintings. None of them measured the screen.**

Photographed and sampled off the render:

    body  modulate = (0.58, 0.473, 0.476)      warm, dark, strongly coloured
    tail  modulate = (1, 1, 1)  self = (0.8, 0.8, 0.8)      flat grey

The limb came out **+27% brighter than the hide and desaturated to 1.6% against
its 4.8%** - a grey tail on a warm animal, which is exactly what was reported
every time. And `beast_scope.gd` carried a comment asserting the opposite in as
many words: *"`modulate` is inherited from the beast, so the day tint and the
environment grade already reach it"*. It does not reach it. **That false comment
is why six passes were spent tuning a ratio that was then multiplied by grey
instead of by the beast's own grade** - including `BEAST_TAIL_SEAT`, an authored
20% darkening added to answer "the tail reads lighter", which was treating the
symptom of a missing grade.

`BeastTailSpline.wear_grade` is handed the grade at the same moment the body is
given it, in both scopes. Measured after: **+6.6% luminance and +2.9 saturation
points**, against +26.7% and -3.2 before. The seat offset went back to 1.0,
because with the grade applied its cause is gone and leaving it would be the
same fault pointing the other way.

**Two things it dragged out with it.** `_surface_mean` returned
`get_luminance()`, so two colours of one brightness and different hues measured
identical - and "not colour graded the same" is a hue complaint a greyscale
scalar can never answer; it is per channel now, and it reads the whole limb
against the whole rear of the body rather than a strip at the seam, which agreed
within nine percent while the length of the tail did not. And **`menu_shot` had
been printing "no tail sprite found" over a tail plainly on screen** since the
tail became a spline: it cast to `Sprite2D` and a spline is a `Node2D`. A
diagnostic lying about the one thing it exists to report is worse than no
diagnostic, and it is why nobody caught the grading in a photograph.

**The lesson is the one this project keeps relearning in new clothes.** A model
of a thing is not the thing: the camp lords drifted a roster average, the curve
report read the wrong account, and here six passes measured source art while the
owner was looking at pixels on a screen. **When a report and the code disagree
seven times, photograph the output and measure that.**

**And the far end settles**, which was the other half of the same request. The
droop is in the *rest pose* rather than in the walk - `beast_tail_check` holds
that the chain at rest reproduces its rest pose exactly, which is what catches
the wave distorting the art, so a droop added in the walk reads to that gate as
precisely the distortion it refuses. Zero at the root and all of it at the tip,
because `BEAST_TAIL_LIFT` lines the seam up and was set by two separate reports
about that seam.

**A head-on body turns too, as of 2026-09-16, and the refusal narrows rather
than reverses.** The owner reported a body "only facing 1 way like the ember
shamans were... They need to be able to face where they're going and targeting
properly."

**There was no code bug, and that is the useful finding.** The flip works, and
is *deliberately* off for `Facing.FRONT` - about thirty-eight of the roster -
because mirroring head-on art is what produced the "facing backwards" reports of
2026-09-13 and -14. The two reports are the two halves of one dilemma: art drawn
square to the camera can neither mirror correctly nor turn.

**What made the first answer wrong is that it treated every head-on sprite as a
shield-bearer.** Mirroring the Rootshield moves its shield to the other arm and
mirroring the Crown Herald sounds its horn out of the back of its head - those
genuinely cannot flip. A bandit's sword changing hands reads as a man who turned
round, and a symmetric brute does not change at all.

So the refusal is now "a sprite carrying a **handed** prop" rather than "a sprite
drawn head-on", and it is **derived rather than hand-kept**: `brace_chance` above
zero already means the body has a shield, authored on sixteen breeds for the
stagger work. Only the two horn-bearers needed `art_handed` saying out loud.
**A symmetric sprite is unaffected either way**, so this can only add a turn
where there was none.

**And I went at this the wrong way first.** The response to the ember shaman was
to regenerate it as a profile, and the owner stopped it: *"Ember shaman didn't
need to be regenerated, it's this bug that's the issue."* They were right - one
breed at a time is not an answer to thirty-eight, and the art was never the thing
that was wrong. **Wildlife was already correct** and needed nothing: it flips
toward its motion for every animal.

**The menu camp moves into the corner it was always meant to be in, as of
2026-09-16.** The owner: the campfire "is off the edge of the cliff and needs to
all be moved further right", the ledge's left edge "shouldn't have such a fade
out", and the whole outcrop should be "attached to the far right side of the
screen on the bottom right anchored" as foreground parallax.

**Three numbers, and each of them was describing an intention rather than the
picture.** `MENU_CAMP_BAND` put the vignette at 62-70% of the width - the middle
right rather than the corner. `MENU_CAMP_ROCK` darkened the outcrop to 0.44 on
the reasoning that a foreground mass "should be close to a true silhouette";
photographed, it was closer to *absent*, and indistinguishable from the dark
ground behind it. And `fire_side` was rolled either way, so a fire could land on
the open-air side of a ledge that runs off the right of the screen - which is
exactly the fire hanging in space that was reported.

**The first correction over-shot, and the gate caught it.** Pushed to 17% in from
the right, the Warden stood behind the run statistics - the precise fault the
note above `MENU_CAMP_BAND` warns about. `menu_camp_check` then refused the fire
for being "under the interface".

**And the fix for that was to move the interface, not the camp.** The statistics
are text and the corner is what the owner asked for the rock to have, so they
lift 160px off the bottom. **Which made the gate's own bound wrong**: it held the
fire inside a literal 0.2-0.8 of the width, and that 0.8 *encoded* the statistics
owning the right fifth. `MENU_CAMP_CLEAR_OF_INTERFACE` is that bound named in
`Balance` and read by the gate, so the layout and the check cannot drift apart -
the same failure `curve_report`'s pressure band shipped with once, where a bound
lived in prose here and as a number typed into a tool.

**The fire's shafts are three now, feathered, each its own length.** A
`draw_colored_polygon` cannot have a soft edge - one colour for the whole shape
is what a hard edge *is* - so each shaft is three quads with a colour per vertex:
a core and a feather either side whose outer vertices are transparent. Each cone
takes its reach, sway rate and flicker phase from its own irrational step through
the fire's seed, so no two over one flame fall into step; the old pair shared a
length and read as two wipers rather than as light.

**A hero in deep water still swings, slowly, as of 2026-09-16.** Owner: "Players
can't attack when it becomes heavily flooded, they should still be able to attack
but at a much slower rate than usual."

**The refusal was written for a pond and a flood is not a pond.** `Hero._process`
read `can_fight() and not _swimming` - "no weapon in the water: a swimmer has
both hands full staying up" - which is fair for somebody who swam out to a
fishing spot and wrong for water that arrives where the fight already is. The
road is still full of bodies and they do not stop; being unable to answer is a
spectator seat rather than a cost. `HERO_SWIM_ATTACK_DRAG` stretches **every
phase together**, the same rule Swiftness and the weapon are under, so the
telegraph stretches with the blow instead of the swing becoming slow and
unreadable.

**And three call sites became one.** The windup, the active and the recovery each
multiplied `_swiftness_scale() * _weapon_scale() * _haste_scale()` by hand, so a
fourth factor had three chances to be added and two to be forgotten - which is
exactly how an Arcane node once shipped with its reach applied at four of five
throws. `HeroAttack._phase_scale()` is the one place. `HeroAttack` still does not
know what a `Hero` is: `drag` is a number the hero sets, as `damage_multiplier`
already was.

**Nine coat patterns instead of four, as of the same date.** Owner: wildlife
"needs more shaders for their variety patterns to make them all more unique and
diversified ... appropriately designed for each wildlife."

Twenty of forty-four species carried one of the four old patterns and the other
twenty-four carried none, so a raccoon, a raven and a marmot were each a flat
colour shifted a little. **DAPPLE, BANDS, MASK, SPECKLE and COUNTERSHADE** are
each a shape a coat actually has rather than another noise function - and
countershading in particular is the one that still reads when a sprite is forty
pixels tall, which is why the small species get it. Twenty-two species were
re-coated to the shape of the animal: the raccoon's and badger's masks, the
hedgehog's banded quills, the otter's countershading, the moth's speckling.

**Appended to the enum, never inserted.** `WildlifeData.coat_pattern` is indexed
by number out of every `.tres` that names one, and this project has twice shipped
content pointing at the wrong member because somebody added one in the middle -
`Role` and `Trigger` both did it.

**The bound is unmoved: a coat is a look.** `PHENOTYPE_HUE_CEILING` still stops a
fox turning blue, a marking must still never be mistaken for the rank sheen that
says rarity, nothing reads a pattern, and `Graphics.KEY_PHENOTYPE` still turns
every one of them off with no number moving.

**The Update Manager and the launcher are windows rather than fixed pictures, as
of 2026-09-16.** Owner: "elevate the update manager tool app so that it can be
resized appropriately and also allowing panels to be stretched for convenience,
as well as allowing fullscreen support", and "elevate the launcher app".

**The Update Manager resized and nothing followed.** The form was a fixed
776x700 and every control inside it sat at an absolute point with an absolute
size, so dragging the window bigger grew the grey around a 752x652 island - the
tuning tree stayed 260 wide with a hundred entries in it however much room there
was. The tab strip fills the form now, and the tuning page is three docked bands:
a filter strip, a button strip, and a middle that takes the rest.

**The divider is the part that was actually asked for.** A `Splitter` between the
sections tree and the values panel, because how much room each deserves depends
on what you are doing - reading a long list, or editing one number - and that is
the user's call rather than a number in this file. **Docked bottom-first**, since
WinForms docks in reverse order of addition and a `Fill` added before a `Bottom`
eats the bottom's room.

**F11 fills the screen in both apps**, Escape leaves. The bounds are *remembered*
rather than recomputed, so leaving puts the window back exactly where it was - a
window restored by size alone drifts a little every time.

**And the launcher stops taking the whole screen to fetch a zip.** It opened
forced fullscreen at 1920x1080 (`window/size/mode=3`), which covered whatever the
player was doing while it downloaded and could not be moved aside. Windowed at
1280x800 and resizable, with fullscreen as a choice. Its key handling is
`_unhandled_input` rather than `_input`, so a key pressed while a text field has
focus reaches the field first.

**The launcher wears the game's face, as of 2026-09-16.** Owner: "The launcher
is outdated and needs the new aesthetics and polish for production ready release!
It should be more like the main menu scene now!"

**It was two generations behind and nobody had looked.** `launcher_bg.png` and
`launcher_logo.png` are the *same dimensions* as the game's `menu_key_art.png`
and `ui_logo.png` - they were copied across once and never again - so the first
thing anybody sees of this game was a flat-colour pixel horizon from long before
the painterly jungle-gate key art, under an old wordmark. Both are copies of the
current art now.

**The carved border and the corner foliage are a drawing rather than a port.**
`MenuFrame` and the menu's foliage are several hundred lines each of shader,
wobble, sheen and per-strand placement, and they live in the *game* project - the
launcher is its own Godot project and cannot reach across a `res://`.
`LauncherDress` is one `_draw` laying the same carved edge and corner art with
the same hanging fronds, swaying on two rates so the motion has no period a
person can catch. It redraws twenty times a second rather than every frame,
because this is a window that spends its life waiting on a download.

**Two faults in that work, and both are ones this project has hit before.**
`move_child(dress, 0)` put the border *behind* the backdrop, where a frame is
invisible - the three scenery nodes come first and everything pressable comes
after, so it belongs at index 3. And `_draw` read `size`, which on a `Control`
added from code is **zero until the next layout pass**, so the first cut drew a
border zero pixels wide and the launcher came out looking exactly as it had. It
reads `get_viewport_rect()` now: the window is the thing being framed and the
window always knows how big it is.

**Photographed rather than asserted**, through a new `launcher/tools/launcher_shot`
- which is how both of those were caught, because each one leaves a launcher that
loads perfectly cleanly and looks unchanged.

**And then the border and the foliage came out again, on the owner's call.**
Two passes were spent on them - rooting the fruit on strands, insetting the band,
grading everything down - and the owner's verdict was that they "just lower the
quality and polish so just remove them". That is the right call and the reason is
worth keeping: **it was a `_draw` laying the menu's textures flat.** The menu's
frame gets its look from a shader, a wobble, a travelling sheen and per-strand
placement; copying the art without the machinery was always going to read as
flatter than the thing it was copying. Fewer pieces that move properly beat more
pieces that do not.

**What replaced it is the real shader.** `title_hologram.gdshader` is copied
across from the game rather than reimplemented - two shaders claiming to be one
effect would drift - and driven from the clock the launcher already runs. What it
takes from a hologram is its *behaviour*: a sheen travelling across the lettering
and a faint channel split. Not a blue palette; the wordmark is gold and stone,
and tinting it would be a different logo. Skipped headless, where compiling a
shader is an error the pipeline test reads as a failure.

**And the release notes stopped showing their own syntax.** The panel has
`bbcode_enabled` and GitHub writes Markdown, so every note rendered with
`**Full Changelog**` asterisks on show - the one piece of raw syntax on an
otherwise finished window. Translated rather than stripped, and conservatively:
anything unrecognised is left exactly as it was, because a note that renders
plainly is a small fault and one mangled by a clever regex is a worse one.
`String.replace` in GDScript takes **no count argument**, so the bold pass
splices by index - a plain replace turns every marker on a line into an opening
tag.

**And the addresses in them are links** (owner, 2026-09-16: "make links in the
launcher app work like a simple hyperlink click"). Three things make that behave
the way a person expects rather than merely function. **Markdown links are
wrapped before bare URLs**, because the bare pass run first eats the address out
of the middle of a `[text](url)` and leaves its brackets stranded around a tag.
**It looks like a link before it is clicked** - underlined, with a pointing
cursor on hover - since a thing that only reveals it is clickable once you click
it is not discoverable. And **only `http` and `https` open**: `OS.shell_open`
hands whatever it is given to the shell, and these notes are text fetched off the
network, so a `file://` or a handler URI in one is not something this window will
run. The whole point of a launcher is that it is the trusted thing.

**The stash is one shape, and its rows stop being eight lines tall, as of
2026-09-16.** The owner sent three screenshots of it: "not properly sized nor its
internal elements ... needs a strong polish overhaul", "bring the close button
anchored to the bottom of the panels", and one captioned "this time it opened
like this" - the same screen, a different shape.

**Three faults, and the first explains the photographs.** Five row actions at
`ACTION_WIDTH` are 660 units of a 940-unit panel; with the icon that left a
piece's name about two hundred wide, so "Chainbroken Coalpaint Edge · Weapon ·
Lv3 · +6 Might, +3 Vigour…" wrapped to **eight lines**. An `HBoxContainer` child
fills the box's height and the box is as tall as its tallest child, so the row's
buttons then stood a hundred and twenty units tall. That is the whole of "the
internal elements are wrong": one narrow column, and everything else stretching
to match it.

- The actions **keep their own height** (`SIZE_SHRINK_CENTER`) rather than
  growing with the row. The name may be as tall as it likes; a button stays the
  size a button is.
- The name gets a **floor** (`NAME_FLOOR`), because the name is the thing the
  list exists to be read for.
- The panel gets a **height floor**. It was free to be as short as its contents,
  so a filtered list with two pieces collapsed into a strip floating mid-screen
  with Close beneath it - which is both "not properly sized" and why the Close
  button reads as sitting at the top of the space rather than the bottom of a
  panel. It is most of the screen now whatever is held, and the scroll takes up
  the slack, so the screen is the same shape every time it opens.

**Half the Guide's pictures were photographs of something else, found
2026-09-16.** The owner went through the Guide section by section and reported
about fifteen images as showing the wrong thing: the bow "not really
demonstrated", no boss in the boss picture, "nests and eggs not visible", the
Forge picture "wrong on the resources tab", "trading and the Ledger bad".

**They were not wrong so much as absent.** `guide_shots.gd` takes about
twenty-eight photographs and then `_copy`s them into fifty-six files. `bow`,
`boss_fight`, `fog`, `minimap` and `enemy_shots` are all literally the same
`waves` picture; `gear`, `trading` and `forge` are all the same photograph of the
stash. A section about the Forge illustrated with a picture of the stash is a
picture of something else, and every one of those reports is that.

**The resolution was the other half**, and it is one number for all of them.
`SIZE` was 640x360 - a three-times downscale off a 1920-wide frame - which is
most of "low quality" before any zoom is argued about. It is 960x540 now, the
same 16:9 the Guide lays them out in, so nothing about the page moves.
`ASSET_MANIFEST` records the size of every picture and `asset_report` checks it,
so those fifty-six rows moved with it.

**Converted so far: the Ledger and the Forge**, which are screens that need no
game state behind them - `_screen_shot` stands one up alone and photographs it.
Four more are zoomed rather than framed across a whole battlefield: the towers,
the traps, the wells and the fishing.

**This paragraph listed seventeen sections as "still copies" and was stale by
2026-09-16.** They were converted across the sessions that followed, one harness
job at a time, and nothing updated the list here. Measured rather than read:
`guide_shots.gd` holds **three** `_copy` calls, and hashing `art/guide/` finds
**71 distinct images across 73 pages**.

The three are all glossary pages and all deliberate - `glossary_a` takes the act
track, `glossary_b` the relics, `glossary_c` the night - because a glossary is a
word list and the picture beside it is context for the words rather than a
photograph of a thing. (`relics` has since been re-shot, so B differs from its
source on disk.)

**Recorded rather than quietly corrected**, for the reason the starting-gold
paragraph was: this file is the first thing every session reads, and a list of
outstanding work is a *model*. Hash the folder and grep the tool before building
something that already exists - that is the same lesson the loot-magnetism
triage taught on the same day, in the same document.

**Blood stopped being circles, as of 2026-09-16.** The owner asked to "elevate
the blood shaders on characters and vfx and game juice to maximum perfect
aesthetically appealing polish". The shader on the *characters* was already the
interesting one - blood is speckled onto individual texels rather than washed
over the sprite, which is what stops it reading as a status effect. What had
never been looked at is the blood on the ground and in the air.

**Both canvases drew with `draw_circle`.** A perfectly round shape in one flat
colour - which is the third time this project has paid for the same finding,
after the swim sheen and the menu campfire: **one colour for the whole shape is
what a hard edge *is***, and nothing wet has one. `BloodInk` is the shared
answer, and it is the same technique both of those ended at - a fan of triangles
with per-vertex colour, a solid middle, and a rim at zero alpha, handed to one
`canvas_item_add_triangle_array`. It is **fewer** draw calls than the circles it
replaced, not more, which matters because a busy wave lays down hundreds.

**A splat is one pool and then satellites**, and that was the second photograph
rather than the first idea. With every blob thrown from the same distribution a
mark came out as four or five separate lumps with a hole in the middle - a
scatter rather than a spatter. The first blob is now the pool the blow left,
sitting where it landed; everything after it is what sprayed off, smaller the
further it went and drawn out along the way it was going.

**Feathering costs ink, and that had to be paid back deliberately.** A feathered
blob carries about 0.68 of the colour a flat disc of the same radius did, so
swapping the discs quietly took a third out of every mark on the field.
`BLOOD_GROUND_ALPHA` went 0.50 to 0.68 - arithmetic, not taste. The change was
meant to soften the edge, not to wash out the mark, and left alone it would have
read as "blood is too faint now" with nothing pointing at the cause.

**`BloodInk.MAX_LONG` is a cap in the painter rather than at each caller**,
because the failure is the same wherever the stretch comes from: past about
twice its width a blob stops reading as a drop of something and starts reading
as a slash. The first cut of the airborne motes came out as claw marks across
the screen. A caller may now hand over any velocity it likes and still get blood
back.

**And the gate could not see any of it.** `blood_vfx_check` asks whether a burst
*exists*, which it did throughout - so every check passed for as long as the
circles shipped. It drives `BloodInk.blob` directly now, which is the right
seam: the blob is pure arithmetic over arrays, so its shape is measurable
without rendering anything. Checked by putting the flat disc back, which it
named by the rim's alpha.

`blood_shot` is new and is the half a number cannot answer. Two things about
building it are worth keeping, because both made a working feature photograph as
a broken one. `BLOOD_GROUND_Z` is -3 so blood lies under what walks on it, which
on a bare diagnostic plate puts it **behind the plate** - the first run
photographed an empty rectangle. And the window is sized in pixels while the
marks are laid in *content* units, so without pinning the content scale every
mark came out at about half the size it is in play, and was read as blood being
too small when it was the picture that was shrunk.

**Something decides what the screen is for, as of 2026-09-16.** The owner
forwarded a two-hundred-item game-juice list and asked for it to be triaged for
implementation, adaptation or rejection. `docs/IDEAS_REVIEW_2026-09-16.md` is the
triage - about ninety of the two hundred are already built here under other
names - and this is its Tier 1, which the document itself also put first.

**Every effect in this game is emitted at its call site**, and that is correct:
`Enemy` decides its own sparks, `Tower` its own kick, `Meteor` its own rings. It
is why the game feels as it does. What no part of it could answer is **whether
this is worth the player's attention against everything else happening**, and
**whether a whole class of effect can be turned down**.

`JuiceDirector` is one number - a weight between a floor and one - that the
places which finally decide a presentation multiply by. It is not a second
effects system and must never become one.

**The bound is the one every feel change here is held to:** a director may change
how something is *presented* and never whether it happened. Turn every scale to
zero, fill the load to its ceiling, and the run is identical.

**The priority order is the design**: telegraph, hazard, boss, player, cosmetic.
A telegraph is never damped whatever else is on screen - a warning turned down
under load is turned down at exactly the moment it is needed - and adds nothing
to the load, so two warnings cannot crowd each other out. Everything below gives
way in order, so what a busy frame loses is decoration rather than information.
**And nothing ever reaches nothing**: every priority keeps an authored floor,
because an effect that disappears under load reads as a bug rather than as
restraint.

**The load is derived rather than ticked**, which is what lets this be a static
class with no node and no `_process`: a note records a load and a time, and a
read decays from the elapsed time on the spot. That also makes it exactly
reproducible for a gate, which hands in its own clock instead of waiting.

**Two comfort scales joined the shake slider** (the accessibility half, #182-#195
of the list): screen flashes and damage-number density. **Scales rather than
switches, which is the part that was missing** - the graphics options could turn
the fog off and the phenotypes off, and there was nothing at all to say to a
player who wants *half* the flashing rather than none of it, so the only honest
answer available to somebody made ill by it was to stop playing. Density is
deliberately not a switch either: turned down, the ordinary numbers thin out and
the criticals and finishers stay, so what is lost is clutter rather than
information. Both default to 1, so the shipped game is exactly what it was.

**The shake slider was already there and is now read in one place.** It had been
a raw `MetaState.settings` lookup with the key spelled out in the camera rig - a
second definition of a setting `UserSettings` already owned, and the shape that
produced an Arcane node applying its reach at four of five call sites.

**Three faults were planted to check the gate and the third one walked straight
through it**, which is the part worth keeping. A telegraph that gives ground and
a broken priority order were both named immediately. A director scaling *damage*
was not - because the payout test summed total damage dealt to death, and that
is the body's pool whatever a blow is worth. It measures **what one blow takes
off and how many blows it takes** now, which are the two figures that actually
move, and it then names the planted fault exactly.

**And the gate twice passed having measured nothing at all.** `Enemy` has no
`configure` and no `is_alive`; GDScript aborts the whole function on a call to
one that does not exist, so the harness returned an empty dictionary, the
comparison loop iterated it zero times, and the gate printed PASS. **A comparison
of two nothings is the most dangerous shape a check can take**, and it now
refuses to run on an empty result.

**The room goes quiet when a boss falls, as of 2026-09-16.** #138 of the
forwarded list, triaged as "trivial to build, enormous", and it is both.

An act boss falling is the loudest moment in this game - the kill flash, the
slow, a 22-magnitude shake, `boss_fall.gdshader` draining the colour and inking
the field away, and a full-screen card. Piling a victory sting straight on top
of all that is the one arrangement in which none of it lands. Taking the room
away first is what makes the release a release.

**It ducks and never mixes.** `AudioBuses` applies the hush on top of the
player's own faders, on the master bus, so one multiply covers the music, the
effects, the ambience and the weather at once - four separate fades would not
stay in step - and not one slider on the settings screen moves.

**Never to nothing**: total silence reads as the audio having crashed, so the
world stays faintly there underneath. Down fast and back slowly, because a drop
a listener can follow reads as a fault in the audio rather than as the world
stopping, and a return that is quick is a click.

**The failure worth gating is silent and permanent.** A hush interrupted and
never resolved - by a scene change, a gate tearing the audio down, a second boss
- leaves the master fader at a tenth for the rest of the process while every
slider still reads what the player chose. Nothing errors, nothing sounds broken,
and the game is simply quiet forever. `feel_check` cuts one short through
`stop_immediately` and insists the room comes straight back; checked by removing
that line, which it named.

**A Label cannot be smaller than its font, and `layout_check` was red on main
because of it, found 2026-09-16.** The pool bars wear their names - "HP", "MP",
"SP" - written on the bar rather than beside it, because the top bar has no
width to give. That is fine for the health bar and impossible for the two thin
ones: **`Control.size` is clamped to the combined minimum size**, so a Label
anchored to fill an eight-pixel bar is not eight pixels tall. It is as tall as
its font wants, and it hangs out of the bottom of its parent onto whatever is
underneath. "MP" was sitting across the SP bar.

**Two fixes were tried and measured before the third.** *Growing the bars to
fit*: at 430 wide the pools column has no vertical room to give, and taller bars
pushed the whole top row down into six fresh overlaps in the act line, the boss
readout and the city icon. *Putting the name beside the bar*: a row is as tall
as its tallest child, so the Label drove the row height exactly as it had driven
its own, and the same six overlaps came back. There is no height here and there
is no width; the name cannot be a laid-out node at all.

`BarName` is a plain `Control` with a `_draw`. A `Control` has no font-driven
minimum, so it is exactly the rect it is given; the glyphs paint a pixel or two
past a very thin bar, which is what a name written on a bar looks like, and
nothing in the layout can collide with something that is not in the layout.

**And the gate that would have caught it does not run at release.**
`layout_check` has been in `guard.yml` since 2026-08-25 and was never in
`release.yml`, so a HUD overlap could reach a tag as long as nobody pushed in
between - and the SP bar's name sat on main for exactly that reason. Both phone
shapes are on the release bar now. **A gate is only as good as the last time
somebody ran it, and the release is the last time anybody does.**

**`ui_shot` photographs the HUD now**, which nothing did. The names are *drawn*,
so `layout_check` passing says only that they collide with nothing - a name that
rendered as nothing at all would pass it perfectly. That is the same distinction
`a-passing-art-gate-cannot-see-quality` records, arriving in the interface.

**The loot goblin never once reached cover, found 2026-09-16.** `raccoon_check`
was red on main — the fourth gate in two days to be — and the three failures
cascaded from one: with the gear in its sack it did not run for cover.

**The cause is that `THIEF_HIDE_DISTANCE` bounds the destination and says
nothing about the route.** `_hiding_spot` took the *nearest* tree that stands
`THIEF_HIDE_DISTANCE` from every hero, which is frequently on the far side of
one. Traced on the real field: the thief grabbed the gear at 1.8s, picked cover
732 units from the hero — legal — walked straight at him, took fright at 8.4s
with the cover still 900 units off, gave up, settled at 10.5s, and by 11.1s was
scavenging the coin it had left behind. **The entire "runs it to cover and lies
low half-seen" behaviour the owner asked for had never happened.**

So a trunk is only cover if the straight walk to it stays clear of every hero by
the animal's own fright radius plus `THIEF_ROUTE_CLEARANCE`. *Preferred* rather
than required: if nothing is reachable the best far-from-everybody tree still
wins, because standing in the open holding the loot is worse than a risky walk.

**It was found by tracing, not by reading.** Two passes of reading the state
machine produced two wrong theories — the hide clock expiring, and the cover
being too close — and both were disproved by one log of every state transition
with the positions and the hero distance beside them. The gate said "did not run
for cover" and the truth was "ran, was scared off, and went shopping again",
which no amount of staring at the branch was going to produce.

**And the weapons that shipped in the gear batch broke a cadence invariant.**
`weapon_vfx_check` holds `reach_scale * swing_scale` within 0.01 of 1.0 — reach
is bought with cadence, never given away, which is what keeps a weapon off the
capped power scale. The Gravebell Maul and Oathkeeper Spear came out at 1.18 and
1.38 of a baseline and the Ratcatcher's Awl at 0.62. All three are 1.000 now,
shaped to their names: the maul and spear reach and are slow, the awl is short
and quick.

**The transferable half is how the gates to run were chosen.** Five were run
after adding the gear, picked by their *names* looking relevant. Sixteen gates
read `GearData`, and the one that failed is named after VFX. A gate is named
after the system it guards, not the data it reads, so the list to run comes from
a grep rather than from intuition:

    grep -ln "GearData" game/tools/*_check.gd game/tools/*_test.gd

**The juice triage was wrong twice, and measuring is what said so, 2026-09-16.**
`docs/IDEAS_REVIEW_2026-09-16.md` named loot magnetism (#32-34) as "none of it
is built" and the Guide as having seventeen pictures that were photographs of
something else. Both were checked before being built and both were overstated.

**Loot magnetism was already built** - magnet range, acceleration, a latch so a
drop at the edge does not stutter in and out of range, a Curious-spirit trait
that widens the net without changing who gets paid, burst, settle, hover,
beacon, and a distance-faded plate. The one genuine gap in that group was
**audio**: one flat sound for a copper coin and a Beastcalled sword, and six
drops hoovered in two seconds sounding like one drop six times.

**The Guide had four duplicate pictures, not seventeen.** Hashing the folder
found 67 distinct images across 73 pages; most of the list had been converted in
earlier sessions and the note in this file went stale. Of the four, exactly one
was a genuine fault - `summons`, a section about a *spell* that calls a wolf for
twenty seconds, illustrated by the permanent bond journal, with six COMPANION
spells in the game and none of them ever photographed.

**The lesson is the one this project keeps paying for in new clothes**: a list
of outstanding work is a model, and a model of a thing is not the thing. Hash
the folder, grep for what a system *reads* rather than what it is called, and
check before building something twice.

**Three small things the same pass turned up, all built.** A tower now *swells*
when it is upgraded - placement has risen out of its foundation since
2026-09-15 and upgrading, the thing a player does forty times a run, changed a
tint and threw a burst while the structure itself never moved. The swell is a
half-sine so it returns exactly to rest, and it rides inside the one expression
that already owns `sprite.scale` and `sprite.position`: a second assignment to
either is the sway-and-wobble bug that file has already shipped once.

The hero's health bar keeps the **delayed-damage trail** the enemy bars have had
since they were written, drawn as a child rect in the empty background between
the new value and the old so it needs no z-order argument with the fill. And the
**purse rolls** rather than teleporting, proportional and floored so eleven Gold
arrives quickly and nine hundred takes about the same moment, snapped inside one
so a counter never rests on 89.6 showing 89.

**`Stragglers` points at the last bodies of a wave.** A wave does not end until
its pack is down, and the last one or two are routinely behind the treeline or
in fog, which does not draw a body at all. Whatever is left when the queue is
empty wears a plume tall enough to clear the canopy.

**The fog's bound is narrowed rather than broken.** `FogOfWar` hides and never
helps, and nothing about targeting, spawning, pathing or reward reads it. This
reads nothing either - it is a drawing, it changes no number, and it appears
only once a wave is in its tail. What it gives away is "the wave is not over and
it is that way", which is what the wave clock is already charging for. Camp
bodies are excluded, because nothing is waiting on one and pointing at it would
send the player on an errand the clock never asked for.

**And turning for home is a departure rather than a cut.** #41 and #42 called
extraction the crown jewel and the objection was fair: the largest decision in a
run resolved on the frame the card closed. The view now goes to the scope that
actually carries the party home, the room drops away through the same duck an
act boss uses, and the road is held for a moment before the run settles.

**The road behind you closes when you turn for home, as of 2026-09-16.** #41
and #42 of the forwarded juice list wanted the threat rising while you leave,
and it was parked rather than built because it changes what a return *costs* -
which is the number `homecoming_marks` is balanced against and the whole reason
the pass is a decision. **Owner ruling: "Yes pressure should rise against
players who walk out of a run."**

**A return no longer settles on the frame the card closes.** For
`HOMECOMING_WITHDRAWAL_SECONDS` the road keeps sending bodies at the town,
thickening as the beast pulls away, and the fortress the party is leaving holds
the gate with exactly the board they built.

**What it takes is the condition of the front they carry home**, and nothing
else. `Expedition.compose` runs *after* the withdrawal, so the wall and every
emplacement come home in whatever state the fight left them - the attrition
ruling of 2026-09-15 pointed at the walk out. `homecoming_marks` is untouched,
the Marks are paid in full, the eggs still hatch and the front is still banked.

**Three designs were written for this and all three were refused. Each one's
fatal flaw is now a bound**, which is why they are recorded rather than the
winner alone:

- **A last stand you could fail.** `bank_the_front` is called by extraction and
  by nothing else, so extraction is the **only ratchet the expedition system
  has** - "everything before the last extraction is banked, everything since is
  at risk". Putting it behind a fight pins a player who cannot win one at their
  last successful extraction for ever, and makes stopping for the evening while
  hurt require winning, which is the opposite of what a ten-evening campaign is
  for. So `Health.floor_hp` holds the town at `HOMECOMING_WALL_FLOOR` for the
  length of a withdrawal: **a party who pressed Turn For Home always reaches
  home.**

  **The town was only one of the two doors, and the second was nearly missed.**
  A Warden on their last Wound who goes down ends the run through
  `Hero._on_died`, and a co-op pair through `CoopHeroes._on_team_wipe` - so the
  wall could be held and the party killed out of the walk anyway, losing the
  return they had already chosen *and* the front it was about to bank, since
  `bank_the_front` is reached from `return_home` and from nowhere else.
  `RunState.run_may_be_lost()` is the rule, asked at both doors and decided at
  neither. Found by asking what else ends a run, rather than by anything
  failing: the gate was green with the hole in it.
- **A toll scaled by road walked since the last bank.** That is
  `RunState.momentum` with the sign flipped and a larger coefficient, aimed at
  the board and the wall - which `MOMENTUM_PER_CROSSROAD`'s own ruling forbids
  it from touching, and which would make banking at the first fork strictly
  correct. The withdrawal's bodies are **the act's own bodies at the act's own
  scaling**, through `WaveDirector.send_closing_body`, so it is the road
  pressing rather than a tax on having pushed.
- **A hunter that chases you out.** The roster walks at 28-68 units against a
  hero at 200, so a pursuer is a mechanic that **cannot fire** - it can never
  land a blow on anybody holding a movement key, and raising its speed to match
  makes it unavoidable for everyone. Nothing chases. The bodies walk at the
  town, which cannot run.

**It borrows ROAD_BATTLE rather than inventing a phase**, and that is load
bearing rather than tidy: `Tower._process` and `Hero.set_active` both gate on
`RunState.is_command_combat()`, which names ROAD_BATTLE, BOSS and FINAL_ASCENT
and nothing else - so a withdrawal fought in a phase of its own is a fight with
the board switched off and the hero inactive. The cost of borrowing it is that
the ordinary wave clock is also happy, so `_road_waves_allowed` refuses while
`RunState.withdrawing`: one refusal, in the one function that already owns "may
a road wave start now".

**And it fixed the door nobody was walking through.** `_ride_home` was reached
from `_on_boss_defeated` and from nowhere else, so the departure beat added the
same week silently never happened at the **fork** - which is the door a player
uses far more often, since it is offered at every crossroad and the pass only at
an act's end. Both doors walk out through the same function now.

**Nothing new persists and nothing new crosses the wire.** The wall ratio and
the tower health were already in the snapshot; `RunState.withdrawing` is
run-scoped and cleared by `reset`; a guest runs no waves and settles no run, and
the bodies reach it as the same spawn facts every other body does.

**`homecoming_check` grew from 41 checks to 53, and the departure beat is gated
for the first time.** `_ride_home` returns on its first line headless, so every
line of it had been unreachable to every gate since the day it was written -
`Run.withdrawal_test_seconds` is the documented seam, the same shape
`MusicPlayer.test_slots` is. Five faults were planted and all five named: no
floor (the town falls and the run ends as a *fall*), a run that may still be
lost (the Warden is killed out of the walk), a flat ramp, a floor never
released, and the front photographed before the fight rather than after.

**A fifth plant taught something worth keeping.** Banking the front early while
leaving the correct bank in place passed cleanly - because the later, correct
call simply overwrote it. **A planted fault has to remove the correct behaviour,
not merely add the wrong one beside it**, or it proves the gate blind when the
gate was fine.

**One dead assertion went with it.** `homecoming_check` held
`_check(... or true, "held on the pass")`, which could never fail, so the gate
counted a check it was not making. What it should have held is that the road
does not advance underneath an open pass - the card's figures come from the act
the boss fell in and the payout recomputes from `RunState.act` at settle time,
and they agree only because turning for home returns before `resume_after_boss`
increments it.

**A conformance row marked `manual` because nobody thought of a probe, as of
2026-09-16.** `V4_CONFORMANCE` §6 carried *"Yuri named in the beast scope | not
'the beast'"* as a human-judgement row since it was written, and `gdd_audit.gd`
named it in as many words as an example of a question a gate cannot decide.

**Its target is not a judgement.** It is the literal words "not 'the beast'",
and the interface names that view in exactly two places: the scope button on the
HUD's nav bar and the row on the rebinding screen. Both are checkable.

**And the row was open rather than merely unjudged.** Both said "Beast", so the
only part of the game that names that view named his species. The beast scope
itself has no player-facing text at all - Yuri appears in `beast_scope.gd` only
in a code comment - which is exactly why reading the scope said the row was fine
and nothing ever caught it.

`copy_check` decides it now, and the audit is **47 of 47 automatable checks
(100%)** with four human-judgement rows left rather than five.

**And `copy_check` was on the guard bar only**, which is worse than it sounds:
GDD §57 makes *"no unreviewed enslavement language ships"* a **release**
requirement, and the gate enforcing it could not fail a tag. It is on both bars
now. That is the third time this project has found a gate in one workflow and
not the other, after `layout_check` and the phone shapes.

**The lesson is about the word `manual`.** It is supposed to mean "a person has
to read this", and it had come to mean "nobody thought of a probe" - which is a
row that is never checked by anybody, wearing a label that says checking it is
somebody else's job.

**Every loot sound in the game had never played, found 2026-09-16.**
`Sfx.play_group(group)` does `GROUPS.get(group, [])` and returns when the array
is empty - no error, no warning, not even the `_blocked_missing` tally `play`
keeps, because nothing was *missing*: a key simply was not there. The keys carry
an `sfx_` prefix and four call sites did not.

**So a drop landing on the road, a drop being picked up and a raid key being
taken were all silent**, along with the story intro's page turn. The
loot-streak pitch and the rarity grading built earlier the same day were feeding
a function that plays nothing.

**`audio_verify` was thorough and could not see it.** It checks every sound
resolves to a real stream, every group member is a sound or another group, every
chain reaches a recording, every file on disk is registered and every
placeholder has a mix row - and it checks the *tables against each other*. A
table can be impeccable while nobody addresses it correctly. That is the
`DisciplineEffects` lie in the audio system, and the answer is the same one this
project has now reached four times: **walk the callers against the table**. The
gate greps every `play_group("x")` in the project and refuses an `x` that is not
a key; it skips comment lines, because its own docstring names one on purpose.

**And `audio_verify` was on the release bar only**, the mirror image of
`copy_check` being on the guard bar only - both found in the same hour. Both are
on both bars now. **That is three guard/release splits in one session**, after
`layout_check`, and the lesson has been recorded before: the two lists are
hand-written and neither is a superset. Diff them before a tag.

**Found by reading the function while adding a fifth bad call to it**, not by
anything failing - the Smithy's new strike sound would have been the fifth. The
Smithy now says what came off the anvil: the hammer, then the piece on the same
rarity ladder a drop off the road uses (`Sfx.gear_arrived`, one function so the
forge and the road cannot disagree about what a Beastcalled sounds like). That
is #160 of the forwarded juice list - "players recognise what happened from
audio alone" - and it is deliberately not a new sound, because a player has
heard that ladder hundreds of times before they can afford a gem.

**Worth knowing before the next play session: these mix levels have never been
heard in play.** They were authored expecting to be audible and nothing has ever
verified them by ear.

**The forwarded canon story is triaged rather than built, as of 2026-09-16.**
`docs/ChatGPT_More_Ideas_6.md` had been committed and never read: a 1,001-line
proposed canon - a setting, a timeline, an origin for the Chainmaker, a ten-act
story table, an identity for the Gatekeeper, an alternate ending and a postgame.
`docs/IDEAS_REVIEW_2026-09-16b.md` is the triage. **Nothing is built and no
ruling is assumed**, because canon is an owner decision and several of these
re-cut shipped fiction rather than extending it.

**It is three turns of a transcript and they disagree.** Turn 1 proposes a
post-apocalyptic future Earth; turn 2 is shown the game's lore and *explicitly
reverses it* - "I would not make Wilderhold explicitly future Earth"; turn 3
reinstates everything turn 2 discarded without noticing. **"Adopt the document"
is therefore not an available action** - turn 2 and turn 3 are mutually
exclusive, and turn 2 is the one written with the game in front of it.

**One sentence must not ship and it is the §57 half no gate can catch.** Kharok
"compelled workers to maintain the anchors" - forced labour with every
denylisted word removed. `copy_check` passes all 1,001 lines, which is the
point: the gate catches the vocabulary and §57 exists because a human has to
catch the rest.

**The first ruling needed is that the document inverts the final act.** It has
Yuri as one of the last *unbound* Worldstriders and the plot as preventing his
binding; the game says he is already bound and cutting his chains is the
finale - in four player-facing strings and in v4 §201, which makes the chains a
thing the hero *attacks*. Everything else in the document rests on it.

**Refused outright**: the acts 6-10 rename and reorder (it breaks every banked
expedition, the same hazard that stopped acts 1-3 being renumbered), the 2377 CE
reinstatement, the Earthwitness layer (it needs a dialogue system and a set
piece against a surface that is 27 lore entries and a four-panel intro), and
"The Beast Beneath" as a name, since the beast is Yuri in fifteen strings.

**What is worth having is words in existing fields**: Kharok was a Warden and
one of the greatest, the Gatekeeper was his closest companion kept waiting by an
order he chained into him, and "Roadsong" names the elemental system the game
already runs. The game ships three sentences about Kharok and **no origin at
all**, so that is the largest gap in the canon closed at the cost of prose.

**And a large part of turn 2 is already true** - the Host's compulsion, the
Warden explicitly not being a prophesied savior, the lantern's reason, and Acts
1-5 down to the verbatim act titles. That is the fifth forwarded document in a
row to be roughly half a description of what already ships.

**Twenty-three gates ran in guard and never at release, found 2026-09-16 by
diffing the two lists instead of tripping over them.** Three had been found one
at a time that day - `layout_check`, `copy_check`, `audio_verify` - each after
something it guarded had already gone wrong. Diffing properly found twenty more,
in about a minute:

    grep -oE 'res://tools/[a-z_0-9]+\.tscn' .github/workflows/guard.yml | sort -u > /tmp/g
    grep -oE 'res://tools/[a-z_0-9]+\.tscn' .github/workflows/release.yml | sort -u > /tmp/r
    comm -23 /tmp/g /tmp/r      # in guard only: cannot fail a tag
    comm -13 /tmp/g /tmp/r      # in release only: cannot fail a push

Among the twenty-three: **the whole co-op layer** (`coop_check`,
`coop_heroes_check`, `coop_world_check`, `webrtc_check`), **`save_round_trip_check`**
- the save being the one thing git cannot restore - and **`exchange_check`**,
which holds the Ledger's buy-versus-vendor bound against printing Marks forever.

**The rule this settles: the release bar is a superset of guard's.** Release is
the last thing that runs before something reaches a player. Guard is also not a
guarantee that any given commit was checked - `cancel-in-progress` drops an
in-flight run when a newer commit lands, which happened twice on 2026-09-16 - so
a tag cut close behind a push can outrun the only run that would have covered
it.

**The five that stay release-only are deliberate and guard.yml's own header says
why**: `balance_test`, `curve_report`, `soak` and `perf_check` are the
judgement-heavy ones that are "legitimately red in the middle of a migration",
and a check that is red for a week is one people stop reading. That asymmetry is
the right direction; the other one was not.

**Measured before it was argued**: the twenty-three cost about three minutes, off
the sweep's own per-gate logs, against a release job with no `timeout-minutes`
set at all.

**And the Resume card shows the wall**, which it never did - `fortifications`
counts towers and the wall is the thing a run is actually lost through. It
matters from today because a withdrawal can wear it on the way out.
`Expedition.wall_share` is the reader and `expedition_check` holds that a worn
gate comes home worn. **This paragraph went on to say nothing between runs
mended it, and named that a decision waiting to be taken.** It has been taken -
see below - and the sentence is corrected here rather than left standing,
because this file is the first thing every session reads. Inside a run the wall
is still mended with Wood or through the Quartermaster.

**The Hold sells the gate repair, as of 2026-09-22.** The owner: *"The Hold
should sell wall repairs if a successful extract is available to continue its
run and it requires mending."* Both halves of that were nearly true and the
second was wrong. `repair_bill` had priced the gate since 2026-09-20 - but both
screens offered the Mend button on `fortifications().y`, which counts **towers**
- so a front that came home behind a battered gate with every emplacement whole
was offered no repair anywhere, while the purchase that would have mended it
worked perfectly if it were ever reached. `Expedition.needs_mending` is the one
question now, and it asks the bill.

**In Marks, and that is what "sell" means here.** The emplacements stay on
timber and ore - the mines are the between-runs economy and a tower has a Gold
price to take a share of. The wall has neither, and the Hold *sells*: the Hold
sells for Marks, which is the stable's rule and is itself working rule 7's bound
that a material is an input to the Smithy and nothing else. A run currency was
never available, because it resets - the repair would be free on the first frame
of the next road.

**The bound is that it must be dearer than letting the run go, and the
interesting half is which direction is dangerous.** There is no Marks printer
here and there could not be: the transaction consumes Marks and produces a
mended wall, paying out no currency, no gear and no level - `expedition_check`
serializes the whole save either side and holds it byte-identical but for the
Marks. What *is* available is the opposite. `return_home` banks the front **and**
pays `homecoming_marks` in full, and the withdrawal of 2026-09-16 is what wears
the gate on the way out - so a whole gate priced under one return would be
attrition refunded out of the payout the withdrawal itself earned, and the
2026-09-15 ruling that a damaged fortification comes back damaged would survive
only as a figure on the Resume card.

So `FORTIFY_GATE_MARKS_SHARE` is **above one**, and the price is a share of what
a return from that front pays, per point of wall missing. A gate that fell to
the withdrawal's floor costs more than the road that broke it earned; a lightly
worn one costs a little, so nobody is ever choosing between an unaffordable bill
and abandoning a campaign.

**The snapshot's own act and tier, never the ambient ones.** `loot_scale` runs
1.0 to 3.6, so a price that read `RunState.tier()` - whatever was last played -
would quote a Hell front at Normal rates the moment a Warden opened the menu
after a Normal run, and *low* is the failure direction this bound exists to
close. `Expedition.homecoming_worth` writes that arithmetic out a second time
rather than calling `Run.homecoming_marks`, because `Expedition` is reached from
`MetaState` and `Run` reaches back into it - one shared function across that
edge is a cyclic reference bought for a line. The two are held against each
other instead, over every act and every tier, which is what sharing a function
was ever for. Planted with the tier dropped, the gate named it on Nightmare act
1: 57 Marks against a 180 payout.

**And the price is on the screen before anything is spent.** `Expedition.bill_text`
is the one place it is written - both halves and what the Warden is holding
against each - because there are two doors onto this purchase and they had
already drifted: the front door carried the bill in a tooltip and the Hold's
button carried no price at all. A sale with no price on it is the Forge's own
rule broken.

**A glacier was playing the desert battle track, found 2026-09-16.** Counted
rather than assumed: the act playlists hold **11, 24, 24, 13 and 4** songs for
acts I to V and **nothing at all** for acts VI to X. Seven of the ten regions
also have no `music_battle_<id>.ogg`. So five of the ten acts reach
`MusicPlayer._battle_track`'s fallback - and the fallback was
`posmod(act - 1, 3)`, the region's *position on the road* rather than anything
about the region.

**Four of those five were wrong**, and reading each region's own cinematic says
why: the Glass Fields is *"a glacier ground over a city"* and played **desert**;
the Ashen Reach is *"stumps, ash drifts and a glow under all of it"* and played
**snow**; the Iron Steppe is *"grass to the horizon and no cover"* and the Last
Terrace is *"cut stone steps climbing into cloud"*, and both played **jungle**.

`TerrainData.battle_music` is authored per region now, from that description
rather than from an index - on the resource rather than in a table inside
`MusicPlayer`, so adding a region means adding a file (working rule 3), and an
empty value still falls to the old rotation so an unjudged region is no worse off.

**The gate held the bug, and amending it is recorded rather than quiet.**
`music_check` asserted *"act 5 with no songs rotates to the desert track"* - true
of the rotation, and the rotation was the fault. The replacement holds the
invariant instead of the table: **where a region sits on the road may not decide
what it sounds like**, so every terrain must resolve to a real track and to the
*same* track in every act. Checked by putting the fault back, which it named as
"glass_fields plays 3 different tracks depending on which act it lands in".

**Two faults in that work were mine and both are ones this project has already
written down.** The `.tres` edit put `battle_music` **before** the
`script = ExtResource(...)` line, where Godot applies it to a Resource that does
not yet have the script and **drops it in silence** - the anchor-on-the-script-line
rule, paid for again. And the first cut of the new check sampled acts
**[1, 4, 7, 10]**, which are all the same slot of a three-track rotation, so it
read one answer four times and passed while the property was being dropped. It
walks every act now: a guarantee is a property of every act or it is not a
guarantee.

**The honest remaining gap is content, not code**, and `music_check` prints it
every run rather than leaving it to somebody's memory:

    [music] soundtrack: 76 songs over 5 of 10 acts (11, 24, 24, 13, 4, 0, 0, 0,
    0, 0); 0 of 10 acts have a boss theme

So acts VI to X have no music of their own and **no act has a boss theme at
all** - eleven bosses sharing one generic track. Neither is a fault: the
machinery is built and both fallbacks are deliberate, which is exactly why they
are invisible. Nothing ever fails when a file is absent, so the only way either
is ever noticed is by somebody counting - and a count off the disk cannot go
stale the way a note in this file can. The soundtrack grows by dropping a file
in at `music_act%02d_%02d.ogg` and `music_boss_act%02d.ogg`.

**Acts IV to X were played in silence, found 2026-09-16.** Not a wrong sound - no
sound. `Ambience.BEDS` declares a bed for all ten regions and **seven of those
files do not exist**, and `Ambience.play` turns a missing file into `stop()`. So
seven of the ten regions had no ambience at all, and **no gate had ever read the
ambience table**.

That is worse than the battle track's version of the same gap, which at least had
a wrong answer rather than no answer - and it is the kind of absence nothing can
notice, because quiet is what ambience sounds like when it is working.
`TerrainData.ambience_bed` names the nearest bed a region should lie under,
judged from the same character that chose its battle track and **deliberately
agreeing with it**: whatever decides a place sounds cold decides it sounds cold.
`audio_verify` now walks every terrain and every weather bed and fails on a file
that is not on disk.

**And one recording in this project had been made, registered, mixed and played
by nothing.** `sfx_wildfire` sat in `SOUNDS`, in `MIX` - with a `limit: 2,
gap: 0.08` throttle *written for a call site that did not exist*, which is what
stops a blaze lighting `WILDFIRE_MAX_LIT` plants from machine-gunning - while
`wildfire.gd` held no audio at all.

**It was already written down and acted on by nothing.** `docs/SFX_PROMPTS.md`
has a "prompted but never played" section whose prose says *"Not a fault - a few
are chosen from data rather than written into code"*. That is true of the other
155 entries, which are music and ambience resolved by format string, and false of
the one `sfx_` entry in the list. A note that explains away a list stops anybody
reading the list.

So `audio_verify` walks the **mirror** direction now: a caller naming a sound
that does not exist was closed this morning, and a sound existing that no caller
names is closed this afternoon. "Names" is deliberately generous - any literal in
any `.gd` or `.tres`, plus membership of a group that is itself reached - because
ids picked out of a data field are legitimate. Measured: with the wildfire call
in, **zero** of 216 are unreachable; with it removed, exactly one.

**The first version of that check was vacuous and I nearly shipped it.** It
walked every `.gd` including `Sfx.gd`, so every sound was "named" by its own
`SOUNDS` row and the answer was always zero. It reads clean and it proves
nothing - the same shape as a comparison of two nothings. The declaration rows
are skipped now, and the check was validated by removing the call rather than by
reading its output.

**Losing a tower sounded like selling one, found 2026-09-16.**
`Sfx._on_tower_changed` told "built or upgraded" from "sold" by asking whether
the tile was empty afterwards - and a tower smashed by a siege breed empties its
tile exactly as a sale does. So the moment a player's defence came apart played
a dismantle-and-refund noise. `EventBus.tower_changed`'s own docstring says
"built, upgraded, sold **or destroyed**", so the ambiguity was known and the
sound layer was guessing.

`clear_tower` says why now - a non-zero `broken_at` means broken - and
`tower_destroyed` is emitted immediately before `tower_changed`, synchronously,
so a listener reading the pair sees the reason before the consequence. That
ordering is the whole mechanism and it is what the gate holds.

**And the same line shook the screen on the flat channel.** A tower breaking
emitted `camera_shake_requested(9.0, 0.4)` wherever it stood, so one lost on the
far road rattled as hard as one at the player's feet - exactly what
`camera_impact` was built to stop on 2026-09-13, in a place that never learned
about it.

**Three ways to die did not name what did it, found the same day.** `note_blow`
is called by everything that swings - bodies, ground strikes, the earth's events
through `strike_the_players`, a bubble in a pond - and by **none of the three
deaths a player is least able to explain**: drowning, the Wildblight's venom, and
a dungeon collapsing. So the debrief confidently named whatever had last touched
them, which on a collapse is the body they fought on the way in and on a drowning
can be a region ago. The bite that *delivers* the venom named itself; the venom
that finished the job did not.

`debrief_check` walks the source for those three rather than driving them,
deliberately: a real drowning needs water, a real collapse needs a dungeon and a
real blight needs a rabid animal, which is three harnesses for a check whose
whole content is "this call exists". **The fault was an omission, and an omission
is what a source walk sees.**

**Two thirds of the ecology was mute, and a set never said it was a set, found
2026-09-16.**

**Thirty-three of fifty-one species carried no `vocal_sfx`** - including every
animal added for acts IV to X. Voices are *shared* here and always have been (the
griffon takes the hawk's, the moonstag the deer's), so most of that was a
judgement rather than a recording: twenty-three species are voiced now, each
mapped to the nearest of the twelve on disk by what the animal actually is.

**The ledger matters more than the mapping.** A blank `vocal_sfx` could not tell
*"nobody has got to this one"* apart from *"a scorpion does not make a noise"*,
and nine of the ten still-silent species are the second kind. They are declared
in `wildlife_spawn_check.SILENT` with a reason each, which is
`DisciplineEffects.DECLARED_ONLY`'s pattern: a thing that cannot be wired yet
belongs on a list, visibly, rather than missing from both. The tenth is the
**reed frog**, which is loud and has nothing on disk it could honestly borrow -
listed as owed a recording rather than declared silent, because a frog given a
hiss is worse than a frog given nothing.

**And `Modifiers.set_pieces_worn` documented itself "for the screens and the
gate" while being called by the gate and by nothing else.** So the only thing
that ever told a player a matched set existed was the ring of motes at their feet
*once it was already finished*, and the only way to find the fourth Emberwind
piece was to have noticed the first three. That is the argument the discipline
synergies were built under, word for word - *"a synergy discovered by accident is
a coincidence rather than a build"* - and it is truer of a set, which asks the
player to pass over better gear in five slots to reach it. The stash row says
`Emberwind 3/5` now, on the line read while deciding what to wear.

**The gate for it was wrong first, in the way I had already been caught once
today.** It called `GearRow.set_text` directly, so removing the *call site* in
the row builder left it passing - it tested the function and not the wiring.
It builds the row the stash builds and reads the label back now, and with the
call site removed it quotes the line the player would actually have seen.

**A voice comes from the animal now, as of 2026-09-16.** `Sfx.play_at` has
quietened by distance since 2026-09-15, and **every wildlife vocalisation and
almost every companion sound was played flat** - so a wolf across the outskirts
was exactly as loud as one at the Warden's feet. `sfx_companion_down` in that
same file had used `play_at` since it was written and nothing else in it did.

**It had to come with the voices.** Giving twenty-three mute species a voice an
hour earlier made the road far noisier with sounds that did not attenuate, so the
fix would have made the game worse without this.

**And the count in the survey was 121, and 121 is not the number that should
change.** A menu click, a purse, the Warden's own breath and a hero standing at
the pond they are fishing are all correctly flat. Only the two files that make
world sounds *away from the camera* were converted, and `feel_check` holds only
those - a rule that every `Sfx.play` must carry a position would be the same
mistake as reading a count as a fault list.

**The gate found two sites I had missed**, including a second
`sfx_companion_down` sitting next to the one that was already positional - which
is the gate doing its job before the commit rather than after it. And
`Wildlife._strike` was shaking the screen on the flat channel too, so an animal
biting someone across the map rattled as hard as one underfoot: the same fault as
the tower, in a third place that never learned about `camera_impact`.

**Which sounds are positional, and which are deliberately not, as of
2026-09-16.** The owner asked that everything needing direction play
directionally per player, with the networking right. Both halves are recorded on
`Sfx.play_group_at` so the policy sits beside the function rather than only here.

**The rule is one question: can this happen somewhere the player is not?**
Positional: a body, an animal, a companion, a tower, a torch, a camp razed, a
rock landing, a death stone, a vault chest. Deliberately flat, each for a reason:
the interface; anything the player is standing in (fishing is the clearest - the
hero is *at* the pond); **a telegraph**, because
`JuiceDirector.Priority.TELEGRAPH` exists to say a warning is never turned down
and quietening one by distance contradicts that where it matters most; **the wall
being hit** at +4 dB, because it is the loss condition and a player out at a far
camp is exactly who needs to hear it; and announcements - a boss arriving, a fork
opening, distant thunder - which come with a banner and are about the road rather
than a place on it.

**The networking was already right and is now written down.** Each machine calls
`Sfx.listen_from` with **its own camera** every frame, so two players hear one
event at the distance each is standing from it, and **nothing about sound crosses
the wire**: `CoopRelay` and `CoopWorld` contain no `Sfx` call at all. A sound is
the local consequence of a relayed *fact*. Sending the sound itself would double
it on the host and desynchronise it everywhere else.

**Three flat `camera_shake_requested` calls went with it** - the camp razing, the
wildlife bite and the tower's destruction - all predating `camera_impact` and all
shaking as hard from across the map as from underfoot.

**And a companion freed mid-run printed an error every frame.**
`Battlefield._process` did `hero.get("spirit") as Companion` and *then* checked
`is_instance_valid` - but casting a freed object throws, so the guard never ran.
Ninety-five errors in a short gate run, and a silent flood in play.

**It is invisible to CI, which is the half worth keeping.** A clean profile has
no bonded spirit, so nothing ever reaches that branch there: the sweep's log for
`companion_check` has zero error lines and the same gate on the owner's account
has ninety-five. That is `ci-profile-hides-state-dependent-ui` inverted - an
empty account hides a panel's overlaps, and a *played* one reveals a crash path
no gate will ever walk. **When a gate passes in CI, it has only been asked about
the state CI has.**

**The sound effects are real recordings, as of 2026-09-16.** The owner generated
347 takes and 41 synthesised placeholders became recorded ones, in three takes
each; the reed frog got the croak nothing on disk could stand in for.

**One-shots are mono, and that is correctness before it is size.** `Sfx` plays
every effect through a plain `AudioStreamPlayer` and attenuates by distance in
`play_at`; nothing ever pans a stream, so a stereo one-shot stored a channel the
game could not use. Re-encoding the eighty shipped files that sat above the
project's own settings gave **2.54 MB** back.

**Music is left at q1 and the number is recorded rather than acted on.**
Measured on a shipped track: q0 is 82% of q1, q2 is 105%. So dropping to q0 takes
about 18% off - 25 MB of today's 139 MB, nearer 45 MB once the sixty-one act
songs and ten boss themes still owed have landed. That is a *quality* decision on
a commissioned soundtrack and re-encoding lossy adds generation loss, so it
belongs in `import_audio.py`'s comment next to the constant, to be changed before
a batch rather than after one.

**A voice is pitched by the body that makes it.** Twenty-three species share one
of twelve recordings, so without this a fennec is a fox and a jackal is a wolf.
`WildlifeData.scale` sets the throat and the growth stage makes a cub reedier;
the shift multiplies with the per-play drift the MIX row already carries, so the
scale says what kind of animal and the drift says which time it called.
`EnemyData.voice_sfx` is the same rule for a roster of **sixty-seven breeds that
ship with no voice at all** - empty and silent until a file is named, with six
archetype prompts in the doc rather than sixty-seven recordings.

**I deleted the owner's source takes, and that is why the batch is three deep
instead of eight.** After importing I ran `rm -rf audio_inbox/NewSFX`;
`audio_inbox/` is gitignored, so there was no copy in the repo, and `rm` does not
use the recycle bin. No shadow copy or restore point existed. The owner could not
re-download them. **Never delete an inbox after importing it** - the import is
lossy by design (it keeps a subset, converts, trims and normalises), so the inbox
is the only master.

**And the cap that made it three was the wrong trade on its own terms.** It was
set to protect download size; every take of the whole batch was about **8 MB
against a 139 MB soundtrack**, so it was shaving six percent of the audio while
the other ninety-four sat untouched, and discarding variety already paid for. A
fishing reel, a swim stroke and a dying body are heard hundreds of times a run,
which is exactly where a fifth take stops being redundant.
`VARIATIONS_PER_SOUND` is 0 - all of them - and duplicates are dropped by content
hash after conversion, with numbering assigned after that drop so a removed
duplicate cannot leave a group naming a member with no file.

**`tools/register_sfx.py` makes `Sfx.gd` agree with the folder** rather than
applying a diff, so it is idempotent: more takes grow the groups, fewer shrink
them, a second run changes nothing, and it refuses to invent a group for takes
another group already claims. The flow is `import_audio.py <folder>`,
`register_sfx.py`, `--import`.

**`music_check` held that the boss cues were single `SOUNDS` rows**, which was
true while they were synthesised and stopped being true when they became groups.
Amended deliberately, as the ambience and battle-track invariants were: what it
holds is that a cue *resolves to a real recording*, following the group to its
takes.

**Three owner rulings of 2026-09-17, recorded before anything is built on
them.** Two of them re-cut bounds this file states outright, which is exactly
what the table at the top of §1 exists to make visible the second time.

**1. The Hold becomes a place, and it is populated by simulation with real
players taking those places.** This file has said three times that there is
nothing more a hub could honestly do without accounts - and that objection is
about *authority*, not about presence, which is what the ruling exploits.

The Hold stands up with simulated Wardens in it: pens filled, figures about
the square. A player who arrives - invited, or matched the way the co-op
lobby search already matches - **takes the place of one of them**, and that
seat's pen, companions and everything else become genuinely theirs. Four
seats, so three guests.

- **Private by default for every new account**, toggled from inside the Hold
  by its own interactable. Only a private hold's host may invite.
- **A public hold is matchable**: a player searching joins any hold that is
  not full, through the same path the co-op search uses.
- **A seat freed by somebody leaving makes the hold matchable again.**
- **Being in one hold is not being in a party.** A run still needs a party,
  which is what stops somebody being dragged onto a road they did not choose.
- **The host may hand the hold to another player**, and when a host leaves
  with some of the party the hold migrates to somebody staying - preferring a
  player whose own hold was public, because they have already said they do not
  mind strangers.

**The bound is the one co-op already lives under: the host is the authority
and nothing a guest says is trusted.** A seat is presence, not an account. No
stranger's save, stash, pen contents or gear may ever be written by anybody
but its owner, and a simulated Warden holds no state worth forging. The
existing rule stands unchanged - **the Ledger still publishes prices and never
pieces**, because that one *is* about authority.

**2. Ascension is a third capped power scale, tuned against Nightmare.** This
file records ascension as "prestige and nothing else ... no level, no
attribute, no card and no relic - levelling and gear stay the only two
scales". The owner has re-cut that: ascension must "empower significantly" so
that Nightmare is survivable after grinding its gear.

**What does not change is the word *capped*.** This project has refused a
third scale perhaps a dozen times - spirit traits, discipline depth,
synergies, omens, fish, professions, materials, set bonuses - and every one of
those refusals was about a scale *nobody was tuning*. The objection was never
"three is too many"; it was "an untuned one is unmeasurable". So ascension
gets its own ladder with its own ceiling, and **`curve_report` models three
scales instead of two**, with Nightmare and Hell re-measured assuming the
player holds the ascension a tier expects. An ascension rank that is not in
that model is the thing that stays forbidden.

**3. The Gatekeeper is an opt-in ladder, and skipping it costs you at the
summit.** Trials open on Acts 3, 5 and 7, each unlocked by clearing the one
before, and the Gatekeeper himself is fought on Act 9. All four are optional
and no act requires them.

**What makes them worth taking is the owner's own addition: a difficulty whose
Gatekeeper has not been beaten fights him *alongside* the Act 10 boss.** So
the ladder is not a side quest with a reward bolted on - it is the choice
between paying four times on the way up or once, at the worst possible moment,
next to Kharok. Beating the Gatekeeper on a difficulty removes him from that
difficulty's summit. Nightmare and Hell each run their own ladder and each
extend the ascension tree.

**And the summit does not move. Owner ruling, 2026-09-17 (a).** "The Act 10
boss should be Kharok" was ambiguous against what ships, and the reading
taken is the one that falsifies nothing.

The campaign already has an eleventh act: `FINAL_ASCENT_ACT = ACT_COUNT + 1`,
`cinematics/gatekeeper.tres` is act 10, and `cinematics/chainmaker.tres` and
`summit.tres` are act 11 - so **Kharok is already the final boss** and the
Gatekeeper is already the thing before him. What the owner wanted is the
Gatekeeper *off the top of the road*, not Kharok moved down it.

So: **Kharok stays at the Final Ascent. The Gatekeeper leaves Act 10 for the
optional ladder** at Acts 3, 5, 7 and 9. Nothing is renumbered, no banked
expedition breaks, and the two shipped cinematics that say the beacon and the
Chainmaker wait above stay true.

The literal reading was costed and refused: moving Kharok to Act 10 falsifies
`summit.tres` ("Above waits the beacon, the Chainmaker, and the last chain")
and `chainmaker.tres` ("Break him, and Yuri walks free"), and leaves
`_summit_cleared()` with nothing to call it - a Final Ascent with no body in
it. That is new art and a new boss to buy a renumbering nobody asked for.

**And there are two things called ascension, which is why the new scale is not
called that.** `RunState.hero_ascension` is run-scoped and *already grants
power* - `+ASCENSION_STAT_BONUS` max HP a rank, incremented per boss by
`boss_director.gd` - while `MetaState.ascension` is the persistent prestige
rank capped at 2. The owner's third capped scale extends the *persistent* one;
the run-scoped one is renamed rather than left to be confused with it, which
is safe because it is reset by `RunState.reset` and never saved.
**Act X gets a boss of its own, and the Final Ascent opener moved with him,
as of 2026-09-17.** Freeing the Gatekeeper for the ladder left the Last Terrace
without an act boss, so **the Last Anchor** stands on it: one of the spikes
Kharok drove into the earth to hold the roads still, and the last one between
the road and the Crown. Enemy, cinematic, boss core and relic, with a
placeholder sprite until real art is drawn.

**And `summit.tres` was waiting on the wrong body falling.** The Final Ascent
opener triggers on the *last act's boss* being defeated, and that was authored
as `gatekeeper` - which after the ruling is an optional fight on Act 9 rather
than the last act's boss. `milestone_cinematic_check` derives the last boss from
the terrain data rather than naming it, so it caught this the moment the terrain
changed, which is the whole reason that check is derived.

**The canon is in the Guide.** Roadsong, the Chain, Kharok, the Gatekeeper,
Ascension, the first cut, and the Final Ascent as the story's last chapter - the
entries the triage of `ChatGPT_More_Ideas_6.md` found were worth having as words
in existing fields. The game shipped three sentences about Kharok and no origin
at all; that was the largest gap in the canon and it is closed at the cost of
prose.

**The Hold is a place you walk in, as of 2026-09-17.** The owner's ruling, in
their own words: *"an actual map that players can jump into"* with a central
square, a forge a blacksmith works, a vendor's shop with the Long Ledger inside
it, pens down a path, and every other door as something you walk up to.

**Every station is a button that already worked.** `HubScreen.adopt` has kept
each door's own handler since the room was built; `HoldYard` stands a building
where that door is and presses the same button when the Warden walks up to it.
So the place and the list cannot disagree about what is in the Hold - they are
the same buttons, read twice - and a door added to the menu tomorrow gets a
building tomorrow without a second list to edit. **The list did not go away**:
walking is the Hold, not a toll, and the Warden's stone opens a card carrying
every door as a row along with the rename and the professions.

**Presence is relayed and nothing else is.** `HoldSession` seats four through
the co-op session the lobby already hosts and finds with; a seat is a name, a
title, a place to stand and - so a Warden can see other people's companions over
a fence - a list of species. No save, stash, pen or piece of gear travels, a
guest *asks* to move rather than saying it has, and each player's Market is
their own and never crosses the wire.

**Migration is a re-gather rather than a seamless transfer, and that is a
transport fact rather than a preference.** `Coop.host_room()` must `leave()`
before it can ask for a code, so a successor cannot hand its code back down a
wire it has already dropped. The host names one before it goes - preferring a
player whose own Hold was public, which is the owner's own clause - and
everybody else is told who took it.

**The Market keeps its own shelf, and it is written to the save.** That is the
owner's anti-abuse rule rather than a convenience - *"so that players do not
just keep closing their game and reopening it to keep spam refreshing the
vendor"* - and a stock held only in memory is re-rolled by restarting. Ten
minutes on the **wall** clock or a road of at least two minutes, whichever comes
first; the same eight things are on the shelf after a relaunch with the same
time left on them. Rarity trails what the Warden has actually held and only
rarely steps a rung ahead of it, and `VENDOR_MARKUP` is over one so buy-and-sell
can never print Marks - the bound `exchange_check` already holds over the
Ledger, in a second place.

**It amends working rule 7 and it is the mildest amendment in this file.**
`MetaState.vendor` holds gear that is **not the player's**: unowned pieces on a
shelf and the moment they were laid there. Nothing in it grants an attribute, a
level, a currency or an unlock, and buying one spends Marks and puts a piece in
the stash through the door gear has always arrived by. Additive; absent reads as
a shelf that has never been stocked, which is a new account.

**And the blacksmith supplies the stock while the Warden supplies the gem.** The
owner asked for a commission that costs *more* than smithing it yourself and is
*more demanding than having enough gold*. Both halves: the fee is Marks scaled
by what he is being asked to make, and the demanding half is that a commission
**teaches nothing** - no Smith experience is paid - and comes off his ordinary
stock, so the piece is the level ordinary timber makes. Marks cannot buy
practice and cannot buy good stock. A gem bought with Marks would have been the
failure `exchange_check` exists to prevent, so he never sells one.

**The Walk, as of 2026-09-17.** The tutorial the owner asked for: a guided
valley, RuneScape's tutorial island by way of the last human hold, eighteen
stops, and an ending where the Warden cuts the chain off Yuri.

**It is the battlefield with a scripted director, not a second game.** Every
system it teaches is the shipped one - the ponds are `Fishing`, the trunks are
`Gathering`, the swing is `HeroAttack`, the build panel is the build panel. A
bespoke tutorial scene is a second copy of each to keep in step, and this
project has paid for that four times over.

**Its own door, and that is load-bearing.** `start_run` clears a banked
expedition, consumes the Treasury cache and the Sigil bundle, withdraws the
party from the lobby and stamps the road's clock; a veteran replaying the
tutorial from the Hold would lose five hours of road to it, silently. So
`GameDirector.start_walk` resets the run state and takes none of those steps,
`RunState.walking` is set for its duration, and **`_settle_run` returns on its
first line while it is true** - which is also what keeps the Walk from writing a
statistic, paying a Tool, publishing a score or opening co-op at its own ending.
A first walk runs straight onto the road; a replay returns to the menu, for the
expedition reason above.

**Stops are placed against the field's own landmarks rather than at authored
cells.** A hand-typed grid coordinate is a number nobody can check without
looking at the screen, and this project's record is full of placement faults
that every number agreed about and a photograph refused - a pond dug where
nobody could reach it, a newborn fifteen hundred units off the edge. So a stop
names a *kind of place* - the road at a share of its length, a pond, a trunk, a
seam, a build anchor, the town - and the Walk asks the live field where that is.
It cannot resolve to unreachable ground, because the ground it resolves to is
ground the field already built. **A bespoke valley blueprint is still worth
having**; when one is drawn, the stops need no edit.

**One ledger, paid once, at the chain or at the skip.** A blueprint that is
first in the Tools ladder's own sort order, one Common bond, one fish, a little
timber and ore, a little craft practice. No Gold, no level, no spell, no gear,
no statistic and no tower unlock - each refused for a reason written beside it
on `TutorialGrants`, and the sharpest is that granting one spell would *narrow*
the starting pair to one and make the gift a cut. **A skipper is paid exactly
what a walker earns**: opting out of an optional system must not cost power,
which is the bound every optional system here is held to.

**It amends working rule 7 by one boolean.** `stats.tutorial_walk_done` sits
beside `tutorial_done`, so no top-level save key is added and `balance_test`'s
allowlist is untouched. It is written **and parsed**, because a once-only flag
that is serialized and never read back fires every launch - this project has
shipped that fault and it handed out a free sword each time. Whether the Walk is
*offered* is derived from `runs_started` rather than stored, because a flag
defaulting false would send every existing account to the tutorial on its next
launch.

**And the valley is quiet.** Nothing in the earth's events was ever phase-gated,
so the quake, the funnel, the meteor and the blaze each get their own line;
nothing hunts the Warden; and the beast does not walk, because he is chained to
the ground and a road advancing underneath the tutorial would call a boss and
finish it for the player. "Unlikely because wrath opens at its floor" is a coin
toss wearing a gate's clothes, and this project has shipped four of those.

**A party takes the road from the Hold, and is asked first.** The host owns the
run - that has not changed - but a road is the one decision in this game that
costs everybody the next hour, and a *continued* run is somebody else's banked
front. So `HoldSession.offer_run` puts the kind of road and its details to the
party with a clock, exactly as `PartyEvents` puts a raid or a rift to them, and
the host may go before it runs out. Alone, it simply goes.

**There are mounts, and a mount is movement and nothing else, as of
2026-09-17.** The owner asked for *"mounts that players can ride and the
ability to get mounts from a vendor at the Hold with the right resources ...
the most aesthetic solution in The Hold for it like a stable or something and
animated horses with AI and a vendor at it. And mounts should also have sprint
ability. But players need to dismount to fight and they dismount when they
attack and start fighting where they dismounted."*

**The owner's own dismount rule is what makes a mount safe**, and it is worth
stating plainly because this project has refused a third power scale about a
dozen times - spirit traits, discipline depth, synergies, omens, fish,
professions, materials, set bonuses - and every one of those refusals was about
a scale nobody was tuning. Mounted, the Warden may not swing, cast, loose,
gather, fish, work a seam or take an egg, and **the first press of attack puts
them on their feet where they stood and lets the swing through**. So a mount
can never touch a number in a fight.

**And it is not new speed either.** `MOUNT_SPEED_CEILING` *is*
`HERO_SPRINT_SPEED` - the same constant, on purpose - so the fastest a Warden
may cross the field is exactly what it was before mounts existed. What a mount
buys is that speed **without spending SP** and without the Warden's own legs
giving out, paid for by being unable to do anything else while it lasts. The
horse carries its own wind with its own floor and its own recovery; the rider's
SP is untouched, because a mount drinking from SP would make the pool the
Warden sprints on a shared resource that nothing is tuning.

**The whole refusal is one mask, in one place, and that is the interesting
half.** The interact button alone is read at *eight* call sites - the ponds,
the seams, the nests, the rift gates, the plots, the chest, the portal and a
tower - and every one of them does `who.get("input") as HeroInput` and then
asks. Adding a mounted test to each is the failure this project has shipped
twice: an Arcane node whose reach was applied at four of five throws, and a
spell scale computed by hand at three call sites. So `HeroInput.muted` sits on
the source every one of them already holds, `pressed`/`held` filter through it,
and subclasses override `_read_press`/`_read_hold` instead.

It is also what makes co-op almost free: **a muted source packs a muted
snapshot**, so a guest riding a horse sends no swing and the host's copy of
that hero does not swing either. Getting on and off crosses as the mount button
inside `HERO_INPUT` like any other intent. The one thing that genuinely cannot
be worked out locally is *which* horse - that is the other account's saved
choice, and `MetaState.saddled_mount()` read for somebody else's Warden returns
this player's own. So the id travels (`Request.HERO_MOUNT`, and a sixth element
on the state row the applier already tolerates) and the behaviour does not.

**It amends working rule 7 by one list and one name.** `MetaState.stable` is
`{owned: [...], saddled: ""}` and nothing else: no level, no stat, no currency,
no unlock, and nothing the road can grow. Bought with **Marks and never
materials** - a material is an input to the Smithy and nothing else
(2026-09-13), and the run currencies reset, so the only honest price for a thing
you keep is the account's own. Additive, like the pantry, the spirits, the
materials and the pen before it: a save written before this has no `stable` key
and reads back as a Warden on foot, which is what a new account is.
`SAVE_VERSION` did not move.

**The stable is a place in the Hold**, which is the owner's own clause. A barn
west of the square, Halric standing at its gate, and a fenced paddock with five
horses in it - **each on its own clock**, grazing where it stands and wandering
somewhere new, so a paddock of five is never five copies of one animation. That
is the argument `PenYard` was built under and the gate drives forty seconds and
refuses a yard where every animal is doing the same thing. The saddled one
waits at the rail nearest the gate, which is the only piece of information in
the picture.

**The door is a button adopted into the Hold like every other**, so the menu
list and the walkable place cannot disagree about what is in it - they are the
same buttons, read twice.

`mount_check` (87 checks) holds the ceiling by **measuring `Hero.move_speed()`**
rather than reading `MountData.gallop` back, drives the real `_tick_mount` with
a real attack press to prove the dismount happens *and* that the press is not
swallowed, galloping for three seconds and reading the Warden's SP back
unchanged, and buys every mount in the stable to prove the purse is the only
thing that moved. Three faults were planted and all three named.

**Two things fell out of building it and both are ones this project already
knows.** `MOUNT_DOWN_SECONDS` was authored and read by nothing, and
`balance_reach_check` refused it - correctly, since getting *off* has to be
instant or the swing that asked for it does not land. And the gate first
reported a working gallop as broken twice over: once for setting `_galloping`
by hand when the tick recomputes it, and once for calling `_tick_gallop`
directly when it is the *outer* tick that counts the climb into the saddle
down. Drive the door, not the flag, and drive the outermost one.

**That paragraph was stale and is corrected here rather than overwritten, as of
2026-09-18.** All four mounts have idle, walk *and* gallop sheets on disk; they
landed after it was written and nothing updated it. **The Stable's horses are
still motionless and the reason is not the screen** - the owner reported it twice
and both times the code was doing exactly what it was told.

Measured off the files rather than reasoned about:

    mount_*_idle.png    224 x 1792    8 directions x 1 frame
    mount_*_walk.png   2016 x 1792    8 directions x 9 frames

**An idle sheet holds one frame per direction, so `play("idle")` has nothing to
play.** The rig, the south-east facing and the per-row speed scale are all
correct; the state is a still painting by construction. The fix is art and
nothing else: eight-direction *idle* animations for the four mounts, generated
with `mode: "v3"` and an `action_description` (the template animations strip the
tack - see below), cropped by the union of each facing rather than per frame.

The original note, kept because its caveat about missing sheets is what sent two
sessions looking in the wrong place:

**The art is not finished and the gap is named rather than left to be noticed.**
The steppe horse and the marsh pony have their eight-direction base sheets; the
walk and gallop sheets and the other two mounts were still generating when this
was written. `MountRig` treats every missing sheet as a stiller picture rather
than as a hole - a missing gallop falls back to the walk, a missing walk to the
base painting - which is the same rule the Warden's own sprint sheet lives
under. **And the Guide has no mount page yet**: a section needs a photograph on
disk and `guide_shots` needs a window, which was not available.

**The Ash Courser had to be drawn twice, and the reason is a knob worth
knowing.** Generated with the steppe horse as a style image, it came out as the
steppe horse: the transfer carried the *palette* along with the outline and the
shading, and "smoke grey and charcoal" was overruled by the reference. Two
mounts that look the same are one mount sold twice. `style_options` separates
them - `color_palette: false` with `outline`, `shading` and `detail` left on -
which is the right default whenever the reference and the subject are the same
*kind* of thing in different colours.


**The third capped scale is measured rather than merely capped, as of
2026-09-17.** The owner's ascension ruling earlier the same day came with a
price attached, in its own words: *"`curve_report` models three scales instead
of two, with Nightmare and Hell re-measured assuming the player holds the
ascension a tier expects. An ascension rank that is not in that model is the
thing that stays forbidden."*

**Half of it had been built.** The scale exists, is capped, and is summed
*inside* Resolve's ceiling rather than multiplied after it - which is the whole
safety of the re-cut, because an ascended Warden with maxed Resolve then stands
at one ceiling rather than at the product of two. What did not exist was the
model: `curve_report` printed *"which this model does not carry"*, which is the
forbidden half in as many words.

**It carries it now**, applied to the half of capability it actually touches.
Ascension moves what the Warden *survives*, so it scales the hero and the
spirit at their shoulder and nothing else - a tower's uptime is not improved by
the person standing near it. A hero taking `1 - m` of the damage has `1 / (1 -
m)` of the effective health, and sustained contribution scales with how long
they stand. `expected_rank_for_tier` derives what a Warden arriving at a
difficulty holds from the *ladder* rather than from a field on the tier -
Nightmare is 4, Hell is 8 - so the day a rung is added the expectation moves
with it.

**And the measurement said something worth acting on.** Carrying the rank moved
the band by **0.002**. That is true, and it is not the answer: pressure is
threat over *capability*, a model with no deaths in it, and the owner asked
whether Nightmare is **survivable**. Those are two questions and the first
cannot answer the second.

So the report prints the second as a readout beside the band: **how many blows
from the body that act sends the Warden can take**, act by act. It reads 5.7 in
Act I falling to 1.0 by Act X, and a full ladder lifts that floor by 13.6% -
which is where a rank is actually spent. Blows rather than seconds, because
seconds need an arrival rate and that is a second model of the road. It prints
and fails nothing, like the purse column, because giving it a verdict would be
that second model with an opinion.

**The line says which hero it is**, and that is not decoration. "1.0 blows"
printed bare is the misreading this file keeps recording: it is `HERO_MAX_HP` -
no levels, no Vigour, no gear - exactly as `_hero_dps` models a naked combo.
Levelling and gear are the two capped scales that carry a real Warden past Act
X; what the readout shows is the floor ascension lifts.

**Nothing gated the ladder or the scale at all**, which for a system with an
owner ruling, a new save key and a *power scale* is the gap this project gates
hardest. `ascension_check` (118 checks with the mount's) holds that rungs climb
in order and only in order - at the door that *writes* as well as the one that
offers, because a relayed or replayed message never reaches `may_enter` - that
each difficulty climbs its own, that an unbeaten Gatekeeper holds that
difficulty's summit, that the record alone pays nothing, and that a rank moves
survival and nothing else. Measured on a real hero through `Health.damage_scale`
rather than read off the constants, because reading them back would pass on a
build where the hero applied them twice.

**Its first run failed, and the reason is one this file has recorded twice.** It
read 12.8% against a 12.0% cap, because it was measuring the owner's live save:
mitigation is a *sum*, so existing Resolve points make ascension's share a
larger fraction of what is left. Resolve is zeroed for the measurement and the
*difference* is taken rather than the ratio - the quantity the cap bounds is the
mitigation added. A model that reads state measures whatever state it was
handed, and it will not tell you which unless it is made to.

Three faults were planted and all three named: one ladder shared across every
difficulty, mitigation escaping the shared ceiling to 54.4% against Resolve's
40%, and a rank granting a health pool.

**And the mount animations had to be generated twice, which is a technique
worth keeping.** PixelLab's *template* animations (`walk-8-frames`,
`running-8-frames`) re-render the whole sprite: the steppe horse came back with
its bedroll and saddlebags **gone from every frame**, the saddle changing colour
between frames, detached artefacts in the air and almost no leg motion. That is
the same failure `tools/lock_tower_frames.py` exists for, and the sheets were
*worse than the base painting* - so they were deleted rather than shipped.

**`mode: "v3"` with an `action_description` is the answer**, and one direction
was piloted before forty-eight more were bought. The v3 walk keeps the bedroll,
keeps the tack, cycles the legs properly and leaves no artefacts.

Two things about packing it. v3 pads the canvas to **252** where a rotation is
192, so frames have to be cropped - and **the crop is the union of every pose in
a facing, never each frame's own**, because cropping a pose to its own content
cancels exactly the motion the animation was generated for. That is the rule
`install_boss_frames.py` settled on, for the same reason. And the ground line
comes from the installed base painting, so every sheet agrees with every other -
**unless this run is writing that base**, which it was for the Ash Courser,
where the file on disk was still the magenta placeholder whose "ground line" is
the bottom of the canvas. The tool refused a 27px shove downward and was right
to.


**Photograph what ships, not a stand-in, as of 2026-09-17.** `mount_shot` was
written because every rule a mount has is a number and **the seat is not** -
how high the rider sits, whether the hooves are on the ground the Warden was
standing on, whether the horse turns with its rider. It built its rider out of
`hero_base.png`, an older single painting, and the owner caught it at a glance:
*"ours has the lantern"*.

**The wrong sprite was hiding a bug in the real one.** `MountRig` measures the
rider to find where their hips are, and **a region-enabled sprite's `texture`
is the whole sheet** - the Warden is eight rows of `hero_idle.png` at
1512x1280. So in play it measured the rider as about 1270 tall, put the hips
571 up, and seated them at the horse's feet. A stand-in cannot fail the way the
real thing fails.

Three things the photographs settled that no number could, in order:

- **Every mount floated.** A base painting has margin below the hooves and the
  reader placed the texture's *bottom edge* on the node. True of all four.
- **The rider was seated by their boots.** A hero sprite is drawn from the feet
  up, so lifting by the saddle's own height left the whole Warden above the
  horse with a gap under them. A rider straddles: `MOUNT_RIDER_HIP`.
- **In profile they sat on the neck.** The saddle is behind the withers from
  the side and directly under the rider head-on, so `MOUNT_SEAT_BACK` is
  applied *along the facing* - reversing with the animal and exactly zero when
  it is coming at you, which is how one number serves eight directions.

**And a shared transform is not the same as a shared ground line.** The packer
crops a whole facing through one box - right, and what preserves the motion -
and then *also* pushed every frame's own floor down to the cell edge, which is
the instruction "never leave the ground". A gallop is a bound. The terrace
stag's needed a 31px correction and the assertion refused it as "a different
pose, not a wandering foot": true, and **the pose was right and the correction
was the mistake**. Every gallop packed before that had been flattened.


**The Hold is cut into a hillside, and its people stand on the ground, as of
2026-09-17.** The owner asked for *"a tileset environment with multi-elevations
and platforms designed for each area and a thoughtful and carefully planned
outline for the Hold's layout and design"*, so that the place reads as *"a
fortified shelter camp"*, and reported that *"some of the characters are static
and have ground included in their images"*.

**Both halves of that were answered by photographing the Hold, and the second
one had already been answered wrongly from a model.** `hold_shot` did not exist
until the day before; the residents' report was first met by measuring the
*hero and enemy* sprites, finding no baked ground there, and saying so with a
figure attached. The subject was the four `art/city/merchant_*.png` paintings,
which are **dioramas on a round cobblestone plinth** - right for a travelling
stall you walk up to and look at, and wrong for somebody who walks. The Hold
was drawing four figures each standing on its own private disc of pavement and
sliding it about the yard.

So the residents have paintings of their own, with nothing under the boots, and
an idle and a walk apiece; the merchants keep their plinths for the road and
for the shop panels, where they belong. **A plinth turns out to be measurable**
and `hold_check` measures it: ground is continuous and legs are not, so what
separates them is *how many rows from the bottom are solid all the way across
the silhouette* - 39 to 43 for the dioramas, zero for a person. Counting opaque
pixels at the foot does not separate them at all and failed all eight files on
its first run, which is why the constant is derived from a measurement rather
than chosen.

**Three shelves, and the plan is the layout that was already there.** The shelf
under the unfinished wall holds the Stash, the Chronicle, the Codex and the pen
house; the square in the middle holds the forge, the market, the anvil, the
Ledger, the stable and the Warden's Stone; the lower yard is the pens and the
road out, so a Warden coming home *climbs into* the Hold. Four stairs cross the
two edges.

**Every edge runs east to west, and that is not a shortcut.** The camera looks
down and slightly along, so a south-facing bank is the only face a player can
ever see and a north one would be drawn behind the shelf that owns it. The raid
camp reached that conclusion on 2026-09-13, and this is its bank art tinted to
the Hold's own soil - one earth face authored and used twice cannot disagree
with itself.

**A rise, never a height, which is the whole implementation.** A Warden's
position stays in the flat plane: the reach, the focus ring, the pens, the dash
and the relay are all measured there and none of them learned that the Hold has
shelves. What a shelf changes is where a thing is *drawn* (`lift_at`) and
whether a step across an edge is allowed (`step_is_legal`, with `_slide` giving
ground sideways rather than sticking). The dash goes through the same function,
which is the one way a rule like this gets quietly skipped.

**The failure worth gating is a shelf you can see and never reach.** A stair
authored outside the stretch of edge people actually use strands a whole third
of the Hold, and every number in the table agrees it is fine - the same failure
as the ponds dug where nobody could fish them. So `hold_check` *walks* the yard
from the road out on a grid finer than the narrowest stair and insists every
station, every resident and every pen was reached; it also plants a foot either
side of each bank, well away from any stair, and refuses a build where the
climb is allowed - because a step rule that always says yes is a flat Hold that
passes every other check here.

**Three things in that pass were found by the photograph and by nothing else.**
The shelves were drawn lowest-first, so the top one painted over every shelf
below it and the Hold came out flat with one bank hanging in the middle of it.
The bank was drawn untinted, which laid the road's orange soil across a green
valley. And the paths, the paddock and the pens were each a flat translucent
rectangle - the largest shapes in the place, reading as panes of glass laid on
the painting. All three are the same lesson in three costumes: **a model of a
thing is not the thing.**

**Everything that moves scuffs the ground it moves over, as of 2026-09-17.**
The owner: *"Moving for all characters from players to enemies to wildlife
should also generate ground vfx with perfect game juice and it should be tuned
for each character's size and mass and speed including the dirt clouds etc which
should be tuned for the color of the ground under where it occurred."*

**One watcher, not a call site per mover, and that is the whole design.** Five
things in this game walk - a Warden, a body, an animal, a companion and a horse
- and each moves through code of its own: a state machine, a shove from the
crowd grid, a dash, knockback. Emitting a scuff at each is the failure this
project has now shipped three times, after an Arcane node applying its reach at
four of five throws, a spell scale recomputed by hand at three sites, and the
interact button read at eight. `Footfalls` measures **travel** instead, which
covers every way a body can move by construction - including the ways nobody
thought of, which is why a body knocked back throws dirt with nothing having
wired knockback to anything. `DeathMarkers` settled this shape first, watching
whether each hero is standing rather than listening for a death.

**Three numbers a body, each derived from what it already declares.** Its own
contact radius is the footprint, its hide is the weight - `FOOTFALL_MASS_BY_HIDE`
gives plate and stone more and a **spirit zero**, so a summoned companion leaves
nothing while a raised one leaves what its species weighs - and its own walking
speed is what effort is measured against. A rabbit flat out and a boss ambling
cover the same ground in a second; the rabbit is at its limit. So a breed, an
animal or a mount added tomorrow scuffs correctly with nobody editing that file.

**The colour is read, never authored.** `GroundTone` is the mean of the sheet
the floor is actually painted with, lifted because dust in the air catches light
the earth does not: the road where there is a road, the region's ground
elsewhere, cut rock in a maze. It is `hold_yard._ground_colour`'s own reading
**moved rather than copied** - the first cut left the Hold with its own mean and
its own cache, which would have been two answers to "what colour is the earth
here" drifting apart the first time either was tuned.

**The bound is every decoration's.** Nothing reads a scuff. `Graphics.particle_scale()`
scales it to nothing, `JuiceDirector` damps it as COSMETIC, and the run is
identical either way. One pass at `FOOTFALL_HZ` over the bodies within
`FOOTFALL_VIEW` of what the camera watches, one triangle array for every live
mark, and a hard cap of `FOOTFALL_MAX_MARKS` - so two hundred bodies cost what
the dozen on screen do.

**The Hold lays its own, and that is a consequence of what the Hold is.** Its
Wardens and residents are *records* drawn by one `_draw`, not nodes, which is
what makes four seats, six houses, a lawn and a bonfire affordable at once - so
there is nothing for a group to watch. `HoldYard._tick_treads` does the same
measurement over the same two lists, into the array the hooves are already laid
in. A rider lays no boot marks; the horse is already marking.

**And three systems were unreachable with one graphics option off.**
`_build_death_markers`, `_build_stragglers` and `_build_withdrawal` were all
called from inside `_build_trample`, *after* its `if not Graphics.foliage_trample():
return`. So a player who turned foliage trample off silently lost the death
stones, the straggler plumes, and `Withdrawal` - which is not decoration at all:
it is the road pressing on a party who pressed Turn For Home, and it carries the
floor that guarantees they reach it. Nothing errored and nothing could have.
**Found while adding a fourth thing to the same list**, which is the argument for
reading a function before appending to it.

`footfall_check` drives the real node with puppets rather than real bodies - the
subject is the driver, and a real body brings a route and a director that would
move it for reasons this gate has no opinion about - and it **counts what the
painter produced** rather than reading the constants back. It holds that
standing still and drifting under the threshold lay nothing, that zero mass
never joins the group, that the hide table names every hide, that a heavier body
and a faster one each throw more, that sixty bodies at a run stay inside the cap
*and actually reach it*, and that the regions do not all read as one colour. The
last test is a source walk, because the failure it catches is an **omission**: a
body that never registers is silently dustless for ever with every other check
on the page green.


**The city was besieged from a hundred units of picture away, and then not at
all, as of 2026-09-20.** The owner's biggest report of that batch: enemies
*"attack the city base from too far away including melee enemies"*, and the
constraint beside it - they must *"still not be able to walk over the city
base's sprite ... but rather simply stay outside of it and attack it from where
they can reach it"*.

**Both halves were one number in two places, and it is `sprite_clearance`.**
That is the whole *sprite's* diagonal half-extent - about 135 units on a 192px
body, because it measures to the corner of a painting, and a painting includes a
lifted head, a banner and a raised arm. None of that is where the body stands.

- `_target_gap` **subtracted** it from the distance to the city, so a melee
  breed stood off the wall by its range, plus its own radius, plus that picture.
  It was counted twice besides: `attack_reach()` already adds this body's
  `contact_radius()`, exactly as the ordinary branch leaves the *target's*
  radius to the gap and the *attacker's* to the reach. `edge` is already the
  nearest point on the city's own sprite, so the distance to it is the whole
  answer.
- `_process` **padded a deflection** with it, every body every frame. At 135
  against a melee reach of `ENEMY_ATTACK_RANGE + contact_radius()` - about 84 -
  a body is held beyond its own arm and besieges nothing. The first fault made
  them swing from too far out; this one would have stopped them swinging at all.

**And the deflection is not a second copy of a rule that already had an owner**
- which is what it looked like, and the wrong reading cost a gate, so both halves
are recorded. `Battlefield.step_is_legal` refuses a step that crosses *in* and
deliberately never refuses one going out; its own note lists the ways a body ends
up inside anyway - spawned there, shoved by the crowd, standing there when the
town was rebuilt - and declines to repair them. The deflection **is** that
repair. Scoping it to knockback on the duplicate theory left a body standing on
the base, which `release_repair_check` refused by name.

**`sprite_clearance` is the wrong number in both places, and the sentence that
stood here for an hour was wrong.** It said the deflection *"only ever acts on a
body already inside the rect, so it cannot park a breed beyond its own arm"*. It
can, and it did. `deflect_from_city` **grows** the rect by the padding before it
tests it, so the padding is not a margin applied to bodies already inside - it is
**the distance at which every body is turned away**. At 135 units a breed that
walked up honestly was teleported back out on every frame and stood there for the
rest of the run.

The owner photographed it: three Ember Shamans that would not come closer, one of
them shooting the wall from where it stood. A shaman reaches `aura_radius 185 +
contact_radius 25` = 210, which clears 136; every melee breed reaches
`ENEMY_ATTACK_RANGE 62 + contact_radius` = about 84, which does not. **So the
whole roster's melee could not land a blow on the city, and only the ranged
breeds appeared to work** - which is why it read as "some enemies are stuck" and
not as "the siege is broken".

The padding is `contact_radius()` now: feet at the edge, art free to overlap, and
the owner's rule in as many words - *"walk up to the point of colliding to
deflect off of the city base's sprite ... and attacking it from ranged if the
enemy is ranged, but only from once the city base's sprite is within the enemy's
attack range"*.

**Two things I assumed and measured instead, both wrong.** The town's 512x512
texture looked like it must be mostly transparent padding inflating
`city_bounds()`; its art fills 477 of the 512, so that was not it. And
`step_is_legal` does stop a body at the wall on its own - enemies consult it at
three call sites - so the walk was never the problem and the repair was doing all
of the damage.

**And the gate could not have caught it, because it asked one breed.**
`release_repair_check` took `ContentDB.enemies.values()[0]` and asserted it could
still reach the wall, which passed only because that breed happened to be ranged.
It walks the whole roster now and prints the tightest margin at the wall. **A
guarantee is a property of every breed or it is not a guarantee** - the same
lesson as the 24 fixed roads, the scattered volley and the four-act sample that
shared a period.

**What also needed moving was a gate's frame.****What actually needed moving was a gate's frame.** `enemy_behaviour_check` stood
its two probes on the field origin, which is the town, so the repair shoved them
off it and out of line and a working shield read as a broken one. Where the
probes stand is incidental to what that test measures - a shield redirects rather
than reduces - so the frame moved and the invariant did not. **That distinction
is the whole licence for touching a gate**: amending an invariant makes every
later run agree with the bug, and amending a harness does not.

**The pressure band moved with the nerf, 0.44 to 0.40.** The owner asked that
*"all enemies scale to too much health and damage"* come down; the act ladders
did - health 2.28 to 1.94 by Act X, damage 1.28 to 1.18 - and solo mean pressure
went 0.479 to 0.417. That is `curve_report` judging the re-tune against the game
it replaced, which is **the same failure recorded when the band last moved on
2026-09-15**: a bound written in prose here and enforced by a constant in a tool
is two places to change and one place to forget, and the constant is the one that
decides. The ceiling is deliberately unmoved - a nerf cannot make the road
harder, so lowering the top would invent a bound nobody asked for.

**And the first fork stopped offering a road nobody had walked.**
`extraction_open` was reading `RunState.wave_number > 0`, true from the first
wave, against a docstring that says the opposite in as many words. `momentum` is
the reading that answers it, and `_open_crossroad` raises it *after* computing
the offer precisely so the first fork sees zero. Momentum also rides the
expedition snapshot, so a resumed road remembers how many forks it passed
without banking.

**Two gates were run by nothing**: `release_repair_check` and
`lightning_lifetime_check` each had a `.tscn` and no workflow line, so neither
could fail a push or a tag. That is the fourth costume of the guard/release
split, after `layout_check`, `copy_check` and `audio_verify` - and the answer is
still to **diff the two lists rather than trip over them**. Both are on both bars
now, and the diff reads clean in the direction that matters: release is a
superset of guard, with only the five judgement-heavy reports release-only.

**"Enemies never attack anything" was six bodies aimed at a tower, and the
loop everyone suspected was not the cause, as of 2026-09-21.** The report on
v0.47.1: a body stood against the base, the town at 24%, nothing swinging -
"not the base, not the player, nothing." The plan left for this session named a
mechanism and, to its credit, said not to believe it: `step_is_legal` refuses
the ungrown rect while `deflect_from_city` grows it by the padding, so a body
walks in and is teleported out on every frame and never settles into a swing.

**Traced before anything was changed, five ways.** One body hand-driven with
the field frozen; one body with the whole field live; four breeds against a
hero on the road; the real director for four minutes on a new account; and the
real director on a copy of the owner's own banked front (Act II, wave 58,
twelve towers, wall at 51%). Every ordinary body walked up and struck: the town
went 1250 to 0 on the fresh account and 641 to 0 on the owner's, the hero at
176 units was hit by all four Act I breeds. **And every Dune Burrower in the
owner's wave stood at the wall for three minutes in WALKING, thirty-one units
off the base, aimed at a tower.**

**The road is not optional, and that is why a siege breed arrives with a
target it cannot reach.** `_walk` follows the route whatever the body is
looking at - that rule is what keeps a column on the bends - so a breed that
`targets_towers` picks the nearest tower in its lane, walks past it, and reaches
the wall still holding it. The hero branch of `_pick_target` has said "a body
at the gate hits the gate" since 2026-09-12; the tower, grudge and taunt
branches never did, and the tower branch has had no reach condition since
2026-08-13. **So this was not a v0.47 regression.** It stood at the 216-unit
circle before the rect and at the rect after it, and nothing in either release
changed what it did; what v0.47.1 changed is that a melee body now stops a
body-length off the base rather than ninety units out, which is what made the
one that never swung look like the one that could not.

**The loop is real and it is not the fault.** A body that walks up honestly
stops the moment it is in reach - eighty-four units off the rect - and the
padding is twenty-two, so the deflection never fires for it. It fires only for
a body that keeps walking at the wall, which is a body whose target is not the
wall. Fix the target and the loop has nothing to run on.

**One rule, applied once.** `_pick_target` now wraps `_choose_target`: a body
in reach of the town and of nothing it was aiming at answers the town. It never
takes a target away from something in reach, it never touches a camp body, and
it is in the wrapper rather than in each branch so that the next branch added
cannot forget it. Measured on the owner's front after: the burrowers at the wall
in RECOVER and STRIKE aimed at the town; the town fell at 55 s rather than 165.

**"Not the player" was not reproduced and is recorded as such.** Four breeds
attacked a hero standing on the road at 176 units within three seconds. What
did change in v0.47.0 is the sanctuary: `inside_city` went from a 216-unit
circle to the sprite's own 512-unit square, so a Warden within 256 of the town -
362 at a corner - is invisible and immune to every body on the road, by the
owner's own rule of 2026-09-17. A player defending at the gate is standing in
it. That is the design working at a larger radius, and it should be said on
screen rather than discovered.

**`enemy_siege_check` (246 checks)** walks all sixty-eight breeds up the road
by hand until each strikes the town, stands every siege breed at the gate with a
tower in its lane beyond its arm and insists it swings at the wall, and keeps
`structure_check`'s invariant that the tower is preferred from the spawn and
beside it. Planted: the wrapper returning what was chosen names all six siege
breeds. Five things the gate taught on the way, each a harness fault and each
one this project has met before in other clothes:

- **A boss's blow ends the run.** Walking the roster hand-driven, a giant took
  the town to zero, `TownCore._on_died` called `end_run`, and forty breeds after
  it were measured on a run that had ended - "aiming at nothing". `floor_hp`
  holds the town at half; it is the door the withdrawal already uses.
- **A share of a route is not a distance.** Routes differ threefold in length,
  so "a fifth of the way in" put one marcher a minute further out than another
  and the slow ones ran out of budget. Bodies stand a fixed distance back from
  the wall now.
- **A lane's routes end at any of the four gates.** A body draws its route at
  spawn from the run's stream, so the probe's "unreachable tower" was reachable
  on one run and not on the next - a coin toss wearing a gate's clothes, the
  fifth here. The tower is placed clear of every gate for every siege arm.
- **A tower stands ninety-six units off its tile's centre**, and a body
  measures reach from its combat origin, a hundred units above a giant's feet.
  Both were read off the built tower and the ticked body rather than computed,
  because the first cut computed them and passed the giant.
- **Shots are children of the field, not of the entity root.**

**And a mount was thrown by the ground it rode on.** `_may_stay_mounted`
refused the saddle while `_beast_stun_left` ran, and every footfall of Yuri's
sets that - the fault the fishing line paid for once, where a shove never
settled under a stillness threshold. Read straight off the code and then driven:
one `beast_step_landed` and six ticks, off the horse. **What ends a ride now is
a blow** (owner, 2026-09-21): `_on_damaged` throws the rider when health was
lost, the saddle closes for `Balance.MOUNT_HURT_COOLDOWN`, and `mount()` says
so out loud. **Health lost, not a hit**, because a ward that swallowed the whole
blow emits `damaged` with nothing taken, and the co-op mirror - which learns of
a blow only as a lower fraction in `CoopHeroes._apply_health` - could never
agree about one of those. The mirror throws on the drop through the same
`throw_from_saddle`, so the host's copy of a guest and the guest's own Warden get
off on the same fact. `MountCooldownRing` is a child of the ride button that
draws the horse's own south-east idle cell inside an emptying arc, read off
`mount_cooldown_ratio` every frame and visible for that clock and no other -
the ordinary 0.6 s remount delay would be a ring flashing on every voluntary
dismount. `mount_check` (119 checks) drives all of it and both planted faults
were named. The owner's other mount ruling - faster, and a sprint that costs SP
- is untouched by this patch and still owed.

**Two things worth keeping from how this was found.** A report and a headless
harness disagreed four times in a row, and what settled it was neither reading
the code again nor doubting the owner: it was running the owner's *own save*
through the real director and dumping every body. `enemy_siege_trace` is that
harness, kept as a diagnostic rather than a gate - `--mode=hand|engine|hero|
full|resume`, the last against whatever save the profile holds - so the next
"they never attack" starts from a dump rather than from a theory. And the beast's footfall was
ruled out for the enemies by arithmetic rather than by measurement - 27 units a
second at 0.72 decaying at 900 is a fifth of a unit of travel - which is a
computation, and is recorded as one.

**Loot falls as pieces, and a pickup is one thing you walk to, as of
2026-09-21.** The owner: pickups *"should fall and bounce on the ground and
scatter in high quantities instead of as stacks so that the player can enjoy
picking up each individual item ... more pickups should drop more often but
maybe in less total quantity to balance it out"*.

**A drop is split, tossed and landed before it can be taken.** `LootDrop.split`
deals an amount into pieces by `LOOT_PIECE_VALUE`, at most `LOOT_PIECES_MAX`,
and **the pieces sum to the amount exactly** - a piece is never created and
never lost, which `exploit_check` holds by collecting every piece of a drop and
reading the purse. Each piece is thrown (`LOOT_TOSS_LIFT_*`, `LOOT_GRAVITY`),
bounces and settles, and **may not be collected or magnetised until it has
landed once** - the first cut let a hero standing under a kill take the piece
on the frame it was thrown, and the toss was never seen. The node never leaves
the ground plane; only the picture does, so nothing about range or reach moves.

**Attention belongs to the lead of a batch worth announcing.** Nine coins are
one thing to walk to: the spire and the motes go on the lead piece of a batch
worth `LOOT_BEACON_MIN_VALUE` or more, and never on each coin of a handful -
or a wave's worth of pieces is a forest of spires. Gear, blueprints and every
recovery keep their own.

**Three more things to pick up.** A **coin pouch** off elites and bosses,
which lands as one thing and spills on pickup into the four currencies,
gold-heavy, in at most `COIN_POUCH_PIECES_MAX` handfuls; a **quiver**, which
pays ammunition for whatever bow the Warden carries and is not dropped for a
Warden without one; and a **mana orb**, a fraction of the pool. Every
recovery still expires rather than pays - working rule 7 is untouched, and
the pouch's pieces pay through the same door every piece pays through, so a
pouch is paid once and never created from nothing.

**The rate moved the way the owner asked**: drops on more kills
(`LOOT_DROP_CHANCE`) for a smaller share of the kill (`LOOT_BONUS_SHARE`),
elites and crates scaled to match. `LOOT_FIELD_MAX` bounds the nodes on the
field by paying the oldest plain piece out rather than deleting it. In co-op
each piece is its own fact with its own `net_id` and a lead flag; the relay
still accepts the old four-argument shape.

**Three harnesses assumed a drop is one node and were amended, deliberately.**
`raccoon_check` counted drops and matched one Gold amount (it sums the pieces
now), `regression_check` asked a one-Gold piece for a spire (it asks the lead
of a batch worth announcing, and holds the inverse), and `exploit_check`
collected at a one-unit radius. Recorded because amending a gate's invariant
is the one change that makes every later run agree with the bug.

**And two of the new gate's own checks were coin tosses.** The toss is drawn
from the piece's own dice, and the gate held its peak against a literal 40
when the weakest toss peaked at 25 - it passed about four rolls in five. The
weakest toss now clears `LOOT_CATCH_HEIGHT` by construction (`LOOT_TOSS_LIFT_MIN`
310) and the gate holds the *derived* minimum; the slide was held against a
literal 160 when the constants can throw about 200, and is held against
their own arithmetic now. `recovery_drop_check` waited ninety *frames* for a
crate that has to land first, and headless runs far above sixty a second - it
waits seconds. `loot_juice_check` reads 50 checks, four runs in a row.

**The guest's four failures were one real fault and one frozen harness, found
2026-09-21.** `coop_ui_check` is the two-process gate launched by
`tools/coop_ui.sh`, run by hand and on neither bar. Its host passed and its
guest failed four checks: no wildlife seen, a tend and a tower asked for and
not answered, and a hero carrying full walking velocity after a wipe and moving
nowhere. Identical on v0.47.2, so older than that release.

**The wildlife was the relay's arity.** `coop_wildlife_spawned` grew a fourth
argument - the shiny flag - and `CoopRelay._on_coop_wildlife_spawned` kept
three, so Godot printed *"expected 3 argument(s), but called with 4"* on the
host at **every spawn** and relayed nothing; the receive arm accepted three
and would have dropped a four-element fact besides. An arity mismatch errors
on the sender and is silent on the receiver, which is the worst shape a fault
can take, and every co-op gate drove the signals either side of the relay
without firing this one through it. `coop_check` walks the whole binding table
against the bus's signal list now, and named the planted three-argument
handler. The same walk over every *lambda* connected to an EventBus signal
found one more, in `coop_live_check` itself: its enemy-spawn listener took
seven of eight, so the live harness had been red for as long as the pursuer
flag has existed.

**The other three were the harness measuring a suspended field.** The guest
asks for a road and the host grants it - and then `_on_road_chosen` deals the
road cards and keeps the battlefield suspended under the draft until one is
kept. Nobody in the harness took a card, so both machines sat at the crossroad
with every hero absent from the world: the host's mirror of the guest stood at
one position with stale velocity, `_send_state` never ticked, the tend the host
did perform (0.50 to 0.84 on its copy) never crossed, and the guest's own
Warden was corrected every packet toward a copy that could not move. Traced by
printing both sides every two seconds rather than by reading the code again -
the code was right. The guest asks for a card now, through the screen's own
`_send_road_card`, and both sides assert the field resumed.

**And the tend check was measuring a fiction.** It set the guest's own hero to
40% locally and waited for it to rise. A guest hero's health is the host's to
say - it arrives as a fraction of the host's mirror twenty times a second - so
that number was one the host had never seen. It reads the host-authored wound
the wipe respawn left and asks for a rise above it.

**Also found on the way:** a guest was measuring lane pressure off its own
field and the relay refused it as a guest authoring a fact, an error line per
tick for the whole run; `_update_pressure` returns on a guest, whose HUD is fed
from the wire. And the host script finished before the guest's requests
arrived, so the guest now says it is done on the chat channel and the host
waits for that. Both two-process harnesses pass clean on this machine.

**Eleven acts, and every act names its roster, as of 2026-09-21.** The owner:
*"11 acts with more waves per act and 8-19 enemies per act, with each act
progressively increasing in +1 count of the total unique enemies each
consecutive act, with act 1 having 8 unique enemies ... and act 11 having 19"*.

**The eleventh act was already there and was not an act.** `FINAL_ASCENT_ACT`
has been `ACT_COUNT + 1` since the ten-act road, with Kharok at its top - and
it was 400 units on the Terrace's own ground with the Terrace's own roster,
about seven waves. It is an act now: `data/terrains/crown.tres` at act 11 with
a summit floor, a horizon strip and a pond sheet of its own, the roster every
road behind it sent, and `FINAL_ASCENT_DISTANCE` 3200 - about 58 waves,
shorter than the Terrace because a climax is a peak and not a plateau.
**Nothing was renumbered**: acts 1-10 keep their ids, every banked expedition
still means what it meant, and `act_end_distance(11)` is where the summit is.
Entering the ascent changes the region exactly as a boss falling does, and
`act_started` is said for it, which `resume_after_boss` deliberately never did
past `ACT_COUNT`.

**A roster is a countable list now.** `TerrainData.veteran_ids` names the
breeds from other roads that walk this one at the invader chance, replacing
the old draw from a random earlier region's whole pool - so a wolf rider is
on the Steppe because it belongs there, not because its region came first.
`Balance.ACT_UNIQUE_ENEMIES` is the owner's table, 8 to 17 by one a step and
19 at the summit: the two endpoints the owner named do not meet at +1 over
eleven acts (that reaches 18), so the table is the rule to the Terrace and the
summit takes the owner's own figure. One number to change if that reading is
wrong. `roster_check` (702) holds every act to its entry **exactly**, every
body to its base painting and its idle, walk and attack frames, every veteran
to a home on another road, and **drives the real director's draw** three
thousand times an act to prove the list is what the dice reach - listing a
breed is not fielding it.

**Fourteen breeds joined the road**, one or two a region and four for the
Crown: Thorn Archer and Canopy Stalker (Verdant Maw), Dune Reaver (Waste),
Marsh Piper (Marches), Gear Grinder (Rustwood), Tide Lurcher (Saltpan), Horde
Marksman (Steppe), Prism Lancer (Glass Fields), Slag Brute (Ashen Reach),
Stair Warder (Terrace), and Kharok's own Chainwarden, Chainlancer, Anchor
Cantor and Ballast Brute. The four road breeds no region had ever listed -
Crevasse Stalker, Frost Herald, Glass Chanter, Loam Lurker - walk the regions
they were drawn for. Every stat sits inside its role's neighbours and every
kill value on the roster average, because **a roster average drifts as the
roster grows** and `curve_report` refused a batch authored below it once.

**Generated with a shipped sprite as the style image and the palette left
off**, which matched the painterly roster on the first pilot - the technique
is in the memory directory. Seven of the first twenty animation jobs came
back **410**: PixelLab's GPU worker dropped them, unbilled, and the staging
tool aborted the whole batch on the first one. It skips and names them now.

**The road is an eighth longer and the curve is re-measured.** Every act's
road grew by an eighth (`ACT_ROAD_DISTANCE`), which with the summit lowered
solo mean pressure to 0.375 against a floor of 0.40 - a longer road earns a
purse the same climb no longer answers. **Height and length are separate
knobs**: `WAVE_GROWTH_REFERENCE_RUN` went 296 to 330 and the curve reads
0.414 solo, 0.487 for four, acts 0.22 to 0.58, on a new account.
`ACT_START_BUDGET` was re-read off the purse column. `balance_test` held the
launch roster to exact counts and a drop to one node; both are floors now.

**The wyrm is seen as the thing it is, as of the same date.** The owner:
*"Dragons need more polish and bug fixes."* Four things were true in the code
and false on the screen: every variant flew as one painting tinted toward its
breath; a landed wyrm was the base painting standing still while its idle and
attack sheets sat on disk unread; the shadow stayed at flight size under a body
on the ground and read as a second dragon lying beside the first; and a rare
wyrm - a fifth larger overhead - landed at the common size. Each variant has
its own overhead painting and `_fly_NN` wing-beat frames now, the landed body
breathes and strikes on its own sheets, the shadow settles to
`DRAGON_SHADOW_REST` of its silhouette as the body comes down, the rarity step
is the same on the ground as in the air, and the landing is felt: dust the
colour of the ground, a knock through `camera_impact` weighted by distance
like every blow, the animal's own voice. **Presentation only** - nothing
downstream reads any of it, and a variant without its own painting flies as
the shared one tinted, which is what every dragon was. `dragon_check` lands a
common and a rare wyrm by hand and reads the size, the shadow and the frames
back.

**The Walk's verbs finish their stops, as of the same date.** The owner: *"The
game's tutorial needs to be completed and polished."* Twelve of eighteen stops
finished on arrival, and four of them did so while telling the player to *do*
a thing - loose an arrow, cast, upgrade, cut the chain - so the valley taught
the words and never the deed. Each finishes on the signal the game already
emits (`hero_loosed`, `spell_cast`, `tower_changed` read for a level that
rose, and the chain's own `cut`), which is `_listen`'s rule: a Walk that
thinks an arrow flew and a hero that does not is not a state it can reach.

**Three things had to stand before the verbs could.** The butts lend the
starting-kit bow and a quiver, exactly as the armoury hands them over; the
build stop said *"It costs Gold, which is why you killed for it"* on a road
that opens with none and one scripted kill behind it, so the two purchase
stops open with the valley's chest (`WALK_BUILD_PURSE`, `WALK_UPGRADE_PURSE`);
and the last stop said *"Cut the chain. Hold Interact"* with nothing to hold
it against, so `WalkChain` stands `WALK_CHAIN_STANDOFF` below the town, reads
the same `HeroInput` every worked thing reads, sparks while it is held, gives
ground while it is not, and parts after `WALK_CHAIN_SECONDS`. All of it is
run-scoped - the Walk's run is never settled - so *"nothing here grants
anything"* still means the account. `tutorial_walk_check` drives every verb
through its real signal on a real Walk, and named a planted Walk that stopped
listening for arrows.

**The clock has one owner, as of 2026-09-21.** The roadmap's first genre
expectation: *"a ten-and-a-half-hour tower-defence campaign without a
fast-forward is a pacing complaint in every review"*, and there was none.
What there was is why it had to be built as an *owner* rather than a toggle:
`Engine.time_scale` was written by the hitstop, the boss-fall slow and three
doors in `GameDirector`, and every one of them put it back to the literal
`1.0` when it was done - so a 2x laid beside them would have been undone by
the first blow that landed. `GameSpeed` holds the base rate; everything that
borrows the clock gives it back through `restore()`, every run and walk opens
through `reset()`, and `game_speed_check` walks the source for the literal so
the next door cannot write it.

**Solo only, and that is a fact about the wire.** A guest's world is facts on
the host's clock; a host that is merely listening may be joined. Any session
at all holds the road at one speed, and the button says why. It is `P` and a
button beside RIDE ON, hidden on a touch layout for now - the column has no
room on a landscape phone and the key it wears is a keyboard's.

**The wall is said out loud, as of the same date.** *"I didn't know I was
losing"* was the first-hour complaint the roadmap put first, and the town bar
answered a blow with nothing. A blow flashes the bar and the banner names the
road it came from - read off where it landed against the town's centre, because
four roads face four ways and a player defending the east gate wants to know
it is the west one falling - at most once per `TOWN_ALERT_COOLDOWN`, or a
siege is a banner that never leaves. Under the critical share the bar pulses
as the hero's does; bodies inside `TOWN_ALERT_NEAR` tint its icon and are said
once, polled rather than counted a frame. `EventBus.town_struck` carries the
position `TownCore` already had and threw away.

**And the sanctuary is said on entering.** The town's own footprint is where no
road body can see or touch a Warden (owner, 2026-09-17), and it grew from a
circle to the whole sprite in v0.47.0 without a word on screen - so a player
standing on it watched bodies ignore them and read it as "enemies never
attack". It is said once on the way in, in combat, and not again for a while.
`town_alert_check` reads all of it back off the real HUD's own banner.

**The animator paints its own light, and the fix is the prompt, not the
scrubber.** Six of fourteen strike sheets came back with slash trails, bursts
and arcs painted into the air - the same bright-blob artefact the menu Warden
shipped with, now on purpose because the words "slash", "swing" and "strike"
are effect words to the model. A prompt that *forbade* effects in capitals
changed nothing. **Describing the motion of the body alone, with no combat
noun** - "the figure twists its torso, both arms sweeping across the body at
waist height" - came back clean on all five. `tools/scrub_animation_frames.py`
carries the menu scrubber's rule for any sheet as a backstop; it found nothing
to erase on the shipped roster, which is the measurement that says the prompt
did the work. The game draws its own hit effects, and a strike painted into the
sprite is a strike that plays twice.

**Three walks sat in PixelLab's queue for an hour and were marked failed
without a 410** - the download answered 423 the whole time, so the staging
loop waited on jobs that would never finish. The queue's own message says to
submit fewer at once; twenty in flight is the ceiling, not the target.

**Mounts are faster than the Warden on foot, and a gallop spends SP, as of
2026-09-21.** Owner ruling, recorded in `docs/NEXT_SESSION_PLAN.md` before it
was built: *"a mount is faster than the Warden on foot, a mounted sprint does
spend SP, the rate differs per mount, and every mount gets its own tuned walk
and sprint speeds."* That re-cuts two sentences this file wrote down
deliberately on 2026-09-17 - `MOUNT_SPEED_CEILING` *is* `HERO_SPRINT_SPEED`,
and *"the rider's SP is untouched"* - so it is recorded here rather than
quietly built.

**The bound was written before the code, because the old one is gone.** What a
mount trades is not damage - the dismount-on-attack rule is untouched, a rider
still cannot swing, cast, loose, gather, fish or work a seam, and
`curve_report` still models no movement - but **how fast a Warden can be
anywhere on the field**, which with four roads is a defensive number. So a
gallop is bounded twice and both are stated in `Balance`: `MOUNT_GALLOP_CEILING`
(2.2 of a walk) in speed, and `MOUNT_GALLOP_RANGE` (2,600 units) in how far one
full pool of SP may carry it. Every mount's `gallop` and `sprint_drain` are
tuned against each other under the range and above the Warden's own sprint
(about 1,500 units a pool), so a faster animal is a thirstier one: the marsh
pony gallops at 1.70 for 14 SP a second, the steppe horse 1.85 for 17, the
terrace stag 1.95 for 16, and the ash courser 2.10 for 24 - quick, and it wants
the stretch to be short.

**One pool, one winded rule.** The mount's own wind (`mount_wind`, its floor
and its rest) is gone: `Hero._tick_stamina` is the sprint on foot and the
gallop in the saddle, differing only in the rate and the dust, so a rider who
spends it all arrives winded exactly as a runner does and is refused a gallop
until `HERO_SPRINT_FLOOR`. A walk in the saddle still spends nothing; what it
costs is being unable to fight.

**`mount_check`'s invariant was amended deliberately.** It held *"galloping
took the Warden's SP ... a mount's wind is its own"*, and amending a gate's
invariant is the one change that makes every later run agree with the bug it
was built to catch - so what replaces it is measured rather than asserted: the
drop over a stretch of the real tick against the mount's authored rate (a hero
draining at the runner's rate was planted and named), an unsprinted mount
spending nothing, the pool coming back at rest, and the winded refusal. The
stable's card says the rate: *"Gallop +85% · 17 SP a second"*.

**Three things between the systems, and a pad that can reach every screen,
as of 2026-09-21.** The roadmap's "not yet considered" list (§7.1-7.2) was
checked before anything on it was built, and most of §7.1 already existed
under other names: tower targeting is `RunState.cycle_target_priority`, the
wave preview is a HUD label, the colourblind modes are on the settings screen,
and the flash and damage-number scales joined the shake slider on 2026-09-16.
What was genuinely missing is built and gated by `qol_check` (32) and
`pad_focus_check` (42), both on both bars:

- **Leaving is said before it is done.** A road banks only when the party
  turns for home at a crossroad, so a quit from the pause menu abandons
  everything since that bank - and the button said "Abandon the road" without
  saying what the road was worth. `PauseMenu.leaving_costs` is the sentence,
  pure over the run state: nothing banked, banked *n* waves ago on this road,
  banked at this very wave, a bank from another road, a guest (whose road is
  the host's), the Walk and an ended run each get the right one. The first
  press shows it and turns the button into the confirmation; the second
  leaves; reopening the pause menu forgets it, so a stale "leave anyway" never
  waits for a later press.
- **A preset chosen for the machine.** `Graphics.preset_for_machine` is pure
  over the adapter name: a discrete card starts on High for the reason above
  `DEFAULT_PRESET`, an integrated chip on Medium, a software renderer on Low,
  the web on Medium whatever the card, a phone on Low. **A saved choice is never
  second-guessed** - it is read only when the save holds none - and the settings
  screen says what was chosen and for what, so the automatic choice is visible
  rather than silent. Names rather than a benchmark, because a benchmark on the
  first frame is a stutter on the first frame.
- **The interface has a size.** `UserSettings.UI_SCALE_KEY` multiplies the fit
  `ScreenFit` already computes for a small screen, so a phone's enlargement and
  a player's taste compose rather than fight, and the window is re-fitted the
  moment the slider moves. Bounded 0.8 to 1.5 and clamped on read, because a
  save may hold anything.
- **Every screen can be walked with a pad.** The pad was full and every action
  had a button, and whether every *screen* could be navigated by focus alone
  had never been asked. `pad_focus_check` stands up every screen with a
  no-argument `open()`, the main menu, the pause menu and the settings, and
  follows the engine's own `find_next_valid_focus` ring from the first
  focusable control until it closes - which is what a D-pad press does - both
  ways round. Every visible, enabled, focusable control has to be on it. A
  planted `focus_next` loop on the pause menu was named. **Its first cut
  reported the vendor's Ledger door as unreachable and was wrong**: the walk's
  budget was twice the count of controls the gate had collected, and the
  engine's ring also walks click-focus controls the gate does not count, so
  the budget ran out before the far end. The budget is a constant now and the
  walk ends when the ring closes.

**The mounts have idles, as of the same date.** Each of the four is eight
directions of five frames - the rotation as frame 0, so the loop closes on the
base, then four generated - bought as `animate_character` in `mode: "v3"`
with an `action_description` that names only what the body does (a breath, an
ear, a tail, a slight dip of the head, hooves planted, tack in place), which is
the recorded lesson from the walk cycles: the template animations strip the
tack. One direction was piloted and photographed before the other thirty-one
were bought, at about four generations a direction. The character zip's
`download` endpoint hands back every frame by folder, and
`tools/pack_mount_frames.py` reads a local path as a local path, so no frame
went through the conversation. `MountRig` plays the idle at 3.5 frames a second
rather than six, because a breath over five frames at six a second read as a
horse shivering.

**The Warden has a look, as of 2026-09-21, and it is a dye and nothing
else.** Owner ruling (`docs/NEXT_SESSION_PLAN.md`): character customization is
approved, and its bound was written before the code - **it may change nothing
but how the Warden looks.** No attribute, no stat, no unlock, no currency,
nothing the road can grow. This project has refused a third power scale a
dozen times, and a cosmetic that reached a number would be one arriving
through a settings screen.

**Two dyes rather than a paper doll, and that is the budget decision the plan
asked for.** The Warden is eight directions of idle, walk, sprint, dash, death
and four attack sheets, and the PixelLab character they came from no longer
exists, so every *drawn* option is every sheet again - the one thing here that
could eat the art budget. A dye is `warden_look.gdshaderinc`: a hue turn on the
teal-steel band the cloak and armour are painted in, and another on the
saturated red the sash and banner are painted in, keyed on hue bands with soft
edges so bone, the lantern's orange, the gold trim and the plain greys stay
what they are. It reaches every frame of every sheet for free.

**One include, two shaders, because a sprite has one material.** The hero on
the road already wears `blood_stain.gdshader`, so the dye lives inside it and
is applied before the rim, the burn and the stain, which read over dyed cloth
as they read over painted cloth. The Hold's figures and the Warden card's
portrait wear nothing, so they wear `warden_look.gdshader`, which includes the
same file - two copies of one recolour would drift the first time either was
tuned. `WardenLook.dress` sets the uniforms on whichever of the two a sprite
wears, gives a *plain* Warden no material at all, and never replaces another
material, which is `BloodStain.attach`'s own rule.

**It amends working rule 7 by two numbers.** `MetaState.look` is
`{cloak, sash}`, each a hue turn clamped to half the wheel; additive, so a save
without it is the painted Warden, which is also what a new account is.
`SAVE_VERSION` did not move. On the wire it is two numbers by value: a
partner's look rides the state row as a seventh element behind the mount, and
the Hold's seat rows and the hello carry it the same way, so a machine draws
the Warden it was told about and never a guess - and its own seat is never
overwritten by the echo of what it sent, because a slider still moving would be
fought by its own packet.

`warden_look_check` (36 checks) holds the bound by dressing a real hero and
reading every attribute, the speed, the pool and the damage back through the
same functions the fight reads; the save round trip through the real loader on
the save's own JSON; a packet that is short, long or not an array drawing the
painted Warden rather than erroring; and the three sprites - one wearing the
blood shader, one wearing nothing, one wearing somebody else's material.
**Headless cannot compile a shader**, so the wiring is read off the source and
`look_shot` photographs four Wardens on a plate - painted, cloak dyed, sash
dyed, both. Read on the renderer: the cloak dye turns the steel and the cloak
and leaves the banner, the lantern and the bone; the sash dye turns the banner
and the sash and leaves the rest. The bands are right.

**Not built, deliberately:** the co-op party portrait on the HUD still draws
the painted Warden for a partner - it is configured by slot and colour before
the partner's look has arrived, and the fix is to dress it from the mirrored
hero's `look` when it changes. And a *drawn* option (a hood down, a different
weapon) is still every sheet again; if one is ever bought, pilot one direction
first, as the mount idles were.

**A boss quickens as it breaks, as of 2026-09-21.** The roadmap (§7.4) called
the bosses "sponges with two moves" and proposed a behaviour change at half
health. Half of that was stale: every one of the twelve already has phases -
thresholds, names, reinforcements, a speed bonus and a damage bonus - and the
codex describes them. What was true is that the slam and the volley kept the
same clock through every phase, so a boss at a third of its health fought
exactly as it did at full with less health left. `Balance.BOSS_PHASE_TEMPO`
shortens both waits by a share per phase entered. **A rate the fight already
has**, which is the bound every boss ability is held to - the slam is the same
slam and the volley the same volley, sooner - and `boss_reach_check` measures
it on a real body through the two doors that set the clocks, because a tempo
applied at one of them would pass any check that read the constant.

**The 4K shape found an overlap that 1080p only sometimes has, as of
2026-09-21.** Roadmap §7.2: "ultrawide and 4K layout ... 21:9 has never been
photographed." `layout_check` was run at 3440x1440, 2560x1080 and 3840x2160,
and 4K failed **one run in three**: a currency icon of the top bar, 34 by 62,
sixteen pixels under "Act 1 boss in 2240 distance". The height is the pools
column - three bars and their gaps are 62, so the bar is 62, so every box
child fills it, including a 34px icon whose *picture* stayed centred at 34
while its *rect* did not. The intermittence is the weather label: it reads
"Clear" or "Clear · 24°" depending on whether the sky's temperature had
arrived by the time the gate measured, and the longer one shoves the currency
rows fifty pixels right, under the boss line's left edge. Nothing about 4K
caused it; 1080p has the same logical width and the same dice, and the sweep's
1080p runs had passed by luck. `IconKit.rect` gives every icon
`SIZE_SHRINK_CENTER` vertically now - its own square, whatever row it sits in
- the overlap reporter prints both rects' sizes, and the 4K and ultrawide
shapes run on both bars. **A size in a report is what told this apart from a
placement fault**; the position alone read as the boss line being too high.

**The tail is answered in the file, as of 2026-09-21 (ninth report).** Eight
passes argued about what happens between the painting and the screen - a
modulate, a self_modulate, a shader, a per-channel harmony, a chroma, a value
pull, a seat - and the owner kept seeing a limb that was not the animal it
hung from. Measured on the paintings, surface only, ink held out: **the tail's
root was painted a sixth darker than the stub it continues** (rgb 60/64/52
against 71/77/59), and the runtime then darkened it a further six percent on
purpose, on the theory that a low-hanging limb should read darker.
`tools/grade_tail_to_stub.py` paints every tail frame's root to the stub's own
colour and brightness, and **nothing at runtime touches the limb's colour any
more**: `wear_grade`, `harmonise`, `_paint_match`, `BEAST_TAIL_GRADE`,
`_CHROMA`, `_VALUE_PULL`, `_SEAT` and the harmony band are all gone. The tail
is a child of the body and inherits its grade, which is the whole mechanism
and cannot drift with a constant. `beast_tail_check` holds both halves - the
file, and the absence of any knob - and `TailProbe` reads both scopes off the
frame in `menu_shot` and `beast_shot`.

**Two things the probe got wrong first, both coordinate mistakes.** The
spline's chain is in the *painting's* pixels with the root at `root_in_art`,
and the node's origin is that root - walked as local coordinates it read 52
lit pixels of night sky as the tail. And screen space is the canvas
transform, never the world: the menu has no camera so the two agree there,
the beast scope has one and the first reading found nothing lit at all. A
model of a thing is not the thing, and a *probe* of a thing is only as good
as its frame.

**The Walk's card clears the command row, and seven actions fit beside four
slots, as of the same date.** The card sat 24px off the bottom edge, where
the ability slots live; its foot reads `HUD.bottom_reserve` now, the one
number the HUD measures its own band by. And the seventh action button (the
ride, 2026-09-17) pushed the bottom row to 1996 of 1920 and the fourth
ability slot off the screen - unseen by `layout_check` because a clean
profile owns no horse. The action buttons wear 18px of side padding in place
of the theme's 34, the gate saddles a mount, and it prints what the row wants
by part so the next button to arrive names itself.

**The Arcane opens with Act II, as of 2026-09-21.** Owner: "players can
unlock the magic discipline in the hero mansion after beating the Act 1 boss
and unlocking act 2". `Balance.DISCIPLINE_OPENS_AT_ACT` is the table, read
through one door - `RunState.discipline_is_open`, asked by
`eligible_discipline_nodes` - against the furthest act the account has reached
*or* the act the run is in, so the run that fells the first boss opens it on
the spot and an account that has reached Act II keeps it open on a new road.
The three melee trees open at once. **It is an unlock, never power**: the
nodes are the same nodes on the same capped scales, and what a new Warden is
spared is a fourth column to read on the first visit. The Mansion page says
what opens the tree and when. `discipline_check` drives the door in Act I, in
the run that reaches Act II, and on an account that has.

**A seam sheds Stone and a trunk sheds Wood, and practice widens the take
without unbounding it, as of the same date.** Owner: "appropriate chances for
all of the resources they should provide, which should also include stone,
and there should be chances to gain increased quantities each mining action
with randomness that is also scaled by the player's mining level. Same with
woodcutting and other professions." `GatherNodeData` names a run currency
with a chance and an amount and, for the ore seams and the bloodpine, a rarer
material on a smaller one - a gem out of copper, resin amber out of pine.
The flat one-in-five double is gone: a swing rolls `GATHER_BONUS_ROLLS` times
for one more of its material, at a chance that rises with the craft, so a
novice's swing is mostly its authored take and a master's is a spread, and
**the most any swing can pay is the authored take plus the rolls**.

**The bounds are the ones every craft and every wire already carry.** The
currency is the run's and resets with it; the material is still an input to
the Smithy and nothing else; a guest's Stone is asked of the host **by node
id, never by amount** (`Request.GATHER_SIDE`), and only when its own roll
landed, so the host pays what the node says and never more often than a
swing. `gathering_check` swings a real seam four hundred times at level one
and at the cap and reads the store and the purse back: novice 474 ore, 238
Stone, 19 gems; master 837, 480, 30 - more of everything, and never past the
ceiling.

**The sponges came down, as of the same date.** Owner: "Some enemies have
absurdly high amounts of health ... such as the Siege Lizard enemies in act 2
... Scale those higher HP enemies including act bosses down to be more
reasonable." A road warden at 250 base was 785 by the middle of Act II once
the act and wave ladders had multiplied it - thirteen seconds of uninterrupted
hitting for a Warden of that level, several to a wave, and it hits towers. The
nine road wardens above 100 are at 64% of what they were (a 300 is 190, the
Siege Lizard's 250 is 160) and every act boss at 72% (the Chainmaker 16,000 to
11,500, the Act I boss 6,400 to 4,600). Camp lords are untouched: a dragon is
worth the detour.

**And `curve_report` read 0.413 before and 0.413 after, to the digit** - which
is worth knowing rather than reassuring. The report's threat is the act and
wave ladders over the roster's *count*; it earns Gold from every breed's kill
value and reads no breed's health at all. So a body's own pool is a thing the
report cannot see, exactly as a boss fight is, and the sponge the owner met was
never going to show in it. Where it does show is `balance_test`,
`roster_check`, `elite_check`, `boss_reach_check` and `enemy_siege_check`, all
green after the cut.

**Every ranged breed throws shots of its own, as of 2026-09-21.** Owner:
"Enemies should not be reusing the same projectiles as each other, each enemy
should have its own unique projectiles ... ranged enemies are to have multiple
variations of ranged projectiles and ranged attacks each tuned for that enemy
... max perfect polished ultra juicy". Twelve shared files served twenty-four
breeds; a Fog Lantern and a Mirage Seer threw the same `snap_bolt`. There are
eighty-six now, every one named for its breed and owned by exactly one: three
to five a shooter across at least two kinds, a thrown opener apiece for the
four riders, and a volley shot for each of the twelve bosses
(`EnemyData.volley_shot_id`), all generated from one table
(`shots_data.py` in the session's scratch, recorded here because the *choices*
are what matter: a region's palette, a head that is the thing thrown).

**What makes them look their own is drawn, never flown.** `EnemyShotData`
carries a `head` - orb, dart, shard, stone, skull, leaf, bola, flame, ring,
bell, gear, or the rune every shot used to be - with a size, a spin, a sway
off the path, a trail weight and a pace; `EnemyProjectile._draw` paints the
head on the drawing's own transform, so a shot that sways still hits exactly
where it flies, and `_land_the_look` dresses the landing by the head (a stone
throws dust, a flame its embers upward, a shard shatters into slivers, a skull
leaves slow dark wisps). **The bound is the tower shots' bound in the other
direction: a look is never a fact.** The blow is the same blow, and `pace` is
bounded either side of one as the hex already was - slower is more dodgeable
and faster less, which is the shape of a blow and not its size.

**The systematic walk the owner asked for is `enemy_shot_check`
(894 checks).** Every shot every breed owns - its repertoire, its opener, its
volley - is thrown for real by a body of that breed through the same dispatch
the fight uses (`Enemy.loose_named_shot`, the documented seam) at a hero with
a known pool and then at the wall, and the damage is read back: something
lands, never more than the strike, and the wall is hurt by whatever is aimed
at it. Thirty-five breeds, eighty-six shots. It also holds the ownership -
named for the breed, owned once, a shooter with fewer than three or of one
kind, two of a breed's own shots that look alike, a boss volleying in the
plain rune - and `enemy_repertoire_check`'s "every shot a colour apart from
every other" was **amended deliberately**: that held twelve shared files and
cannot hold eighty-six, so what it holds now is that a breed's *own* shots
never look alike, and two breeds a region apart may fairly fly the same ember.

**Three harness faults came out of the walk and each is one this project has
met before.** A live body picks its own target every tick and walks its route,
so each breed's first shot landed and every later one was thrown at the town
from wherever the body had walked - sixteen "silent duds" that were the
harness measuring a body that had changed its mind; the probe is held still and
re-aimed before every shot. Headless runs far above sixty frames a second, so
"240 frames" was under a second of game time and a slow hex could not cross
180 units in it; the waits are in seconds. And a fan's other two pellets landed
during the *next* shot's measurement, which then "took 500 from a strike of
300"; the air is settled between shots.

**And a partner's screen wears the same head.** The strike fact carries the
shot's name now (`enemy_struck` and `Fact.ENEMY_STRUCK` grew a third element,
read off this machine's own content on arrival), so a guest's mirror of a
Fog Lantern throws a lantern and never the roster's plain rune; the picture is
a bolt whatever the kind, because a guest resolves no ground blow.
`shots_shot` photographs the twelve heads on a plate, and the first plate had
seven of them standing off it - a shot configured before it had a parent took
its local origin for a global one - which is the same coordinate mistake the
tail probe made an hour earlier, in a third costume.

**The VFX forge is built, and it made one effect, as of 2026-09-21.** Owner:
"If you are able to use the blender method outlined in the docs/VFX_FORGE.md
to make the sprite sheets for our juiciest vfx and bring them into our game
and integrate everything". `tools/vfx_forge/forge.py` drives Blender 4.5
headless through `render.py`: one plane under an orthographic camera and one
material that is the whole effect - the document's five nodes, a frame turned
into an age, a radial coordinate, noise through a hard threshold, a swirl
toward the middle, emission whose alpha is the mask - rendered frame by frame
on a transparent film and packed into one row. **The pilot §5 asked for and
no more**: the burst, sixteen cells of 96, white on transparent, at the enemy
shot impact, the boss slam and the tower shot impact through `Vfx.forge_burst`,
tinted once per use so one sheet serves every element.

**The line the document draws is kept.** A sheet is drawn where an effect's
size is decoration; every telegraph is still drawn at the blow's own radius,
and the forged shock at a slam is laid at the radius the ring already promised
- never a second reach. `forge_check` holds the sheet at its declared size
with lit cells that fray away, a player that frees itself and draws nothing
at a density of zero, and the three call sites; `forge_shot` photographs it
beside the painted burst, which is the only judgement §5 allows. Read on the
plate: the painted burst is a star and the forged one is a ring with a swirl
in it, both hard-edged and flat-lit, and under the sparks and the flash it
joins it reads as a wave leaving the blow rather than as a second game. More
effects are a file each in `render.py` (the eligible list is §3); none was
bought beyond the pilot.

**Two things about Blender worth keeping.** `Standard` view transform, or a
white emission renders the grey AgX invents and the game's tint lands on
that; and a keyframed Value node is the clock, because a driver needs the
expression sandbox and a keyframe needs nothing.

**A gate on neither bar, found 2026-09-22 by the same diff that finds the
splits.** `resource_reach_check` - every authored resource field is read by
something or written down as not, the data-layer twin of
`balance_reach_check` - had a `.tscn`, a commit, and no line in either
workflow, so it could fail nothing. Run by hand it was red: the Walk's stop
data authored `opens`, "the gate this stop unbars", on all eighteen stops as
`""`, and nothing read it. Deleted rather than wired, because every stop left
it empty and the Walk gates its stops by order. The gate is on both bars now.
The diff worth running before every tag is three lines, and the third is the
one this found:

    comm -23 guard release   # in guard only
    comm -13 guard release   # in release only
    comm -23 all-gates release   # on neither - the network gates by design, and this

**Equipped gear is named rather than numbered, as of 2026-09-22.** Owner:
*"breaking or selling or picking up new items can cause equipped gear to get
unequipped"*. `MetaState.equipped` mapped a slot to a stash **index**, and an
index moves whenever anything leaves the stash or it is re-ordered - so every
one of those doors had to re-derive the whole map by hand, and a door that
forgot re-equipped a different sword in silence. `drop_gear`'s own comment had
said so for months: *"it silently re-equips a different sword"*.

**It keys by the piece's own `uid` now**, which is the one thing a piece keeps
across a removal, a sort and a trade, and is why the uid exists. The shifting
problem does not exist to be got wrong: `drop_gear` and `sort_stash` are each
four lines shorter, and `equipped_index`, `is_equipped_index` and `equip` are
the three doors every screen asks through - none of them knows how the map is
keyed. A save written before this holds positions; a stored value that is a
real uid is read as one and anything else is converted once, so `SAVE_VERSION`
did not move.

**One gate's invariant was amended and it is recorded.** `release_repair_check`
asked that a *scrambled* map still recover the right piece for a slot, because
the old `equipped_piece` searched the other worn entries for something of the
right kind. Keyed by uid it refuses instead and the slot reads empty, which
answers the same question - can a scrambled map dress the Warden in another
slot's gear - more strongly than recovery did. Six harnesses that wrote
`equipped[slot] = index` were amended, which is a harness change and not an
invariant one.

**And the lowest rarity is Rough.** A rarity called *Worn* beside gear that is
*being worn*, under a button that breaks "all Worn" and breaks neither, is one
word doing two opposite jobs - the owner's words: *"it does not add up"*. The
equipped state is called **Equipped** in every screen, the stash row says so,
and `trade_check` has refused the word "Worn" on an equipped row since the
trade window was built.

**The ability slots say which boss opens them, as of the same date.** Owner:
*"Power ability for the 3rd slot is still locked until after the Act 2 Boss but
it should become available after the Act 1 Boss"*. **The gate was already
right** - Power opens in Act II, which is after the Act I boss - and the label
was not: the Mansion carried its own copy of the rule (`slot < 2 or act >=
slot`) and printed *"unlocks after the Act 2 boss"* for a slot that opens after
the Act one boss. The owner read the label. `DisciplineNodeData.slot_is_unlocked`
is the one rule now and `slot_opens_after_boss` is what the copy names, in
roman numerals like every other act on screen. **Recorded because the fix is a
sentence rather than a number**, and a session that had trusted the report over
the code would have moved a gate that was correct.

**A breed throws its own shot at the wall, as of the same date.** Owner: *"they
do not use their unique projectiles but seem to all attack the base using the
same projectile"*. True, and one line: `_loose_a_shot` fell back to `BOLT`
*and* to no painting when the target was not a person, so every breed in the
game threw the roster's plain unpainted rune at the gate. The **kind** still
falls back - an area blow resolves on heroes and their spirits alone, so a
mortar aimed at the gate would hit nothing and a siege breed would stop being
able to besiege - and the **look** no longer does.

**The winded breath is not the hurt cry, as of the same date.** Spending a pool
is not taking a blow, and `_give_out` played `sfx_hero_hurt`; a game that says
the same thing for both has taught the player to ignore the one that matters.

**The hundredth level is a season, as of the same date.** Owner: *"the
perpetual player level should not accumulate xp so quickly ... a longer process
similar to the Diablo series but tuned for our game"*. They reached the cap in
about a hundred runs. The ladder was 480,000 XP and is **1.52 billion**:
`HERO_XP_CURVE` is **3.5** and `HERO_XP_BASE` **7.0**, so the exponent carries
the whole change and the base is within a rounding error of where it started.

**This paragraph said 2.40 million until later the same day, and every figure
in it was honest arithmetic about a game nobody plays.** The first cut was
tuned against `tools/level_curve.gd`, which hard-coded ten waves an act over
ten acts - a hundred waves and two and a half hours - against a real campaign
of **819 waves and about 12.7 hours**. The same tool printed each tier's
`xp_scale` beside a walk that never applied it, so Nightmare was modelled at
42% of what it pays and Hell at 20%. Between them the road pays some fifty
times what the tool believed. Measured against the corrected model, the
"season" ladder was **one Normal campaign, capping in Act VII of eleven** -
four acts with nothing left to earn, and eight further campaigns worth nothing
at all. Recorded rather than quietly overwritten, for the reason the
starting-gold paragraph was: this file is the first thing every session reads,
and the most convincing kind of wrong is a number correctly derived from a
broken model.

**The tiers are the specification, and nobody had been reading them.** Each
declares the level its own bosses expect, and the curve is solved into those
bands rather than into a figure anyone chose:

| | reached | the tier's own bosses expect |
|---|---|---|
| one Normal clear | 34 | 30 at Normal's last |
| three Normal clears | 44 | 45 at Nightmare's first |
| the Nightmare tier | 70 | 70 at Nightmare's last |
| two Hell clears | 95 | 94 at Hell's last |
| three Hell clears | **100** | — |

So the hundredth level spans all three difficulties and is earned in Hell,
which is what the ascension ladder and the Hell gear are for.

**What it costs is the middle of the opening, and that is arithmetic rather
than a preference.** The first level still arrives on the first wave - leaving
level 1 costs 7 XP and wave 1 pays 24 - and level 5 lands on wave 13. But
level 10 moves from wave 15 to **wave 74**, the middle of Act II. A road whose
income climbs eight hundredfold from first wave to last pays only **a tenth of
a percent** of a campaign's XP in Act I, so no ladder long enough to span nine
campaigns puts level 10 inside it. The exponent was pushed as high as the far
end tolerates for exactly this reason - a steeper curve makes the low levels
*cheaper* relative to the top - and past about 3.6 the top stops being
reachable at all: at 4.0 three whole Hell campaigns reach only 87. 3.5 is the
corner of that trade, not a round number that looked nice.

**And `balance_test` had two enormous awards typed into it**, 50,000 and
50,000,000, which were obviously enormous against 2.4 million and are a tenth
of one level against 1.52 billion. The gate duly reported the level cap as
broken when what was stale was its own arithmetic. Both are read off
`RunState.hero_xp_for_level` now, so the next re-tune cannot break them - the
invariants (one award crosses every level it earns, the cap is a ceiling) never
moved, and a harness that encodes today's numbers is a harness that fails on
tomorrow's. Checked by making one award resolve a single level, which the gate
named.

**The tail, eleventh report, and the answer was the distribution and where the
limb hangs, as of 2026-09-22.** The owner sent a two-scope crop with the fault
circled in their own words: *"the tail attachment is lighter than the body
segment and has less contrast and grading and tinting"*. Three things had to be
true at once and each earlier pass had only one of them.

**A gain cannot add moss.** The pass before this matched the tail's *mean* to
the stub's with one per-channel multiplier. A multiplier moves a distribution;
it cannot give a bare limb the body's green moss cast or its near-black
crevices, and those are most of what the eye is comparing. `match_tail_palette.py`
- the histogram match written for exactly this and partly undone since - maps
the tail's per-channel distribution onto the hide's with the ink held out, and
brings the moss and the dark end with it. `grade_tail_to_stub.py` is retired:
two tools claiming one job is how one of them ends up wrong.

**And a limb is compared with the part of the body it hangs beside.** The
Worldstrider's back is pale plated stone and its haunch and belly are deep
shadow under hanging vine; the tail leaves the haunch and hangs at the height
of the belly, so matching it to the animal's *average* leaves it visibly pale.
`seat_tail_in_shadow.py` grades it into that shadow, hardest at the root,
easing to the tip, luminance only.

**The mechanism was never the fault, and that is now provable rather than
argued.** `beast_shot --force-grade` paints the body a colour nothing else in
the scene is: with the body forced red the tail comes back exactly as red, so
the grade reaches the limb through the parent's `modulate` and always did.
Eleven passes argued about that chain from one property at a time;
`TailProbe.say_the_chain` prints every `modulate`, `self_modulate` and material
up the tree, which is the reading that would have ended it.

**Two gate invariants were amended and both are recorded in the file.** The
root is held *below* the stub in a band rather than matched to it, and the
whole limb likewise - a distribution carrying the hide's share of near-black
measures darker than one without, which is the point of having it.

**The lesson, and it is the one this project keeps paying for.** Every pass
before this measured a statistic and reported success; the owner rejected the
claim four times. What settled it was a magnified crop of the render beside
the owner's own screenshot, and then handing the pictures back rather than the
conclusion. **When a report and a measurement disagree more than twice, stop
measuring and start showing.**

**The forge is a catalogue, a window, and twenty-four effects in the game, as
of 2026-09-22.** The owner asked for *"not just a few forge vfx sheets ... a
great amount of the best varieties and polish for all that we can make ...
give them variations and make several takes of sheets for each one and use
each randomly and also maybe flip them randomly ... and give them random
rotations when spawned"*, with hit effects per element, and for the whole
thing to become *"a full standalone app ... with an aesthetically appealing
smart dark mode fully featured GUI so that I can also try previewing the shots
and rendering sprite sheets within our app"*.

**An effect is a file now**, which is working rule 3 applied to art. The pilot
wrote its one effect as a branch inside `render.py` - right for one and wrong
for thirty, because two people cannot author two effects in one `if/elif`.
`forge_kit.py` holds the scene and the shapes (`grow`, `band`, `lobes`,
`grain`, `squashed`, `rise`, `phase`...), `effects/<id>.py` declares a `SPEC`
and a `build(f)`, and `forge.py` discovers the folder. Eighty-five sheets
across twenty-four effects.

**One door, and the variety is at the door rather than in the files.**
`Vfx.forge_play` picks a take at random, turns the sheet, flips it, and
wanders its size - so a road of forty impacts is forty pictures rather than
one stamped forty times. **Which axis may be flipped is derived from how the
sheet may be turned**, never authored beside it: two columns saying one thing
is two chances to disagree, and what is safe follows from what carries the
meaning. A radial sheet spins and flips either way; one that knows where the
ground is never turns and mirrors left to right; one drawn along a direction
is laid on the aim it is given and mirrors top to bottom.

**And the cell count is read off the sheet.** A row of squares is as many
cells as its width over its height, so an effect re-rendered at a different
length simply is that length - there is no number in the game to drift out of
step with the file, which is a fault this project has paid for twice.

**The bound has not moved**: a sheet is decoration. Scaled away by
`Graphics.particle_scale`, damped by `JuiceDirector` as COSMETIC, drawn on its
own dice rather than the run's stream, and read by nothing. And the line
`VFX_FORGE.md` §3 draws still holds - **a telegraph is drawn at the blow's own
radius and stays procedural**, so the warning and the damage cannot disagree.
Every sheet laid where a telegraph already promised something is laid at that
same number.

**Every element has a hit and it behaves the way that element does** - fire
flares upward and dies, water splashes into a ring of droplets, earth throws
chunks, air is a ring leaving, steel is a hard star. They are played from
`Vfx.impact`, which is the one place that already knows which element landed,
so the thirty call sites that deal an elemental blow needed no edit at all.

**`forge_check` went from 3 ways to be a lie to 687 checks**, and two of them
are the ones no person can do. **Every sheet on disk must be an effect the
catalogue names** - a file that ships, was paid for in render time, and can
never be played is the `DisciplineEffects` lie in the art layer - and **every
effect must be played by something**, read off the source with the two
catalogue literals cut out so a row cannot name itself. Four faults were
planted and all four named: an upright sheet spun, a call site removed, a take
that is pixel-for-pixel another take, and a sheet with no effect.

Three of its own checks were wrong first and each is a shape worth knowing.
A cell size held against one effect's 96 failed nine honest sheets rendered at
64 and 128 - **an effect declares its own size, so what is worth holding is
that the cells are square**. An "is this cell empty" bar held as an absolute
count failed at 64 for the same reason, and is a share of the cell now. And
comparing takes by their **lit-pixel total** failed three honest ones for
colliding on a single integer; comparing the pixels catches exactly the
failure the check is for - a seed that reaches nothing downstream - with no
false positives.

**Two effects were rebuilt because a photograph said so and no number did.**
`funnel_debris` was drawn entirely on the radial coordinate, which is a plan
view, so however it was chopped it came out a wheel of dashes; it is a stack
of five ellipses now, rising and widening, which is what a funnel is from a
camera that looks down and slightly along. `meteor_bloom` scaled its dome's
`y` *up*, making it wider than it was tall, and over an even flatter skirt the
pair read as an eye; the dome is taller than wide now and fire leaves the top
of it. Both were found on a contact sheet of all twenty-four and by nothing
else, which is the rule §5 of `VFX_FORGE.md` set before the tool was built.

**The window is `forge_app/`**, its own Godot project beside the launcher and
for the launcher's reason: it ships to nobody and must not be able to break
the game by existing. It lists the catalogue by asking the forge, renders
without freezing, and **plays the result the way the game will** - tinted,
additive, at `Balance.VFX_FORGE_FRAME_RATE`, over a plate the colour of the
road, with a contact strip of every cell under it. That last part is the whole
reason it exists: a lit-pixel count says nothing about what an effect looks
like moving, and a tool that renders a sheet and cannot show it playing is a
slower command line. Its theme is derived in code from three colours, so
changing the app's mood is changing three values rather than forty boxes.

Three faults in that window are the same fault in three costumes, and all
three were found by photographing it. A status label that wraps by default,
given no width in a row with an expanding spacer, wrapped to **one character a
line** and made the header four hundred pixels tall. Clipping it then
truncated it to nothing. And a contact strip anchored to its panel came out
1372 pixels wide in an 830-pixel one, because **`Control.size` is clamped to a
container's combined minimum** - so the share each cell may have is worked out
first and becomes its minimum.

**A menu button played its sound twice, as of the same date.** The owner
reported the menu's random sounds as too loud. Both `Sfx` and `UiSound` hooked
every button in the game on `node_added` - each guarding against its own
handler and neither knowing about the other - so a hover played at
`UiSound.HOVER_DB` *and* at zero, and a click likewise. A menu is nothing but
buttons, which is why it was heard there first. `UiSound` was already the
complete answer and has the better rule besides (a disabled button does not
answer the cursor), so the fix is a deletion; the levels moved into `Sfx.MIX`,
where a level belongs, because a level at a call site is a level the next call
site does not know about.

**The earth's wave comes from a place and travels, as of 2026-09-22.** The
owner: the ground-wave disaster was *"a low quality and unaesthetically
appealing and low game juice starting solution that needs to be made ready
for production ready release with better vfx and game juice and appeal and
game play mechanics"*. Every word of that was earned, and **the worst of it
was not the picture**.

**An earthquake was one number, everywhere, on one frame.** Every hero, every
enemy, every tower and every animal on the field took their share at the
instant it broke, through a filter reading `func(_where): return true`. There
was nowhere to be, nothing arriving and nothing to read. The only thing on
screen was a camera shake, three dust puffs near whoever was watching, and a
fault crack stamped at a point drawn from a stream nobody had watched - so the
crack in the ground had no relationship to anything that had happened.

**`GroundWave` is the answer and it is a gameplay change first.** The ground
splits at an epicentre, the split is shown while the earth hums, and one to
three crests roll outward across the whole field at `QUAKE_WAVE_SPEED`. A body
is struck **once per ring, as the front reaches it** - so the blow arrives from
somewhere, and where you are standing when it does is a decision.

**The bound is that a wave may only ever be gentler than the old number was,
never harder.** Each crest carries the old total divided by the crest count and
every crest reaches *past* the far corner of the grid, so anything that does
not move - every tower, most of the road - takes exactly what it always took.
What reading it buys a Warden is the crests they step out of and nothing else:
no crest strikes twice, none strikes harder than its share, and the sum is
fixed before the first one is born. That is what lets `curve_report` still be
read against the same numbers, and it is why the shove a crest gives is a
`Hero.shove` rather than a stun - the player keeps control of a body that is
briefly sliding.

**The epicentre is an argument now, not a private variable**, with
`Vector2.INF` meaning "pick one" - the origin could not be the sentinel because
the origin is the town and a quake under the town is a legal quake.
`warn_quake` picks the place and hums *there*, so the telegraph says where as
well as when; a telegraph that says only when is half a telegraph. And the
fault the quake leaves is laid along the first crest's own front at the
distance it was strongest, which is ground the player watched open.

**The ground itself bends.** `quake_ripple.gdshader` is `flood_sheen`'s
technique put to the other use: it reads the frame beneath it and displaces it
by up to three travelling rings, so the earth swells in front of a crest and
dips behind it. Never headless, where there is no frame to copy, and
`Graphics.KEY_WATER_REFRACTION` turns it off at the same cost as the flood's.

**The crest was drawn four times and every reading is worth keeping**, because
all four are the same lesson in different clothes. At the fissure's own alphas
it was a pale hairline nobody could see from the distance a quake is actually
watched. Drawn solid and bright it became an enormous flat donut laid over the
field - one colour all the way through, which is the failure the forge's first
flame had. Drawn as broken polylines it read as a ring of fence panels, because
a polyline has one width and two flat ends. What earth breaking looks like is
**slabs with gaps between them**, each tapering to a point at both ends and
ragged along its outer edge, each on its own radius - so a piece is a polygon
now, and `QUAKE_CREST_FILL` being under one is as much of the look as anything
that is drawn.

**And the diagnostic was a coin toss for two of those runs.** `sky_shot` called
`quake(1.0)` with no patterns named, and `quake()` with nothing selected draws
its patterns from the wrath - so whether there was a ground wave at all was a
roll. Two runs in a row photographed a wave and then an empty field. It names
`["quake"]` now. **That is the sixth time this project has shipped a check
whose verdict was a coin toss**, and the answer is the same every time: a
diagnostic that cannot be trusted either way is worse than none.

**Three gate amendments are recorded rather than quiet**, and all three are
harness changes rather than invariants. `wrath_check` read the health back on
the line after `quake()`, which was a fair question when a quake was an
instant and is not one now; it waits out the crests. Its probe was then shot
dead by a tower during that wait and the gate read that as a wave that struck
nobody - **the probe-that-dies-mid-measurement lesson, again**, answered with
a pool nothing on the field can empty. And `_the_wave` was handing back the
*previous* test's wave, because a crest crosses the whole grid and takes longer
than the test before it waits.

What is new as an invariant is `_test_the_wave_travels`: the wave breaks where
it was told to, a body that does not move is struck, and a body that steps out
of the crests takes less than one that does not. Planted the old instantaneous
blow and the gate named it - *"stepping out of the crests bought nothing"*.

**And the other earth patterns break the same way.** The fissure and the
trail were a translucent bar with two hard straight edges for a warning and
three polylines for a split - photographed by `sky_shot`, where two of them
crossing the field came out as a pair of gold rectangles. They are drawn in
the language the crest settled on now: the warning is hairline cracks
reaching out from the line and a dark seam growing along it, never a filled
bar, because a translucent rectangle over grass is the one shape that reads
as a user interface rather than as earth; and the split is slabs either side
of that seam. **The breath is untouched** - it is a cone of fire rather than
earth and is the one mode there that is not a crack.

**Each aftershock is heard from where it left.** The break itself keeps its
flat `sfx_quake`, which is an announcement and belongs everywhere at once; a
later crest is a thing happening at a place, so it is quieter and goes
through `play_at`, which attenuates by distance from what the camera is
watching.

**Nothing new persists and nothing new is a power scale.** The wave is
run-scoped and dies with its last crest; `EventBus.earthquake` grew the
epicentre and the crest count so a guest draws the same wave in the same place,
and a guest's copy hurts nobody. The relay tolerates a two-argument fact from a
build that predates this, which reads as one crest at the middle of the field -
exactly what that build drew.

**A partner never came back from a raid, found 2026-09-22.** `Battlefield.suspend`
takes every hero on the field out of the world so nothing walks over one while
the scope is frozen - the rule added when wildlife mauled a hero standing at a
suspended scope's origin. **`resume` put back only the local hero.**

So in co-op a partner was removed from `GROUP_ANY` by the first raid, rift or
crossroad and never returned to it, for the rest of the run. Nothing errors and
nothing looks broken: an absent hero is simply something no body targets, no
revive finds and no tower defends, and what the player sees is a partner who
has quietly stopped being part of the fight.

**Remembered rather than recomputed.** `suspend` keeps the ids of exactly the
heroes it took out and `resume` puts back exactly those - the party may have
changed while the scope was frozen, and putting back somebody who was already
away is the same fault pointing the other way. The one case where absence
outlives a suspend is a hero away on an event of its own (`set_hero_away`),
which is checked by name.

Found by reading the two functions beside each other rather than by anything
failing, which is the argument for a restore living next to the thing it
restores. `coop_heroes_check` drives the real `suspend` and `resume` - a test
that called `set_present` by hand would pass with the omission still in place -
and the planted original named it twice.

**Several Wardens on one machine, and the first of them is the file that was
already there, as of 2026-09-22.** The owner: *"save slots per profile are
desirable."*

**A slot is an ordinary save in the ordinary format, in a file of its own.**
There is no second schema, no new save key, no migration and no
`SAVE_VERSION` bump - because a slot is not a new *kind* of thing to persist.
It is the same account written somewhere else, so working rule 7's list is
exactly what it was and `balance_test`'s top-level allowlist is untouched.

**The bound is one sentence: slot 0 is `MetaState.SAVE_PATH` itself, by name
and byte for byte.** A player's save is the one thing in this project git
cannot restore, so slots were built to *add* files rather than to move one: an
existing account **is** slot 0 by derivation, the first launch after this reads
exactly the file the last launch before it wrote, and nothing is renamed,
copied or migrated to make that true. The same reasoning pins the user
directory one level up, and it fails the same way if it is ever got wrong - no
error, no warning, a fresh account on the menu.

Slot 1 onward is `beast_road_save_1.json` and so on, and **every name in the
family comes out of one derivation**: `slot_path` for the save,
`slot_backup_path` and `slot_unreadable_path` for the two backups, which on
slot 0 resolve to the historic names players' disks already carry. The
version-backup rule - one copy per version, never overwritten, the first copy
is the valuable one - now holds **per slot**, because two Wardens hitting the
same mismatch are two files worth keeping.

**Which slot is active lives outside every slot**, in `beast_road_save.slot`.
A pointer written *into* a save would be a fact about the machine living in a
file that belongs to one Warden, so switching would have to write two files to
stay consistent and a half-written pair would open the wrong account. **Missing,
empty, truncated, not an object or out of range all mean slot 0** - which is
what every player who has never seen this feature has, and they must land on
the historic save and notice nothing at all.

**Out of range is malformed rather than clampable, and `save_slot_check` caught
that on its first run.** The first cut clamped the pointer into range, so a file
naming slot 999 - written by a build with more slots, or edited by hand - opened
the *last* slot and quietly handed the player somebody else's Warden instead of
the save they had.

**A slot may only change between runs**, which is `pen_take`'s rule and a
sharper version of its reasoning: a road is banked at a crossroad, so switching
Warden mid-run abandons a front the player never chose to give up - silently,
because the other slot's menu looks entirely ordinary afterwards. `use_slot` and
`erase_slot` both refuse outside `Phase.ENDED`, and both refuse while saves are
held, since switching is a write by definition and a gate's scratch account must
never be the thing that lands in a slot.

**Resetting a slot is `adopt_save({})` rather than a list of fields**, and that
is load bearing. Every `_read_*` helper clears before it reads, so an empty save
*is* the empty account - by construction, for whatever the save carries today
and whatever is added to it next. A hand-written list would be a second opinion
about what a slot contains, and the first block somebody forgot to add to it
would leak one Warden's pen, stable or pantry into the next one. The code is
written so that cannot happen rather than merely checked for.

**Preferences carry across and three "settings" do not.** Volume, display mode
and key bindings are facts about the person and the machine; wiping somebody's
bindings because they made a second Warden would be a second, unasked-for
destruction. But the starting weapon, the tutorial and the milestone cinematics
are *account progress wearing a preference's clothes* - without clearing them a
second Warden begins unarmed and untaught. `_clear_account_progress_settings`
is the one owner of that list, shared with `erase_progress` so the two cannot
drift.

**The picker is on the front door rather than in the Hold**, deliberately,
though every other account door moved into the room in 2026-09-11. The Hold is a
room *this* Warden owns - their stash, their pen, their forge - so choosing
which Warden to be from inside it is the wrong way round. **Erase is not offered
for the first slot**: throwing that account away is `Erase progress` in
Settings, a different door with its own confirmation that does not leave the
game pointing at a file it has just deleted.

**`save_slot_check` (117 checks) drives the real doors through a documented
seam.** `MetaState.slot_root` is `SAVE_PATH` in a shipping game and is moved to
a fixture by that gate alone - so the doors under test are the real `use_slot`,
`erase_slot`, `load_save` and `save_game`, and a developer's own Wardens are not
merely protected by the save hold, they are not on any path the gate can reach.
Ten faults were planted and all ten named, including the one a driven test
cannot see: **a source walk over `MetaState.gd` holding that no shipping path
names a save outside the derivation**, because a call site left on a fixed path
writes one Warden over another's file while every other check stays green.

**And the new-account check passed vacuously at first**, for the reason this
project has recorded before: a CI profile *is* a new account, so switching away
from it reads "new" whether or not anything resets. The Warden being left is
made a played one first.

**Towers take less of everything, and everything on the board now shoots, as
of 2026-09-22.** The owner: *"reduce the amount of damage that towers take
from natural disasters. Tornadoes especially do too much damage to towers and
need tower damage nerfed. Towers should take less damage from all sources and
everything needs to be balanced"*, and *"all towers need to deal some kind of
damage ... except for the healing well"*.

**The tornado complaint was right by a wide margin, and the arithmetic is
worth keeping.** `TORNADO_TOWER_DPS` was 700 flat, with no act scaling and no
falloff inside the wake. A funnel crosses its own 84-unit wake in 1.4 seconds,
so **a single straight pass delivered 980 damage** - more than every tower in
the roster holds except the Bastion. A funnel therefore deleted every
emplacement on the road it crossed, in a second and a half, and the player
could neither see it coming nor answer it. The meteor was the same shape
quieter: `METEOR_TOWER_DAMAGE` was 520, which is exactly `TOWER_BASE_MAX_HP`,
so a stone that **deliberately hunts towers** one-shot any of them that had not
authored a bigger pool.

**The nerf is one scale and two constants.** The scale is
`TOWER_DAMAGE_TAKEN_SCALE`, applied as `Health.damage_scale` on the tower
rather than inside `Tower.hurt` - and that is the whole reason it answers the
ask. `hurt()` is the *world's* door: the tornado, the meteor, the ground wave
and the earth's cracks. **Enemy melee and enemy shots bypass it entirely**,
reaching `Health.take_damage` directly, so a multiplier in `hurt()` would have
answered "less from all sources" by covering four of the six. It sits after
the flat armour and its twenty-percent floor, so a Bastion's plate and this
compound the way a hero's armour and Resolve do.

**And the tornado's invariant was amended, which is recorded rather than done
quietly.** `wrath_check` asserted *"the funnel walked over a tower and left it
standing"* - which required at least 436 tower DPS and is *why* the constant
was 700. A gate can hold a fault in place; this one did. What replaces it
holds **both** ends, which the old one did not: a straight pass must hurt the
tower and must **not** fell it, and a funnel **parked** on one must fell it
inside twelve seconds. So the nerf cannot be undone by raising the constant
back, and it cannot be taken further either. Planted the original pair - 700
DPS and no scale - and the gate named it.

**Every tower deals damage now, and the silence was in the code rather than in
the data.** `Tower._process` read `if data.is_support(): _tick_support(delta);
return`, an unconditional return that sat *before* the wind-up, the cooldown,
`_acquire_targets` and `_fire`. So authoring `damage` on a Bellows Forge did
nothing at all: four of the forty-two towers could not shoot whatever their
resource said. The return is conditional on the damage now, so a support
authored with none is still silent by construction and nothing further down the
firing path had to learn that supports exist.

**The reason the old assertion existed is kept as a ceiling.** A Bellows Forge
that out-shoots an Ashen Censer is not a support, it is a gun that also helps -
so `TOWER_SUPPORT_DAMAGE_SHARE` bounds a support at 62% of the weakest pure
gun in its own role, and `tower_support_check` **measures that floor off the
roster** rather than reading a number, so the bound moves when the roster does.
The four land at 3.3 to 3.6 dps against an Ember Spire's 26.7. Both ends are
planted and named: a support with no damage, and one firing at 16.7.

**The well is untouched**, which the owner exempted and which two gates already
require - `healing_well_check` says *"a well that also shoots is a gun"* in as
many words, and a well is gated one branch further down by `is_well()`.

**Ten towers an element, as of the same date.** The owner asked for ten types
per element; there were eight. The eight new ones are two a side, each filling
the role that element was thinnest in and **each a combination the roster did
not have** rather than a bigger number - which is the rule the 2026-09-11 batch
was authored under and the only thing that makes a tenth tower worth meeting.

Fire had no chain and nothing that left fire on the ground: the **Sear Coil**
and the **Kindler's Eye**. Water had no spray and no freeze worth building
for: the **Brinespitter** and **Frostpoint**. Earth left nothing behind and
pierced nothing: the **Fissure Drum** and the **Granite Ballista**. Air had no
shell of its own and nothing that held a lane: the **Downburst** and the
**Lodestone Mast**, which is the first air tower that taunts and the first that
grants lane armour.

**`Balance.TOWERS_PER_ELEMENT` is the count and the gate reads it.** The
assertion was a literal eight, walked over all four elements - so the roster
could not drift to nine of one and eleven of another, which is what "ten types
each" means and is not something a total would catch. It has now had to move
twice, so it is a named number rather than a figure typed into a gate.

**Two harnesses had to learn about the scale and neither invariant moved.**
`structure_check` hurt a tower by `max_hp * 0.58` and then asserted it was
burning, which is a statement about the *ratio* wearing a damage figure's
clothes; it drives the tower down to the ratio it is asking about now.

**And `tower_juice_check` failed for a reason that had nothing to do with
towers.** It reported two of the five shot styles as not landing - one tower
"would not fire at a body in reach" standing 322 units away with a range of
402. What had actually happened is that **the town fell in the middle of the
fourth round**: five rounds of up to twelve hundred frames each is minutes of
game time on a live road, a body reached the gate, the run settled, the
battlefield suspended itself, and the last two towers were measured on a
frozen field.

It took six bisections to find, and every one of them pointed at the wrong
thing - the knockback, the ambient air, the shot style, the sell, the crowd
grid. What found it was **printing the state** rather than reasoning about it:
one line carrying the phase, the suspend flag and the neighbour count said
`phase=5 susp=true`, and `run_ended`'s own summary then named the blow. The
first culprit that trace named was a *badger* - `last_blow` read "Badger for
10" - which was a second, independent way for the same gate to die, and was
also real.

**The gate had been one authored tower away from this since the day it was
written.** Nothing about the eight new towers is wrong; adding a tenth tower
to each element moved which tower the lob style picks, which shifted the
timing by a second or two. `floor_hp` holds the town at half for the gate's
duration now, which is the door the homecoming withdrawal and
`enemy_siege_check` already use - and the gate checks its own sell and clears
the air between rounds, because rounds that share a field must not share
anything else.

**The trap menu is ten offers that fit on the screen, as of 2026-09-22.** The
owner's report: traps need *"1 more option to total 10"*, the Iron Hoarding and
the Stake Line *"do not have the full tooltips on hover like the rest of the
traps"*, and the whole menu *"needs to be bottom right anchored without
overlapping the bottom or right UIs. It's currently top right anchored seemingly
and overlapping the spirit companion UI."*

**It was already bottom-right anchored, and the report was still exactly
right.** The road sheet hangs from the bottom right and grows *upward*, the
same as the build sheet - and unlike the build sheet it had no ceiling and no
fit function at all. Ten rows pushed its top edge to about y=136 against a
right-column floor near 206, so it grew straight through the spirit readout,
whose Call button is `MOUSE_FILTER_STOP` and stopped taking clicks. "Top right
anchored" is what a sheet growing past the top of its room looks like from the
outside.

**`_fit_right_sheet` is one function and both sheets call it.** Two copies of a
layout rule is how one of them ends up wrong, and this is the case: three
functions re-fitted the build sheet when the screen or the column's floor moved
- `_refit_banners`, `_refit_right_column` and the touch pass - and not one of
them named the road sheet. The road sheet has a `ScrollContainer` now as well,
so a list too long for the screen scrolls rather than growing off it.

**The tenth offer is the eighth trap: the Caltrop Drift.** Eight traps and the
two barricades are the ten rows the menu lists. What makes it distinct is
**reach**: 280 units against the 150 the widest trap managed, for the weakest
bite in the set, plus a short stumble rather than a stop. Every other trap
answers a place; this one answers a *stretch*. `TrapData` needed no new field,
which is working rule 3 doing its job - the trap is a file.

**And it carries a Gold price on purpose.** The obvious way to make it distinct
was to price it in Wood alone, the way the Stake Line is - and that would
quietly have re-cut the opening envelope. `STARTING_WOOD` is 180 and
`STARTING_GOLD` is 0, and the reasoning above the Gold constant is that zero
Gold means zero towers *because every tower carries a Gold price*. A Wood-only
defence makes Wood into tower capital by a side door and hands the player a
laid road on the opening frame, which is the one thing §448's teaching
obligation is protecting. If a Gold-free trap is ever wanted, that is a
decision about the opening rather than a price.

**The barricades' tooltips were a call site, not data.** `_add_road_row` takes
a picture and a figures block as optional arguments; the trap loop passed both
and the barricade loop passed neither, so the two walls showed a bare sentence
and no image beside seven traps showing a picture and five lines of numbers.
`BarricadeData` has carried `max_hp`, `slow_factor` and a working
`get_sprite_path` since it was written and both sprites are on disk. What was
missing is `_barricade_tooltip` and two arguments. **An argument that defaults
to empty is the shape of omission nothing can see** - not a type checker, not a
layout measurement, not `asset_report` - which is why the gate drives the row's
own `mouse_entered` rather than calling the builder.

The Raise row had a smaller version of the same fault: it promised "Level %d:
harder, wider" and quoted the trap's *level-one* numbers as its figures.
`_trap_tooltip` takes the level being bought now.

**Three faults were found by opening the sheets rather than by reading them,
and every one was invisible to `layout_check`.**

- **Both sheets were drawn entirely off the right edge of an upright phone.**
  The portrait branch of the fit wrote `offset_left = BUILD_PANEL_MARGIN` - a
  *left* margin against `PRESET_BOTTOM_RIGHT`, which puts `anchor_left` at 1.0
  as well as `anchor_right` - so the sheet's left edge landed thirty-four units
  past the right edge of the screen with its width collapsed to whatever its
  contents demanded. Measured at 430x932: x=1713 of 1680.
- **The command panel sat 276 units above the top of the screen, in every
  combat phase, on every launch.** `_build_command_panel` anchors it top left
  and says it moved there to free the bottom right for these sheets;
  `_on_touch_layout_changed` still wrote the bottom-right offsets it used to
  have, and that function runs from `_ready` on a desktop as well as on touch.
- **`BUILD_PANEL_LIFT` was 164 to clear that same panel**, and had been since
  before it moved. A hundred and sixty-four units of screen were spent clearing
  something that was not there, on every desktop, on both sheets, for as long
  as the roster has been growing. It is 40 now: air above the ability bar and
  nothing else.

**`layout_check` could see none of the three, and the reason is one line in
it** - a widget *entirely* outside the viewport is skipped, on the reasonable
grounds that it is usually a panel waiting to slide in. So a panel placed fully
off the screen is the one placement fault that gate is blind to by
construction, and all three were exactly that. The other half is that it had
never opened the road sheet: **a sheet nothing opens is a sheet nothing
measures**, which is the same finding as traps and barricades shipping
unreachable before the sheet existed at all.

**The chrome came out of the scroll, and it goes back in where it will not
fit.** The heading, the hover footer and the Close button were inside the build
sheet's `ScrollContainer`, so on a sheet too short for its list the player had
to scroll the list to reach the button that closes it and the heading - the
only thing naming what is being built - was the first thing to scroll away.
Outside the scroll they cannot scroll away, and that is how both sheets are
laid out on every ordinary screen.

**The price is that `Control.size` is clamped to the combined minimum size**, so
a panel whose chrome is taller than the room it is given does not shrink - it
grows past its offsets, and hanging from the bottom that means growing
*upward*, through the readout the ceiling exists to protect. A landscape phone
is 777 units of logical height with the right column owning the top 271 and the
combat row the bottom 308, and a thumb-sized Close button alone is 120. So
`_seat_chrome` puts the chrome back inside the scroll on exactly the screens
that have no room for it, which is what every sheet did before this. The order
never changes - heading, list, footer, Close - so the sheet reads the same
either way; what changes is whether those three move when the list is scrolled.

**The gate holds reachability rather than seating**, for that reason: a Close
button outside the scroll must be inside the panel's frame, one inside the
scroll must be the last thing in the list and the list must actually scroll to
it, and on a desktop shape - which has room several times over - it must be the
fixed one. A rule that always takes the same branch is a rule nothing is
testing.

**What is left on a landscape phone is recorded rather than solved.** With the
spirit readout up, that shape leaves the road sheet about 76 units and it
scrolls nearly everything. That is the true room under the ceiling, and it is a
large improvement on what it replaced - the sheet had no ceiling at all and
grew through the readout without bound - but it is not good. The three ways out
are all decisions: cover the Call button, cover the combat row, or have the
readout step aside while a sheet is open the way the minimap already does. The
third is the most promising and it needs the owner, because it softens a ruling
they made on 2026-09-17.

**`road_sheet_check` is the gate, on both bars, at four shapes.** It holds the
row count against `ContentDB` rather than against a number - with a floor of
ten under it, because everything else there counts rows against what
`ContentDB` loaded and a trap whose resource silently failed to load makes
those two agree with each other and both be wrong. It drives every row's own
`mouse_entered` and reads the figures box back, holds Close reachable, turns
the window upright and insists both sheets were re-laid, and checks the command
panel is on the screen when it is shown. Three
harness faults in writing it are worth keeping, because each made a working
feature read as broken or a broken one read as fine:

- **The box was not cleared between hovers**, so a row that opens no figures
  box at all read as explained by the *previous* row's numbers - it quoted a
  barricade's figures at four element-rail buttons. A rail pick buys nothing
  and carries its own `tooltip_text`; demanding a price of one is demanding a
  price of a folder. What is not allowed is a row that explains itself nowhere.
- **The element rail's picks are toggles**, so pressing the element that is
  already open closes it. The gate opens the build sheet more than once, and
  the second pass measured the four-row rail with nothing on it - a list that
  fits any screen and proves nothing.
- **Making the window shorter measures nothing.** The project stretches
  `canvas_items`, so shrinking a window's height leaves the logical viewport
  exactly as tall and a stale sheet still fits by accident: the first cut read
  the same rectangle before and after and called it a pass. It turns the window
  *upright* now, which is a shape the sheets answer differently on purpose.

**One allowance is written into that gate deliberately.** A build-sheet row
with no picture fails only when more rows lack one than there are towers whose
art is not yet on disk. A row that was never given a picture is this gate's
business; art that has not been drawn yet is the asset manifest's, and a gate
that is red for somebody else's half-finished change is a gate people stop
reading. The allowance is counted from disk, so it shrinks to nothing on its
own the day the art lands.

**And the road sheet's own Close button left the minimap hidden.** The sheets
hide the map while they are open, and three of the four paths that close the
road sheet put it back; the button the sheet itself offers did not.
`_close_road_panel` is the one door now.

**`road_sheet_shot` is the picture, and it is a diagnostic rather than a
gate.** The gate measures rectangles and cannot see whether an eighth trap's
art belongs beside the seven that shipped or whether ten rows read as a list a
person chooses from - and this project has paid several times over for the
difference between a number agreeing and a picture agreeing. It opens the sheet
on a real road tile and hovers the *last* row, which is a barricade, because
the empty tooltip was half of what was reported and an unhovered sheet does not
draw the box at all.

**A gate can be on neither bar because of its file extension, found
2026-09-22.** The three-line diff that finds the guard/release splits has a
third line - *on neither bar* - and it had never been run against the **shape**
of a gate rather than its name. Both workflow gate lists are hand-kept and both
are overwhelmingly `res://tools/x.tscn`; two gates are `--script` SceneTree
tools and were in neither list. `raid_layout_check` was green throughout.
**`grid_check` had been red since 2026-09-12**, with 34 failures, for ten days
of pushes and four releases.

**It was stale rather than broken, and all 34 were stale.** It asserted the map
as it was the day before the outskirts landed:

- *"the grid must be 45x45 at 64 units."* The **authored core** is 45x45; it is
  pasted at an offset inside a field of `SIZE`, which is 87 and not the 75 the
  outskirts note above records - `OUTSKIRTS` grew from 15 to 21 on 2026-09-14
  and the prose did not. What replaces it does not restate `SIZE`'s own
  definition, which would assert nothing: it holds that the layout on disk is
  `CORE_SIZE` square, that the core actually arrived with its town and its
  corridors, and that **every tile the outskirts template can address lands on
  the field** - `_put` drops an out-of-bounds write in silence, so a tuned
  constant that ran off the edge would simply not exist, with nothing said.
- *"sealing the border must leave the twelve spawn tiles as road", found 24.*
  Twelve was one three-wide mouth a lane. Each lane forks into two legs that
  reach the edge, so the figure is `LANE_COUNT * 2 * ROAD_WIDTH_TILES` -
  **derived, because a hand-typed 45 is what put this file a design behind.**
  The hand-picked sample tile went with it: the ring is swept, so a seal that
  missed a stretch cannot hide in the tiles nobody looked at.
- *"a route must end at the town", 32 times.* It deliberately does not, since
  the owner's report of 2026-09-12. Named off the lattice rather than off the
  256 units it happens to be: the last point must be one of the town node's own
  lattice neighbours, and the town's tile may appear nowhere on the route.

**Three assertions were re-scoped, which is an amendment rather than a repair.**
The open-ground fraction and the two-towers-abreast count now measure the
**authored core**. They were written about the authored map's four-tile gaps and
had come to read over a field 3.7 times the area they were sized for, where the
outskirts drown the signal: 4,566 places for two towers against a floor of 200
is a number that can no longer go wrong. Scoped to the core it reads 641. A
loose field-wide floor stays beside them, answering the different question of
whether the template has grown over everything.

**And `far_routes` is walked.** It is half the road network - the legs every
wave uses once a lane's two camps have fallen - it is a product of `BattleGrid`,
and no gate in the project had ever asked whether it was road the whole way. It
is, and every far route ends at the gate ring too. The near routes are walked
from step 1 and the far ones from step 0, because a near route begins in the
trees and crosses open ground to reach the corridor, which is the ambush working
rather than a hole in the road.

**The plant found a blind spot in the new gate, which is what plants are for.**
The third fault planted - the war camp's template range pushed past the edge -
**passed**. The range came out empty, the camp record described no tiles, and
"none of its tiles are the wrong cell" was true of no tiles at all: a comparison
of two nothings, which this project has shipped before. A camp must name ground
before it can name the right ground, and with that check added the fault is
named on all four lanes. The other two plants - the gate-ring truncation removed,
and the fork legs stopped one tile short of the edge - were named immediately.

**The sweep needed no parser change, and that is the recurring shape of this
mistake.** `tools/sweep.sh` hands everything after the keyword to Godot and has
always run the `--script` lines; three guard gates and three release gates are
already of that shape. What was wrong is its own header comment, which named
only the two `.tscn` shapes and so read as a statement that a `--script` line
was invisible to it. **A comment that understates a tool is the same fault as
one that overstates it** - `menu_shot` printing "no tail sprite found" over a
tail plainly on screen is the same lesson - and the first move planned here was
to teach the parser a shape it already knew. Corrected, and release-side gates
now carry their subcommand in the name, so three `run_tool.gd` lines are told
apart in the summary.

**The diff to run before a tag has three lines and the third is the one that
found this**, over `res://tools/[a-z_0-9]+\.(tscn|gd)` rather than `.tscn`
alone. It now reads clean: nothing guard-only, the five judgement-heavy reports
release-only as `guard.yml`'s own header intends, and on neither bar only the
five two-process network harnesses - which are run by hand by design - and
`tool_leak_check`, a `RefCounted` helper that `run_tool.gd -- tool-leak` uses
and which is on both bars.

**Four things about the breather, as of 2026-09-22.** The owner asked for a
tooltip that never hides behind the Preparation card, a countdown on the build
sheets, a grace period after a wave, and three wells rather than one with each
dearer than the last.

**A wave ends inside one frame, and that is why the grace is needed.** The
director closes the wave, emits `wave_cleared` *synchronously*, `Run._on_wave_cleared`
runs in that same frame, `_enter_wave_breather` sets PREPARATION, and
`GameDirector` flips build mode back on inside that one emit. From that
instant `PlacementCursor._is_active()` is true, so the next mouse release
opens a build sheet - and a player still swinging at the last body releases
that button on open ground. The owner's words: *"players can for example stop
spam attacking whatever they were attacking"*.

**The grace is asked beside `can_build_now`, never inside it**, and
`preparation_check` holds that with a source walk. That question is also asked
by the Quartermaster, by tower repair, by selling and by the crossroad path,
none of which is a click on the ground; folding a grace into it would refuse
all of them for a second for no reason. It is asked at
`PlacementCursor._is_active`, which the survey confirms is the **only** phase
gate on the click path - so one test there covers both sheets and every way
either of them opens.

**And the clock waits the second out rather than spending it**, which is the
owner's own reading: *"for 1 second after a wave ends before preparation
starts counting"*. The thirty seconds are still thirty.

**The sheets carry the clock now.** A player deciding what to build is looking
at the sheet, not at the card in the middle of the bottom of the screen, and
the thing that decides whether there is time for one more tower is the
countdown. One builder for both sheets, fed from the same `preparation_changed`
the card is fed from, wearing the same two colours the card's own clock wears -
a second opinion about when a countdown is urgent is a second opinion the
player has to hold.

**It is hidden where there is no deadline**, which is three of the four ways
into Preparation: only the between-wave breather is timed, and the crossroad's,
the boss's and the opening breather leave the clock at zero. A bar reading
empty where there is no clock at all would be a lie about the one thing it
exists to say.

**The tooltip is lifted above the Preparation card.** The box and the card are
siblings on one CanvasLayer and the card is added *after* it, so a box that
lands on the card is drawn behind it and cannot be read at all - and
`_clamp_build_tooltip` clamped only against the top and bottom of the screen
and knew about nothing else in the HUD. At 1920x1080 the two share about 260
units of width while the build sheet's rows sit at exactly the card's height,
so this was the common case rather than an edge case.

Lifted rather than pushed down, because below the card is the bottom of the
screen and the combat band; and if lifting would take the box off the top it
stays where the ordinary clamp put it, because a box half behind the card
still shows its first lines and one off the top shows nothing.

**Three wells, and each one dearer than the last.** The cap is not new -
`WELL_LIMIT_PER_PLAYER` has existed since 2026-09-13 and was **one**, for the
reason recorded there: one well answers the whole recovery economy and a
second made that answer permanent. The owner raised it to three and the other
half of the decision pays for it: `WELL_PRICE_STEP` is 1.8, so the three cost
150, 270 and 485 Gold and 25, 45 and 80 Stone. The first is what it always
was, the second is a purchase, and the third is a decision about the act
rather than about the wave.

**The count is the run's own record rather than a walk of the Tower group.**
`RunState.wells_standing()` reads `towers`, which loses an entry when a well
is sold *and* when one is destroyed - which is exactly what "a well that falls
frees its place" has to mean. It is also the only shape a `static` price
function and the build sheet can both reach.

**The price is handed in, not looked up.** `TowerData.build_cost(already_standing)`
takes the count as an argument because that class is loaded by the headless
`--script` tools where no autoload exists - the same reason it declares its own
currency ids at the bottom of the file. Both the quote and the charge go
through `Battlefield.cost_of`, so there is still exactly one place a build
price is decided.

**And the row says so before the click.** The refusal existed since
2026-09-13 and was only ever shown *after* the press, on the message line: the
row quoted a full price, took the click, and then said no. It reads
`Healing Well 2/3` now and dims at three, which is the rule every unaffordable
row already followed.

**The gate's own tooltip check was wrong first, and the shape is worth
keeping.** It handed the Preparation card itself to `_show_build_tooltip` as
the hovered control - and `_panel_of` walks up from whatever it is given to the
first `PanelContainer`, which *was* the card, so the box was placed to the left
of it, never overlapped it, and the check passed with the lift removed. What
has to be driven is the geometry the build sheet produces: a box in the card's
own column, at the card's own height. Checked by removing the lift, which it
then named with both rectangles.

**A property read off a resource that does not declare it, twice, as of
2026-09-22.** The release sweep read 178/181 and two of the three were the same
shape. GDScript only refuses an unknown property at parse time when the
receiver's static type is known; through a variable typed loosely enough - or a
resource fetched out of a Dictionary - the check defers to runtime, and the
runtime error fires only on the frame that line runs. `script_check` loads every
script and does not run them.

**`set_aura.gd` read `found.colour`** where `GearSetData` declares
`aura_colour`. The error aborted `_look()` **before** it assigned `_set` and set
`visible`, so the ring of motes at a finished set's feet had not drawn at all
since the forge catalogue landed. `gear_set_check` said so in as many words -
*"a hero in a whole set shows nothing"* - and nothing else could have.

**`wildlife_family_check` read `breed.is_boss`** where `EnemyData` carries a
`Category`. The abort returned null, `_stand_a_body_near` handed back nothing,
and **the whole third section of the courtship test had never run once**: a
companion with something to answer is busy.

**With it running, the section after it failed**, and that half is the more
useful lesson. The harness freed the probe body and waited **three frames**;
headless runs far above sixty a second, so the companion was still 0.95s into
the cooldown its own `attack_interval` authored when the next line asked whether
it was free. `_let_the_swing_finish` waits the companion's own swing window and
cooldown, **in seconds**. That is the same fault `enemy_shot_check` paid for
once, and the answer is the same: a wait counted in frames is a wait in whatever
the machine felt like giving.

**Found by making the check say which of five conditions was holding it.**
`may_court` answers one bool over five, and a gate that only ever printed *"it
is not free"* sends the next session reading the state machine instead of the
state. `_why_it_will_not_court` names the timer, which turned that into
*"mid-swing, swing cooldown 0.95s"* and ended the question in one run.

**The ring at the feet was at chest height, behind the body, as of the same
date.** Forty-seven shot tools and not one photographed the set aura - which is
the whole of what the owner asked sets for (*"wearing a full set should have a
visual vfx game juicy effect on players"*). `gear_set_check` proves `worn_set()`
answers and the node ticks; that is the **wiring**, and it stayed green through
two separate faults that made the feature invisible.

`set_aura_shot` is the picture: three panels of one Warden - nothing worn, the
moment the set completes, settled. Two real faults fell out of it and neither is
a number.

**The ring was drawn 68.8 units above the ground.** `Hero._ready` shifts the
body down onto its own feet so the Y sorter has ground contact as its key, and
lifts every *centre-authored* part back up by the same amount to keep the
picture - the sprite, the collider, the health bar. The aura was lifted with
them, which put the ring at the sprite's middle: behind the body at
`z_index = -1`, and the exact thing `SetAura._draw`'s own comment refuses. The
aura's coordinates **are** the ground, so it is not lifted.

**And the ring stood up like a hoop.** `draw_arc` is a true circle, while the
motes rode an ellipse flattened by 0.42 - two halves of one ring disagreeing
about which way the ground faces, with the comment above the motes explaining
the very mistake the line above it was making. The ring is a polyline on that
same ellipse now and the flattening is `Balance.GEAR_SET_AURA_FLATTEN`, read by
both.

**Three faults in the tool itself, every one found by looking at its output.**
The blits raced - `_blit` awaits a frame, so an un-awaited call resolves onto a
changed stage and the third panel saved before it landed. The Warden settles
68.8 below where it is placed, so the ring framed off the bottom edge until the
offset was **read off the settled body** rather than guessed twice. And the
plate sat at z 0 in front of an aura at z -1, photographing an empty floor -
the same z-order trap that has already cost this project a mount and a campfire.

**The lesson is the one already written here in other clothes.** A gate that
asks whether a thing is *wired* cannot tell you whether it is *visible*, and
four of the five faults above were invisible to every number in the project.
When a system's whole purpose is something a player looks at, photograph it
before believing it works.

**A frame of the interface may repaint itself and may never rebuild itself, as
of 2026-09-22.** The release sweep's third failure was
`perf_check`: *"node count still climbing after warm-up (+190.7%, budget
+6.0%)"*, with the frame time, the hitch count and the orphan count all clean.

**It was the sheet clock added hours earlier.** `Run._process` emits
`preparation_changed` on **every frame** of a breather, `_paint_sheet_clocks`
called `_dress_bar(bar, tint)`, and `_dress_bar` only ever *adds* a sheen and a
frame. Four nodes a frame for the length of a thirty-second breather - measured
at **7,264 children on each of the two clock bars**, 12,416 of the run's 12,514
node growth, against every other bucket in the census moving by forty or less.

**And the same line was a no-op for its stated purpose.** `_dress_bar` never
read the `colour` it was handed, so the bar had never changed with urgency
either; only the label's font did. An argument nothing reads is what made a
constructor helper look like a re-skin, which is how the call came to be written
at all. The parameter is gone, `_dress_bar` refuses a bar it has already
dressed, and the clock mutates the `StyleBoxFlat` the bar already owns - which
adds no node and finally does what the line was written to do.

**The gate for it is deterministic and the report is not, which is the right
split.** `perf_check` is one of the five judgement-heavy release-only reports,
its verdict here was a **coin toss** - `RunState.reset()` rolls a fresh seed, the
leak only runs during a *timed* breather, and 45 seconds contained one about one
run in three (measured: -0.1%, +0.2%, then +190.7%). So the invariant lives in
`preparation_check`, which drives `EventBus.preparation_changed` two dozen times
against the real HUD and reads `bar.get_child_count()` back. Driving the signal
rather than the painter is the point: a test that called `_paint_sheet_clocks`
would prove the function and not the wiring, which is the mistake the set-piece
row label already cost this project once.

**And a growth failure names its culprit now.** `perf_check` sampled one scalar,
so "+190.7%" was unactionable and diagnosing it needed a separate census harness
written from scratch. It takes a per-script histogram beside the scalar once a
second - **after the frame has been charged**, so an O(n) walk over eighteen
thousand nodes cannot invent a hitch in the frame it is measuring - and the
failure line ends with the three biggest movers.

**Why nothing else could have seen it.** The leaked nodes are hidden,
non-processing `Control`s: they cost no frame time, they are not orphans, and
they are children of a panel the player need never open. `layout_check` measures
rectangles, `preparation_check` drove the painter exactly **once** - which
proves the clock reads right and can never see a leak that needs two calls - and
no other gate in the project counts nodes at all.

**My premise was wrong and the measurement is the useful part, as of
2026-09-22.** I recorded the two property faults above as *"GDScript only
refuses an unknown property at parse time when the receiver's static type is
known"*, and set an audit going on that theory. It came back with the theory
falsified: `found` in `set_aura.gd` **was** exactly typed
(`var found: GearSetData = ...`). Measured in a standalone probe project on
4.7.1 - an unknown property *or method* on a precisely-typed script class is a
**runtime** error, always, because `unsafe_property_access` and
`unsafe_method_access` are warnings that default to off and this project sets
neither. So the fault class is not "loosely typed receivers"; it is **every
member access in the codebase**, and `script_check` can never see one.

Reproduced the compiler's own verdict: on a scratch copy with both warnings at
error, `script_check` flags 477 sites in 100 scripts, of which exactly **five**
name a member the class genuinely lacks. An independent source walk found the
same five and nothing else, validated by overlaying the two already-fixed files.

**Three of the five were shipping, and all three were player-facing.**

- **The Hold's pond has never produced a fish.** `hub_screen.gd` read
  `kind.roll_weight` on a `FishData`, which declares `weight`; `roll_weight`
  belongs to `WildlifeData` and is a *function* there. `_pond_catch` threw on
  its first loop iteration and returned null, so every cast on every account
  since it was written answered *"Nothing is rising."* - a fault that apologises
  politely is the worst shape one can take.
- **The Hold's "Start at an act" door hid the Hold and opened nothing.**
  `_road_act_start` assigned `act_start.take_the_road`, which `ActStartScreen`
  did not declare, so the assignment threw and aborted the function **after**
  `_hide_road()` and `suspend()` had already run. Invisible because that button
  is built only for an account that has passed Act I, and a CI profile never
  has - `a-passing-ci-gate-was-only-asked-about-ci-state`, in a third costume.
- **Two breeds ship as plain walkers.** `crevasse_stalker.tres` and
  `loam_lurker.tres` carry seven `behaviour_*` lines **above** the `script =`
  line, where Godot applies them to a scriptless Resource and drops them in
  silence. Loaded and read back: `behaviour = 0` where the file says 2. The
  anchor-on-the-script-line rule, paid for a third time - and
  `enemy_behaviour_check` skips a breed whose behaviour is NONE, so a dropped
  behaviour takes the breed out of the gate's own sample.

**And two gates were holding nothing.** `camps_check` guarded on
`gates.has_method("count")` for a method `RiftGates` has never had, so `before`
was always -1 and *"a dungeon mouth opens on its ground"* had never once run -
the `or true` shape again, wearing a defensive guard's clothes.
`discipline_check` read `node.slot` on a `DisciplineNodeData` that has
`slot_index()`; unreachable today, and a landmine for the day somebody authors
the synergy that guard exists to refuse. `PixelFilter.set_exclusions` was an
orphan wrapper whose only possible effect was to throw, and is deleted.

**The gate for the two that shipped is that something now drives them.**
`hold_check` fishes the Hold's pond twenty times through the screen's own
`_pond_catch`, and presses the act-start door **on an account given a road
behind it**. Both were invisible for the same reason: nothing had ever driven
them.

**And my own new test passed while aborting, which is the finding to keep.** A
GDScript runtime error stops the function it happens in and nothing else - so
planting the act-start fault made `hold_check` lose three checks and still print
**PASS**. A count of checks is not a proof that they ran. Each of those tests
stamps its own name as its last statement now, and `_run` accounts for every
stamp; with the fault back it names `'act_start_door' never reached its end`.
That is the comparison-of-two-nothings shape one layer out, and it will be true
of any gate in this project whose test calls a function that can throw.

**Not taken, and recorded so it is a decision rather than an omission.** The
audit's own first recommendation is to set `gdscript/warnings/unsafe_property_access=2`
in `project.godot`, which makes the compiler do this walk for ever. It flags 176
sites today; 148 of them are one pattern (EventBus reached through a
`Node`-typed receiver in `coop_relay.gd` and `coop_check.gd`) and 28 are spread
over 14 files. It is the right answer and it is a change that can stop the
*game* loading rather than only a gate, so it wants its own pass with its own
sweep rather than riding on this one.

**The dye was built correct in isolation and broken in company, as of
2026-09-22.** CLAUDE.md recorded one gap here - *"the co-op party portrait on
the HUD still draws the painted Warden for a partner"* - and a survey found the
prose wrong about where and the gap the smallest of three. There is **no party
portrait on the HUD at all**; `CoopPartyPortrait` is only ever built by the
pre-run lobby. `warden_look_check`, `coop_check` and `coop_heroes_check` were
all green throughout.

**The party tint destroyed the dye, and that is the one that mattered.**
Measured on the real south idle frame, band weight against the painting: Red
lost its cloak entirely and grew its sash **1299%**; Blue lost its sash; and
**Yellow and Green lost both** - the dye did nothing whatsoever for half the
seats. `Hero._apply_party_colour` lerps `sprite.modulate` 46% toward the seat
colour, `COLOR` already carries modulate when `fragment()` opens, and the bands
select by *hue*, so the mask moved with the seat. `warden_look(rgb, art)` reads
its bands off `texture(TEXTURE, UV)` and applies the turn to `COLOR`: what a
pixel **is** comes from the art, what is done to it comes from the state - the
separation `blood_stain.gdshader` already insists on for the blood. Solo was
never affected, because the tint only shows in company.

**A guest's dye reached nobody.** It rides the *host-authored* state row and
`_on_hero_state` returns unless this machine is a guest, so the host never wrote
a mirrored hero's `look`; `_look_of` then packed a `Hero.look` that was
`WardenLook.plain()` forever. The host drew every guest painted and relayed that
plain row on, so with three players each guest saw the other painted too. Only
the host's own dye ever travelled. `Request.HERO_LOOK` carries it, attributed by
the peer the packet arrived on - never by a slot inside it - exactly as
`HERO_MOUNT` beside it, and repeated on a slow clock because the host's mirror
of a guest is built from a spawn the guest does not control the timing of.

**And the lobby is before a run**, so no hero state row exists there at all. The
dye travels in the guest's own hello beside the tier and comes back out on the
roster, both of which already tolerate a short row - so a party spanning two
builds degrades to the painted Warden rather than to an empty roster. The local
card needed no wire and was painted too.

**Nothing could have caught any of it, and the reasons are each a lesson
already in this file.** Headless never compiles a shader, so
`warden_look_check` greps the source - and greps for the *old* signature.
`look_shot` is the photograph that would have shown it and it stood four
Wardens with **no session**, so the party tint had never once been in a picture;
it has a second row now, the same dye under all four seat tints.
`coop_lobby_check` asserts the atlas region and the seat colour, and a dyed
portrait and a painted one have identical regions.

**Three faults in writing those pictures, each worth keeping.** `wear_look`
takes a *packed row* and a dictionary unpacks to the painted Warden by design,
so the first run photographed four undyed Wardens and read as the bug still
being there. `_apply_party_colour` runs every frame and writes the tint back to
white when alone, so a tint set beside a live hero is gone before the frame is
drawn. And the lobby's `_update_party_view` returns unless
`Coop.is_networked()`, so a party seated locally draws nothing - the cards are
photographed on a plate, configured exactly as the lobby configures them.

**And I made the fault class I had spent the day fixing, inside its own gate.**
The first cut of the dye test wrote `partner.slot = slot`, which `Hero` does not
declare - a runtime error that aborted the whole test, so it **passed with its
subject removed**. That gate carries the same stamp guard `hold_check` learned
this morning. The harness also seated only the guest, which took slot 1, and
`_hero_for_slot` answers the *local* hero for `party.slot()` - so it dressed
this machine's own Warden, which reads exactly like the wire not working.

**The comfort scales are offered before the first road, as of 2026-09-22.**
`docs/ROAD_TO_1_0.md` §7.2: *"the flash scale exists - surface it in first-run
options rather than burying it."* All three existed and all three were four
clicks deep in Settings, on a tab nobody has a reason to open before they have
seen the thing that would send them there.

**The whole risk of showing a card to everybody is in one sentence: it must not
change everybody's save.** `comfort_card_check` serializes the whole account
either side of an untouched card and insists the two are byte-identical, and
that check had to be strengthened before it was worth anything - on a clean
profile the settings already hold what the card would write, so a card that set
every value on open produced an identical save and the first cut passed with the
fault planted in it. The settings are moved off their defaults first, the card's
own `_touched` is read back, and each value is read after the open.

**And it stores no flag saying it has been seen.** `_read_settings` drops
undeclared keys, so a flag has to join the defaults - and then every save on the
machine grows a key on its next write, for players who never opened this.
Whether to offer it is *derived* from `runs_started`, as `Graphics.default_preset`
and `TutorialGrants.should_offer` are, which also re-arms correctly after
`Erase progress` and for a second Warden in a new slot.

**`UserSettings.COMFORT_ROWS` is the one definition**, and the settings panel
builds from it too - so if the table is wrong that screen is wrong immediately
and visibly. Two screens each holding their own copy of a key, a range and a
step is the failure an Arcane node's reach shipped with.

**Which the shake slider had already shipped with.** `beast_scope` read
`SHAKE_KEY` raw off `MetaState.settings`, twice, while every other consumer went
through `JuiceDirector.shake_scale()`, which clamps to 1. The slider's maximum
is 1.5, so a player who turned shake **up** got 1.5x on the walk and 1.0x on the
road - and, worse for the purpose of a comfort card, a player turning it *down*
was obeyed in only one of the two scopes. Both values are legal floats and
nothing errored. `comfort_card_check` holds it with a source walk, because the
fault is an *omission*: a raw read added beside this one is silently unclamped.

**And `SaveSlotScreen` had never had its focus ring walked.** It was added on
2026-09-22 with a no-argument `open()` and not to `pad_focus_check._screens`,
and that gate's `_collect` filters on `is_visible_in_tree()` - so a screen that
is never stood up contributes no checks and no failures. 42 checks became 45,
and 48 with the comfort card.

**A board can be stood up again, as of 2026-09-22.** `docs/ROAD_TO_1_0.md`
§7.2: *"With 61 towers, 'repeat my last board' is real quality of life on a
second run."* Forty emplacements placed one click at a time are forty clicks the
player has already made, over a campaign that is ten evenings long.

**It is a shopping list and never a purse.** Every emplacement goes through
`Battlefield.try_build` and `try_upgrade` at the price the road charges, which
is the argument `ActStart.outfit` is built on and the reason no economy rule had
to learn that templates exist. The quote on the button reads the same two
functions the purchase charges, so the number shown and the number taken cannot
drift. Anything the purse, the board or the Forge refuses is simply not bought
and is said in the refusing door's own words - a board that ran out of Gold in
silence is a button that did half of what it promised and told nobody.

**Anchors are core-relative, and that is the load-bearing decision.** The
authored 45x45 core is byte-identical on every seed, but `BattleGrid._init`
rolls `camp_side` from the layout seed and the outskirts it lays differ with it.
`Expedition.compose` stores *absolute* tiles and gets away with it only because
`Expedition.apply` restores the same seed first; a template is applied to a
different seed by definition, so copying that shape would put emplacements on
ground the new run may have laid as road - **silently**, because an unbuilt
tower looks exactly like open ground. A recorded tower outside the core is
dropped when the board is composed rather than failing when it is applied.

**It amends working rule 7 by one key, and it is a shape rather than a
resource.** `MetaState.build_template` holds a place, a kind, a level, a path
and a targeting priority per emplacement - every one of them something the
player bought once and would buy again. No hero level, no gear, no attribute,
no unlock, no currency, no seed and no wall. `balance_test` names the key with
that reasoning and walks the keys a *row* may carry, because a template quietly
becoming a second expedition is what a top-level allowlist alone cannot see.
Additive: absent reads as no template, which is what a new account is, so
`SAVE_VERSION` did not move.

**Recorded where the board last existed**, on the frame a run ends and before
anything is torn down - and never by a guest, because the board is the host's
and a guest keeping one would be keeping somebody else's decisions. Two passes
on the way back up, ordinary towers then fusions, because a fusion needs its
neighbours standing before it can be offered at all.

`build_template_check` (58) replays a board **on a seed it never saw**, found by
walking forward from the recording seed until `camp_side` mirrors. Both faults
that matter were planted and both named: absolute tiles, which it names with the
coordinates, and an applier that writes `RunState.towers` directly, which it
names as *"quoted 305 Gold and took 175"* and as a board stood up with an empty
purse.

**Nobody was lost; one body in ten was walking a road 67 seconds longer, as of
2026-09-22.** The owner: *"Not all enemies that have spawned go to the city
base! Some seem to go off elsewhere or get lost preventing the wave from
completing!"*

**Traced before anything was changed**, because the state machine reads fine and
this project's record is full of pathing reports where it did. `wave_stall_trace`
is the harness: the real director on the field exactly as it ships, every body
sampled twice a second, and a body called lost when it has not improved on its
own best distance to the wall for twenty-five seconds. `enemy_siege_trace
--mode=full` could not answer it - its `_ready` clears the wildlife and switches
the sky's events off, which removes two of the ways a body can leave the road
before the measurement starts.

**Every lost body was WALKING, on a sane path index, with a legitimate route.**
Their routes reached the *direct approach* - one stood at (-1088, 0) with the
town at the origin - and then turned north, crossed the top of the map, came
down the east side and entered by a different gate. 5,632 units against a
shortest way in of 2,944.

**The pool, measured** (`route_report`, eight seeds): near routes 2,944 to 5,632
units, far routes 3,968 to 6,656. At the roster's 28 to 48 units a second that
is a 74-second walk against a 198-second one. The weighting deals each of the
two longest **2.4%** of the time, so about one body in ten arrives 55 to 95
seconds after its wave-mates - on an eight-body Act I wave, better than even odds
of a straggler every single wave. A wave cannot close until its last body
resolves, and `WAVE_INTERVAL` is **20 seconds**. Driven on the owner's own
account: **wave 1 took 345 seconds to clear.**

**The cap was there and it was passing.** `ROUTE_LENGTH_MAX_RATIO` is 2.0 and the
worst route measured 1.91x. Its own comment names this exact complaint - *"an
enemy taking it walks for around two and a half minutes ... the wave has been
over for a minute by the time it arrives, and it reads as a stuck enemy rather
than as a flanker"* - and it could not see it, for two reasons.

- **A ratio is not a bound on the thing the player feels.** It says how the
  routes compare to each other and nothing about how long anybody walks. When
  the map grew - `OUTSKIRTS` 15 tiles to 21 on 2026-09-14, `SIZE` with it -
  every route got longer in absolute terms while the ratio between them did not
  move, so the cap went on passing a pool it had stopped describing. **That is
  the same family as the pressure band written in prose here and enforced by a
  constant in a tool**, one layer further in: the bound was real, it was
  enforced, and it was measuring the wrong quantity.
- **And it measured the wrong route.** `_finish_routes` filtered `_tile_length`
  of the whole lattice walk from the fork junction, while what it hands back is
  that walk trimmed at `_join_step` with a spawn and a way onto the road in
  front of it. Two different lengths, and the body only ever walks the second.

`ROUTE_LATE_ARRIVAL_SECONDS` is the bound that answers it, stated against
`WAVE_INTERVAL` because that is the thing it must not outlive: a body still
walking when the next wave is dealt makes the road read as stuck and holds the
wave after it open too. Held on the produced polyline, at `ROUTE_REFERENCE_WALK`.
Measured after: the pool is 2,944 to 3,456 units, **12.8 seconds apart** rather
than 67, and every lane still offers four ways in. **The flanking survives** -
even the shortest route still loops south through the build ground before it
reaches the gate; what went is the pair that crossed to another quadrant
entirely, which is what the owner was watching.

**And the rescue had been disarmed, which is the other half of "preventing the
wave from completing".** `WaveDirector` has a watchdog that ends a wave after
`WAVE_STALL_TIMEOUT` - 75 seconds, itself long enough to read as a stall - and
its clock is reset by any progress. Progress is two readings, and **both counted
bodies the wave does not**: `enemy_count` excludes camp mobs because *"a camp is
not a wave"*, and `nearest_enemy_distance` and `wave_activity_checksum` did not.
A camp regenerating on the outskirts is what a camp does the moment it is left
alone, and a Warden who walks out to fight one moves camp health every frame -
so the checksum moved every frame, the clock reset every frame, and a genuine
straggler held the road open **for ever** rather than for 75 seconds. The
outskirts exist to be visited during a wave, so this is the common case rather
than the edge one. `EnemyField.holds_the_wave` is the one rule now, asked by all
four, and `nearest_enemy_distance` measures from the town rather than from the
world origin - which was the right answer only because the town happens to stand
there.

**`route_length_check` (212 checks) holds both halves**, and it drives
`route_for` across its whole roll space rather than reading the pool, because the
pool is where the bound is applied and `route_for` is the door the spawner opens.
Three faults planted and all three named: the shipped ratio-only bound, which it
reports as *"a route 2688 units behind its shortest - 67s against a budget of
20s"*; camp bodies counting toward the wave, which it names on all four readings;
and a budget tuned down until a lane has one road left.

**That third plant walked straight through the first cut of the gate**, which is
the finding worth keeping. The variety check counted *routes*, and every shape is
laid twice - once from each ambush side - so a pool holding one road still holds
two routes, and two different arrays, differing in their first point and nowhere
else. It read clean and proved nothing. A road is counted as distinct by its
length or its gate now. **A countervailing bound is only worth having if it can
fail**, and the cheap way to satisfy an "arrives on time" bound is to delete the
map's shape.

**One thing the trace found and ruled out, recorded so it is not chased again.**
Road bodies do get into long fights with wildlife well off the road - an Ember
Shaman was watched losing 58 hp to two animals at 636 units out, and another was
killed by one while standing at the wall. It is bounded and it is not this:
`_biting_back` returns a provoker **only while it is already in reach**, so an
animal can never pull a column off the road, and a body that loses the fight
dies, which *resolves* the wave rather than holding it open.

**And the pounce had never left the ground, as of the same date.** The half of
"some seem to go off elsewhere" that the routes do not explain, found by an
audit running beside the trace rather than by the trace, which never saw it: a
pounce only fires with a Warden inside its leap, and the harness had parked the
hero out of the way. **A harness that keeps the field quiet cannot measure the
things that only happen when it is loud.**

**Measured on all eighteen breeds that pounce, hand-driven through the real
state machine.** Two faults, and the second is the one the owner was watching.

- **The leap crossed nothing.** `_commit_behaviour` writes it into `_slip` -
  *"a shove along the marked line, through the same slip the knockback uses, so
  nothing downstream learns a pounce exists"* - and `_slip` is spent in
  `_advance`, which is reached from `_walk`, `_walk_camp` and `_rout` and from
  nowhere else. The COMMIT arm of `_tick_state` calls none of them. So every
  pouncing breed has told its tell, committed, and **moved zero units**, since
  the behaviour was authored on 2026-09-15. `_hold_behaviour` decaying that
  slip, and ANCHOR zeroing its own to stay *rooted*, are the same two lines
  saying the movement was meant to be there.
- **And the shove outlived the commitment.** `_slip` is the field the snow also
  uses, and only the snow's copy carries `_slip_left`, which is the only thing
  `_tick_slip` ever clears. A pounce's carried no timer and nothing else zeroed
  it, so what the decay had not eaten was added to **every step the body took
  for the rest of its life**. Measured: 153 to 245 units a second left behind by
  a pounce that ran its course, and **709 to 821** by one a rout broke into -
  against authored walks of 76 to 96. A body carried off the road at two to
  eight times its own speed, in the direction the Warden had been standing,
  never arriving and never dying. That is the report.

**The decay rate was a third number with no relationship to the other two.** A
flat 240 a second against an opening 789 wants 3.3 seconds, and the commitment
lasts 2.4 - so the residue existed even when nothing interrupted anything.
`_leap_speed` and `_leap_decay` are a ramp now: `2 * reach / t` falling to
nothing over `t`, which covers exactly the authored reach and arrives at exactly
zero. The shove is applied through `_step`, split out of `_advance` so a
commitment can move a body without also paying it its walking speed, and the
cliff slide is not written twice.

**And the clear lives in `_enter`**, which is the one funnel every state change
goes through - beside the line that drops an interrupted throw for precisely the
same reason. Put in `_end_behaviour` it would have covered the tidy exit and
missed the rout, the death and the behaviour taken over, which are the three
that were wrong.

**One thing measured and deliberately not changed.** `_commit_behaviour` holds
the commitment for `maxf(data.behaviour_seconds, ENEMY_BEHAVIOUR_SECONDS)`, and
that floor of 2.4 seconds is above every value POUNCE (0.36-0.50) and STORE
(0.50-0.80) author, and below every value ANCHOR (3.0-4.0) and WARD (5.0-6.0)
do. So the floor never does what it was written for - *"a breed that authors
nothing gets the default"* - and only ever overrides the two behaviours whose
authored windows are deliberately short. `_behaviour_reach` reads the same kind
of field the other way round (`authored if > 0 else default`), which is the
correct idiom and is two functions away. **It is left alone because changing it
is a pacing decision on twenty-seven breeds and the owner reported movement, not
timing** - and with the leap applied, the body now crosses its reach in its own
0.4 seconds and stands committed for the rest, which is strictly better than
standing still for all 2.4 and then drifting. Worth an owner ruling.

`enemy_behaviour_check` grew from 130 checks to **343**, and it walks every
pouncing breed twice - once left alone and once broken out of the commitment by
a rout. Both faults were planted back and both were named: the unapplied shove
as *"crossed 0 units on a pounce authored to reach 300"*, and the surviving one
as *"left 1302 units a second of drift ... it walks at 96"*.

**The gate's first run reported twelve breeds as never pouncing, and that was
the harness.** Eighteen breeds each get twenty seconds beside the Warden and
they all swing; the hero died partway down the list, `_foe_stands` then refused
it, nothing targeted it, and every breed after that looked like one with no
behaviour at all. It is `stagger_check`'s probe dying three blows into a
twelve-blow flurry, one level up - **a probe that dies mid-measurement reads
exactly like a feature that does not work.**

**And "every enemy in the group" is never "every enemy on this field".**
`Enemy.GROUP` is global - every body joins it in `_ready` - while a raid camp, a
rift maze and the road are all `EnemyField`s full of enemies. Two things read it
as though it meant the road.

- **The road's wave counted an arena's bodies.** Solo that is harmless, because
  entering a raid or a rift freezes the field (working rule 8); in co-op it is
  not, because a party that splits leaves the road running - which is that
  rule's own 2026-09-12 amendment - and the wave then waited on bodies in a maze
  nobody on the road could reach.
- **And the rescue razed the outskirts.** `resolve_stalled_wave` walked the
  whole group and killed it through `Health.kill`, which is the ordinary death:
  so a watchdog firing razed **every camp on the map** and paid full spoils,
  experience, loot and gear for each one. A stall is already a bad moment;
  handing the player twenty-eight free camp kills and emptying the ground the
  outskirts exist for is worse than the thing it was rescuing.

`Enemy.field()` names the scope a body was stood up in, `holds_the_wave` asks
it, and a body that names no field at all is still counted - that is a harness
probe, and excluding it would quietly change what every gate measuring
`enemy_count` is measuring.

**Both of these came out of an audit run beside the trace rather than out of
the trace**, which is the argument for running both: the trace measures what
the field actually does and can only see what its own harness provokes, and a
read of the code sees what is reachable and cannot tell you whether anything
reaches it. Between them the pounce was found twice, independently, with the
same arithmetic.

**Nothing walks off the map, and the edge is one number, as of 2026-09-22.**
The owner, of the beasts and of "any other enemies that might experience
similar issues": they *"try to leave the map or get lost ... ensure that they
are not able to leave the map's bounds"*.

**The Warden had been clamped since it was written and nothing else ever
was.** `Battlefield.step_is_legal` refuses only the city, and the base
`EnemyField.step_is_legal` returns `true` outright - so a hard enough shove,
or the pounce drift above, walked a body off the field, where it could never
arrive, never be killed and never stop holding its wave open. The knockback
bounce had its own copy of the edge, and that copy named the *battlefield's*
extent even inside a raid arena several times smaller.

**One rule, per scope, asked at every mover.** `BattleGrid.play_extent()` and
`RaidLayout.play_extent()` state the edge once; `EnemyField.hold_inside` is
the question, answered by the battlefield and the raid arena for their own
ground. `Enemy._step` (the walk, the cliff slide, a commitment's shove),
`Enemy._walk_camp` (a camp lord's patrol), `Enemy._bounced` (knockback) and
`Wildlife._walk_step` all ask it, and so does the hero's `bounds_extent`, so
the Warden and the things hunting them agree about where the world ends.

**Clamped, never refused.** A body already outside - thrown there, spawned
there by a harness, standing there when the ground was re-laid - has to be
able to come back, which is `step_is_legal`'s own reasoning about the city
applied at the other edge.

**An animal crosses the edge twice in its life, on purpose.** It arrives from
off the map and it leaves over it. The first cut held every step, which pinned
a leaving animal against the border walking at a way out it could never reach -
the report, from the other side. `ARRIVING` and `LEAVING` cross; everything
else is held, **and so is where it is going**. A goal outside is written in
several places - a bolt with nowhere clear to go, a shove off the town, a
relocation - and a body held at the border while it walks at an unreachable
goal is an animal stuck at the edge of the world. `_settled` holds the goal at
its one reader, and the wander centre and every bolt candidate with it.

**`map_bounds_check` (24 checks, both bars)** shoves every breed from a
corner, walks a body placed four thousand units out back in, patrols a camp
lord whose home is outside, and settles every animal at a corner with its
haunt and goal dragged off the map while one more is sent away over it. Four
faults planted, four named: the enemy step unheld, the bounce unheld (a Bell
Priest thrown 9,468 units out), the wildlife step and goal unheld (789 units
out), and every crossing held (a leaver pinned inside).

**Its wildlife test was blind twice, and both are lessons this file already
holds.** It read the survivors at the end, and an animal that walks far enough
out is *forgotten* - removed as out of everybody's sight - so a stray passed
precisely because it got away; it samples every frame now. And the Warden
stood at the town, 3,800 units from the corner the animals were placed in, so
the mythic was forgotten on its first tick and the test measured an empty
field. **A probe outside the thing it measures reads as the thing working.**

The source walk refuses a hand-written `HALF_EXTENT - TILE` anywhere but the
two owners, and its first cut named five files of which two were not copies at
all - half a tile to lay a tilemap, two tiles for a spawn ring. A different
inset is a different number that shares a spelling, so it matches only a tile
that is not multiplied, in code rather than comments. The four real copies, in
`fishing.gd` and `wildlife.gd`, ask `play_extent()` now.

**Four interface faults from one play report, as of 2026-09-22.**

- **The tower's range ring was drawn round its target.** `EventBus.tower_fired`
  carries where the shot went - right for the sound and the muzzle - and
  `CombatTells` drew the tower's reach there, so the ring stood on the enemy it
  hit. The owner asked for League's readout: the reach round the tower. The
  centre is asked of the field by anchor (`Battlefield._tower_ring_centre`,
  the same point the selection ring uses) and a tower the field cannot find
  draws no ring rather than a wrong one. `tower_juice_check` holds it for all
  five shot styles.
- **The command panel is hidden until Command is earned**, and hangs below the
  HUD's second row measured off that row (`UI_COMMAND_PANEL_GAP`). It sat at a
  typed 104 while the row it had to clear is seated off the top bar's own
  height, so the quiver readout and the sundial were under its frame. Derived
  from `command_earned`, so it resets with the run and rides the expedition
  snapshot. The tutorial step already fired on the first Command earned, so the
  panel and the lesson arrive together; its copy no longer says "along the
  bottom". `road_sheet_check` holds both halves.
- **Building sheets dock under the top-left readouts.** `UiMetrics.dock_panel`
  takes the edge to start below; the HUD publishes it
  (`HUD.top_left_reserve`) where it seats that row. On a screen too short for
  both, the sheet keeps `UI_SIDE_PANEL_MIN_HEIGHT` and the readouts give way.
  `layout_check` holds it on every shape tall enough to ask.
- **The Warden picker refused on every fresh launch. Owner re-cut of the
  2026-09-22 slot rule**: *"even if I don't have a run saved I should still be
  able to change save slots. And even if I do"*. The rule was "not mid-run" and
  the predicate was `phase != ENDED` - but the phase becomes `ENDED` only when
  a run is *settled*. It is `PREPARATION` at every launch and stays mid-run
  after a road is left from the pause menu, so the menu said "a road is under
  way" when none existed. `RunState.road_is_live` asks the director
  (`run_active`) and the phase together, and the pen's `pen_take` had the same
  fault and asks the same function. A banked road is the slot's own and stays
  with it, so changing Warden never costs one; switching while a road is truly
  live is still refused. `save_slot_check` and `pen_check` drive a live road by
  the director's own flag now, and hold the fresh-launch case.

**A camp pays the share of a wave it always should have, as of 2026-09-22.**
The owner: camps *"drop too many resources including gold which can really
affect the runs"*. Measured: razing paid a flat 90 / 170 / 360 currency, 55%
of it Gold, in every act, on a 150-second clock - against a road body worth
about 1.3 resources in Act I. An outer camp paid roughly seven road waves and
nearly bought the first tower on its own, which is the opening envelope
`balance_test` guards arriving through a side door.

The raze pays a third of that now (`CAMP_CURRENCY` 36 / 64 / 110), split with
Gold the smallest share (`CAMP_CURRENCY_SPLIT`), climbing with
`kill_act_scale` exactly as a road kill does; a camp body pays 1.1 of a road
body rather than 1.4; and the camps come back on 240 / 300 / 420 seconds. What
a camp is *for* is untouched: the gear, the Shards and the fork.
`Camps.raze_currency` is the one function the ground is paid by and the gate
reads, and `camps_check` holds that no tier's raze in Act I buys the cheapest
tower and that the pay climbs with the road. Planted: the old flat table,
which it named on all three tiers.

**A body held by spam breaks out and swings, as of 2026-09-22.** The owner:
enemies *"hitstunlocked from the player's spammed attacks"* should *"eventually
... break out of it and attack back, tuned for each enemy appropriately"*.

**The footing of 2026-09-15 took the shove away and left the lock.** The load
drains at two thirds a second and an ordinary body gains a fifth a blow, so a
Warden swinging three times a second holds it low for ever - and every blow
with any shove still knocked a 0.45-second wind-up back into recovery.
Measured by planting the fault: a body spammed every 0.3 seconds went nine
seconds without one swing.

So broken wind-ups are counted inside `ENEMY_BREAKOUT_WINDOW`, and once a body
has had `breakout_after()` broken, the next is armoured: no flinch, no shove,
no stun, a loud early tell (ring, sparks, the armour ring's sound, a small
impact), and **the ordinary blow at its ordinary size**. The count is derived
from the `stagger_tolerance` each breed already declares - a boss after one,
a plated or stone body after two, an ordinary body after three - so a breed
tuned to reel longer is tuned to be held longer, and nobody edits sixty-eight
files. A brace is still a refusal that deals nothing; this is the other half,
and it deals exactly what the body was always going to deal, which is why
`curve_report` reads the same waves. `stagger_check` (241) spams a real body
in real time and insists the swing lands and was armoured, and that one blow
arms nothing.

**A mount charges, and that re-cuts "a mount can never touch a number in a
fight", as of 2026-09-22.** The owner: *"Right clicking while mounted should
charge in the direction aimed and ram enemies on its path and dismounting after
ramming or reaching the end reach of the charge or colliding with something
including the end edges of the map and deflecting ... do proper damage and aoe
on impact and set the mount on a cooldown."* The 2026-09-17 bound was the
dismount rule; this is the owner reversing half of it, so it is recorded.

**The bound that replaces it is where the number comes from.** The ram hits for
`MOUNT_RAM_DAMAGE_SCALE` of the Warden's own finisher through
`damage_multiplier`, so it sits on the capped levelling-and-gear scale every
blow already uses and a horse adds no power of its own; the bodies round the
impact take `MOUNT_RAM_AOE_SHARE` of it and are shoved. **What it costs is the
ride**: every charge ends on foot - at a body, at a wall or the map's edge
(deflected along the bounce), or at `MOUNT_RAM_DISTANCE` - and the saddle rests
for `MOUNT_RAM_COOLDOWN`, on the same ring and refusal a throw uses, named
"Resting" rather than "Thrown". One opening blow a fight, never a way to fight
mounted; the swing still dismounts.

**It rides the dash bit**, which is no longer muted in the saddle: the charge
is movement that ends in a blow, and the dash press is what already crosses the
co-op wire, so the host's copy of a guest charges on the same fact and a
puppet refuses the damage on the guest. `mount_check` (151) drives the press a
player makes: a body on the line takes the scaled finisher and the one beside
it takes its share, a charge into open ground runs its reach, a charge at the
edge stops inside the map, and every charge ends resting. **Two coin tosses
were in the first cut of that test, and both are recorded lessons**: a press on
a single frame is dropped whenever Yuri's footfall has the Warden stunned (the
test presses until the charge starts, as a player does), and the seed's weather
floods the field often enough to refuse the charge and unseat the rider. The
reach is measured only on a charge that ran free - trees and props end one
exactly as they should - and every early end must say what it met.

**Every dragon breathes its own element, and the fire wyrm has a hyperbeam, as
of 2026-09-22.** The owner: *"Dragon firebreath is highly unpolished and needs
super aesthetically appealing game juicy vfx! Make it with blender's forge ...
each dragon type's elemental breath attack which should match its element and
not all be fire, although the non-fire dragons can also breath normal
firebreath ... the fire dragon ... a special ultra firebreath attack which is a
fire/electric/plasmaish hyperbeam type of laser beam."*

**Both breaths were two straight lines of one colour.** The war-camp wyrm's
release (`EnemyGroundStrike`, a line) and the passing dragon's
(`GroundHazard`, "breath"). `DragonBreath` is the one picture both stand up: a
charge glowing at the mouth over the warning, a feathered licking cone in the
element's three colours (`DRAGON_BREATH_PALETTES`), forged tongues and blooms
rolled down it from Blender (`breath_tongue`, `breath_bloom`), the element's
matter thrown off it (embers, frost motes, lightning, grit), and for the ultra
a plasma beam - white core, violet sheath, fire skin, two arcs wound round it
and forged `beam_core` segments tiled along it. `breath_shot` photographs all
five; the first photograph had the cone too thin to read as anything but a
laser, a square-cut front and tongues as opaque blobs, and each was fixed
against the picture rather than a number.

**`EnemyData.breath_element` and `breath_ultra`**, authored on the four
dragons. `DragonBreath.choose` breathes the dragon's own element
`DRAGON_OWN_BREATH_CHANCE` of the time and plain fire otherwise, the fire wyrm
its ultra on `DRAGON_ULTRA_CHANCE`, and wanders the line's width, reach and
angle within authored bounds - the ultra is longer, narrower and charges for
longer, so the stronger picture is the more readable tell.

**The bound is the one every shot here is held to: shape, never size.** The
release's damage is the bank's own and is decided *before* the dice are rolled;
`dragon_check` walks the source to hold that order, and drives two thousand
breaths per dragon to hold that each mostly breathes its own element, sometimes
fire, and that only the fire wyrm ever breathes the ultra. `DragonBreath` reads
nothing, moves no number and draws on its own dice. The telegraph's exact edges
are still drawn by the strike that owns them.

**A beast sent after the players keeps after the players, and the screen's
edge points at what the player must find, as of 2026-09-22.** The owner, of the
"new beasts": *"sometimes they'll run off and attack a camp or try to leave the
map or get lost. They should have smarter AI behaviors ... and indicators also
implemented to help players identify where they are"*.

**The fault was the frenzy's appetite on an animal that was not frenzied.** A
savage - the elite a species sends after somebody who over-farmed it - is also
flagged `rabid`, which is what lends it the frenzy's reach, and `_quarry_for`
offered a rabid animal every road body and camp body in range. So a beast sent
after the player detoured into the first camp it passed; a robbed parent
(`angered`) had the same door. And with no Warden in reach it settled where it
had been placed - which for a savage is the edge of the map - and wandered.
`Wildlife.hunts_the_players` names the two; they take only heroes and the
spirits at their shoulder, and with nobody in reach they walk toward the
nearest Warden not sheltered in the town. A Wildblight frenzy that nobody
provoked still attacks everything near it - that is the blight, unchanged.
`wildlife_spawn_check` offers a savage a road body and no Warden, and refuses
the old appetite by name.

**`ThreatPointers` puts an arrow at the screen's edge**, pointing out along the
line from the middle of the screen, for four things: the wave's last bodies
(asked of `Stragglers`, so the plume and the arrow are one set - and
`Stragglers` now scopes itself to its own field's wave, as `enemy_count` does),
an act boss, a beast hunting the players, and a dragon that has landed. **The
fog's bound, narrowed as `Stragglers` narrowed it**: only what is hunting the
player or what a wave or an announcement is already asking about; an arrow at
every elite and every camp would be the fog turned off. Nothing reads it.
`road_sheet_check` stands a boss off the screen and insists on one arrow, at
the edge, facing it - and none once the boss is on the screen. Its first cut
waited twenty frames for a set gathered every fifth of a second, which headless
is no time at all: waits are in seconds.

**The owner could not reach Act II, and the batch that answered it, as of
2026-09-22.** A level-100 geared Warden barely reached the first crossroad, the
Walk on a new slot could not be lost or left, and several things on screen were
lies. Each answer below is a decision rather than a tune, so each is written
down.

- **A lost Walk ends the Walk.** `_settle_run` returned on its first line while
  walking, which swallowed every loss: a Warden on their last wound was sent
  back for ever and a fallen town kept standing. A loss now calls
  `end_walk(false)` - nothing settles, the menu offers the Walk again.
  `GameDirector.walk_leaves_on_loss` is the documented seam that lets
  `tutorial_walk_check` drive the loss without its own scene being replaced.
- **Enemy damage 0.85 to 0.62, ranged a further quarter lighter**
  (`ENEMY_RANGED_DAMAGE_SCALE`). Contact damage is outside `curve_report`'s
  pressure by design, so the ramp is untouched and only survival moves.
- **Extraction at every crossroad, the first included.** The 2026-09-20 rule
  refused the first fork; for a player who can barely reach it, the first fork
  is the only chance to keep anything, and a missing button read as bad luck.
- **Ranged bodies besieging the wall come in closer** (`ENEMY_SIEGE_SHARE`,
  stepping nearer by `ENEMY_SIEGE_STEP` after every shot to
  `ENEMY_SIEGE_FLOOR`), **every recovery wanders per body**
  (`ENEMY_CADENCE_WANDER`), and **light bodies and shooters may sidestep a
  swing** they read at its start (`dodge_chance`, derived from role, hide and
  footing; bosses, camp lords, plate, stone and shields never do). Each body's
  own dice, seeded from its identity, so the run's stream does not move.
- **A range ring is a true circle at the reach actually fired from**:
  `Tower.effective_range()` through the field, never `range_at(level)`, and no
  squash - the flattened ring promised 58% of the reach up and down the screen.
  **Enemies show their reach after attacking** (`EventBus.enemy_attacked`),
  near a Warden and at most `RANGE_RING_ENEMY_MAX` at once.
- **Rebuild last board offers only free ground** (`BuildTemplate.rows_to_raise`,
  asked of `placement_problem`), so a doctrine's board from an act start is
  neither quoted, counted nor "refused".
- **Locked towers are listed, dimmed, per element (x/10).** All forty existed;
  the eight of 2026-09-22 sat at the end of the Tools ladder, and a sheet that
  listed only what was unlocked read as a roster that was never built. The four
  support towers' descriptions no longer say they fire nothing.
- **Swings cost SP; Swiftness and Vigour deepen the pool** (`max_stamina`,
  `HERO_ATTACK_SP_COST`, `HERO_SP_PER_*`); **the charge needs and spends
  `MOUNT_RAM_SP_COST`**; **HP, MP and SP bars carry current/max and a
  percentage**, drawn by `BarName` so a thin bar is never taller than itself.
- **Combination towers name their own paths and capstones**
  (`TowerData.path_names`); they already climbed to ten and split at five
  through the same ladder, and were offered their first parent's names.
- **A Wildblight frenzy pulses, froths and throws toxic rings.** Its picture
  clocks live beside the animal's record, never in it: written into the record,
  `wildlife_family_check`'s companion courtship failed four runs in four, and
  moved out it passed - a record is what the ecology, the wire and the gates
  reason about.

**Not built in this batch, and recorded so it is not assumed**: enemy MP and SP
pools with their own bars and spending, more attributes, several attribute
points a level (a re-cut of "one point a level", which `attribute_check` holds
first and hardest), and new combination towers with their own art.

**The second pass of 2026-09-22, and the design question behind it.** The owner
played v0.53 and reported Acts III–IV playing themselves once the board was
built, the map reading as a swastika, and a list of fixes.
`docs/DESIGN_DIRECTION_2026-09-22.md` is the decision document for the first
two - mirroring alternate lanes as the immediate P0 for the map shape, and
board-attacking enemies plus Warden-only objectives for the late game - and
**none of it is built**; each is the owner's to rule on.

Built: range rings follow the enemy that drew them, are fainter, and **pulse on
every refresh** so a held ring still says each shot; each kind is its own
setting (`Graphics.KEY_RANGE_TOWERS`, `KEY_RANGE_ENEMIES`). A 15 FPS frame cap.
**Undo** of the last tower or trap for its full price within
`PURCHASE_UNDO_SECONDS` in Preparation, only while it is exactly as bought.
**Sell all Rough / Sound** beside Break all, with the same sweep rules. The
tower sheet wraps its text and grows leftward, so the upgrade's price stays on
screen. The boss bar and the portent cards stop overlapping what is beside them.
**Enemy health from Act III** raised (`WAVE_ACT_HP_SCALE` 1.52 at III to 1.96
at X): the first cut raised the late acts too and `curve_report` refused it at
0.627 for four players against a ceiling of 0.58; the model itself put Acts III
and IV at 0.30, which is the owner's "too easy" in numbers, so the raise is
concentrated there.

**The battlefield has modes, as of 2026-09-23.** The owner: *"settings
dropdown options for the best different map modes for our game including the new
map modes and current map mode, so all variations can be tested and current
method can be preserved to revisit as needed"*, then *"an option that will
randomly use any of the map modes except for the original which looks like a
reverse swastika. Any of the random maps it makes should also have procedural
variations"*, and *"another version of confluence that has the rings for the
north and south as well"*. That re-cuts v4 §54's cut of procedural layouts and
the 2026-09-12 line above that "what the seed decides is a mirror", so it is
recorded.

**What the problem actually was, measured.** The authored core is the pinwheel,
not only the outskirts: it matches itself under a quarter turn on 100% of its
road and its own mirror image on 44%. `DESIGN_DIRECTION_2026-09-22.md`'s option A
- mirror the outskirts - could never have fixed it.

**Seven layouts** (`MapModes`): **Classic**, the authored map exactly; **Keep**,
two walls whose roads double back to four gates; **Citadel**, one wall with gates
east and west and a bastion on every road; **Beast-Axis**, a spine and ribs;
**Confluence**, two braided trunks the north and south roads split onto;
**Confluence: Four Rings**, a braided ring for every road; and **Wild Roads**, a
network rolled from the seed. **Random** is a choice rather than a layout: it
deals any of them but Classic when a road begins, **varied** - its walls, bars,
ribs, braids and ties rolled from the seed within ranges that keep it sound.

**The core is replaced and nothing around it moves.** Every layout keeps the four
entries at the middle of each edge, so the outskirts, camps, forks, ponds, nodes,
plots and gates are laid exactly as before; every road is a straight three-wide
corridor on the lattice the renderer, torches and minimap already read. Classic's
code path is untouched to the line - the authored file, the same-way-round camps,
the original route walk - and `map_mode_check` holds that a grid made as Classic
is the unmoded grid cell for cell and route for route.

**Four bounds, each gated:**

- **A new layout is its own mirror image left to right** (`map_mode_check`,
  99% or better; they measure 100%). A shape with a mirror line cannot be a
  pinwheel, so the fault is impossible rather than merely absent. Their camps
  mirror too (`BattleGrid._side_of`): east and west reflect each other, north and
  south likewise.
- **No lane is the one every wave is lost on.** Shortest ways in within 1.6x of
  each other across the four lanes, and every varied roll within 1.45x
  (`MapLayouts._sound`), none a straight shot.
- **Room to build**: at least 55% of the tower places Classic's core offers.
- **Every road is walked.** `map_mode_play_check` stands the real run up on each
  layout and sends bodies down every lane until they reach the wall - on the
  release bar only, because it takes six minutes.

**A layout is the road's, never the machine's.** The setting chooses the *next
new* road. `RunState.map_mode` and `map_varied` are reset to Classic by every
`reset()` - so a gate never measures whichever map its developer last chose - and
set in `start_run` from the setting, or for a guest from the host's word heard
beside the seed (`Fact.RUN_STARTED` carries both). A banked front carries its
own and comes back on it whatever the setting says. The Walk is always Classic,
because its stops and its pictures were made there. The pause menu names the
battlefield, since Random says so nowhere else.

**Generated layouts walk routes differently, and Classic does not.** A double
wall is a grid, and the plain walk stops at `ROUTES_PER_LANE_MAX` on the first
two dozen ways in the lattice lists rather than the shortest two dozen. So the
new layouts take the true shortest way first and then search only steps that can
still arrive within `_bounded`'s limits (`_walk_routes_bounded`).

**Nothing persists but the choice**: `settings.map_mode`, declared in the
defaults, and two fields on a banked front. Additive; `SAVE_VERSION` did not move.
**The default is still Classic**, because the ruling was to add and preserve.
Moving it off Classic before anybody outside plays is the P0 in the design
direction, and it is now a one-line default rather than a project.

**Three things taken from Core Keeper, as of 2026-09-23.** The owner asked what
the game can learn from Core Keeper's systems and its polish, ruled "no idols",
and left the rest to judgement. `docs/IDEAS_REVIEW_2026-09-23.md` is the triage:
what it does, what Wilderhold already has under other names, what comes next and
what is refused. Three pieces were built the same day, each a presentation that
changes nothing but presentation, and `polish_check` holds all three:

- **The music settles when the road is safe.** Preparation on the battlefield
  eases the music bus through a low-pass and a trim (`MUSIC_CALM_*`); a wave
  opens it over three seconds. The same song, never a track change; the player's
  slider and the post-boss hush never move; a raid is never safe. It found a real
  bug on its first run: `AudioBuses.set_calm` skipped any step under 0.002
  *without storing it*, and at a high frame rate every step is that small, so
  the fade stalled. A skip may save the bus work; it may never drop the count.
- **Flowers glow at night.** A share of the flower and mushroom patches carries
  an additive halo behind the plant (`show_behind_parent`), in the petals' own
  colour read off the painting, lit by `DayNight.darkness`. Sprites, never
  `PointLight2D` - a hundred real lights is the frame going away - and capped by
  `FOLIAGE_GLOW_MAX`. Which plants glow comes from where they stand, never from
  the run's stream.
- **You look like what you wear.** `WardenLook.worn` puts a full set's aura
  colour on a cloak the player left undyed, and every place this machine draws
  or sends its own Warden uses it - so a partner, the Hold's seats and the lobby
  see the same Warden. `mine` is still what the dye slider reads and writes,
  because that is what it edits; a set that overrode a chosen dye would be the
  game ignoring the player.

**The visual pass that followed, as of 2026-09-24.** The owner took the triage's
visual roadmap and asked for all six, then forwarded twelve Godot VFX and polish
videos (`docs/IDEAS_REVIEW_2026-09-24.md` is that triage: nearly all of it
already ships, and the two real gaps are built below). Every item is a look and
never a fact - nothing reads any of it, and `polish_check` holds each one.

- **Light takes the ground's colour.** `GroundGlow` is a pool that comes up with
  the dark, its colour the light times the earth under it
  (`GroundGlow.bounced`): lifted so black earth tints a pool rather than putting
  it out, held at the light's own brightness so the ground moves the hue and
  never the strength, and re-read when the region changes. The torch pools take
  the same arithmetic. A pool is a sprite, never a `PointLight2D`.
- **The town is shelter at night**: one warm light and a wide pool
  (`TOWN_NIGHT_*`). **Every tower throws its element on the ground**, and **ore
  and gem seams glow**; timber does not. The first town pool was invisible at
  midnight - a wide pool at a torch's strength is spread too thin to read - and
  only the photograph said so.
- **Towers shade with the light's direction** - the pilot, towers first (owner).
  `actor_polish.gdshader` reads the relief off the painting itself: mostly the
  silhouette, a little of the brightness, at two reaches, so a lit tower reads as
  a turned form rather than as embossed bricks. That was the first cut, and the
  picture refused it; a flame, a crystal or an ember is left unshaded because it
  is its own light. A custom `light()` brightens the side facing a light and
  darkens the far side by less. **At `shade_strength` 0 it is the engine's own
  formula, measured byte-identical** (`tools/shade_probe.gd`, windowed), and
  only `tower.gd` sets it - `polish_check` walks every other script. A tower's
  own light stands `TOWER_LIGHT_HEIGHT` above it so it lights its tower flat.
  `SunRelief` is the sun for towers alone (`SUN_RELIEF_LAYER`): it lights no flat
  pixel, swings from the right at dawn to the left at dusk, and is gone at night.
  Rolling it out to bodies is one uniform a kind, and a decision.
- **A third dye and presets.** The leather - hue 21-32°, saturated and dark,
  which keeps the lantern's bright orange out of it - rather than the metal trim
  the triage named, because the trim shares its hues with the lantern and the
  leather has a clean band. **Appended to `WardenLook.KEYS`, never inserted**: a
  two-number row from an older partner still means cloak and sash, and
  `coop_heroes_check` proves one lands. Six presets in `WardenLook.PRESETS`.
- **A palette check per region**: `tools/palette_sheet.py <out>` - a region's
  palette off its ground and foliage, then every sprite that stands there ranked
  by distance from it. A picture, not a verdict: it flags where to look.
- **Bloom**, inside the colour grade's own pass. The Compatibility renderer does
  give the screen texture mipmaps (`tools/bloom_probe.gd`), so it is three taps
  of a blur the renderer already paid for, after the grade and the vignette, as
  a screen blend. The threshold falls with the dark, so a sunlit field never
  hazes and every torch, flame, spell and seam bleeds into the night.
  `Graphics.KEY_BLOOM`, off by default on Low. `bloom_shot` photographs it.
- **The boot splash is the studio splash's own dark, with no image.** The first
  thing a player saw was Godot's logo. `polish_check` holds the colour against
  `splash.tscn`'s background, so the handoff cannot flash.

**The twelve videos were studied from their transcripts, as of 2026-09-24.**
The first triage above was written from titles and chapter lists, because a
signed-out browser is refused YouTube's transcripts; the owner asked for the
real thing. `yt-dlp` fetched nine caption tracks, Whisper (`medium.en`, on the
GPU) transcribed the two with none - one of them a short whose auto-captions
YouTube had misheard as Arabic - and the 14-second electric clip has no speech
and was read from its frames. About 30,000 words, every technique checked
against the code by reading it. `docs/IDEAS_REVIEW_2026-09-24.md` is rewritten
from that, video by video, with the file and line for each.

**The reading held up, with one more gap and one refusal.** Nearly every
technique in the twelve ships here, several in a stronger form - the camera
shake is a modelled thunder and rumble rather than sampled noise. The gap:
**a big blow throws a real light** now (`Vfx.light_burst`). Brackeys animates
a light with every explosion and Le Lu puts one at a lightning strike "to tie
the effect into the world"; `Vfx.flash_at` is an additive polygon and lights
nothing. A meteor, a strike, a boss slam and a dragon's breath throw a
`PointLight2D` that decays, capped at `LIGHT_BURST_MAX` with the oldest giving
way, standing `LIGHT_BURST_HEIGHT` high so the towers - shaded by light
direction since the same morning - are lit from the side the meteor fell on.
Off on Low. `polish_check` holds the cap, the life, the Low switch and the four
call sites. The refusal is MrEliptik's acceleration and friction on the walk:
every telegraph here is answered by stepping out of a circle, and a tenth of a
second to start walking is a tenth of a second less to leave a slam's ring.
Recorded in the triage so it is a decision rather than an omission.

**And the method is recorded in the memory directory**, because the wrong
methods cost an hour: the browser's transcript panel, YouTube's transcript API
and the timed-text URL are all dead ends signed out.

**A charge into a pond skipped the rest, found 2026-09-24 by a red release.**
v0.56.0 failed on `mount_check` in CI and the same gate on the same commit
failed once and passed once here: the rammed body took nothing, its neighbour
took nothing, and the saddle was open. **The seventh coin toss this project has
shipped in a gate's clothes**, and the same shape as the first six: the charge
line was typed as (1500, 1400) heading right, the ponds are the seed's, and on
some seeds one lay under that line.

**Behind it was a real hole.** `_tick_mount` answered "may not stay mounted" -
deep water, the flood, death - with a bare `dismount()`, so a charge the water
took never went through `_end_ram` and rested nothing: a rider could charge
into a pond and be handed the saddle back with no cooldown, which is the ram's
whole price skipped. A charge ends through the one door every charge ends
through now, `_end_ram("water")`, and the gate accepts "water" as a reason a
charge ended. The harness asks the field where dry ground is (`_dry_line`,
`Battlefield.water_depth_at` every 32 units, the same reading the swimmer uses)
and charges there, for the body test and the edge test both. Run three times in
a row before the tag.

**A reach is an arc, and the frame governs the preset, as of 2026-09-24.**
Two of the owner's asks from the same brief - "the part of the circle aimed at
the enemy it attacked with smooth fading" and "auto settings detection and
configuration for all platforms and any device".

**The range ring draws only the part that faces what was shot at.**
`ranged_shot_fired` carries the shot's own direction, a tower's ring reads the
aim off where its shot went, and a body's off its `_target` every frame it is
followed. `CombatTells._arc` takes an `aim`: `RANGE_RING_ARC_SPAN` degrees on
it, each end feathered over `RANGE_RING_ARC_FEATHER` with a smoothstep - a
sector that ends in a cut reads as a slice of pie - laid over a wider, fainter
halo of the same colour so it reads as light on the ground. A shooter with no
aim to give still draws the whole ring, which is what keeps every gate that
reads rings reading. The three ring tints are a fifth more transparent.

**`QualityGovernor` measures the frame in combat and steps the preset**, only
while the player has never chosen one (`Graphics.is_automatic`), only on the
road after `GOVERNOR_SETTLE_SECONDS`, in windows of `GOVERNOR_WINDOW_SECONDS`:
two slow windows step down, twelve fast ones step up and never past what the
machine was judged for by name. **A frame cap the player set is not a
struggling device** - the slow line is the cap's own interval plus slack. The
step is remembered under `KEY_AUTO_PRESET`, never as the player's choice, so
the two cannot overwrite each other, and the settings screen's **Auto** hands
the choice back. It is said on the HUD once. On Low every third torch carries
a real light (`TORCH_LIGHT_EVERY_LOW`) and the rest still burn and pool - a
phone cannot afford a hundred lights. A look, never a fact: a preset moves
shadows, particles, bloom, shading and lights and not one number the fight
reads. `governor_check` drives `sample` with a clock of its own, because
headless frames cost nothing; **its first cut fed 250 ms "frames" as the
settle and the governor rightly read them as two slow windows** - the harness,
not the feature.

**Modular gear on the Warden's body is designed and piloted, not built, as of
2026-09-24.** The owner asked for character creation and customization "with
modular parts so that even wearing gear or weapons updates on the players
appearance". `docs/WARDEN_DRESS_DESIGN_2026-09-24.md` is the design; the
bound is the dye's - **a look may change nothing but how the Warden looks** -
and it adds nothing to the save, because which class a Warden wears is
derived from worn gear at draw time, as the set aura's colour already is.

**The recommendation is layered deltas on one shared skeleton, and the pilot
proved it buildable for about 90 generations.** The Warden was re-founded as
a PixelLab character from its own shipping south frame (identity kept in all
eight facings); a `create_character_state` keeps the individual **and the
pose** per facing; and two states walked through the same template in
`mode: "skeleton-v3"` land on the same pixels frame for frame (feet within
1-3 px, 0.70-0.76 IoU, the difference being exactly the plate and the helm)
**with the lantern, sword and banner kept** - where plain template mode
stripped all three, which is the mount lesson of 2026-09-17 again. So every
look class is one state, every state is animated through the same skeleton
templates, and a class's delta against the weaponless base is composited over
the body in lockstep. Ninety-six combinations from fifteen sheets a state.

Three things to know before spending on it: a state edit can disagree with
itself across facings (the Unarmed state kept the sword in two of eight - check
facing by facing, inpaint the stragglers); skeleton-v3 returns 192x192 and is
cropped by the union of the facing; and at 2-4 generations a facing the whole
wardrobe is a cycle's budget, so **weapons first**, armour and helmets next
cycle. The pilot character (`Warden (dress pilot)`) stays in the account as
the base. `docs/IMAGE_PROMPTS_CHATGPT_2026-09-24.md` is the companion list of
everything PixelLab should *not* make - paintings, the interface kit, store
art, icon sets the game has none of - for the owner to generate.

**Act X ran at 13 fps on the machine it was tuned on, measured 2026-09-24.**
The owner: *"run even the last few acts and peak pressure successfully at
60fps"*, and, watching it, *"it's getting 12fps on avg"*. `perf_check --act=10
--build` - forty level-8 towers on Act X's waves, the board `curve_report` says
a walked campaign holds - read **76 ms a frame** at 1080p on the RTX 3070 Ti,
`process` 96 ms, 950 hitches a minute; Low was 61 ms, and every `--off=` switch
moved it by less than the run-to-run noise. The cost is script and node churn,
not pixels.

**What the steady bisect saw before it died** (`perf_bisect --act=10
--settle=50`, the field held with the director stopped and the bodies
immortal): 42 bodies, **247 lights, 2,674 draw calls, 7,151 canvas items, 491
particle systems** at 90-99 ms. Read against the code: every walking body
re-chose its target *every frame*, each choice walked every tower on the field
twice through `all_towers()` (a fresh forty-entry array a call) and
`Tower.lane()` (a geometric search over the roads a call); every shot carried a
`PointLight2D`, two `Line2D`s, three polygons and a head sprite and shed a
sprite-plus-tween eighteen times a second; every impact spawned a sprite, a
forged sheet, seven shard `Line2D`s with tip sprites, a ring with a bloom
sprite and a flash, each with its own tween.

**The first cut, all gated green**: `ENEMY_RETARGET_SECONDS` - a body chooses
on a cadence with its own phase and at once when what it fought is gone;
`Tower._lane` decided once in `setup`; `Battlefield.all_towers()` rebuilt only
when a tower comes or goes; `LightKit`'s shot-light budget
(`PROJECTILE_LIGHT_MAX`, one counter for both projectile kinds, none on Low);
motes thinned by `JuiceDirector` and `Graphics.particle_scale`. A look and a
cadence, never a number: `enemy_siege_check`, `enemy_behaviour_check`,
`stagger_check`, `enemy_shot_check` and `tower_juice_check` read the same
fights.

**And the bisect itself had to be rebuilt to survive Act X.** Three runs died
under the table: the town fell (held now by `floor_hp`, the door every
long harness uses); a freed body was cast before it was checked; a wave's end
put the field into Preparation mid-table so the groups measured in it "saved"
forty milliseconds of bodies that had merely died - it holds the field steady
now; and then the **pause menu opened and its Leave button fired** - traced
through the director's one scene door (`WILDERHOLD_TRACE_SCENE=1` prints who
asked) - so the harness disarms the pause menu, unbinds the pause action,
stops the road and the sky, and refuses a paused tree. `perf_bisect --act=N`
and `perf_check --act=N` stage the road through the same statics
(`stage_late_act`, `build_late_board`) so both tools stand on one road. **A
windowed measurement on the owner's screen is a measurement the owner can
end** - and did, twice, by pressing Escape on a window that had covered what
they were doing. Run them when the screen is free, or not at all.

**One real bug fell out of it**: `CombatTells._enemy_aim` asked `target is
Node2D` before asking whether the target existed, so every following ring
printed an error a frame from the moment its body's target died - sixty lines a
frame on Act X. Validity first; `tower_juice_check` frees a body's target under
a followed ring now.

**The second cut is the ink, as of the same date.** The owner, of the same
build: *"nor is it aesthetically appealing as projectiles are not polished"*.
Both halves of that were one thing. A spark was a `Line2D` with a tip sprite
and two tweens; a ring a `Line2D`, a bloom sprite and two tweens; a flash a
polygon and a tween; a tower's shot a body node, two `Line2D`s, three
polygons, a head sprite, a light and a shadow, shedding a sprite-and-tween
eighteen times a second - and a `Line2D` with a round cap *reads as a pipe*,
which is what "not polished" was.

**`VfxInk` is one canvas for the short-lived light of a fight**: sparks,
rings, flashes, motes and rays are records in arrays, advanced once a frame and
handed to the renderer as one triangle array a kind, capped a kind by dropping
the oldest (`VFX_INK_*_MAX`) - which is what `VFX_MAX_LIVE` did to the node
layer. No node is born or freed for any of them. Every shape has a solid middle
and a rim at zero alpha and the canvas blends additively, so a spark over a
torch pool brightens it - the rule `BloodInk`, the menu fire and the swim sheen
each ended at. It processes always and, while the tree is paused, advances only
the records flagged `finish_when_paused`, which is what `lightning_lifetime_check`
holds. `Vfx.spark`, `ring`, `flash_at`, `rays`, `pellets` keep their signatures
and write records; `Vfx.mote` is the new door a shot sheds through.

**And a projectile draws itself.** `Projectile` is one node and one additive
child now: the head is painted art or the element's own silhouette with a soft
rim, the ember of a high tier turns against it, a lob's shadow is drawn on the
ground under the picture, and the ribbon is `InkRibbon` - a tapered, feathered
strip along the shot's history with a white-hot filament inside it, **the same
geometry for the tower's shot and the enemy's**, so the two cannot drift apart
the first time either is tuned. What remains as a node is the light, on the
shared budget. `projectile_tier_check` still reads a wider, hotter shot per
level and `tower_juice_check` still reads every style's damage through it,
because nothing about a shot's flight or its hit moved: a look, never a fact.

**The third cut is everything else a hit stood up, and three budgets, as of
the same date.** The owner: *"optimize our game perfectly with all of the best
techniques to help players get such a high fps rate even 144+"*. The Act X
measurements said where the frame was, and it was not one thing:

    clean            process 96.5 ms
    cast shadows off process 62.3 ms   (-34)
    particles off    process 62.0 ms   (-34)
    lights off       process 56.1 ms   (-40)
    Low              process 38.5 ms

**`process` includes the renderer.** `Performance.TIME_PROCESS` is the main
loop's iteration, and in the Compatibility renderer `RenderingServer.draw`
runs inside it on the main thread - so the 34 ms that cast shadows cost is
canvas work, not script, and a script bisect would never have found it.

- **A hit allocates no node.** A damage number was a `Label` and five tweens;
  a muzzle a polygon, a sprite and three tweens; an impact a sprite, a
  material and two tweens; a forged sheet a sprite, a material and a tween.
  All are records now, on a **second, flat** `VfxInk` for what is paint
  (numbers, impact and muzzle art) beside the additive one for what is light,
  because additive text over a bright ground disappears. `forge_check` reads
  the records back where it read sprites - the invariants (a take, a turn, a
  flip, a size wander, nothing at zero density) are unchanged and a flip is a
  negative axis on the record's scale.
- **Cast shadows are the nearest few.** `LightKit.budget_shadows` ranks every
  shadow light by distance to what the camera watches and keeps
  `SHADOW_LIGHT_BUDGET_HIGH` (8) or `_ULTRA` (14), re-ranked on
  `SHADOW_BUDGET_INTERVAL` from the battlefield and the raid arena. A hundred
  torches each cast, and a shadowed light the renderer can see draws every
  occluder four times and samples its map under every lit pixel; what the
  player sees is the torches beside the Warden casting, which is where they
  were looking. Ultra keeps more than High because `live_settings_check` holds
  that Ultra promotes torch shadows; an unlit light takes no slot.
- **An emitter the camera cannot see rests.** `ScreenCull.sees` is `Flame`'s
  own on-screen test moved to one place, and a flame, a tower's air
  (`TowerAura`) and a camp fire hide their emitters off screen. Hidden, never
  stopped: `CPUParticles2D` skips its whole update while not visible in the
  tree, nothing restarts, and a torch panned onto is mid-life. Two hundred of
  the four hundred and ninety-one emitters on Act X were torches.
- **The foliage's idle step reaches only the view.** Every painted plant
  breathes on three frames, so one step wrote about two thousand textures at
  once, four and a half times a second - a 4-6 ms spike on a clock nobody
  could see. `Foliage._step_idle` takes the world window
  (`ScreenCull.world_window`) and a plant's place is read once and kept.
- **The physics tick follows the display.** The Warden moves in
  `_physics_process`; at sixty ticks a 144 Hz screen watched a hero stepping
  at sixty while the road moved at 144. `Graphics.physics_rate_for` is the
  display's refresh capped by the frame cap, inside `PHYSICS_RATE_MIN` and
  `_MAX`, with `PHYSICS_STEPS_PER_FRAME_MAX` so a slow frame catches up rather
  than slowing the clock. Headless there is no display and the rate is the
  floor, so no gate measures a different game. The cap offers 165 and 240.

**The bound is the one every feel change here is held to: nothing about damage
moves.** Every one of these is a look, and `frame_budget_check` drives each -
forty hits and an empty effects layer, twenty lights and the nearest eight, a
flame far off the screen resting and waking, two plants and one window, and
the tick over every shape of display - rather than reading a constant back.

**And the field is asked once a frame for what is on it.** `act_census`
(headless: what an Act X field hands the renderer, by owner) found twenty-three
drops each carrying a lamp and a hundred and eighty pieces each walking the hero
group every frame; forty towers, every spell, arrow, barricade, companion and
animal walked the enemy group every call to `enemies_near`. `EnemyField.living_bodies`
gathers the roster once a frame and `LootDrop._alive_heroes` the heroes;
`LOOT_LIGHT_MAX` is the shot budget's rule on the lamps, the first to land
keeping theirs and a piece leaving handing its lamp on. No behaviour moved: a
body that starts dying after the roster was taken is still refused per call.

**Measured, then bisected, then measured again, as of the same evening.** The
owner gave the screen and `perf_check --act=10 --build` read **58.9 ms
(17 fps)** after the three cuts above, against 76.3 before them - and its new
split said the renderer was **7.7 ms CPU and 7.7 ms GPU of a 55 ms process**.
The frame was script, and the `--off=` deltas that had said shadows and
particles were a third each were single samples of `TIME_PROCESS` taken at
report time, which is one frame's worth and reads as noise. `perf_check`
averages its split over every sampled frame now and measures the renderer's
own clock (`viewport_set_measure_render_time`).

**The bisect runs headless now**, because script time costs the same without a
renderer and a windowed one takes the owner's screen for minutes - they quit
the first one - and it is drift-proof: each script group is measured on, off
and on again against its own neighbours, because a table takes minutes and the
frame moves under it; the second run compared every group with a baseline two
minutes old and named nothing. It also says when the field was held in a
breather, which measures idle towers. What it named, on a 56 ms frame with 38
bodies held:

    tower.gd     11.9 ms   40 nodes
    enemy.gd      7.6 ms   38 nodes
    vfx_ink.gd    4.3 ms    4 nodes
    flame.gd      1.6 ms  220 nodes
    floor         6.9 ms   every node's processing off: the engine's own frame

- **A tower chose forty times a second and sorted every body twice per
  comparison.** The lean tell called `_acquire_targets` every frame beside
  the shot's own call, and the sort's comparator scored both bodies on every
  comparison, each score walking a body's children for its `Health`. The
  choice is made at most once a frame and shared; the candidates are scored
  once and then sorted; the lean re-asks on `TOWER_AIM_INTERVAL`; a body's
  health is the field it already has; the impact rim is written only while it
  moves.
- **Every walking body scanned every body for a howler every frame**, from
  `current_speed`. It asks on `ENEMY_HOWLER_SENSE_SECONDS`.
- **The ink canvases redraw on `VFX_INK_HZ` and draw their last frame.** They
  never had: a canvas that only redrew while records moved left the final
  picture standing until the next effect arrived - which is half of what the
  owner saw as the projectiles being *"really messed up"*.
- **The other half was the ribbon.** `InkRibbon` fell from full at the spine
  to nothing at the ribbon's width, which on a five-unit shot at play zoom is
  a hairline; photographed, every shot was a thread from the tower to the
  body. It is a solid core with a feather either side now, as the `Line2D` it
  replaced was. The trail was kept by point count, so at twenty frames a
  second it spanned the whole flight and at 144 it was a stub: a point every
  `PROJECTILE_TRAIL_STEP` of travel, trimmed to `PROJECTILE_TRAIL_LENGTH`,
  for both shot kinds. And the additive child drew *over* the head (a child
  draws after its parent) and its glow was not turned with the flight; it is
  under the head, absolutely, and turned.
- **Bloom came down**, night most of all (`BLOOM_STRENGTH_NIGHT` 1.25 to
  0.70, the night threshold 0.16 to 0.30), on the owner's report that it was
  too strong in places.

**Measured after: 22.4 ms a frame (45 fps), p99 50 ms.** The headless field
frame went 56 ms to 11, of which the engine's floor is 6.9 - so the script is
a few milliseconds now and the per-script table is inside its own noise at
that scale. The p99 is the hitch ledger, and the ledger says what the hitches
are:

    hitch 86.5 ms at 20s  nodes +6    textures +3072 KB
    hitch 84.2 ms at 14s  nodes +10   textures +3072 KB
    hitch 81.5 ms at 16s  nodes +13   textures +3588 KB
    hitch 74.5 ms at 83s  nodes +244  textures +9216 KB

**The same three megabytes, read off the disk every few seconds.**
`ResourceLoader` caches a texture only while something holds it, and the
fight's art - a shot's head frames (loaded per projectile in `_ready`), an
impact's frames, a muzzle's, a forged sheet (loaded per play) - is held only
by the record or node playing it, so between one volley and the next it was
freed and the next volley read and uploaded it again. `GameData._load_sequence`
and `Vfx._sheet_texture` keep what they load for the process now, and
`Vfx.warm_art` loads every element's shot, impact and muzzle art and every
forged sheet before the act, from `RosterWarmup.warm_act` - which also warms
the **veterans** and the **camps' own breeds and lords** now: the 244-node,
nine-megabyte hitch was a wave of invaders no region's roster names. The
sheets are skipped headless, where nothing draws them and a hundred gates
would each pay to load sixty megabytes of light.

**And two scopes were processing while hidden.** `_show_scope` hid the town
and the beast and disabled neither; the raid and the rift were disabled when
hidden since they were built. The walk's frames, its backdrop, its route and
the town's plots ticked every frame under the battlefield for a camera that
was elsewhere. A hidden scope's `process_mode` is `DISABLED` now, and the
battlefield's never is, because leaving the fight has to cost.

**And every number before this one was taken at 1440p.** The project opens
fullscreen at the display's native size and `perf_check` never pinned its
window, so the GDD's "60 FPS at 1080p" had been measured on the owner's
1440p monitor all along. It pins 1920x1080 windowed now and prints the size
(`--native` measures the display as it is). At 1080p, after the caches and
the scopes: **21.5 ms (46 fps), GPU 6.3 ms, 1,075 draw calls, three texture
hitches in ninety seconds.** The GPU barely moved from 1440p to 1080p, and
`--off=lights` and the Low preset moved it by nothing at all - so its cost
is per draw call, not per pixel or per light, and the render CPU is the same
draw calls being submitted. **The lever now is the number of things drawn.**

**The torches were the first**, at fifteen canvas items each: the ironwork
(four polygons and the coals) is one `_draw` on the torch, the flame's glow
is drawn by the flame on its own additive material rather than a sprite
under it, and the rekindle wisp exists only while a relight is held. Canvas
items 5,611 to about 4,800; **20.1 ms (50 fps), 998 draw calls.** What the
census names next: the health bars at three items each, the nine hundred
painted plants sorted one by one against the bodies, and a `ShaderMaterial`
per loot drop.

**A frame is profiled by system, and the heavy stretch was the blood, as of
2026-09-24 (night).** The hitch ledger's worst eight were all at 32-33
seconds, and a headless trace of that window - every frame with its cost,
what arrived, and every bus signal fired in it - read **20-36 ms a frame
against a 9 ms road either side**, with three to sixteen `camera_impact`
emissions a frame. A blow is where the impact is announced, so the stretch
was several hundred blows a second, and something in the blow path cost a
millisecond each.

**It was `Vfx.blood`, which stood a node up per blow.** `BloodBurst` was the
one hit effect the ink pass never reached: five to nine motes on arcs, each
rebuilt as a lobed blob in GDScript every frame for half a second, and every
landing droplet queuing a repaint of all hundred and forty ground marks. Five
hundred of those nodes were alive at once. `BloodMotes` is one canvas for
every drop in the air, on packed arrays, drawing the flames' own soft dot
stretched along each drop's velocity - a three-pixel drop cannot be told from
a lobed fan, and the ground keeps the lobes where a mark is large and looked
at. `BloodField` repaints on its own `REDRAW_HZ` and never per mark. Capped at
`VFX_BLOOD_MOTES_MAX`; `blood_vfx_check` and `frame_budget_check` count
records where they counted nodes.

**And a bisect could never have named it**, which is why `FrameProfile`
exists beside it: the bisect holds the field with its bodies immortal, so it
never dies, never drops loot and never sees the stretch. `perf_check --trace`
turns the profile on, every system's tick or draw is wrapped in a four-line
timer (`_process_measured`, bucket `enemy`, `tower`, `blow`, `ink_draw`,
`fog`...), and each trace frame prints its buckets. It cost one
`Time.get_ticks_usec()` a site when off. What it named after the blood:

    blood_air   4.56 ms   every frame, the cap full
    fog         5.5 ms    ten times a second
    trample     2.8 ms    fifteen times a second

**The fog re-stamped a hundred and forty circles that never move and then
walked every cell.** Towers, the town and the torches are flagged `static` by
the battlefield now; `FogOfWar` stamps them into a layer once and again only
when their set changes - a torch's reach quantised to whole cells, because its
strength drifts every tick and a layer rebuilt for a pixel is the full stamp
back - and a tick copies that layer, stamps the few that move over it, and
touches the bytes only in the cells a mover lit. The explored layer and the
bytes are kept beside every stamp, so the pass over all 7,569 cells is gone.
`reveal_all` writes the bytes too, which it never did.

**The trample decayed and republished thirteen thousand cells to move a few
hundred.** `TrampleField` keeps a live list; a cell that decays to nothing
writes its neutral bytes once and leaves it.

**Measured, headless, on the same seed and window: 20.1 ms mean and 88 frames
over 20 became 12.9 ms mean, 17.7 worst and none over 20**; the whole run 11.3
to 9.5 ms, p99 22.2 to 13.9. Script is about 6 ms of that frame now - bodies
1.5, towers 1.1, the animals 0.7, the ink 0.7, the blows 0.5 - and the engine's
own floor is the rest. **`TIME_PROCESS` is each second's worst frame**, not an
average: `perf_check`'s split line said "process 30 ms" beside a 20 ms
average frame and the label now says what it is. The ledger also says whether
its hitches are a beat and what changed on each hitch frame, because three
hundred hitches in ninety seconds is either a clock or a burst and the eight
worst could not tell.

**Not yet re-measured on the renderer.** Every number here is headless; the
windowed frame at 1080p was 20.1 ms before these three cuts and the next
number wants the screen for ninety seconds.

**And the idle shape, twice more.** With the profile split one level down,
two thirds of the towers on Act X were past their cooldown, scanning the
roster and finding nothing, and scanning again on the next frame - 0.66 ms a
frame of scans that found nothing; a tower with nothing in reach asks again
after `TOWER_IDLE_RESCAN_SECONDS` now, and the tower's tick went 1.17 ms to
0.58. And `_pick_target` ran twenty-two times a frame across forty-four
bodies, because `or _target == null` had every body *between* foes - and
every camp body - choosing again every frame rather than on
`ENEMY_RETARGET_SECONDS`; only a target freed under a body is answered at
once now. **"Nothing found, so try again next frame" is the shape to look
for in any per-frame tick**: the cadence that was added for the found case
does not cover the empty one. The run reads 9.0 ms headless, p99 15.

**The renderer's half, measured, and the floor that was a sleep, as of
2026-09-24 (late).** Three findings from the same evening, each of which
corrected an earlier number in this file.

**The 6.9 ms "engine floor" was `low_processor_mode_sleep_usec`.** With
nothing to draw, Godot sleeps every frame out to that setting's default of
6,900 microseconds, so every headless frame lighter than that read as 6.90 -
and a floor ablation that freed the whole field, class by class, printed
6.90 on every row. With the sleep off, "every node's processing off" is
**0.19 ms**: the engine idles at nothing and a headless frame is script, full
stop. Both headless tools zero it now, and every headless average recorded
above this paragraph carried that floor. The heavy stretches were never
floored - a frame heavier than the sleep is not slept - so the cuts they
led to stand.

**And every windowed number before the evening was taken on a 60 Hz
monitor.** `perf_check` put its 1080p window at screen coordinates (40, 40),
which on this machine is one of two 60 Hz displays beside the 180 Hz one,
and the tool's own note said so in the log: the compositor rounds any
windowed frame over 16.7 ms up to 33.3 whatever vsync reports, so the
"average" was a quantisation. It pins to the fastest screen now and prints
which. On the 180 Hz screen, honestly measured, Act X read **20.8 ms (48
fps), the heavy stretch 30.7 ms**, before the evening's cuts.

**`perf_bisect --visuals` is the renderer's own table**: a class of thing on
the screen is hidden, the frame measured on, off and on again, and the
saving printed. It said what the script profile could not, and it corrected
a plan: the 725 painted plants I was about to fold into bands (and pay for
in sorting) cost **0.4 ms**; the flames cost 2.7-3.6 and the two ink
canvases 2-4, because **a triangle array handed to the Compatibility
renderer is a new GPU buffer on every redraw**. A `draw_mesh` is uploaded
once; a texture rect is an instance in a batch the renderer already keeps
(a probe drew five hundred rotated quads in three draw calls). So the flame
ring is forty-eight retained meshes, sparks, motes and flashes are quads of
the flames' soft dot, torches carry no smoke emitter (`TORCH_SMOKES`: a
wisp nobody can see, and a hundred of the four hundred and fifty particle
systems), the tells repaint on `RANGE_RING_REDRAW_HZ`, a torch asks whether
a hero is near on `TORCH_HERO_SAMPLE`, and a body writes its shader uniforms
only when they change. Read the table in aggregate over runs: the held
field's load moves second to second and a single row can be a wave-state
shift (one run printed the minimap at 16 ms).

**Measured after, windowed at 1080p on the 180 Hz screen, High, forty
level-8 towers on Act X: 17.9 ms average (56 fps), p99 27.1, the heavy
stretch 23.6 ms, five hitches a minute** - from 20.8, 34.3, 30.7 and
49-78. What a heavy frame is now: about 9 ms of script (bodies 1.8, towers
0.9, the hero's physics ticks 0.55, the tells 0.55, the animals 0.45, the
look 0.45, the ink 0.45, sound 0.4), the viewport's own 5.2 ms of render
CPU and 4.4 of GPU beside it, and some 9 ms of renderer work outside the
viewport's measure - culling, sync, lights, particles, present. **A steady
sixty at Act X's peak needs about seven milliseconds more**, and the
ablation names where: torches and their pools (1.5-3), particles (1-3),
the ink (2-4 under load), the tells, the bars, the ground blood - and on the
script side the body's tick and the tower's. The plants are not on the list.

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

Save slots (2026-09-22) did not move that file and must never move it. An
existing account **is** slot 0, derived rather than migrated, and every later
slot is a new file beside it; the backup rule above holds per slot, under names
that resolve to exactly these on slot 0. `res://tools/save_slot_check.tscn`
holds the historic path as a literal — if it ever fails on that line, the line
is not what needs changing.

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
