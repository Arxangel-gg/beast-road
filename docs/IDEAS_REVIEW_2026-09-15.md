# Ideas review — mythical wildlife, 2026-09-15

The owner forwarded a long proposal for mythical wildlife in Wilderhold: 112
creatures, a Mythic classification above Legendary, evidence-and-tracking
encounters, mythic materials, a sanctuary, and a bestiary that fills in through
play.

This triages it the way `IDEAS_REVIEW_2026-09-10.md` and `_2026-09-14.md` did:
what is already here under another name, what genuinely multiplies what exists,
what is a second system beside one that works, and what rests on a mechanic this
game does not have.

---

## 1. The best idea in the document is not a creature

**Evidence → Tracking → Encounter.** Claw marks, then burnt trees, then a
half-eaten animal, then a shadow overhead, then the thing itself. That is the
one proposal here that makes every creature better without adding a creature,
and it is the one that fits what is already built:

- `WeatherSky.wrath()` already runs a hidden anger that rises with what the
  player kills, and already says so through *signs* rather than a bar — the
  `data/wrath/unrest_N` lines, the birds, the ground, the sky. A Mythic's
  approach is the same grammar with a different subject.
- `FogOfWar` already hides what has not been seen, and `Wildlife` already has
  animals that hide and break cover (the raccoon, 2026-09-14).
- `Wildlife.living_legendaries()` already makes a living legendary an *anchor*
  that calms the earth and speeds its recovery, so the game already has one
  creature that is worth more alive than dead.

So the frame to build is the trail, and the creatures hang off it. Building
creatures first and a trail later gets the order backwards: a dragon you walk
into is a bigger boar.

## 2. What the document assumes that Wilderhold does not have

**It is written as though Wilderhold were an extraction game.** "Extraction
philosophy", "run to extraction", "the griffon follows you to extraction". It
is not one: a run is a road with ten acts, a homecoming pass after each boss,
and raids and rifts as detours. Several of its best beats — steal the egg and
be hunted all the way out — need a translation before they mean anything here.
The nearest real equivalent is **the homecoming pass**: take the egg, and the
parent is on the road until you turn for home. That is a genuinely good fit and
it is the shape the idea should take, but it is a translation and not a lift.

**There is no ocean.** Kraken, Leviathan, sea serpent, selkie, reef drake and
the abyssal angler all want water this game does not have; the ponds are
knee-deep and sit in the outskirts. Refused until there is a sea.

**A werewolf is the Wildblight wearing a second coat.** "A wounded traveller
that turns at nightfall, a blood moon that raises spawn rates and drops lunar
materials" is, mechanically, the frenzy lifecycle built on 2026-09-14: an
animal sickens, warns, frenzies, and is answered in person. Building a second
one beside it is two systems doing one job. The right version is a **Cursed**
variant *of* the blight — a species whose frenzy is permanent and whose cure is
different — which costs a flag and some art rather than a subsystem.

## 3. What a Mythic classification actually costs

The proposal is right that Mythic should be a *classification* rather than a
sixth rarity, and that shiny should roll independently. Both already have a
place to live: `WildlifeData` carries rarity and the shiny roll is separate.

What it touches, and none of it is free:

| Thing | Why it has to move |
|---|---|
| `Balance.WRATH_RARITY_SCALE` | 1, 3, 8, 24 by rarity. A Mythic kill has to cost more than a legendary or the earth does not notice the biggest thing in it. |
| `SpiritBond` | Which Mythics may be bonded at all. The document is right that most must not be: a player casually walking around with a Kraken is the mystique gone. |
| Population budgets | `budget_check` holds the ceilings the frame was measured under. A Mythic that does not count against them is the frame going away. |
| Co-op | Every arrival, every clue and every frenzy is a fact the host tells. A Mythic whose *trail* is not replicated means two players tracking different animals. |
| The codex | The bestiary-fills-in-through-play idea is good and is `GuideSectionData` plus statistics; it is also the one piece here that is nearly free. |

## 4. The shortlist

Five, chosen because each multiplies a system that already works rather than
adding one beside it. Not twenty, and certainly not 112: the value is in a
handful finished — adult art, young art, idle, move, warning pose, calls,
family rules, companion behaviour, codex text and the wire — rather than a
roster of names.

1. **Moonstag.** The anchor idea made visible. A living one calms the earth
   further than a legendary does; killing it is a real reward and a real loss,
   and the wrath system already has both halves of that sentence.
2. **Griffon.** Circles before it commits, nests on the outskirts' cliffs, is
   territorial rather than hostile. The camps already put cliffs on the map and
   `Enemy.make_camp_mob` already has leash-and-return behaviour to borrow from.
3. **Glimmerfox.** A companion first: the spirit traits (2026-09-01) are an
   envelope that trades rather than a damage upgrade, and a fox that blinks
   rather than hits harder is exactly that shape.
4. **Hollowhorn.** The stalker. Needs the one real piece of new engineering in
   this list — a clue that is drawn while the animal itself is hidden, because
   `Wildlife` hides the whole sprite — and that engineering is what the whole
   Evidence idea needs anyway.
5. **Phoenix.** Fire already has a wildfire, an ember strain and charged
   ground. A Phoenix that dies into ash and returns unless something is done
   about it is a fire event the fire systems can already read.

Deliberately **not** first: dragons. The document is right that they should be
the rarest thing in the game and that the map should know one is there — and
that is a world-event system, not a creature. It should be built after the
trail, with one named dragon, or not at all this year.

## 5. What is already here under another name

- "Their presence changes nearby enemies and wildlife" — `Wrath` zones, the
  legendary shock window, and `Wildlife.frightened_at` already do this.
- "Unusual weather, altered music, animals running in one direction" — the
  legendary-slain moment (2026-09-14) is exactly that, and is the template.
- "Mythic materials" — `MetaState.materials` and the Smithy, bounded by *a
  material is an input to the Smithy and nothing else*. A Mythic material must
  take that bound or it becomes the third power scale this project keeps
  refusing.
- "A sanctuary where bonded spirits appear" — the Hold exists. This is the best
  of the collection ideas and it is a screen, not a system.
- "Silhouette until discovered, statistics that fill in" — the Guide and
  `MetaState.stat` already do this for achievements.

## 6. The bound, if any of it is built

The same one everything since the omens has been held to: **a Mythic may change
what a fight asks of you and must not add a power scale nobody is tuning.**
Levelling and gear are the two capped scales the campaign tiers are measured
against. A Mythic material feeds the Smithy, which rolls gear on the tables
that already exist. A Mythic companion trades within the spirit envelope. A
Mythic kill moves wrath, which is a number the earth already has an opinion
about. Anything that grants magnitude outside those needs its own decision, in
`CLAUDE.md`, dated, before a line of it is written.

---

**NEXT** — the trail before the creatures: a clue that can be drawn while the
animal that left it is hidden, and a `WildlifeData` flag for what leaves one.
Then the Moonstag, which needs no new engineering beyond it.
