# The ideas documents, triaged

The owner supplied two ChatGPT brainstorms (`ChatGPT_More_Ideas.md`,
`ChatGPT_More_Ideas_2.md`) and asked which of it Beast Road should adopt.

This is that answer, written against the code rather than against the pitch.
Roughly sixty ideas, in four buckets: **already built** (a surprising number),
**taken now**, **worth building next**, and **refuse**.

The second document contains its own best advice and it is repeated here because
it is right:

> New ideas must either improve retention, polish, or fix an obvious weakness —
> or they go into the post-launch backlog.

Beast Road is at v0.10.1 with a closed loop, 76 guard gates and a released
build. The bar for adding a system now is not "would this be good" — nearly all
of it would be. It is **"does this multiply what is already here, and can it be
finished."**

---

## 1. Already built — do not build these twice

The single most useful output of this review. A third of the document describes
things this game shipped months ago under other names, and an agent handed the
document cold would have built them again.

| Proposed | Already in Beast Road |
|---|---|
| Branching Road Decisions | **Crossroads.** Roads are drawn per segment with authored types, and the one not taken disappears. `data/roads/` |
| Shared co-op decisions with visible votes | **Crossroad voting**, including the partner's pick flashing on the card. `crossroad_screen.gd` |
| Enemy Affixes (Armored, Frenzied, Volatile…) | **Eight affixes**, rolled onto ordinary enemies. `data/affixes/` |
| Difficulty pacts / self-chosen modifiers | **Road difficulties** (Guarded / Contested / Perilous) *and* campaign tiers (Normal / Nightmare / Hell) |
| Shareable run seeds | **On the main menu.** "RUN SEED — random, or enter 9 digits" |
| The Run Chronicle (a story, not numbers) | **`run_recap.gd` + `chronicle_goals.gd`**, 14 authored deeds |
| Feat-based unlocks | **Objectives**, 14 of them, plus the codex |
| Day/night changing strategy | **`DayNight` autoload**, with torches that matter and nocturnal wildlife |
| Traps as map weapons | **`data/traps/`**, placed and paid for |
| Destructible battlefield | **Barricades**, raised, damaged and broken |
| Discovered shops / wandering merchants | **Travelling merchants who settle**, three of them, with residency as progression |
| Mercenary camps → hireable survivors | **Captives / Oathbound**, and `data/captives/` |
| Treasure creatures, wildlife encounters | **Wildlife with an ecology**, predators and prey, bondable as Spirit Companions |
| Perk shrines → persistent run perks | **Relics** (27) socketed in the Town Hall |
| Card-style upgrade choices | **Disciplines** — a per-road draft of three trees with depth gating, plus synergies |
| Boss modifiers | **`boss_director.gd`** |
| Optional creep camps — "leave the line for a prize" | **Raids.** The battlefield freezes, you hit a camp off-road, and you extract with what you can carry. This is the exact tension the document names, and it is a v4 LOCKED pillar |
| Map-specific objectives instead of identical waves | **`data/objectives/`**, 14 authored |
| Hero and base needing each other | **The core loop.** Kills pay for towers, the horn and Command are in-combat agency, tending and repair cost run currency |
| The Road Director pacing a run | **`wave_director.gd`**, plus weather and regional polish |
| Elemental identity across towers | **Four elements and the fusion system** (v4 §3.4) |
| Combat juice | **`hitstop.gd`, `Vfx`, blood fields, actor polish, weapon trails** |

**Caveat worth stating plainly:** "exists" is not "is as good as the pitch". The
Road Director in the document is smarter than `wave_director`; the proposed
elemental *reactions between towers* is genuinely absent even though elements
are not. Those are listed below as depth work, not as new systems — which is the
distinction that keeps scope honest.

---

## 2. Taken now — Road Omens

**Built this session.** When an act boss falls, three portents are offered and
one is read; it keeps for the rest of the run and stacks with the ones before.
Ten authored, gated by `omen_check`, recorded in `CLAUDE.md`.

Why this one out of everything:

- **It multiplies rather than adds.** Both halves resolve into `Modifiers`, the
  flat table relics already feed, so a portent reaches every tower, wave, wallet
  and wall without a single system downstream learning it exists.
- **It fixes a real weakness.** Road difficulty was a scalar chosen fresh each
  crossroad and forgotten by the next one. Nothing accumulated, so no run had a
  shape you could describe afterwards. Three stacked portents give a run a
  sentence: *the night never lifted, they came in fours, and every one of them
  was worth something.*
- **It is worldbuilding, not a modifier list.** Each carries a portent line —
  "the tracks come in fours now, and they are not going around us" — which is
  the owner's own framing for this game: the Road is always telling you
  something. That line is the content; the numbers are the mechanism.
- **It was finishable in one sitting**, which at v0.10.1 is the deciding
  property.

---

## 3. Worth building next, in this order

Each of these is cheap *because* of what exists, and each was chosen over a
flashier neighbour for that reason.

**1. Elemental reactions between towers.** Water + Cold → Freeze, Fire + Wind →
Firestorm, Earth + Lightning → Sunder. The four elements and the fusion system
already exist and are already tuned; reactions make *adjacency* a decision,
which turns the whole tower roster combinatorial without a single new tower.
This is the highest-value item on the list and it is not small — it needs a
reaction table, a gate that proves every pair is reachable and none is strictly
best, and VFX for each. Do it as its own piece of work.

**2. The Last Stand.** When the city is about to fall, do not end the run: light
everything on fire, change the music, and give thirty seconds. Clear the field
and the city survives at 1 HP. Almost free — the town's health, the music player
and the wave director all exist — and it converts the worst moment in the game
into the one people talk about.

**3. Perfect-wave momentum.** A wave taken with no city damage builds a meter;
break the streak and it resets. Tension while strong is the thing a tower
defence loses last, and this is one counter and one HUD element.

**4. Treasure creatures.** A rare beast that flees, and explodes into resources
if you can drop it in time. The wildlife system already spawns, flees and can be
struck; this is a data variant and a drop table. Pure delight per unit of work.

**5. Rare "what was *that*" events.** One in several hundred: the horizon
darkens and something enormous crosses the background without attacking. No
mechanics at all. This is the cheapest item on the list and the one most likely
to be posted about.

**6. Enemy formations.** A Warden escorting four Bogkin reads as intelligence
without any AI being written — the spawner picks squads rather than individuals.
The morale system already makes a champion's death matter, so formations and
morale would compound.

---

## 4. Refuse, or defer past 1.0 — with reasons

Not because they are bad. Because they are a different game, or they break a
bound this project has already decided.

- **Road Cards as a second upgrade layer.** Disciplines already *are* the card
  draft, with trees, depth and synergies. A second parallel pool of "+15% melee
  damage" cards would compete with it for the same moment and the same attention,
  and the honest fix for "the tree is not exciting" is a better tree.
- **Augments that change how the hero works** (Twin Shot, Don't Stop, Executioner).
  Genuinely exciting, and this is what discipline *synergies* were built to be —
  stage two landed on 2026-09-10. Grow that rather than starting a third system.
- **Build evolutions** (Earth tower → Colossus or Geomancer). This is the fusion
  system with a different name. Fusion is v4 LOCKED and signature.
- **Prestige cosmetics, tower skins, banners, emblems.** Post-1.0. It is a
  content pipeline, not a mechanic, and it needs art capacity that is currently
  the binding constraint.
- **Outposts, faction territory control, spawn manipulation by gate.** These are
  an RTS layer. Beast Road's answer to "where do enemies come from" is *the four
  roads*, and it is deliberate and tuned. §54 cut party rosters for the same
  reason.
- **Pack-a-Punch / Ascension Forge.** Weapons already upgrade through levels and
  gear already has five rarities. A third weapon-power axis is a third scale
  nobody is tuning against — the same objection that bounded spirit traits.
- **Ultimate ability milestones, hero ability branches.** Real scope, and it
  overlaps disciplines. If the hero needs more identity, that is a discipline
  question first.
- **Safe rooms, power-on infrastructure, mystery boxes, wall buys.** These are
  Zombies' *map* grammar. Beast Road's map is a road that moves; a room you hold
  is the opposite shape of level.
- **NPCs remembering how you died.** Lovely, and it is `chronicle_goals` plus
  conditional lines. Cheap enough to be worth doing — but it is polish for a
  game that is otherwise finished, so it belongs in the last pass, not this one.

---

## 4b. The three the document itself picks — and one correction

The Warcraft III section names optional creep camps, forward outposts and
neutral map objectives as the three that would suit Beast Road best, on the
grounds that they give a player reasons to leave the defensive line.

**The premise is right and one third of the answer is already shipped.** Raids
*are* the creep camp: the battlefield freezes exactly as it stands, you go off
the road to hit a camp, and you extract with what you can carry — with a partial
extraction window and a chieftain climax. That is the "the next wave is coming
but there is a three-skull camp over there" tension, built, tuned and locked in
v4. What raids do *not* have is the document's **difficulty signalling** — a
readable "this one is too big for you yet" before you commit. That is a small,
worthwhile addition to something that exists, and it is a better use of the idea
than a second off-road system beside it.

Auras — stand near this tower and gain something — are the other item from that
section worth taking. They make *position* matter in a game where towers are
already placed deliberately, they suit co-op formations, and relics already
resolve through `Modifiers`, so a proximity aura is a small, bounded addition
rather than a system.

Forward outposts and faction territory stay refused, for the reason in §4: they
are an RTS layer, and a road that moves cannot have a second base on it.

## 4c. The Zombies "map opens up" idea

The strongest single idea in that section is that opening a route should be a
trade — more access, more exposure — rather than pure progress.

Beast Road already spends this currency somewhere else: **roads open one at a
time as waves arrive**, and each new road is exactly "more to defend". The
opening was measured against this deliberately (see `CLAUDE.md` on starting
capital). So the pattern is present and the escalation is already tuned.

What is *not* present is the player **choosing** to open one early for a reward.
That is a real idea, it is compatible, and it would be a small change to the
crossroad — but it changes the wave-pressure curve that three acts are tuned
against, so it is a balance project rather than a feature, and it belongs after
elemental reactions rather than before.

Mystery boxes, wall buys, safe rooms and Pack-a-Punch stay refused for the
reason in §4: they are the grammar of a map you hold, and Beast Road's map walks.

## 5. The thing the document is most right about

> Make systems collide.

Beast Road already has an unusual number of systems that *could* touch and
mostly do not: wildlife and companions, morale and formations, weather and
elements, the Ledger and the loot economy, disciplines and gear. Elemental
reactions (item 1 above) is the highest-leverage collision available, and it is
the one to spend the next block of work on.

The second-most-right thing is the budget advice in the same document: this is
the finishing month, and the correct answer to most of the list is *Season 1*.
