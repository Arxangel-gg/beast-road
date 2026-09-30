class_name BloodField
extends Node2D

## Blood on the ground, drawn as a few canvases rather than one node per splat.
##
## A hit leaves a mark and the mark outlives the hit. That is most of what makes
## a fight read as having happened - the field remembers where the fighting was,
## and a player crossing their own last stand sees it.
##
## **A few nodes, many marks.** The obvious build is a `Polygon2D` per splat with
## a tween on its alpha, which is the idiom everywhere else in `Vfx` and is right
## for a handful of short-lived things. Blood is not a handful: a busy wave puts
## down hundreds, each would be a node in the tree with its own tween, and the
## cap in `Vfx._track` would start evicting live effects to make room for
## bloodstains. So marks are plain records painted by `_draw`.
##
## **And the fade is the shader's, as of 2026-09-25** (owner: "shader fade for
## ground blood"). Each vertex carries its mark's birth and life, `blood_ground`
## works out the fade and the drying from the field's own clock, and a mesh is
## rebuilt only when a mark is laid or leaves.
##
## **Chunks, as of 2026-09-30.** The owner asked for blood as Off, Low and High,
## High lasting until the party extracts and washed only by rain and flood. High
## keeps several times the marks, and one mesh for all of them meant rebuilding
## every one in GDScript whenever a droplet landed - which in a fight is always.
## Marks are laid into chunks of `CHUNK` now, each its own canvas item, so a new
## mark rebuilds the newest chunk and nothing else; the fade needs no rebuild at
## all. The cost of a long memory is a few more draw calls, not a slower fight.

## The most marks Low keeps. The oldest are dropped first. Generous enough that
## a long fight leaves a real trail, bounded so a whole act cannot accumulate
## into a slideshow.
const MAX_SPLATS: int = 140

## How many marks one canvas holds.
const CHUNK: int = 24

## How often a changed chunk repaints.
const REDRAW_HZ: float = 10.0

const SHADER_PATH: String = "res://scripts/shaders/blood_ground.gdshader"

## The field's own clock: the frame's delta times the wash, so a mark's age is
## `_clock - born`, rain and flood age what they fall on faster, and a frozen
## field stays still.
var _clock: float = 0.0
## When the last mark laid will have faded, on `_clock`.
var _last_end: float = 0.0
var _material: ShaderMaterial = null
## Starts full, and is refilled whenever the field goes quiet: the first mark
## after a quiet spell paints at once, and only marks arriving in a burst wait
## for the clock.
var _since_redraw: float = 1.0 / REDRAW_HZ
var _rain_wash: float = 1.0
var _chunks: Array[BloodChunk] = []


## One canvas of marks. It paints what it holds and drops what has faded.
class BloodChunk extends Node2D:
	var marks: Array[Dictionary] = []
	var field: BloodField = null
	var dirty: bool = false

	func _draw() -> void:
		var started: int = Time.get_ticks_usec()
		_draw_measured()
		FrameProfile.add(&"blood_ground", started)

	func _draw_measured() -> void:
		var points := PackedVector2Array()
		var colours := PackedColorArray()
		var indices := PackedInt32Array()
		var uvs := PackedVector2Array()
		var kept: Array[Dictionary] = []
		var clock: float = field.clock() if field != null else 0.0
		for splat: Dictionary in marks:
			var born: float = float(splat["born"])
			var life: float = maxf(float(splat["life"]), 0.01)
			if clock - born >= life:
				continue
			kept.append(splat)
			# The fade and the drying are the shader's (see `blood_ground`): what
			# the vertex carries is the mark's shade roll in red and the blob's own
			# shape in alpha, and its birth and life in the UV.
			var carrier := Color(float(splat["tone"]), 0.0, 0.0, 1.0)
			var origin: Vector2 = to_local(splat["at"] as Vector2)
			for blob: Variant in (splat["blobs"] as Array):
				var one: Dictionary = blob
				BloodInk.blob(points, colours, indices, origin + (one["at"] as Vector2),
					float(one["r"]), carrier, float(one.get("seed", 0.0)),
					one.get("long", Vector2.ZERO) as Vector2)
			while uvs.size() < points.size():
				uvs.append(Vector2(born, life))
		marks = kept
		if points.is_empty() or indices.is_empty():
			return
		if material == null and (field == null or field.material == null):
			# No shader on disk: the mark is drawn at its laying shade and never
			# fades, which is a stain rather than nothing.
			for index: int in colours.size():
				var c: Color = colours[index]
				colours[index] = Color(Balance.BLOOD_FRESH, c.a * Balance.BLOOD_GROUND_ALPHA)
		# One draw call for the chunk: a soft blob is three triangles a rim
		# vertex, and spending a draw call each would undo the whole point.
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
			indices, points, colours, uvs)


func _ready() -> void:
	# Under everything that walks on it, and above the ground it stains.
	z_index = Balance.BLOOD_GROUND_Z
	texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	add_to_group(Graphics.FILTER_GROUP)
	EventBus.weather_changed.connect(_on_weather_changed)
	_on_weather_changed(RunState.weather_id)
	if ResourceLoader.exists(SHADER_PATH):
		_material = ShaderMaterial.new()
		_material.shader = load(SHADER_PATH) as Shader
		_material.set_shader_parameter("hold", Balance.BLOOD_HOLD)
		_material.set_shader_parameter("ground_alpha", Balance.BLOOD_GROUND_ALPHA)
		_material.set_shader_parameter("fresh", Balance.BLOOD_FRESH)
		_material.set_shader_parameter("dry", Balance.BLOOD_DRY)
		_material.set_shader_parameter("dry_seconds", Balance.BLOOD_DRY_SECONDS)
		_material.set_shader_parameter("clock", _clock)
		material = _material
	set_process(false)


## The field's clock, for the chunks and the gate.
func clock() -> float:
	return _clock


## **How long a mark lasts, and how many the field keeps, by the setting.** Low
## is the ten-minute memory; High lasts until the party extracts - the field is
## freed with the road - and only rain and flood wash it (owner, 2026-09-30).
static func life_for(level: int) -> float:
	return Balance.BLOOD_GROUND_LIFE_HIGH if level >= UserSettings.BLOOD_HIGH else Balance.BLOOD_GROUND_LIFE


static func cap_for(level: int) -> int:
	return Balance.BLOOD_MARKS_HIGH if level >= UserSettings.BLOOD_HIGH else MAX_SPLATS


## Lays a mark down. `heading` biases the spatter the way the blow was going.
func splat(at: Vector2, heading: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var level: int = UserSettings.blood_level()
	if level <= UserSettings.BLOOD_OFF:
		return
	var blobs: Array = []
	var count: int = rng.randi_range(Balance.BLOOD_BLOBS_MIN, Balance.BLOOD_BLOBS_MAX)
	var along: Vector2 = heading.normalized() if heading.length_squared() > 0.001 \
		else Vector2.from_angle(rng.randf() * TAU)
	# **One mass, then satellites.** Photographed on 2026-09-16: with every blob
	# thrown from the same distribution a mark came out as four or five separate
	# lumps with a hole in the middle - a scatter rather than a spatter. The
	# first blob is the pool the blow actually left, sitting where it landed and
	# not drawn out at all; everything after it is what sprayed off, smaller the
	# further it went.
	for i: int in count:
		var pool: bool = i == 0
		# Most of the rest still lands near the impact; the tail throws forward
		# along the blow. A perfectly radial splat reads as a stamp rather than
		# as something that happened in a direction.
		var throw: float = 0.0 if pool \
			else pow(rng.randf(), 2.0) * size * Balance.BLOOD_THROW
		var spread: float = rng.randf_range(-0.7, 0.7)
		var wander: float = 0.06 if pool else 0.28
		var offset: Vector2 = along.rotated(spread) * throw \
			+ Vector2.from_angle(rng.randf() * TAU) * rng.randf() * size * wander
		# The pool is the big one; a satellite falls away with its throw, hard
		# enough that the far end of a spatter is specks rather than more lumps.
		var far: float = clampf(throw / maxf(size * Balance.BLOOD_THROW, 0.01), 0.0, 1.0)
		var radius: float = rng.randf_range(size * 0.30, size * 0.40) if pool \
			else rng.randf_range(size * 0.09, size * 0.22) * (1.0 - far * 0.62)
		blobs.append({
			"at": offset,
			"r": radius,
			# The blob's own outline, rolled once. `BloodInk` derives the lobes
			# from this, so a drying mark holds its shape rather than shimmering
			# through a new one every repaint.
			"seed": rng.randf() * 1000.0,
			# Thrown blood lands as a streak pointing the way it was going; blood
			# that only pooled lands round. The further it was thrown the longer
			# the mark, which is one number rather than two authored shapes.
			"long": along.rotated(spread * 0.5) * throw * Balance.BLOOD_STREAK,
		})
	# Life is an authored promise: every mark that is not displaced by the
	# bounded field survives its full memory. Randomising it below one quietly
	# turned "600 seconds" into as little as eight minutes.
	_lay({"at": at, "blobs": blobs, "born": _clock, "life": life_for(level),
		"tone": rng.randf()}, level)


## One procedural droplet, added when its visible ballistic mote reaches the
## floor. Separate from `splat`: a burst must not stamp a large stain at impact
## before its particles have actually landed.
func droplet(at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var level: int = UserSettings.blood_level()
	if level <= UserSettings.BLOOD_OFF:
		return
	_lay({
		"at": at,
		"blobs": [{"at": Vector2.ZERO,
			"r": maxf(radius * rng.randf_range(0.78, 1.22), 1.4),
			"seed": rng.randf() * 1000.0,
			"long": Vector2.ZERO}],
		"born": _clock,
		"life": life_for(level),
		"tone": rng.randf(),
	}, level)


## Lays a mark into the newest chunk, opening one when it is full, and drops the
## oldest marks past the setting's cap - which dirties only the oldest chunk.
func _lay(mark: Dictionary, level: int) -> void:
	var chunk: BloodChunk = _chunks.back() if not _chunks.is_empty() else null
	if chunk == null or chunk.marks.size() >= CHUNK:
		chunk = BloodChunk.new()
		chunk.field = self
		chunk.use_parent_material = true
		add_child(chunk)
		_chunks.append(chunk)
	chunk.marks.append(mark)
	chunk.dirty = true
	var cap: int = cap_for(level)
	var total: int = held()
	while total > cap and not _chunks.is_empty():
		var oldest: BloodChunk = _chunks[0]
		if oldest.marks.is_empty():
			_chunks.remove_at(0)
			oldest.queue_free()
			continue
		oldest.marks.remove_at(0)
		oldest.dirty = true
		total -= 1
	_touch(float(mark["life"]))


## How many marks are held, faded or not.
func held() -> int:
	var total: int = 0
	for chunk: BloodChunk in _chunks:
		total += chunk.marks.size()
	return total


## A mark arrived: repaint now if the clock allows, otherwise with the next
## tick of it.
func _touch(life: float) -> void:
	_last_end = maxf(_last_end, _clock + life)
	set_process(true)
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		_repaint_dirty()


func _repaint_dirty() -> void:
	for chunk: BloodChunk in _chunks:
		if chunk.dirty:
			chunk.dirty = false
			chunk.queue_redraw()


## How many marks are still showing. For the gate. Counted rather than taken
## from the arrays' size, because an expired mark stays in its chunk until the
## next rebuild drops it.
func marks() -> int:
	var showing: int = 0
	for chunk: BloodChunk in _chunks:
		for splat: Dictionary in chunk.marks:
			if _clock - float(splat["born"]) < float(splat["life"]):
				showing += 1
	return showing


## How many canvases the marks are spread over. For the gate.
func chunk_count() -> int:
	return _chunks.size()


## Current ageing rate, exposed for the release gate.
func wash_multiplier() -> float:
	return _wash_now()


## **What ages the blood.** One in dry weather; rain washes Low at
## `BLOOD_RAIN_WASH_MULTIPLIER` and High at `BLOOD_HIGH_WASH`, and so does a
## flood deep enough to reach the ground - "only washing naturally from
## rain/flood rules" is the owner's own sentence.
func _wash_now() -> float:
	var wet: bool = _rain_wash > 1.0 or RunState.flood >= Balance.BLOOD_FLOOD_WASH_FROM
	if not wet:
		return 1.0
	return Balance.BLOOD_HIGH_WASH if UserSettings.blood_level() >= UserSettings.BLOOD_HIGH \
		else Balance.BLOOD_RAIN_WASH_MULTIPLIER


## Clears the field. Called between roads: last week's blood is not this fight.
func wipe() -> void:
	for chunk: BloodChunk in _chunks:
		chunk.queue_free()
	_chunks.clear()
	set_process(false)
	_since_redraw = 1.0 / REDRAW_HZ
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta * _wash_now()
	if _material != null:
		_material.set_shader_parameter("clock", _clock)
	if _clock >= _last_end:
		# Everything has faded: drop it all and rest.
		wipe()
		return
	_since_redraw += delta
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		_repaint_dirty()


func _on_weather_changed(weather_id: String) -> void:
	var weather: WeatherData = ContentDB.weather(weather_id)
	_rain_wash = Balance.BLOOD_RAIN_WASH_MULTIPLIER \
		if weather != null and weather.precipitation == WeatherData.Precipitation.RAIN \
		else 1.0
