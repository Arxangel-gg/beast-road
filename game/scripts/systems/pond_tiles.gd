class_name PondTiles
extends RefCounted

## The geometry of a pond: a blob of water on a lattice, and the Wang tiles
## that draw its edge.
##
## **Procedural in shape, not in placement.** `Fishing` decides where a pond may
## sit; this decides what one looks like once it is there. A pond is a set of
## water *nodes* on a lattice, and the tiles are the squares *between* nodes -
## each tile shows water in whichever of its four corners is a water node. That
## is the 2-corner Wang convention PixelLab's topdown tilesets are drawn to,
## and it is why a blob of any shape needs exactly sixteen tiles to draw.
##
## **The sheet is canonical.** `tools/install_pond_tiles.py` repacks every
## region's generated sheet into corner order - tile index = NW·8 + NE·4 +
## SW·2 + SE, four across - so nothing here reads per-region metadata. A region
## is a texture at the conventional path and nothing else.
##
## Static and autoload-free, like `TowerData`: the headless tools load it.

const TILE: int = 32
const SHEET_ACROSS: int = 4

## One TileSet per texture, shared by every pond that uses it. A `TileSet` is
## sixteen atlas tiles and nothing a pond changes, so six ponds building six of
## them would be six copies of the same thing.
static var _sets: Dictionary = {}


## A TileSet over a canonical 4x4 sheet.
static func tileset_for(texture: Texture2D) -> TileSet:
	var key: String = texture.resource_path
	if not key.is_empty() and _sets.has(key):
		return _sets[key] as TileSet
	var set := TileSet.new()
	set.tile_size = Vector2i(TILE, TILE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE, TILE)
	for index: int in 16:
		source.create_tile(atlas_coords(index))
	set.add_source(source, 0)
	if not key.is_empty():
		_sets[key] = set
	return set


## Where a corner-indexed tile sits on the canonical sheet.
static func atlas_coords(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % SHEET_ACROSS, index / SHEET_ACROSS)


static func tile_index(nw: bool, ne: bool, sw: bool, se: bool) -> int:
	return (8 if nw else 0) + (4 if ne else 0) + (2 if sw else 0) + (1 if se else 0)


## A blob of water nodes on a `width` x `height` lattice, from the run's stream.
##
## An ellipse with one to three lobes pushed off-centre, a little roughness on
## the rim, and then the largest connected piece kept - so a pond is one body
## of water rather than a puddle beside a puddle. The roughness is bounded so
## a rim never grows the one-node spits that draw as a single water corner
## poking out of dry ground.
static func shape(rng: RandomNumberGenerator, width: int, height: int) -> Array[Vector2i]:
	var cx: float = float(width - 1) * 0.5
	var cy: float = float(height - 1) * 0.5
	var rx: float = maxf(float(width) * 0.5, 1.0)
	var ry: float = maxf(float(height) * 0.5, 1.0)
	var lobes: Array[Vector3] = []
	for _lobe: int in rng.randi_range(1, 3):
		lobes.append(Vector3(rng.randf_range(-rx * 0.45, rx * 0.45),
			rng.randf_range(-ry * 0.45, ry * 0.45), rng.randf_range(0.5, 0.85)))
	var water: Dictionary = {}
	for y: int in height:
		for x: int in width:
			var px: float = (float(x) - cx) / rx
			var py: float = (float(y) - cy) / ry
			var d: float = px * px + py * py
			for lobe: Vector3 in lobes:
				var lx: float = (float(x) - cx - lobe.x) / (rx * lobe.z)
				var ly: float = (float(y) - cy - lobe.y) / (ry * lobe.z)
				d = minf(d, lx * lx + ly * ly)
			if d + rng.randf_range(-0.1, 0.1) < 0.82:
				water[Vector2i(x, y)] = true
	return _largest_body(water)


## The biggest connected set of nodes, four-connected.
static func _largest_body(water: Dictionary) -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	var seen: Dictionary = {}
	for start: Variant in water:
		if seen.has(start):
			continue
		var body: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start as Vector2i]
		seen[start] = true
		while not stack.is_empty():
			var node: Vector2i = stack.pop_back()
			body.append(node)
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = node + step
				if water.has(next) and not seen.has(next):
					seen[next] = true
					stack.append(next)
		if body.size() > best.size():
			best = body
	return best


## Lays the tiles for a body of water onto a layer.
##
## The lattice has `width` x `height` nodes, so there are `width + 1` by
## `height + 1` tiles around them; node (x, y) is the SE corner of tile (x, y)
## and the NW corner of tile (x + 1, y + 1). A tile with no water corner is
## left unset rather than drawn as bank - the mask would hide it anyway, and an
## unset cell is a cell the renderer never touches.
static func lay(layer: TileMapLayer, nodes: Array[Vector2i], width: int, height: int) -> void:
	var water: Dictionary = {}
	for node: Vector2i in nodes:
		water[node] = true
	layer.clear()
	for j: int in height + 1:
		for i: int in width + 1:
			var index: int = tile_index(
				water.has(Vector2i(i - 1, j - 1)), water.has(Vector2i(i, j - 1)),
				water.has(Vector2i(i - 1, j)), water.has(Vector2i(i, j)))
			if index == 0:
				continue
			layer.set_cell(Vector2i(i, j), 0, atlas_coords(index))


## Where a node sits in the layer's own pixels.
static func node_px(node: Vector2i) -> Vector2:
	return Vector2(float(node.x + 1) * TILE, float(node.y + 1) * TILE)


## The blend mask the water shader reads, and the fishing code samples: red
## fades the generated bank into the painted field, green marks the deep water
## the light may land on, **blue is depth** - how far from the bank a texel
## is, 0 at the rim and 1 at the deepest node - which is what tints the middle
## darker and decides where the rare fish live.
##
## Built at an eighth of the pond's resolution. The sampler is linear, so an
## eight-pixel ramp is smooth on screen, and it keeps the distance field to a
## few thousand operations per pond rather than a few hundred thousand - this
## runs on every region change, on a phone, for every pond at once.
const MASK_STEP: int = 8


static func mask(nodes: Array[Vector2i], width: int, height: int) -> ImageTexture:
	return ImageTexture.create_from_image(mask_image(nodes, width, height))


static func mask_image(nodes: Array[Vector2i], width: int, height: int) -> Image:
	var px_w: int = (width + 1) * TILE
	var px_h: int = (height + 1) * TILE
	@warning_ignore("integer_division")
	var image: Image = Image.create(px_w / MASK_STEP, px_h / MASK_STEP, false, Image.FORMAT_RGB8)
	var centres: PackedVector2Array = []
	var depths: PackedFloat32Array = []
	var by_node: Dictionary = node_depths(nodes)
	for node: Vector2i in nodes:
		centres.append(node_px(node))
		depths.append(float(by_node.get(node, 0.0)))
	for y: int in image.get_height():
		for x: int in image.get_width():
			var at := Vector2(float(x) * MASK_STEP + MASK_STEP * 0.5,
				float(y) * MASK_STEP + MASK_STEP * 0.5)
			var nearest: float = INF
			var depth: float = 0.0
			# Depth is the inverse-distance blend of the two nearest nodes'
			# own depths, so it ramps between lattice points rather than
			# stepping at the midline between them.
			var best_a: float = INF
			var best_b: float = INF
			var depth_a: float = 0.0
			var depth_b: float = 0.0
			for index: int in centres.size():
				var gap: float = at.distance_to(centres[index])
				nearest = minf(nearest, gap)
				if gap < best_a:
					best_b = best_a
					depth_b = depth_a
					best_a = gap
					depth_a = depths[index]
				elif gap < best_b:
					best_b = gap
					depth_b = depths[index]
			if best_a < INF:
				var wa: float = 1.0 / maxf(best_a, 1.0)
				var wb: float = 1.0 / maxf(best_b, 1.0) if best_b < INF else 0.0
				depth = (depth_a * wa + depth_b * wb) / (wa + wb)
			# The bank is drawn in the half-tile around a water node; past a
			# full tile it is gone. Deep water is the inner third.
			var edge: float = 1.0 - smoothstep(20.0, float(TILE), nearest)
			var deep: float = 1.0 - smoothstep(11.0, 17.0, nearest)
			image.set_pixel(x, y, Color(edge, deep, depth * deep))
	return image


## How deep each water node is: steps to the nearest node that is not water,
## normalised so the deepest node in the pond is 1. A rim node is 0.
static func node_depths(nodes: Array[Vector2i]) -> Dictionary:
	var water: Dictionary = {}
	for node: Vector2i in nodes:
		water[node] = true
	var steps: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for node: Vector2i in nodes:
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not water.has(node + step):
				steps[node] = 0
				frontier.append(node)
				break
	var deepest: int = 0
	while not frontier.is_empty():
		var node: Vector2i = frontier.pop_front()
		var here: int = int(steps[node])
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = node + step
			if water.has(next) and not steps.has(next):
				steps[next] = here + 1
				deepest = maxi(deepest, here + 1)
				frontier.append(next)
	var out: Dictionary = {}
	for node: Vector2i in nodes:
		out[node] = float(int(steps.get(node, 0))) / float(maxi(deepest, 1))
	return out


## The depth under a point in the layer's own pixels, 0 on dry ground.
static func depth_at(image: Image, local_px: Vector2) -> float:
	if image == null:
		return 0.0
	var x: int = int(floor(local_px.x / MASK_STEP))
	var y: int = int(floor(local_px.y / MASK_STEP))
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return 0.0
	var texel: Color = image.get_pixel(x, y)
	# Wet at all is the green channel; how deep is the blue. A swimmer wants
	# "am I in water" more than "how deep", so the shallows count a little.
	return maxf(texel.b, texel.g * 0.35)


## A polished `smoothstep` for the mask; GDScript has no built-in.
static func smoothstep(from: float, to: float, value: float) -> float:
	var t: float = clampf((value - from) / maxf(to - from, 0.0001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
