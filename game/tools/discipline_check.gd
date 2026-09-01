extends Node

var _failures: PackedStringArray = []


func _ready() -> void:
	# **Held for the whole run.** This gate edits MetaState in place - a wiped
	# stash, a drained Tools purse, a reset flag - and any save reached while
	# that scratch state is live overwrites a real player's file. One did, on
	# 2026-08-31, and a stash is the one thing here that cannot be restored.
	MetaState.hold_saves()
	RunState.reset()
	# 24 authored nodes, plus one summon per discipline from 2026-08-25 and a
	# second from 2026-09-01: 30.
	#
	# **A tripwire against loss, not a ceiling.** The count is asserted rather
	# than derived on purpose - a node that vanishes from the data is a hero
	# power silently disappearing, and nothing else in the project would notice.
	# Raising it when nodes are deliberately added is the intended maintenance;
	# what must never happen is it being *lowered* to match a roster that got
	# smaller by accident.
	_check(ContentDB.discipline_nodes.size() == 30,
		"expected 30 authored discipline nodes, got %d" % ContentDB.discipline_nodes.size())
	_check(RunState.trained_discipline_nodes.size() == 2,
		"a run must begin with the curated Attack and Defense pair")
	_check(RunState.discipline_node_in_slot(0) != null \
			and RunState.discipline_node_in_slot(1) != null,
		"starter Attack and Defense must occupy their role slots")
	_check(RunState.discipline_node_in_slot(2) == null \
			and RunState.discipline_node_in_slot(3) == null,
		"Power and Ultimate must begin empty")

	RunState.building_tiers["sanctum"] = 3
	RunState.refresh_discipline_offers()
	_check(RunState.discipline_offers.size() == 3,
		"a built Mansion must offer exactly three unique nodes")
	var seen: Dictionary = {}
	for id: String in RunState.discipline_offers:
		seen[id] = true
	_check(seen.size() == RunState.discipline_offers.size(),
		"Mansion offers must not contain duplicates")

	_test_every_node_can_be_offered()

	var power: DisciplineNodeData = ContentDB.discipline_node("marrow_drain")
	RunState.trained_discipline_nodes.append(power.id)
	_check(not RunState.try_equip_discipline(power.id).is_empty(),
		"Power must remain locked during Act I")
	RunState.act = 2
	_check(RunState.try_equip_discipline(power.id).is_empty() \
			and RunState.discipline_node_in_slot(2) == power,
		"Power must equip after the Act I gate")

	RunState.gain_currency(RunState.FOOD, 999)
	var first_cost: int = RunState.discipline_respec_cost()
	_check(RunState.try_respec_disciplines().is_empty(),
		"Preparation respec must succeed when Food is available")
	_check(RunState.discipline_respec_cost() > first_cost,
		"respec Food cost must rise per use")
	_check(RunState.trained_discipline_nodes.size() == 2,
		"respec must return to the curated starter pair")

	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		_check(ResourceLoader.exists(node.get_sprite_path()),
			"missing discipline icon: %s" % node.get_sprite_path())

	if _failures.is_empty():
		print("[discipline] PASS — %d nodes, role gates, offers, respec and icons"
			% ContentDB.discipline_nodes.size())
	else:
		for failure: String in _failures:
			push_error("[discipline] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


## Every authored node has to be reachable through the offer rotation.
##
## The tree is a *choice*: 27 nodes and a maxed hero trains eleven, drawn three
## at a time from a deterministic per-road shuffle. That is a good shape, and it
## has one silent failure - a node that the rotation never surfaces is content
## nobody can take, and it looks exactly like a node nobody happened to pick.
## Nothing else in the project would notice: the count assertion above sees it in
## the data, the icon assertion below sees its art, and the offer assertion sees
## three ids without caring which.
##
## Swept over roads rather than reasoned about, because the ordering is a hash
## and hashes do not answer arguments.
func _test_every_node_can_be_offered() -> void:
	var before_seed: int = RunState.run_seed
	var before_segment: int = RunState.segment
	var before_wave: int = RunState.wave_number
	var before_act: int = RunState.act
	var before_trained: Array[String] = RunState.trained_discipline_nodes.duplicate()

	# The Mansion at its ceiling, so tier is not what is excluding anything -
	# that is the assertion below, and mixing the two would hide it.
	RunState.building_tiers["sanctum"] = 3
	RunState.trained_discipline_nodes = []

	var offered: Dictionary = {}
	for seed_index: int in 40:
		RunState.run_seed = 1000 + seed_index * 7919
		for segment: int in 12:
			RunState.segment = segment
			RunState.wave_number = segment * 3
			RunState.act = 1 + (segment % 3)
			RunState.refresh_discipline_offers()
			for id: String in RunState.discipline_offers:
				offered[id] = true

	var missing: PackedStringArray = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if not offered.has(node.id):
			missing.append(node.id)
	_check(missing.is_empty(),
		"never offered across 480 roads, so nobody can train them: %s"
			% ", ".join(missing))
	print("[discipline] %d of %d nodes reachable through the rotation"
		% [offered.size(), ContentDB.discipline_nodes.size()])

	# A tree the player can finish is a checklist, not a build.
	RunState.hero_level = Balance.HERO_MAX_LEVEL
	_check(RunState.discipline_cap() < ContentDB.discipline_nodes.size(),
		"a maxed hero may train %d of %d nodes - at parity the tree stops being a choice"
			% [RunState.discipline_cap(), ContentDB.discipline_nodes.size()])

	RunState.run_seed = before_seed
	RunState.segment = before_segment
	RunState.wave_number = before_wave
	RunState.act = before_act
	RunState.trained_discipline_nodes = before_trained
	RunState.refresh_discipline_offers()
