class_name Foliage
extends Node2D

## Scattered plants that sway, placed procedurally per terrain.
##
## Two rules make scattered decoration read as a place rather than as confetti:
##
## 1. **Nothing lands where the game happens.** Lanes, build spots and the town
##    are exclusion zones. Decoration that overlaps a road makes the road look
##    like a mistake, and decoration under a tower makes the tower hard to click.
##
## 2. **Nothing is identical.** Every clump varies in size, tint, lean and sway
##    phase, so a hundred instances of three shapes still look like undergrowth.
##
## Per-terrain growth language. Colour is not hardcoded: it is sampled from the
## act's ground painting each time the terrain changes, so plants inherit the
## local hue and remain coherent under the same day/night CanvasModulate.
const STYLES: Dictionary = {
	"jungle": {"kind": "reed"},
	"desert": {"kind": "shard"},
	"snow": {"kind": "tuft"},
}

## How far a single plant's hue may drift from the region's sampled palette.
## Small on purpose: the palette comes from the ground so the field stays in tint
## with its act, and a wide jitter would put plants outside their own region.
const HUE_JITTER: float = 0.035

## How often a plant is a broadleaf rather than its region's own silhouette.
const BROADLEAF_CHANCE: float = 0.18

## Painted plant art, one per region.
const PLANT_ART_FORMAT: String = "res://art/foliage/plant_%s.png"

## Extra painted kinds, drawn from alongside the region's own plant.
##
## Two families. **Regional** kinds carry the act's identity and are named per
## region; **shared** kinds are things that look the same everywhere - a rock is
## a rock in a jungle or a snowfield - and are named once.
##
## The region's own plant stays the most common draw. The rest are punctuation:
## a field of nothing but boulders is as monotonous as a field of nothing but
## reeds, and the point of the extra kinds is that a clump is occasionally *not*
## the thing you expected.
const REGIONAL_KINDS: Array[String] = ["shrub", "flower"]
const SHARED_KINDS: Array[String] = ["rock", "boulder"]
const REGIONAL_KIND_FORMAT: String = "res://art/foliage/plant_%s_%s.png"
const SHARED_KIND_FORMAT: String = "res://art/foliage/prop_%s.png"

var _plant_art: Texture2D = null
var _plant_art_id: String = ""

## Every painted kind available for the current region, the region's own plant
## first. Rebuilt when the act changes.
var _kind_art: Array[Texture2D] = []
var _kind_art_id: String = ""

const PALETTE_SAMPLE_SIZE: int = 32
const PALETTE_MIN_VALUE: float = 0.08
const PALETTE_MAX_VALUE: float = 0.78

## Sway, done on the GPU.
##
## The field used to be one CanvasItem per clump - 420 of them - each rotated
## every frame to make it lean. Measured, that was the entire performance
## regression: switching foliage off took the game from 57 to 104 fps on a
## 3070 Ti while cast shadows, contact shadows and clouds were worth about one
## frame each between them.
##
## The cost was never the polygons; it was 420 separate canvas items, and a
## per-frame transform write on each. So the whole field is now drawn once into
## a single canvas item and never touched again, and the leaning happens in a
## vertex shader.
##
## The trick is UV.y. Each blade is drawn with 0 at its root and 1 at its tip,
## so the shader can displace the tip and leave the root planted - which is what
## makes grass look rooted rather than sliding. The wind is a function of world
## position and TIME, so neighbouring clumps lean together into a travelling
## gust without any of them knowing about each other.
const WIND_SHADER: String = """
shader_type canvas_item;

uniform float sway_degrees = 5.5;
uniform float sway_speed = 1.15;
uniform float gust_speed = 0.23;
uniform float sway_reach = 34.0;

// Whether V runs root-to-tip or tip-to-root.
//
// Blades are built with the root at V=0 because that is what the sway weight
// means. A texture drawn with draw_texture_rect gets its UVs from the rect, so
// V=0 is the *top* of the sprite - and a painted plant sharing the blade
// material therefore swung its base while its tip stayed nailed in place.
uniform float root_at_top = 0.0;

void vertex() {
	// Root to tip. Zero at the base means the plant stays where it grew.
	float up = mix(UV.y, 1.0 - UV.y, root_at_top);

	// One travelling wave over the field, plus a slow gust that swells and eases
	// so the whole meadow breathes rather than every blade fidgeting on its own
	// clock.
	float phase = TIME * sway_speed + (VERTEX.x + VERTEX.y) * 0.012;
	float gust = 0.6 + 0.4 * sin(TIME * gust_speed);
	float lean = sin(phase) * radians(sway_degrees) * gust;

	// Displacement grows with the square of height: the tip whips, the middle
	// bends, the base does not move at all.
	VERTEX.x += lean * up * up * sway_reach;
}
"""

static var _wind_shader: Shader = null
static var _wind_material: ShaderMaterial = null
static var _painted_material: ShaderMaterial = null


## One material for every blade in the game.
static func wind_material() -> ShaderMaterial:
	if _wind_material == null:
		_wind_material = _make_material(0.0, Balance.FOLIAGE_SWAY_REACH)
	return _wind_material


## The same wind, for painted plants: V inverted and the reach cut right down.
##
## A second material rather than a second shader - one compile, two parameter
## sets - and a second *canvas item*, because a material is per item and the
## blades and the sprites share a band.
static func painted_material() -> ShaderMaterial:
	if _painted_material == null:
		_painted_material = _make_material(1.0, Balance.FOLIAGE_SWAY_REACH_PAINTED)
	return _painted_material


static func _make_material(root_at_top: float, reach: float) -> ShaderMaterial:
	if _wind_shader == null:
		_wind_shader = Shader.new()
		_wind_shader.code = WIND_SHADER
	var material := ShaderMaterial.new()
	material.shader = _wind_shader
	material.set_shader_parameter("sway_degrees", Balance.FOLIAGE_SWAY_DEGREES)
	material.set_shader_parameter("sway_speed", Balance.FOLIAGE_SWAY_SPEED)
	material.set_shader_parameter("sway_reach", reach)
	material.set_shader_parameter("root_at_top", root_at_top)
	return material


## Every blade in the field, in world space, ready to draw in one pass.
## How many depth slices the field is drawn in. Sixteen keeps the sorting cue
## finer than anyone can see while costing sixteen draw calls instead of 420.
## Sorting bands across the field.
##
## Every plant in a band sorts at the band's centre, so a band is also the error
## in that plant's depth: at 16 bands each was a few hundred world units tall and
## a plant near its top edge drew in front of anything up to half a band above
## it - which is what "foliage in front of a tower it is standing behind" was.
## 48 brings the error to about a tile, which is below what the eye picks up.
const BAND_COUNT: int = 48

var _bands: Array[FoliageBand] = []

## Held apart from the clumps because they must not sway: a shadow that swings
## with the plant above it reads as the ground moving.
var _shadows: Array[Node2D] = []

## The density this scatter was built at, so a re-scatter only happens on change.
var _scattered_at: float = -1.0

## The battlefield's grid, so the scatter can ask where the roads are. Assigned
## before the node enters the tree: the first scatter happens on ready.
var grid: BattleGrid = null


func _ready() -> void:
	scatter()
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: scatter())


## Rebuilds the whole scatter for the current terrain.
func scatter() -> void:
	for node: Node2D in _bands + _shadows:
		if is_instance_valid(node):
			node.queue_free()
	_bands.clear()
	_shadows.clear()

	var style: Dictionary = STYLES.get(RunState.terrain_id, STYLES["jungle"]).duplicate()
	style.merge(_terrain_palette(), true)
	var rng := RandomNumberGenerator.new()
	# Seeded per terrain, so a given act always looks the same rather than
	# reshuffling every time the scope is entered.
	rng.seed = hash(RunState.terrain_id)

	# Depth bands, not one canvas item per clump.
	#
	# Measured: 420 clumps cost 47 frames a second, and disabling the wind
	# entirely recovered one of them. The work was never the maths - it was 420
	# separate canvas items, each its own draw call.
	#
	# Drawing the whole field into one item would fix that and break something
	# worth more: foliage has to sort against the hero, so a plant in front of
	# them occludes and one behind does not. A single item sorts at one depth.
	#
	# Bands are the middle: each spans a slice of the map and sorts at its own
	# centre. Sixteen of them keep the depth cue to within a band's height, which
	# no one can see, and cost sixteen draw calls instead of four hundred.
	var span: float = Balance.LANE_SPAWN_RADIUS * 1.15
	for index: int in BAND_COUNT:
		var band := FoliageBand.new()
		band.name = "Band%d" % index
		# Sorted against units by the band's own centre line.
		band.position.y = lerpf(-span, span, (float(index) + 0.5) / float(BAND_COUNT))
		band.material = wind_material()
		band.y_sort_enabled = false
		add_child(band)
		_bands.append(band)

	_scattered_at = Graphics.foliage_scale()
	var wanted: int = Graphics.scaled(Balance.FOLIAGE_COUNT, _scattered_at)
	var placed: int = 0
	var attempts: int = 0
	while placed < wanted and attempts < wanted * 12:
		attempts += 1
		var point: Vector2 = _random_point(rng)
		if not _is_clear(point):
			continue
		# Ground cover first, tall growth on top. Two heights is the difference
		# between undergrowth and a field of identical weeds.
		var ground: bool = rng.randf() < Balance.FOLIAGE_GROUND_RATIO
		_add_clump(point, style, rng, ground, span)
		placed += 1

	for band: FoliageBand in _bands:
		band.queue_redraw()


## Which band a point belongs to.
func _band_for(y: float, span: float) -> FoliageBand:
	var ratio: float = clampf((y + span) / (span * 2.0), 0.0, 0.9999)
	return _bands[clampi(int(ratio * float(BAND_COUNT)), 0, _bands.size() - 1)]


## Uniform over the disc. Sampling radius linearly would bunch everything at the
## centre, which is exactly where the town is.
## Re-scatters if the density setting moved.
##
## Guarded because this is called on every quality change and a full re-scatter
## of six hundred clumps is not something to do because the frame cap moved.
func refresh_quality() -> void:
	if is_equal_approx(_scattered_at, Graphics.foliage_scale()):
		return
	scatter()


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	var radius: float = sqrt(rng.randf()) * Balance.LANE_SPAWN_RADIUS * 1.15
	return Vector2.RIGHT.rotated(rng.randf() * TAU) * radius


## Keeps plants off the roads and the town.
##
## Asks the grid where the road is rather than measuring four straight lane centre
## lines. The lanes have U-bends now, so a centre-line test cleared the whole bend
## and reeds grew straight across the road - and decoration that overlaps a road
## makes the road look like a mistake, which is rule 1 above. The old test also
## avoided a fixed ring of tower slots that free placement did away with.
func _is_clear(point: Vector2) -> bool:
	if point.length() < Balance.TOWN_RADIUS + Balance.FOLIAGE_TOWN_MARGIN:
		return false
	if grid == null:
		return true
	var tile: Vector2i = BattleGrid.world_to_tile(point)
	# A tile of margin either way: a clump is wider than the point it is placed
	# on, and a blade leaning in the wind reaches further still.
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			var cell: int = grid.cell_at(tile + Vector2i(dx, dy))
			if cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN:
				return false
	return true


func _add_clump(at: Vector2, style: Dictionary, rng: RandomNumberGenerator,
		ground: bool, span: float) -> void:
	var band: FoliageBand = _band_for(at.y, span)
	var local: Vector2 = at - band.position

	var scale: float = rng.randf_range(Balance.FOLIAGE_MIN_SCALE, Balance.FOLIAGE_MAX_SCALE)
	if ground:
		scale *= Balance.FOLIAGE_GROUND_SCALE
	var blades: int = rng.randi_range(5, 8) if ground else rng.randi_range(3, 6)
	var blade_span: float = 19.0 if ground else 13.0

	# The skirt that roots the clump. Drawn first so blades overlap it.
	band.add_blade(PackedVector2Array([
		Vector2(-16.0, 2.0), Vector2(16.0, 2.0),
		Vector2(11.0, -3.0), Vector2(-11.0, -3.0)]),
		(style["dark"] as Color).darkened(0.22), local, 0.0, scale, false)

	for blade: int in blades:
		var ratio: float = (float(blade) + 0.5) / float(blades)
		var offset := Vector2(lerpf(-blade_span, blade_span, ratio) + rng.randf_range(-2.4, 2.4),
			rng.randf_range(-1.6, 1.6))
		var blade_scale: float = scale * rng.randf_range(0.72, 1.18)
		if ground:
			blade_scale *= 0.62
		var colour: Color = _plant_colour(style, rng)
		band.add_blade(_blade_shape(String(style["kind"]), rng), colour,
			local + offset, rng.randf_range(-0.12, 0.12), blade_scale, true)

	# A painted plant every so often, standing among the blades. This is what
	# gives a region a face: the polygons say "ground cover", the sprite says
	# which region's ground cover it is.
	if not ground and rng.randf() < Balance.FOLIAGE_PAINTED_CHANCE:
		var art: Texture2D = _painted_kind(rng)
		if art != null:
			# Tinted toward the region's own sampled palette rather than drawn
			# neutral, so a painted plant sits in the same light as everything
			# around it instead of looking pasted on.
			var tint: Color = Color.WHITE.lerp(_plant_colour(style, rng),
				Balance.FOLIAGE_PAINTED_TINT)
			band.add_plant(art, local, scale * rng.randf_range(0.62, 0.92),
				tint, rng.randf() < 0.5)

	# Only the tall layer gets a shadow. Ground cover is already a few pixels
	# high, so a pool under it reads as dirt rather than as shade.
	if not ground:
		_add_shadow(at, scale)


## A shadow for a clump, which has no sprite to measure — so it is built by hand
## against the same shared material every other shadow on the field uses.
func _add_shadow(at: Vector2, scale: float) -> void:
	# Built by hand rather than through ShadowKit.add_contact, which measures a
	# sprite this has none of - so the quality switch has to be checked here too.
	# Missing it meant Low reported "ground shadows off" and still drew fifty of
	# them, which is a setting that lies.
	var shadow := Sprite2D.new()
	shadow.name = "ContactShadow"
	shadow.texture = ShadowKit.quad_texture()
	shadow.material = ShadowKit.material()
	shadow.scale = Vector2.ONE * (34.0 * scale / float(ShadowKit.quad_texture().width))
	shadow.z_index = -1
	shadow.z_as_relative = true
	shadow.position = at
	shadow.add_to_group(ShadowKit.GROUP)
	shadow.visible = Graphics.contact_shadows()
	add_child(shadow)
	_shadows.append(shadow)


## The act's own ground painting, reduced to a dark and a light.
##
## Sampled rather than hardcoded so plants inherit the local hue and stay
## coherent with the terrain under the same day/night tint.
func _terrain_palette() -> Dictionary:
	var fallback := {"dark": Color("253129"), "light": Color("667055")}
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain == null or not ResourceLoader.exists(terrain.get_sprite_path()):
		return fallback
	var texture: Texture2D = load(terrain.get_sprite_path()) as Texture2D
	if texture == null:
		return fallback
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return fallback
	var sampled: Image = source.duplicate()
	sampled.resize(PALETTE_SAMPLE_SIZE, PALETTE_SAMPLE_SIZE, Image.INTERPOLATE_LANCZOS)
	var total := Vector3.ZERO
	var count: int = 0
	for y: int in PALETTE_SAMPLE_SIZE:
		for x: int in PALETTE_SAMPLE_SIZE:
			var colour: Color = sampled.get_pixel(x, y)
			if colour.v < PALETTE_MIN_VALUE or colour.v > PALETTE_MAX_VALUE:
				continue
			total += Vector3(colour.r, colour.g, colour.b)
			count += 1
	if count == 0:
		return fallback
	var average := Color(total.x / float(count), total.y / float(count),
		total.z / float(count))
	var saturation: float = clampf(average.s * 1.18 + 0.035, 0.08, 0.42)
	var dark := Color.from_hsv(average.h, saturation,
		clampf(average.v * 0.68, 0.11, 0.38), 0.96)
	var light := Color.from_hsv(average.h, clampf(saturation * 0.82, 0.07, 0.34),
		clampf(average.v * 1.34, 0.30, 0.68), 0.98)
	return {"dark": dark, "light": light}


## A shadow for a clump, which has no sprite to measure — so it is built by hand

## One plant's colour: the region's own light-to-dark range, nudged a few degrees
## around the hue circle.
##
## The lerp alone gave every plant in an act the identical hue at a different
## brightness, which reads as one plant drawn four hundred times. A small hue
## jitter is enough to make a field look grown rather than stamped, and it is
## deliberately small - the palette is sampled from the ground so the field stays
## in tint with its region, and a wide jitter would throw plants out of it.
## The current region's painted plant, cached. Derived from the terrain id like
## every other asset path here; a region without one simply grows no sprites.
func _plant_texture() -> Texture2D:
	if _plant_art_id == RunState.terrain_id:
		return _plant_art
	_plant_art_id = RunState.terrain_id
	var path: String = PLANT_ART_FORMAT % RunState.terrain_id
	_plant_art = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _plant_art


## Every painted kind this region offers, cached per act.
func _painted_kinds() -> Array[Texture2D]:
	if _kind_art_id == RunState.terrain_id:
		return _kind_art
	_kind_art_id = RunState.terrain_id
	_kind_art = []
	var own: Texture2D = _plant_texture()
	if own != null:
		_kind_art.append(own)
	for kind: String in REGIONAL_KINDS:
		var path: String = REGIONAL_KIND_FORMAT % [RunState.terrain_id, kind]
		if ResourceLoader.exists(path):
			_kind_art.append(load(path) as Texture2D)
	for kind: String in SHARED_KINDS:
		var path: String = SHARED_KIND_FORMAT % kind
		if ResourceLoader.exists(path):
			_kind_art.append(load(path) as Texture2D)
	return _kind_art


## Draws one painted kind, weighted toward the region's own plant.
##
## The region's plant is what makes a field read as *this* act, so it stays the
## common case; the extra kinds are what stop a field of it reading as wallpaper.
func _painted_kind(rng: RandomNumberGenerator) -> Texture2D:
	var kinds: Array[Texture2D] = _painted_kinds()
	if kinds.is_empty():
		return null
	if kinds.size() == 1 or rng.randf() < Balance.FOLIAGE_REGION_PLANT_SHARE:
		return kinds[0]
	return kinds[rng.randi_range(1, kinds.size() - 1)]


func _plant_colour(style: Dictionary, rng: RandomNumberGenerator) -> Color:
	var colour: Color = (style["dark"] as Color).lerp(
		style["light"] as Color, rng.randf_range(0.12, 0.92))
	colour.h = wrapf(colour.h + rng.randf_range(-HUE_JITTER, HUE_JITTER), 0.0, 1.0)
	colour.s = clampf(colour.s * rng.randf_range(0.86, 1.14), 0.0, 1.0)
	return colour


func _blade_shape(kind: String, rng: RandomNumberGenerator) -> PackedVector2Array:
	# A region's own silhouette most of the time, and a broadleaf occasionally.
	# One shape per region made a field read as a texture; an occasional
	# different plant makes it read as ground something grows out of.
	if rng.randf() < BROADLEAF_CHANCE:
		var leaf: float = rng.randf_range(13.0, 22.0)
		return PackedVector2Array([
			Vector2(-1.5, 0.0), Vector2(1.5, 0.0),
			Vector2(rng.randf_range(3.0, 7.0), -leaf * 0.55),
			Vector2(rng.randf_range(-1.0, 1.0), -leaf),
			Vector2(rng.randf_range(-7.0, -3.0), -leaf * 0.55)])
	return _kind_shape(kind, rng)


func _kind_shape(kind: String, rng: RandomNumberGenerator) -> PackedVector2Array:
	var height: float = rng.randf_range(16.0, 30.0)
	match kind:
		"shard":
			return PackedVector2Array([
				Vector2(-3.0, 0.0), Vector2(3.0, 0.0),
				Vector2(rng.randf_range(-2.0, 2.0), -height)])
		"tuft":
			return PackedVector2Array([
				Vector2(-4.0, 0.0), Vector2(4.0, 0.0),
				Vector2(2.0, -height * 0.7), Vector2(0.0, -height),
				Vector2(-2.0, -height * 0.7)])
		_:
			# Reeds come in two: a straight blade and a bent one. Two silhouettes
			# is the difference between a field and a hatch pattern.
			if rng.randf() < 0.42:
				return PackedVector2Array([
					Vector2(-2.0, 0.0), Vector2(2.0, 0.0),
					Vector2(rng.randf_range(4.0, 9.0), -height * 0.62),
					Vector2(rng.randf_range(1.0, 4.0), -height)])
			return PackedVector2Array([
				Vector2(-2.0, 0.0), Vector2(2.0, 0.0),
				Vector2(rng.randf_range(1.0, 5.0), -height)])


## One depth slice of the field, drawn as a single canvas item.
##
## Blades are stored already transformed into the band's local space, so drawing
## is a flat loop with no per-blade maths at all. UV.y carries the sway weight -
## 0 at a root, 1 at a tip - which is the only thing the wind shader needs in
## order to bend a plant without uprooting it.
class FoliageBand extends Node2D:
	var _shapes: Array[PackedVector2Array] = []
	var _uvs: Array[PackedVector2Array] = []
	var _colours: Array[Color] = []

	## Painted plants, drawn in the same canvas item as the blades.
	##
	## Alongside them rather than instead of them: the polygons are cheap enough
	## to scatter hundreds of, and they are what makes the ground look *covered*.
	## The sprites are the few plants the eye actually stops on. Replacing every
	## blade with a texture would multiply the draw cost of a field for a
	## difference nobody would see at a quarter of the plants.
	var _painted: PaintedLayer = null

	func add_plant(texture: Texture2D, at: Vector2, plant_scale: float,
			tint: Color, flip: bool) -> void:
		if texture == null:
			return
		if _painted == null:
			# A child, so it draws after this band's blades - a painted plant
			# stands in front of the undergrowth around it rather than being
			# buried in it - and so it can carry its own wind material.
			_painted = PaintedLayer.new()
			_painted.material = Foliage.painted_material()
			add_child(_painted)
		_painted.plants.append({"texture": texture, "at": at, "scale": plant_scale,
			"tint": tint, "flip": flip})

	func add_blade(shape: PackedVector2Array, colour: Color, at: Vector2,
			angle: float, blade_scale: float, sways: bool) -> void:
		var transform := Transform2D(angle, at).scaled(Vector2.ONE * blade_scale)

		var points := PackedVector2Array()
		var uvs := PackedVector2Array()

		# Sway weight is height within the blade, normalised. A skirt is pinned to
		# zero so it stays planted while the growth above it moves.
		var lowest: float = -INF
		var highest: float = INF
		for point: Vector2 in shape:
			lowest = maxf(lowest, point.y)
			highest = minf(highest, point.y)
		var reach: float = maxf(lowest - highest, 0.001)

		for point: Vector2 in shape:
			points.append(transform * point)
			uvs.append(Vector2(0.5,
				clampf((lowest - point.y) / reach, 0.0, 1.0) if sways else 0.0))

		_shapes.append(points)
		_uvs.append(uvs)
		_colours.append(colour)

	func _draw() -> void:
		for index: int in _shapes.size():
			var shade := PackedColorArray()
			shade.resize(_shapes[index].size())
			shade.fill(_colours[index])
			draw_polygon(_shapes[index], shade, _uvs[index])


## The painted plants of one band, in their own canvas item.
##
## Split off from the blades for one reason: a material is per canvas item, and
## these need the wind with V inverted and its reach cut down. Sharing the band's
## item meant sharing the band's material, which swung every sprite about its tip
## and left its roots sliding across the ground.
class PaintedLayer extends Node2D:
	var plants: Array[Dictionary] = []

	func _draw() -> void:
		for plant: Dictionary in plants:
			var texture: Texture2D = plant["texture"]
			var size: Vector2 = texture.get_size() * float(plant["scale"])
			var at: Vector2 = plant["at"]
			# Anchored at the foot, not the centre: a plant grows up out of the
			# point it was scattered on, and centring it buries half of it.
			var rect := Rect2(at - Vector2(size.x * 0.5, size.y), size)
			draw_texture_rect(texture, rect, false, plant["tint"], bool(plant["flip"]))
