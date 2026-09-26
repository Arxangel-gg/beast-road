class_name DisciplineNodeData
extends GameData

## One authored node in the Warden's Disciplines: four arms around the Warden,
## kept on the account and edited in the Hold (owner ruling, 2026-09-26 - see
## `docs/SKILL_TREE_REWORK_2026-09-26.md`). Acquisition, slot role and the
## implemented spell adapter all live in data; no screen branches on a node id.

## The four trees.
##
## **Appended, never reordered.** A trained node is stored by id rather than by
## discipline, so this is not on disk - but every screen that lists the trees
## indexes into a parallel array of names, and reordering would rename three
## trees at once.
##
## Arcane was added on 2026-09-13: the owner asked for "a wizard spec more
## ranged caster type build", and the three trees were a melee bruiser, a melee
## paladin and a melee berserker. Focus, mana and five ranged spells all existed
## and nothing in the tree wanted them.
enum Discipline { BLOOD, HOLY, BERSERK, ARCANE }

## What each tree is called, in one place. Three screens kept their own copy of
## a three-entry array, which is three chances to add a fourth and remember
## twice.
const DISCIPLINE_NAMES: Array[String] = ["Blood", "Holy", "Berserk", "Arcane"]
enum Role { ATTACK, DEFENSE, POWER, PASSIVE, ULTIMATE, AUGMENT }

## What a node is in the tree. **Appended, never reordered**: data names these
## by number, and `Role` and `Trigger` have both shipped content pointing at the
## wrong member after an insertion.
##
## - SKILL: a cast, slotted by its `role` - Attack, Defense, Power or Ultimate.
## - FORM: a shape of the three-hit chain. One is chosen at a time, beside the
##   four slots rather than in one of them, so every slot can hold a cast.
## - PASSIVE: always on once learned.
## - UPGRADE: changes one skill (`parent_id`); those sharing an `exclusive`
##   group exclude each other.
## - OATH: the tip of an arm; one sworn at a time.
enum Kind { SKILL, FORM, PASSIVE, UPGRADE, OATH }

@export var discipline: Discipline = Discipline.BLOOD
@export var role: Role = Role.ATTACK
@export var kind: Kind = Kind.SKILL

## Which ring of its arm the node sits in, from the Warden outward: 1 to 3, and
## 4 for the tip. A ring opens when enough of its own arm is learned -
## `Balance.DISCIPLINE_RING_DEPTH` - **counted rather than graphed**: a count
## cannot author an unreachable node the way a hand-drawn graph can, and this
## project lost `call_wolf` to exactly that once.
@export_range(1, 4) var ring: int = 1

## The skill an upgrade changes, and the group of upgrades it excludes.
@export var parent_id: String = ""
@export var exclusive: String = ""

## What the node is about, for passives and synergies to name and for the map
## to show - so a passive never says "area" without saying where.
@export var tags: Array[String] = []

## Optional adapter to an existing fully implemented SpellData. Empty means the
## node modifies core combat or is a passive/upgrade rather than a cast.
@export var spell_id: String = ""

## A semantic effect key and bounded magnitude for core-combat consumers.
@export var effect_id: String = ""
@export var effect_value: float = 0.0

## A chain form's extra on every swing, as a share. Authored on the form rather
## than matched by effect id in `Hero.damage_multiplier`, which is where the
## three forms' 8%, 5% and 4% lived until 2026-09-26.
@export var form_damage: float = 0.0


## How many nodes of this node's own arm must be learned before it opens.
func depth_to_open() -> int:
	var table: Array[int] = Balance.DISCIPLINE_RING_DEPTH
	return table[clampi(ring - 1, 0, table.size() - 1)]


func is_form() -> bool:
	return kind == Kind.FORM


func get_sprite_path() -> String:
	return GameData.derive_path("icons/disciplines", "discipline_", id)


## Only a skill sits in a slot: a form is chosen beside them.
func is_active_slot() -> bool:
	return kind == Kind.SKILL and role in [Role.ATTACK, Role.DEFENSE, Role.POWER, Role.ULTIMATE]


func slot_index() -> int:
	if kind != Kind.SKILL:
		return -1
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
	match kind:
		Kind.FORM:
			return "Form"
		Kind.PASSIVE:
			return "Passive"
		Kind.UPGRADE:
			return "Upgrade"
		Kind.OATH:
			return "Oath"
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
	return DISCIPLINE_NAMES[clampi(int(discipline), 0, DISCIPLINE_NAMES.size() - 1)]


func is_slot_unlocked(act: int) -> bool:
	return slot_is_unlocked(slot_index(), act)


## **The act a slot opens in**, and the one rule for it.
##
## Attack and Defense are open from the first road; Power opens in Act II and
## Ultimate in Act III - which is to say **after the Act I boss and after the
## Act II boss**, since an act begins when its predecessor's boss falls.
##
## The Mansion carried its own copy of this as `slot < 2 or RunState.act >= slot`,
## which is the same rule written twice, and its label read *"unlocks after the
## Act 2 boss"* for a slot that opens after the Act *one* boss. The owner read
## the label and reported the slot as locked an act too long (2026-09-22). A
## slot names the boss that opens it through `slot_opens_after_boss` now, and
## there is one rule rather than two.
static func slot_is_unlocked(slot: int, act: int) -> bool:
	return act >= slot_opens_at_act(slot)


static func slot_opens_at_act(slot: int) -> int:
	return maxi(slot, 1)


## The act whose **boss** has to fall before this slot opens.
static func slot_opens_after_boss(slot: int) -> int:
	return maxi(slot_opens_at_act(slot) - 1, 0)
