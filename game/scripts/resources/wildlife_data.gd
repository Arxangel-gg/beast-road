class_name WildlifeData
extends GameData

## One kind of animal that lives off the roads.
##
## Data, like everything else that can be added to (working rule 3): a new
## creature is a `.tres` and a sprite, never a branch in the spawner. The sprite
## path is derived from the id by the usual convention, so `id = "fox"` loads
## `res://art/wildlife/wildlife_fox.png` and its idle frames follow from that.

## How an animal treats whatever comes near it.
##
## The whole point of the ladder is that **seeing an animal should not tell you
## what happens next**. A bear beside the road is a question - can I get round
## it? - and that question only exists because a bear is not simply an enemy
## walking at you. Four rungs, and every one behaves differently:
##
## * `PASSIVE` runs. Deer, rabbits, squirrels.
## * `CAUTIOUS` keeps its distance but is drawn to what you leave behind. Foxes,
##   raccoons, ravens.
## * `TERRITORIAL` ignores you until you are inside its ground, then commits.
##   Boar, badger, bear.
## * `PREDATORY` comes looking. Wolves, vipers, hawks.
##
## The two hostile rungs differ in *when* they start, not in how hard they hit,
## which is what makes walking past a boar a decision and walking past a wolf a
## race.
enum Temperament { PASSIVE, CAUTIOUS, TERRITORIAL, PREDATORY }

## How this species occupies space when it is not fighting.
##
## Authored in data rather than inferred from an id: a later mountain goat may
## graze like a deer and a marsh bird may forage on foot even though both are
## completely different sprites. The system supplies steering; the resource
## says which natural rhythm belongs to this animal.
enum MovementStyle { GRAZER, FORAGER, PROWLER, SOARER, SKITTER }

## How often this species turns up, against the others.
##
## **The tier decides the order of magnitude; `weight` only nudges within it.**
## The two multiply, and the tiers are spaced far enough apart that no nudge in
## the authored range can lift a Rare above an Uncommon - which is the property
## that makes a second number safe here. Reach for `weight` to say "commoner
## than the other commons", and for `rarity` to say anything larger.
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON


## How likely this is in a given act, against everything else.
##
## Rarity sets the base; the act it belongs to multiplies it. **A preference, not
## a gate** - the same reasoning weather got: an act that admits only its own
## list has character by having nothing else to offer, which is not the same as
## having character. A bear in Act I is a story; a bear that is impossible there
## is a rule nobody can see.
func roll_weight(act: int) -> float:
	var base: float = 1.0
	match rarity:
		Rarity.COMMON:
			base = 2.4
		Rarity.UNCOMMON:
			base = 1.2
		Rarity.RARE:
			base = 0.45
		Rarity.LEGENDARY:
			base = 0.12
	base *= maxf(weight, 0.0)
	if acts.is_empty() or acts.has(act):
		return base
	# Out of its own region, and much rarer for it, but never impossible.
	return base * 0.22

@export var temperament: Temperament = Temperament.PASSIVE
@export var movement_style: MovementStyle = MovementStyle.FORAGER

## Damage per strike. Zero for anything that does not fight.
##
## Scaled against the *enemy* roster, whose contact damage runs 6 to 34. Nothing
## in the wilderness should hit harder than the hardest thing the road sends -
## the bear was on 54, and an elite bear at 1.45x took a 100 HP hero off the
## board in two swings, which makes an ambient system the deadliest content in
## the game.
@export_range(0.0, 200.0) var damage: float = 0.0

## Seconds between strikes.
@export_range(0.2, 6.0) var attack_interval: float = 1.1

## How close it must be to strike.
@export_range(20.0, 400.0) var attack_range: float = 90.0

## How far it notices something worth attacking.
##
## For a territorial animal this is the edge of its ground: cross it and it
## commits. For a predator it is how far it will come looking. The same number
## means two different things on purpose - one is a boundary, the other a reach.
@export_range(0.0, 1400.0) var aggro_radius: float = 0.0

## Knockback dealt per strike.
@export_range(0.0, 800.0) var knockback: float = 0.0

## How fast it moves while hunting, as a multiple of its walking speed.
##
## **Keep `speed * charge_speed_scale` under `Balance.HERO_MOVE_SPEED`**, with
## the boar and the hawk as the deliberate exceptions - the charger and the
## flier are the two that are *meant* to catch you.
##
## Four of the six originally sustained 218-385 units/s against a hero that walks
## at 200, so a hunt could not be broken by moving: whatever the hunt timer said,
## the animal stayed in contact until one of them died. A predator you cannot
## walk away from is not a predator, it is a timer on your health bar.
@export_range(1.0, 5.0) var charge_speed_scale: float = 1.7

## Chance this one arrives as an elite, 0 to 1.
##
## An elite is the same animal grown and scarred rather than a different one:
## bigger, tougher, hits harder, worth more. The player has to be able to *see*
## it coming, so the tell is size and colour rather than a name in a tooltip.
@export_range(0.0, 1.0) var elite_chance: float = 0.0

## Which acts this creature belongs to. Empty means all of them.
##
## A deer in the ash wastes of Act III would be saying the wrong thing about the
## place, and the point of ambient life is that it describes where you are.
@export var acts: Array[int] = []

## How likely this one is, relative to the others available.
@export_range(0.0, 10.0) var weight: float = 1.0

## How many arrive together. A fox is alone; deer are not.
@export_range(1, 8) var group_min: int = 1
@export_range(1, 8) var group_max: int = 1

## Preferred room between members of the same arrival group. This is a soft
## steering radius, backed by a harder spawn clearance in Balance.
@export_range(24.0, 260.0) var social_spacing: float = 82.0

## How strongly a social animal stays near its group's moving centre, 0..1.
## Solitary creatures leave this at zero.
@export_range(0.0, 1.0) var group_cohesion: float = 0.0

## Share of an idle pause spent moving. A grazer takes measured steps; a
## squirrel works in short bursts; a soaring bird almost never freezes aloft.
@export_range(0.15, 1.0) var activity: float = 0.55

## World units per second while moving.
@export_range(4.0, 240.0) var speed: float = 34.0

## How far it will wander from where it arrived, in world units.
@export_range(0.0, 900.0) var roam: float = 240.0

## How close something frightening gets before it bolts.
##
## Zero means nothing frightens it, which is right for a raven: they are the
## animals that turn up *because* of a battle rather than in spite of one.
@export_range(0.0, 900.0) var skittish_radius: float = 260.0

## Multiplier on how fast it moves while fleeing.
@export_range(1.0, 6.0) var flee_speed_scale: float = 2.6

## True for anything that arrives and leaves by air.
##
## A flier ignores the ground rules on the way in and on the way out - it is
## crossing the sky, not the field - and obeys them only while it is down.
@export var flies: bool = false
## Whether it can get up a tree when the ground floods. A climber makes for
## the nearest trunk and waits the water out; a flyer leaves; anything else
## small enough drowns where it stands. See `Wildlife._on_flood`.
@export var climbs: bool = false

## **Lives in the water and comes out of it** (owner, 2026-09-16).
##
## An amphibious animal is placed in a pond, spends most of its life submerged or
## lying at the surface with only its eyes showing, and hauls out onto the bank
## for a while before going back in. Everything else about it is ordinary
## wildlife - it is bonded, hunted, bred, coated, counted by the earth and drawn
## on the map through exactly the same doors as a deer.
##
## The four water states are drawn from this one sprite by `submerged.gdshader`,
## which grades and bends whatever sits below a waterline. Nothing extra is
## painted for them.
@export var amphibious: bool = false

## How long it lies in the water between haul-outs, and how long it stays out.
## A predator waiting at the surface is the state worth watching, so the water
## half is the long one.
@export var water_seconds: Vector2 = Vector2(22.0, 60.0)
@export var land_seconds: Vector2 = Vector2(12.0, 34.0)

## How much faster it moves submerged than it walks. Water is where it is
## dangerous and where it is hardest to see; the bank is where it is slow.
@export_range(1.0, 4.0) var swim_speed_scale: float = 1.9

## Short isolated call used on arrival and on a committed strike. Kept in the
## creature resource so adding wildlife also states which recording it needs;
## a missing file is a supported silent state until the prompt is generated.
@export var vocal_sfx: String = ""

## Drawn size, as a multiple of the sprite's own pixels.
##
## Judge these against the hero, not against each other: the hero is 128px of art
## at `HERO_SPRITE_SCALE` 1.75, so about 224 world units tall. A deer stands with
## its back at roughly a person's shoulder, so it wants ~200 units — which at
## 64px of art means a scale near 3, not near 1. The first pass had every one of
## these under 1 and they read as toys on the grass.
@export_range(0.2, 6.0) var scale: float = 1.0

## True when the source art faces right. All six ship facing **left**.
##
## Declared rather than assumed, because assuming is what went wrong: the flip
## was written for right-facing art against sprites that were drawn facing left,
## so every animal in the game walked backwards.
@export var art_faces_right: bool = false

## **Drawn from above rather than from the side.**
##
## A moth and a butterfly are painted head-up, wings spread either side. The
## field was flipping them horizontally and adding a small banking roll,
## which is what a profile sprite wants and leaves a top-down one pointing
## north however it flies - reported 2026-09-13 as flyers "90 degrees off
## from the direction they're moving in". A top-down flier is rotated onto
## its heading instead, and never mirrored.
@export var art_top_down: bool = false

## What it takes to bring one down, and what it is worth.
##
## All three scale together with the animal's size, which is what makes hunting a
## *choice*: a deer is worth crossing the field for and costs several swings, a
## squirrel is a swing of opportunity. Nothing here is scaled by hero damage or
## by the run - hunting is a thing to do while crossing the field, not an economy,
## and a rabbit worth a tower would turn every Preparation into a larder.
##
## Food is a range rather than a number so two deer are never worth exactly the
## same, rolled from the wildlife stream so a seeded replay is unchanged by
## whether anybody stopped to hunt.
@export_range(1.0, 400.0) var max_hp: float = 30.0
@export_range(0, 90) var food_min: int = 4
@export_range(0, 90) var food_max: int = 8
@export_range(0, 400) var xp_reward: int = 6

## Whether this animal carries stolen goods.
##
## The road's answer to a loot goblin, adapted rather than borrowed: a hoarder
## drops Gold and may drop gear when it is killed, and when its patience runs
## out it does not walk off - it bolts through a rift and is gone, goods and
## all. That makes it a prize with a clock on it: worth leaving the line for,
## and worth the bow, since it runs faster than the hero walks.
@export var hoards: bool = false
## How often a hoarder is born with its sack. Below one, a sackless one is a
## thief with nothing yet - see `steals` - and the sack is the tell that this
## particular animal is worth the chase (owner brief, 2026-09-14: "not every
## raccoon has loot").
@export_range(0.0, 1.0) var hoard_chance: float = 1.0
## Whether this animal hunts loot: takes the richest drop lying on the ground
## within reach of its nose, runs it to cover and lies low, and forages the
## foliage when it has nothing. What it carries falls when it dies and goes
## with it when it rifts.
@export var steals: bool = false
@export_range(0, 400) var hoard_gold_min: int = 0
@export_range(0, 400) var hoard_gold_max: int = 0
@export_range(0.0, 1.0) var hoard_gear_chance: float = 0.0

## Seconds this creature stays before wandering off, as a range.
@export_range(4.0, 600.0) var stay_min: float = 30.0
@export_range(4.0, 600.0) var stay_max: float = 90.0


## True for anything that gets about in hops rather than strides.
##
## Declared rather than inferred from size, because it decides which gait a
## single authored walk frame is given: a rabbit with one frame should bound,
## and a bear with one frame absolutely should not.
@export var hops: bool = false


# --- Families and the Wildblight (owner brief, 2026-09-14) -----------------------
#
# Authored per species rather than inferred, for the reason everything else
# here is: a marsh bird and a wolf raise young differently, and a rule that
# guessed from `temperament` would have no way to say that a heron guides and
# a badger stands its ground. See `WildlifeFamilies` for what reads each.

## How a parent answers something that comes near its young.
##
## GUIDE takes them away - what a deer does. DEFEND puts itself between and
## fights for a moment - a badger, a boar. HUNT goes after it, which is what a
## predator does to everything anyway.
enum Protection { GUIDE, DEFEND, HUNT }

## Whether this species pairs and bears young at all. Off by default: a
## species opts in with a group to pair inside and a litter to bear.
@export var breeds: bool = false

## Who this species may pair with. Empty means "its own kind only"; a shared
## name is a breeding group, so a Deer and a Pale Stag may pair by both
## naming "deer". **Explicit rather than derived** - nothing about the two
## ids says they are the same animal, and a rule that guessed would pair a
## Snow Hare with a Saltpan Crab the day somebody renamed one.
@export var breeding_group: String = ""

## How many arrive at once, and how long after the mating they take.
@export_range(1, 6) var litter_min: int = 1
@export_range(1, 6) var litter_max: int = 1
@export_range(4.0, 300.0) var gestation_seconds: float = 40.0

## How strongly a pair that has succeeded before prefers each other, and how
## often one goes to a nearer stranger anyway. Both 0..1, and both read only
## when a familiar partner and a stranger are both in reach.
@export_range(0.0, 1.0) var loyalty: float = 0.5
@export_range(0.0, 1.0) var infidelity: float = 0.15

## How this species protects its young.
@export var protection: Protection = Protection.GUIDE

## The id of the young's own sprite, where one is drawn. Empty means the
## young wears the adult's art at a smaller size, which is right for most
## species and wrong for the antlered ones - a fawn with a full rack reads
## as a shrunken stag.
@export var young_id: String = ""

## Whether the Wildblight can take this species. True for everything by
## default: the condition is fictional precisely so that birds, reptiles and
## insects can catch it (rabies is a mammal's disease, and this roster is not
## all mammals).
@export var blight_eligible: bool = true

## What this species bites for while frenzied, when it has no bite of its
## own. A rabbit that turns has to be able to hurt something or the frenzy is
## a light show; a bear needs no help. Zero falls back to a small bite scaled
## by the animal's size.
@export_range(0.0, 60.0) var blight_damage: float = 0.0


## **What varies between two animals of a kind.** See `Phenotype`.
##
## Every species gets the three spreads for free - a slightly warmer or cooler,
## lighter or darker, richer or duller version of its own painting - because a
## field of six identical deer is the thing this exists to fix and authoring
## thirty-nine files to get it would mean most of them never got it.
##
## **A pattern is authored and is the species' own.** A rabbit does not grow
## stripes because a die came up stripes; a fallow deer has dapples and a badger
## has patches, and what a seed decides is *where they fall and how strongly*.
##
## **Appended, never inserted** - `.tres` files index this enum by number, and
## `Role` and `Trigger` both taught this project that in silence.
## **Appended, never inserted.** This is indexed by number out of every
## `.tres` that names a coat, and inserting a member in the middle silently
## repoints all of them - `Role` and `Trigger` both did exactly that here.
enum Coat { NONE, SPOTS, STRIPES, PATCHES, SOCKS,
	DAPPLE, BANDS, MASK, SPECKLE, COUNTERSHADE }
@export var coat_pattern: Coat = Coat.NONE
## How far a coat may wander from the painting, per species. Bounded again by
## `Balance.PHENOTYPE_*_CEILING`, which is the hard limit: past it the variation
## stops reading as an individual and starts reading as a rarity, and the rank
## sheen is what says rarity.
@export_range(0.0, 0.2) var coat_hue_spread: float = 0.018
@export_range(0.0, 0.5) var coat_light_spread: float = 0.10
@export_range(0.0, 0.6) var coat_saturation_spread: float = 0.12
## How strong the markings are at their strongest, how big they are in source
## pixels, and what colour they are. A pattern with a transparent tint marks
## nothing, which `phenotype_check` refuses.
@export_range(0.0, 1.0) var coat_pattern_strength: float = 0.0
@export_range(1.0, 32.0) var coat_pattern_scale: float = 6.0
@export var coat_pattern_tint: Color = Color(0.0, 0.0, 0.0, 0.0)


## **A classification rather than a sixth rarity.**
##
## `docs/IDEAS_REVIEW_2026-09-15.md` triaged a proposal for 112 mythical
## creatures and settled this: Mythic is a *classification*, because a sixth
## rarity moves nine tables - the wrath scale, the sheen ladder, the bond
## variants, the inheritance odds - and buys nothing the classification does not.
##
## A mythic is an ordinary animal in every respect the tables care about. What
## it is not is *scattered*: `Wildlife._pick_kind` never offers one, so the only
## way to meet it is to follow what it leaves behind. See `MythicTrail`.
@export var mythic: bool = false
## The signs this one leaves, by `TrailSignData` id. The trail deals one of each
## stage in order, so a species wants at least one sign per stage - a hole is a
## trail that ends early, and `mythic_trail_check` refuses one.
@export var trail_signs: PackedStringArray = PackedStringArray()
## The first act its trail may begin in.
@export_range(1, 10) var trail_first_act: int = 1


## **Half this roster does not give birth.**
##
## Owner brief, 2026-09-15 (the forwarded essay on egg and nesting ecology). The
## families built on 2026-09-14 place a cub beside its mother, which is right
## for a wolf and wrong for a crane. A laying species leaves a **nest** instead:
## the same clutch, rolled the same way, sitting on the ground and hatching by
## road walked. See `WildlifeNests`.
@export var lays_eggs: bool = false
## How much road the clutch needs before it opens. Zero uses the roster default.
@export_range(0.0, 400.0) var incubation_distance: float = 0.0


## The group this species pairs inside: its own name unless it shares one.
func breeding_group_id() -> String:
	return breeding_group if not breeding_group.is_empty() else id


func protection_of() -> Protection:
	return protection


## True for anything that will fight rather than flee.
func is_hostile() -> bool:
	return damage > 0.0 and (temperament == Temperament.TERRITORIAL
		or temperament == Temperament.PREDATORY)


func get_sprite_path() -> String:
	return GameData.derive_path("wildlife", "wildlife_", id)
