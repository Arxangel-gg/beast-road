class_name TownCore
extends Node2D

## The thing being defended (GDD §3). Holds the town's health, which lives in
## RunState so the town scope and the HUD read the same number.
##
## Losing this ends the run.

const GROUP: StringName = &"town"

@export var health: Health
@export var sprite: Sprite2D

var _flash_left: float = 0.0
var _ended: bool = false


func _ready() -> void:
	add_to_group(GROUP)
	health.max_hp = RunState.town_max_hp
	health.current_hp = RunState.town_hp
	health.damaged.connect(_on_damaged)
	health.changed.connect(_on_changed)
	health.died.connect(_on_died)
	EventBus.town_health_changed.emit(health.current_hp, health.max_hp)


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	sprite.modulate = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)


func radius() -> float:
	return Balance.TOWN_RADIUS


func _on_damaged(amount: float, _from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	# Damage to the town slows the beast, which slows construction. That chain
	# is the whole reason failure compounds (GDD §7).
	RunState.beast_speed = maxf(
		RunState.beast_speed - amount * Balance.BEAST_SPEED_LOSS_PER_DAMAGE,
		Balance.BEAST_SPEED_FLOOR)
	EventBus.beast_speed_changed.emit(RunState.beast_speed)
	EventBus.town_damaged.emit(amount, health.current_hp, health.max_hp)
	EventBus.camera_shake_requested.emit(6.0, 0.25)


func _on_changed(current: float, maximum: float) -> void:
	RunState.town_hp = current
	RunState.town_max_hp = maximum
	EventBus.town_health_changed.emit(current, maximum)


func _on_died(_from: Vector2) -> void:
	if _ended:
		return
	_ended = true
	GameDirector.end_run(false)
