extends Node

## Production gate for the bounded objective layer.
##
## Uses only in-memory account state and restores it before exit. It never calls
## save_game(), so the developer's real save is not read back or overwritten.

func _ready() -> void:
	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	var ids: Dictionary = {}
	var orders: Dictionary = {}
	var content_ok: bool = objectives.size() == 8
	var total_reward: int = 0
	for objective: ChronicleObjectiveData in objectives:
		content_ok = content_ok and not objective.id.is_empty()
		content_ok = content_ok and not objective.display_name.is_empty()
		content_ok = content_ok and not objective.description.is_empty()
		content_ok = content_ok and objective.tool_reward > 0
		content_ok = content_ok and not ids.has(objective.id)
		content_ok = content_ok and not orders.has(objective.order)
		ids[objective.id] = true
		orders[objective.order] = true
		total_reward += objective.tool_reward
	print("[chronicle] content=%d unique=%s one-time Tools=%d" % [
		objectives.size(), str(content_ok), total_reward])

	var first_road: Dictionary = {
		"act": 1,
		"victory": false,
		"towers_built": 0,
		"tower_upgrades": 0,
		"chieftains": 0,
		"town_damage": 0.0,
		"wounds": 0,
	}
	var premature: int = 0
	for objective: ChronicleObjectiveData in objectives:
		if objective.is_met(first_road):
			premature += 1

	var full_clear: Dictionary = {
		"act": 3,
		"victory": true,
		"towers_built": 12,
		"tower_upgrades": 8,
		"chieftains": 1,
		"town_damage": 0.0,
		"wounds": 0,
	}

	var before_completed: Array[String] = MetaState.completed_objectives.duplicate()
	var before_tools: int = MetaState.tools
	MetaState.completed_objectives = []
	MetaState.tools = 0
	var earned: Array[String] = MetaState.complete_chronicle(full_clear)
	var after_first: int = MetaState.tools
	var repeated: Array[String] = MetaState.complete_chronicle(full_clear)
	var after_second: int = MetaState.tools
	var serialized: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	var saved_ids: Array = (serialized.get("chronicle", {}) as Dictionary).get(
		"completed", []) as Array
	var persistence_ok: bool = int(serialized.get("version", 0)) == MetaState.SAVE_VERSION \
		and saved_ids.size() == objectives.size()
	MetaState.completed_objectives = before_completed
	MetaState.tools = before_tools

	var one_time: bool = earned.size() == objectives.size() and repeated.is_empty() \
		and after_first == total_reward and after_second == after_first
	print("[chronicle] first-road completions=%d, full-clear=%d, repeat=%d" % [
		premature, earned.size(), repeated.size()])
	print("[chronicle] one-time=%s persistence=%s" % [str(one_time), str(persistence_ok)])

	if not content_ok or premature != 0 or not one_time or not persistence_ok:
		push_error("Chronicle objective gate failed")
		get_tree().quit(1)
		return
	for _frame: int in 5:
		await get_tree().process_frame
	get_tree().quit(0)
