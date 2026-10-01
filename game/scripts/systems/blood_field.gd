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
## **The flood clock** (Brutal, 2026-10-01): seconds of deep water the ground
## has stood under, weighted by how deep. A Brutal mark is thinned by the flood
## that has passed since it was laid, toward `BLOOD_BRUTAL_WASH_FLOOR` and never
## past it; nothing else ages a Brutal mark.
var _wash_clock: float = 0.0
var _brutal_shown: float = -1.0


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
			# On Brutal the second half is the flood clock it was laid at: its
			# life is longer than any road, and the shader needs the wash.
			var second: float = float(splat.get("wash_born", life)) \
				if UserSettings.blood_level() >= UserSettings.BLOOD_BRUTAL else life
			while uvs.size() < points.size():
				uvs.append(Vector2(born, second))
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


## **The pools under Brutal blood**, made the first time one is poured, and a
## field banked with a front laid again when this ground is first stood up.
var _pools: BloodPools = null


func pools() -> BloodPools:
	if _pools == null:
		_pools = BloodPools.new()
		add_child(_pools)
		_pools.scars = Vfx.scars_above(get_parent())
		_pools.stains = stains()
	return _pools


## The pools if any were poured, else null - for the movers' read.
func pools_if_any() -> BloodPools:
	return _pools


## **What Brutal never forgets** (`BloodStains`): the marks the field lets go of
## and the pools that soak away, baked into one map. Made the first time one is.
var _stains: BloodStains = null


func stains() -> BloodStains:
	if _stains == null:
		_stains = BloodStains.new()
		add_child(_stains)
		move_child(_stains, 0)
	return _stains


func stains_if_any() -> BloodStains:
	return _stains


## The flood clock, for the gate.
func wash_clock() -> float:
	return _wash_clock


## **How much of a Brutal mark a flood has left** after `flooded` seconds of
## the flood clock: 1 untouched, falling toward `BLOOD_BRUTAL_WASH_FLOOR` and
## never below it. The shader's own arithmetic, for the gate.
static func brutal_washed_left(flooded: float) -> float:
	var washed: float = clampf(1.0 - exp(-maxf(flooded, 0.0)
		/ maxf(Balance.BLOOD_BRUTAL_WASH_TAU, 1.0)), 0.0, 1.0)
	return lerpf(1.0, Balance.BLOOD_BRUTAL_WASH_FLOOR, washed)


## **How fast a flood runs the flood clock**: nothing short of
## `BLOOD_BRUTAL_FLOOD_FROM`, rising to one a second at the height that drowns -
## so it takes great depth, and a long time at it, to thin Brutal blood at all.
static func brutal_flood_rate(flood: float) -> float:
	var deep: float = clampf((flood - Balance.BLOOD_BRUTAL_FLOOD_FROM)
		/ maxf(1.0 - Balance.BLOOD_BRUTAL_FLOOD_FROM, 0.01), 0.0, 1.0)
	return deep * deep


## **What a Brutal field banks with a front**: the newest marks, five numbers
## and an age each, and the pools. Empty on any other level.
func snapshot() -> Dictionary:
	if UserSettings.blood_level() < UserSettings.BLOOD_BRUTAL:
		return {}
	var all: Array[Dictionary] = []
	for chunk: BloodChunk in _chunks:
		for mark: Dictionary in chunk.marks:
			if mark.has("seed"):
				all.append(mark)
	var start: int = maxi(all.size() - Balance.BLOOD_BRUTAL_SAVED, 0)
	var flat: Array = []
	for index: int in range(start, all.size()):
		var mark: Dictionary = all[index]
		var at: Vector2 = mark["at"]
		var heading: Vector2 = mark.get("heading", Vector2.ZERO)
		flat.append_array([snappedf(at.x, 0.1), snappedf(at.y, 0.1), int(mark.get("kind", 0)),
			snappedf(float(mark.get("size", 0.0)), 0.01), snappedf(heading.x, 0.001),
			snappedf(heading.y, 0.001), int(mark["seed"]),
			snappedf(maxf(_clock - float(mark["born"]), 0.0), 0.1)])
	return {"marks": flat, "pools": _pools.snapshot() if _pools != null else [],
		"wash": snappedf(_wash_clock, 0.1),
		"stains": _stains.snapshot() if _stains != null else ""}


## Lays a banked Brutal field down again: every mark from its seed at its age,
## and the pools as they were.
func restore(stored: Dictionary) -> void:
	_wash_clock = maxf(float(stored.get("wash", 0.0)), 0.0)
	var stained: String = String(stored.get("stains", ""))
	if not stained.is_empty():
		stains().restore(stained)
	var flat: Array = stored.get("marks", []) as Array
	var level: int = UserSettings.BLOOD_BRUTAL
	var at: int = 0
	while at + 7 < flat.size():
		var where := Vector2(float(flat[at]), float(flat[at + 1]))
		var kind: int = int(flat[at + 2])
		var size: float = float(flat[at + 3])
		var heading := Vector2(float(flat[at + 4]), float(flat[at + 5]))
		var seed: int = int(flat[at + 6])
		var age: float = float(flat[at + 7])
		var mark: Dictionary = make_droplet(where, size, seed) if kind == 1 \
			else make_splat(where, heading, size, seed)
		mark["born"] = _clock - age
		mark["life"] = life_for(level)
		mark["wash_born"] = _wash_clock
		_lay_quietly(mark, level)
		at += 8
	var pooled: Array = stored.get("pools", []) as Array
	if not pooled.is_empty():
		pools().restore(pooled)
	_repaint_dirty()


## Lays a mark without pouring it again - a restored mark's blood is already in
## the restored pools.
func _lay_quietly(mark: Dictionary, _level: int) -> void:
	var chunk: BloodChunk = _chunks.back() if not _chunks.is_empty() else null
	if chunk == null or chunk.marks.size() >= CHUNK:
		chunk = BloodChunk.new()
		chunk.field = self
		chunk.use_parent_material = true
		add_child(chunk)
		_chunks.append(chunk)
	chunk.marks.append(mark)
	chunk.dirty = true
	_last_end = maxf(_last_end, _clock + float(mark["life"]) - (_clock - float(mark["born"])))
	set_process(true)


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
		_material.set_shader_parameter("settled", Balance.BLOOD_BRUTAL_SETTLED)
		_material.set_shader_parameter("settle_seconds", Balance.BLOOD_BRUTAL_SETTLE_SECONDS)
		_material.set_shader_parameter("wash_tau", Balance.BLOOD_BRUTAL_WASH_TAU)
		_material.set_shader_parameter("wash_floor", Balance.BLOOD_BRUTAL_WASH_FLOOR)
		material = _material
	set_process(false)
	# A banked Brutal field, read once and erased - the way a tower's health is.
	if not RunState.blood_restore.is_empty() and UserSettings.blood_level() >= UserSettings.BLOOD_BRUTAL:
		restore.call_deferred(RunState.blood_restore.duplicate(true))
	RunState.blood_restore.clear()


## The field's clock, for the chunks and the gate.
func clock() -> float:
	return _clock


## **How long a mark lasts, and how many the field keeps, by the setting.** Low
## is the ten-minute memory; High lasts until the party extracts - the field is
## freed with the road - and only rain and flood wash it (owner, 2026-09-30).
static func life_for(level: int) -> float:
	if level >= UserSettings.BLOOD_BRUTAL:
		return Balance.BLOOD_GROUND_LIFE_BRUTAL
	return Balance.BLOOD_GROUND_LIFE_HIGH if level >= UserSettings.BLOOD_HIGH else Balance.BLOOD_GROUND_LIFE


static func cap_for(level: int) -> int:
	if level >= UserSettings.BLOOD_BRUTAL:
		return Balance.BLOOD_MARKS_BRUTAL
	return Balance.BLOOD_MARKS_HIGH if level >= UserSettings.BLOOD_HIGH else MAX_SPLATS


## Lays a mark down. `heading` biases the spatter the way the blow was going.
func splat(at: Vector2, heading: Vector2, size: float, rng: RandomNumberGenerator) -> void:
	var level: int = UserSettings.blood_level()
	if level <= UserSettings.BLOOD_OFF:
		return
	# **From a seed of its own** (2026-10-01), so a Brutal field banked with a
	# front can lay the very same mark again from five numbers.
	var mark: Dictionary = make_splat(at, heading, size, rng.randi())
	mark["born"] = _clock
	mark["wash_born"] = _wash_clock
	# Life is an authored promise: every mark that is not displaced by the
	# bounded field survives its full memory. Randomising it below one quietly
	# turned "600 seconds" into as little as eight minutes.
	mark["life"] = life_for(level)
	_lay(mark, level)


## A spatter's mark, its outline rolled from `seed` alone.
static func make_splat(at: Vector2, heading: Vector2, size: float, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
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
	return {"at": at, "blobs": blobs, "tone": rng.randf(), "kind": 0, "size": size,
		"heading": heading, "seed": seed}


## One procedural droplet, added when its visible ballistic mote reaches the
## floor. Separate from `splat`: a burst must not stamp a large stain at impact
## before its particles have actually landed.
func droplet(at: Vector2, radius: float, rng: RandomNumberGenerator) -> void:
	var level: int = UserSettings.blood_level()
	if level <= UserSettings.BLOOD_OFF:
		return
	var mark: Dictionary = make_droplet(at, radius, rng.randi())
	mark["born"] = _clock
	mark["wash_born"] = _wash_clock
	mark["life"] = life_for(level)
	_lay(mark, level)


static func make_droplet(at: Vector2, radius: float, seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return {
		"at": at,
		"blobs": [{"at": Vector2.ZERO,
			"r": maxf(radius * rng.randf_range(0.78, 1.22), 1.4),
			"seed": rng.randf() * 1000.0,
			"long": Vector2.ZERO}],
		"tone": rng.randf(),
		"kind": 1, "size": radius, "heading": Vector2.ZERO, "seed": seed,
	}


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
	# **Brutal blood pools** where it falls thick (2026-10-01): the mark pours
	# its volume, by its area against a hit's, into the sheet under it.
	if level >= UserSettings.BLOOD_BRUTAL:
		var size: float = float(mark.get("size", Balance.VFX_BLOOD_HIT_SIZE))
		if int(mark.get("kind", 0)) == 1:
			size *= 2.0
		var area: float = pow(size / Balance.VFX_BLOOD_HIT_SIZE, 2.0)
		pools().pour(mark["at"] as Vector2, Balance.BLOOD_POOL_PER_MARK * area, size * 0.45)
	var cap: int = cap_for(level)
	var total: int = held()
	var forever: bool = level >= UserSettings.BLOOD_BRUTAL
	while total > cap and not _chunks.is_empty():
		var oldest: BloodChunk = _chunks[0]
		if oldest.marks.is_empty():
			_chunks.remove_at(0)
			oldest.queue_free()
			continue
		# **Brutal forgets nothing** (2026-10-01): the mark the field lets go
		# of becomes the ground's own stain rather than nothing at all.
		if forever:
			stains().bake(oldest.marks[0])
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


## How much of a Brutal mark laid at flood clock `wash_born` is left now.
func brutal_left_of(mark_wash_born: float) -> float:
	return brutal_washed_left(_wash_clock - mark_wash_born)


## **What ages the blood.** One in dry weather; rain washes Low at
## `BLOOD_RAIN_WASH_MULTIPLIER` and High at `BLOOD_HIGH_WASH`, and so does a
## flood deep enough to reach the ground - "only washing naturally from
## rain/flood rules" is the owner's own sentence.
func _wash_now() -> float:
	# **Brutal: nothing ages it** - rain does nothing and a flood runs the
	# flood clock instead, which thins a mark and never takes it (2026-10-01).
	if UserSettings.blood_level() >= UserSettings.BLOOD_BRUTAL:
		return 1.0
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
	if _pools != null:
		_pools.clear()
	if _stains != null:
		_stains.clear()
	_wash_clock = 0.0
	set_process(false)
	_since_redraw = 1.0 / REDRAW_HZ
	queue_redraw()


func _process(delta: float) -> void:
	_clock += delta * _wash_now()
	var brutal: bool = UserSettings.blood_level() >= UserSettings.BLOOD_BRUTAL
	if brutal:
		var rate: float = brutal_flood_rate(RunState.flood)
		_wash_clock += delta * rate
		if _pools != null and rate > 0.0:
			_pools.wash(Balance.BLOOD_POOL_FLOOD_WASH * rate, delta)
		if _stains != null:
			_stains.set_wash(brutal_washed_left(_wash_clock))
	if _material != null:
		_material.set_shader_parameter("clock", _clock)
		_material.set_shader_parameter("wash_clock", _wash_clock)
		var shown: float = 1.0 if brutal else 0.0
		if shown != _brutal_shown:
			_brutal_shown = shown
			_material.set_shader_parameter("brutal", shown)
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
