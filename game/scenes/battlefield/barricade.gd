class_name Barricade
extends Node2D

## A raised barricade, standing across one road tile until something breaks it.
##
## It carries a `Health` child, which is the entire trick: enemy targeting is
## already field-mediated and enemy striking already looks up `Health.of(target)`
## without caring what it found. So a barricade needs no new code in `Enemy` at
## all — it needs the field to be willing to offer it as a target.
##
## See `BarricadeData` for why it is a thing to break rather than a thing to walk
## around: there is no pathfinder in this game, and a wall that rerouted would
## mean writing one.
##
## **A guest's barricades decide nothing.** Health arrives from the host as a
## fraction, exactly as an enemy's does. Two machines each running the same wall
## down against their own copies of the enemies would disagree about when it
## fell, and a wall that is standing on one screen and gone on the other is worse
## than no wall.

const GROUP: StringName = &"barricades"

var data: BarricadeData = null
var tile: Vector2i = Vector2i.ZERO
var lane: int = 0
var field: Node = null

## True when the host decides this barricade's health and this machine draws it.
var puppet: bool = false

var health: Health = null
var _sprite: Sprite2D = null
var _flash: float = 0.0


func setup(barricade: BarricadeData, at: Vector2i, in_lane: int, arena: Node) -> void:
	data = barricade
	tile = at
	lane = in_lane
	field = arena


func _ready() -> void:
	if data == null:
		queue_free()
		return
	add_to_group(GROUP)
	health = Health.new()
	health.name = "Health"
	health.max_hp = data.max_hp
	health.current_hp = data.max_hp
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)

	_sprite = Sprite2D.new()
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	add_child(_sprite)
	ShadowKit.add_contact(self, _sprite, 0.8)
	z_index = int(global_position.y)


func _process(delta: float) -> void:
	if _flash <= 0.0 or _sprite == null:
		return
	_flash = maxf(_flash - delta, 0.0)
	_sprite.modulate = Balance.HIT_FLASH_COLOUR.lerp(Color.WHITE,
		1.0 - _flash / Balance.HIT_FLASH_TIME)


func _physics_process(_delta: float) -> void:
	if data == null or data.slow_factor >= 1.0 or field == null:
		return
	if not field.has_method("enemies_near"):
		return
	# Anything pressed against it is held there. A wall that only had health
	# would be a speed bump with extra steps; slowing what is hitting it is what
	# makes a *partial* line worth building, because the gap is then faster than
	# the wall and the wall shapes where they go.
	for enemy: Enemy in field.enemies_near(global_position, Balance.BARRICADE_GRIP_RADIUS):
		enemy.apply_slow(data.slow_factor, Balance.BARRICADE_GRIP_SECONDS)


func _on_damaged(_amount: float, _from: Vector2) -> void:
	_flash = Balance.HIT_FLASH_TIME
	if puppet:
		return
	RunState.set_barricade(tile, data.id, health_ratio())


func _on_died(at: Vector2) -> void:
	Vfx.dust(at, data.colour, 12, 70.0)
	EventBus.camera_shake_requested.emit(4.0, 0.2)
	if puppet:
		queue_free()
		return
	# Cleared through RunState rather than freed here, so the guest is told and
	# the two machines agree about what is still standing.
	RunState.clear_barricade(tile)


func health_ratio() -> float:
	if health == null or health.max_hp <= 0.0:
		return 0.0
	return health.current_hp / health.max_hp


## Restores health when the node is rebuilt from RunState, or mirrored.
func set_health_ratio(ratio: float) -> void:
	if health == null or health.max_hp <= 0.0:
		return
	health.current_hp = clampf(ratio, 0.0, 1.0) * health.max_hp
	health.changed.emit(health.current_hp, health.max_hp)


## How far out its own body reaches, so an enemy knows when it is in range.
func radius() -> float:
	if _sprite == null or _sprite.texture == null:
		return 40.0
	return _sprite.texture.get_size().x * 0.5 * absf(_sprite.scale.x)
