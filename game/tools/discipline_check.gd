extends Node

var _failures: PackedStringArray = []


func _ready() -> void:
	RunState.reset()
	# 27 since the three companion summons joined the roster on 2026-08-25. The
	# count is asserted rather than derived on purpose: a node that vanishes from
	# the data is a hero power silently disappearing, which nothing else notices.
	_check(ContentDB.discipline_nodes.size() == 27,
		"expected 27 authored discipline nodes, got %d" % ContentDB.discipline_nodes.size())
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
		print("[discipline] PASS — 27 nodes, role gates, offers, respec and icons")
	else:
		for failure: String in _failures:
			push_error("[discipline] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)
