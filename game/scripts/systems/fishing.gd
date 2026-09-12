class_name Fishing
extends Node2D

## Ponds at the edge of the field, and the line you put in them.
##
## **The second cut of fishing, 2026-09-11.** The first put a line in the water
## the moment the hero stood still beside a pond, and the owner played it and
## asked for two things it did not do: it did not happen ("fishing did not
## happen automatically while standing idle next to a fishing pond" - the beast's
## footfall kept the body's velocity above the stillness threshold for most of a
## second after every step, so "still" was a state a hero on a moving beast
## almost never reached), and once it did happen it asked nothing of the player.
##
## **What it is now.** Stand by water and *cast* - a press. Wait. Something
## nibbles, then bites, and the bite is a window: hook it in time or it slips.
## Then reel: hold to take line in, let go to give it, and keep the tension in
## the band while the fish fights. Too tight and the line snaps; slack for too
## long and it is gone. That is a catch a player made rather than one they
## waited for, and it is why a Legendary on the bank means something.
##
## **The Angler level is the first profession**, and its bound is that it
## touches nothing but fishing: a wider bite window, a wider band, a shorter
## wait, a weaker fight and a slightly better chance at the rare fish. No damage,
## no health, no attribute - it is a skill at a thing, not a scale of power
## beside levelling and gear (CLAUDE.md working rule 7). It persists as
## `MetaState.profession_xp`, and the amendment is recorded there.
##
## **Where a pond sits is the owner's ruling too**: around the edge of the map,
## beyond where the roads begin, off the roads and off the spawn mouths. Inside
## the grid still, because the hero is clamped to it and water they can see and
## never reach is the failure the first cut was built to avoid.
##
## **The water is a tilemap, not a picture.** Each region has a sixteen-tile
## Wang sheet at the conventional path, and a pond is a blob of water nodes on a
## lattice drawn with those tiles - so every pond is a different shape and size
## and every region's water is its own. `PondTiles` owns the geometry and
## `pond_water.gdshader` owns the light on it.
##
## **Both machines grow the same ponds and neither is told about them.** The
## dig is seeded from the run seed and the region, on a generator of its own
## rather than the shared fishing stream - because the *catches* draw on that
## stream, and a host that had caught three fish before the region changed
## would otherwise dig different ponds from a guest that had caught none.

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
	"jungle": {"ponds": 5, "width": Vector2i(4, 7), "height": Vector2i(3, 4)},
	"desert": {"ponds": 2, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"snow": {"ponds": 3, "width": Vector2i(4, 6), "height": Vector2i(3, 4)},
	"hollow_marches": {"ponds": 6, "width": Vector2i(4, 8), "height": Vector2i(3, 4)},
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

enum State { IDLE, READY, CASTING, WAITING, BITE, REELING }

var grid: BattleGrid = null

## The scope the ponds are in. Asked for the hero whose line this is and for
## somewhere to put the Food, rather than reaching up the tree for either.
var field: Node = null

## Where the ponds are parented: the battlefield's y-sorted entity layer, so a
## hero standing in front of one occludes it.
var host: Node2D = null

## The pond records. Each is {root, layer, material, at, half, nodes, stock,
## ripples, cursor, ambient_in}.
var _ponds: Array[Dictionary] = []

var _state: State = State.IDLE
## The pond in play: the nearest one while READY, the one the line is in after.
var _pond: int = -1
## The water's own clock, fed to every shader so a ring's birth and the time it
## is measured against are the same clock.
var _clock: float = 0.0
var _phase_left: float = 0.0
var _phase_total: float = 0.0
var _nibble_in: float = 0.0
var _hooked: FishData = null
var _tension: float = 0.0
var _progress: float = 0.0
var _fight: float = 0.0
var _fight_left: float = 0.0
var _pulling: bool = false
var _reel_seconds: float = 1.0
var _slack_for: float = 0.0
var _click_in: float = 0.0
var _float: Sprite2D = null
var _line: Line2D = null
var _float_at: Vector2 = Vector2.ZERO
var _float_from: Vector2 = Vector2.ZERO
var _announce_clock: float = 0.0
var _prompt: String = ""
var _prompt_button: String = ""
## Cosmetic timing - nibbles, the fish's rhythm, the ambient stir. Not the run's
## stream, because nothing here decides what is caught.
var _jitter: RandomNumberGenerator = RandomNumberGenerator.new()


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

	# Its own generator, seeded from the run and the region. See the class note
	# for why this is not the shared fishing stream.
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("ponds:" + region)
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
		_dig(tiles, at, half, nodes, width, height)


## Every open tile in the outer band of the field, in grid order.
##
## The owner's ruling: ponds sit around the edges of the map, beyond where the
## roads begin. Inside the grid still - the hero is clamped to it, so a pond out
## past the rim would be water the player can see and never reach. Drawn from
## the tiles rather than from a random point, because the open ground out there
## is four corner pockets and a random point in the band lands in one of them
## about once in five hundred throws - the first version of this dug nothing.
static func band_tiles(on: BattleGrid, band: float) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var floor_distance: float = band * (BattleGrid.HALF_EXTENT - BattleGrid.TILE * 2.0)
	for y: int in range(1, BattleGrid.SIZE - 1):
		for x: int in range(1, BattleGrid.SIZE - 1):
			var tile := Vector2i(x, y)
			if on.cell_at(tile) != BattleGrid.Cell.OPEN:
				continue
			if BattleGrid.tile_to_world(tile).length() < floor_distance:
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
## Four refusals, each derived from something that already knows the answer:
## every tile under it *and a ring of tiles around it* open ground by the
## grid - which is what keeps water off the roads and the border, on the
## grid's own cells rather than on the lane's forty waypoints - clear of the
## spawn mouths so the first wave does not walk out of a lake, clear of the
## town, and clear of the other ponds.
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
	for pond: Dictionary in _ponds:
		var other: Rect2 = Rect2((pond["at"] as Vector2) - (pond["half"] as Vector2),
			(pond["half"] as Vector2) * 2.0)
		if rim.grow(Balance.FISHING_POND_SPACING).intersects(other):
			return false
	return true


## Every tile under `rim` is open ground, and no tile within `ring` of it is a
## road or the town. Shared with the rift gates, which want the same answer for
## the same reason.
##
## The ring tolerates the border: the outer band is where water goes, and a
## ring that refused the border row refused every corner of the map - the
## first run of this dug nothing in any region.
static func ground_is_open(on: BattleGrid, rim: Rect2, ring: int) -> bool:
	var top_left: Vector2i = BattleGrid.world_to_tile(rim.position + Vector2.ONE * 0.5)
	var bottom_right: Vector2i = BattleGrid.world_to_tile(rim.end - Vector2.ONE * 0.5)
	for y: int in range(top_left.y - ring, bottom_right.y + ring + 1):
		for x: int in range(top_left.x - ring, bottom_right.x + ring + 1):
			var cell: int = on.cell_at(Vector2i(x, y))
			var under: bool = x >= top_left.x and x <= bottom_right.x 				and y >= top_left.y and y <= bottom_right.y
			if under and cell != BattleGrid.Cell.OPEN:
				return false
			if not under and (cell == BattleGrid.Cell.ROAD or cell == BattleGrid.Cell.TOWN):
				return false
	return true


func _dig(tiles: Texture2D, at: Vector2, half: Vector2, nodes: Array[Vector2i],
		width: int, height: int) -> void:
	var root := Node2D.new()
	root.name = "Pond"
	root.scale = Vector2.ONE * Balance.FISHING_TILE_SCALE
	# Sorted by the near edge: the root sits there and the layer is lifted so
	# the water is drawn where it is.
	root.global_position = at + Vector2(0.0, half.y * SORT_ANCHOR)

	var layer := TileMapLayer.new()
	layer.name = "Water"
	layer.tile_set = PondTiles.tileset_for(tiles)
	layer.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	layer.add_to_group(Graphics.FILTER_GROUP)
	var size_px := Vector2(float(width + 1), float(height + 1)) * float(PondTiles.TILE)
	layer.position = -size_px * 0.5 - Vector2(0.0, half.y * SORT_ANCHOR / Balance.FISHING_TILE_SCALE)
	PondTiles.lay(layer, nodes, width, height)

	var material := ShaderMaterial.new()
	material.shader = load(WATER_SHADER) as Shader
	material.set_shader_parameter("mask", PondTiles.mask(nodes, width, height))
	material.set_shader_parameter("pond_size", size_px)
	material.set_shader_parameter("now", _clock)
	material.set_shader_parameter("spent", 0.0)
	var rings: PackedVector4Array = []
	rings.resize(Balance.FISHING_RIPPLE_SLOTS)
	material.set_shader_parameter("ripples", rings)
	layer.material = material
	root.add_child(layer)
	(host if host != null else self).add_child(root)

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
	})


# --- The water -----------------------------------------------------------------

func _process(delta: float) -> void:
	_clock += delta
	_tick_water(delta)
	if _ponds.is_empty():
		return
	var angler: Node2D = _local_hero()
	if angler == null or RunState.phase == RunState.Phase.ENDED:
		_abandon("")
		_set_prompt("", "")
		return
	var still: bool = _is_still(angler)
	match _state:
		State.IDLE, State.READY:
			_tick_ready(angler, still)
		State.CASTING:
			if not still:
				_abandon("The line came out.")
				return
			_phase_left -= delta
			_lay_line(angler, 1.0 - _phase_left / maxf(_phase_total, 0.01))
			if _phase_left <= 0.0:
				_splash_down()
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


## The clock into every shader, and the pond's own stir.
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
	if not still:
		_set_prompt("Stand still to cast", "")
		return
	_set_prompt("Cast a line", "CAST")
	if _pressed(angler):
		_cast(angler)


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
		if gap <= Balance.FISHING_RADIUS and gap < nearest:
			nearest = gap
			best = index
	return best


## Standing still enough to fish.
##
## The hero's *own* motion - `Hero.own_speed` subtracts the beast's shove -
## because the first cut read the body's whole velocity, and on a walking
## beast that never settled below the threshold. Being dashed or knocked still
## counts as moving, which is right: the line is out of the water in both.
func _is_still(angler: Node2D) -> bool:
	if angler.has_method("own_speed"):
		return float(angler.call("own_speed")) <= Balance.FISHING_STILL_SPEED
	var body := angler as CharacterBody2D
	if body == null:
		return true
	return body.velocity.length() <= Balance.FISHING_STILL_SPEED


# --- The cast ------------------------------------------------------------------

func _cast(angler: Node2D) -> void:
	if _pond < 0 or _pond >= _ponds.size():
		return
	var catch: FishData = _roll_fish()
	if catch == null:
		_set_prompt("Nothing lives in this water", "")
		return
	_hooked = catch
	_float_from = _hand_of(angler)
	_float_at = _nearest_water(_pond, angler.global_position)
	_state = State.CASTING
	_phase_total = Balance.FISHING_CAST_TIME
	_phase_left = _phase_total
	_make_line()
	_make_float()
	_set_prompt("", "")
	Sfx.play("sfx_fish_cast")


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


func _splash_down() -> void:
	_state = State.WAITING
	_phase_total = _hooked.patience * lerpf(1.0, Balance.FISHING_SKILL_WAIT_FLOOR, _skill())
	_phase_left = _phase_total
	_nibble_in = _jitter.randf_range(Balance.FISHING_NIBBLE_INTERVAL.x,
		Balance.FISHING_NIBBLE_INTERVAL.y)
	_announce_clock = 0.0
	_ripple_at(_pond, _float_at, 1.0)
	Vfx.sheet_burst(_float_at, SPLASH_ART, Balance.FISHING_SPLASH_SIZE)
	Vfx.sheet_burst(_float_at, RIPPLE_ART, Balance.FISHING_SPLASH_SIZE * 1.4,
		Color(1.0, 1.0, 1.0, 0.8), true)
	Sfx.play("sfx_fish_splash")
	_set_prompt("Wait for a bite", "")
	EventBus.fishing_started.emit(_phase_total)


func _tick_waiting(angler: Node2D, delta: float) -> void:
	_phase_left = maxf(_phase_left - delta, 0.0)
	_lay_line(angler, 1.0)
	# Ten a second rather than sixty. A progress bar cannot show more, and the
	# bus does not need to carry what nothing can read.
	_announce_clock -= delta
	if _announce_clock <= 0.0:
		_announce_clock = 0.1
		EventBus.fishing_progress.emit(1.0 - _phase_left / maxf(_phase_total, 0.01))
	# Reeling an empty line in is allowed, and it is how you re-roll a slow
	# wait: the cast is free and the seconds standing still are the price.
	if _pressed(angler):
		_abandon("The line came back empty.")
		return
	_nibble_in -= delta
	if _nibble_in <= 0.0 and _phase_left > 0.8:
		_nibble()
		_nibble_in = _jitter.randf_range(Balance.FISHING_NIBBLE_INTERVAL.x,
			Balance.FISHING_NIBBLE_INTERVAL.y)
	if _phase_left <= 0.0:
		_bite()


## A false bite: the float dips a little and comes back. The tell is small on
## purpose - the real bite is the one that goes under.
func _nibble() -> void:
	_dip_float(5.0, 0.16)
	_ripple_at(_pond, _float_at, 0.4)
	Sfx.play("sfx_fish_nibble")


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
	_hooked = _roll_fish()
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
	_reel_seconds = Balance.FISHING_REEL_SECONDS_BY_RARITY[rarity]
	_tension = Balance.FISHING_SAFE_BAND_CENTRE * 0.5
	_progress = 0.0
	_slack_for = 0.0
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

	var half: float = lerpf(Balance.FISHING_SAFE_BAND_MIN, Balance.FISHING_SAFE_BAND_MAX, _skill())
	var low: float = Balance.FISHING_SAFE_BAND_CENTRE - half
	var high: float = Balance.FISHING_SAFE_BAND_CENTRE + half
	if _tension >= 1.0:
		_snap()
		return
	if _tension >= low and _tension <= high:
		_progress += delta / _reel_seconds
	elif _tension < low:
		_progress -= delta * 0.3 / _reel_seconds
	else:
		_progress += delta * 0.35 / _reel_seconds
	_progress = clampf(_progress, 0.0, 1.0)
	if _tension <= 0.001:
		_slack_for += delta
	else:
		_slack_for = 0.0
	if _slack_for >= Balance.FISHING_SLACK_GRACE:
		_escape()
		return
	# The float walks in with the fish.
	var toward: Vector2 = _float_at.lerp(_float_from, _progress * 0.55)
	_lay_line(angler, 1.0, toward)
	EventBus.fishing_reel.emit(_tension, low, high, _progress)
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
	_abandon("It threw the hook.")


# --- Landing -------------------------------------------------------------------

## The catch is landed: Food on the ground, the fish in the stash, the Angler
## a little better at this.
func _land() -> void:
	var kind: FishData = _hooked
	var index: int = _pond
	var at: Vector2 = _float_at
	_finish_line()
	if kind == null or index < 0 or index >= _ponds.size():
		return
	_ponds[index]["stock"] = int(_ponds[index]["stock"]) - 1
	if int(_ponds[index]["stock"]) <= 0:
		# Fished out, and it says so: the water goes flat and dull rather than
		# silently refusing a player who walks back to it.
		(_ponds[index]["material"] as ShaderMaterial).set_shader_parameter("spent", 1.0)

	# The fish is this player's, on this player's account, and needs no wire.
	MetaState.take_fish(kind.id)
	# The Food is run currency and the host owns that, so a guest asks rather
	# than paying itself - by id, never by amount, so a forged packet can name
	# a fish that does not exist and never a number that does not.
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
	# Named out loud, through the strip that already carries "not enough Gold".
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
	var was_out: bool = _state >= State.CASTING
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
		at.y -= sin(flight * PI) * Balance.FISHING_CAST_ARC
	else:
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
## The Angler tilts the odds toward the rarer fish a little, and only a little:
## the bonus scales with rarity so a Common is never *less* likely for a novice
## than for a master, only less likely relative to the Rare beside it.
func _roll_fish() -> FishData:
	var eligible: Array[FishData] = []
	var weights: Array[float] = []
	var total: float = 0.0
	var skill: float = _skill()
	for kind: FishData in ContentDB.fish_sorted():
		if not kind.lives_in(RunState.terrain_id):
			continue
		var tilt: float = 1.0 + skill * Balance.FISHING_SKILL_RARE_BONUS \
			* float(kind.rarity) / float(maxi(FishData.Rarity.size() - 1, 1))
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

## This machine's own player, not the partner's.
##
## The scope's `hero` rather than a scan of the heroes group, and the difference
## is the whole of co-op fishing: each angler fishes their own line into their
## own account's stash, so the partner standing in a pond must not put a fish in
## yours. `CoopHeroes` makes that distinction the same way.
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


## The reel: a level.
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
	if _state >= State.CASTING:
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


## How many water cells each pond drew, in the same order. A pond that placed
## no tiles is invisible water, which is the failure `pond_tiles` can have.
func pond_cell_counts() -> PackedInt32Array:
	var out: PackedInt32Array = []
	for pond: Dictionary in _ponds:
		var layer: TileMapLayer = pond["layer"] as TileMapLayer
		out.append(layer.get_used_cells().size() if layer != null else 0)
	return out


## Whether a line is in the water right now.
func is_fishing() -> bool:
	return _state >= State.CASTING


func state() -> State:
	return _state


## The reel, for the gate: tension and how far in the fish is.
func reel_state() -> Vector2:
	return Vector2(_tension, _progress)
