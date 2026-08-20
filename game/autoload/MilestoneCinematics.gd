extends Node

## Queues first-view milestone cinematics off the existing run contract.
##
## No scope owns this presentation and no battlefield node knows it exists.
## Existing EventBus moments are enough, which keeps the cinematic slice out of
## Claude's concurrent HUD, loot, launcher and leaderboard work.

var _queue: Array[MilestoneCinematicData] = []
var _draining: bool = false

## Headless release gates normally skip presentation. A focused scene check can
## opt in without weakening that protection for the rest of the tooling suite.
var force_presentation_for_tests: bool = false


func _ready() -> void:
	EventBus.act_started.connect(_on_act_started)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)


func _on_act_started(_act: int, terrain_id: String) -> void:
	_enqueue_matches(MilestoneCinematicData.Trigger.ACT_STARTED, terrain_id)


func _on_boss_spawned(boss_id: String, _act: int) -> void:
	_enqueue_matches(MilestoneCinematicData.Trigger.BOSS_SPAWNED, boss_id)


func _on_boss_defeated(boss_id: String, _act: int) -> void:
	_enqueue_matches(MilestoneCinematicData.Trigger.BOSS_DEFEATED, boss_id)


func _enqueue_matches(trigger: MilestoneCinematicData.Trigger, trigger_id: String) -> void:
	if not _presentation_available():
		return
	for data: MilestoneCinematicData in ContentDB.milestone_cinematics_sorted():
		if not data.matches(trigger, trigger_id) or MetaState.milestone_cinematic_seen(data.id):
			continue
		if _queue.has(data):
			continue
		_queue.append(data)
	if not _queue.is_empty() and not _draining:
		# Let the signal that changed the act or spawned the boss finish first. The
		# overlay may pause the tree, but it must never pause half a state change.
		call_deferred("_drain")


func _presentation_available() -> bool:
	return force_presentation_for_tests or DisplayServer.get_name() != "headless"


func _drain() -> void:
	if _draining:
		return
	_draining = true
	while not _queue.is_empty():
		var data: MilestoneCinematicData = _queue.pop_front()
		if MetaState.milestone_cinematic_seen(data.id):
			continue
		var overlay := MilestoneCinematic.new()
		overlay.name = "MilestoneCinematic_%s" % data.id
		get_tree().root.add_child(overlay)
		await overlay.play(data)
		MetaState.mark_milestone_cinematic_seen(data.id)
		overlay.queue_free()
	_draining = false
