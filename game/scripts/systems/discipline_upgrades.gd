class_name DisciplineUpgrades
extends RefCounted
## What a Warden's learned branches do to one skill, read in one place.
##
## A skill is three nodes (docs/SKILL_TREE_D4_2026-09-28.md): the skill, an
## enhancement hanging off it, and one of two forks hanging off the
## enhancement. Each branch carries an `effect_id` from a small vocabulary -
## `up_power`, `up_cooldown`, `up_reach`, `form_finisher_heal` and the rest -
## and a value, and **belongs to the skill at the root of its `parent_id`
## chain**. So a caster asks "what does Ember Fall have", never "which nodes are
## learned", and the answer is a dictionary of key to summed value.
##
## Static and over a plain `learned` map (id to rank), because the host asks it
## of a partner's sheet exactly as the hero asks it of the account, and two
## readers of one rule would drift. `WardenSheet.upgrade_of` is the door both
## sides use; null is this machine's own Warden.
##
## **The bound**: a branch moves a number the skill already has, and
## `Balance.DISCIPLINE_UPGRADE_CEILING` is the most any one key may move it,
## whatever the data authors. Counted keys (`up_extra`) are whole things and
## are not shares, so the ceiling is not applied to them.

## The keys that are not shares - a count, or seconds - and so are not held to
## the share ceiling.
const COUNTED: Array[String] = ["up_extra", "up_kill_cooldown", "up_status_wet",
	"form_brand_seconds", "form_finisher_dash_refund",
	# Break the Host is a fork of Beast's Breath now and its number was always
	# seconds - the moment an elite's fall buys a channel, up to the card's own
	# hard cap - read by `DisciplineEffects` rather than by a branch reader.
	"elite_extend_ultimate"]


## The root of a branch: the skill or form its `parent_id` chain ends at, or
## "" for a node that is not a branch.
static func root_of(node: DisciplineNodeData) -> String:
	if node == null or node.kind != DisciplineNodeData.Kind.UPGRADE:
		return ""
	var at: DisciplineNodeData = node
	var steps: int = 0
	while at != null and at.kind == DisciplineNodeData.Kind.UPGRADE and steps < 8:
		at = ContentDB.discipline_node(at.parent_id)
		steps += 1
	return at.id if at != null and at.kind != DisciplineNodeData.Kind.UPGRADE else ""


## Every branch value a skill or form holds, keyed by `effect_id`.
static func for_skill(learned: Dictionary, skill_id: String) -> Dictionary:
	var out: Dictionary = {}
	if skill_id.is_empty():
		return out
	for key: Variant in learned:
		var node: DisciplineNodeData = ContentDB.discipline_node(String(key))
		if node == null or node.kind != DisciplineNodeData.Kind.UPGRADE:
			continue
		if root_of(node) != skill_id or node.effect_id.is_empty():
			continue
		var rank: int = maxi(int(learned[key]), 1)
		out[node.effect_id] = float(out.get(node.effect_id, 0.0)) + node.effect_value * float(rank)
	return out


## One branch value, bounded. `skill_id` is the skill's or form's node id.
static func value(learned: Dictionary, skill_id: String, key: String) -> float:
	var raw: float = float(for_skill(learned, skill_id).get(key, 0.0))
	if COUNTED.has(key):
		return raw
	return minf(raw, Balance.DISCIPLINE_UPGRADE_CEILING)


## The branch value for whichever learned skill casts this spell. A spell can be
## cast by more than one node in principle; the branches of every learned node
## that casts it are summed, because the Warden bought every one of them.
static func for_spell(learned: Dictionary, spell_id: String, key: String) -> float:
	if spell_id.is_empty():
		return 0.0
	var total: float = 0.0
	for id: Variant in learned:
		var node: DisciplineNodeData = ContentDB.discipline_node(String(id))
		if node != null and node.kind == DisciplineNodeData.Kind.SKILL and node.spell_id == spell_id:
			total += float(for_skill(learned, node.id).get(key, 0.0))
	if COUNTED.has(key):
		return total
	return minf(total, Balance.DISCIPLINE_UPGRADE_CEILING)


## Every sworn Oath, in the tree's order. One for most Wardens; a Gatebroken
## Warden may hold two (`MetaState.oaths_allowed`), and the door and the
## settling hold the count - this only reads what is held.
static func oaths_of(learned: Dictionary) -> Array[DisciplineNodeData]:
	var out: Array[DisciplineNodeData] = []
	for node: DisciplineNodeData in ContentDB.discipline_oaths_sorted():
		if learned.has(node.id):
			out.append(node)
	return out


## The first sworn Oath, or null.
static func oath_of(learned: Dictionary) -> DisciplineNodeData:
	var sworn: Array[DisciplineNodeData] = oaths_of(learned)
	return sworn[0] if not sworn.is_empty() else null


## The sworn Oaths' boon, by key, summed, or 0.
static func boon(learned: Dictionary, key: String) -> float:
	var total: float = 0.0
	for oath: DisciplineNodeData in oaths_of(learned):
		if oath.effect_id == key:
			total += oath.effect_value
	return total


## The sworn Oaths' bane, by key, summed, or 0.
static func bane(learned: Dictionary, key: String) -> float:
	var total: float = 0.0
	for oath: DisciplineNodeData in oaths_of(learned):
		if oath.bane_id == key:
			total += oath.bane_value
	return total
