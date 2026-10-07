class_name Tracks
extends Node2D

## **Footprints that stay a while** (2026-09-30). The second-rank juice the
## 2026-09-15 triage deferred - "persistent footprints" - built now the dust
## they sit beside exists. `Footfalls` already measures every body's stride; a
## stride leaves a scuff of dust that is gone in half a second, and this is what
## it leaves in the earth: a soft dark print, left and right in turn, that holds
## and then fades over `Balance.TRACK_LIFE`. A column that walked a road leaves
## the road trodden, and a Warden can read which way something went.
##
## **A look and nothing else.** Nothing reads a print, it rolls no die and
## changes no number, and it is laid only where `Footfalls` already lays dust -
## in view, moving, and never at the lowest effects setting.
##
## **Built the way the ground blood is** (`BloodField`): prints are records in
## chunks of `CHUNK`, each chunk one canvas and one triangle array, rebuilt only
## when a print is laid into it, and the fade is the shader's off one clock
## uniform - so a thousand prints fading costs a uniform a frame, not a rebuild.
## A chunk whose newest print has faded is freed whole, and the oldest chunk
## gives way past `Balance.TRACK_MAX`.
##
## **What a foot carries, and what it was standing in** (owner, 2026-10-07:
## *"All characters should leave footprints that are affected by influential
## factors to make them last longer etc or have vfx if affected by elements
## such as burn or wet or possibility for residue footstep from electricity
## remaining in a footstep that can provide an aftershock that can also chain
## again potentially, but is a rarer effect for footsteps, and walking on
## dirt/unpathed ground affects footsteps when returning to pathed ground, and
## vice versa"*). A print lasts longer under a heavier body, in soft earth
## rather than on the road, and in the wet; a foot that comes off one ground
## onto another carries the first for a few steps, so dirt is walked onto the
## road and road dust out over the dirt; a burning body leaves scorched
## prints that smoulder, a wet one dark prints that hold, and a body the
## lightning has just been through now and then leaves a print that is still
## charged. All of it a look - but for that last, which is the one print in
## the game that bites back: the next road body to step on it takes a
## small shock, and the shock may jump once more. The board's own lightning,
## lingering; rare by `TRACK_SHOCK_CHANCE`, capped by `TRACK_SHOCK_MAX`, and
## the host's alone.

const CHUNK: int = 48
## How often a chunk that was laid into repaints.
const REDRAW_HZ: float = 6.0
const SHADER_PATH: String = "res://scripts/shaders/track_ground.gdshader"
## Rim points of a print.
const RIM: int = 8
## What a body's own state may lend its print (`footprint_mark`).
const MARK_BURN: int = 1
const MARK_WET: int = 2
const MARK_CHARGED: int = 4

## What colour the earth is at a point, and how deep water stands on it.
## Handed in, so this file knows nothing about where it is.
var ground: Callable = Callable()
var water: Callable = Callable()
## The road bodies near a point, for a charged print's aftershock. Handed in;
## a scope with none hands in nothing and its charged prints only crackle.
var bodies_near: Callable = Callable()
## What a walker last stood on, and what it carries off it: id to
## `[under, carried, steps left]`.
var _carry: Dictionary = {}
## The charged prints still holding their shock.
var _charged: Array[Dictionary] = []
var _crackle_in: float = 0.0
## The prints' own dice: whether one keeps its charge and whether a shock
## jumps. Never the run's stream, which a print must not move.
var _dice: RandomNumberGenerator = RandomNumberGenerator.new()

var _clock: float = 0.0
var _material: ShaderMaterial = null
var _chunks: Array[TrackChunk] = []
var _since_redraw: float = 1.0 / REDRAW_HZ


## One canvas of prints.
class TrackChunk extends Node2D:
	var prints: Array[Dictionary] = []
	var last_end: float = 0.0
	var dirty: bool = false

	func _draw() -> void:
		var started: int = Time.get_ticks_usec()
		_draw_measured()
		FrameProfile.add(&"tracks", started)

	func _draw_measured() -> void:
		var points := PackedVector2Array()
		var colours := PackedColorArray()
		var uvs := PackedVector2Array()
		var indices := PackedInt32Array()
		for one: Dictionary in prints:
			Tracks.lay_print(points, colours, uvs, indices, to_local(one["at"] as Vector2),
				one["way"] as Vector2, float(one["w"]), float(one["l"]),
				one["colour"] as Color, float(one["born"]), float(one["life"]))
		if indices.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
			indices, points, colours, uvs)


func _ready() -> void:
	texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	add_to_group(Graphics.FILTER_GROUP)
	if ResourceLoader.exists(SHADER_PATH):
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
		_material.set_shader_parameter("hold", Balance.TRACK_HOLD)
		_material.set_shader_parameter("clock", _clock)
		material = _material
	_dice.seed = absi(hash("tracks:%d" % RunState.run_seed))
	set_process(false)


## One stride's print, beside the line the body walks on. `side` is -1 or 1,
## the foot; `size` the body's contact size; `weight` how much of the effects
## budget there is (`Footfalls` works it out once a pass).
func press(at: Vector2, way: Vector2, size: float, mass: float, side: float,
		weight: float, marks: int = 0, walker: int = 0) -> void:
	if weight <= Balance.TRACK_WEIGHT_FLOOR or size <= 0.0:
		return
	if water.is_valid() and float(water.call(at)) > 0.0:
		return
	var along: Vector2 = way.normalized() if way.length_squared() > 0.0001 else Vector2.DOWN
	var across := Vector2(-along.y, along.x)
	var width: float = size * Balance.TRACK_SIZE * sqrt(clampf(mass, 0.4, 3.0))
	var earth := Color(0.30, 0.24, 0.18)
	if ground.is_valid():
		var found: Variant = ground.call(at)
		if found is Color:
			earth = found as Color
	var ink: Color = earth.darkened(Balance.TRACK_DARKEN)
	# What the foot carries off the last ground it stood on.
	var carried: float = 0.0
	var mud: Color = ink
	if walker != 0:
		var memory: Array = _carry.get(walker, []) as Array
		if memory.size() == 3:
			var under: Color = memory[0] as Color
			var steps: int = int(memory[2])
			if _gap(under, earth) > Balance.TRACK_CARRY_GAP:
				memory[1] = under
				steps = Balance.TRACK_CARRY_STEPS
			if steps > 0:
				carried = float(steps) / float(Balance.TRACK_CARRY_STEPS)
				mud = (memory[1] as Color).darkened(Balance.TRACK_DARKEN * 0.6)
				steps -= 1
			memory[0] = earth
			memory[2] = steps
		else:
			if _carry.size() > Balance.TRACK_CARRY_WALKERS:
				_carry.clear()
			_carry[walker] = [earth, earth, 0]
	ink = ink.lerp(mud, carried * Balance.TRACK_CARRY_SHARE)
	var life: float = Balance.TRACK_LIFE * life_scale(mass, earth, marks, carried)
	var strength: float = Balance.TRACK_ALPHA * clampf(weight, 0.0, 1.0) * clampf(mass, 0.6, 1.4)
	if marks & MARK_WET:
		ink = ink.darkened(Balance.TRACK_WET_DARKEN)
		strength = minf(strength * 1.2, 0.9)
	if marks & MARK_BURN:
		ink = ink.lerp(Color(0.07, 0.045, 0.03), Balance.TRACK_BURN_CHAR)
		strength = minf(strength * 1.25, 0.92)
	if marks & MARK_CHARGED:
		ink = ink.lerp(Color(0.55, 0.72, 1.0), 0.3)
	var print_colour := Color(ink, strength)
	var chunk: TrackChunk = _chunks.back() if not _chunks.is_empty() else null
	if chunk == null or chunk.prints.size() >= CHUNK:
		chunk = TrackChunk.new()
		chunk.use_parent_material = true
		add_child(chunk)
		_chunks.append(chunk)
		while _chunks.size() * CHUNK > Balance.TRACK_MAX and _chunks.size() > 1:
			var oldest: TrackChunk = _chunks.pop_front()
			oldest.queue_free()
	chunk.prints.append({
		"at": at + across * side * size * Balance.TRACK_SPREAD,
		"way": along, "w": width, "l": width * Balance.TRACK_LENGTH,
		"colour": print_colour, "born": _clock, "life": life,
	})
	chunk.last_end = maxf(chunk.last_end, _clock + life)
	_juice(at + across * side * size * Balance.TRACK_SPREAD, marks, width)
	if marks & MARK_CHARGED and Coop.is_guest() == false \
			and _charged.size() < Balance.TRACK_SHOCK_MAX \
			and _dice.randf() < Balance.TRACK_SHOCK_CHANCE:
		_charged.append({"at": at + across * side * size * Balance.TRACK_SPREAD,
			"until": _clock + Balance.TRACK_SHOCK_SECONDS, "walker": walker})
	chunk.dirty = true
	set_process(true)
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		_repaint()


## **How long a print holds**, as a share of `TRACK_LIFE`: a heavier body
## presses deeper, soft earth holds a print the road does not, the wet holds
## it longest, and scorch stays a while. Mud carried onto the road is the
## soft earth's own. Pure, so the gate can ask it.
static func life_scale(mass: float, earth: Color, marks: int, carried: float) -> float:
	var heavy: float = lerpf(1.0, Balance.TRACK_HEAVY_LIFE, clampf((mass - 1.0) / 2.0, 0.0, 1.0))
	var wet: float = Balance.TRACK_WET_LIFE if marks & MARK_WET else 1.0
	var burn: float = Balance.TRACK_BURN_LIFE if marks & MARK_BURN else 1.0
	var rain: float = 1.0 + clampf(RunState.rain_intensity, 0.0, 1.0) * (Balance.TRACK_WET_LIFE - 1.0) * 0.5
	return heavy * maxf(wet, rain) * burn * (1.0 + carried * 0.3)


## How far apart two grounds are, as colours: enough to call it another ground.
static func _gap(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## What an element does as a print is laid: a scorched one smokes and spits
## an ember, a wet one splashes in the rain, a charged one crackles. Records on
## the ink, never nodes, and none at all with the effects turned down.
func _juice(at: Vector2, marks: int, width: float) -> void:
	if marks == 0 or Graphics.particle_scale() <= 0.0:
		return
	if marks & MARK_BURN:
		Vfx.mote(at, Vector2(randf_range(-6.0, 6.0), -22.0), Color(1.0, 0.55, 0.2, 0.9), 2.5, 0.9)
		Vfx.dust(at, Color(0.18, 0.15, 0.13), 2, width * 0.8)
	if marks & MARK_WET and RunState.rain_intensity > 0.2:
		Vfx.ring(at, width * 0.9, Color(0.75, 0.85, 0.95, 0.35), 0.35, 1.5)
	if marks & MARK_CHARGED:
		Vfx.spark(at, Color(0.6, 0.8, 1.0), 3, Vector2.UP, 120.0)


## **The charged prints crackle, and the next road body to step on one takes
## the shock** (2026-10-07). Small and rare by design: a share of what a strike
## deals a road body, scaled by the act as the strike is, and it may jump once
## to the nearest other body. The host's alone; a guest's prints only crackle,
## and only its own.
func _tick_charged(delta: float) -> void:
	if _charged.is_empty():
		return
	_crackle_in -= delta
	var crackle: bool = _crackle_in <= 0.0
	if crackle:
		_crackle_in = Balance.TRACK_SHOCK_CRACKLE
	for index: int in range(_charged.size() - 1, -1, -1):
		var one: Dictionary = _charged[index]
		if float(one["until"]) <= _clock:
			_charged.remove_at(index)
			continue
		var spot: Vector2 = one["at"] as Vector2
		if crackle and Graphics.particle_scale() > 0.0:
			Vfx.spark(spot, Color(0.65, 0.85, 1.0), 2, Vector2.UP, 90.0)
		if not bodies_near.is_valid():
			continue
		var stepped: Enemy = null
		for found: Variant in bodies_near.call(spot, Balance.TRACK_SHOCK_RADIUS):
			var body := found as Enemy
			if body != null and is_instance_valid(body) and not body.is_dying() \
					and body.get_instance_id() != int(one["walker"]):
				stepped = body
				break
		if stepped == null:
			continue
		_charged.remove_at(index)
		var act_scale: float = Balance.WAVE_ACT_HP_SCALE[clampi(RunState.act - 1, 0,
			Balance.WAVE_ACT_HP_SCALE.size() - 1)]
		var shock: float = Balance.LIGHTNING_ENEMY_DAMAGE * Balance.TRACK_SHOCK_SHARE * act_scale
		_discharge(spot, stepped, shock, true)


## One shock into a body, and once in a while one more jump.
func _discharge(from: Vector2, body: Enemy, shock: float, may_jump: bool) -> void:
	if body == null or not is_instance_valid(body):
		return
	var hit: Vector2 = body.global_position
	Vfx.beam(from, hit, 3.0, Color(0.6, 0.82, 1.0, 0.9))
	Vfx.spark(hit, Color(0.7, 0.88, 1.0), 6, Vector2.UP, 200.0)
	DamageLedger.credit_as(DamageLedger.OTHER)
	body.take_damage(shock * body.shock_scale(), from, 0.0)
	if not may_jump or _dice.randf() >= Balance.TRACK_SHOCK_CHAIN_CHANCE or not bodies_near.is_valid():
		return
	var next: Enemy = null
	var best: float = INF
	for found: Variant in bodies_near.call(hit, Balance.TRACK_SHOCK_CHAIN_REACH):
		var other := found as Enemy
		if other == null or other == body or not is_instance_valid(other) or other.is_dying():
			continue
		var away: float = other.global_position.distance_squared_to(hit)
		if away < best:
			best = away
			next = other
	if next != null:
		_discharge(hit, next, shock * Balance.TRACK_SHOCK_CHAIN_SHARE, false)


## How many charged prints are holding a shock. For the gate.
func charged_count() -> int:
	return _charged.size()


## A soft oval: a solid middle, a feather, and a rim at nothing. The fade is the
## shader's, from the birth and life each vertex carries in its UV.
static func lay_print(points: PackedVector2Array, colours: PackedColorArray,
		uvs: PackedVector2Array, indices: PackedInt32Array, at: Vector2, along: Vector2,
		width: float, length: float, colour: Color, born: float, life: float) -> void:
	var across := Vector2(-along.y, along.x)
	var base: int = points.size()
	var carried := Vector2(born, life)
	points.append(at)
	colours.append(colour)
	uvs.append(carried)
	for ring: int in 2:
		var reach: float = 0.62 if ring == 0 else 1.0
		var shade := Color(colour, colour.a if ring == 0 else 0.0)
		for index: int in RIM:
			var angle: float = TAU * float(index) / float(RIM)
			var offset: Vector2 = along * cos(angle) * length * 0.5 * reach \
				+ across * sin(angle) * width * 0.5 * reach
			points.append(at + offset)
			colours.append(shade)
			uvs.append(carried)
	for index: int in RIM:
		var inner: int = base + 1 + index
		var inner_next: int = base + 1 + (index + 1) % RIM
		var outer: int = base + 1 + RIM + index
		var outer_next: int = base + 1 + RIM + (index + 1) % RIM
		indices.append_array([base, inner, inner_next])
		indices.append_array([inner, outer, outer_next])
		indices.append_array([inner, outer_next, inner_next])


func _repaint() -> void:
	for chunk: TrackChunk in _chunks:
		if chunk.dirty:
			chunk.dirty = false
			chunk.queue_redraw()


## How many prints are still showing. For the gate.
func showing() -> int:
	var count: int = 0
	for chunk: TrackChunk in _chunks:
		for one: Dictionary in chunk.prints:
			if _clock - float(one["born"]) < float(one["life"]):
				count += 1
	return count


## How many canvases the prints are spread over. For the gate.
func chunk_count() -> int:
	return _chunks.size()


func clock() -> float:
	return _clock


func _process(delta: float) -> void:
	_clock += delta
	if _material != null:
		_material.set_shader_parameter("clock", _clock)
	# A chunk whose newest print has faded is freed whole.
	while not _chunks.is_empty() and _chunks[0].last_end <= _clock:
		var spent: TrackChunk = _chunks.pop_front()
		spent.queue_free()
	_tick_charged(delta)
	if _chunks.is_empty() and _charged.is_empty():
		set_process(false)
		return
	_since_redraw += delta
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		_repaint()
