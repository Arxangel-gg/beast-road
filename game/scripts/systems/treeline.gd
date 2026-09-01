class_name Treeline
extends Node2D

## Trees, beyond where the game is played.
##
## The field ends at the build grid and the ground beyond it was empty, so the
## map read as a board rather than as a clearing in a place. Trees fill that
## outside, and where they may stand is the whole design: **not one of them is
## inside the grid.** A tree among the roads would hide a lane, block a tower
## slot, or sit under a click - and the answer to all three is that trees do not
## grow where the player builds.
##
## Two exclusions, both derived rather than typed:
##
## 1. **Outside the build grid.** `BattleGrid.in_bounds` is the authority on
##    where a tower can go, so it is the authority on where a tree cannot.
## 2. **Clear of the lane mouths.** Enemies walk in along lanes that begin at the
##    grid edge; a tree across a mouth would hide the thing the player most needs
##    to see arriving. Each lane's outward heading is kept open.
##
## Sorted by trunk, not by centre. Each tree's origin sits at the base of its
## trunk and the node y-sorts its children, so a hero standing in front of a tree
## occludes it and one behind does not - decided by the bottom pixels of both,
## which is the only comparison that reads as ground contact.

## One tree per region. Path derived from the region id, like every other asset.
const TREE_ART_FORMAT: String = "res://art/foliage/tree_%s.png"
const TREE_VARIANT_FORMAT: String = "res://art/foliage/tree_%s_%02d.png"

## How the treeline reads in each region.
##
## Density is trees per attempt over the ring, and the two numbers do most of the
## characterisation: a jungle closes in, a waste is a scattering of survivors,
## a snowfield stands somewhere between with the trees in loose stands. Scale
## spread does the rest - uniform trees read as wallpaper. [TUNE]
const REGIONS: Dictionary = {
	"jungle": {"density": 1.0, "clump": 0.62},
	"desert": {"density": 0.34, "clump": 0.16},
	"snow": {"density": 0.62, "clump": 0.44},
}

## Where a tree's origin sits inside its art, as a fraction of height.
##
## Just above the bottom edge rather than exactly on it: the art carries a little
## ground under the trunk - roots, sand, a drift - and anchoring at the very
## bottom of the image would sort the tree by the edge of that ground rather than
## by where the trunk meets it.
const TRUNK_ANCHOR: float = 0.94

var grid: BattleGrid = null

## Where the trees are actually parented.
##
## **Not this node.** Children of a system node sort at *that node's* position,
## so every tree in the act would draw at the origin's depth - which is the town.
## Handing them to the battlefield's y-sorted entity layer is what makes a hero
## walking in front of a trunk occlude it. Wildlife does the same thing for the
## same reason.
var host: Node2D = null

var _trees: Array[Sprite2D] = []

## Trees with an authored idle sequence, and where each is in it. Stepped on one
## shared clock, like the foliage field's - a texture assignment five times a
## second rather than a transform sixty times a second on two hundred nodes.
var _animated: Array[Dictionary] = []
var _idle_clock: float = 0.0
var _idle_frame: int = 0

## Leaves coming off this treeline. Owned here because it needs the canopies.
var _leaves: Leaffall = null


## Re-grows the treeline for the current region.
func scatter() -> void:
	for tree: Sprite2D in _trees:
		if is_instance_valid(tree):
			tree.queue_free()
	_trees.clear()
	# Cleared with the trees they belonged to. A stale entry here is a freed
	# sprite walked every animation step.
	_animated.clear()

	var region: String = RunState.terrain_id
	var art: Array[Texture2D] = _region_art(region)
	if art.is_empty():
		return
	var shape: Dictionary = REGIONS.get(region, REGIONS["jungle"])

	var rng := RandomNumberGenerator.new()
	# Seeded per region, so an act looks the same every time it is entered rather
	# than reshuffling its forest whenever the scope is left and returned to.
	rng.seed = hash("treeline:" + region)

	var mouths: Array[Vector2] = _lane_mouths()
	var wanted: int = int(round(float(Balance.TREELINE_ATTEMPTS) * float(shape["density"])
		* Graphics.foliage_scale()))
	var span: Vector2 = _scale_span(region)
	var placed: int = 0
	for attempt: int in Balance.TREELINE_ATTEMPTS:
		if placed >= wanted:
			break
		var at: Vector2 = _outside_point(rng, shape)
		if not _is_clear(at, mouths):
			continue
		if not _has_trunk_room(at):
			continue
		var tree_scale: float = rng.randf_range(span.x, span.y)
		if rng.randf() < Balance.TREELINE_GIANT_CHANCE:
			tree_scale *= rng.randf_range(Balance.TREELINE_GIANT_SCALE.x,
				Balance.TREELINE_GIANT_SCALE.y)
		_plant(art[rng.randi_range(0, art.size() - 1)], at, tree_scale, rng)
		placed += 1
	_refresh_leaves(region)


func _region_art(region: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var base_path: String = TREE_ART_FORMAT % region
	if ResourceLoader.exists(base_path):
		out.append(load(base_path) as Texture2D)
	for index: int in range(1, 9):
		var path: String = TREE_VARIANT_FORMAT % [region, index]
		if ResourceLoader.exists(path):
			out.append(load(path) as Texture2D)
	return out


func _has_trunk_room(at: Vector2) -> bool:
	for tree: Sprite2D in _trees:
		if is_instance_valid(tree) \
				and at.distance_to(tree.position) < Balance.TREELINE_TRUNK_SPACING:
			return false
	return true


## How many trees are standing. For the gate.
func count() -> int:
	return _trees.size()


## A point in the ring outside the grid.
##
## Rejection against the grid rather than arithmetic on a square: the grid is the
## authority on its own extent, and a radius that merely *ought* to clear it is a
## radius that stops clearing it the day the grid changes size.
func _outside_point(rng: RandomNumberGenerator, shape: Dictionary) -> Vector2:
	var half: float = float(BattleGrid.SIZE) * BattleGrid.TILE * 0.5
	for i: int in 8:
		# Biased outward from the grid edge, then clumped: trees gather. An even
		# scatter over a ring reads as a texture rather than as woodland.
		var lean: float = pow(rng.randf(), 1.0 - float(shape["clump"]) * 0.5)
		var radius: float = half * 1.02 + lean * (Balance.TREELINE_REACH - half)
		var at: Vector2 = Vector2.RIGHT.rotated(rng.randf() * TAU) * radius
		if not BattleGrid.in_bounds(BattleGrid.world_to_tile(at)):
			return at
	return Vector2.RIGHT.rotated(rng.randf() * TAU) * Balance.TREELINE_REACH


## Where each lane meets the edge, pointing outward.
func _lane_mouths() -> Array[Vector2]:
	var out: Array[Vector2] = []
	if grid == null:
		return out
	for path: Variant in grid.lane_paths:
		var points: PackedVector2Array = path as PackedVector2Array
		if points.size() > 0:
			# Index 0 is the spawn edge; `lane_paths` is ordered from there.
			out.append(points[0])
	return out


func _is_clear(at: Vector2, mouths: Array[Vector2]) -> bool:
	if BattleGrid.in_bounds(BattleGrid.world_to_tile(at)):
		return false
	for mouth: Vector2 in mouths:
		# Distance to the ray running outward from the mouth, not to the mouth
		# itself: enemies walk in along that line and a tree anywhere on it hides
		# them just as well as one standing on the mouth.
		var outward: Vector2 = mouth.normalized()
		var along: float = at.dot(outward)
		if along <= 0.0:
			continue
		var sideways: float = (at - outward * along).length()
		if sideways < Balance.TREELINE_LANE_CLEARANCE:
			return false
	return true


func _plant(art: Texture2D, at: Vector2, size: float,
		rng: RandomNumberGenerator) -> void:
	var tree := Sprite2D.new()
	tree.texture = art
	tree.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	# Per region: a snow conifer and a jungle broadleaf must not lean by the same
	# angle. Still one material per region rather than one per tree, so two hundred
	# trees cost one material and the weather reaches all of them in one write.
	tree.material = Foliage.canopy_material(RunState.terrain_id)
	tree.add_to_group(Graphics.FILTER_GROUP)
	tree.add_to_group("ambient_tree")
	# Origin at the trunk, so the node's own y is where it touches the ground -
	# which is what `y_sort_enabled` on this node then sorts by.
	tree.offset = Vector2(0.0, -float(art.get_height()) * TRUNK_ANCHOR)
	tree.position = at
	tree.scale = Vector2(
		size * rng.randf_range(Balance.TREELINE_WIDTH_VARIATION.x,
			Balance.TREELINE_WIDTH_VARIATION.y),
		size * rng.randf_range(Balance.TREELINE_HEIGHT_VARIATION.x,
			Balance.TREELINE_HEIGHT_VARIATION.y))
	tree.rotation = deg_to_rad(rng.randf_range(-Balance.TREELINE_LEAN_DEGREES,
		Balance.TREELINE_LEAN_DEGREES))
	# Mirrored half the time, and tinted a shade either way. One silhouette
	# repeated two hundred times is wallpaper; the same silhouette flipped and
	# shaded is a wood.
	tree.flip_h = rng.randf() < 0.5
	var shade: float = rng.randf_range(Balance.TREELINE_SHADE.x,
		Balance.TREELINE_SHADE.y)
	var temperature: float = rng.randf_range(-0.035, 0.035)
	tree.modulate = Color(shade + temperature, shade,
		shade - temperature * 0.55)
	var parent: Node2D = host if host != null and is_instance_valid(host) else self
	parent.add_child(tree)
	_trees.append(tree)
	# A tree with authored frames breathes as well as leaning. Both are supported
	# and neither is required: dropping `_idle_01.png` beside the sprite is the
	# whole of adding an animation, exactly as it is for a painted plant.
	var frames: Array[Texture2D] = Foliage.idle_sequence(art)
	if not frames.is_empty():
		_animated.append({"sprite": tree, "frames": frames,
			"phase": _animated.size()})


func _scale_span(region: String) -> Vector2:
	match region:
		"desert":
			return Balance.TREELINE_DESERT_SCALE
		"snow":
			return Balance.TREELINE_SNOW_SCALE
		_:
			return Balance.TREELINE_JUNGLE_SCALE


## Steps every animated tree on one shared clock.
##
## The same rule the foliage field uses, and for the same reason: two hundred
## trees advancing on one integer index cost one comparison per frame and a
## texture assignment only on the steps where the index actually changes.
func _process(delta: float) -> void:
	if _animated.is_empty():
		return
	_idle_clock += delta * Balance.FOLIAGE_IDLE_FRAME_RATE
	var step: int = int(_idle_clock)
	if step == _idle_frame:
		return
	_idle_frame = step
	for entry: Dictionary in _animated:
		var sprite: Sprite2D = entry["sprite"]
		if not is_instance_valid(sprite):
			continue
		var frames: Array = entry["frames"]
		sprite.texture = frames[(step + int(entry["phase"])) % frames.size()]


## Hands the leaf system the canopies it sheds from.
##
## Told rather than searched: a group query per fall would build an array of two
## hundred nodes to pick one of them, and this list already exists.
##
## The canopy point is the crown, not the node position - the node sits at the
## trunk's ground contact, and a leaf that appears there and falls has fallen
## from the roots.
func _refresh_leaves(region: String) -> void:
	if _leaves == null:
		_leaves = Leaffall.new()
		_leaves.name = "Leaffall"
		var parent: Node2D = host if host != null and is_instance_valid(host) else self
		parent.add_child(_leaves)
	var canopies: Array[Array] = []
	for tree: Sprite2D in _trees:
		if not is_instance_valid(tree) or tree.texture == null:
			continue
		var height: float = float(tree.texture.get_height()) * tree.scale.y
		var half_width: float = float(tree.texture.get_width()) * tree.scale.x * 0.35
		canopies.append([tree.position, height, half_width])
	_leaves.set_canopies(canopies, region)
