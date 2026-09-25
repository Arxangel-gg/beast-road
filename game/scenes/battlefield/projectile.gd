class_name Projectile
extends Node2D

## A tower's shot: one node that draws itself (2026-09-24).
##
## It was a tree - a body node, two `Line2D`s for the ribbon and its filament,
## three polygons for the glow, the core and the hot ember, a head sprite, a
## `PointLight2D` with its driver, a shadow polygon for a lob, and a sprite
## with a tween shed eighteen times a second - nine to eleven nodes a shot, and
## a lane of forty level-8 towers keeps a hundred shots in the air. Measured
## on Act X: 7,151 canvas items and 2,674 draw calls at 90-99 ms a frame.
##
## Now the picture is one `_draw` on this node - a tapered, feathered ribbon
## with a white-hot filament inside it, a soft glow, the element's head (its
## painted art where there is some, its authored silhouette where not), the
## ember of a high tier, and the shadow a lob throws - and the motes go to
## `Vfx.mote`, the drawn ink canvas. What remains as a node is the light,
## which has to be a light, and is on a budget (`LightKit.shot_light_free`).
##
## **The look is drawn as light.** Every shape has a solid middle and a rim at
## zero alpha, and the glow layer blends additively, so a volley over a torch
## pool brightens it rather than laying flat strokes across it. The owner's
## report was that the projectiles were "not polished"; a `Line2D` with a
## round cap reads as a pipe, and that was the whole of it.
##
## **A style is a look and never a fact**: a lob's picture rises off the
## straight path while the node that hits stays on it, a lance is the same
## speed drawn longer, a chain's jitter is in the ribbon. `tower_juice_check`
## reads the damage back through every style.

const PROJECTILE_ART_FORMAT: String = "res://art/vfx/projectile_%s.png"

var damage: float = 0.0
var knockback: float = 0.0
var speed: float = 600.0
var colour: Color = Color.WHITE
var data: TowerData = null

## The level of the tower that fired this, which is what every visual here
## sizes itself from: a level 8 shot is bigger, hotter, longer-tailed.
var tier: int = 1
## What the shot's blast is scaled by - a Spread capstone widens it.
var aoe_scale: float = 1.0

var _target: Enemy = null
var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0
var _aimed: bool = false
var _shot: int = TowerData.Shot.BOLT

## The ribbon: where the picture has been, newest last, in world space.
var _history: PackedVector2Array = []
var _spin: float = 0.0
var _mote_left: float = 0.0

## A lob's arc: how far it had to fly when it left, how high the picture is
## now, and the highest it has been (the gate reads that).
var _lob_total: float = 0.0
var _lift: float = 0.0
var _peak_lift: float = 0.0

## The head's painted art, when the element has some; frames for an animated
## head, else one texture.
var _head_frames: Array[Texture2D] = []
var _head_shape: PackedVector2Array = []
var _ember_shape: PackedVector2Array = []
var _glow_shape: PackedVector2Array = []

## The additive layer the ribbon, the glow and the filament are drawn on - the
## one child a shot keeps for its picture, because a canvas item has one
## material and the head art is not additive.
var _glow_layer: ProjectileGlow = null

## The light, on the shared shot-light budget; null when none was free.
var _light: PointLight2D = null
var _carries_light: bool = false

## Reused every frame rather than reallocated.
var _points: PackedVector2Array = PackedVector2Array()
var _colours: PackedColorArray = PackedColorArray()
var _indices: PackedInt32Array = PackedInt32Array()


## A shot from the pool, or a fresh one (`NodePool`, 2026-09-24). The tower
## asks here; `_ready` dresses it per use and `reset_for_pool` undresses it.
static func take() -> Projectile:
	return NodePool.take(&"shot", func() -> Projectile: return Projectile.new()) as Projectile


## Builds the shot. **`fired_at` is a parameter, not a field to assign after.**
##
## Everything visual here sizes itself from the tier - head, trail, glow, light -
## so a caller that set `tier` afterwards got a level 1 shot from a level 5
## tower, and nothing said so. That is exactly what happened, for as long as the
## scaling has existed. Taking it as an argument makes the mistake unavailable
## rather than merely commented against.
func setup(target: Enemy, tower_data: TowerData, hit_damage: float,
		hit_knockback: float, fired_at: int = 1) -> void:
	tier = maxi(fired_at, 1)
	_target = target
	data = tower_data
	damage = hit_damage
	knockback = hit_knockback
	colour = tower_data.shot_colour()
	_shot = int(tower_data.shot)
	speed = Balance.TOWER_PROJECTILE_SPEED


func _ready() -> void:
	z_index = Balance.VFX_Z - 1
	# Per use (2026-09-24): a pooled shot runs this on every take.
	visible = true
	set_process(true)
	_glow_shape = _element_shape(Balance.PROJECTILE_GLOW_SCALE * _tier_scale())
	_head_shape = _element_shape(_tier_scale())
	# **An upgraded shot is hotter, not just larger.** Scale already carried the
	# tier and a bigger shot still reads as the same shot; a white centre turning
	# against its own shell changes what the projectile is. Only from
	# `PROJECTILE_HOT_TIER`, so the step is an event rather than a gradient
	# nobody notices crossing.
	_ember_shape = PackedVector2Array()
	if tier >= Balance.PROJECTILE_HOT_TIER:
		_ember_shape = _element_shape(_tier_scale() * Balance.PROJECTILE_HOT_SCALE)
	_head_frames.clear()
	_load_head_art()
	if _glow_layer == null:
		_glow_layer = ProjectileGlow.new()
		_glow_layer.shot = self
		add_child(_glow_layer)
	# Every shot carries its own small light, which is most of why a night
	# battlefield reads at all - up to `PROJECTILE_LIGHT_MAX` of them at once
	# (2026-09-24): a lane of forty level-8 towers keeps a hundred shots in
	# the air, and a hundred lights is the frame going away. None on Low.
	if LightKit.shot_light_free():
		_light = LightKit.add_light(self, colour,
			Balance.PROJECTILE_LIGHT_RADIUS * _tier_scale(),
			Balance.PROJECTILE_LIGHT_ENERGY * _tier_scale())
		LightKit.take_shot_light()
		_carries_light = true
	# **Aimed on the first tick, not here.** The field positions a shot *after*
	# adding it to the tree, so in `_ready` the node still sits at the world
	# origin, and a heading taken from there is a heading from the wrong side
	# of the map: every shot left its tower pointing somewhere else and curved
	# round over the first tenth of a second. A tower far from the origin
	# threw shots that flew away from the body before homing back.


## Back to the pool rather than freed (2026-09-24), from the landing and from
## the fizzle alike. The blow was dealt before this; a reused shot cannot deal
## it twice because `reset_for_pool` forgets who it was flying at.
func _release() -> void:
	NodePool.give(&"shot", self, Balance.SHOT_POOL_MAX)


## Everything a use decided, undone - the pool's rule. The glow layer is kept
## (it is what pooling saves); the light is not, because its driver is bound
## to it at `setup` and the budget slot goes back in `_exit_tree` as always.
func reset_for_pool() -> void:
	visible = false
	set_process(false)
	for child: Node in get_children():
		if child is PointLight2D or child is LightDriver:
			child.queue_free()
	_light = null
	damage = 0.0
	knockback = 0.0
	speed = 600.0
	colour = Color.WHITE
	data = null
	tier = 1
	aoe_scale = 1.0
	_target = null
	_direction = Vector2.RIGHT
	_life = 0.0
	_aimed = false
	_shot = TowerData.Shot.BOLT
	_history.clear()
	_spin = 0.0
	_mote_left = 0.0
	_lob_total = 0.0
	_lift = 0.0
	_peak_lift = 0.0
	_head_frames.clear()
	_head_shape = PackedVector2Array()
	_ember_shape = PackedVector2Array()
	_glow_shape = PackedVector2Array()
	rotation = 0.0


func _exit_tree() -> void:
	if _carries_light:
		_carries_light = false
		LightKit.give_shot_light()


## Swaps the authored silhouette for painted art, where art exists.
func _load_head_art() -> void:
	var element: int = data.element if data != null else TowerData.Element.FIRE
	var path: String = PROJECTILE_ART_FORMAT % TowerData.element_name(element).to_lower()
	if not ResourceLoader.exists(path):
		return
	_head_frames = GameData.load_idle_frames(path)
	if _head_frames.is_empty():
		var single: Texture2D = load(path) as Texture2D
		if single != null:
			_head_frames.append(single)


## The heading from where the shot actually is to what it is flying at.
func _aim() -> void:
	_aimed = true
	if _target != null and is_instance_valid(_target):
		_direction = (_target.global_position - global_position).normalized()
	rotation = _direction.angle()


func _process_measured(delta: float) -> void:
	if not _aimed:
		_aim()
	_life += delta
	if _life > Balance.PROJECTILE_MAX_LIFE:
		_expire()
		return

	# Lost the target: keep flying so the shot does not vanish mid-air.
	if _target == null or not is_instance_valid(_target) or _target.is_dying():
		_target = null
	else:
		var wanted: Vector2 = (_target.global_position - global_position).normalized()
		_direction = _direction.lerp(wanted, clampf(Balance.PROJECTILE_TURN_RATE * delta, 0.0, 1.0)).normalized()

	global_position += _direction * speed * delta
	rotation = _direction.angle()
	_tick_lob()
	# Earth shots tumble; everything else holds its heading.
	if data != null and data.element == TowerData.Element.EARTH:
		_spin += delta * Balance.PROJECTILE_SPIN_RATE * (1.0
			+ float(_tier_step()) * Balance.PROJECTILE_SPIN_TIER_STEP)
	_push_trail()
	_mote_left -= delta
	if _mote_left <= 0.0:
		_mote_left = Balance.PROJECTILE_MOTE_INTERVAL
		if _shot == TowerData.Shot.CHAIN:
			_mote_left *= Balance.PROJECTILE_CHAIN_MOTE_SCALE
		# A mote is a record on the ink canvas now, eighteen times a second per
		# shot; under load the director thins them and the particle scale can
		# give them away entirely. Cosmetic, so nothing about the shot moves.
		var keep: float = JuiceDirector.weight(JuiceDirector.Priority.COSMETIC) \
			* Graphics.particle_scale()
		if keep >= 1.0 or randf() < keep:
			_shed_mote()
	queue_redraw()
	if _glow_layer != null:
		_glow_layer.queue_redraw()

	if _target != null:
		var reach: float = _target.contact_radius() + Balance.PROJECTILE_HIT_RADIUS
		if global_position.distance_to(_target.global_position) <= reach:
			_impact()


## What a lob does every frame: its picture rises on an arc over the straight
## path and its shadow stays on the ground where the hit will land. The arc is
## measured against the distance the shot had to fly when it left the tower,
## so it peaks halfway however far that is - taken on the first tick rather
## than in `_ready`, because the field positions a shot after adding it.
func _tick_lob() -> void:
	if _shot != TowerData.Shot.LOB:
		return
	var left: float = 0.0
	if _target != null and is_instance_valid(_target):
		left = global_position.distance_to(_target.global_position)
	if _lob_total <= 0.0:
		_lob_total = maxf(left, 1.0)
	var progress: float = clampf(1.0 - left / maxf(_lob_total, 1.0), 0.0, 1.0)
	var arc: float = sin(progress * PI)
	_lift = arc * Balance.PROJECTILE_LOB_HEIGHT * _tier_scale()
	_peak_lift = maxf(_peak_lift, _lift)


## Where the picture is: the shot's own position, lifted by a lob's arc.
func _drawn_at() -> Vector2:
	return global_position + Vector2(0.0, -_lift)


func _push_trail() -> void:
	var at: Vector2 = _drawn_at()
	# A point every `PROJECTILE_TRAIL_STEP` of travel, so a fast frame rate
	# does not lay a hundred points a shot; then the tail is trimmed to a
	# length in units, so the ribbon is the same ribbon at any frame rate.
	if not _history.is_empty() \
			and _history[_history.size() - 1].distance_to(at) < Balance.PROJECTILE_TRAIL_STEP:
		return
	_history.append(at)
	var allowed: float = Balance.PROJECTILE_TRAIL_LENGTH * _tier_scale()
	if _shot == TowerData.Shot.LANCE:
		allowed *= Balance.PROJECTILE_LANCE_TRAIL
	var length: float = 0.0
	for index: int in range(_history.size() - 1, 0, -1):
		length += _history[index].distance_to(_history[index - 1])
		if length > allowed:
			_history = _history.slice(index - 1)
			break
	while _history.size() > Balance.PROJECTILE_TRAIL_POINTS:
		_history.remove_at(0)


func _shed_mote() -> void:
	var drift: Vector2 = -_direction * randf_range(18.0, 36.0) \
		+ _direction.orthogonal() * randf_range(-14.0, 14.0)
	Vfx.mote(_drawn_at() + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)), drift,
		Color(colour.lerp(Color.WHITE, 0.55), 0.72),
		randf_range(3.0, 5.5) * _tier_scale(), Balance.PROJECTILE_MOTE_LIFE)


# --- The picture ------------------------------------------------------------------

## What this node draws itself: the head - painted art or the element's own
## silhouette - the ember, and a lob's shadow. Everything that is light is on
## the additive child.
func _draw_measured() -> void:
	var at: Vector2 = to_local(_drawn_at())
	if _shot == TowerData.Shot.LOB:
		# The shadow stays on the ground under the shot, smaller and fainter
		# the higher the picture is - which is what says "this is in the air".
		var arc: float = _lift / maxf(Balance.PROJECTILE_LOB_HEIGHT * _tier_scale(), 1.0)
		var w: float = Balance.PROJECTILE_WIDTH * _tier_scale() * 2.2 * (1.0 - 0.45 * arc)
		_begin()
		_ellipse(Vector2.ZERO, w, w * 0.55, Color(0.0, 0.0, 0.0, 1.0),
			Balance.PROJECTILE_LOB_SHADOW_ALPHA * (1.0 - 0.5 * arc), 10)
		_flush()
	var stretch: Vector2 = Balance.PROJECTILE_LANCE_STRETCH \
		if _shot == TowerData.Shot.LANCE else Vector2.ONE
	if not _head_frames.is_empty():
		var frame: Texture2D = _head_frames[int(_life * Balance.VFX_ART_FRAME_RATE) % _head_frames.size()]
		var scale: float = Balance.PROJECTILE_ART_SCALE * _tier_scale()
		draw_set_transform(at, _spin, stretch * scale)
		draw_texture(frame, -frame.get_size() * 0.5, colour.lerp(Color.WHITE, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		# The authored silhouette, with a soft rim.
		draw_set_transform(at, _spin, stretch)
		_begin()
		_soft_polygon(_head_shape, colour.lerp(Color.WHITE, 0.55), 1.0)
		_flush()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not _ember_shape.is_empty():
		# Against the shell. Two things turning the same way read as one thing
		# turning; opposed, they read as something being driven.
		draw_set_transform(at, -_spin * 1.6, stretch)
		_begin()
		_soft_polygon(_ember_shape, Color(1.0, 0.97, 0.9), 0.92)
		_flush()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The additive half, drawn by the glow child: the ribbon, its filament and
## the glow round the head.
func draw_light(on: CanvasItem) -> void:
	if _history.size() < 2:
		_draw_glow_only(on)
		return
	var inverse: Transform2D = on.get_global_transform().affine_inverse()
	var points: PackedVector2Array = _history
	if _shot == TowerData.Shot.CHAIN:
		# A jagged ribbon: every other point thrown off the path, freshly each
		# frame, so the trail crackles rather than merely bends.
		points = PackedVector2Array(_history)
		for index: int in range(1, points.size() - 1, 2):
			var along: Vector2 = (_history[index + 1] - _history[index - 1]).normalized()
			points[index] += along.orthogonal() * randf_range(-Balance.PROJECTILE_CHAIN_JITTER,
				Balance.PROJECTILE_CHAIN_JITTER)
	var width: float = Balance.PROJECTILE_WIDTH * _tier_scale()
	var filament: float = Balance.PROJECTILE_FILAMENT_WIDTH * _tier_scale()
	if _shot == TowerData.Shot.LANCE:
		width *= 0.8
		filament *= 1.7
	# The broad elemental ribbon, tapering to nothing at the tail and fading
	# along its length so the tail dissolves; then the white-hot filament
	# inside it, which is what keeps volleys readable against a night grade.
	# One geometry for both projectile kinds (`InkRibbon`), so the enemy's
	# shot and the tower's cannot drift apart the first time either is tuned.
	InkRibbon.ribbon(on, points, inverse, width, Color(colour, 0.75), 0.0, 0.85)
	InkRibbon.ribbon(on, points, inverse, filament,
		Color(colour.lerp(Color.WHITE, 0.9 if _shot == TowerData.Shot.LANCE else 0.82), 0.95),
		0.0, 1.0)
	_draw_glow_only(on)


func _draw_glow_only(on: CanvasItem) -> void:
	var inverse: Transform2D = on.get_global_transform().affine_inverse()
	var at: Vector2 = inverse * _drawn_at()
	var lit: float = _glow_alpha(0.34 if not _head_frames.is_empty() else 0.44)
	# Turned with the flight as the head is: the glow child is top-level, so
	# the node's own rotation does not reach it (2026-09-24 - a lance's
	# stretched glow lay across the world's x axis whatever way it flew).
	on.draw_set_transform(at, rotation + _spin, Balance.PROJECTILE_LANCE_STRETCH \
		if _shot == TowerData.Shot.LANCE else Vector2.ONE)
	_begin()
	_soft_polygon(_glow_shape, colour, lit)
	_flush_on(on)
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A polygon with a solid centre and a soft rim: a fan from the centroid to
## each vertex at `lit`, then a feather band outside it at nothing.
func _soft_polygon(shape: PackedVector2Array, tint: Color, lit: float) -> void:
	if shape.size() < 3:
		return
	var centre := Vector2.ZERO
	for point: Vector2 in shape:
		centre += point
	centre /= float(shape.size())
	var base: int = _points.size()
	var n: int = shape.size()
	_points.append(centre)
	_colours.append(Color(tint.r, tint.g, tint.b, lit))
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	for point: Vector2 in shape:
		_points.append(point)
		_colours.append(Color(tint.r, tint.g, tint.b, lit * 0.85))
	for point: Vector2 in shape:
		_points.append(centre + (point - centre) * 1.55)
		_colours.append(clear)
	for index: int in n:
		var a: int = base + 1 + index
		var b: int = base + 1 + (index + 1) % n
		_indices.append(base)
		_indices.append(a)
		_indices.append(b)
		# the feather quad between the edge a-b and its outer copy
		var a2: int = a + n
		var b2: int = b + n
		_indices.append(a)
		_indices.append(a2)
		_indices.append(b)
		_indices.append(b)
		_indices.append(a2)
		_indices.append(b2)


func _ellipse(centre: Vector2, rx: float, ry: float, tint: Color, lit: float,
		segments: int) -> void:
	var base: int = _points.size()
	_points.append(centre)
	_colours.append(Color(tint.r, tint.g, tint.b, lit))
	var clear := Color(tint.r, tint.g, tint.b, 0.0)
	for step: int in segments:
		var angle: float = TAU * float(step) / float(segments)
		_points.append(centre + Vector2(cos(angle) * rx, sin(angle) * ry))
		_colours.append(clear)
	for step: int in segments:
		_indices.append(base)
		_indices.append(base + 1 + step)
		_indices.append(base + 1 + (step + 1) % segments)


func _begin() -> void:
	_points.clear()
	_colours.clear()
	_indices.clear()


func _flush() -> void:
	_flush_on(self)


func _flush_on(on: CanvasItem) -> void:
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(on.get_canvas_item(), _indices, _points, _colours)


# --- What the gates and the field read ---------------------------------------------

func _glow_alpha(base: float) -> float:
	return minf(base + float(_tier_step()) * Balance.PROJECTILE_GLOW_TIER_STEP, 0.72)


func style() -> int:
	return _shot


func lifted() -> float:
	return _lift


func peak_lift() -> float:
	return _peak_lift


func has_shadow() -> bool:
	return _shot == TowerData.Shot.LOB


func has_hot_core() -> bool:
	return not _ember_shape.is_empty()


func look() -> Dictionary:
	var width: float = Balance.PROJECTILE_WIDTH * _tier_scale()
	if _shot == TowerData.Shot.LANCE:
		width *= 0.8
	return {
		"trail": width,
		"glow_alpha": _glow_alpha(0.22 if not _head_frames.is_empty() else 0.30),
		"hot": has_hot_core(),
	}


func _tier_step() -> int:
	return clampi(tier, 1, Balance.TOWER_MAX_LEVEL) - 1


func _tier_scale() -> float:
	return 1.0 + float(clampi(tier, 1, Balance.TOWER_MAX_LEVEL) - 1) * Balance.PROJECTILE_TIER_SCALE


## Element-specific head silhouettes. Fire is a teardrop, water a shard, earth a
## chunk, air a thin dart.
func _element_shape(scale: float) -> PackedVector2Array:
	var w: float = Balance.PROJECTILE_WIDTH * scale
	var element: int = data.element if data != null else 0
	match element:
		TowerData.Element.WATER:
			return PackedVector2Array([
				Vector2(w * 2.6, 0.0), Vector2(0.0, -w * 0.9),
				Vector2(-w * 1.6, 0.0), Vector2(0.0, w * 0.9)])
		TowerData.Element.EARTH:
			return PackedVector2Array([
				Vector2(w * 1.5, -w * 0.6), Vector2(w * 1.1, w * 1.2),
				Vector2(-w * 1.2, w * 1.0), Vector2(-w * 1.4, -w * 0.9),
				Vector2(0.0, -w * 1.4)])
		TowerData.Element.AIR:
			return PackedVector2Array([
				Vector2(w * 3.4, 0.0), Vector2(-w * 1.0, -w * 0.5),
				Vector2(-w * 0.4, 0.0), Vector2(-w * 1.0, w * 0.5)])
		_:
			return PackedVector2Array([
				Vector2(w * 2.2, 0.0), Vector2(w * 0.6, -w * 1.0),
				Vector2(-w * 1.4, -w * 0.6), Vector2(-w * 1.4, w * 0.6),
				Vector2(w * 0.6, w * 1.0)])


# --- The hit ------------------------------------------------------------------------

func _impact() -> void:
	var field: Battlefield = _find_field()
	# `tier` is the firing tower's level, so the blast grows with the upgrade
	# rather than staying at the resource's level-one radius forever.
	var blast: float = data.aoe_at(tier) * aoe_scale
	if field != null and blast > 0.0:
		for enemy: Enemy in field.enemies_near(global_position, blast):
			_apply(enemy)
		Vfx.ring(global_position, blast, Color(colour, 0.55), 0.3, 4.0)
	elif _target != null and is_instance_valid(_target):
		_apply(_target)

	if data.ground_zone_dps > 0.0 and field != null:
		field.spawn_ground_zone(global_position, data.ground_zone_dps_at(tier),
			data.ground_zone_duration_at(tier), maxf(blast, 90.0), data.element)

	# A bright flash, a burst away from the impact, and a ring for anything with
	# area. Three cues rather than one, because a single spark at this size is
	# easy to miss in a crowded lane.
	Vfx.impact(global_position, data.element if data != null else TowerData.Element.FIRE,
		colour, maxf(blast * 1.15, Balance.PROJECTILE_IMPACT_ART_SIZE * _tier_scale()))
	Vfx.spark(global_position, colour.lerp(Color.WHITE, 0.4),
		int(float(Balance.PROJECTILE_IMPACT_SPARKS) * _tier_scale()), -_direction, 260.0)
	Vfx.ring(global_position, Balance.PROJECTILE_IMPACT_RING * _tier_scale(),
		Color(colour, 0.7), 0.22, 3.0)
	Vfx.flash_at(global_position, colour, Balance.PROJECTILE_IMPACT_FLASH * _tier_scale())
	# A lob lands: dust off the ground and a tremor weighted by distance from
	# the camera, through the same door every blow in the game uses.
	if _shot == TowerData.Shot.LOB:
		Vfx.dust(global_position, Color(colour.darkened(0.35), 0.5), 8, 62.0 * _tier_scale())
		EventBus.camera_impact.emit(global_position, Balance.PROJECTILE_LOB_IMPACT * _tier_scale())
	_release()


## Reached the end of its life without connecting. Fizzles rather than
## disappearing, so a miss is visible.
func _expire() -> void:
	Vfx.spark(global_position, Color(colour, 0.5), 3, _direction, 90.0)
	_release()


func _apply(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	# **Mirrorhide** (2026-09-25): the whole shot glances, status and all.
	if enemy.glances_tower_shots():
		enemy.glance_off(global_position)
		return
	if data != null:
		enemy.mark_element(data.element)
	if damage > 0.0:
		enemy.take_damage(damage * enemy.brand_multiplier(), global_position, knockback)
	var utility: float = data.utility_at(tier)
	if data.slow_factor < 1.0:
		var slow: float = 1.0 - (1.0 - data.slow_factor) * utility
		enemy.apply_slow(maxf(slow - Modifiers.value(Modifiers.SLOW_STRENGTH), 0.1),
			data.slow_duration * utility)
	if data.burn_dps > 0.0:
		enemy.apply_burn(data.burn_dps * utility * Modifiers.multiplier(Modifiers.BURN_DAMAGE),
			data.burn_duration * sqrt(utility))
	if data.freeze_chance > 0.0 and RunState.rng("combat").randf() \
			< minf(data.freeze_chance * utility, 0.82):
		enemy.apply_freeze(1.2 * sqrt(utility))


func _find_field() -> Battlefield:
	var node: Node = get_parent()
	while node != null:
		var field := node as Battlefield
		if field != null:
			return field
		node = node.get_parent()
	return null


## The additive layer of a shot: one child, one material, drawn by the shot.
class ProjectileGlow extends Node2D:
	var shot: Projectile = null

	func _ready() -> void:
		# World space, so the ribbon behind the head stays put as the head moves
		# rather than turning with the projectile.
		top_level = true
		# **Under the head**, absolutely: a child draws after its parent, so
		# the ribbon and glow were laid over the head and washed it out.
		z_as_relative = false
		z_index = Balance.VFX_Z - 2
		var material: CanvasItemMaterial = LightKit.additive_material()
		self.material = material

	func _draw() -> void:
		if shot != null and is_instance_valid(shot):
			shot.draw_light(self)


## `FrameProfile` bucket "shot": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"shot", started)


## `FrameProfile` bucket "shot_draw": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"shot_draw", started)
