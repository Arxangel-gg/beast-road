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

const CHUNK: int = 48
## How often a chunk that was laid into repaints.
const REDRAW_HZ: float = 6.0
const SHADER_PATH: String = "res://scripts/shaders/track_ground.gdshader"
## Rim points of a print.
const RIM: int = 8

## What colour the earth is at a point, and how deep water stands on it.
## Handed in, so this file knows nothing about where it is.
var ground: Callable = Callable()
var water: Callable = Callable()

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
	set_process(false)


## One stride's print, beside the line the body walks on. `side` is -1 or 1,
## the foot; `size` the body's contact size; `weight` how much of the effects
## budget there is (`Footfalls` works it out once a pass).
func press(at: Vector2, way: Vector2, size: float, mass: float, side: float,
		weight: float) -> void:
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
	var print_colour := Color(earth.darkened(Balance.TRACK_DARKEN),
		Balance.TRACK_ALPHA * clampf(weight, 0.0, 1.0) * clampf(mass, 0.6, 1.4))
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
		"colour": print_colour, "born": _clock, "life": Balance.TRACK_LIFE,
	})
	chunk.last_end = _clock + Balance.TRACK_LIFE
	chunk.dirty = true
	set_process(true)
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		_repaint()


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
	if _chunks.is_empty():
		set_process(false)
		return
	_since_redraw += delta
	if _since_redraw >= 1.0 / REDRAW_HZ:
		_since_redraw = 0.0
		_repaint()
