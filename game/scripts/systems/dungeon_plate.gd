class_name DungeonPlate
extends Node2D

## A pressure plate in the corridors of a rift (owner item 29, 2026-10-06:
## "traps, interactables"). Anything that stands on it - the hero or a body -
## fires a telegraphed circle on the plate, and it rearms a few seconds later.
##
## **The blow is the mortar's blow.** A plate stands up an `EnemyGroundStrike`,
## the same node every ranged breed's ground blow is thrown through, so the
## tell is drawn at the radius the blow will use, the riser swells toward it,
## the debrief names it, and the blow reaches the players through
## `strike_the_players` and the bodies through the one field they stand in. A
## plate is a hazard a player reads and can bait a column across; nothing in
## `curve_report` carries it, because the curve models no arena.
##
## **Shares, never numbers.** It takes `DUNGEON_PLATE_DAMAGE` of the hero's
## own pool and `DUNGEON_PLATE_BODY_SHARE` of a body's own, so a plate on the
## Chainmaker's Road is as dangerous to a Warden as one on the Long Road and
## never a wall for a new Warden. A readout of the plate - its iron, its rune,
## the ember while it is armed - is drawn here and read by nothing.

const GROUP: StringName = &"dungeon_plates"
const IRON: Color = Color(0.13, 0.12, 0.11, 1.0)
const RIM: Color = Color(0.3, 0.27, 0.22, 1.0)
const EMBER: Color = Color(1.0, 0.5, 0.22, 1.0)
const SIZE: float = 56.0

var arena: RiftArena = null
var armed: bool = true
var fired: int = 0

var _rearm_left: float = 0.0
var _life: float = 0.0
## The ember, on its own additive canvas: the deep's dark is a CanvasModulate
## over everything, and a rune drawn plainly under it photographed as a speck.
var _rune: Node2D


func _ready() -> void:
	add_to_group(GROUP)
	z_index = -1
	z_as_relative = true
	_rune = Node2D.new()
	_rune.name = "Rune"
	_rune.material = LightKit.additive_material()
	_rune.draw.connect(_draw_rune)
	add_child(_rune)


func _process(delta: float) -> void:
	_life += delta
	if not armed:
		_rearm_left -= delta
		if _rearm_left <= 0.0:
			armed = true
		_redraw_both()
		return
	if fmod(_life, 0.1) < delta:
		_redraw_both()
	if arena == null:
		return
	if _something_stands_here():
		fire()


## The hero, a spirit or a body of this arena on the plate.
func _something_stands_here() -> bool:
	var who: Hero = Hero.nearest_on_field(get_tree(), global_position, Balance.DUNGEON_PLATE_TRIGGER)
	if who != null and who.is_alive():
		return true
	for body: Enemy in arena.enemies_near(global_position, Balance.DUNGEON_PLATE_TRIGGER):
		if body.field() == arena:
			return true
	return false


## The plate drops and the circle is told. The strike lives under the arena's
## effects, so it freezes with the arena and lands whatever stepped off.
func fire() -> void:
	if not armed:
		return
	armed = false
	fired += 1
	_rearm_left = Balance.DUNGEON_PLATE_REARM
	var pool: Health = Health.of(arena.hero) if arena != null and arena.hero != null else null
	var strike := EnemyGroundStrike.new()
	strike.name = "PlateStrike"
	strike.shape = EnemyGroundStrike.Shape.CIRCLE
	strike.reach = Balance.DUNGEON_PLATE_REACH
	strike.delay = Balance.DUNGEON_PLATE_DELAY
	strike.damage = (pool.max_hp if pool != null else 0.0) * Balance.DUNGEON_PLATE_DAMAGE
	strike.tint = EMBER
	strike.blamed_on = "A pressure plate"
	strike.hurts_bodies = true
	strike.body_share = Balance.DUNGEON_PLATE_BODY_SHARE
	strike.body_field = arena
	strike.position = global_position
	var home: Node = arena.effect_root if arena != null and arena.effect_root != null else get_parent()
	home.add_child(strike)
	Sfx.play_at("sfx_hit_stone_1", global_position, -6.0)
	Vfx.dust(global_position, Color(0.35, 0.3, 0.26, 0.9), 6, 30.0)
	_redraw_both()


func _redraw_both() -> void:
	queue_redraw()
	if _rune != null:
		_rune.queue_redraw()


func _draw() -> void:
	var half: float = SIZE * 0.5
	draw_rect(Rect2(-half, -half * 0.72, SIZE, SIZE * 0.72), RIM)
	draw_rect(Rect2(-half + 3.0, -half * 0.72 + 3.0, SIZE - 6.0, SIZE * 0.72 - 6.0), IRON)


func _draw_rune() -> void:
	var half: float = SIZE * 0.5
	var glow: float = 0.0
	if armed:
		glow = 0.5 + 0.3 * sin(_life * 3.0)
	else:
		# Dark while it rests, warming back as the rearm runs down.
		glow = 0.25 * (1.0 - clampf(_rearm_left / maxf(Balance.DUNGEON_PLATE_REARM, 0.01), 0.0, 1.0))
	_rune.draw_arc(Vector2.ZERO, half * 0.4, 0.0, TAU, 28, Color(EMBER, glow), 3.0, true)
	_rune.draw_arc(Vector2.ZERO, half * 0.22, 0.0, TAU, 20, Color(EMBER, glow * 0.6), 2.0, true)
	_rune.draw_circle(Vector2.ZERO, 3.5, Color(EMBER, glow))
