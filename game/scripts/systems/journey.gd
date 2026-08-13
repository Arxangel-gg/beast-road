class_name Journey
extends Node

## The beast's walk (GDD §7, §8): distance, resources earned by walking,
## construction progress, crossroads, acts and the win condition.
##
## Distance is the clock the whole run runs on. Construction is gated on it,
## resources come from it, and the war horn stops it — so this node must be
## suspended along with the battlefield rather than ticking through a raid.

var _running: bool = false
var _crossroad_pending: bool = false

## Fractional resource yield carried between frames rather than truncated away.
var _resource_remainder: float = 0.0

## Which 300-unit segment the beast is standing in. A crossroad fires when this
## increments. Checking "distance to the next boundary <= 0" cannot work: the
## moment the boundary is crossed the remaining distance rolls over to a full
## segment, so the zero is never observed.
var _segment_index: int = 0
var _announced_act: int = 0


func start() -> void:
	_running = true
	_segment_index = _segment_for(RunState.distance_travelled)
	if _announced_act != RunState.act:
		_announced_act = RunState.act
		EventBus.act_started.emit(RunState.act, RunState.terrain_id)


func stop() -> void:
	_running = false


func _process(delta: float) -> void:
	if not _running or _crossroad_pending:
		return

	# The horn plants the beast's feet: no distance, so no resources and no
	# construction. That is the horn's immediate, legible cost (GDD §6.1).
	if RunState.horn_active:
		return

	var walked: float = RunState.beast_speed * delta
	if walked <= 0.0:
		return

	RunState.distance_travelled += walked
	_accrue_resources(walked)
	_advance_construction(walked)
	_recover_beast_speed(delta)

	EventBus.distance_changed.emit(RunState.distance_travelled, RunState.distance_to_crossroad())

	var segment_now: int = _segment_for(RunState.distance_travelled)
	if segment_now > _segment_index:
		_segment_index = segment_now
		# Every third segment closes an act, and an act closes with a boss
		# rather than a fork in the road. The run is won by killing the Act 3
		# boss, never by the distance bar filling on its own.
		if _segment_index % Balance.SEGMENTS_PER_ACT == 0:
			_await_boss()
		else:
			_reach_crossroad()


func _accrue_resources(walked: float) -> void:
	var earned: float = walked * RunState.resource_rate()
	# Fractional yield is accumulated rather than truncated away each frame.
	_resource_remainder += earned
	var whole: int = int(floor(_resource_remainder))
	if whole > 0:
		_resource_remainder -= float(whole)
		RunState.gain_resources(whole)



func _advance_construction(walked: float) -> void:
	if RunState.construction.is_empty():
		return
	var done: float = float(RunState.construction.get("distance_done", 0.0)) + walked
	var needed: float = float(RunState.construction.get("distance_needed", 1.0))
	var id: String = String(RunState.construction.get("id", ""))
	var tier: int = int(RunState.construction.get("tier", 1))

	if done < needed:
		RunState.construction["distance_done"] = done
		EventBus.construction_progress.emit(id, clampf(done / needed, 0.0, 1.0))
		return

	RunState.building_tiers[id] = tier
	RunState.construction.clear()
	EventBus.construction_completed.emit(id, tier)

	# The Town Hall changes how many relics may be socketed, so the town has to
	# be told rather than inferring it next time it is opened.
	if id == "town_hall":
		EventBus.relic_socketed.emit("")


## A clean stretch lets the beast recover, so one bad wave is not permanent.
func _recover_beast_speed(delta: float) -> void:
	if RunState.beast_speed >= Balance.BEAST_BASE_SPEED:
		return
	RunState.beast_speed = minf(
		RunState.beast_speed + Balance.BEAST_SPEED_RECOVERY_PER_SEC * delta,
		Balance.BEAST_BASE_SPEED)
	EventBus.beast_speed_changed.emit(RunState.beast_speed)


static func _segment_for(distance: float) -> int:
	return int(floor(distance / Balance.SEGMENT_DISTANCE))


func _reach_crossroad() -> void:
	_crossroad_pending = true
	RunState.segment += 1

	var segments_done: int = _segment_index
	var new_act: int = clampi(int(floor(RunState.distance_travelled / Balance.ACT_DISTANCE)) + 1, 1, Balance.ACT_COUNT)
	if new_act != RunState.act:
		RunState.act = new_act
		var terrain: TerrainData = ContentDB.terrain_for_act(new_act)
		if terrain != null:
			RunState.terrain_id = terrain.id
		_announced_act = RunState.act
		EventBus.act_started.emit(RunState.act, RunState.terrain_id)

	EventBus.crossroad_reached.emit(segments_done)


## Holds the walk until the act's boss is dead. The beast does not leave a
## region with that still standing in it.
func _await_boss() -> void:
	_crossroad_pending = true
	EventBus.act_boss_due.emit(RunState.act)


## Called by the boss director once the act boss falls.
func resume_after_boss() -> void:
	_crossroad_pending = false
	_segment_index = _segment_for(RunState.distance_travelled)
	RunState.segment += 1

	var next_act: int = RunState.act + 1
	if next_act > Balance.ACT_COUNT:
		return
	RunState.act = next_act
	var terrain: TerrainData = ContentDB.terrain_for_act(next_act)
	if terrain != null:
		RunState.terrain_id = terrain.id
	_announced_act = RunState.act
	EventBus.act_started.emit(RunState.act, RunState.terrain_id)


## Called by the crossroad UI once the player has chosen a road.
func resolve_crossroad(option_id: String) -> void:
	_crossroad_pending = false
	_segment_index = _segment_for(RunState.distance_travelled)
	EventBus.crossroad_resolved.emit(option_id)


func is_at_crossroad() -> bool:
	return _crossroad_pending
