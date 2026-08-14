class_name WarHorn
extends Node

## The war horn, the raid meter, and the weakened window (GDD §6).
##
## Blowing the horn is a decision with an immediate cost and a delayed one:
## distance stops now, and enemies are permanently stronger for the rest of the
## run. What you buy is a much faster raid meter — and when the meter fills,
## everything on the field is briefly weakened and a raid opens up.

var _horn_left: float = 0.0
var _weakened_left: float = 0.0


func _ready() -> void:
	EventBus.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	if _horn_left > 0.0:
		_horn_left -= delta
		if _horn_left <= 0.0:
			RunState.horn_active = false
			EventBus.war_horn_ended.emit()

	if _weakened_left > 0.0:
		_weakened_left -= delta
		RunState.weakened_until = _weakened_left
		if _weakened_left <= 0.0:
			RunState.weakened_until = 0.0
			EventBus.weakened_ended.emit()


func can_blow() -> bool:
	return RunState.phase == RunState.Phase.ROAD_BATTLE \
		and not RunState.horn_active and not RunState.horn_used_this_battle \
		and RunState.raid_charge < 1.0


func blow() -> bool:
	if not can_blow():
		return false
	RunState.horn_active = true
	RunState.horn_used_this_battle = true
	RunState.war_horn_uses += 1
	_horn_left = Balance.WAR_HORN_DURATION
	EventBus.war_horn_activated.emit(Balance.WAR_HORN_DURATION)
	return true


## True while the meter is full and the weakened window is open — the only time
## a raid may be entered.
func raid_available() -> bool:
	return RunState.raid_charge >= 1.0


func horn_time_left() -> float:
	return maxf(_horn_left, 0.0)


func weakened_time_left() -> float:
	return maxf(_weakened_left, 0.0)


## Spends the meter. Called when the player commits to a raid.
func consume_charge() -> void:
	RunState.raid_charge = 0.0
	_weakened_left = 0.0
	RunState.weakened_until = 0.0
	EventBus.raid_charge_changed.emit(0.0)


func _on_enemy_died(_id: String, _at: Vector2) -> void:
	if RunState.raid_charge >= 1.0:
		return
	var gain: float = Balance.RAID_CHARGE_PER_KILL * Modifiers.multiplier(Modifiers.RAID_CHARGE)
	var road: RoadData = RunState.active_road()
	if road != null:
		gain *= road.raid_charge_scale
	if RunState.horn_active:
		gain *= Balance.RAID_CHARGE_HORN_MULTIPLIER
	RunState.raid_charge = clampf(RunState.raid_charge + gain, 0.0, 1.0)
	EventBus.raid_charge_changed.emit(RunState.raid_charge)

	if RunState.raid_charge >= 1.0:
		_weakened_left = Balance.WEAKENED_DURATION
		RunState.weakened_until = _weakened_left
		EventBus.raid_available.emit(Balance.WEAKENED_DURATION)
