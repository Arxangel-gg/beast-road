# Content multipliers: what to build, adapt or refuse, 2026-09-25

The owner forwarded eight "content multiplier" ideas and asked for them to be
implemented, adapted or rejected as judged best, plus any of our own. Each was
checked against the code before a verdict, because the last five forwarded
documents were each roughly half a description of what already ships.

The bound every verdict is held to is the one this project has held for a
year: **a multiplier may change the shape of a fight and never grow a third
power scale nobody is tuning.** Levelling and gear are the two capped scales,
ascension is the third and it is measured; anything else that adds magnitude
needs its own ruling. What a multiplier may do is re-route an existing effect,
recombine existing pieces, or make an existing number depend on the world.

## 1. Modular enemy affixes - ADAPT, building

**Already built:** 22 marks (`data/affixes/`) spread from Act II to Act X, each
moving numbers the fight already has - health, damage, speed, resistance,
regeneration, a ward, burn, slow, mana burn, a death blast, mending the company,
auras of speed or resistance. Elites wear two or three; a champion pack shares
one. Marks multiply rather than tabulate, so every combination names itself
("Rimewarded Emberclad Bogkin") and nothing describes the pair.

**The gap is who wears them and why.** Ordinary bodies never do, and which mark
comes up has nothing to do with the world. Built:

- **Marked commons, by tier** (see §6): on Nightmare and Hell a share of the
  ordinary road bodies wear one or two marks, outlined in the mark's colour and
  paying a little more for it. Normal is untouched, which keeps every curve
  measured on it.
- **The weather chooses.** A mark may name the weathers it favours; under
  them it is several times likelier. Rimewarded in snow, Galeshod in a gale,
  Emberclad in a heatwave - the road is telling you something again.
- **The earth's anger marks more of them.** The hidden wrath lifts the marked
  share, capped. It is a sign rather than a readout, which is the wrath's rule.
- **Four new marks from the list**, each a number the fight already has:
  **Frenzied** (faster below a third of its health), **Packbound** (an aura
  only its own breed hears), **Stormbound** (its death leaps as lightning to
  the nearest few of the player's, instead of a blast round it) and
  **Mirrorhide** (for a moment now and then, tower shots glance off it - the
  answer is the Warden).
- **Refused from the list:** *Broodmother* (spawns young) adds bodies, and the
  pressure curve is tuned on how many bodies arrive - the same reason a routed
  body never despawns. *Burrowing* and *Blighted* are a movement rule and a
  terrain state rather than numbers; the right time is after the four above
  have been played.

## 2. Augment drafts - ADAPT, building as keystone Road Cards

**Already built:** Road Cards - 24 cards, three offered at every crossroad, a
hand of five, one card per effect key. They are deliberately numbers ("+8%
damage" is exactly what they are), because a card may only move a number
`Modifiers` resolves.

**The ask is the other kind** - "frozen enemies explode", "harvesting trees
heals structures", "critical hits ignite vegetation". Those are *mechanics*,
and a third draft of mechanics is a content system nobody can read the curve
against. The discipline synergies already answered this shape: **a synergy
changes when an existing effect fires or what it fires on, and never its
magnitude.** Keystones are that rule on a card:

- One **keystone** at most in a hand, dealt rarely from Act III, taking a slot.
- Each re-routes an existing effect onto a new trigger at that effect's own
  size: a chilled body's death spreads its chill (Shatter); the Warden's
  critical blows light the brush where they land, which is a fire the player
  lit and costs wrath (Tinderstrike); felling a trunk mends the towers near it
  through the repair door (Timberwright); towers prefer what the Warden has
  just struck (Marked for Death); the spirit swings faster beside the board it
  guards (Pack Instinct).
- **Refused from the list:** *"every third projectile becomes a meteor"* and
  *"tornadoes redirect projectiles"* add a damage source or a physics rule;
  *"+8% damage"* is what the ordinary cards already are.

## 3. Tag-based item generation - ALREADY BUILT, one piece deferred

A piece is a base kind (114 of them) at a rarity (seven) and a level, with one
to five attribute bonuses dividing its budget, legendary affixes that name it -
`Stash.display_name` already builds "Runed Ashfall Glaive of Embers" from prefix
and suffix affixes - and set membership by kind. All of it derives from the
piece's `uid`, so nothing new is saved.

**Deferred: corruption.** A "cursed" piece is the portent shape on gear - a
bane beside the boon - and it is a good idea, especially a bane that feeds the
earth's wrath. It needs a stored flag on the piece (the uid cannot say which
tier it dropped at), which touches trade, the Ledger and the stash. Staged for
after 1.0 with that bound written first. *Provenance* ("found in the Saltpan")
is refused for the same save-shape reason and adds no decision.

## 4. World events with branching consequences - ADAPT, building

**Already built, as systems rather than scenes:** the mythic trail
(evidence, tracking, encounter), nests you can rob and be hunted for, the
Wildblight and the mercy that costs no wrath, eggs carried home to bond,
over-farming answered by a savage elite, and the dragon's pass.

**The gap is the choice.** Every one of those is something that happens; none
of them stops and asks. **Wayside encounters** are that: a wounded rare animal
on the outskirts, a cart overturned on the road, a cache nobody guards -
walked up to and answered from three or four options, **each option an
existing door**: a gear roll, a sighting toward a bond, Food spent, a savage of
the species sent hunting, wrath, towers mended. The composition is the
content; nothing new persists; the earth keeps the ledger it already keeps.

For 1.0 an encounter rolls only when the road is not shared: in co-op the
choice would have to be put to the party, which is `PartyEvents`' conversation
and is its own piece of work.

## 5. Wildlife genetics 2.0 - ADAPT, building the look

**Already built:** a coat per animal from its serial (hue, lightness,
saturation, nine pattern shapes), a temperament per bonded spirit (six traits,
held to a mean of one), rarity and shine inherited on the family tables.

**The gap is resemblance.** A cub's coat is drawn from its own serial, so it
looks nothing like either parent. Built: a newborn's coat is its parents' -
each gene from one or the other or between, with a small mutation.
**Refused:** speed, aggression, loyalty and elemental affinity as inherited
*numbers*. Those are a stat scale bred rather than found, and breeding would
then be the way to power.

## 6. Difficulty as rulesets - BUILD

**The gap is real.** A campaign tier is five numbers today: health, damage,
speed, experience and loot. Built as rules on the tier resource, all zero on
Normal:

- **Marked commons** (§1) - the share, and how many marks a body may wear.
- **Bosses wear marks** (§7) - one on Nightmare, two on Hell.
- **The earth starts angrier** - the wrath floor opens above zero.

**Refused:** *scarcer extraction*. It was refused on 2026-09-15 for a reason
that has not changed: the expedition system rests on trusting the crossroads,
and "sometimes you cannot leave" is a feature that is either invisible or
infuriating. *Corrupted loot* waits on §3.

## 7. Boss mutations - ADAPT, via marks

**Already built:** every act boss has authored phases (thresholds, names,
reinforcements, speed and damage bonuses), a telegraphed slam and a volley of
its own shots, and quickens as it breaks.

**Built:** on Nightmare and Hell a boss rolls marks from the act's pool, so the
same boss is a different fight - Warded, Bannerborne, Stormbound. **A boss wears
a mark's behaviour and never its size**: the health and damage multipliers are
not applied to a boss, because a mark authored for a road body on a boss pool of
eleven thousand is an hour-long fight. *Arena weather* and *summon packages*
are staged: both are good, and both want the marks played first.

## 8. Quest template generator - REFUSED as a system, translated

A generated quest wants an actor to give it and a place to return it, and the
road has neither: the town rides the beast and the Hold is between runs.
Chronicle objectives already give a run its standing goals. What survives of
the idea - an actor, a motive, a complication, a choice and a consequence - is
**the wayside encounter** (§4), which is a quest that starts and ends where it
is found.

## 9. Our own

- **The weather chooses the marks** (§1) is the one we would have proposed
  anyway: it makes two of the game's best systems read each other.
- **A guest now sees what it is fighting.** Found while surveying §1: the
  co-op announce never carried a body's rank or marks, so on a partner's screen
  every elite and champion was a plain body at the host's health. Fixed with
  the marks work.

## 10. The order

1. Marks: the four new ones, weather and wrath, marked commons and boss marks
   by tier, and the co-op announce.
2. Keystone Road Cards.
3. Wayside encounters.
4. Genetics: resemblance.

Each ships with a gate that drives it through the real doors, and each is
recorded in CLAUDE.md with its bound.
