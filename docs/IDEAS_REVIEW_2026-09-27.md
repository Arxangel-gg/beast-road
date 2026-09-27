# Ideas review — the Auto-Arsenal, what is built and what comes next

**27 September 2026 · owner asked for the list, and for it to be kept**

The source is the second half of `AUGMENT_CATALOGUE_2026-09-26.md`: about two
hundred auto-attacking augments forwarded as inspiration "for implementation,
adaptation, or rejection". The first build of the Arsenal took fourteen of them
(`AUTO_ARSENAL_2026-09-27.md`, shipped in v0.59.0). This is the triage of the
rest: what is worth building, in what order, and what is refused and why.

Every recommendation is held to the bounds the Arsenal was built under: every
blow through `Enemy.take_damage` and named in the ledger, one formula, no weapon
fires a weapon, records never nodes, and every weapon modelled by
`curve_report` and measured against that model by `arsenal_check`.

## 1. Built (v0.59.0)

**At the Warden's side** (a seat's own card in co-op)

| Weapon | Pattern | Element | Rarity |
|---|---|---|---|
| Ember Wisps | orbit | fire | Common |
| Frost Shards | orbit | water | Uncommon |
| Seeking Flames | seeker | fire | Common |
| Chain Spark | chain | air | Uncommon |
| Thunderclap | nova | air | Uncommon |
| Thorn Wake | trail | earth | Common |
| Stone Rain | strike | earth | Rare |
| Marrow Seekers | on kill | air | Rare |

**On the towers near a Warden** (the party's): Sentry Wisps (orbit), Arc
Lattice (arc), Fortress Barrage (strike every twelve kills).

**On the town** (the party's): Falling Stars (strike), Bell of the Hold (nova),
Soulfire (on kill).

**Evolutions**: Sunwheel (Ember Wisps + Twin Casting), Stormcrown (Chain Spark
+ Quickening Oil), Worldbreaker (Stone Rain + Wider Wake), Briar Sea (Thorn Wake
+ Long Burn).

**Catalysts** (move numbers only the Arsenal reads): Quickening Oil (cadence),
Twin Casting (volley), Wider Wake (reach), Long Burn (duration), Kindled Heart
(power).

## 2. Recommended, in order

### 0. The Arsenal joins the elemental reactions — **built 2026-09-27**

It shipped without them. A water weapon never soaked a body and an air weapon
never hit a soaked body harder, so Frost Shards and a storm tower were two
halves of a combo that did not meet. `Arsenal.strike_body` now follows
`Tower._hit`'s rules: air hits a wet body `WET_SHOCK_DAMAGE` harder, water
leaves what it hits wet, and a chain leaving a wet body leaps `WET_CHAIN_RANGE`
further, as the sky's own lightning does. Steam and wet chill were already
inside `apply_burn` and the chill meter.

**Deliberately not joined**: the earth's strain (ember, tide, tremor). A tower's
shot feeds it; the Arsenal is half the defence after Act I, and feeding it would
change how often the earth's events arrive against a wrath curve that is hidden
and tuned. And an Arsenal fire does not light the brush, or Ember Wisps would
burn every forest it circled. Both are decisions to revisit, not omissions.

### 1. New elements for the existing patterns — **built 2026-09-27**

Data files only; every pattern already exists. Each fills an element the
pattern lacked.

| Weapon | Pattern | Element | Rarity | What it is for |
|---|---|---|---|---|
| Sawstones | orbit | earth | Uncommon | Slow, heavy discs that shove |
| Ice Needles | seeker | water | Common | Rapid bolts that slow and soak |
| Arcane Missiles | seeker | air | Uncommon | A swarm of weak bolts; hits soaked bodies harder |
| Flame Nova | nova | fire | Common | A pulse that leaves bodies burning |
| Frost Nova | nova | water | Rare | A wide pulse that slows hard and soaks everything in it |
| Flame Trail | trail | fire | Common | Thorn Wake's fire: walking leaves burning ground |
| Frost Trail | trail | water | Uncommon | Walking leaves ice that slows and soaks |
| Lightning Strike | strike | air | Uncommon | Bolts called onto knots of bodies near you |
| Ice Pillar | strike | water | Rare | A spike under the thickest knot; slows and soaks |

Water now has five weapons that soak and air five that conduct, so a water
weapon and an air weapon in one hand are a build rather than two cards.

### 2. New ways of killing — a pattern each, then data

| Idea | New pattern | Note |
|---|---|---|
| Sunray | beam, rotating | The fire wyrm's beam art exists (`beam_core`) |
| Frost Ray | beam, locked on | Slows harder the longer it holds |
| Shrapnel Burst | radial volley | Bolts in every direction |
| Thunderstep | distance trigger | Lightning every so many steps walked; rewards moving |
| Runic Footsteps | mine | A rune left behind that bursts when stepped on |
| Stone Fissure | travelling line | A crack through a crowd; the earthquake's fissure art |
| Spirit Raven | boomerang | Out, strike, return: the "summons" as an effect |
| Static Revenge, Flame Retort, Shield Shatter | on hit | When struck, or when a ward breaks; capped a second |
| Emergency Nova | low health | Fires on its own, long cooldown |
| Interceptor Orb | anti-shot | Shoots down hostile shots; the Stillwater Mirror already swallows them |
| Blade Dash | along movement | Blades thrown the way you are walking |

### 3. Targeting catalysts — cheap, and the most variety for the least code

Each changes what every weapon aims at, never how hard it hits: the keystone
bound. Giant Slayer (elites and bosses first), Executioner (lowest health
first), Threat Response (closest to the town first), Guardian Instinct (bodies
attacking a tower first — the answer to the siege orders).

### 4. Tower-linked — what only this game can do

Elemental Network (the Arsenal takes the element of the nearest tower), Tower
Echo (a weapon that fires a copy of the nearest tower's shot), Overcharge Pulse
(walking past a tower makes it fire faster for a moment — the Warden's position
deciding which stretch of wall fights harder).

### 5. Super-weapons — long cooldown, from art that exists

Dragon Pass (a spectral dragon crosses breathing its element; the dragon art
and the breath exist), Wild Hunt (spectral riders gallop down a road; the
mounts' gallop sheets), Stormfront (a storm walks a lane), Meteor Mark (an
elite's death calls a meteor).

### 6. Evolutions for the weapons that have none

Every weapon evolves in the genre this is drawn from. At the Warden's side:
Hailstorm Crown (Frost Shards + Long Burn), Phoenix Volley (Seeking Flames +
Kindled Heart), Skybreaker (Thunderclap + Wider Wake), Grave Cascade (Marrow
Seekers + Twin Casting).

**The board's weapons should evolve by pairing two of them**, not by a
catalyst: in co-op a catalyst is a Warden's own card and a board weapon is the
party's, so a board evolution that wanted a catalyst would need two hands to
agree. Tesla Bastion (Arc Lattice + Sentry Wisps), Starfall Bell (Falling Stars
+ Bell of the Hold), Pyre Barrage (Soulfire + Fortress Barrage).

## 3. Refused, and why

- **Pulls and pushes that move bodies off the road** (Black Hole, Gravity Well,
  Gravity Pulse, Repulsion Field): morale's bound — nothing relocates a body.
  Knockback stays; a shoved body walks back.
- **Summons with a body** (Ghost Knight, Stone Golem, Phantom Archer,
  Dragonling, Living Vine, Ancient Guardian, Afterimage, Stampede): the party
  roster §54 cuts, and the spirit companion is that body already. The good ones
  are recast above as effects.
- **Multipliers on everything** (Echo Cast, Multicast, Chain Echo, Chain
  Reaction, Delayed Echo): a third power scale nobody tunes against, and a
  weapon that fires a weapon never ends.
- **Weapons that spend resources** (Coin Cannon, Ore Shrapnel, Blood Engine,
  Wrath Engine, Interest Barrage): they compete with the wall for its money or
  its health, which Megabonk's own patch notes record as the failure.
- **Wrath and disaster linked** (Wrathstorm, Quakeborn, Tornado Child, Meteor
  Kin, Wildfire Spirits, Stormcaller): the earth's wrath is hidden by design and
  a weapon that grew with it would be a readout. Visible weather is different —
  marks already read it — and a weather-favoured catalyst is a fair later idea.
- **Poison** (Poison Needles, Poison Bloom, Poison Mist, Pestilent Death, Plague
  Comets): there is no poison status; it would be a new status system first.
- **Healing** (Life Drain Field, Healing Wisp, Bloodroot, Sanctuary Pulse):
  recovery is scarce on purpose, and `FISH_MEALS_PER_RUN` is the bound that
  keeps it so.
- **The Mythic tier** (Tempest Crown, World Engine, Living Fortress and the
  rest): an evolution is the top of a weapon; a tier above it is the next thing
  to build once these have been played.

## 4. What building the first batch found

Adding the nine weapons read as a harder road, which is backwards, and the
reason was three faults rather than the weapons (`AUTO_ARSENAL_2026-09-27.md`
§7): the curve's model drafted greedily and never evolved, its party replays
held the solo run's finished hand from wave 1 and hid that a party ranked far
faster than a player, and an evolved weapon was dealt again. All three are
fixed; evolutions open from Act III and the Arsenal's late ladder is flatter,
measured back into the band.

## 5. Art

PixelLab is spent until 2026-10-11. New card icons are composed from shipped
paintings (`tools/compose_arsenal_icons.py`), as the first twenty-three were.
Bespoke paintings are an October job, and installing one is overwriting its
file.
