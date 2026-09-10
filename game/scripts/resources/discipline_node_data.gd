class_name DisciplineNodeData
extends GameData

## One authored node in the Mansion's three discipline trees. Acquisition,
## slot role and the implemented spell adapter all live in data; the Mansion UI
## never branches on a node id.

enum Discipline { BLOOD, HOLY, BERSERK }
enum Role { ATTACK, DEFENSE, POWER, PASSIVE, ULTIMATE, AUGMENT }

@export var discipline: Discipline = Discipline.BLOOD
@export var role: Role = Role.ATTACK
@export_range(1, 3) var mansion_tier: int = 1
@export var food_cost: int = 45

## Optional adapter to an existing fully implemented SpellData. Empty means the
## node modifies core combat or is a passive/augment rather than a cast.
@export var spell_id: String = ""

## A semantic effect key and bounded magnitude for core-combat consumers.
@export var effect_id: String = ""
@export var effect_value: float = 0.0

## **How deep into this node's own discipline the player must already be.**
##
## The trees used to be three flat lists gated only by Mansion tier, which is a
## *building* level rather than anything the player chose - so every node was
## available to everyone at the same time and a Blood hero differed from a Holy
## one only by which four things happened to be slotted. There was no path, and
## so no commitment and no build identity. Reported as the tree being
## "not interesting or smart/intuitive"; owner asked for Diablo-style paths on
## 2026-09-09.
##
## Counted rather than graphed: a node needs N nodes of the *same* discipline
## trained before it can be offered, instead of naming particular predecessors.
## Two reasons. A count cannot author an unreachable node the way a hand-drawn
## graph can - `discipline_check` caught exactly that failure once already, when
## a hash rotation left `call_wolf` unofferable across 480 roads. And it leaves
## the shape of a tree to the tiers that already exist rather than inventing a
## second structure to keep in step with them.
##
## -1 derives it from the tier, which is the intended shape: tier 1 opens a
## discipline, tier 2 wants one node in it, tier 3 wants two. Authoring a value
## overrides that for a node that should sit deeper or shallower than its tier.
@export var requires_depth: int = -1


## Nodes of this discipline that must already be trained before this is offered.
func required_depth() -> int:
	return requires_depth if requires_depth >= 0 else maxi(mansion_tier - 1, 0)


func get_sprite_path() -> String:
	return GameData.derive_path("icons/disciplines", "discipline_", id)


func is_active_slot() -> bool:
	return role in [Role.ATTACK, Role.DEFENSE, Role.POWER, Role.ULTIMATE]


func slot_index() -> int:
	match role:
		Role.ATTACK:
			return 0
		Role.DEFENSE:
			return 1
		Role.POWER:
			return 2
		Role.ULTIMATE:
			return 3
		_:
			return -1


func slot_name() -> String:
	match role:
		Role.ATTACK:
			return "Attack"
		Role.DEFENSE:
			return "Defense"
		Role.POWER:
			return "Power"
		Role.ULTIMATE:
			return "Ultimate"
		Role.AUGMENT:
			return "Augment"
		_:
			return "Passive"


func discipline_name() -> String:
	return ["Blood", "Holy", "Berserk"][clampi(int(discipline), 0, 2)]


func is_slot_unlocked(act: int) -> bool:
	match role:
		Role.POWER:
			return act >= 2
		Role.ULTIMATE:
			return act >= 3
		_:
			return true
