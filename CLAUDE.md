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

So a thousand waves needs one of: more build spots (the map is hand-authored), a
longer tower ladder (a new power scale, refused eleven times), or **waves towers
do not answer**. The third is the real answer, and it means the wave-type library
*is* the thousand waves - siege, sabotage, caravan, rescue, holdout, ritual,
hunt, calm. **Owner ruling, 2026-09-15: build the library first, then set the
count by measuring what it supports.** A count set first and filled in later is
how an act becomes a hundred repetitions of one loop.

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
