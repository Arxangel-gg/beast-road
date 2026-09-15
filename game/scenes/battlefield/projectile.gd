class_name Projectile
extends Node2D

## A tower's shot, in flight.
##
## Replaces an instant tracer line. The difference is not cosmetic: a shot that
## takes time to arrive means a tower can miss a fast enemy, a slow heavy shell
## reads differently from a rapid one, and the player can see which lane is
## actually under fire. It makes the towers legible.
##
## Homing rather than ballistic. A tower that fires at where something *was* is
## technically more honest and practically just frustrating at this scale.

## Element head art, derived from the element name the same way every other
## asset path in the project is derived from an id (CLAUDE.md SS4).
const PROJECTILE_ART_FORMAT: String = "res://art/vfx/projectile_%s.png"

## Set by the tower before it enters the tree.
var damage: float = 0.0
var knockback: float = 0.0
var speed: float = 600.0
var colour: Color = Color.WHITE
var data: TowerData = null

## Level of the tower that fired this. An upgraded tower throws visibly bigger,
## brighter, longer-tailed shots, so the investment shows in flight rather than
## only in the damage numbers.
var tier: int = 1
## What the firing tower's path does to this shot's blast. 1.0 unless the
## tower took the spreading path (2026-09-13).
var aoe_scale: float = 1.0

var _target: Enemy = null
var _direction: Vector2 = Vector2.RIGHT
var _life: float = 0.0

## A ribbon of recent positions. A moving dot reads as a dot; a dot with a tail
## behind it reads as speed, and costs one node and a ring buffer.
var _trail: Line2D
var _filament: Line2D
var _core: Polygon2D
## The white heart a high-tier shot carries. Null below `PROJECTILE_HOT_TIER`.
var _ember: Polygon2D = null

## Painted head, when the element has art. The authored polygons stay as the
## fallback, so a missing file costs nothing and the shot still reads.
var _head: Sprite2D = null

## The head's own animation, when the element has authored continuation frames.
##
## Empty is the normal case for any element that ships one drawing, and costs
## nothing: the sprite simply keeps the single texture it was given. Frame zero
## of the sequence *is* that texture, by the same convention every animated
## structure and creature in the project uses.
var _head_frames: Array[Texture2D] = []
var _glow: Polygon2D
var _light: PointLight2D
var _history: PackedVector2Array = []
var _spin: float = 0.0
var _mote_left: float = 0.0

## The style this shot is drawn in (`TowerData.Shot`, owner brief 2026-09-14),
## and what the style needs. **The style is a look and never a fact**: the
## node's own position, speed, homing and hit are the same in all five, and
## `tower_juice_check` fires each at a body and reads the damage back.
var _shot: int = TowerData.Shot.BOLT
## Everything that flies - head, glow, core, ember, light - hangs off this so
## a lob can lift the picture off the straight path while the hit stays on it.
var _body: Node2D = null
## A lob's shadow on the ground beneath the lifted picture.
var _shadow: Polygon2D = null
var _lob_total: float = 0.0
var _lift: float = 0.0
var _peak_lift: float = 0.0
var _aimed: bool = false


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
	_body = Node2D.new()
	add_child(_body)

	# The trail lives in world space, so it stays put as the head moves rather
	# than rotating with the projectile.
	_trail = Line2D.new()
	_trail.top_level = true
	_trail.width = Balance.PROJECTILE_WIDTH * _tier_scale()
	_trail.default_color = Color(colour, 0.75)
	_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	_trail.joint_mode = Line2D.LINE_JOINT_ROUND
	# Tapers to nothing at the tail; a constant-width trail looks like a pipe.
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.05))
	taper.add_point(Vector2(1.0, 1.0))
	_trail.width_curve = taper
	# Fades along its length as well as tapering, so the tail dissolves.
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([Color(colour, 0.0), Color(colour, 0.85)])
	_trail.gradient = ramp
	add_child(_trail)

	# A thin white-hot filament inside the broad elemental ribbon adds contrast
	# at speed and keeps volleys readable against the darker night grade.
	_filament = Line2D.new()
	_filament.top_level = true
	_filament.width = Balance.PROJECTILE_FILAMENT_WIDTH * _tier_scale()
	_filament.default_color = Color(colour.lerp(Color.WHITE, 0.82), 0.95)
	_filament.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_filament.end_cap_mode = Line2D.LINE_CAP_ROUND
	_filament.width_curve = taper
	_filament.gradient = ramp
	add_child(_filament)

	# Each element gets its own head shape, so a lane full of shots is readable
	# at a glance without reading the colours.
	_glow = Polygon2D.new()
	_glow.polygon = _head_shape(Balance.PROJECTILE_GLOW_SCALE * _tier_scale())
	# Blooms harder with the tier, so the shot reads brighter as well as bigger.
	_glow.color = Color(colour, _glow_alpha(0.30))
	_body.add_child(_glow)

	_core = Polygon2D.new()
	_core.polygon = _head_shape(_tier_scale())
	# A hot centre: the element colour lifted toward white reads as energy
	# rather than as a coloured shape.
	_core.color = colour.lerp(Color.WHITE, 0.55)
	_body.add_child(_core)

	# **An upgraded shot is hotter, not just larger.** Scale already carried the
	# tier and a bigger shot still reads as the same shot; a white centre turning
	# against its own shell changes what the projectile is. Only from
	# `PROJECTILE_HOT_TIER`, so the step is an event rather than a gradient
	# nobody notices crossing.
	if tier >= Balance.PROJECTILE_HOT_TIER:
		_ember = Polygon2D.new()
		_ember.polygon = _head_shape(_tier_scale() * Balance.PROJECTILE_HOT_SCALE)
		_ember.color = Color(1.0, 0.97, 0.9, 0.92)
		_body.add_child(_ember)

	_build_head()

	# Every shot carries its own small light, which is most of why a night
	# battlefield reads at all.
	_light = LightKit.add_light(_body, colour,
		Balance.PROJECTILE_LIGHT_RADIUS * _tier_scale(),
		Balance.PROJECTILE_LIGHT_ENERGY * _tier_scale())

	# **Aimed on the first tick, not here.** The field positions a shot *after*
	# adding it to the tree, so in `_ready` the node still sits at the world
	# origin, and a heading taken from there is a heading from the wrong side
	# of the map: every shot left its tower pointing somewhere else and curved
	# round over the first tenth of a second. A tower far from the origin
	# threw shots that flew away from the body before homing back.
	_dress_for_style()


## The heading from where the shot actually is to what it is flying at.
func _aim() -> void:
	_aimed = true
	if _target != null and is_instance_valid(_target):
		_direction = (_target.global_position - global_position).normalized()
	rotation = _direction.angle()


## What the style changes about the picture, once, when the shot is built.
func _dress_for_style() -> void:
	match _shot:
		TowerData.Shot.LANCE:
			# A long bright streak: a thinner ribbon, a hotter filament and a
			# head stretched along the flight.
			_trail.width *= 0.8
			_filament.width *= 1.7
			_filament.default_color = Color(colour.lerp(Color.WHITE, 0.9), 1.0)
			_body.scale = Balance.PROJECTILE_LANCE_STRETCH
		TowerData.Shot.LOB:
			# The arc is measured against the distance the shot had to fly when
			# it left the tower, so it peaks halfway however far that is. Taken
			# on the first tick rather than here: the field positions a shot
			# *after* adding it, so in `_ready` it is still at the world origin.
			_lob_total = 0.0
			_shadow = Polygon2D.new()
			var points: PackedVector2Array = []
			var w: float = Balance.PROJECTILE_WIDTH * _tier_scale() * 2.2
			for i: int in 10:
				var a: float = TAU * float(i) / 10.0
				points.append(Vector2(cos(a) * w, sin(a) * w * 0.55))
			_shadow.polygon = points
			_shadow.color = Color(0.0, 0.0, 0.0, Balance.PROJECTILE_LOB_SHADOW_ALPHA)
			_shadow.top_level = true
			_shadow.z_index = Balance.VFX_Z - 3
			add_child(_shadow)
			_shadow.global_position = global_position
		_:
			pass


func _process(delta: float) -> void:
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
	_tick_style()
	if not _head_frames.is_empty() and _head != null:
		var frame: int = int(_life * Balance.VFX_ART_FRAME_RATE) % _head_frames.size()
		_head.texture = _head_frames[frame]

	# Earth shots tumble; everything else holds its heading.
	if data != null and data.element == TowerData.Element.EARTH:
		_spin += delta * Balance.PROJECTILE_SPIN_RATE * (1.0
			+ float(_tier_step()) * Balance.PROJECTILE_SPIN_TIER_STEP)
		_core.rotation = _spin
		_glow.rotation = _spin
		if _head != null:
			_head.rotation = _spin
		# Against the shell. Two things turning the same way read as one thing
		# turning; opposed, they read as something being driven.
		if _ember != null:
			_ember.rotation = -_spin * 1.6

	_push_trail()
	_mote_left -= delta
	if _mote_left <= 0.0:
		_mote_left = Balance.PROJECTILE_MOTE_INTERVAL
		if _shot == TowerData.Shot.CHAIN:
			_mote_left *= Balance.PROJECTILE_CHAIN_MOTE_SCALE
		_shed_mote()

	if _target != null:
		var reach: float = _target.contact_radius() + Balance.PROJECTILE_HIT_RADIUS
		if global_position.distance_to(_target.global_position) <= reach:
			_impact()


## What the style does every frame: a lob lifts its picture on an arc over the
## straight path and drops a shadow where the hit will land.
func _tick_style() -> void:
	if _shot != TowerData.Shot.LOB or _body == null:
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
	# Screen-up, whichever way the node is turned.
	_body.position = Vector2(0.0, -_lift).rotated(-rotation)
	if _shadow != null:
		_shadow.global_position = global_position
		_shadow.scale = Vector2.ONE * (1.0 - 0.45 * arc)
		_shadow.color.a = Balance.PROJECTILE_LOB_SHADOW_ALPHA * (1.0 - 0.5 * arc)


## Where the picture is: the shot's own position, lifted by a lob's arc.
func _drawn_at() -> Vector2:
	return global_position + Vector2(0.0, -_lift)


## Element-specific head silhouettes. Fire is a teardrop, water a shard, earth a
## chunk, air a thin dart.
## Swaps the authored polygon head for painted art, where art exists.
##
## The polygon is hidden rather than removed and the glow is kept but dimmed:
## the glow is what carries the element colour at distance, and the sprite is
## what carries the shape up close. Everything that *moves* - the taper, the
## tumble, the light, the per-level scaling - is untouched, because the motion
## is the read and the sprite is only the surface.
func _build_head() -> void:
	var element: int = data.element if data != null else TowerData.Element.FIRE
	var path: String = PROJECTILE_ART_FORMAT % TowerData.element_name(element).to_lower()
	if not ResourceLoader.exists(path):
		return
	_head = Sprite2D.new()
	_head.texture = load(path)
	# The bolt animates *in place* while this node does the travelling. That
	# split is deliberate and is what keeps one drawing reusable: the sprite
	# carries flicker, heat and trailing embers, and the scene carries speed,
	# homing and where the thing actually is.
	_head_frames = GameData.load_idle_frames(path)
	_head.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_head.add_to_group(Graphics.FILTER_GROUP)
	_head.scale = Vector2.ONE * Balance.PROJECTILE_ART_SCALE * _tier_scale()
	# Tinted toward the element rather than left neutral, so a Fire shot from a
	# fused tower still reads as that tower's colour.
	_head.modulate = colour.lerp(Color.WHITE, 0.35)
	_body.add_child(_head)
	_core.visible = false
	# Still tier-scaled. This used to reset the alpha to a flat value, which
	# quietly undid the upgrade's bloom for every tower that has painted head
	# art - which is all of them.
	_glow.color = Color(colour, _glow_alpha(0.22))


## How much bigger a shot is per level of the tower that fired it.
## The glow's opacity at this tier, from a base the caller chooses.
##
## One place, because two call sites set it and only one of them was scaling -
## so a painted shot bloomed the same at level 5 as at level 1.
func _glow_alpha(base: float) -> float:
	return minf(base + float(_tier_step()) * Balance.PROJECTILE_GLOW_TIER_STEP, 0.72)


## The style this shot is drawn in, how far a lob has lifted its picture, and
## whether it throws a shadow. For the gate.
func style() -> int:
	return _shot


func lifted() -> float:
	return _lift


## The highest the picture rose over its whole flight, for a gate reading a
## shot that has already landed.
func peak_lift() -> float:
	return _peak_lift


func has_shadow() -> bool:
	return _shadow != null and is_instance_valid(_shadow)


## Whether this shot carries the white heart of an upgraded tower. For the gate.
func has_hot_core() -> bool:
	return _ember != null and is_instance_valid(_ember)


## The trail's width and the glow's opacity, for the gate to compare tiers by.
func look() -> Dictionary:
	return {
		"trail": _trail.width if _trail != null else 0.0,
		"glow_alpha": _glow.color.a if _glow != null else 0.0,
		"hot": has_hot_core(),
	}


## How many upgrades this shot is above a fresh one, 0 to TOWER_MAX_LEVEL - 1.
func _tier_step() -> int:
	return clampi(tier, 1, Balance.TOWER_MAX_LEVEL) - 1


func _tier_scale() -> float:
	return 1.0 + float(clampi(tier, 1, Balance.TOWER_MAX_LEVEL) - 1) * Balance.PROJECTILE_TIER_SCALE


func _head_shape(scale: float) -> PackedVector2Array:
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
				Vector2(w * 2.2, 0.0), Vector2(w * 0.2, -w * 1.0),
				Vector2(-w * 1.8, 0.0), Vector2(w * 0.2, w * 1.0)])


## Keeps the last N world positions and feeds them to the trail.
func _push_trail() -> void:
	_history.append(_drawn_at())
	var held: float = float(Balance.PROJECTILE_TRAIL_POINTS) * _tier_scale()
	if _shot == TowerData.Shot.LANCE:
		held *= Balance.PROJECTILE_LANCE_TRAIL
	while _history.size() > int(held):
		_history.remove_at(0)
	if _shot == TowerData.Shot.CHAIN:
		# A jagged ribbon: every other point thrown off the path, freshly each
		# frame, so the trail crackles rather than merely bends.
		var jag: PackedVector2Array = PackedVector2Array(_history)
		for index: int in range(1, jag.size() - 1, 2):
			var along: Vector2 = (_history[index + 1] - _history[index - 1]).normalized()
			jag[index] += along.orthogonal() * randf_range(-Balance.PROJECTILE_CHAIN_JITTER,
				Balance.PROJECTILE_CHAIN_JITTER)
		_trail.points = jag
		_filament.points = jag
		return
	_trail.points = _history
	_filament.points = _history


func _shed_mote() -> void:
	var mote := Sprite2D.new()
	mote.texture = Flame.dot_texture()
	mote.modulate = Color(colour.lerp(Color.WHITE, 0.55), 0.72)
	mote.scale = Vector2.ONE * randf_range(0.08, 0.16) * _tier_scale()
	mote.top_level = true
	add_child(mote)
	mote.global_position = _drawn_at() + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	var drift: Vector2 = -_direction * randf_range(18.0, 36.0) \
		+ _direction.orthogonal() * randf_range(-14.0, 14.0)
	var tween: Tween = mote.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mote, "global_position", mote.global_position + drift,
		Balance.PROJECTILE_MOTE_LIFE)
	tween.tween_property(mote, "modulate:a", 0.0, Balance.PROJECTILE_MOTE_LIFE)
	tween.chain().tween_callback(mote.queue_free)


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
	queue_free()


## Reached the end of its life without connecting. Fizzles rather than
## disappearing, so a miss is visible.
func _expire() -> void:
	Vfx.spark(global_position, Color(colour, 0.5), 3, _direction, 90.0)
	queue_free()


func _apply(enemy: Enemy) -> void:
	if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
		return
	if damage > 0.0:
		# The brand is read at impact rather than at the muzzle: a shot in flight
		# toward an elite that gets branded on the way should land the amplified
		# hit, and one aimed at a body whose mark expired mid-flight should not.
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
