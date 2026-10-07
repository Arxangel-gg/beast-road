class_name Tornado
extends Node2D

## A funnel that walks the field: it flattens what it passes over and batters
## what stands near.
##
## Owner brief, 2026-09-14. Raised by the earth's wrath, or by the storm towers
## themselves once they have run long enough (`RunState.gale`). It is born at
## the field's edge, heads for a point inside and wanders as it goes, and dies
## after its seconds are spent or once it has walked off the far side. In its
## wake - `TORNADO_WAKE` - a tower is torn down and a body is thrown and hurt
## hard; out to `TORNADO_AOE` everything alive is hurt a little and pushed.
##
## Drawn rather than painted: a stack of turning ellipses narrowing to the
## ground, dust at the foot, debris climbing it. Nothing here needs a shader,
## which is why it can be looked at headless. The host moves it and hurts with
## it; a guest is told where it is (`coop_tornado_moved`) and draws it there.
##
## **One funnel, one way round, grown rather than placed** (owner, 2026-10-07:
## *"Tornadoes have a V shaped frame VFX that is not in line with the rest of
## the body ... and has an offset downwards ... and even potentially spin the
## other way ... it should spawn better and grow into the full tornado"*). The
## V was the forged debris sheet, played on the ink centred on the funnel's
## *feet*, so its throat hung a third of the column below the ground; and it
## was a fresh take every quarter second, half of them turning the other way,
## flipped at random besides. The sheet is drawn here now, as part of the
## funnel: its throat on the ground, its mouth at the column's own height and
## width, leaning with it, and one take that turns the way the column turns.
## Which way that is is the funnel's own (`turning`), decided where it was
## born so both machines agree. And it is born small - a dust devil at the
## ground that rises and widens into the column over `TORNADO_BIRTH_SECONDS`
## - and it dies by lifting and thinning rather than by fading in place.
## Every one of those is a look: the blow, the pull and the wake are the
## funnel's from its first frame to its last, exactly as before.

const GROUP: StringName = &"tornadoes"

var at: Vector2 = Vector2.ZERO
var heading: Vector2 = Vector2.RIGHT
var seconds_left: float = 0.0
var field: Battlefield = null
var _rng: RandomNumberGenerator = null
var _mirror: bool = false
var _spin: float = 0.0
var _sync_timer: float = 0.0
var _dust_timer: float = 0.0
var _howl_timer: float = 0.0
var _debris: CPUParticles2D = null
var _target: Vector2 = Vector2.ZERO
## For the gate: what it has torn down and hurt.
var towers_felled: int = 0
## How far it wanders off its line each second. A seam for the gate, which
## needs a funnel that walks over the tower it was aimed at.
var wander: float = Balance.TORNADO_WANDER
## A fire whirl: seconds left carrying fire, after crossing a wildfire.
var _fire_left: float = 0.0
var _ignite_timer: float = 0.0
## The pull, the lift and the throw (2026-09-30). The host's only.
var _catch: TornadoCatch = null
## **Which way it turns**, 1 or -1: the column, the streaks, the debris and
## what it carries all go round the same way. Decided from where it was born
## and where it is going, so a guest told the same two points turns it the
## same way without a packet.
var turning: float = 1.0
## Seconds since it was born, and since it began to come apart (-1 until it
## does). Both are the picture's only.
var _age: float = 0.0
var _dying: float = -1.0
## The forged debris, drawn as part of the funnel.
const DEBRIS_SHEET: String = "funnel_debris"
var _sheet: Texture2D = null
var _sheet_cells: int = 1
## The colour of the ground it is standing on, which is what it picks up.
var _earth: Color = Color(0.42, 0.36, 0.28)
var _earth_timer: float = 0.0


func _ready() -> void:
	name = "Tornado"
	add_to_group(GROUP)
	z_as_relative = false
	z_index = Balance.TORNADO_Z
	position = at
	_rng = RunState.rng("wrath")
	_mirror = Coop.is_guest()
	turning = 1.0 if posmod(hash(Vector4i(int(round(at.x)), int(round(at.y)),
		int(round(_target.x)), int(round(_target.y)))), 2) == 0 else -1.0
	_load_sheet()
	_build_debris()
	_read_the_earth()
	_born()
	EventBus.coop_tornado_moved.connect(_on_moved_elsewhere)
	if not _mirror and field != null:
		_catch = TornadoCatch.new()
		_catch.funnel = self
		_catch.field = field
		add_child(_catch)


func _build_debris() -> void:
	_debris = CPUParticles2D.new()
	_debris.name = "Debris"
	_debris.texture = Flame.dot_texture()
	_debris.amount = Graphics.scaled(48, Graphics.particle_scale())
	_debris.lifetime = 1.4
	_debris.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_debris.emission_sphere_radius = Balance.TORNADO_WAKE * 0.6
	_debris.direction = Vector2.UP
	_debris.spread = 40.0
	_debris.initial_velocity_min = 120.0
	_debris.initial_velocity_max = 320.0
	_debris.gravity = Vector2(0.0, 90.0)
	_debris.scale_amount_min = 1.2
	_debris.scale_amount_max = 3.2
	_debris.color = Color(0.36, 0.3, 0.24, 0.85)
	_debris.local_coords = false
	add_child(_debris)


func _process_measured(delta: float) -> void:
	_age += delta
	# It turns faster as it grows into itself, and slows as it comes apart.
	_spin += delta * Balance.TORNADO_SPIN * turning * lerpf(0.35, 1.0, _grown()) \
		* (1.0 - _dissolve() * 0.6)
	queue_redraw()
	if _dying >= 0.0:
		_dying += delta
		if _dying >= Balance.TORNADO_DEATH_SECONDS:
			queue_free()
		return
	_earth_timer -= delta
	if _earth_timer <= 0.0:
		_earth_timer = 0.5
		_read_the_earth()
	if _mirror:
		# A guest's copy keeps the same clock and the same edge, or it would
		# stand on the field for the rest of the run after the host's had gone.
		seconds_left -= delta
		var edge: float = BattleGrid.HALF_EXTENT + Balance.TREELINE_RING
		if seconds_left <= 0.0 or absf(at.x) > edge or absf(at.y) > edge:
			_die()
		return
	seconds_left -= delta
	# Wandering toward its point, then past it: the heading turns a little
	# every frame, so the path is a curve nobody can stand in the way of by
	# reading a straight line.
	var wanted: Vector2 = (_target - at).normalized() if at.distance_to(_target) > 40.0 else heading
	heading = (heading.lerp(wanted, minf(delta * 1.4, 1.0)).rotated(
		_rng.randf_range(-1.0, 1.0) * wander * delta)
		+ RunState.wind * Balance.TORNADO_WIND_PUSH * delta).normalized()
	at += heading * Balance.TORNADO_SPEED * delta
	position = at
	_tick_fire(delta)
	_hurt(delta)
	_dust_timer -= delta
	if _dust_timer <= 0.0:
		_dust_timer = 0.28
		Vfx.dust(at, _earth, 5, Balance.TORNADO_WAKE)
	_howl_timer -= delta
	if _howl_timer <= 0.0:
		_howl_timer = 2.4
		Sfx.play_at("sfx_tornado", at, -4.0)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = Balance.SKY_SYNC_INTERVAL
		if Coop.is_host() and Coop.partner_present():
			EventBus.tornado_moved.emit(at, burning())
	var reach: float = BattleGrid.HALF_EXTENT + Balance.TREELINE_RING
	if seconds_left <= 0.0 or absf(at.x) > reach or absf(at.y) > reach:
		_die()


## Where it is heading first. Set by the sky before it enters the tree.
func aim_at(target: Vector2) -> void:
	_target = target
	heading = (target - at).normalized()


## Whether it carries fire right now.
func burning() -> bool:
	return _fire_left > 0.0


## A funnel through a fire carries it (ChatGPT notes, 2026-09-14: "Wildfire +
## Tornado -> Fire Tornado"): for a while after crossing burning ground it
## lights the brush in its wake and burns what it touches. It re-arms only
## from a fresh crossing - the fires it lit itself fall behind it faster than
## they can keep it lit - and the wildfire's own bounds hold the rest.
func _tick_fire(delta: float) -> void:
	var fire: Wildfire = field.wildfire() if field != null else null
	if fire == null:
		return
	if _fire_left <= 0.0 and fire.heat_at(at, Balance.TORNADO_AOE) > 0.0:
		_fire_left = Balance.TORNADO_FIRE_SECONDS
		Vfx.flash_at(at, Color(1.0, 0.6, 0.25), Balance.TORNADO_AOE * 0.5)
		Vfx.spark(at, Color(1.0, 0.55, 0.2), 24, Vector2.UP, 360.0)
		if _debris != null:
			_debris.color = Color(1.0, 0.5, 0.18, 0.9)
	if _fire_left <= 0.0:
		return
	_fire_left -= delta
	if _fire_left <= 0.0 and _debris != null:
		_debris.color = Color(0.36, 0.3, 0.24, 0.85)
	_ignite_timer -= delta
	if _ignite_timer <= 0.0:
		_ignite_timer = Balance.TORNADO_FIRE_IGNITE_TICK
		var behind: Vector2 = at - heading * Balance.TORNADO_WAKE \
			+ Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * Balance.TORNADO_WAKE
		fire.ignite_near(behind, Balance.TORNADO_WAKE * 1.5, 1.0)


func _hurt(delta: float) -> void:
	if field == null:
		return
	var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
		Balance.WAVE_ACT_HP_SCALE.size() - 1)]
	var fire_more: float = Balance.TORNADO_FIRE_DPS if burning() else 0.0
	# Towers in the wake are torn down. Hard, and per second rather than at
	# once, so a funnel that clips a tower scars it and one that sits on it
	# breaks it.
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower := node as Tower
		if tower == null or not is_instance_valid(tower) or not tower.is_vulnerable():
			continue
		if tower.global_position.distance_to(at) <= Balance.TORNADO_WAKE:
			var was: bool = tower.is_vulnerable()
			tower.hurt(Balance.TORNADO_TOWER_DPS * delta, at)
			if was and not tower.is_vulnerable():
				towers_felled += 1
	for enemy: Enemy in field.enemies_near(at, Balance.TORNADO_AOE):
		# What the funnel is carrying it hurts in the carrying.
		if _catch != null and _catch.carries(enemy):
			continue
		var away: float = enemy.global_position.distance_to(at)
		var inside: bool = away <= Balance.TORNADO_WAKE
		var amount: float = ((Balance.TORNADO_WAKE_DPS if inside else Balance.TORNADO_AOE_DPS) + fire_more) \
			* act_scale * delta
		DamageLedger.credit_as(DamageLedger.EARTH)
		enemy.take_damage(amount, at, 0.0)
	var hero_pool: float = 100.0
	if field.hero != null and field.hero.health != null:
		hero_pool = field.hero.health.max_hp
	# The ones it is carrying are passed over - they are hurt in the carrying -
	# and it no longer shoves outward: the funnel pulls (`TornadoCatch`).
	var carried: Dictionary = {}
	if _catch != null:
		for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
			if _catch.carries(node):
				carried[node.get_instance_id()] = true
	EarthHand.open()
	EnemyGroundStrike.strike_the_players(get_tree(), hero_pool * Balance.TORNADO_HERO_SHARE_PER_SECOND * delta,
		"", func(where: Vector2) -> bool: return where.distance_to(at) <= Balance.TORNADO_AOE,
		0.0, at, carried)
	EarthHand.close()
	var animals: Wildlife = field.wildlife()
	if animals != null:
		animals.wound_within(at, Balance.TORNADO_AOE, Balance.TORNADO_WILDLIFE_DPS * delta, false)
		animals.scare_from(at, Balance.TORNADO_AOE * 1.5)


func _on_moved_elsewhere(where: Vector2, is_burning: bool) -> void:
	if _mirror:
		at = where
		position = at
		_fire_left = Balance.TORNADO_FIRE_SECONDS if is_burning else 0.0
		if _debris != null:
			_debris.color = Color(1.0, 0.5, 0.18, 0.9) if is_burning else Color(0.36, 0.3, 0.24, 0.85)


func _die() -> void:
	if _dying >= 0.0:
		return
	# Everybody it was carrying is put down before the funnel fades.
	if _catch != null and is_instance_valid(_catch):
		_catch.queue_free()
		_catch = null
	Vfx.dust(at, _earth, 14, Balance.TORNADO_AOE * 0.6)
	Vfx.ring(at, Balance.TORNADO_AOE * 0.6, Color(_earth.r, _earth.g, _earth.b, 0.28))
	# Where it fell apart the air stays charged for a while.
	if not _mirror and field != null and field.zones() != null:
		field.zones().open("storm_core", at, Balance.ZONE_STORM_RADIUS)
	if _debris != null:
		_debris.emitting = false
	# It lifts and thins over `TORNADO_DEATH_SECONDS` and is freed by its own
	# clock (`_process_measured`); nothing it does after this is a blow.
	_dying = 0.0


## The funnel: a column of dust that fades into the air at every edge, with
## debris winding up it and a pool of grit at its foot.
func _draw_measured() -> void:
	_draw_the_foot()
	_draw_the_column()
	_draw_the_puffs()
	_draw_the_debris()
	_draw_the_chunks()
	_draw_the_streaks()


## **How far it has grown into itself**, 0 at its birth and 1 once it stands.
func _grown() -> float:
	return smoothstep(0.0, 1.0, _age / maxf(Balance.TORNADO_BIRTH_SECONDS, 0.01))


## **How far it has come apart**, 0 standing and 1 gone.
func _dissolve() -> float:
	if _dying < 0.0:
		return 0.0
	return clampf(_dying / maxf(Balance.TORNADO_DEATH_SECONDS, 0.01), 0.0, 1.0)


## How tall the column stands right now: it rises out of the ground as it is
## born and lifts away as it dies.
func _height() -> float:
	return Balance.TORNADO_HEIGHT * lerpf(0.12, 1.0, _grown()) * (1.0 + _dissolve() * 0.35)


## How solid the whole of it is drawn.
func _presence() -> float:
	return lerpf(0.25, 1.0, sqrt(_grown())) * (1.0 - _dissolve())


## The forged debris, on the funnel's own clock and in its own shape: the
## sheet's throat on the ground and its mouth at the column's top, as wide as
## the column is there, leaning with it. One take, turning the funnel's way.
func _draw_the_debris() -> void:
	if _sheet == null or _sheet_cells <= 0:
		return
	var tall: float = float(_sheet.get_height())
	var frame: int = int(_age * Balance.VFX_FORGE_FRAME_RATE) % _sheet_cells
	var height: float = _height()
	# The sheet's cone runs from its throat at FUNNEL_THROAT of the cell down
	# from its top to its mouth at FUNNEL_MOUTH, and is FUNNEL_MOUTH_WIDE of the
	# cell across at the mouth (`effects/funnel_debris.py`).
	var cell_tall: float = height / (Balance.TORNADO_SHEET_THROAT - Balance.TORNADO_SHEET_MOUTH)
	var cell_wide: float = _reach_at(1.0) * 2.0 / Balance.TORNADO_SHEET_MOUTH_WIDE
	var top: float = -height - Balance.TORNADO_SHEET_MOUTH * cell_tall
	var shade: Color = Color(1.0, 0.62, 0.3) if burning() else _earth.lightened(0.2)
	# **In bands, thinning upward.** Drawn whole, its mouth was a ring of the
	# sheet's biggest pieces at the top of a column whose dust has thinned to
	# nothing there - a lid, and the very V that was reported. What is caught
	# low, where the funnel is packed, is what reads as debris.
	var bands: int = Balance.TORNADO_SHEET_BANDS
	var left: float = _lean_at(0.5) - cell_wide * 0.5
	for band: int in bands:
		var from: float = float(band) / float(bands)
		var to: float = float(band + 1) / float(bands)
		# The band's share of the way from the mouth (0) to the throat (1).
		var middle: float = lerpf(Balance.TORNADO_SHEET_MOUTH, Balance.TORNADO_SHEET_THROAT,
			(from + to) * 0.5)
		var low: float = inverse_lerp(Balance.TORNADO_SHEET_MOUTH, Balance.TORNADO_SHEET_THROAT, middle)
		var tint: Color = shade
		tint.a = Balance.TORNADO_SHEET_ALPHA * _presence() * pow(clampf(low, 0.0, 1.0), 1.6)
		if tint.a <= 0.01:
			continue
		draw_texture_rect_region(_sheet,
			Rect2(Vector2(left, top + from * cell_tall), Vector2(cell_wide, (to - from) * cell_tall)),
			Rect2(Vector2(float(frame) * tall, from * tall), Vector2(tall, (to - from) * tall)), tint)


## **Dust going round**: soft puffs on rings up the column, each turning with
## it, bigger and thinner the higher they ride, lighter as they come round the
## near side. What makes the column read as air full of dirt rather than as a
## cone of paint.
func _draw_the_puffs() -> void:
	var dot: Texture2D = Flame.dot_texture()
	var rings: int = Balance.TORNADO_PUFF_RINGS
	var around: int = Balance.TORNADO_PUFFS_PER_RING
	var presence: float = _presence()
	var lit: bool = burning()
	for ring: int in rings:
		var t: float = (float(ring) + 0.5) / float(rings)
		var reach: float = _reach_at(t)
		var height: float = _height()
		for j: int in around:
			var jitter: float = fposmod(float(ring * 7 + j) * 0.6180339, 1.0)
			var angle: float = TAU * (float(j) + jitter * 0.6) / float(around) \
				+ _spin * lerpf(1.3, 0.7, t) + t * 3.0
			var facing: float = sin(angle) * 0.5 + 0.5
			var spot: Vector2 = Vector2(_lean_at(t) + cos(angle) * reach * 0.82,
				-height * t + sin(angle) * reach * 0.2)
			var size: float = lerpf(Balance.TORNADO_PUFF_SIZE.x, Balance.TORNADO_PUFF_SIZE.y, t) \
				* (0.75 + jitter * 0.5)
			var colour: Color = Color(1.0, 0.55, 0.22) if lit else _earth.lightened(facing * 0.25)
			colour.a = (0.12 + 0.2 * facing) * pow(1.0 - t, 0.7) * presence
			draw_texture_rect(dot, Rect2(spot - Vector2(size, size * 0.7) * 0.5,
				Vector2(size, size * 0.7)), false, colour)


## **What it has picked up**: chunks of earth and the odd leaf, climbing the
## funnel as they go round it and spat out at the top. One mesh.
func _draw_the_chunks() -> void:
	var count: int = Balance.TORNADO_CHUNKS
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var presence: float = _presence()
	var height: float = _height()
	for i: int in count:
		var jitter: float = fposmod(float(i) * 0.6180339, 1.0)
		var climb: float = lerpf(0.12, 0.3, fposmod(float(i) * 0.3719, 1.0))
		var t: float = fposmod(jitter + _age * climb, 1.0)
		var angle: float = float(i) * 2.399 + _spin * lerpf(1.7, 0.9, t)
		var reach: float = _reach_at(t)
		var facing: float = sin(angle) * 0.5 + 0.5
		var spot: Vector2 = Vector2(_lean_at(t) + cos(angle) * reach * 0.9,
			-height * t + sin(angle) * reach * 0.22)
		var size: float = lerpf(2.5, 6.5, fposmod(float(i) * 0.7713, 1.0)) * lerpf(1.0, 1.4, facing)
		var leaf: bool = i % 4 == 0
		var colour: Color = Color(0.32, 0.5, 0.2) if leaf else _earth.darkened(0.45)
		colour = colour.lightened(facing * 0.3)
		colour.a = (0.35 + 0.6 * facing) * sin(t * PI) * presence
		var turn: float = angle * 1.7 + float(i)
		var first: int = points.size()
		for corner: int in 4:
			points.append(spot + Vector2.from_angle(turn + float(corner) * PI * 0.5) * size)
			colours.append(colour)
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## The take that turns the way this funnel does. Even takes of the sheet turn
## one way and odd takes the other (`effects/funnel_debris.py`).
func _load_sheet() -> void:
	var path: String = Vfx.FORGE_ART_FORMAT % DEBRIS_SHEET if turning > 0.0 \
		else Vfx.FORGE_TAKE_FORMAT % [DEBRIS_SHEET, 1]
	if not ResourceLoader.exists(path):
		path = Vfx.FORGE_ART_FORMAT % DEBRIS_SHEET
	if not ResourceLoader.exists(path):
		return
	_sheet = load(path) as Texture2D
	if _sheet != null:
		_sheet_cells = maxi(_sheet.get_width() / maxi(_sheet.get_height(), 1), 1)


func _read_the_earth() -> void:
	if field != null and field.has_method("ground_colour"):
		var ground: Color = field.ground_colour(at)
		# Lifted a little: dust in the air catches light the earth does not.
		_earth = ground.lerp(Color(0.62, 0.56, 0.46), 0.35)
		_earth.a = 1.0


## **The birth**: the ground gives up a ring of grit where it rises, felt a
## little by whoever is near. A look; the blow is the funnel's from now.
func _born() -> void:
	Vfx.dust(at, _earth, 10, Balance.TORNADO_WAKE * 1.4)
	Vfx.ring(at, Balance.TORNADO_AOE * 0.7, Color(_earth.r, _earth.g, _earth.b, 0.55), 0.6, 6.0)
	Vfx.spark(at, _earth.lightened(0.3), 16, Vector2.UP, 220.0)
	EventBus.camera_impact.emit(at, Balance.TORNADO_BIRTH_IMPACT)


## How far out the funnel reaches at a height, and how far the column leans
## there. One function so the column, the streaks and the foot cannot disagree
## about where the funnel is.
func _reach_at(t: float) -> float:
	return lerpf(Balance.TORNADO_WAKE * 0.5, Balance.TORNADO_AOE * 0.9, t) \
		* lerpf(0.4, 1.0, _grown()) * (1.0 + _dissolve() * 0.5)


func _lean_at(t: float) -> float:
	return sin(_spin * 0.7 + t * 4.0) * _reach_at(t) * 0.18


## The dust of the funnel at a height and a place across it (-1 to 1).
func _dust_at(t: float, across: float) -> Color:
	# Dense through the middle, nothing at the silhouette: the shape has no
	# edge, which is the whole difference from a stack of flat ellipses.
	var solid: float = 1.0 - pow(absf(across), Balance.TORNADO_EDGE_FALLOFF)
	# Dense at the foot where the funnel is packed with what it has picked up,
	# thin at the top where it is only air. At 0.62 the first cut read as smoke
	# against dark ground rather than as a column of dirt.
	# To nothing at the top: a column that ends at a fifth of its density
	# ends in a line, and the line was half of the reported V.
	var alpha: float = lerpf(0.92, 0.0, pow(t, 1.3)) * clampf(solid, 0.0, 1.0) * _presence()
	if burning():
		# A fire whirl, lit from inside: hot and pale up the core, darker
		# toward the edges where there is only smoke.
		var heat: float = clampf(solid * 1.25, 0.0, 1.0)
		return Color(lerpf(0.55, 1.0, heat), lerpf(0.16, lerpf(0.5, 0.82, t), heat),
			lerpf(0.08, lerpf(0.1, 0.34, t), heat), alpha * 1.2)
	# Thin dust at the edge catches more light than the packed core does.
	var shade: float = lerpf(0.58, 0.19, clampf(solid, 0.0, 1.0)) + t * 0.16
	# The ground it stands on, in the dust it lifts.
	var dust: Color = Color(shade, shade * 0.93, shade * 0.82).lerp(
		_earth * (shade / 0.45), 0.35)
	return Color(dust.r, dust.g, dust.b, alpha)


func _draw_the_column() -> void:
	var rings: int = Balance.TORNADO_RINGS
	var columns: int = Balance.TORNADO_COLUMNS
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	for ring: int in rings:
		var t: float = float(ring) / float(rings - 1)
		var reach: float = _reach_at(t)
		var lean: float = _lean_at(t)
		var height: float = -_height() * t
		for column: int in columns:
			var across: float = lerpf(-1.0, 1.0, float(column) / float(columns - 1))
			# The rim of a ring sits a little lower than its middle: the far
			# side of a circle seen from above and slightly along.
			var dip: float = (1.0 - absf(across)) * reach * 0.2
			points.append(Vector2(lean + across * reach, height + dip))
			colours.append(_dust_at(t, across))
	var indices := PackedInt32Array()
	for ring: int in rings - 1:
		for column: int in columns - 1:
			var a: int = ring * columns + column
			indices.append_array([a, a + 1, a + columns,
				a + 1, a + columns + 1, a + columns])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## **Debris going round.** Six strands winding up the funnel, each tapering to
## nothing at both ends and fading as it passes behind the column, so the thing
## reads as turning. Built into one mesh rather than drawn strand by strand.
func _draw_the_streaks() -> void:
	var rings: int = Balance.TORNADO_RINGS
	var half: float = Balance.TORNADO_STREAK_WIDTH * 0.5
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var lit: bool = burning()
	for strand: int in Balance.TORNADO_STREAKS:
		var phase: float = TAU * float(strand) / float(Balance.TORNADO_STREAKS) + _spin * 1.6
		var first: int = points.size()
		for ring: int in rings:
			var t: float = float(ring) / float(rings - 1)
			var angle: float = phase + t * TAU * Balance.TORNADO_STREAK_TURNS
			var reach: float = _reach_at(t)
			var here := Vector2(_lean_at(t) + cos(angle) * reach * 0.86,
				-_height() * t + sin(angle) * reach * 0.2)
			points.append(here + Vector2(0.0, -half))
			points.append(here + Vector2(0.0, half))
			# Bright as it comes round the near side, gone behind the column,
			# and tapering away at the top and the foot.
			var facing: float = clampf(sin(angle) * 0.5 + 0.5, 0.0, 1.0)
			var ends: float = sin(t * PI)
			var alpha: float = facing * ends * lerpf(0.55, 0.22, t) * _presence()
			var grit: Color = Color(1.0, 0.72, 0.36, alpha * 1.4) if lit \
				else Color(0.74, 0.69, 0.58, alpha)
			colours.append(grit)
			colours.append(grit)
			if ring > 0:
				var a: int = first + (ring - 1) * 2
				indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## The grit at the foot: a pool that is thickest at its rim, where the funnel is
## throwing the ground outward, and clear in the middle where the funnel stands.
func _draw_the_foot() -> void:
	var steps: int = 20
	# Wider while it is being born - the dust devil it grows out of - and as
	# it comes apart, when what it was holding falls back to the ground.
	var reach: float = Balance.TORNADO_WAKE * (0.95 + sin(_spin * 2.1) * 0.06) \
		* (1.0 + (1.0 - _grown()) * 0.8 + _dissolve() * 0.9)
	var lit: bool = burning()
	var foot: float = clampf(lerpf(1.6, 1.0, _grown()) * (1.0 - _dissolve()), 0.0, 1.6)
	var middle: Color = Color(0.62, 0.26, 0.09, 0.42) if lit \
		else Color(_earth.r * 0.5, _earth.g * 0.5, _earth.b * 0.5, 0.36)
	var rim: Color = Color(0.9, 0.46, 0.16, 0.0) if lit else Color(_earth.r, _earth.g, _earth.b, 0.0)
	var edge: Color = Color(0.86, 0.42, 0.14, 0.5) if lit \
		else Color(_earth.r * 0.95, _earth.g * 0.95, _earth.b * 0.95, 0.44)
	middle.a *= foot
	edge.a = minf(edge.a * foot, 0.7)
	var points := PackedVector2Array([Vector2.ZERO])
	var colours := PackedColorArray([middle])
	for band: int in 2:
		for s: int in steps:
			var angle: float = TAU * float(s) / float(steps) + _spin * 0.4
			var out: float = reach * (0.66 if band == 0 else 1.0)
			points.append(Vector2(cos(angle), sin(angle) * 0.36) * out)
			colours.append(edge if band == 0 else rim)
	var indices := PackedInt32Array()
	for s: int in steps:
		var inner: int = 1 + s
		var next_inner: int = 1 + (s + 1) % steps
		indices.append_array([0, inner, next_inner])
		var outer: int = 1 + steps + s
		var next_outer: int = 1 + steps + (s + 1) % steps
		indices.append_array([inner, outer, next_inner, outer, next_outer, next_inner])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), indices, points, colours)


## `FrameProfile` bucket "d_tornado": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_tornado", started)


## `FrameProfile` bucket "p_tornado": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_tornado", started)
