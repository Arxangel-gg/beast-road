class_name ArsenalWeaponData
extends GameData

## **One way of killing** - a weapon of the Arsenal (owner, 2026-09-27;
## `docs/AUTO_ARSENAL_2026-09-27.md`).
##
## A Road Card names one of these (`RoadCardData.weapon`) and the hand holding
## that card fires it on its own clock, anchored to the Warden, the towers or the
## town. The eight patterns are code, once, in `Arsenal`; every weapon is this
## file (working rule 3).
##
## **The bound is one formula** (`Arsenal.hit_for`): a hit is `damage` times the
## level, the act, the owner's own damage multiplier - Might from level and gear,
## the chain's form, the hand - and the Arsenal's own power. Nothing else
## multiplies it, and every blow goes through `Enemy.take_damage`.

## **Appended, never inserted** - data indexes these by number.
enum Pattern {
	## Bodies circle the anchor and cut what they touch.
	ORBIT,
	## Homing bolts at the nearest bodies.
	SEEKER,
	## A strike that leaps from body to body.
	CHAIN,
	## A pulse around the anchor.
	NOVA,
	## Patches left where the anchor walked, biting whatever stands in them.
	TRAIL,
	## Something falls on the thickest knot of bodies, telegraphed.
	STRIKE,
	## A body that dies lets something go to hunt the next.
	ON_KILL,
	## Lightning hangs between two anchors and bites what crosses it.
	ARC,
	# --- The defence (docs/ARSENAL_DEFENSIVE_2026-09-28.md) --------------------
	# Appended, never inserted: every `.tres` names its pattern by number.
	## On a cadence, the anchor gains a ward worth a share of its own pool.
	WARD,
	## On a cadence, the anchor heals a share of what it is missing.
	MEND,
	## When the anchor is struck, a burst hits the bodies at it, once a cadence.
	RETORT,
	## Stones orbit the Warden and swallow hostile shots; one reforms on a cadence.
	GUARD,
	## Bodies inside a ring round the anchor are slowed and wetted while they stand in it.
	FIELD,
}

enum Anchor {
	## The Warden who holds the card. Per Warden in co-op.
	WARDEN,
	## Every tower on the board. The party's.
	TOWERS,
	## The town. The party's.
	TOWN,
}

@export var pattern: Pattern = Pattern.SEEKER
@export var anchor: Anchor = Anchor.WARDEN
## `TowerData.Element`, for the mark a hit leaves, the burst it lands with and
## what reads the element downstream (Wet, a charged ground, the kill's end).
@export var element: int = 0
## The colour it is drawn in.
@export var tint: Color = Color(1.0, 0.72, 0.35)

## A hit at level I, in Act I, from a Warden with no Might and nothing in hand.
@export var damage: float = 10.0
## Seconds between firings. For an orbit, the gap before one orb may cut the
## same body again; for a trail, how often a patch bites.
@export var cooldown: float = 1.0
## Orbs, bolts, jumps, rocks or patches, at level I.
@export var count: int = 1
## The orbit's ring, the pulse's reach, a blast, a patch, an arc's width.
@export var radius: float = 60.0
## How far it looks for a body.
@export var reach: float = 420.0
## Radians a second for an orbit; units a second for a bolt.
@export var speed: float = 3.0
## How long a patch stands or a burn lasts.
@export var duration: float = 0.0
## A share of the hit laid on as a burn over `duration`; nought for none.
@export var burn_share: float = 0.0
## A slow laid on a hit (0.6 is to sixty per cent speed); one for none.
@export var slow: float = 1.0
@export var knockback: float = 0.0
## For a weapon on the board: it fires every this many kills on the road rather
## than on a clock. Nought for a clock.
@export var every_kills: int = 0

## What each level multiplies the hit by, and adds to the count and the reach.
@export var level_damage: Array[float] = [1.0, 1.25, 1.55, 1.85, 2.2]
@export var level_count: Array[int] = [0, 0, 1, 1, 2]
@export var level_radius: Array[float] = [1.0, 1.0, 1.1, 1.2, 1.3]

## **How many bodies a hit typically lands on in a road crowd** - the one number
## `curve_report` needs to model a weapon, and the one `arsenal_check` measures
## against a real crowd so the curve cannot be tuned on a model the fight
## disagrees with.
@export var crowd: float = 1.0

## The painted projectile head it is drawn with ("fire", "water", "earth",
## "air"), or "" for the element's silhouette.
@export var head: String = ""
## The forged effect played where it lands, from `Vfx.FORGE_CATALOGUE`.
@export var effect: String = ""
## **A spirit it lets go, drawn as itself** (2026-10-08: "some arsenal/augments
## give spirits ... I have not seen any such thing happen"). The painting at
## `res://art/vfx/spirit_<spirit>.png` with its idle frames, risen out of the
## body that fell and flown at a pace the eye can follow; "" draws the head.
## A look: what it strikes and for how much is the weapon's.
@export var spirit: String = ""

## **The defence's number**: a WARD's share of the anchor's pool, a MEND's share
## of what the anchor is missing, at level I; `level_damage` is its ladder.
## Never a figure - a Warden at level 100 and one at level 1 hold the same card
## and it means the same to each (docs/ARSENAL_DEFENSIVE_2026-09-28.md §2).
@export var share: float = 0.0
## Aegis of the Road: a Warden's ward also falls on every other Warden and on
## the towers near them.
@export var spread: bool = false


## A weapon has no picture of its own: the card carries the icon.
func get_sprite_path() -> String:
	return ""


func damage_at(level: int) -> float:
	return damage * level_damage[clampi(level - 1, 0, level_damage.size() - 1)]


func count_at(level: int) -> int:
	return count + level_count[clampi(level - 1, 0, level_count.size() - 1)]


func radius_at(level: int) -> float:
	return radius * level_radius[clampi(level - 1, 0, level_radius.size() - 1)]


## **What this weapon deals a second at a level, in the model.** A hit, and the
## burn it lays on, times the bodies one lands on, times the shots, over the
## cadence - the one line `curve_report` and `arsenal_check` both read, so they
## cannot disagree about what a weapon is supposed to do.
func modelled_dps(level: int) -> float:
	# **Pure defence moves the curve by exactly nothing**, and a retort is
	# modelled at zero as well: it fires only when something has already
	# landed a blow on the anchor, and a best case that assumed the Warden is
	# hit on a schedule would model a player the road never produces.
	if is_defensive():
		return 0.0
	return damage_at(level) * (1.0 + burn_share) * float(maxi(count_at(level), 1)) \
		* crowd / maxf(cooldown, 0.05)


## Whether this is one of the five defensive patterns.
func is_defensive() -> bool:
	return pattern in [Pattern.WARD, Pattern.MEND, Pattern.RETORT, Pattern.GUARD, Pattern.FIELD]


## The share at a level: the authored share up the same ladder a hit climbs.
func share_at(level: int) -> float:
	return share * level_damage[clampi(level - 1, 0, level_damage.size() - 1)]
