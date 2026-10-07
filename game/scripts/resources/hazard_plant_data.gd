class_name HazardPlantData
extends GameData

## **A plant that hurts** (owner, 2026-10-07): *"Each act should also have a
## variety of harmful plants that can hurt the players and other characters in
## different ways, from simply walking through them to outright spitting ranged
## projectiles at players and having different states to hide or come out and
## attack while out."*
##
## Four ways a plant can hurt, each a different question for the player:
##
## - **THORNS** are always out. Whatever wades into one is cut a little every
##   moment it stays and is slowed while it is in - the answer is to go round.
## - **SPORES** are a pod. Something coming near makes it swell, and then it
##   bursts - the answer is to see the swelling and step back.
## - **A SNAPPER** lies hidden as a mound. Step close and it rears up and bites
##   where you stood - the answer is not to stand still beside a mound.
## - **A SPITTER** lies hidden as a bud. Anything inside its range wakes it; it
##   opens and lobs at the thing, a while, then closes again - the answer is to
##   leave its range, or to cut it down.
##
## **Shares, never numbers**, as the dungeon's plates are: a blow takes
## `hero_share` of a Warden's own pool, `body_share` of a road body's and
## `animal_share` of an animal's, so a plant on the Chainmaker's Road is as
## dangerous to a Warden as one on the Long Road and never a wall for a new one.

enum Behaviour {
	THORNS,
	SPORES,
	SNAPPER,
	SPITTER,
	## Appended, never inserted - `.tres` files index this enum by number.
}

@export var behaviour: Behaviour = Behaviour.THORNS
## The acts this plant grows in. A plant listing none grows in none.
@export var acts: Array[int] = []
## How likely this plant is beside the other plants of its act.
@export var weight: float = 1.0
## The radius of the hurt: the patch, the burst, the bite or the spit's splash.
@export var reach: float = 60.0
## How close something has to come to wake a pod, a mound or a bud.
@export var trigger: float = 120.0
## A spitter's range.
@export var spit_range: float = 420.0
## A share of the pool of whatever it hurts, per blow.
@export_range(0.0, 0.5) var hero_share: float = 0.05
@export_range(0.0, 0.5) var body_share: float = 0.08
@export_range(0.0, 1.0) var animal_share: float = 0.15
## The tell before a blow lands: a pod swelling, a mound rearing, a spit in
## flight. Thorns have none - they are the tell.
@export var telegraph: float = 0.7
## Between blows (a spitter's spits) or before a spent pod or a mound rearms.
@export var cooldown: float = 3.0
## How long a spitter stays open with nothing to spit at before it closes.
@export var out_seconds: float = 5.0
## The share of its speed a mover keeps inside thorns (1.0 slows nothing).
@export_range(0.2, 1.0) var slow: float = 1.0
## How much cutting it takes to clear it: Warden blows, in its own pool.
@export var max_hp: float = 40.0
## The colour of its tell and its blow.
@export var tint: Color = Color(0.55, 0.85, 0.35, 1.0)
## How big it is drawn.
@export var scale: float = 1.0


func get_sprite_path() -> String:
	return derive_path("hazards", "hazard_", id)


## The painting it wears while hidden - a pod spent, a mound closed, a bud shut.
func hidden_path() -> String:
	var base: String = get_sprite_path()
	return "" if base.is_empty() else "%s_hidden.png" % base.get_basename()


func hides() -> bool:
	return behaviour != Behaviour.THORNS


## Whether it rests hidden and comes out to strike (a mound, a bud) - a pod
## rests full and lies spent only after it bursts.
func starts_hidden() -> bool:
	return behaviour == Behaviour.SNAPPER or behaviour == Behaviour.SPITTER
