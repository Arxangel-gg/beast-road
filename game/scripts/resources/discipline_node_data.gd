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
