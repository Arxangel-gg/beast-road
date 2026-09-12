class_name TownGrounds
extends Node2D

## The land the town stands on, as seen from above in the town scope.
##
## Owner brief (2026-09-12): the town scope's background needs to be more
## aesthetically appealing, procedurally generated, fitting and proper. The
## town rides the beast, so what surrounds it is the region the beast is
## walking through: a worn ring of ground under the plots, the region's own
## trees standing beyond them, its plants and props scattered in the gaps, and
## a vignette so the eye stays on the ring. All of it laid from the run's seed
## and the region, so the same act shows the same town and a new act shows a
## new one.
##
## Everything here is the battlefield's own art - `Treeline`, `Foliage` - so
## the town looks like the place it is in, and a region that gains a plant
## gains it here too. Nothing is painted for this scope.

const RING_INNER: float = 200.0
const RING_OUTER: float = 400.0
const TREE_RADIUS: Vector2 = Vector2(560.0, 1080.0)
const PROP_RADIUS: Vector2 = Vector2(430.0, 1000.0)
const TREE_COUNT: int = 42
const PROP_COUNT: int = 44
const TUFT_COUNT: int = 70
const GRASS_FORMAT: String = "res://art/foliage/grass_%s.png"

var _for_region: String = ""
var _sorted: Node2D = null
var _ring: Node2D = null
var _idle: Array[Dictionary] = []
var _idle_clock: float = 0.0
var _idle_frame: int = 0


func _ready() -> void:
	y_sort_enabled = false


## Re-lays the grounds for the current region. Cheap enough to call on every
## refresh; it does nothing when the region has not changed.
func rebuild() -> void:
	var region: String = RunState.terrain_id
	if region == _for_region:
		return
	_for_region = region
	for child: Node in get_children():
		child.queue_free()
	_idle.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("town:" + region)

	_ring = Node2D.new()
	_ring.name = "Ring"
	_ring.z_index = -2
	add_child(_ring)
	_ring.draw.connect(_draw_ring.bind(_ring))
	_ring.queue_redraw()

	_sorted = Node2D.new()
	_sorted.name = "Grounds"
	_sorted.y_sort_enabled = true
	_sorted.z_index = -1
	add_child(_sorted)

	# Grass tufts, inside and out, drawn low and never sorted above a building.
	var tufts: String = GRASS_FORMAT % region
	if ResourceLoader.exists(tufts):
		var sheet: Texture2D = load(tufts)
		for _tuft: int in TUFT_COUNT:
			var at: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU) \
				* rng.randf_range(RING_OUTER - 40.0, PROP_RADIUS.y)
			var tuft := Sprite2D.new()
			tuft.texture = sheet
			tuft.region_enabled = true
			var which: int = rng.randi_range(0, 3)
			tuft.region_rect = Rect2(float(which) * 32.0, 0.0, 32.0, 32.0)
			tuft.position = at
			tuft.offset = Vector2(0.0, -12.0)
			tuft.scale = Vector2.ONE * rng.randf_range(1.6, 2.4)
			tuft.flip_h = rng.randf() < 0.5
			tuft.z_index = -1
			tuft.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
			_sorted.add_child(tuft)

	# Props: the region's plants and the shared props, in the gap between the
	# ring and the trees.
	var props: Array[Texture2D] = _prop_art(region)
	if not props.is_empty():
		for _prop: int in PROP_COUNT:
			var at: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU) \
				* rng.randf_range(PROP_RADIUS.x, PROP_RADIUS.y)
			var art: Texture2D = props[rng.randi_range(0, props.size() - 1)]
			_plant(at, art, rng.randf_range(1.4, 2.0), rng)

	# Trees, beyond, thickening outward so the town sits in a clearing.
	var trees: Array[Texture2D] = _tree_art(region)
	if not trees.is_empty():
		for _tree: int in TREE_COUNT:
			var reach: float = lerpf(TREE_RADIUS.x, TREE_RADIUS.y, pow(rng.randf(), 0.6))
			var at: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU) * reach
			var art: Texture2D = trees[rng.randi_range(0, trees.size() - 1)]
			_plant(at, art, rng.randf_range(1.5, 2.3), rng)

	# The vignette: the edges fall away, so the ring is where the eye rests.
	var veil := Node2D.new()
	veil.name = "Vignette"
	veil.z_index = 5
	add_child(veil)
	veil.draw.connect(_draw_vignette.bind(veil))
	veil.queue_redraw()


func _plant(at: Vector2, art: Texture2D, size: float, rng: RandomNumberGenerator) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.position = at
	sprite.offset = Foliage.foot_offset(art)
	sprite.scale = Vector2.ONE * size
	sprite.flip_h = rng.randf() < 0.5
	var shade: float = rng.randf_range(0.82, 1.04)
	sprite.modulate = Color(shade, shade, shade)
	sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	sprite.material = Foliage.canopy_material(RunState.terrain_id)
	_sorted.add_child(sprite)
	var frames: Array[Texture2D] = Foliage.idle_sequence(art)
	if not frames.is_empty():
		_idle.append({"sprite": sprite, "frames": frames, "phase": _idle.size()})


func _prop_art(region: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var own: String = Foliage.PLANT_ART_FORMAT % region
	if ResourceLoader.exists(own):
		out.append(load(own))
	for kind: String in Foliage.REGIONAL_KINDS:
		var path: String = Foliage.REGIONAL_KIND_FORMAT % [region, kind]
		if ResourceLoader.exists(path):
			out.append(load(path))
	for kind: String in ["rock", "boulder", "log", "stump", "mushrooms", "wildflower_01",
			"wildflower_02", "wildflower_03", "wildflower_04"]:
		var path: String = Foliage.SHARED_KIND_FORMAT % kind
		if ResourceLoader.exists(path):
			out.append(load(path))
	return out


func _tree_art(region: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var base: String = Treeline.TREE_ART_FORMAT % region
	if ResourceLoader.exists(base):
		out.append(load(base))
	for index: int in range(1, 9):
		var path: String = Treeline.TREE_VARIANT_FORMAT % [region, index]
		if ResourceLoader.exists(path):
			out.append(load(path))
	if out.is_empty():
		# A region without its own trees borrows the first act's rather than
		# standing in a bare field.
		var fallback: String = Treeline.TREE_ART_FORMAT % "jungle"
		if ResourceLoader.exists(fallback):
			out.append(load(fallback))
	return out


## The worn ring under the plots: packed earth a shade darker than the ground,
## with a soft edge, and a paler path around the hall.
func _draw_ring(node: Node2D) -> void:
	for step: int in 6:
		var t: float = float(step) / 6.0
		node.draw_arc(Vector2.ZERO, lerpf(RING_INNER, RING_OUTER, t + 0.08), 0.0, TAU, 96,
			Color(0.08, 0.06, 0.05, 0.16), (RING_OUTER - RING_INNER) / 6.0 + 4.0)
	node.draw_arc(Vector2.ZERO, RING_INNER - 30.0, 0.0, TAU, 96, Color(0.55, 0.48, 0.38, 0.22), 26.0)
	node.draw_arc(Vector2.ZERO, RING_INNER - 30.0, 0.0, TAU, 96, Color(0.95, 0.9, 0.8, 0.10), 6.0)


func _draw_vignette(node: Node2D) -> void:
	for step: int in 10:
		var t: float = float(step) / 10.0
		node.draw_arc(Vector2.ZERO, lerpf(760.0, 1500.0, t), 0.0, TAU, 96,
			Color(0.02, 0.02, 0.03, 0.06 + t * 0.08), 80.0)


func _process(delta: float) -> void:
	if _idle.is_empty():
		return
	_idle_clock += delta * Balance.FOLIAGE_IDLE_FRAME_RATE
	var step: int = int(_idle_clock)
	if step == _idle_frame:
		return
	_idle_frame = step
	for entry: Dictionary in _idle:
		var sprite: Sprite2D = entry["sprite"]
		if not is_instance_valid(sprite):
			continue
		var frames: Array = entry["frames"]
		sprite.texture = frames[(step + int(entry["phase"])) % frames.size()]
