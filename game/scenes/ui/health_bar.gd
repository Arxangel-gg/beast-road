class_name HealthBar
extends Node2D

## A health bar that rides above a unit in world space.
##
## Stage 1 has no HUD by design, but "does swinging feel good" is unanswerable
## if you cannot see whether a swing landed. This is the smallest thing that
## makes damage legible, and it stays attached to the unit rather than becoming
## screen furniture.

@export var background: ColorRect
@export var fill: ColorRect

## Enemies only show a bar once they have been hurt; the hero always shows one.
@export var hide_until_damaged: bool = true

var _bound: Health = null


func _ready() -> void:
	# Above everything in the sorted layer, and absolute rather than relative so
	# it cannot inherit a parent's depth. A health bar is a readout, not scenery:
	# foliage standing in front of the hero was drawing over the hero's own bar,
	# which is correct y-sorting and completely wrong information.
	z_index = Balance.HEALTH_BAR_Z
	z_as_relative = false

	_apply_size()
	visible = not hide_until_damaged


func bind(health: Health) -> void:
	if _bound != null and _bound.changed.is_connected(_on_changed):
		_bound.changed.disconnect(_on_changed)
	_bound = health
	if _bound == null:
		return
	_bound.changed.connect(_on_changed)
	_on_changed(_bound.current_hp, _bound.max_hp)


func _apply_size() -> void:
	var w: float = Balance.HEALTH_BAR_WIDTH
	var h: float = Balance.HEALTH_BAR_HEIGHT
	if background != null:
		background.position = Vector2(-w * 0.5, 0.0)
		background.size = Vector2(w, h)
	if fill != null:
		fill.position = Vector2(-w * 0.5, 0.0)
		fill.size = Vector2(w, h)


func _on_changed(current: float, maximum: float) -> void:
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	if fill != null:
		fill.size = Vector2(Balance.HEALTH_BAR_WIDTH * clampf(ratio, 0.0, 1.0), Balance.HEALTH_BAR_HEIGHT)
	if hide_until_damaged:
		visible = ratio < 1.0
