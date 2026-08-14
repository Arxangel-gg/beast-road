class_name TowerSlot
extends Node2D

## A build spot on a lane (GDD §3). Six per lane - an inner/middle/outer trio on
## each flank of the road - and each flank's middle spot is its combination slot,
## unlocked once both of its own neighbours are built.
##
## The slot owns no game state — RunState does. This node reads RunState and
## draws what it says, so a slot rebuilt from a save looks the same as one the
## player just filled.

const GROUP: StringName = &"tower_slots"

## The player clicked this spot; the HUD opens the build panel on it.
signal clicked(lane: int, slot: int)

## Size of the invisible click target over the marker.
##
## Sized to the marker rather than generously around it. A click target that
## reaches past the art it represents is a target that catches clicks meant for
## something else — here, enemies walking down the road beside it. See
## Balance.TOWER_SLOT_OFFSET for the full geometry.
const HIT_SIZE: float = 96.0

@export var marker: Sprite2D
@export var tower_root: Node2D

var lane: int = 0
var slot: int = 0

var _field: Battlefield = null
var _tower: Tower = null
var _hovered: bool = false
var _hit_button: Button = null


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


## How often the click target rechecks whether a fight has arrived on top of it.
## Every frame would be twelve slots against every living enemy; seven times a
## second is faster than a player can aim and swing.
const CLICK_GUARD_INTERVAL: float = 0.14

var _click_guard_left: float = 0.0


## Clicks belong to whoever the player is actually aiming at.
##
## Reported: "sometimes I'm trying to attack mobs on towers and end up clicking
## on the tower and opening its build menu". The swing itself was never lost -
## the hero polls the attack action, which a Button cannot swallow - but the
## build panel opened over the fight every time, which is worse than losing the
## click because now there is a panel in the way.
##
## So a build spot stops taking clicks while there is something to fight standing
## on it. During Preparation it always takes them: that is what it is for, and
## after the crossroad fix there is nothing alive on the field then anyway.
func _process(delta: float) -> void:
	_click_guard_left -= delta
	if _click_guard_left > 0.0:
		return
	_click_guard_left = CLICK_GUARD_INTERVAL
	if _hit_button == null:
		return
	_hit_button.mouse_filter = Control.MOUSE_FILTER_STOP if accepts_clicks() \
		else Control.MOUSE_FILTER_IGNORE
	if not accepts_clicks() and _hovered:
		set_hovered(false)


## Whether this spot is currently a button rather than a piece of battlefield.
func accepts_clicks() -> bool:
	if RunState.can_build_now():
		return true
	return not _enemy_is_close()


func _enemy_is_close() -> bool:
	var here: Vector2 = global_position
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		if enemy.global_position.distance_squared_to(here) \
				<= Balance.TOWER_CLICK_BLOCK_RADIUS * Balance.TOWER_CLICK_BLOCK_RADIUS:
			return true
	return false


## A flat Button rather than an Area2D: this is a UI affordance, and it should
## behave like one — hover states, focus, and clicks that the HUD consumes.
func _make_hit_target() -> void:
	var button := Button.new()
	_hit_button = button
	button.flat = true
	button.size = Vector2(HIT_SIZE, HIT_SIZE)
	button.position = Vector2(-HIT_SIZE, -HIT_SIZE) * 0.5
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(func() -> void: clicked.emit(lane, slot))
	button.mouse_entered.connect(func() -> void: set_hovered(true))
	button.mouse_exited.connect(func() -> void: set_hovered(false))
	add_child(button)


func is_combo_slot() -> bool:
	return Balance.slot_is_combo(slot)


func is_empty() -> bool:
	return _tower == null


func tower() -> Tower:
	return _tower


## What this slot can currently build, or null. For the combination slot that
## depends on what is standing either side of it.
func buildable_combination() -> TowerData:
	return RunState.available_combination(lane, slot) if is_combo_slot() else null


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
	# The tower fires shots but does not own them, so it needs the scene handed
	# down rather than loading a path of its own.
	instance.projectile_scene = _field.projectile_scene
	instance.setup(wanted, wanted_level, lane, slot, _field)
	tower_root.add_child(instance)
	_tower = instance
	_update_marker()


func _on_slot_changed(changed_lane: int, changed_slot: int) -> void:
	if changed_lane != lane:
		return
	# A neighbour changing can unlock or invalidate this slot's combination, so
	# the middle slot listens to its neighbours as well as to itself - but only
	# the ones on its own flank. The other side of the road runs its own trio and
	# its own fusion, and letting it invalidate this one would refund a tower for
	# something built across the path from it.
	if changed_slot == slot:
		refresh()
	elif is_combo_slot() and Balance.slot_side(changed_slot) == Balance.slot_side(slot):
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
	RunState.gain_currency(RunState.GOLD, refund)
	RunState.gain_currency(RunState.STONE,
		int(round(float(Balance.TOWER_COMBO_STONE_COST) * Balance.TOWER_STONE_SELL_REFUND)))
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
	if _hit_button != null:
		_hit_button.mouse_default_cursor_shape = Control.CURSOR_DRAG \
			if _tower == null and not is_locked() else Control.CURSOR_POINTING_HAND
