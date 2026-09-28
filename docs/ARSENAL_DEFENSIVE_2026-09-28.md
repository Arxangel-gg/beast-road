# The Arsenal, defended — augments that keep you standing

**Design and build record · 28 September 2026 · owner request**

> *"Including making the rest of the autonomous augments, both offensive and
> defensive ones with enough of them to make a decent ratio that will keep
> players invested in wanting to play to try to get the ones they want. Make
> the best game juicy vfx for all of them using Forge VFX and Godot, ensure
> proper optimization for all things added to the game."*

`docs/AUTO_ARSENAL_2026-09-27.md` built the offensive half: twenty-three
weapons, five catalysts, four evolutions, on eight patterns. Every one of them
is a way of *killing*. Nothing in the deck answers the question a Warden on
Act VII is actually asking, which is how to still be standing when the wave
is over. This document adds the other half.

## 1. What a defensive augment is here

The offensive bound is *a way of killing, never a number*. The defensive bound
is its mirror: **a way of not dying, never a stat.** A ward that appears on a
cadence is a thing that happens, with a moment and a picture; "+12% armour"
is a number nobody sees and the third power scale this project has refused a
dozen times. So every defensive card is one of five *patterns*, each a thing
the field already knows how to do, done on the Arsenal's clock:

| Pattern | What happens | The door it uses |
|---|---|---|
| **WARD** | on a cadence, the anchor gains a ward worth a share of its own pool | `Hero.grant_ward`, `Tower.ward`, `TownCore.ward` |
| **MEND** | on a cadence, the anchor heals a share of what it is missing | `Health.heal`, `Tower.repair`, the wall's own mend |
| **RETORT** | when the anchor is struck, a burst hits the bodies at it, at most once a cadence | `strike_body` — a real Arsenal blow through `take_damage` |
| **GUARD** | stones orbit the Warden and swallow hostile shots; a stone reforms on a cadence | the Stillwater Mirror's `absorb`, asked of the Arsenal |
| **FIELD** | bodies inside a ring around the anchor are slowed and wetted while they stand in it | `apply_slow`, `apply_wet` — statuses the fight already has |

Nothing here is new to the game. A ward is what the Aegis and the Kept Gate
give; a mend is the Mason Shrine's pulse; a retort is a nova with a different
trigger; a guard is a mirror worn instead of built; a field is a trail patch
that follows its anchor. That is the whole argument for building it: each
pattern is one function in `Arsenal`, and every card is a data file.

## 2. The bounds

1. **A share of the anchor's own pool, never a figure.** A ward is
   `max_hp × share`, a mend `missing × share`. A Warden at level 100 and one at
   level 1 hold the same card and it means the same thing to each. Every share
   is held under `ARSENAL_WARD_CEILING` and `ARSENAL_MEND_CEILING` per firing,
   and `ARSENAL_MEND_TOWN_CEILING` for the wall, which is the loss condition
   and has a Gold sink of its own (the Quartermaster) that a free mend must
   not undercut.
2. **A retort is a blow, so it is a weapon.** It goes through `strike_body`,
   is named in the ledger, sets off no form and no keystone, and is modelled
   as damage a second **at zero**: it fires only when something has already
   landed a blow on the anchor, and a best-case model that assumed the Warden
   is hit on a schedule would be modelling a player the road never produces.
   The gate measures it fires when struck and never otherwise.
3. **Pure defence moves the curve by exactly nothing.** `modelled_dps` is 0 on
   WARD, MEND, GUARD and FIELD; `curve_report` reads the same waves. What they
   move is the *blows the Warden can take* readout, which prints and fails
   nothing, as the ascension rank's did.
4. **A field slows and never moves.** Morale's own bound: a status may change
   the shape of a fight and never where a body goes. `apply_slow` is what
   Frostpoint already does; nothing here shoves.
5. **A guard swallows a shot and never a blow.** Melee is answered by wards
   and mends. A guard that stopped a swing would be immunity on a cadence.
6. **Same clock, same freeze, same canvas.** Cadence through `cadence()`, so
   Focus quickens a ward as it quickens a spell; records on the Arsenal's
   canvases, never nodes; frozen with the scope (working rule 8); nothing
   persists (working rule 7).
7. **Seat and board as the offensive cards.** A Warden-anchored card is that
   seat's own; a tower- or town-anchored one is the party's board
   (`Augments.seat_keeps` reads the anchor and needs no new rule).

## 3. The roster

Ten cards, three anchors, one catalyst, two evolutions. With the twenty-three
weapons that ships a deck of **fifty** (23 weapons, 10 wards, 6 catalysts, 6
evolutions, 5 keystones), which is about the size the genre keeps and is what
"a decent ratio ... to try to get the ones they want" means: a hand of eight
from fifty is a build, and two runs never draw the same deck.

### Warden — at your shoulder (per Warden)

| Card | Pattern | Element | The rule |
|---|---|---|---|
| **Lantern Ward** | WARD | air | every 9 s, a ward of 10% of your pool |
| **Marrow Mend** | MEND | water | every 7 s, 8% of what you are missing comes back |
| **Thornskin** | RETORT | earth | struck, thorns burst 90 units round you; once every 2.5 s |
| **Guardian Stones** | GUARD | earth | two stones circle you and each swallows one shot; a stone reforms every 8 s |
| **Frostbound Ring** | FIELD | water | bodies within 120 units are slowed 30% and soaked |

### Rampart — the towers near the Warden (the party's)

| Card | Pattern | Element | The rule |
|---|---|---|---|
| **Mason's Wisps** | MEND | earth | every 6 s each tower near you mends 5% of what it is missing |
| **Ward Lattice** | WARD | air | every 12 s each tower near you gains a ward of 12% |
| **Kiln Skin** | RETORT | fire | a tower near you that is struck burns what struck it; once every 3 s a tower |

### Hearth — the town (the party's)

| Card | Pattern | Element | The rule |
|---|---|---|---|
| **Hearthstone** | MEND | holy | every 10 s the wall mends 1.5% of what it is missing |
| **Gate Ward** | WARD | holy | every 15 s the gate gains a ward of 5% |

Levels I to V climb the share (`level_damage` is the ladder for a share as
it is for a hit), the count (a third stone, a second ring) and the radius,
through the same three arrays every weapon carries.

### Catalyst

**Steadfast Salt** — the Arsenal's wards and mends are worth more
(`arsenal_guard`, read only by the five patterns above; Kindled Heart moves
the blows and never these).

### Evolutions

| Base at V | + Catalyst | Becomes |
|---|---|---|
| Lantern Ward | Steadfast Salt | **Aegis of the Road** — the ward falls on every Warden and every tower near you |
| Guardian Stones | Twin Casting | **Stone Choir** — a stone that swallows a shot throws it back |

Both open from Act III, as the four offensive evolutions do.

### Refused, and why

- **Damage reduction, armour, resistances as cards.** A number nobody sees; the
  third power scale. Resolve is the attribute for that and it is capped.
- **Invulnerability windows, immunity frames.** A window in which nothing lands
  is a window in which the pressure curve measures nothing.
- **Life on kill as a card.** Wellspring and the drain's own draught already
  are; a card that does it for every blow makes the horde a health bar.
- **A ward on the spirit companion.** The companion's power is capped by
  `SPIRIT_APEX_POWER` and a ward on it is a second pool nobody tuned.
- **Reflecting a share of *every* blow (true thorns).** A retort is a burst
  the anchor answers with, once a cadence; a share of every blow returned
  scales with the road's own damage ladder and would out-hit the weapons by
  Act X.

## 4. The pictures

Every one of the five patterns has a forged sheet, made through
`tools/vfx_forge` (Blender, `effects/<id>.py`) as the twenty-four before it
were, tinted per card so one sheet serves every element:

- `ward_bloom` — a ring of light closing over the body from the ground up
- `mend_motes` — motes rising and gathering into the chest
- `thorn_burst` — a radial burst of spikes, upright (never turned)
- `guard_shatter` — a stone breaking into chips where a shot was swallowed
- `frost_ring` — a low, slow ring drifting outward, flattened for the camera

Played through `Vfx.forge_play` with the take, the turn, the flip and the size
wander every forged sheet gets, capped by `Graphics.particle_scale` and damped
by `JuiceDirector` as COSMETIC. A guard's stones and a field's ring are drawn
by the Arsenal's own `_draw`, as the orbits are.

## 5. The gate

`arsenal_check` grows a section a pattern, on the real field:

- a WARD fires on its cadence, is worth its share of the anchor's pool and no
  more, and never past the ceiling whatever the data authors;
- a MEND heals a share of what is *missing* — a whole anchor is mended by
  nothing — and the wall's is under its own ceiling;
- a RETORT fires when the anchor is struck, once a cadence, through the
  ledger, and never when the anchor is left alone for a minute;
- a GUARD swallows a real hostile shot, spends a stone, and reforms it on its
  clock; a swing is not swallowed;
- a FIELD slows a body inside it and leaves one outside it alone, and moves
  nothing;
- every defensive card's `modelled_dps` is 0 and `curve_report` reads the same
  band as before this document;
- the deck's ratio is held: at least a quarter of the weapons are defensive.

Three faults to plant before it is believed: a ward past its ceiling, a retort
firing on its own clock, and a mend on a whole pool.
