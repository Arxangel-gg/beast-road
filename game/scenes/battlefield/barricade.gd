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
var _bar: HealthBar = null
var _flash: float = 0.0

## Which way the road runs under it, so the right piece is drawn.
var facing: BarricadeData.Facing = BarricadeData.Facing.ACROSS


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
	_apply_facing()
	add_child(_sprite)
	ShadowKit.add_contact(self, _sprite, 0.8)
	z_index = int(global_position.y)

	# A wall with no visible health is a wall nobody can decide about: whether to
	# reinforce a lane or spend elsewhere is exactly the judgement the bar exists
	# to inform, and it was missing.
	_bar = (load("res://scenes/ui/health_bar.tscn") as PackedScene).instantiate()
	_bar.position = Vector2(0.0, -Balance.BARRICADE_BAR_LIFT)
	add_child(_bar)
	_bar.bind(health)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
		_apply_wear()


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


func _on_damaged(amount: float, from: Vector2) -> void:
	_flash = Balance.HIT_FLASH_TIME
	# Splinters, off the side it was struck from. A wall that only flashed read
	# as a health bar with a picture behind it rather than as something being
	# broken apart.
	Vfx.spark(global_position, data.colour, 5,
		(global_position - from).normalized(), 150.0)
	Vfx.number(global_position, amount, data.colour, false)
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
	_apply_wear()


## Turns the wall to match the road under it.
##
## Called by the battlefield when it raises one, because the *grid* is what knows
## which way the road runs - the barricade only knows the tile it was given.
## Turns the wall to match the road under it.
##
## The piece *and* a rotation, because the two do different jobs. The authored
## pieces carry the right silhouette for a wall seen face-on or edge-on; a corner
## needs an actual angle, and rotating is exact where asking a generator for "the
## same wall at 45 degrees" produced a third design rather than a third
## orientation. So the diagonal piece is turned, and mirrored to follow whether
## the bend runs north-east or north-west.
func set_facing(wanted: BarricadeData.Facing, mirrored: bool) -> void:
	facing = wanted
	if _sprite == null:
		return
	_sprite.flip_h = mirrored
	var lean: float = Balance.BARRICADE_DIAGONAL_DEGREES 		if wanted == BarricadeData.Facing.DIAGONAL else 0.0
	_sprite.rotation = deg_to_rad(-lean if mirrored else lean)
	_apply_facing()


func _apply_facing() -> void:
	if _sprite == null or data == null:
		return
	var path: String = data.sprite_path_for(facing)
	if not ResourceLoader.exists(path):
		# A barricade that ships only its main piece still stands everywhere,
		# turned the wrong way rather than invisible.
		path = data.get_sprite_path()
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	_apply_wear()


## Damage shown on the wall itself, not only on the bar.
##
## Darkened and settled rather than swapped for a broken sprite: three authored
## damage states per orientation per barricade is twelve images for something the
## player reads mostly from the bar, and a wall that sags and greys as it is worn
## down carries the same information at every zoom.
## One writer for the tint, composing both channels.
##
## The wear and the hit flash both want `modulate`, and two systems assigning one
## property is how the earlier tower sway-versus-wobble bug happened - the later
## write simply erases the earlier, so a wall would flash white and lose its wear,
## or wear and never flash. Summed here instead, in the one place that owns it.
func _apply_wear() -> void:
	if _sprite == null:
		return
	var wear: float = 1.0 - health_ratio()
	var worn: Color = Color.WHITE.lerp(Balance.BARRICADE_BROKEN_TINT, wear)
	var struck: float = _flash / Balance.HIT_FLASH_TIME if _flash > 0.0 else 0.0
	_sprite.modulate = worn.lerp(Balance.HIT_FLASH_COLOUR, struck)
	_sprite.scale.y = 1.0 - wear * Balance.BARRICADE_SAG


## How far out its own body reaches, so an enemy knows when it is in range.
func radius() -> float:
	if _sprite == null or _sprite.texture == null:
		return 40.0
	return _sprite.texture.get_size().x * 0.5 * absf(_sprite.scale.x)
