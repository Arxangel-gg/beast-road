class_name TownCore
extends Node2D

## The thing being defended (GDD §3). Holds the town's health, which lives in
## RunState so the town scope and the HUD read the same number.
##
## Losing this ends the run.

const GROUP: StringName = &"town"

@export var health: Health
@export var sprite: Sprite2D
@export var occluder: Occluder

## Health fractions at which the town swaps to the next damage stage. The art is
## city_base -> city_damage_1 -> _2 -> _3, so the town visibly falls apart as it
## is worn down rather than only reporting it on a bar.
const STAGES: Array[Dictionary] = [
	{"above": 0.75, "texture": "res://art/city/city_base.png"},
	{"above": 0.50, "texture": "res://art/city/city_damage_1.png"},
	{"above": 0.25, "texture": "res://art/city/city_damage_2.png"},
	{"above": -1.0, "texture": "res://art/city/city_damage_3.png"},
]

var _flash_left: float = 0.0
var _ended: bool = false
var _stage: int = -1


func _ready() -> void:
	add_to_group(GROUP)
	health.max_hp = RunState.town_max_hp
	health.current_hp = RunState.town_hp
	health.damaged.connect(_on_damaged)
	health.changed.connect(_on_changed)
	health.died.connect(_on_died)
	_apply_stage(true)
	EventBus.town_health_changed.emit(health.current_hp, health.max_hp)


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	sprite.modulate = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE, 1.0 - _flash_left / Balance.HIT_FLASH_TIME)


func radius() -> float:
	return Balance.TOWN_RADIUS


## Swaps the sprite when health crosses a threshold, and only on a change.
##
## The Occluder measures its trigger area from the sprite's texture, so it is
## re-measured on every swap - otherwise a stage with different dimensions would
## keep fading using the previous stage's bounds. Y-sorting is unaffected: it
## reads the node position, not the texture.
func _apply_stage(force: bool = false) -> void:
	var ratio: float = health.ratio()
	var wanted: int = STAGES.size() - 1
	for i: int in STAGES.size():
		if ratio > float(STAGES[i]["above"]):
			wanted = i
			break
	if wanted == _stage and not force:
		return
	_stage = wanted

	var path: String = String(STAGES[wanted]["texture"])
	if not ResourceLoader.exists(path):
		return
	sprite.texture = load(path)
	if occluder != null:
		occluder.remeasure()

	if not force:
		# A stage change is a landmark: the town just visibly got worse.
		Vfx.ring(global_position, Balance.TOWN_RADIUS * 1.6,
			Color(0.9, 0.45, 0.25, 0.6), 0.6, 6.0)
		EventBus.camera_shake_requested.emit(14.0, 0.5)
		Sfx.play("sfx_town_damaged", 4.0)


func _on_damaged(amount: float, _from: Vector2) -> void:
	_flash_left = Balance.HIT_FLASH_TIME
	# Damage to the town slows the beast, which slows construction. That chain
	# is the whole reason failure compounds (GDD §7).
	RunState.beast_speed = maxf(
		RunState.beast_speed - amount * Balance.BEAST_SPEED_LOSS_PER_DAMAGE,
		Balance.BEAST_SPEED_FLOOR)
	EventBus.beast_speed_changed.emit(RunState.beast_speed)
	_apply_stage()
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
