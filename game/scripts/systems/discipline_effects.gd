class_name DisciplineEffects
extends RefCounted

## Which discipline `effect_id`s the game actually reads, and what they are worth.
##
## **Why this file exists.** On 2026-09-09 a sweep of all thirty discipline nodes
## found that `.effect_id` was read in exactly three places in the whole codebase:
## `hero.gd` matched three attack keys for a damage multiplier, `enemy.gd` matched
## one for a bleed, and `Modifiers` read the field off *relics* only — disciplines
## never reach it. Twenty-one of the twenty-four authored effects were inert, and
## ten nodes had no `spell_id` either, so training them did nothing whatsoever.
##
## A third of the skill tree was placebo. Every one of those nodes still costs a
## skill point and its Food, still draws an icon, and still shows the player a
## sentence describing what it does: "Critical chance rises against isolated
## enemies", "Perfect dodges near the Town Hall grant Command". The descriptions
## are specifications that were never wired up, not vague intentions — each
## carries an authored `effect_value` as well.
##
## It is the same failure `item_check` was written for, in a system nobody had
## pointed that lesson at: *an effect nothing reads would be taken, drawn, and do
## nothing.*
##
## **How this stops it recurring.** Every authored `effect_id` must appear in
## exactly one of the two lists below, and `discipline_check` fails if one appears
## in neither or in both. A new node cannot quietly join the inert pile, because
## adding its key to `DECLARED_ONLY` is a deliberate act that shows up in review.
## Moving a key from `DECLARED_ONLY` to `IMPLEMENTED` is what shipping the effect
## looks like.
##
## The debt is listed rather than made a failure, because a gate that is red for a
## week is a gate people stop reading — and twenty-one of these cannot be written
## in one change.

## Effects with a live consumer. Adding a key here without a consumer is the
## exact lie this file exists to prevent, and `discipline_check` cannot detect
## it — it can only check that the two lists cover the data. Do not add a key
## until something reads it.
const IMPLEMENTED: Array[String] = [
	"bleed_finisher",
	"drain_command",
	"heavy_reverse_pull",
	"tempest_heal_cap",
	"tower_damage_brand",
	"crowd_finisher_force",
	"defense_radiant_finisher",
	"town_dodge_command",
	"active_attack_speed",
	"support_kill_speed",
	"revive_knockback",
	# The seven spell riders, wired 2026-09-11. Each rides a spell that already
	# worked and adds the extra its card promised; `SpellCaster._rider` is where.
	"armor_stagger",
	"dash_shield_field",
	"lane_cleanse",
	"marked_dash_refund",
	"recoverable_wound",
	"road_line_disrupt",
	"selected_road_shockwave",
]

## Authored, described to the player, and not yet read by anything.
##
## Each of these has a sentence in its `.tres` that promises a behaviour, and an
## `effect_value` sized for it. They are not design questions — they are unwritten
## implementations. Shortening this list is the work.
const DECLARED_ONLY: Array[String] = [
	"block_finisher",
	"consume_marks_burst",
	"elite_extend_ultimate",
	"isolated_crit",
	"repair_blocker_shields",
	"tower_haste",
]


## The authored magnitude for an effect the hero has *trained*, or 0.
##
## Trained rather than equipped: a passive is not slotted, so an effect that only
## counted equipped nodes would leave every PASSIVE and AUGMENT node inert for a
## second time, which is the whole bug this file is about.
static func trained_value(effect_id: String) -> float:
	if effect_id.is_empty():
		return 0.0
	for id: String in RunState.trained_discipline_nodes:
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if node != null and node.effect_id == effect_id:
			return node.effect_value
	return 0.0


## Whether the hero has trained a node carrying this effect.
static func trained(effect_id: String) -> bool:
	if effect_id.is_empty():
		return false
	for id: String in RunState.trained_discipline_nodes:
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if node != null and node.effect_id == effect_id:
			return true
	return false
