class_name TowerSlot
extends Node2D

## A build spot on a lane (GDD §3). Three per lane; the middle one is the
## combination slot and only unlocks once both of its neighbours are built.
##
## The slot owns no game state — RunState does. This node reads RunState and
## draws what it says, so a slot rebuilt from a save looks the same as one the
## player just filled.

const GROUP: StringName = &"tower_slots"

## The player clicked this spot; the HUD opens the build panel on it.
signal clicked(lane: int, slot: int)

## Size of the invisible click target over the marker.
const HIT_SIZE: float = 120.0

@export var marker: Sprite2D
@export var tower_root: Node2D

var lane: int = 0
var slot: int = 0

var _field: Battlefield = null
var _tower: Tower = null
var _hovered: bool = false


func setup(lane_index: int, slot_index: int, field: Battlefield) -> void:
	lane = lane_index
	slot = slot_index
	_field = field


func _ready() -> void:
	add_to_group(GROUP)
	var art: String = "res://art/battlefield/build_spot%s.png" % ("_combo" if is_combo_slot() else "")
	if ResourceLoader.exists(art):
		marker.texture = load(art)
	_make_hit_target()
	EventBus.tower_slot_changed.connect(_on_slot_changed)
	refresh()


## A flat Button rather than an Area2D: this is a UI affordance, and it should
## behave like one — hover states, focus, and clicks that the HUD consumes.
func _make_hit_target() -> void:
	var button := Button.new()
	button.flat = true
	button.size = Vector2(HIT_SIZE, HIT_SIZE)
	button.position = Vector2(-HIT_SIZE, -HIT_SIZE) * 0.5
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func() -> void: clicked.emit(lane, slot))
	button.mouse_entered.connect(func() -> void: set_hovered(true))
	button.mouse_exited.connect(func() -> void: set_hovered(false))
	add_child(button)


func is_combo_slot() -> bool:
	return slot == Balance.COMBO_SLOT_INDEX


func is_empty() -> bool:
	return _tower == null


func tower() -> Tower:
	return _tower


## What this slot can currently build, or null. For the combination slot that
## depends on what is standing either side of it.
func buildable_combination() -> TowerData:
	return RunState.available_combination(lane) if is_combo_slot() else null


## A combination slot with nothing to combine is not buildable at all.
func is_locked() -> bool:
	return is_combo_slot() and buildable_combination() == null


func set_hovered(value: bool) -> void:
	_hovered = value
	if _tower != null:
		_tower.show_range(value)
	_update_marker()


## Rebuilds the visual to match RunState.
func refresh() -> void:
	var wanted: TowerData = RunState.tower_in_slot(lane, slot)
	var wanted_level: int = RunState.level_in_slot(lane, slot)

	if wanted == null:
		if _tower != null:
			_tower.queue_free()
			_tower = null
		_update_marker()
		return

	if _tower != null and _tower.data == wanted:
		_tower.upgrade_to(wanted_level)
		_update_marker()
		return

	if _tower != null:
		_tower.queue_free()
		_tower = null

	var scene: PackedScene = _field.tower_scene
	var instance := scene.instantiate() as Tower
	if instance == null:
		return
	instance.setup(wanted, wanted_level, lane, slot, _field)
	tower_root.add_child(instance)
	_tower = instance
	_update_marker()


func _on_slot_changed(changed_lane: int, changed_slot: int) -> void:
	if changed_lane != lane:
		return
	# A neighbour changing can unlock or invalidate this slot's combination, so
	# the middle slot listens to the whole lane, not just to itself.
	if changed_slot == slot:
		refresh()
	elif is_combo_slot():
		_validate_combination()
	else:
		if _tower != null:
			_tower.refresh_modifiers()
		_update_marker()


## If the flanking towers changed so that the built combination is no longer
## the one they produce, the middle tower is refunded rather than silently left
## wrong.
func _validate_combination() -> void:
	if _tower == null:
		_update_marker()
		return
	var now: TowerData = buildable_combination()
	if now != null and now == _tower.data:
		_tower.refresh_modifiers()
		return
	var refund: int = int(round(float(_tower.data.build_cost()) * Balance.TOWER_SELL_REFUND))
	RunState.gain_resources(refund)
	RunState.clear_slot(lane, slot)


func _update_marker() -> void:
	if marker == null:
		return
	marker.visible = _tower == null
	var tint: Color = Color(1, 1, 1, 0.55)
	if is_locked():
		tint = Color(0.5, 0.5, 0.5, 0.25)
	elif _hovered:
		tint = Color(1, 1, 1, 0.95)
	marker.modulate = tint
