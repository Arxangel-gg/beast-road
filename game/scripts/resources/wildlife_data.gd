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

## Seconds this creature stays before wandering off, as a range.
@export_range(4.0, 600.0) var stay_min: float = 30.0
@export_range(4.0, 600.0) var stay_max: float = 90.0


## True for anything that gets about in hops rather than strides.
##
## Declared rather than inferred from size, because it decides which gait a
## single authored walk frame is given: a rabbit with one frame should bound,
## and a bear with one frame absolutely should not.
@export var hops: bool = false


## True for anything that will fight rather than flee.
func is_hostile() -> bool:
	return damage > 0.0 and (temperament == Temperament.TERRITORIAL
		or temperament == Temperament.PREDATORY)


func get_sprite_path() -> String:
	return GameData.derive_path("wildlife", "wildlife_", id)
