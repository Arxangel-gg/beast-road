# Wilderhold - the tutorial

> Drafted 2026-09-17 against every shipped player-facing string, then
> reviewed adversarially against GDD section 57, act integrity and the
> shipped lore. **Nothing here is built yet and several points need an
> owner ruling - they are listed at the end.**

---

# The Walk — Wilderhold's guided tutorial

*A beat sheet. Owner brief 2026-09-17. Corrected against the shipped code on
2026-09-17; every claim below that names a file, a constant or a shipped string
was read rather than remembered.*

---

## 0. What this is, in one paragraph

A single narrow valley — the last hold, its farmland and its forest — walked
once, west to east, at night into dawn. Eighteen stops. Each teaches one thing
and opens the path to the next. The first thirteen are on the valley floor. The
next four are up on Yuri's flank, where the valley's lesson becomes the game's:
four roads, a wall, a tower, a wave. The eighteenth is the chain. It ends with
Yuri pulling his foot out of the ground and taking a step.

It is not a new engine. It is a map, one resource, a grant ledger, a new pair of
doors on `GameDirector`, and a gate.

---

## 1. Eight things the first draft of this design got wrong

At the top rather than buried, because each is a fault this project has already
paid for once and the next person here will be tempted by the same shortcut.

**1. Yuri has not lain down.** That is a shipped string, verbatim: the other
Worldstriders "were caught, chained and ridden into the earth by the
Chainmaker's host, or simply lay down somewhere far from any road and were
forgotten. **Yuri has not lain down.**" A tutorial whose whole ending is the
beast *getting up* falsifies it in the most important beat the game has.

**Yuri is standing.** The Host got a chain on him and did not finish; the cuff
is on a foreleg and the anchor is driven into the valley floor. He cannot walk.
He has not lain down. The ending is a foot coming free, not a body rising — and
every line that said "lying still", "could not get up" or "the beast stands up"
is rewritten below. The fiction is *better* for it: a failed chaining is why he
is the last one, and the valley grew up around a beast that was already there.

**2. There are eight gear slots, not three.** `GearData.Slot` is `WEAPON,
ARMOUR, CHARM, HELMET, GLOVES, BOOTS, RING, AMULET`. A draft that teaches "three
things are worn" puts a false rule on the screen where a new player learns the
rule, and then builds a design argument ("two empty slots is the lesson") on
arithmetic over a number that does not exist. It is seven empty slots.

**3. The Walk must not be a `GameDirector` run.** "A run with a different
layout" is the right *shape* and the wrong *door*. Read what the two existing
doors actually do:

- `start_run` calls `MetaState.clear_expedition()` on any road not resumed — so
  replaying the Walk from the Hold **destroys a veteran's banked front**, five
  hours of road, silently. It also calls `RunState.reset(true, …)`, which
  **consumes the Treasury cache and the Sigil starting bundle**
  (`RunState.gd` ~553), and withdraws the party from the co-op directory.
- `_settle_run` writes `runs_started`, `runs_won`, `act3_cleared`,
  `best_distance`, `total_enemies_killed`, `highest_act`; awards Tools and the
  roster tower they buy; awards a Sigil on victory; completes Chronicle
  objectives and pays their Tools; publishes to the leaderboard; runs
  `check_achievements`; banks the Treasury cache; and calls `save_game`.

Every one of those is something §6 promises does not happen. The Walk gets
`GameDirector.start_walk()` and `end_walk()`, `RunState.walking` is set for its
duration, and `_settle_run` returns on its first line while it is true.

**4. `mark_tutorial_done` has two call sites, not one.** The coach's is
`tutorial_coach.gd:194`, on `CROSSROAD_REACHED`. The second is
`GameDirector.gd:541`: `if RunState.wave_number >= 6: MetaState.mark_tutorial_done()`.
A Walk that settles a run, or that runs six waves, unlocks co-op at its own
ending — in direct contradiction of the brief, silently.

**5. Granting one spell makes the hero weaker.** `RunState._equip_starting_spells`
builds its pool from `MetaState.unlocked_spells`, **and falls back to the entire
spell library when that list is empty**, then takes `Balance.STARTING_SPELLS`
(2). A new account today therefore starts every run with **two** spells. Grant
exactly one and the pool becomes that one spell and the hero starts Act I with
**one**. The grant intended as a gift is a 50% cut.

`unlocked_spells` is also written in exactly one place today —
`GameDirector._pay_out_unlocks`, `if victory:` — so it is a summit payout list,
not a horizontal shelf. **The spell grant is cut.** The Walk teaches the two
spells the hero already starts with.

**6. The starting weapon cannot be handed over at stop 11.**
`MetaState._seed_starting_gear()` runs inside `_ready()`, at launch, before the
menu exists; it appends `coalpaint_edge` to the stash and equips it. The weapon
is already worn before the Walk begins. Its flag is *deliberately* not
idempotent — the comment says so — and deferring the seed means editing the
account baseline path so that a crash mid-Walk can cost a player their only
weapon. **The Walk narrates a weapon the hero already has.** That is all it can
honestly do, and it is enough.

**7. `Preparation` is not a hazard-free phase.** Only *hostile wildlife
arrivals* are suppressed, and only at wave zero
(`Wildlife._hostile_arrivals_allowed`). Camps sleep on the phase change
(`Camps._on_phase_changed`). **The earth's events are not phase-gated at all** —
nothing in `wrath`, the weather, the wildfire, the quake, the funnel, the meteor
or the dragon pass asks `is_preparation()`. Wrath opens at its floor so it is
unlikely, and "unlikely" is a coin toss wearing a gate's clothes; this project
has shipped four of those. The Walk holds the earth quiet explicitly and the
gate asserts it.

**8. The valley's animals must be placed, not arrived.** Wildlife enters from
the map's arrival point and walks in — which is how a newborn once ended up
fifteen hundred units off the edge and a family could not form. Stop 3's deer
and the rabbit that follows the player have to *stand where the stop is*.

---

## 2. Architecture — build it out of doors that already exist

The temptation is a bespoke tutorial scene. Refuse it: every system it
re-implements is a system with two behaviours to keep in step, and this project
has paid for that four times (two copies of `strike_the_players`, two copies of
the act boundary, two definitions of the shake setting, three arrays of
discipline names).

**The Walk is the battlefield with an authored layout and a scripted director,
entered and left through its own pair of doors.**

| Piece | Reuse | New work |
|---|---|---|
| The valley | the existing `BeastRoadMapBlueprint` format | `data/maps/walk_layout.json`, **45×45 exactly** — see below |
| Choosing it | — | `BattleGrid.LAYOUT_PATH` is a `const`; it becomes a settable path |
| Entering | the seam `Expedition.apply` and `ActStart.begin` share | `GameDirector.start_walk()` |
| Leaving | — | `GameDirector.end_walk()`; `_settle_run` returns while `RunState.walking` |
| The stops | — | `TutorialStopData` in `data/tutorial_stops/`, one file per stop |
| Narration | the existing `TutorialCoach` card | a `walk_stop_reached` path beside the trigger path |
| Fishing, gathering, the pond, the seam, the forge bench | unchanged | one instance of each, placed |
| The wave | `WaveDirector` | one authored fixed queue, one lane |
| Taking the hero off the field for the rise | `Battlefield.set_hero_away` / `Hero.set_present` | — |
| The ending | a `MilestoneCinematic`-shaped beat, then `Scope.BEAST` | the rise itself |

**The valley is 45×45.** `BattleGrid.CORE_SIZE` is a `const 45` read by **static**
functions (`in_core`, `beyond_core`) and by everything derived from them — the
outskirts template, the camps, the forks, the ambush depths, the pond band, the
gather band, the rift gates. A differently-sized core is not a drop-in; it is a
change to a compile-time constant that a dozen static callers assume. Author the
valley in the same blueprint at the same size and nothing about the grid has to
learn that the Walk exists.

**Four things must not be touched.**

- `TutorialStepData.Trigger` is indexed by number out of twenty shipped `.tres`
  files. The Walk gets its own resource and its own enum. It does not grow a
  member — that is the fault that shifted twelve tutorial steps by one and told
  new players about raids when they found gear.
- `MetaState.SAVE_VERSION` does not move. The one new key is additive and sits
  under `stats`, beside `tutorial_done`, so no top-level key is added and
  `balance_test`'s save-key allowlist is untouched.
- `Balance.STARTING_GOLD` stays 0.
- The Walk never emits `EventBus.crossroad_reached` and never reaches
  `_settle_run`.

---

## 3. The valley

```
   [barn] - field - fence - FOREST: woodpile & seam - millpond - forge shed
                                                                    |
                                                              butts - hearth
                                                                    |
                                                         orchard - the hall
                                                                    |
                                                              THE FORK
                                                              /        \
                                                    short: the lane    long: the orchard wall
                                                              \        /
                                                       foot of the roads
                                                                    |
                                                  [ up onto Yuri's flank ]
                                                    build - upgrade - THEY COME
                                                                    |
                                                              THE ANCHOR
```

Gating is by path, not by invisible wall: each stop's completion opens the gate
ahead of it — a stile, an unbarred door, a plank across the race. A player who
wanders back can wander back. Nothing is modal and nothing has to be
acknowledged; the card is the existing narrow one at the bottom-left, with **Got
it** and **Skip the walk**.

**Yuri is visible from stop 2 onward** as a long dark shape closing the east end
of the valley. That is the reveal, and it is a landmark rather than a cutscene.
He is standing, and the narration never says otherwise.

**The brief says "farmlands and forests".** Stop 5 is in the forest, not at a
woodpile on the edge of a field. Trees are what a Woodcutter works and a forest
is where the seam is worth walking to.

---

## 4. The stops

Each is: **teaches / does / narration / reward**. Narration splits into an
`instruction` (the imperative) and an `aside` (the world); both are exported,
both optional, and a replay shows instructions only.

### PART ONE — THE VALLEY FLOOR (night)

**1 · `walk_yard` — The lamp, the yard**

*Teaches:* movement, the lantern, night. *Does:* walks out of the barn.

> **instruction:** Walk with WASD, or the left stick. The lantern lights itself when the light goes.
> **aside:** Nobody has lit the wall lamps in a while. There was nobody left to walk them.

---

**2 · `walk_hedgerow` — The hedgerow**

*Teaches:* the map, the fog. *Does:* presses M.

> **instruction:** M for the map. What you have seen stays on it. What you are looking at now is the only part that is live.
> **aside:** The long shape closing the east end of the valley is not a hill.

---

**3 · `walk_field` — The long field**

*Teaches:* wildlife, and that most of it is harmless. *Does:* walks through
placed deer and rabbits; they scatter. Sightings record normally. **One rabbit
does not leave** — it keeps pace at the hedge, and does so again at 5, 6 and 10.

> **instruction:** Most of what lives out here will not touch you. Walk near it and it goes.
> **aside:** The animals stayed when the people left. Whatever the Host is, it walks past a field.

> ***§57 rewrite.*** The first draft read *"They were not what the Host came
> for."* That says, without a single denylisted word, that the Host **came for
> people** — which is the abduction reading and it is the exact shape of the
> sentence the forwarded story document was refused on. The Host **marches**.
> It is compelled by chain-magic and it walks at a town; it does not collect
> anyone. Nothing anywhere in the Walk may imply that a person was taken, kept,
> worked or owned. The people **left**.

---

**4 · `walk_fence` — The broken fence**

*Teaches:* melee — the chain, the heavy third, the dash — Gold, **and what
losing your health actually costs.** *Does:* kills one sick boar. It is slow, it
telegraphs, it cannot kill them. It drops Gold.

> **instruction:** Left mouse swings. Three swings chain and the third is the heavy one. Space dashes, and nothing can touch you in the middle of a dash.
> **instruction:** Your health comes back on its own between fights. Go all the way down and you carry a Wound instead, and a Wound stays until something mends it. You are not the loss condition. Losing you is expensive.
> **aside:** That one is sick and it is not getting better. Putting it down is the kindest thing anyone has done in this field all season.
> **instruction (on the drop):** Gold. It comes off what you kill, and it is the only thing that buys towers.

*Reward:* Gold, **tutorial-scoped**.

> *Implementation note.* Author the boar as a fixed scripted actor with the
> blight's presentation, **not** through a Wildblight roll:
> `WildlifeFamilies` forbids the blight in Preparation and in the opening waves,
> and a scripted animal must not be the thing that makes those bounds a lie.

> *Added in this pass.* The first draft never taught wounds, death or recovery
> anywhere in eighteen stops. That is the single most important thing a new
> player needs to know and the one a narrow safe map can still teach honestly.

---

**5 · `walk_cut` — The forest: the trunk and the seam**

*Teaches:* gathering, Wood, Stone, and that a craft is practised. *Does:* fells
one trunk and breaks one copper seam. The rabbit watches.

> **instruction:** Walk up to the trunk and press T to start swinging. Walking away stops you. The seam past it breaks the same way.
> **aside:** Nobody has felled in here in a season. The hold had stopped building anything, which is how you can tell what they thought was coming.

*Reward:* Wood and Stone **(tutorial-scoped)**; timber and copper into
`MetaState.materials` **(persists)**; a little Woodcutter and Miner practice
**(persists)**.

---

**6 · `walk_millpond` — The millpond**

*Teaches:* fishing — cast, hook, reel — Food, and the Angler. *Does:* one cast,
one catch.

> **instruction:** Hold T to cast. The longer you hold, the further it goes. Press again the moment it bites.
> **instruction (on the hook):** Keep the line in the band while it fights. Too tight and it snaps, too slack and it is gone.
> **aside:** The wheel has not turned in a while. The fish did not mind.

*Reward:* Food **(tutorial-scoped)**; one common fish into `MetaState.fish`
**(persists)**; Angler practice **(persists)**.

---

**7 · `walk_forge_shed` — The forge shed**

*Teaches:* the four currencies named together, the bench, and what a plan is.
*Does:* spends timber and copper at the bench to make a dozen plain arrows.

> **instruction:** Four things a run spends. Gold off the dead buys towers. Wood and Food come out of the ground and pay for repair and for tending. Stone pays for the heavy work. All four go when the run goes.
> **instruction:** The bench turns what you gathered into what a plan calls for. You keep the plan. You do not keep the arrows.
> **aside:** The smith left her plans nailed to the post. She did not take them, which tells you how fast she went.

*Reward:* **one blueprint into `unlocked_blueprints` (persists)** — and it is
`plan_barbed_arrow`, **not** `plan_shortbow`. See §6: blueprints are bought with
Tools in sorted id order by `MetaState.earn_next_blueprint`, and `plan_shortbow`
is ninth of eleven. Granting a mid-ladder plan hands over a Tools purchase *and*
reorders the ladder so the next rung skips to `plan_thunder_bolt`. Granting the
first in sort order simply starts the ladder one rung along, which is a thing
that can be stated honestly. Arrows are tutorial-scoped.

---

**8 · `walk_butts` — The butts**

*Teaches:* the bow, ammunition, and the trade that makes range cost something.
*Does:* looses at three straw butts, then at a second sick animal that will not
come closer.

> **instruction:** Press F to loose an arrow at the cursor. Every shot spends one, and the quiver only holds so many.
> **instruction:** Melee costs nothing and always works. That is the whole trade — the bow decides which one you deal with first, and you pay for the privilege.
> **aside:** They shot here often enough to wear the grass off.

> ***Corrected.*** The first draft said "Right mouse looses." The shipped coach
> card (`data/tutorial/bow.tres`) says **F**. A tutorial that teaches the wrong
> key is worse than no tutorial. Every key in the Walk is taken from the shipped
> card that already teaches it, and the gate diffs them.

*Reward:* none. The bow is a loan; the plan from stop 7 is the keeper.

---

**9 · `walk_hearth` — The hearth stone**

*Teaches:* spells, mana, Focus. *Does:* casts one of the two spells the hero
already holds, watches the pool drain and creep back, then casts the other at
something.

> **instruction:** Spells sit on 1 to 4. Casting spends mana, and it comes back on its own, slowly.
> **instruction:** Focus is what deepens the pool, fills it faster, sharpens what you cast and shortens the wait. Everything a caster is, is that one attribute.
> **aside:** Fire, water, stone and air. The hold kept a little of each in this stone and nobody here could have told you why it works.

*Reward:* **none.** See §1.5 and §6 — the spell grant is cut, and the two spells
being cast here are the two every run already starts with.

---

**10 · `walk_orchard` — The orchard**

*Teaches:* bonding a Spirit Companion, the one slot, upkeep. *Does:* feeds the
rabbit that has followed them since the field. It stays.

> **instruction:** It has been behind you since the field. Feed it and it stays.
> **instruction:** One at a time, and it eats. A companion costs Food for as long as you keep it, and it goes home when the larder is empty.
> **aside:** Bonding is not catching. You will not own it. It walks where you walk while it wants to, and it is better at finding things than you are.

*Reward:* **one Common bond into `spirit_bonded` (persists).** See §6.

---

**11 · `walk_table` — The hall, the table**

*Teaches:* gear, and how many places there are to put it. *Does:* opens the
stash, reads the weapon already in the hero's hand, sees the rest empty.

> **instruction:** Eight things can be worn: a weapon, armour, a charm, a helmet, gloves, boots, a ring and an amulet. You are wearing one of the eight.
> **instruction:** The other seven stay empty until the road fills them. Gear grants attribute points, the same points levelling grants, and there is a ceiling on both.
> **aside:** The kit on this table is not new. Somebody wore it before you and did not come back for it.

*Reward:* **none.** The weapon (`coalpaint_edge`) is already worn — seeded at
launch by `MetaState._seed_starting_gear`. The Walk explains a thing the account
already has; it does not hand it over. See §1.6.

---

**12 · `walk_doors` — The hall, the doors**

*Teaches:* the stash, the codex and the chronicle, and that the three of them
outlive a run. *Does:* opens the real `HubScreen` and closes it again.

> **instruction:** The stash keeps what you find. The codex keeps what you have learned about the world. The chronicle keeps what you have done. None of the three is lost when a run is.
> **aside:** These three doors are the only things in the valley that will still be yours tomorrow. Where you find them again is called the Hold.

> ***Corrected fiction.*** The first draft said *"This is the Hold"* of a hall
> in a valley that Yuri then walks away from forever. Shipped lore says the Hold
> is "somewhere that does not move", and the between-run hub is a place a Warden
> returns to after every run — so putting it in the tutorial valley makes the
> player's permanent home a field they abandon in the first hour. It also
> collides with the owner's own phrase for the tutorial setting, *"the last
> human hold"*: two different places called the same word in the first hour of
> the game.
>
> So the hall is **not** the Hold. It is a hall with three doors in it, and the
> narration names the Hold once, as the place those same doors will be from now
> on. The player meets the actual Hold between runs, which is where it belongs.
> Whether the tutorial valley should have a name of its own is an owner
> question, not an agent's.

---

**13 · `walk_fork` — The fork at the mill**

*Teaches:* a crossroad — a reward traded against a difficulty, chosen before you
know what it costs. *Does:* picks one of two ways up to the foot of the roads.

> **instruction:** Two ways up. The lane is short and pays little. The orchard wall is longer, there are two more sick ones in it, and it pays better.
> **instruction:** Read both, then pick. The road asks you this at every crossroad and it never asks twice.
> **aside:** Either way comes out in the same place. That is usually true. It is not always true.

*Reward:* tutorial-scoped currency. **Both paths must pay for one tower and one
upgrade**; the long path additionally pays for a second tower.

> *Implementation note.* This fork must **not** emit `EventBus.crossroad_reached`
> — `TutorialCoach._show` calls `MetaState.mark_tutorial_done()` on that step,
> and co-op waits for the first *real* run. Use `walk_stop_reached`. **And the
> Walk must not reach `GameDirector._settle_run`, which marks it done a second
> way at `wave_number >= 6`.**

---

### PART TWO — THE FLANK (first light)

**14 · `walk_foot` — The foot of the roads**

*Teaches:* the four roads, the town, and what a wall is for. *Does:* climbs one
road. The other three are visible running up the flank.

> **instruction:** Four roads climb him and they are the only way up. Anything that wants the town has to walk one of them.
> **instruction:** The wall is the run. Let enough through and it comes down, and when it comes down you are finished — not hurt, finished.
> **aside:** There is a town up there. Soil settled on him, then water, then people, and none of them ever climbed back down.

---

**15 · `walk_build` — The open ground**

*Teaches:* placing a tower, and **why building is locked to Preparation.**
*Does:* clicks open ground, picks an element, picks a tower, pays Gold.

> **instruction:** Click open ground beside a road, pick an element, pick a tower off the list. It costs Gold, which is why you killed for it.
> **instruction:** You can only build while he is standing still. Stone does not set on a walking beast.
> **instruction:** Once he is moving, what you have built is what you have. Orders, the horn and your own two hands are the rest of it.
> **aside:** They built the hold's wall in a summer. You have got until he walks.

> ***Corrected.*** "While he is lying still" → "**standing** still". See §1.1.
> The diegetic reason is unchanged and still true in the shipped game: the beast
> is at rest during Preparation and `balance_test` asserts it.

---

**16 · `walk_upgrade` — The same tower**

*Teaches:* upgrading, the ten levels, the path at five. *Does:* upgrades once.

> **instruction:** Upgrade it. Ten levels, and it gets dearer every rung.
> **instruction:** At the fifth it takes a path — fewer and harder, or more and faster. You pick once and it keeps it.

---

**17 · `walk_hold` — They come up the road**

*Teaches:* a wave arriving and being held; the wave button; Command; the wall
taking a hit. *Does:* one short authored wave of Coalpaint outriders walks the
one open road. Towers fire for the first time. The wall takes one hit that it
survives.

> **instruction:** This button starts the wave. On the road it is RIDE ON — going early pays extra Gold, and the breather ends by itself if you do not press it.
> **instruction:** Command builds while you fight. Spend it along the bottom — orders work during a wave, which is when building does not.
> **aside (as it ends):** Coalpaint. Outriders, not the column.

> ***Corrected, and it was an internal contradiction.*** The first draft had the
> player press **Ride On** here. Ride On is what tells the beast to walk on —
> and he is chained to the ground with a foreleg he cannot move. The button is
> pressed, the wave starts, and the narration teaches what the button will mean
> on a road rather than pretending it means it now. Yuri takes his first step in
> stop 18 and not before.

*Reward:* Gold off the kills, tutorial-scoped.

---

### PART THREE — THE CHAIN

**18 · `walk_anchor` — The anchor**

*Teaches:* nothing. A tutorial still teaching at its ending has mistimed itself.

**The beat, in order.**

*i. The reason.* The wave is down. The player stands among their own two towers
and a wall with a dent in it. Before any prompt:

> **aside:** That was the front of it. They will come back with the rest of it, and the wall you just held will not hold twice.

*ii. The walk down.* The path to the anchor opens at the foot of the roads. It
is short and silent — no card, no prompt — past the chain where it comes out of
the ground: a hand's width of dark metal running from a spike in the valley
floor up to a cuff on his foreleg, with grass grown over the lowest link.

*iii. The prompt.* `Cut the chain — hold T`. It is the same Interact used at a
tree, a pond and a well, which is the point: the largest thing the player will
ever do uses the button they have been pressing all night.

*iv. Three strikes, one line each, spaced by the swing.*

> The chain is not metal all the way through. Something else runs in it, and that is the part holding him.

> They got this far and stopped. Whatever they meant to do to him, they did not finish it.

*(third strike: no line. Sound only.)*

> ***Rewritten.*** The draft's second line was *"He has been lying here long
> enough for the field to grow over his foot."* That falsifies "Yuri has not
> lain down." The replacement says the same thing about time — a field grew over
> the **link**, at *ii* — while making the chaining a failed attempt, which is
> what the shipped lore about the *other* Worldstriders actually implies.

*v. It parts.* The light in the chain goes out first, then the links go. The
valley is quiet for a beat longer than is comfortable.

> **aside:** He opens one eye. He has been awake the entire time.

*vi. The first step.* The foreleg comes out of the ground and the ground goes
with it. The millpond empties down the slope. The hold's roofs go over one at a
time. The town up on his back leans a long way and holds, because it has done
this before. Dust comes off him in sheets and there is a garden's worth of it.

The hero is taken off the valley floor and put back on the road — the same door
a raid already uses (`Battlefield.set_hero_away` / `Hero.set_present`), so
nothing new has to learn how to move a hero between places. Then the camera lets
go and pulls out to `Scope.BEAST` for the first time: the walking view, and the
first sight of where they have been standing all night.

*vii. Four lines that hand over.*

> He is moving. Nothing in this valley was going to stop him and nothing in it was going to save you.

> This is not a rescue. You cannot hold this ground, and he could not take a step. You have each other and that is the whole of it. You are his Warden now, and the only one he has.

> There is a beacon at the top of the world. Lit, it breaks every chain the Chainmaker has hung, all at once — every clan he holds goes free in the same moment.

> Nobody down here knows the way up. They only know that it is up, that the Gate of the Crown stands at the end of it, and that Kharok is waiting behind it.

> ***Two corrections here.*** The draft's third line put **the Gatekeeper on the
> last step**. The owner's brief of the same date says the Act 10 boss is
> **Kharok**, the Gatekeeper is fought on **Act 9** as the last of three opt-in
> trials, and an unbeaten Gatekeeper fights *alongside* the Act 10 boss. The
> tutorial's closing lines cannot promise a different final fight from the one
> the game ships, so the Gatekeeper is left out of the handover entirely — he is
> an optional ladder and naming him as the destination misdescribes him.
>
> And the draft never once called the player **the Warden**. Suppressing the
> shipped `StoryIntro` for a walker suppresses its third panel — *"Four roads
> climb Yuri's flanks. You are the one defender bound to hold them."* — which is
> where the game currently says the word. The Walk has to say it, and it is the
> right place: the bond is being made, not announced.

*viii. The last line, then control.*

> **Walk him there.**

*(Verbatim from `story_intro.gd`'s fourth panel — "There is a beacon at the top
of the world that can break the chain. **Walk him there.**" It is the sentence
the game has always ended its opening on and it stays the one sentence.)*

Then: fade, `RunState.reset()`, Act 1 — *The Road Begins* — Preparation, zero
Gold, four roads, nothing built.

---

## 5. What the story told you, and where

Nothing is a cutscene. Every piece of the premise is somewhere the player walks
past.

| Told at | What it lands |
|---|---|
| 1, 5 | the hold stopped maintaining itself, and knew why |
| 2 | there is something enormous at the end of the valley |
| 3, 7 | the people left, fast, and not because of the animals |
| 7, 13, 17 | the Host is not a rumour; it is a day out |
| 14 | there is a town on him, and the people who settled it never came down |
| 15 | he is standing still, and that is temporary |
| 18/ii–v | he is chained, the chain is not ordinary, the chaining was never finished, and he has been awake |
| 18/vii | the Warden, the bond, the beacon, the Gate of the Crown, Kharok, and that nobody knows the road |

**The Warden is never told they are special and is never chosen.** Their reason
at stop 18 is arithmetic: the wall will not hold twice, and he cannot take a
step. Two problems that happen to be each other's answer.

**The Host is compelled by chain-magic and by nothing else.** It appears once,
as outriders at a wall. Nobody in the Walk is taken, kept, worked, owned or
serves anyone. That is a release requirement (GDD §57), a gate catches only the
vocabulary, and §4 stop 3 above is the sentence that had to be rewritten to
satisfy the half no gate can catch.

---

## 6. The reward ledger — exactly what crosses, and why each is safe

**The rule: the Walk grants knowledge and objects. It never grants capital,
levels, worn power, spells or tower unlocks.**

### Crosses into the account

| Grant | Key | Why it is safe |
|---|---|---|
| One blueprint — `plan_barbed_arrow` | `unlocked_blueprints` | A *recipe*, on the sanctioned `unlocked` shelf (working rule 7, 2026-08-31). **First in `earn_next_blueprint`'s sort order**, so the Tools ladder starts one rung along rather than skipping a rung out of order. It is honestly one Tools purchase handed over; saying so is the price of granting it. |
| One Common bond | `spirit_bonded` | Rarity 0 is the bottom rung of a ladder already capped by `SPIRIT_APEX_POWER`; it fills the one slot §54 allows; it costs Food upkeep. Written through the `bond_from_egg`-shaped door — precedent for writing a key a sighting would eventually write, and nothing else. |
| One common fish | `MetaState.fish` | The pantry persists (owner, 2026-09-11) and `FISH_MEALS_PER_RUN` is 3. One fish is one of three meals, once. |
| A little timber and copper | `MetaState.materials` | A material is an input to the Smithy and nothing else: no attribute, no tower, no wave, no exchange for a run currency. |
| A little practice | `profession_xp` — angler, woodcutter, miner | A craft touches nothing but its own craft. `PROFESSION_MAX_LEVEL` untouched; `gathering_check` already maxes all five and reads every attribute back. |
| The walk itself | `stats.tutorial_walk_done: bool` | Additive, under `stats` beside `tutorial_done`, so no top-level save key and `balance_test`'s allowlist is untouched. |

**The flag must be written *and* parsed.** This project's own record has a
once-only flag that fired on every launch and handed out a free sword each time,
because the key was serialized and never read back. `TutorialGrants.award()` is
exactly that shape — a guard that fails open pays out a bond, a fish, materials
and a blueprint every launch. `save_round_trip_check` and the Walk's own gate
both round-trip it.

### Deliberately does **not** cross

- **No Gold, Wood, Food or Stone.** Everything earned in the valley is the
  Walk's own `RunState` and dies with it. `Balance.STARTING_GOLD` is still 0 and
  `_test_opening_envelope` asserts it; the real first run opens on the shipped
  `STARTING_WOOD 180 / FOOD 38 / GOLD 0 / STONE 90`. **The opening envelope is
  untouched by construction**, because the Walk changes neither the purse nor
  the enemy.
- **No spell.** Cut. `_equip_starting_spells` falls back to the whole library
  when `unlocked_spells` is empty, so granting one spell *narrows* the starting
  pair to one — the grant would make the hero weaker. `unlocked_spells` is also
  written only on victory today; it is a summit payout list, not a shelf.
- **No hero XP and no levels.** `curve_report` keys "measured on a NEW account"
  on `hero_level <= 1` and the 0.479–0.563 band was solved on a level-1 account
  (2026-09-15). A tutorial that hands out levels makes every "new account"
  measurement a measurement of something else and the report's own account line
  a lie. Kills in the valley are worth nothing.
- **No worn gear beyond what the account already has.** `gear_attribute_points()`
  is read directly by `curve_report`. The seeded `coalpaint_edge` is the
  baseline; the Walk adds nothing to it.
- **No tower unlocks.** `_seed_starting_roster` already seeds all eight,
  idempotently. The Walk teaches the build panel with towers the player owns.
- **No Marks, Shards, Tools, Sigils or ascension.**
- **No run statistics.** `runs_started`, `runs_won`, `best_distance`,
  `total_enemies_killed`, `highest_act`, `act3_cleared` and `expedition` are all
  untouched. `best_distance` drives `ActStart.furthest_act()` and `runs_started`
  gates the auto-offer; a Walk that wrote either would unlock an act start for a
  player who has not played, and hide itself from them.
- **No Chronicle completion and no leaderboard publish.**
- **No Treasury cache consumed, and no banked expedition cleared.** Both are
  side effects of `start_run`, which is why the Walk has its own door.
- **`MetaState.tutorial_done` is not set**, by either of its two call sites.

---

## 7. Skipping, replaying, and quitting halfway

**One function grants, two doors call it.** `TutorialGrants.award()` writes the
ledger in §6 and is guarded by `tutorial_walk_done`. It is called by the
chain-cut beat and by the skip, and by nothing else.

**A skipper is granted exactly what a walker earns.** Any other split makes
skipping a mechanical penalty, which makes the tutorial a tax rather than a
gift, and this codebase applies one bound to every optional system: the thing
you opt out of must not cost you power. A walker and a skipper stand on the
first frame of Act 1 identical.

**How to skip.** The card carries **Skip the walk** from the first frame, beside
**Got it**, confirmed once ("Skip? You can walk it again from the Hold."). From
the menu the Walk is offered **only** when `runs_started == 0 and not
tutorial_walk_done`, **derived rather than stored** — a flag defaulting false
sends every existing account, the owner's at level 81 included, to the tutorial
on next launch. A skipper gets the shipped four-panel `StoryIntro`; a walker has
it suppressed (`story_intro_seen = true` at the chain-cut), because seeing the
premise twice in five minutes is worse than once and the Walk is the better
telling.

**Quitting halfway.** The Walk is resumable at the last completed stop, held in
`RunState` for the session and **not** in the save: a player who quits mid-Walk
and relaunches is offered it again from the start, because the auto-offer is
derived from `runs_started == 0` and nothing was granted. Partial progress
grants nothing — the ledger fires once, at the chain or at the skip.

**Replay.** "Walk the hold again" sits in the Hold beside the codex, forever. It
grants nothing (the guard holds), shows instructions without asides, and lets
the player leave at any stop. **It must go through `start_walk`, never
`start_run`** — the whole reason the doors are separate is that a veteran
replaying it would otherwise lose a banked expedition and a Treasury cache.

---

## 8. Co-op

`MetaState.mark_tutorial_done()` stays where it is. The Walk emits neither
`crossroad_reached` nor a settled run, so neither call site fires, and the co-op
button keeps waiting on `tutorial_done`.

**One thing to put to the owner.** The brief says co-op unlocks "after the
player's first real run". Today it unlocks *during* it — at the first crossroad,
or at the end of any run that reached wave 6. Those are close and they are not
the same sentence. Left as shipped, flagged in the risks.

---

## 9. The existing coach, and what it still owns

Twenty `TutorialStepData` cards exist. Do not delete them and do not fire them
during the Walk.

- **Suppressed during the Walk** — the Walk owns the card while it runs.
- **Armed for the first real run**, unchanged.

**The Walk teaches what a valley can hold; the coach teaches what only a road
can show.** Raids, portents, merchants, rift gates, the first level-up, the
first gear drop, the first crossroad with real stakes, the town scope and crops
stay the coach's. That is nine of the twenty and they are the nine a narrow map
could only have faked.

---

## 10. Data shapes

```gdscript
class_name TutorialStopData
extends GameData

## A place on the Walk. One stop teaches one thing.
## Its own enum, deliberately: TutorialStepData.Trigger is indexed by number out
## of twenty shipped .tres files and must not grow a member.
enum Done {
    ENTERED,        ## standing inside `radius` is enough
    KILLED,         ## `count` bodies down
    GATHERED,       ## a node worked to empty
    CAUGHT,         ## a fish landed
    CRAFTED,        ## the bench used
    LOOSED,         ## `count` arrows away
    CAST,           ## `count` spells away
    BONDED,
    SCREEN_CLOSED,  ## the stash / the hall's doors opened and shut
    BUILT,
    UPGRADED,
    WAVE_HELD,
    CHAIN_CUT,
}

@export var order: int = 0
@export var at: Vector2i = Vector2i.ZERO      ## grid cell, not pixels
@export var radius: float = 90.0
@export var done: Done = Done.ENTERED
@export var count: int = 1
@export_multiline var instruction: String = ""
@export_multiline var instruction_two: String = ""   ## shown after `done`
@export_multiline var aside: String = ""
@export var seconds: float = 9.0
@export var opens: String = ""                ## the gate id this stop unbars
```

Signals (`EventBus`, typed, one line of comment each):

```gdscript
## A Walk stop was reached. Never emitted in a real run.
signal walk_stop_reached(stop_id: String)
## A Walk stop's objective was met.
signal walk_stop_done(stop_id: String)
## The chain parted. The one beat the beast scope listens for.
signal walk_chain_cut()
```

---

## 11. The gate — `tutorial_walk_check.gd`

Drive the Walk headless end to end. Hardest first.

1. **The account is unmoved.** Snapshot the save, walk the whole thing, diff.
   `hero_level`, `hero_xp`, `hero_attributes`, `gear_attribute_points()`,
   `unlocked_towers.size()`, `unlocked_spells`, `marks`, `shards`, `tools`,
   `sigils`, `runs_started`, `runs_won`, `best_distance`,
   `total_enemies_killed`, `highest_act`, `act3_cleared`, `chronicle` and
   `expedition` must be **byte-identical**. This is the `curve_report` baseline
   guard. Checked by granting a level, which it must name.
2. **A banked front and a Treasury cache survive a replay.** Bank an expedition
   and a cache, replay the Walk, read both back. This is the one that catches
   somebody wiring the Walk to `start_run`. Checked by doing exactly that.
3. **The ledger is exactly the ledger.** The diff's added keys are precisely the
   six in §6 and nothing else. Checked by adding a seventh.
4. **The hero starts Act 1 with two spells**, before and after the Walk.
   Checked by granting one spell, which must fail by name.
5. **Skip == walk.** Drive both on clean profiles; the saves match.
6. **Once only, and the flag round-trips.** Walk twice; the second diff is
   empty. Then serialize, reload and walk again; still empty. Checked by
   dropping the key from the parse, which must fail.
7. **`tutorial_done` stays false** through the whole Walk. The fork emits no
   `crossroad_reached`, **and `_settle_run` is never reached** — assert
   `run_active` was never true and that a Walk of six waves still leaves
   `tutorial_done` false. Checked by putting each path back, separately.
8. **Every stop is reachable**, driven in order, each gate opened by the one
   before. A stop nothing can complete is the unreachable-content failure this
   project has paid for with `call_wolf` and with two Arcane nodes.
9. **Every line is present and readable** — non-empty `instruction`, `seconds`
   at least the line's length over a plain reading rate — **and every key named
   in the Walk matches the key the shipped coach card teaches** (F for the bow,
   1–4 for spells, T for interact). Checked by changing one.
10. **Both fork branches pay for a tower and an upgrade.** Drive each; measure
    the purse at stop 16. The trade may change the surplus and may never make a
    lesson unreachable.
11. **The earth stays quiet.** No wildfire, quake, funnel, meteor or dragon pass
    fires during the Walk. Checked by driving the wrath heat to its ceiling.
12. **The valley's animals are where the stops are** — the deer at stop 3 and
    the rabbit at 3, 5, 6 and 10 stand inside `radius`, not at the map's
    arrival point.
13. **The Walk starts no wave director before stop 17**, and the tutorial wave
    ends.
14. `copy_check` already walks `res://data` recursively, so
    `data/tutorial_stops/` is covered. It is on both bars, and §57 is a release
    requirement.

`tutorial_walk_shots.gd` photographs each stop for the Guide, the way
`guide_shots` does. A picture of the wrong thing is the fault this project found
fifteen of on 2026-09-16.

**Also run, because they read what this adds:** `save_round_trip_check`,
`balance_test`, `curve_report` (on an empty `APPDATA`), `audio_verify`,
`music_check`, `copy_check`, `tutorial_check`, `spirit_check`, `fishing_check`,
`gathering_check`, `expedition_check`, `act_start_check`. The list comes from a
grep for what the change touches, not from intuition — name-based intuition
found five of sixteen gear gates once and missed the one that failed.

---

## 12. Art, honestly — and two files nobody has counted

This is the real cost and it is not code. The valley is a region the game does
not have: farmland ground, hedgerow and orchard foliage, forest, a barn, a mill,
a forge shed, a hall, straw butts, a hearth stone, a wall with a gate, and the
chain, the cuff and the anchor. The closest shipped terrain is the Verdant Maw
and the Rustwood, and neither reads as tilled human ground.

Two ways through, and the owner should pick before anyone starts:

- **Dress the jungle.** Reuse Act 1's ground and treeline, add ~8 props. Cheap,
  and the valley reads as "Act 1 with buildings in it" — which costs the reveal.
- **A real eleventh terrain.** One ground sheet, one backdrop, a foliage set of
  eight, and the props.

**The second option is not only art, and the draft missed this.** An eleventh
`TerrainData` needs a `battle_music` and an `ambience_bed` **that exist on
disk**: `audio_verify` walks every terrain and fails on a file that is not
there, and `music_check` walks every terrain across every act. Both are on the
release bar. So an eleventh region is a region's worth of generation *plus two
recordings*, in a project where acts VI–X still have no music of their own.

**And it must not take an act number.** `TerrainData.act` keys the ten regions
to the ten acts. The valley's terrain is act-less and reached only by the Walk;
`Balance.ACT_COUNT` stays 10, `balance_test`'s "exactly ten acts" assertion is
untouched, and nothing is renamed, renumbered or reordered.

The chain, the cuff, the anchor and the first step are one-off art either way,
and they are the game's opening image. They should not be the thing that gets
economised.

---

## 13. Sequencing

1. `TutorialStopData` + the eighteen `.tres` files (content, no engine).
2. `walk_layout.json` at 45×45, `BattleGrid.LAYOUT_PATH` made settable, and the
   gates — the walk with no lessons in it.
3. **`GameDirector.start_walk()` / `end_walk()` and `RunState.walking`, with
   `_settle_run` refusing.** Gate it here, before anything is granted: assertions
   1, 2 and 7 are what protect the account, the band and the brief.
4. Stops 1–4 and 14–17: the systems already wired to the battlefield.
5. Stops 5–10: the craft and ecology stops, one placed instance each.
6. `TutorialGrants.award()`, the skip, and the flag's round trip. Assertions 3–6.
7. Stop 18, the first step, and the scope change.
8. `tutorial_walk_shots` and the Guide page.

The ending is last on purpose. It is the only part that is not reusable, and it
should be built when everything it is the ending *of* already works.


---

## Decisions taken in this draft

- Yuri is STANDING and chained at a foreleg, never lying down. The shipped string 'Yuri has not lain down' made the draft's entire ending - a beast getting up - false. The chaining is a failed attempt the Host never finished; the ending is a foot coming free and a first step. Every 'lying still' / 'could not get up' / 'stands up' line is rewritten.
- The Walk is entered and left through new doors, GameDirector.start_walk()/end_walk(), with RunState.walking set and _settle_run returning on its first line while it is true. start_run calls MetaState.clear_expedition() (destroys a banked front on replay) and RunState.reset(true) (consumes the Treasury cache and Sigil bundle); _settle_run writes eight run statistics, awards Tools, roster towers and a Sigil, completes Chronicle objectives, publishes to the leaderboard and calls save_game.
- mark_tutorial_done has TWO call sites: tutorial_coach.gd:194 on CROSSROAD_REACHED and GameDirector.gd:541 at wave_number >= 6. The Walk must trip neither, so it emits no crossroad_reached AND never reaches _settle_run.
- The spell grant is CUT. RunState._equip_starting_spells falls back to the entire spell library when unlocked_spells is empty and takes STARTING_SPELLS (2), so granting exactly one spell narrows the starting pair to one and makes the hero weaker. unlocked_spells is also written only on victory today - it is a summit payout list, not a horizontal shelf.
- The blueprint granted is plan_barbed_arrow, first in MetaState.earn_next_blueprint's sorted id order, not plan_shortbow which is ninth of eleven. Granting a mid-ladder plan hands over a Tools purchase and reorders the ladder so the next rung skips a recipe.
- The starting weapon is narrated, not handed over. MetaState._seed_starting_gear() runs in _ready() at launch and the weapon is already equipped before the Walk begins; its flag is deliberately not idempotent and deferring it risks an account with no weapon.
- Stop 11 teaches EIGHT worn slots (GearData.Slot: WEAPON, ARMOUR, CHARM, HELMET, GLOVES, BOOTS, RING, AMULET), not three. The draft's 'two empty slots is the lesson' was arithmetic on a number that does not exist.
- The hall in the valley is NOT the Hold. Shipped lore says the Hold is 'somewhere that does not move', and putting it in a valley Yuri walks away from makes the player's permanent home a field they abandon in the first hour; it also collides with the owner's phrase 'the last human hold'. The hall has three doors and names the Hold once as where they will be from now on.
- The Gatekeeper is removed from the handover lines. The owner's brief of the same date puts him on Act 9 as the last of three opt-in trials and Kharok at the Act 10 summit; a tutorial promising a different final fight than the one that ships misdescribes both.
- The Walk calls the player 'the Warden' at the chain, because suppressing StoryIntro suppresses panel three - 'You are the one defender bound to hold them' - which is where the game currently says the word.
- Stop 17 does not press Ride On. Ride On tells the beast to walk on, and he is chained to the ground; the button starts the wave and the narration teaches what it will mean on a road. Yuri's first step is stop 18 and not before.
- Preparation is not a hazard-free phase: only hostile wildlife arrivals are suppressed and only at wave zero, and nothing in the wrath, weather, wildfire, quake, tornado, meteor or dragon pass asks is_preparation(). The Walk holds the earth quiet explicitly and the gate drives the wrath heat to its ceiling to prove it.
- The valley's animals are placed, not arrived. Wildlife enters from the map's arrival point and walks in, which is how a newborn once landed fifteen hundred units off the edge; the deer and the following rabbit must stand inside their stop's radius.
- The valley is authored at exactly 45x45 in the existing BeastRoadMapBlueprint format. BattleGrid.CORE_SIZE is a const read by static functions and by the outskirts, camps, forks, pond band, gather band and rift gates; LAYOUT_PATH is a const and becomes settable, which is the only grid change.
- tutorial_walk_done lives under stats beside tutorial_done, so no top-level save key is added and balance_test's allowlist is untouched - and the gate round-trips it, because this project has shipped a once-only flag that was serialized and never parsed and handed out a free sword every launch.
- Stop 4 teaches wounds, recovery and that the player is not the loss condition. The draft taught death nowhere in eighteen stops, which is the single most important thing a narrow safe map can still teach honestly.
- Stop 8's key is F, taken from the shipped coach card data/tutorial/bow.tres. The draft said right mouse. Every key in the Walk is taken from the shipped card that already teaches it and the gate diffs them.
- Stop 5 is in the forest, answering the brief's 'farmlands and forests' - a woodpile on a field edge is not a forest and a seam is worth walking to.
- Quitting mid-Walk grants nothing and re-offers from the start: progress is held in RunState for the session and never in the save, and the ledger fires once at the chain or at the skip.
- The auto-offer is DERIVED from runs_started == 0 and not tutorial_walk_done, never stored as a flag defaulting false - which would send every existing account, the owner's at level 81 included, to the tutorial on next launch.
- An eleventh terrain costs two audio recordings as well as art: audio_verify walks every terrain's battle_music and ambience_bed and fails on a file not on disk, and music_check walks every terrain across every act. Both are on the release bar.
- The valley's terrain takes no act number. TerrainData.act keys the ten regions to the ten acts; Balance.ACT_COUNT stays 10 and nothing is renamed, renumbered or reordered.
- Stop 3's aside is rewritten: 'They were not what the Host came for' says without a denylisted word that the Host came for people, which is the abduction reading and the exact shape of the refused sentence. The Host marches and walks past a field; the people left.

## Open - these need the owner

1. OWNER RULING - rewards. The brief says the player 'earns basic starting rewards naturally'. This design grants six things and no power at all: a blueprint, a Common bond, one fish, a little timber and copper, three crafts' practice, and the done flag. No Gold, no XP, no levels, no spell, no gear. Is that enough to read as 'earning rewards', or does the tutorial need to hand over something the player can feel on wave 1 - and if so, which, given that hero level and worn gear are the two numbers curve_report reads to decide whether it is measuring a new account?
2. OWNER RULING - hero XP specifically. Killing a boar, three butts and a wave for zero experience may read wrong to a new player. If the Walk should level the hero, the 0.479-0.563 pressure band must be re-measured from a post-tutorial profile and restated in BOTH CLAUDE.md and curve_report.PARTY_PRESSURE_FLOOR/_CEILING - which is the exact two-places-one-forgotten failure recorded on 2026-09-15. Should it?
3. OWNER RULING - the spirit bond. It is the one grant that puts an extra body on the field, and curve_report does not model companions, so no gate measures it. A Common rabbit is the weakest rung and eats Food. Should the tutorial companion be a rabbit, or does the owner want a deer or a fox - which is rarity 1 or 2 and a materially stronger companion handed over before wave 1?
4. OWNER RULING - the blueprint is one Tools purchase given away. Whichever plan is granted, the player reaches the Tools ladder one rung further along than an account that skipped nothing. Is a free recipe an acceptable tutorial reward, or should the Walk grant no blueprint at all and teach the bench with a plan the account already owns?
5. OWNER RULING - naming. The owner's phrase for the setting is 'the last human hold' and the between-run hub is 'the Hold'. Two different places called the same word in the first hour of the game. Should the tutorial valley get a name of its own, and if so, what? Naming is fiction and not an agent's call.
6. OWNER RULING - where the Hold is. Shipped lore says the Hold is 'somewhere that does not move' and this design deliberately does not explain how a Warden reaches it between runs, because the game has never answered that and inventing an answer risks contradicting a shipped string. Does the owner want it answered now, and if so is the Hold a place on the ground that Yuri returns past, or somewhere on his back?
7. OWNER RULING - co-op timing. The brief says co-op unlocks 'after the player's first real run'. It ships today unlocking DURING it: at the first crossroad, or at the end of any run reaching wave 6. Should it move to the end of the first run, which is what the brief literally says, or stay as shipped?
8. OWNER RULING - art route. Dress the jungle (cheap, ~8 props, and the valley reads as 'Act 1 with buildings in it', which costs the reveal) or a real eleventh terrain (one ground sheet, one backdrop, eight foliage, the props, AND a battle track and an ambience bed on disk or audio_verify and music_check fail on the release bar). This must be decided before anyone starts. The chain, the cuff, the anchor and the first step are one-off art either way and should not be the part that gets economised.
9. OWNER RULING - the Gatekeeper's absence from the ending. His four closing lines now name the beacon, the Gate of the Crown and Kharok, and leave the Gatekeeper out entirely, because the brief makes him an Act 9 opt-in trial rather than the last step. Should the tutorial foreshadow the trials at all, or is the first mention of the Gatekeeper better left to Act 3 where the ladder actually opens?
10. SECTION 57 - one sentence was rewritten and the rest needs a human read. The draft's stop 3 aside read 'They were not what the Host came for', which states without any denylisted word that the Host came for PEOPLE - the abduction reading, and the same shape as the refused 'compelled workers to maintain the anchors'. It is now 'Whatever the Host is, it walks past a field.' Every other line was read for the same failure and stop 10's 'Bonding is not catching. You will not own it.' does §57's work deliberately. copy_check catches the vocabulary; a person still has to read all eighteen stops before they ship.
11. SHIPPED FICTION - the bond forms at the tutorial. Shipped StoryIntro panel three says 'You are the one defender bound to hold them' as a present fact, and the Walk now makes the bond at the chain instead. If another agent's canon work places the Warden-Yuri bond earlier, stop 18's 'You are his Warden now' has to agree with it.
12. IMPLEMENTATION HAZARD - this is the one that loses player data. Replaying the Walk through GameDirector.start_run would call MetaState.clear_expedition() and wipe a veteran's banked front - five hours of road - silently, and consume their Treasury cache and Sigil bundle. Gate assertion 2 exists for exactly this and must be written before the replay button is.
13. IMPLEMENTATION HAZARD - mark_tutorial_done's second call site. GameDirector.gd:541 marks it done for any run reaching wave 6, so a Walk that settles a run unlocks co-op at the tutorial's own ending regardless of the crossroad signal. Both paths are gated separately.
14. IMPLEMENTATION HAZARD - the grant guard failing open. If tutorial_walk_done is serialized and not parsed back, TutorialGrants.award() fires on every launch and pays out a bond, a fish, materials and a blueprint each time. This project has shipped that exact fault once with a free sword.
15. MEASUREMENT - the tutorial's own ledger (what the boar, the trunk, the seam, the fish and the fork pay, against TOWER_BUILD_COST and the first upgrade) is authored, not derived. Both fork branches must be driven and the purse read at stop 16: a short branch that cannot afford the upgrade makes stop 16 unreachable and the lesson silently never appears, which is the thin-pool failure omen_check's comment warns about.
16. SCOPE - eighteen stops, a 45x45 authored layout, a new resource, a new pair of GameDirector doors, a grant ledger, an ending beat, a fourteen-assertion gate and a shot tool, sitting on top of a 622-wave campaign that is not yet scored (acts VI-X have no music, no act has a boss theme) and an eleventh terrain that would want two more recordings. It is the right thing to build for launch and it is not a session's work.
