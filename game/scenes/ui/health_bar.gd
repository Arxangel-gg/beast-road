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
## The pale trail behind the fill: a hit leaves it where the health was and
## it drains after, so a blow that takes one percent off a huge body is still
## a visible bite rather than a bar that reads as full (owner brief,
## 2026-09-12: "it always showed a full health bar despite being hit").
var _trail: ColorRect = null
var _trail_ratio: float = 1.0
var _ratio: float = 1.0
## Width against the ordinary bar; the ranked wear a wider one.
var _width_scale: float = 1.0


func _ready() -> void:
	# Above everything in the sorted layer, and absolute rather than relative so
	# it cannot inherit a parent's depth. A health bar is a readout, not scenery:
	# foliage standing in front of the hero was drawing over the hero's own bar,
	# which is correct y-sorting and completely wrong information.
	z_index = Balance.HEALTH_BAR_Z
	z_as_relative = false

	if fill != null:
		_trail = ColorRect.new()
		_trail.name = "Trail"
		_trail.color = Balance.HEALTH_BAR_TRAIL_COLOUR
		_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_trail)
		move_child(_trail, fill.get_index())
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
	var w: float = Balance.HEALTH_BAR_WIDTH * _width_scale
	var h: float = Balance.HEALTH_BAR_HEIGHT
	if background != null:
		background.position = Vector2(-w * 0.5, 0.0)
		background.size = Vector2(w, h)
	if fill != null:
		fill.position = Vector2(-w * 0.5, 0.0)
		fill.size = Vector2(w * _ratio, h)
	if _trail != null:
		_trail.position = Vector2(-w * 0.5, 0.0)
		_trail.size = Vector2(w * _trail_ratio, h)


## A wider bar, for a body worth reading: elites and bosses. Shown at once
## rather than on the first hit, so the rank is visible before it matters.
func set_ranked(scale_width: float) -> void:
	_width_scale = maxf(scale_width, 1.0)
	hide_until_damaged = false
	visible = true
	_apply_size()


func _on_changed(current: float, maximum: float) -> void:
	var ratio: float = clampf(current / maximum if maximum > 0.0 else 0.0, 0.0, 1.0)
	if ratio < _ratio:
		# A bite: the trail stays where the health was and drains after.
		_trail_ratio = maxf(_trail_ratio, _ratio)
		set_process(true)
	elif ratio > _trail_ratio:
		_trail_ratio = ratio
	_ratio = ratio
	_apply_size()
	if hide_until_damaged:
		visible = ratio < 1.0


func _process(delta: float) -> void:
	if _trail_ratio <= _ratio + 0.0005:
		_trail_ratio = _ratio
		_apply_size()
		set_process(false)
		return
	# A short hold, then a drain: the eye catches the pale bite before it goes.
	_trail_ratio = maxf(_trail_ratio - delta * Balance.HEALTH_BAR_TRAIL_RATE, _ratio)
	_apply_size()
