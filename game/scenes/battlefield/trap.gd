class_name Trap
extends Node2D

## A laid trap, waiting on a road tile.
##
## Reads its whole behaviour off `TrapData` (working rule 3). It arms, it waits,
## it fires at whatever walks over it, and after a set number of triggers it is
## gone — see the resource's header for why being *consumed* is the point rather
## than a limitation.
##
## **A guest's traps decide nothing**, exactly like a guest's towers. The host
## resolves the trigger and says so; a puppet draws the burst and nothing else.
## Without that, two machines would each spend the same trap's triggers against
## their own copies of the enemies and disagree about when it ran out.

const GROUP: StringName = &"traps"

var data: TrapData = null
var tile: Vector2i = Vector2i.ZERO
var field: Node = null

## True when the host decides this trap's triggers and this machine only draws
## them. Set by `CoopWorld` on a guest.
var puppet: bool = false

var _left: int = 0
var _arming: float = 0.0
var _sprite: Sprite2D = null
var _pulse: float = 0.0


func setup(trap_data: TrapData, at: Vector2i, arena: Node) -> void:
	data = trap_data
	tile = at
	field = arena


func _ready() -> void:
	if data == null:
		queue_free()
		return
	add_to_group(GROUP)
	_left = data.triggers
	_arming = data.arm_seconds
	_sprite = Sprite2D.new()
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	add_child(_sprite)
	# Under everything that walks, and *relative* so the entity root's y-sorting
	# still places it against the ground rather than lifting it out of the scene.
	# Absolute z put every trap in the game at one depth, in front of things that
	# were standing closer to the camera than it was.
	z_as_relative = true
	z_index = -2
	y_sort_enabled = false


func _physics_process(delta: float) -> void:
	if data == null:
		return
	if _arming > 0.0:
		_arming = maxf(_arming - delta, 0.0)
		# A slow pulse while arming, so "not yet" is visible rather than implied.
		_pulse += delta * 6.0
		if _sprite != null:
			_sprite.modulate.a = 0.45 + 0.25 * sin(_pulse)
		if _arming <= 0.0 and _sprite != null:
			_sprite.modulate.a = 1.0
		return
	# A puppet waits to be told. Deciding locally would have two machines
	# spending the same trap's triggers against their own copies of the enemies.
	if puppet or field == null or not field.has_method("enemies_near"):
		return
	for enemy: Enemy in field.enemies_near(global_position, data.radius):
		if not enemy.is_dying():
			fire()
			return


## Sets the trap off. Public because the host tells a guest's copy to draw it.
func fire() -> void:
	if data == null or _left <= 0:
		return
	_left -= 1
	if not puppet:
		_bite()
	Vfx.ring(global_position, data.radius, Color(data.colour, 0.7), 0.35, 4.0)
	Vfx.spark(global_position, data.colour, 10, Vector2.UP, 220.0)
	EventBus.trap_triggered.emit(tile, data.id, _left)
	if _left <= 0:
		# Spent. Cleared through RunState rather than freed here, so the guest is
		# told and the two machines agree about what is still on the field.
		if not puppet:
			RunState.clear_trap(tile)
		else:
			queue_free()


## Everything the trap does to what stepped on it.
##
## Not scaled by hero damage, deliberately: a trap is the town's, not the hero's,
## and letting a hero build scale it would make traps a hero item that happens to
## sit on the ground.
func _bite() -> void:
	if field == null or not field.has_method("enemies_near"):
		return
	for enemy: Enemy in field.enemies_near(global_position, data.radius):
		if enemy.is_dying():
			continue
		if data.damage > 0.0:
			enemy.take_damage(data.damage, global_position, data.knockback, false)
		if data.slow_factor < 1.0:
			enemy.apply_slow(data.slow_factor, data.slow_duration)
		if data.burn_dps > 0.0:
			enemy.apply_burn(data.burn_dps, data.burn_duration)


## How many triggers are left, for the HUD and the gate.
func triggers_left() -> int:
	return _left


## Restores a trap's remaining triggers when its node is rebuilt from RunState.
func set_triggers_left(value: int) -> void:
	_left = maxi(value, 0)
