class_name Fishing
extends Node2D

## Ponds beyond the roads, the line you put in them, and the water you can
## fall into.
##
## **The third cut of fishing, 2026-09-12.** The second made the catch a
## press, a wait, a hook and a reel. The owner played it and asked for more:
## a cast you *hold* to throw further (and can miss the pond with), water with
## a deep middle where the rare fish are and fight harder, a band that slips
## while you reel, nibbles told apart from the float's idle bobbing, bubble
## patches that mark something below - a chance at a rare catch, or at
## startling it, or at being bitten if you swim over it - and a hero who walks
## into a pond and swims rather than standing on it.
##
## **What it is now.** Stand by water, hold to charge and let go to cast: a
## tap puts the line in the nearest water, a hold throws it as far as the aim,
## and a throw past the pond lands on dry ground and comes back. Wait. The
## float bobs on its own and sometimes something nibbles - the two look
## different and the readout says which. A bite is a window: hook it in time.
## Then reel: hold to take line in, let go to give it, keep the line inside a
## band that *drifts* as the fish darts, and watch the grip - outside the band
## the grip drains and at nothing the fish is gone; too tight and the line
## snaps. A fish hooked in the deep or in a bubble patch fights harder and is
## likelier to be the rare one.
##
## **The Angler level is the first profession**, and its bound is that it
## touches nothing but fishing: a wider bite window, a wider and steadier band,
## a shorter wait, a weaker fight and a slightly better chance at the rare
## fish. No damage, no health, no attribute - it is a skill at a thing, not a
## scale of power beside levelling and gear (CLAUDE.md working rule 7).
##
## **Where a pond sits is the owner's ruling**: beyond the authored core,
## where the roads begin, off the roads, the camps and the spawn mouths. Inside
## the grid still, because the hero is clamped to it and water they can see
## and never reach is the failure the first cut was built to avoid.
##
## **The water is a tilemap, not a picture.** Each region has a sixteen-tile
## Wang sheet at the conventional path, and a pond is a blob of water nodes on
## a lattice drawn with those tiles. `PondTiles` owns the geometry - and now
## the depth field the shader tints by and the fishing reads - and
## `pond_water.gdshader` owns the light, the rings, the foam and the stains.
##
## **Both machines grow the same ponds and neither is told about them.** The
## dig is seeded from the run seed and the region, on a generator of its own
## rather than the shared fishing stream, because the *catches* draw on that
## stream. The bubble patches drift on the same generator for the same reason.

const TILES_ART_FORMAT: String = "res://art/battlefield/pond_tiles_%s.png"
const WATER_SHADER: String = "res://scripts/shaders/pond_water.gdshader"
const FLOAT_ART: String = "res://art/battlefield/fishing_float.png"
const SPLASH_ART: String = "res://art/vfx/splash.png"
const RIPPLE_ART: String = "res://art/vfx/ripple.png"
const PROFESSION: String = "angler"

## How the water reads in each region: how many ponds are dug, and the span of
## a pond's lattice in nodes. A waste has few and they are small; a marsh is
## mostly water. [TUNE]
const REGIONS: Dictionary = {
	"jungle": {"ponds": 5, "width": Vector2i(4, 7), "height": Vector2i(3, 5)},
	"desert": {"ponds": 2, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"snow": {"ponds": 3, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"hollow_marches": {"ponds": 6, "width": Vector2i(4, 8), "height": Vector2i(3, 5)},
	"rustwood": {"ponds": 4, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"saltpan": {"ponds": 2, "width": Vector2i(5, 8), "height": Vector2i(3, 4)},
	"iron_steppe": {"ponds": 3, "width": Vector2i(5, 7), "height": Vector2i(3, 4)},
	"glass_fields": {"ponds": 3, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"ashen_reach": {"ponds": 2, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"last_terrace": {"ponds": 3, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
}

## Where a pond sorts against the things standing on its bank, as a fraction of
## its height below its centre. Water lies flat, so it sorts by its near edge.
const SORT_ANCHOR: float = 0.64

enum State { IDLE, READY, CHARGING, CASTING, MISSED, WAITING, BITE, REELING }

var grid: BattleGrid = null

## The scope the ponds are in. Asked for the hero whose line this is and for
## somewhere to put the Food, rather than reaching up the tree for either.
var field: Node = null

## Where the ponds are parented: the battlefield's y-sorted entity layer.
var host: Node2D = null

## The pond records. Each is {root, layer, material, at, half, nodes, stock,
## ripples, cursor, ambient_in, depth, spots, stains, stain_cursor}.
var _ponds: Array[Dictionary] = []

var _state: State = State.IDLE
## The pond in play: the nearest one while READY, the one the line is in after.
var _pond: int = -1
var _clock: float = 0.0
var _phase_left: float = 0.0
var _phase_total: float = 0.0
var _nibble_in: float = 0.0
var _bob_in: float = 0.0
var _hooked: FishData = null
var _tension: float = 0.0
var _progress: float = 0.0
var _grip: float = 1.0
var _fight: float = 0.0
var _fight_left: float = 0.0
var _pulling: bool = false
var _reel_seconds: float = 1.0
var _click_in: float = 0.0
var _charge: float = 0.0
var _band_centre: float = 0.0
var _band_half: float = 0.1
var _band_velocity: float = 0.0
var _band_turn_in: float = 0.0
var _band_drift: float = 0.0
var _depth_hooked: float = 0.0
var _spot_hooked: int = -1
var _float: Sprite2D = null
var _line: Line2D = null
var _float_at: Vector2 = Vector2.ZERO
var _float_from: Vector2 = Vector2.ZERO
var _announce_clock: float = 0.0
var _prompt: String = ""
var _prompt_button: String = ""
var _bite_in: float = 0.0
var _water_colour: Color = Color(0.16, 0.34, 0.48)
var _water_colour_for: String = ""
## Cosmetic timing - nibbles, the fish's rhythm, the ambient stir. Not the run's
## stream, because nothing here decides what is caught.
var _jitter: RandomNumberGenerator = RandomNumberGenerator.new()
## The patches' own drift, seeded with the dig so both machines agree.
var _drift: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_jitter.randomize()
	# A blow takes the line out of the water. Fishing is a thing you do instead
	# of fighting, not a thing you do while being hit.
	EventBus.hero_damaged.connect(_on_hero_damaged)


# --- Digging -------------------------------------------------------------------

## Re-digs the ponds for the current region.
func scatter() -> void:
	_abandon("")
	for pond: Dictionary in _ponds:
		var root: Node = pond.get("root", null)
		if root != null and is_instance_valid(root):
			root.queue_free()
	_ponds.clear()
	_pond = -1
	_set_prompt("", "")

	var region: String = RunState.terrain_id
	var path: String = TILES_ART_FORMAT % region
	if not ResourceLoader.exists(path) or grid == null:
		return
	var tiles: Texture2D = load(path) as Texture2D
	var shape: Dictionary = REGIONS.get(region, REGIONS["jungle"])

	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("ponds:" + region)
	_drift.seed = rng.seed + 7
	var wanted: int = int(shape["ponds"])
	var widths: Vector2i = shape["width"] as Vector2i
	var heights: Vector2i = shape["height"] as Vector2i
	var anchors: Array[Vector2i] = band_tiles(grid, Balance.FISHING_EDGE_BAND)
	if anchors.is_empty():
		return
	for _attempt: int in Balance.FISHING_PLACEMENT_ATTEMPTS:
		if _ponds.size() >= wanted:
			break
		var width: int = rng.randi_range(widths.x, widths.y)
		var height: int = rng.randi_range(heights.x, heights.y)
		var nodes: Array[Vector2i] = PondTiles.shape(rng, width, height)
		if nodes.size() < 4:
			continue
		var footprint := Vector2i(width + 1, height + 1)
		var rim: Rect2 = footprint_rim(anchors[rng.randi_range(0, anchors.size() - 1)], footprint)
		var half: Vector2 = rim.size * 0.5
		var at: Vector2 = rim.get_center()
		if not _is_good_water(at, half):
			continue
		_dig(tiles, at, half, nodes, width, height, rng)


## Every open tile beyond the authored core, in grid order.
##
## The owner's ruling: ponds sit around the edges of the map, beyond where the
## roads begin. Inside the grid still - the hero is clamped to it, so a pond
## out past the rim would be water the player can see and never reach. Drawn
## from the tiles rather than from a random point, because open ground is
## pockets, and a random point lands in one about once in five hundred throws
## - the first version of this dug nothing.
static func band_tiles(on: BattleGrid, _band: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y: int in range(1, BattleGrid.SIZE - 1):
		for x: int in range(1, BattleGrid.SIZE - 1):
			var tile := Vector2i(x, y)
			if on.cell_at(tile) != BattleGrid.Cell.OPEN:
				continue
			if not BattleGrid.beyond_core(BattleGrid.tile_to_world(tile)):
				continue
			out.append(tile)
	return out


## The world rectangle a footprint of tiles covers from an anchor tile, edge
## to edge - so a pond's water lines up with the grid it was placed on.
static func footprint_rim(anchor: Vector2i, footprint: Vector2i) -> Rect2:
	var top_left: Vector2 = BattleGrid.tile_to_world(anchor) - Vector2.ONE * BattleGrid.TILE * 0.5
	return Rect2(top_left, Vector2(footprint) * BattleGrid.TILE)


## Whether a pond of this size may lie here.
##
## Refusals, each derived from something that already knows the answer: every
## tile under it *and a ring around it* open ground by the grid - which keeps
## water off the roads, the camps and the border - clear of the spawn mouths
## so the first wave does not walk out of a lake, clear of the town, clear of
## the other ponds, and clear of wherever a hero is standing, because a pond
## dug under a player's feet is a player who is suddenly swimming.
func _is_good_water(at: Vector2, half: Vector2) -> bool:
	if grid == null:
		return false
	var rim := Rect2(at - half, half * 2.0)
	var reach: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE
	if absf(at.x) + half.x > reach or absf(at.y) + half.y > reach:
		return false
	if not ground_is_open(grid, rim, Balance.FISHING_ROAD_CLEARANCE_TILES):
		return false
	if at.length() < Balance.FISHING_TOWN_CLEARANCE:
		return false
	for spawn: Variant in grid.spawn_points:
		if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
			return false
	for lane: int in grid.far_spawn_points.size():
		for spawn: Variant in (grid.far_spawn_points[lane] as Array):
			if rim.grow(Balance.FISHING_SPAWN_CLEARANCE * 0.6).has_point(spawn as Vector2):
				return false
	for pond: Dictionary in _ponds:
		var other: Rect2 = Rect2((pond["at"] as Vector2) - (pond["half"] as Vector2),
			(pond["half"] as Vector2) * 2.0)
		if rim.grow(Balance.FISHING_POND_SPACING).intersects(other):
			return false
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
			var who := node as Node2D
			if who != null and rim.grow(BattleGrid.TILE).has_point(who.global_position):
				return false
	return true


## Every tile under `rim` is open ground, and no tile within `ring` of it is a
## road, the town or a camp. Shared with the rift gates, which want the same
## answer for the same reason. The ring tolerates the border.
static func ground_is_open(on: BattleGrid, rim: Rect2, ring: int) -> bool:
	var top_left: Vector2i = BattleGrid.world_to_tile(rim.position + Vector2.ONE * 0.5)
	var bottom_right: Vector2i = BattleGrid.world_to_tile(rim.end - Vector2.ONE * 0.5)
	for y: int in range(top_left.y - ring, bottom_right.y + ring + 1):
		for x: int in range(top_left.x - ring, bottom_right.x + ring + 1):
			var cell: int = on.cell_at(Vector2i(x, y))
			var under: bool = x >= top_left.x and x <= bottom_right.x \
				and y >= top_left.y and y <= bottom_right.y
			if under and cell != BattleGrid.Cell.OPEN:
				return false
			if not under and (cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN
					or cell == BattleGrid.Cell.CAMP):
				return false
	return true


func _dig(tiles: Texture2D, at: Vector2, half: Vector2, nodes: Array[Vector2i],
		width: int, height: int, rng: RandomNumberGenerator) -> void:
	var root := Node2D.new()
	root.name = "Pond"
	root.scale = Vector2.ONE * Balance.FISHING_TILE_SCALE
	# Sorted by the near edge: the root sits there and the layer is lifted so
	# the water is drawn where it is. And one step *below* the sorted layer,
	# so a swimmer is always drawn on the water rather than under it: a hero
	# in the far half of a pond has a smaller y than the pond's sort line, and
	# y-sorting alone would have hidden them beneath the surface.
	root.global_position = at + Vector2(0.0, half.y * SORT_ANCHOR)
	root.z_index = -1

	var layer := TileMapLayer.new()
	layer.name = "Water"
	layer.tile_set = PondTiles.tileset_for(tiles)
	layer.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	layer.add_to_group(Graphics.FILTER_GROUP)
	var size_px := Vector2(float(width + 1), float(height + 1)) * float(PondTiles.TILE)
	layer.position = -size_px * 0.5 - Vector2(0.0, half.y * SORT_ANCHOR / Balance.FISHING_TILE_SCALE)
	PondTiles.lay(layer, nodes, width, height)

	var depth: Image = PondTiles.mask_image(nodes, width, height)
	var material := ShaderMaterial.new()
	material.shader = load(WATER_SHADER) as Shader
	material.set_shader_parameter("mask", ImageTexture.create_from_image(depth))
	material.set_shader_parameter("pond_size", size_px)
	material.set_shader_parameter("now", _clock)
	material.set_shader_parameter("spent", 0.0)
	var rings: PackedVector4Array = []
	rings.resize(Balance.FISHING_RIPPLE_SLOTS)
	material.set_shader_parameter("ripples", rings)
	var stains: PackedVector4Array = []
	stains.resize(4)
	material.set_shader_parameter("stains", stains)
	layer.material = material
	root.add_child(layer)
	(host if host != null else self).add_child(root)

	# The bubble patches: something below, in one or two places, drifting.
	var spots: Array[Dictionary] = []
	var wanted: int = rng.randi_range(Balance.FISHING_BUBBLE_SPOTS.x, Balance.FISHING_BUBBLE_SPOTS.y)
	if nodes.size() < 6:
		wanted = mini(wanted, 1)
	for _spot: int in wanted:
		var node: Vector2i = nodes[rng.randi_range(0, nodes.size() - 1)]
		var bubbles := PondBubbles.new()
		bubbles.name = "Bubbles"
		bubbles.radius = Balance.FISHING_BUBBLE_RADIUS / Balance.FISHING_TILE_SCALE
		bubbles.position = layer.position + PondTiles.node_px(node)
		root.add_child(bubbles)
		spots.append({
			"node": node,
			"goal": node,
			"bubbles": bubbles,
			"drift_in": rng.randf_range(Balance.FISHING_BUBBLE_DRIFT.x, Balance.FISHING_BUBBLE_DRIFT.y),
			"alive": true,
			"bite_in": 0.0,
		})

	_ponds.append({
		"root": root,
		"layer": layer,
		"material": material,
		"at": at,
		"half": half,
		"nodes": nodes,
		"stock": Balance.FISHING_POND_STOCK,
		"ripples": rings,
		"cursor": 0,
		"ambient_in": _jitter.randf_range(0.2, Balance.FISHING_AMBIENT_RIPPLE.y),
		"depth": depth,
		"spots": spots,
		"stains": stains,
		"stain_cursor": 0,
	})


# --- The water -----------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_tick_water(delta)
	if _ponds.is_empty():
		return
	_tick_bites(delta)
	var angler: Node2D = _local_hero()
	if angler == null or RunState.phase == RunState.Phase.ENDED:
		_abandon("")
		_set_prompt("", "")
		return
	var still: bool = _is_still(angler)
	match _state:
		State.IDLE, State.READY:
			_tick_ready(angler, still)
		State.CHARGING:
			if not still or _is_swimming(angler):
				_abandon("")
				return
			_tick_charge(angler, delta)
		State.CASTING:
			if not still:
				_abandon("The line came out.")
				return
			_phase_left -= delta
			_lay_line(angler, 1.0 - _phase_left / maxf(_phase_total, 0.01))
			if _phase_left <= 0.0:
				_touch_down()
		State.MISSED:
			_phase_left -= delta
			_lay_line(angler, 1.0)
			if _phase_left <= 0.0 or _pressed(angler):
				_abandon("The line came back.")
		State.WAITING:
			if not still:
				_abandon("The line came out.")
				return
			_tick_waiting(angler, delta)
		State.BITE:
			if not still:
				_abandon("The line came out.")
				return
			_phase_left -= delta
			_lay_line(angler, 1.0)
			if _pressed(angler):
				_hook()
			elif _phase_left <= 0.0:
				_slip()
		State.REELING:
			if not still:
				_abandon("You stepped off the line.")
				return
			_tick_reel(angler, delta)


## The clock into every shader, the pond's own stir, and the patches' drift.
func _tick_water(delta: float) -> void:
	for index: int in _ponds.size():
		var pond: Dictionary = _ponds[index]
		var material: ShaderMaterial = pond["material"] as ShaderMaterial
		if material == null:
			continue
		material.set_shader_parameter("now", _clock)
		var left: float = float(pond["ambient_in"]) - delta
		if left <= 0.0:
			var nodes: Array[Vector2i] = pond["nodes"]
			var node: Vector2i = nodes[_jitter.randi_range(0, nodes.size() - 1)]
			_ripple_at(index, (pond["layer"] as TileMapLayer).to_global(PondTiles.node_px(node)),
				_jitter.randf_range(0.22, 0.42))
			var spent: bool = int(pond["stock"]) <= 0
			left = _jitter.randf_range(Balance.FISHING_AMBIENT_RIPPLE.x,
				Balance.FISHING_AMBIENT_RIPPLE.y) * (1.8 if spent else 1.0)
		_ponds[index]["ambient_in"] = left
		_tick_spots(index, pond, delta)


## The patches wander: each picks a neighbouring water node now and then and
## slides to it, with a ripple where it settles. A patch that was startled or
## fished is gone until the region is re-dug.
func _tick_spots(index: int, pond: Dictionary, delta: float) -> void:
	var layer: TileMapLayer = pond["layer"] as TileMapLayer
	var nodes: Array[Vector2i] = pond["nodes"]
	for spot: Dictionary in (pond["spots"] as Array):
		var bubbles: PondBubbles = spot["bubbles"] as PondBubbles
		if bubbles == null or not is_instance_valid(bubbles):
			continue
		if not bool(spot["alive"]):
			bubbles.visible = false
			continue
		spot["drift_in"] = float(spot["drift_in"]) - delta
		if float(spot["drift_in"]) <= 0.0:
			spot["drift_in"] = _drift.randf_range(Balance.FISHING_BUBBLE_DRIFT.x,
				Balance.FISHING_BUBBLE_DRIFT.y)
			var here: Vector2i = spot["node"] as Vector2i
			var options: Array[Vector2i] = []
			for node: Vector2i in nodes:
				if node != here and (node - here).length() <= 1.5:
					options.append(node)
			if not options.is_empty():
				spot["goal"] = options[_drift.randi_range(0, options.size() - 1)]
		var goal: Vector2 = layer.position + PondTiles.node_px(spot["goal"] as Vector2i)
		var before: Vector2 = bubbles.position
		bubbles.position = before.move_toward(goal, 14.0 * delta)
		if before.distance_to(goal) > 0.5 and bubbles.position.distance_to(goal) <= 0.5:
			spot["node"] = spot["goal"]
			_ripple_at(index, bubbles.global_position, 0.3)


## A ring on a pond, at a world position. Eight slots, oldest overwritten.
func _ripple_at(index: int, at: Vector2, strength: float) -> void:
	if index < 0 or index >= _ponds.size():
		return
	var pond: Dictionary = _ponds[index]
	var layer: TileMapLayer = pond["layer"] as TileMapLayer
	var rings: PackedVector4Array = pond["ripples"]
	var cursor: int = int(pond["cursor"])
	var local: Vector2 = layer.to_local(at)
	rings[cursor] = Vector4(local.x, local.y, _clock, strength)
	_ponds[index]["ripples"] = rings
	_ponds[index]["cursor"] = (cursor + 1) % rings.size()
	(pond["material"] as ShaderMaterial).set_shader_parameter("ripples", rings)


## Blood on the water. Only while the blood setting is on - it is the same
## switch every other stain obeys.
func _stain_at(index: int, at: Vector2, strength: float) -> void:
	if index < 0 or index >= _ponds.size():
		return
	if not bool(MetaState.settings.get(UserSettings.BLOOD_VFX_KEY, true)):
		return
	var pond: Dictionary = _ponds[index]
	var layer: TileMapLayer = pond["layer"] as TileMapLayer
	var stains: PackedVector4Array = pond["stains"]
	var cursor: int = int(pond["stain_cursor"])
	var local: Vector2 = layer.to_local(at)
	stains[cursor] = Vector4(local.x, local.y, _clock, strength)
	_ponds[index]["stains"] = stains
	_ponds[index]["stain_cursor"] = (cursor + 1) % stains.size()
	(pond["material"] as ShaderMaterial).set_shader_parameter("stains", stains)


# --- Swimming and the thing below --------------------------------------------

## How deep the water is under a world point: 0 on dry ground, 1 at the
## deepest node of a pond. What the hero asks every frame to know whether it
## is swimming, and what the cast asks to know whether it hit water.
func water_depth_at(at: Vector2) -> float:
	var deepest: float = 0.0
	for pond: Dictionary in _ponds:
		var rim := Rect2((pond["at"] as Vector2) - (pond["half"] as Vector2),
			(pond["half"] as Vector2) * 2.0)
		if not rim.grow(BattleGrid.TILE).has_point(at):
			continue
		var layer: TileMapLayer = pond["layer"] as TileMapLayer
		deepest = maxf(deepest, PondTiles.depth_at(pond["depth"] as Image, layer.to_local(at)))
	return deepest


## The pond a world point is over, or -1.
func pond_at(at: Vector2) -> int:
	for index: int in _ponds.size():
		var pond: Dictionary = _ponds[index]
		var rim := Rect2((pond["at"] as Vector2) - (pond["half"] as Vector2),
			(pond["half"] as Vector2) * 2.0)
		if rim.has_point(at):
			return index
	return -1


## The bubble patch a world point is inside, as {pond, spot}, or empty.
func spot_at(at: Vector2) -> Dictionary:
	for index: int in _ponds.size():
		var spots: Array = _ponds[index]["spots"] as Array
		for which: int in spots.size():
			var spot: Dictionary = spots[which]
			if not bool(spot["alive"]):
				continue
			var bubbles: PondBubbles = spot["bubbles"] as PondBubbles
			if bubbles == null or not is_instance_valid(bubbles):
				continue
			if bubbles.global_position.distance_to(at) <= Balance.FISHING_BUBBLE_RADIUS:
				return {"pond": index, "spot": which}
	return {}


## A ring where a swimmer stirs the water. Called by the hero.
func stir(at: Vector2, strength: float = 0.5) -> void:
	var index: int = pond_at(at)
	if index >= 0:
		_ripple_at(index, at, strength)


## The colour of this region's water, for the band drawn over a swimmer.
## Sampled once from the sheet's deep tile.
func water_colour() -> Color:
	if _water_colour_for == RunState.terrain_id:
		return _water_colour
	_water_colour_for = RunState.terrain_id
	var path: String = TILES_ART_FORMAT % RunState.terrain_id
	if ResourceLoader.exists(path):
		var image: Image = (load(path) as Texture2D).get_image()
		if image != null:
			var total := Color(0.0, 0.0, 0.0, 0.0)
			var count: int = 0
			# The all-water tile is the last on the canonical sheet.
			var coords: Vector2i = PondTiles.atlas_coords(15) * PondTiles.TILE
			for y: int in range(4, PondTiles.TILE - 4, 3):
				for x: int in range(4, PondTiles.TILE - 4, 3):
					var texel: Color = image.get_pixel(coords.x + x, coords.y + y)
					if texel.a > 0.5:
						total += texel
						count += 1
			if count > 0:
				_water_colour = Color(total.r / count, total.g / count, total.b / count, 1.0)
	return _water_colour


## Whatever is under a bubble patch bites a swimmer in it.
##
## This machine's own hero only: each player's health is its own machine's
## business, and a bite resolved on both would be paid twice.
func _tick_bites(delta: float) -> void:
	var swimmer: Node2D = _local_hero()
	for index: int in _ponds.size():
		for spot: Dictionary in (_ponds[index]["spots"] as Array):
			spot["bite_in"] = maxf(float(spot.get("bite_in", 0.0)) - delta, 0.0)
			if swimmer == null or not bool(spot["alive"]) or float(spot["bite_in"]) > 0.0:
				continue
			if not _is_swimming(swimmer):
				continue
			var bubbles: PondBubbles = spot["bubbles"] as PondBubbles
			if bubbles == null or not is_instance_valid(bubbles):
				continue
			if bubbles.global_position.distance_to(swimmer.global_position) > Balance.FISHING_BUBBLE_RADIUS:
				continue
			spot["bite_in"] = Balance.FISHING_BUBBLE_BITE_INTERVAL
			var health: Health = Health.of(swimmer)
			if health == null:
				continue
			RunState.note_blow("Something in the water", Balance.FISHING_BUBBLE_BITE_DAMAGE)
			if health.take_damage(Balance.FISHING_BUBBLE_BITE_DAMAGE, bubbles.global_position):
				_ripple_at(index, swimmer.global_position, 0.9)
				_stain_at(index, swimmer.global_position, 1.0)
				Vfx.spark(swimmer.global_position, Color("c4552e"), 6, Vector2.UP, 150.0)
				Sfx.play("sfx_water_bite")


# --- Standing by the water -----------------------------------------------------

func _tick_ready(angler: Node2D, still: bool) -> void:
	var near: int = _pond_near(angler.global_position)
	if near < 0:
		_pond = -1
		_state = State.IDLE
		_set_prompt("", "")
		return
	_pond = near
	_state = State.READY
	if _is_swimming(angler):
		_set_prompt("Get out of the water to cast", "")
		return
	if not still:
		_set_prompt("Stand still to cast", "")
		return
	_set_prompt("Hold to cast  ·  longer throws further", "CAST")
	if _pressed(angler):
		_begin_charge()


## Which pond is close enough to fish, or -1. Measured from the pond's rim
## rather than its centre, because a pond is now the size of a pond.
func _pond_near(at: Vector2) -> int:
	var best: int = -1
	var nearest: float = INF
	for index: int in _ponds.size():
		var pond: Dictionary = _ponds[index]
		if int(pond["stock"]) <= 0:
			continue
		var rim := Rect2((pond["at"] as Vector2) - (pond["half"] as Vector2),
			(pond["half"] as Vector2) * 2.0)
		var gap: float = 0.0 if rim.has_point(at) else \
			at.distance_to(Vector2(clampf(at.x, rim.position.x, rim.end.x),
				clampf(at.y, rim.position.y, rim.end.y)))
		if gap <= Balance.FISHING_RADIUS + Balance.FISHING_CAST_MAX * 0.5 and gap < nearest:
			nearest = gap
			best = index
	return best


## Standing still enough to fish.
##
## The hero's *own* motion - `Hero.own_speed` subtracts the beast's shove -
## because the first cut read the body's whole velocity, and on a walking
## beast that never settled below the threshold.
func _is_still(angler: Node2D) -> bool:
	if angler.has_method("own_speed"):
		return float(angler.call("own_speed")) <= Balance.FISHING_STILL_SPEED
	var body := angler as CharacterBody2D
	if body == null:
		return true
	return body.velocity.length() <= Balance.FISHING_STILL_SPEED


func _is_swimming(who: Node2D) -> bool:
	return who.has_method("is_swimming") and bool(who.call("is_swimming"))


# --- The cast ------------------------------------------------------------------

func _begin_charge() -> void:
	_state = State.CHARGING
	_charge = 0.0
	_set_prompt("Let go to cast", "CAST")
	Sfx.play("sfx_fish_cast_charge")
	EventBus.fishing_charge.emit(0.0)


func _tick_charge(angler: Node2D, delta: float) -> void:
	if _holding(angler):
		_charge = minf(_charge + delta / Balance.FISHING_CHARGE_SECONDS, 1.0)
		EventBus.fishing_charge.emit(_charge)
		return
	_let_fly(angler)


## The line goes: to the nearest water on a tap, or as far as the charge along
## the aim on a hold - which may be past the pond entirely.
func _let_fly(angler: Node2D) -> void:
	if _pond < 0 or _pond >= _ponds.size():
		_state = State.READY
		return
	_float_from = _hand_of(angler)
	if _charge <= Balance.FISHING_TAP_CHARGE:
		_float_at = _nearest_water(_pond, angler.global_position)
	else:
		var aim: Vector2 = _aim_of(angler)
		var reach: float = lerpf(Balance.FISHING_CAST_MIN, Balance.FISHING_CAST_MAX, _charge)
		_float_at = angler.global_position + aim * reach
	# The line always lands inside the field.
	var limit: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE
	_float_at = Vector2(clampf(_float_at.x, -limit, limit), clampf(_float_at.y, -limit, limit))
	_state = State.CASTING
	_phase_total = Balance.FISHING_CAST_TIME * lerpf(0.8, 1.6, _charge)
	_phase_left = _phase_total
	_make_line()
	_make_float()
	_set_prompt("", "")
	EventBus.fishing_charge.emit(-1.0)
	Sfx.play("sfx_fish_cast")


## Where the angler is pointing: the aim, or failing that, at the water.
func _aim_of(angler: Node2D) -> Vector2:
	if angler.has_method("aim_direction"):
		var aim: Vector2 = angler.call("aim_direction") as Vector2
		if aim.length() > 0.05:
			return aim.normalized()
	var toward: Vector2 = _nearest_water(_pond, angler.global_position) - angler.global_position
	return toward.normalized() if toward.length() > 1.0 else Vector2.RIGHT


## The water node nearest the angler, so the line goes in on their side.
func _nearest_water(index: int, from: Vector2) -> Vector2:
	var pond: Dictionary = _ponds[index]
	var layer: TileMapLayer = pond["layer"] as TileMapLayer
	var best: Vector2 = pond["at"] as Vector2
	var nearest: float = INF
	for node: Vector2i in (pond["nodes"] as Array[Vector2i]):
		var at: Vector2 = layer.to_global(PondTiles.node_px(node))
		var gap: float = at.distance_to(from)
		if gap < nearest:
			nearest = gap
			best = at
	return best


## The float came down: on water, or on ground.
func _touch_down() -> void:
	var landed: int = pond_at(_float_at)
	var depth: float = water_depth_at(_float_at)
	if landed < 0 or depth <= 0.02:
		_state = State.MISSED
		_phase_total = Balance.FISHING_MISS_SECONDS
		_phase_left = _phase_total
		Vfx.dust(_float_at, Color(0.6, 0.55, 0.45), 6, 50.0)
		Sfx.play("sfx_fish_miss")
		_set_prompt("Missed the water", "")
		EventBus.fishing_failed.emit("Missed the water.")
		return
	_pond = landed
	_depth_hooked = depth
	var spot: Dictionary = spot_at(_float_at)
	_spot_hooked = int(spot["spot"]) if not spot.is_empty() and int(spot["pond"]) == landed else -1
	_hooked = _roll_fish(_depth_hooked, _spot_hooked >= 0)
	if _hooked == null:
		_abandon("Nothing lives in this water.")
		return
	_splash_down()


func _splash_down() -> void:
	_state = State.WAITING
	_phase_total = _hooked.patience * lerpf(1.0, Balance.FISHING_SKILL_WAIT_FLOOR, _skill())
	if _spot_hooked >= 0:
		_phase_total *= 0.7
	_phase_left = _phase_total
	_nibble_in = _jitter.randf_range(Balance.FISHING_NIBBLE_INTERVAL.x,
		Balance.FISHING_NIBBLE_INTERVAL.y)
	_bob_in = _jitter.randf_range(Balance.FISHING_BOB_INTERVAL.x, Balance.FISHING_BOB_INTERVAL.y)
	_announce_clock = 0.0
	_ripple_at(_pond, _float_at, 1.0)
	Vfx.sheet_burst(_float_at, SPLASH_ART, Balance.FISHING_SPLASH_SIZE)
	Vfx.sheet_burst(_float_at, RIPPLE_ART, Balance.FISHING_SPLASH_SIZE * 1.4,
		Color(1.0, 1.0, 1.0, 0.8), true)
	Sfx.play("sfx_fish_splash")
	var where: String = "deep water" if _depth_hooked > 0.6 else "the shallows"
	if _spot_hooked >= 0:
		where = "the bubbles"
	_set_prompt("Wait for a bite  ·  %s" % where, "")
	EventBus.fishing_started.emit(_phase_total)


func _tick_waiting(angler: Node2D, delta: float) -> void:
	_phase_left = maxf(_phase_left - delta, 0.0)
	_lay_line(angler, 1.0)
	_announce_clock -= delta
	if _announce_clock <= 0.0:
		_announce_clock = 0.1
		EventBus.fishing_progress.emit(1.0 - _phase_left / maxf(_phase_total, 0.01))
	# Reeling an empty line in is allowed, and it is how you re-roll a slow
	# wait: the cast is free and the seconds standing still are the price.
	if _pressed(angler):
		_abandon("The line came back empty.")
		return
	_bob_in -= delta
	if _bob_in <= 0.0:
		_bob()
		_bob_in = _jitter.randf_range(Balance.FISHING_BOB_INTERVAL.x, Balance.FISHING_BOB_INTERVAL.y)
	_nibble_in -= delta
	if _nibble_in <= 0.0 and _phase_left > 0.8:
		_nibble()
		_nibble_in = _jitter.randf_range(Balance.FISHING_NIBBLE_INTERVAL.x,
			Balance.FISHING_NIBBLE_INTERVAL.y)
	if _phase_left <= 0.0:
		_bite()


## The float's own bob: slow, small, silent, and meaningless. Shown so the
## nibble has something to be different from.
func _bob() -> void:
	_dip_float(2.5, 0.42)
	EventBus.fishing_nibble.emit(false)


## A nibble: something is interested. Two quick dips, a ring, a sound and a
## word - and, over a bubble patch, a chance the thing below is startled off.
func _nibble() -> void:
	_dip_float(5.0, 0.14)
	_ripple_at(_pond, _float_at, 0.4)
	Vfx.word(_float_at, "?", Color(0.9, 0.95, 1.0), 22)
	Sfx.play("sfx_fish_nibble")
	EventBus.fishing_nibble.emit(true)
	if _spot_hooked >= 0 and _jitter.randf() < Balance.FISHING_BUBBLE_STARTLE:
		_startle_spot(_pond, _spot_hooked)
		_spot_hooked = -1
		_hooked = _roll_fish(_depth_hooked, false)
		EventBus.fishing_failed.emit("It fled the bubbles.")
		if _hooked == null:
			_abandon("It fled.")


func _startle_spot(index: int, which: int) -> void:
	if index < 0 or index >= _ponds.size():
		return
	var spots: Array = _ponds[index]["spots"] as Array
	if which < 0 or which >= spots.size():
		return
	var spot: Dictionary = spots[which]
	spot["alive"] = false
	var bubbles: PondBubbles = spot["bubbles"] as PondBubbles
	if bubbles != null and is_instance_valid(bubbles):
		_ripple_at(index, bubbles.global_position, 0.8)
		Vfx.sheet_burst(bubbles.global_position, RIPPLE_ART, Balance.FISHING_SPLASH_SIZE,
			Color(1.0, 1.0, 1.0, 0.7), true)
		bubbles.visible = false
	Sfx.play("sfx_fish_escape")


func _bite() -> void:
	_state = State.BITE
	_phase_total = Balance.FISHING_BITE_WINDOW \
		* lerpf(1.0, Balance.FISHING_SKILL_BITE_CEILING, _skill())
	_phase_left = _phase_total
	_dip_float(14.0, 0.12)
	_ripple_at(_pond, _float_at, 0.95)
	Vfx.sheet_burst(_float_at, RIPPLE_ART, Balance.FISHING_SPLASH_SIZE * 1.2,
		Color(1.0, 1.0, 1.0, 0.9), true)
	Vfx.word(_float_at, "!", Balance.FISHING_BITE_COLOUR, 34)
	Sfx.play("sfx_fish_bite")
	_set_prompt("Hook it!", "HOOK")
	EventBus.fishing_bite.emit(_phase_total)


## The bite went unanswered. The line stays in and something else will come.
func _slip() -> void:
	_learn(Balance.FISHING_XP_LOST)
	_hooked = _roll_fish(_depth_hooked, _spot_hooked >= 0)
	if _hooked == null:
		_abandon("It slipped the hook.")
		return
	_state = State.WAITING
	_phase_total = _hooked.patience * lerpf(1.0, Balance.FISHING_SKILL_WAIT_FLOOR, _skill())
	_phase_left = _phase_total
	_ripple_at(_pond, _float_at, 0.5)
	Sfx.play("sfx_fish_escape")
	EventBus.fishing_failed.emit("It slipped the hook.")
	_set_prompt("Wait for a bite", "")
	EventBus.fishing_started.emit(_phase_total)


# --- The reel ------------------------------------------------------------------

func _hook() -> void:
	_state = State.REELING
	var rarity: int = clampi(int(_hooked.rarity), 0, Balance.FISHING_FIGHT_BY_RARITY.size() - 1)
	_fight = Balance.FISHING_FIGHT_BY_RARITY[rarity] \
		* lerpf(1.0, Balance.FISHING_SKILL_FIGHT_FLOOR, _skill())
	_fight *= 1.0 + _depth_hooked * Balance.FISHING_DEPTH_FIGHT_BONUS
	if _spot_hooked >= 0:
		_fight *= 1.0 + Balance.FISHING_BUBBLE_FIGHT_BONUS
	_reel_seconds = Balance.FISHING_REEL_SECONDS_BY_RARITY[rarity]
	_band_half = lerpf(Balance.FISHING_SAFE_BAND_MIN, Balance.FISHING_SAFE_BAND_MAX, _skill())
	_band_centre = Balance.FISHING_SAFE_BAND_CENTRE
	_band_drift = Balance.FISHING_BAND_DRIFT_BY_RARITY[rarity] \
		* lerpf(1.0, Balance.FISHING_SKILL_DRIFT_FLOOR, _skill())
	_band_velocity = 0.0
	_band_turn_in = 0.0
	_tension = _band_centre * 0.5
	_progress = 0.0
	_grip = 1.0
	_pulling = false
	_fight_left = _jitter.randf_range(0.4, 0.9)
	_click_in = 0.0
	_ripple_at(_pond, _float_at, 0.7)
	Sfx.play("sfx_fish_hook")
	_set_prompt("Hold to reel  ·  keep the line in the band", "REEL")


func _tick_reel(angler: Node2D, delta: float) -> void:
	var holding: bool = _holding(angler)
	_fight_left -= delta
	if _fight_left <= 0.0:
		_pulling = not _pulling
		_fight_left = _jitter.randf_range(0.5, 1.3) if _pulling else _jitter.randf_range(0.7, 1.9)
		if _pulling:
			_ripple_at(_pond, _float_at, 0.55)
			_dip_float(7.0, 0.14)
	if holding:
		_tension += Balance.FISHING_REEL_RATE * delta
		_click_in -= delta
		if _click_in <= 0.0:
			_click_in = Balance.FISHING_REEL_CLICK
			Sfx.play("sfx_fish_reel")
	else:
		_tension -= Balance.FISHING_SLACK_RATE * delta
	if _pulling:
		_tension += _fight * Balance.FISHING_PULL_RATE * delta
	else:
		_tension -= _fight * Balance.FISHING_PULL_RATE * 0.25 * delta
	_tension = clampf(_tension, 0.0, 1.0)

	# The band drifts: the fish darts, and the band is where it is now.
	_band_turn_in -= delta
	if _band_turn_in <= 0.0:
		_band_turn_in = _jitter.randf_range(0.35, 1.0)
		_band_velocity = _jitter.randf_range(-_band_drift, _band_drift) * (1.6 if _pulling else 1.0)
	_band_centre = clampf(_band_centre + _band_velocity * delta,
		_band_half + 0.04, 0.96 - _band_half)
	var low: float = _band_centre - _band_half
	var high: float = _band_centre + _band_half

	if _tension >= 1.0:
		_snap()
		return
	var rarity: int = clampi(int(_hooked.rarity), 0, Balance.FISHING_GRIP_DRAIN_BY_RARITY.size() - 1)
	if _tension >= low and _tension <= high:
		_progress += delta / _reel_seconds
		_grip = minf(_grip + Balance.FISHING_GRIP_REFILL * delta, 1.0)
	else:
		_grip -= Balance.FISHING_GRIP_DRAIN_BY_RARITY[rarity] * delta
		if _tension < low:
			_progress -= delta * 0.3 / _reel_seconds
		else:
			_progress += delta * 0.35 / _reel_seconds
	_progress = clampf(_progress, 0.0, 1.0)
	if _grip <= 0.0:
		_escape()
		return
	# The float walks in with the fish.
	var toward: Vector2 = _float_at.lerp(_float_from, _progress * 0.55)
	_lay_line(angler, 1.0, toward)
	EventBus.fishing_reel.emit(_tension, low, high, _progress, _grip)
	if _progress >= 1.0:
		_land()


func _snap() -> void:
	_learn(Balance.FISHING_XP_LOST)
	Vfx.spark(_float_at, Color(0.95, 0.92, 0.85), 6)
	Sfx.play("sfx_fish_snap")
	_abandon("The line snapped.")


func _escape() -> void:
	_learn(Balance.FISHING_XP_LOST)
	_ripple_at(_pond, _float_at, 0.6)
	Sfx.play("sfx_fish_escape")
	_abandon("It slipped away.")


# --- Landing -------------------------------------------------------------------

## The catch is landed: Food on the ground, the fish in the stash, the Angler
## a little better at this. A catch out of a bubble patch takes the patch
## with it - that was the thing below.
func _land() -> void:
	var kind: FishData = _hooked
	var index: int = _pond
	var at: Vector2 = _float_at
	var spot: int = _spot_hooked
	_finish_line()
	if kind == null or index < 0 or index >= _ponds.size():
		return
	_ponds[index]["stock"] = int(_ponds[index]["stock"]) - 1
	if int(_ponds[index]["stock"]) <= 0:
		(_ponds[index]["material"] as ShaderMaterial).set_shader_parameter("spent", 1.0)
	if spot >= 0:
		var spots: Array = _ponds[index]["spots"] as Array
		if spot < spots.size():
			spots[spot]["alive"] = false
			var bubbles: PondBubbles = spots[spot]["bubbles"] as PondBubbles
			if bubbles != null and is_instance_valid(bubbles):
				bubbles.visible = false

	MetaState.take_fish(kind.id)
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.LAND_FISH, [kind.id])
	elif field != null and field.has_method("spawn_loot"):
		field.call("spawn_loot", RunState.FOOD, kind.food, at)

	_ripple_at(index, at, 1.0)
	Vfx.sheet_burst(at, SPLASH_ART, Balance.FISHING_SPLASH_SIZE * 1.15)
	Vfx.ring(at, Balance.FISHING_SPLASH_RADIUS, kind.rarity_colour(), 0.5, 5.0)
	Vfx.number(at, float(kind.food), Balance.LOOT_GLOW_COLOUR, false)
	Sfx.play("sfx_fish_land")
	EventBus.preparation_warning.emit("%s landed  ·  +%d Food"
		% [kind.display_name, kind.food])
	EventBus.fish_caught.emit(kind.id, kind.food)
	var rarity: int = clampi(int(kind.rarity), 0, Balance.FISHING_XP_BY_RARITY.size() - 1)
	_learn(Balance.FISHING_XP_BY_RARITY[rarity])


## Angler experience, and the moment a level arrives.
func _learn(amount: int) -> void:
	var before: int = MetaState.profession_level(PROFESSION)
	var after: int = MetaState.gain_profession_xp(PROFESSION, amount)
	if after <= before:
		return
	var angler: Node2D = _local_hero()
	if angler != null:
		Vfx.word(angler.global_position, "Angler %d" % after, Balance.FISHING_BITE_COLOUR, 26)
	Sfx.play("sfx_profession_level")
	EventBus.preparation_warning.emit("Angler level %d" % after)


## How far along the Angler is, 0 at level 1 and 1 at the cap.
func _skill() -> float:
	return float(MetaState.profession_level(PROFESSION) - 1) \
		/ float(maxi(Balance.PROFESSION_MAX_LEVEL - 1, 1))


# --- The line and the float ----------------------------------------------------

## The line comes out, with or without a reason to say so.
func _abandon(reason: String) -> void:
	var was_out: bool = _state >= State.CASTING or _state == State.CHARGING
	if _state == State.CHARGING:
		EventBus.fishing_charge.emit(-1.0)
	_finish_line()
	if was_out and not reason.is_empty():
		EventBus.fishing_failed.emit(reason)


func _finish_line() -> void:
	var was_out: bool = _state >= State.CASTING
	if _float != null and is_instance_valid(_float):
		_float.queue_free()
	_float = null
	if _line != null and is_instance_valid(_line):
		_line.queue_free()
	_line = null
	_hooked = null
	_spot_hooked = -1
	_state = State.IDLE
	_set_prompt("", "")
	if was_out:
		EventBus.fishing_ended.emit()


func _make_float() -> void:
	if not ResourceLoader.exists(FLOAT_ART):
		return
	_float = Sprite2D.new()
	_float.texture = load(FLOAT_ART)
	_float.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_float.add_to_group(Graphics.FILTER_GROUP)
	var art: float = maxf(float(_float.texture.get_width()), 1.0)
	_float.scale = Vector2.ONE * (Balance.FISHING_FLOAT_SIZE / art)
	_float.z_as_relative = false
	_float.z_index = Balance.VFX_Z - 1
	_float.global_position = _float_from
	(host if host != null else self).add_child(_float)


func _make_line() -> void:
	_line = Line2D.new()
	_line.width = 1.5
	_line.default_color = Balance.FISHING_LINE_COLOUR
	_line.z_as_relative = false
	_line.z_index = Balance.VFX_Z - 1
	_line.antialiased = false
	(host if host != null else self).add_child(_line)


## The float in flight or on the water, and the line from the hand to it.
## `flight` is the cast's progress; the float arcs over, then sits and bobs.
func _lay_line(angler: Node2D, flight: float, resting: Vector2 = Vector2.INF) -> void:
	var hand: Vector2 = _hand_of(angler)
	var end: Vector2 = _float_at if resting == Vector2.INF else resting
	var at: Vector2 = end
	if flight < 1.0:
		at = _float_from.lerp(end, flight)
		at.y -= sin(flight * PI) * Balance.FISHING_CAST_ARC * lerpf(0.7, 1.4, _charge)
	elif _state != State.MISSED:
		at.y += sin(_clock * 2.6) * 1.5 - Balance.FISHING_FLOAT_LIFT * 0.25
	if _float != null and is_instance_valid(_float):
		_float.global_position = at
	if _line != null and is_instance_valid(_line):
		var sag: Vector2 = hand.lerp(at, 0.5) + Vector2(0.0, 10.0 * (1.0 if flight >= 1.0 else 0.3))
		_line.global_position = Vector2.ZERO
		_line.points = PackedVector2Array([hand, sag, at])


func _dip_float(depth: float, seconds: float) -> void:
	if _float == null or not is_instance_valid(_float):
		return
	var tween: Tween = _float.create_tween()
	tween.tween_property(_float, "position:y", _float.position.y + depth, seconds) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_float, "position:y", _float.position.y, seconds * 1.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Where the line leaves the angler: the chest, like a swing or an arrow.
func _hand_of(angler: Node2D) -> Vector2:
	if angler.has_method("combat_origin"):
		return angler.call("combat_origin") as Vector2
	return angler.global_position + Vector2(0.0, -Balance.FISHING_FLOAT_LIFT)


# --- What bites ----------------------------------------------------------------

## Picks what is on the line, by weight, among the fish that live here.
##
## The Angler, the depth and a bubble patch each tilt the odds toward the
## rarer fish, and each only a little: every bonus scales with rarity so a
## Common is never *less* likely than it was, only less likely relative to the
## Rare beside it.
func _roll_fish(depth: float, in_spot: bool) -> FishData:
	var eligible: Array[FishData] = []
	var weights: Array[float] = []
	var total: float = 0.0
	var skill: float = _skill()
	var top: float = float(maxi(FishData.Rarity.size() - 1, 1))
	for kind: FishData in ContentDB.fish_sorted():
		if not kind.lives_in(RunState.terrain_id):
			continue
		var rank: float = float(kind.rarity) / top
		var tilt: float = 1.0 + skill * Balance.FISHING_SKILL_RARE_BONUS * rank \
			+ depth * Balance.FISHING_DEPTH_RARE_BONUS * rank \
			+ (Balance.FISHING_BUBBLE_RARE_BONUS * rank if in_spot else 0.0)
		var weight: float = maxf(kind.weight, 0.0) * tilt
		eligible.append(kind)
		weights.append(weight)
		total += weight
	if eligible.is_empty() or total <= 0.0:
		return null
	var rng: RandomNumberGenerator = RunState.rng("fishing")
	var target: float = rng.randf() * total
	for index: int in eligible.size():
		target -= weights[index]
		if target <= 0.0:
			return eligible[index]
	return eligible[eligible.size() - 1]


# --- Plumbing ------------------------------------------------------------------

## This machine's own player, not the partner's. See `CoopHeroes`.
func _local_hero() -> Node2D:
	if field == null:
		return null
	var who := field.get("hero") as Node2D
	if who == null or not who.has_method("is_alive"):
		return null
	return who if bool(who.call("is_alive")) else null


## The cast, the hook: an edge, read through the hero's own input source so a
## key, a pad button and a thumb all arrive by the same road.
func _pressed(angler: Node2D) -> bool:
	var source := angler.get("input") as HeroInput
	return source != null and source.pressed(HeroInput.BUTTON_INTERACT)


## The reel and the charge: a level.
func _holding(angler: Node2D) -> bool:
	var source := angler.get("input") as HeroInput
	return source != null and source.held(HeroInput.HOLD_INTERACT)


func _set_prompt(text: String, button: String) -> void:
	if text == _prompt and button == _prompt_button:
		return
	_prompt = text
	_prompt_button = button
	EventBus.fishing_prompt.emit(text, button)


func _on_hero_damaged(_amount: float, _from: Vector2, _at: Vector2) -> void:
	if _state >= State.CASTING or _state == State.CHARGING:
		_abandon("The blow took the line out.")


# --- For the gate --------------------------------------------------------------

func pond_count() -> int:
	return _ponds.size()


func stocked_count() -> int:
	var open: int = 0
	for pond: Dictionary in _ponds:
		if int(pond["stock"]) > 0:
			open += 1
	return open


## Where the ponds are, for the gate and for anything that needs to avoid them.
func pond_positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for pond: Dictionary in _ponds:
		out.append(pond["at"] as Vector2)
	return out


## The half-size of each pond, in the same order as `pond_positions`.
func pond_extents() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for pond: Dictionary in _ponds:
		out.append(pond["half"] as Vector2)
	return out


## How many water cells each pond drew, in the same order.
func pond_cell_counts() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for pond: Dictionary in _ponds:
		var layer: TileMapLayer = pond["layer"] as TileMapLayer
		out.append(layer.get_used_cells().size() if layer != null else 0)
	return out


## How many bubble patches each pond holds, alive or not.
func spot_counts() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for pond: Dictionary in _ponds:
		out.append((pond["spots"] as Array).size())
	return out


## Where a pond's first living patch is, or INF.
func spot_position(index: int) -> Vector2:
	if index < 0 or index >= _ponds.size():
		return Vector2.INF
	for spot: Dictionary in (_ponds[index]["spots"] as Array):
		if bool(spot["alive"]):
			var bubbles: PondBubbles = spot["bubbles"] as PondBubbles
			if bubbles != null and is_instance_valid(bubbles):
				return bubbles.global_position
	return Vector2.INF


## Whether a line is in the water right now.
func is_fishing() -> bool:
	return _state >= State.CASTING


func state() -> State:
	return _state


## The reel, for the gate: tension and how far in the fish is.
func reel_state() -> Vector2:
	return Vector2(_tension, _progress)


func grip() -> float:
	return _grip


func charge() -> float:
	return _charge


## The depth the line is in, for the gate.
func hooked_depth() -> float:
	return _depth_hooked
