class_name Farming
extends Node2D

## Plots on the outskirts and what grows in them: the Farmer (2026-09-14).
##
## Owner brief: farming as a slow skill tied to the climate grid, with crops
## that adapt to the ground - or fail on it - and a skills ecosystem where a
## craft changes how the player treats the land rather than only their
## numbers.
##
## **What it is.** The road lays a few tilled plots on the outskirts when a
## run begins, and every region grows a few of its own crops wild out there.
## Seeds are taken from the wild plants; a seed is planted in an empty plot;
## the crop grows by *road walked* - never by the clock, so a beast standing
## still farms nothing - at a speed set by how well the ground under it fits
## what the crop wants (`fit_for`: the air's temperature and the ground's
## wetness, read off `Climate`), and it wilts and dies where the ground is
## wrong. A ripe crop is pulled for Food. The world tells all of it: a
## thriving plant glints, a wilting one droops and browns, and the crop the
## Warden plants is the one that fits the ground best of the seeds held -
## the Farmer's knowledge, read for the player rather than shown as a number.
##
## **The bound, as the Angler's was.** A craft touches nothing but its own
## craft: a practised Farmer's crops tolerate ground further from their band,
## grow faster, pay more and give a seed back more often. No attribute moves.
## **Nothing new persists**: seeds are the run's (`RunState.seeds`, cleared
## with it), plots are the run's, and only the practice (`profession_xp`) is
## kept - working rule 7 is unchanged by this.
##
## **Personal in co-op, like every craft.** Plots are laid from the run's
## seed so both machines dig the same ones, each Warden works its own, and
## only the Food - the run's, which is the host's to pay out - crosses the
## wire, asked by crop id and never by amount (`Request.HARVEST_CROP`),
## exactly as a landed fish is.
##
## Bodies walk over a plot; a plot blocks nothing and reads nothing.

const SOIL_ART: String = "res://art/crops/plot_soil.png"
const CRAFT: String = "farmer"
const STAGES: int = 4
const FRAME_RATE: float = 4.0

var grid: BattleGrid = null
var field: Node = null
var host: Node2D = null
## Ground already taken by gates, camps and gather nodes, kept clear of.
var avoid: PackedVector2Array = []
var avoid_water: Array[Rect2] = []

## {root, soil, sprite, at, tile, crop_id, growth, health, wilting, wild,
## region, glint_in, ring_in}
var _plots: Array[Dictionary] = []
var _near: int = -1
var _prompt: String = ""
var _prompt_button: String = ""
## Decoration's dice: the glints move no roll that matters.
var _jitter: RandomNumberGenerator = RandomNumberGenerator.new()
var _distance_seen: float = -1.0
var _art: Dictionary = {}
var _soil: Texture2D = null


func _ready() -> void:
	_jitter.randomize()
	EventBus.distance_changed.connect(_on_distance)
	if ResourceLoader.exists(SOIL_ART):
		_soil = load(SOIL_ART) as Texture2D


# --- Laying the ground ------------------------------------------------------------

## The run's plots, once; the region's wild crops, every act. The battlefield
## calls the two halves itself, with the nodes laid between them.
func scatter() -> void:
	if grid == null:
		return
	lay_plots()
	refresh_region()


## The plots the run lays, once, from its seed: laid *before* the gather
## nodes so the nodes can keep clear of them deterministically.
func lay_plots() -> void:
	if grid == null or not _plots.is_empty():
		return
	var anchors: Array[Vector2i] = Fishing.band_tiles(grid, Balance.GATHER_EDGE_BAND)
	if anchors.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("farm")
	var laid: int = 0
	for _attempt: int in Balance.FARM_PLACEMENT_ATTEMPTS:
		if laid >= Balance.FARM_PLOTS_PER_RUN:
			break
		var tile: Vector2i = anchors[rng.randi_range(0, anchors.size() - 1)]
		var at: Vector2 = BattleGrid.tile_to_world(tile)
		if not _is_good_ground(at):
			continue
		_dig(at, tile, "", false, rng)
		laid += 1


## The old region's wild crops leave with it; the plots the run laid, and
## whatever is planted in them, stay - which is what makes a frost root
## planted in the snow a decision when the road reaches the Saltpan.
func refresh_region() -> void:
	for index: int in range(_plots.size() - 1, -1, -1):
		var plot: Dictionary = _plots[index]
		if bool(plot["wild"]) and String(plot["region"]) != RunState.terrain_id:
			var root: Node = plot["root"]
			if root != null and is_instance_valid(root):
				root.queue_free()
			_plots.remove_at(index)
	_near = -1
	var kinds: Array[CropData] = []
	for crop: CropData in ContentDB.crops_sorted():
		if crop.regions.has(RunState.terrain_id):
			kinds.append(crop)
	# The regrown undergrowth is cleared off every plot again: the foliage
	# scatters afresh with the region and knows nothing about the plots.
	for plot: Dictionary in _plots:
		_clear_around(plot["at"] as Vector2)
	if kinds.is_empty() or grid == null:
		return
	var standing: int = 0
	for plot: Dictionary in _plots:
		if bool(plot["wild"]):
			standing += 1
	var anchors: Array[Vector2i] = Fishing.band_tiles(grid, Balance.GATHER_EDGE_BAND)
	if anchors.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("wild:" + RunState.terrain_id)
	for _attempt: int in Balance.FARM_PLACEMENT_ATTEMPTS:
		if standing >= Balance.FARM_WILD_PER_REGION:
			break
		var tile: Vector2i = anchors[rng.randi_range(0, anchors.size() - 1)]
		var at: Vector2 = BattleGrid.tile_to_world(tile)
		if not _is_good_ground(at):
			continue
		var kind: CropData = kinds[rng.randi_range(0, kinds.size() - 1)]
		_dig(at, tile, kind.id, true, rng)
		standing += 1


## The same rule a gather node is placed by, with the plots' own spacing.
func _is_good_ground(at: Vector2) -> bool:
	var half := Vector2.ONE * BattleGrid.TILE
	var rim := Rect2(at - half, half * 2.0)
	if not Fishing.ground_is_open(grid, rim, Balance.GATHER_NODE_CLEARANCE_TILES):
		return false
	if at.length() < Balance.FISHING_TOWN_CLEARANCE:
		return false
	for spawn: Variant in grid.spawn_points:
		if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
			return false
	for lane: int in grid.ambush_points.size():
		for spawn: Variant in (grid.ambush_points[lane] as Array):
			if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
				return false
	for taken: Vector2 in avoid:
		if at.distance_to(taken) < Balance.FARM_PLOT_SPACING:
			return false
	var wet: float = Balance.FISHING_RADIUS + Balance.FISHING_CAST_MAX * 0.5 + Balance.FARM_RADIUS
	for pond: Rect2 in avoid_water:
		var near := Vector2(clampf(at.x, pond.position.x, pond.end.x),
			clampf(at.y, pond.position.y, pond.end.y))
		if at.distance_to(near) < wet:
			return false
	for plot: Dictionary in _plots:
		if at.distance_to(plot["at"] as Vector2) < Balance.FARM_PLOT_SPACING:
			return false
	return true


## A clearing in the undergrowth, so the plot can be seen from the road.
func _clear_around(at: Vector2) -> void:
	if field == null or not field.has_method("foliage_node"):
		return
	var foliage: Node = field.call("foliage_node")
	if foliage != null and foliage.has_method("clear_near"):
		foliage.call("clear_near", at, Balance.FARM_CLEARING)


func _dig(at: Vector2, tile: Vector2i, crop_id: String, wild: bool,
		rng: RandomNumberGenerator) -> void:
	var root := Node2D.new()
	root.name = "WildCrop" if wild else "Plot"
	root.global_position = at
	var soil := Sprite2D.new()
	soil.name = "Soil"
	if _soil != null:
		soil.texture = _soil
	soil.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	soil.add_to_group(Graphics.FILTER_GROUP)
	soil.z_index = -1
	soil.z_as_relative = true
	soil.visible = not wild
	root.add_child(soil)
	var sprite := Sprite2D.new()
	sprite.name = "Crop"
	sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	sprite.add_to_group(Graphics.FILTER_GROUP)
	root.add_child(sprite)
	soil.scale = Vector2.ONE * Balance.FARM_ART_SCALE
	sprite.scale = Vector2.ONE * Balance.FARM_ART_SCALE
	(host if host != null else self).add_child(root)
	_clear_around(at)
	_plots.append({
		"root": root, "soil": soil, "sprite": sprite, "at": at, "tile": tile,
		"crop_id": crop_id, "growth": 1.0 if wild else 0.0, "health": 1.0,
		"wilting": false, "wild": wild, "region": RunState.terrain_id,
		"glint_in": rng.randf_range(Balance.FARM_GLINT_SECONDS.x, Balance.FARM_GLINT_SECONDS.y),
		"ring_in": 0.0,
	})
	_dress(_plots.size() - 1)


# --- Growing ----------------------------------------------------------------------

func _on_distance(total: float, _to_crossroad: float) -> void:
	if _distance_seen < 0.0:
		_distance_seen = total
		return
	var step: float = total - _distance_seen
	_distance_seen = total
	if step > 0.0:
		grow_by(step)


## Road walked, applied to every planted crop. The gate drives this by hand.
func grow_by(step: float) -> void:
	if step <= 0.0:
		return
	for index: int in _plots.size():
		var plot: Dictionary = _plots[index]
		if bool(plot["wild"]) or String(plot["crop_id"]).is_empty() or float(plot["growth"]) >= 1.0:
			continue
		_grow(index, step)


func _grow(index: int, step: float) -> void:
	var plot: Dictionary = _plots[index]
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	if crop == null:
		return
	var level: int = MetaState.profession_level(CRAFT)
	var fit: float = fit_at(index)
	if fit >= Balance.FARM_WILT_BELOW:
		var pace: float = fit * (1.0 + float(level) * Balance.FARM_GROW_PER_LEVEL)
		_plots[index]["growth"] = minf(float(plot["growth"]) + step / maxf(crop.grow_distance, 1.0) * pace, 1.0)
		_plots[index]["health"] = minf(float(plot["health"]) + step / Balance.FARM_WILT_DISTANCE * 0.5, 1.0)
		_plots[index]["wilting"] = false
		return
	_plots[index]["wilting"] = true
	var health: float = float(plot["health"]) - step / maxf(Balance.FARM_WILT_DISTANCE, 1.0)
	_plots[index]["health"] = health
	if health <= 0.0:
		_dies(index)


## The crop could not live here: the seed is lost and the plot is bare again.
func _dies(index: int) -> void:
	var plot: Dictionary = _plots[index]
	Vfx.dust(plot["at"] as Vector2, Color(0.5, 0.42, 0.28, 0.8), 6, 40.0)
	_plots[index]["crop_id"] = ""
	_plots[index]["growth"] = 0.0
	_plots[index]["health"] = 1.0
	_plots[index]["wilting"] = false
	_dress(index)


## How well the ground under a plot fits its crop right now, 0 to 1.
func fit_at(index: int) -> float:
	var plot: Dictionary = _plots[index]
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	if crop == null:
		return 0.0
	return fit_here(crop, plot["at"] as Vector2)


## How well the ground at `at` fits `crop` for this Farmer.
func fit_here(crop: CropData, at: Vector2) -> float:
	var climate: Node = field.call("climate") if field != null and field.has_method("climate") else null
	if climate == null:
		return 1.0
	return fit_for(crop, float(climate.call("temperature_at", at)),
		float(climate.call("wetness_at", at)), MetaState.profession_level(CRAFT))


## The fit as arithmetic: 1 inside both bands, falling to 0 over the
## Farmer's tolerance outside either. Static so the gate can read the rule
## without a field.
static func fit_for(crop: CropData, temperature: float, wetness: float, level: int) -> float:
	var tolerance_t: float = Balance.FARM_TOLERANCE_DEGREES + float(level) * Balance.FARM_TOLERANCE_PER_LEVEL
	var tolerance_w: float = Balance.FARM_WET_TOLERANCE + float(level) * Balance.FARM_WET_TOLERANCE_PER_LEVEL
	var out_t: float = maxf(crop.temp_min - temperature, temperature - crop.temp_max)
	var out_w: float = maxf(crop.wet_min - wetness, wetness - crop.wet_max)
	var fit_t: float = 1.0 if out_t <= 0.0 else clampf(1.0 - out_t / maxf(tolerance_t, 0.001), 0.0, 1.0)
	var fit_w: float = 1.0 if out_w <= 0.0 else clampf(1.0 - out_w / maxf(tolerance_w, 0.001), 0.0, 1.0)
	return fit_t * fit_w


## What a harvest of `crop` pays at Farmer `level`. Static so the host can
## pay a guest's harvest off its own tables.
static func food_for(crop: CropData, level: int) -> int:
	return maxi(1, int(round(float(crop.food_yield) * (1.0 + float(level) * Balance.FARM_YIELD_PER_LEVEL))))


## Of the seeds held, the crop that fits `at` best - the Farmer choosing
## for the player. Empty when nothing is held.
func best_seed_for(at: Vector2) -> String:
	var best: String = ""
	var best_fit: float = -1.0
	var best_food: int = -1
	for crop: CropData in ContentDB.crops_sorted():
		if RunState.seed_count(crop.id) <= 0:
			continue
		var fit: float = fit_here(crop, at)
		if fit > best_fit + 0.001 or (absf(fit - best_fit) <= 0.001 and crop.food_yield > best_food):
			best = crop.id
			best_fit = fit
			best_food = crop.food_yield
	return best


# --- Working a plot ---------------------------------------------------------------------

## Seeds from a wild plant. The plant is spent and its ground is a plot now.
func take_seeds(index: int) -> bool:
	if index < 0 or index >= _plots.size():
		return false
	var plot: Dictionary = _plots[index]
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	if crop == null or not bool(plot["wild"]) or float(plot["growth"]) < 1.0:
		return false
	var count: int = _roll().randi_range(Balance.FARM_WILD_SEEDS.x, Balance.FARM_WILD_SEEDS.y)
	RunState.add_seeds(crop.id, count)
	MetaState.gain_profession_xp(CRAFT, Balance.FARM_WILD_XP)
	var at: Vector2 = plot["at"]
	Vfx.word(at + Vector2(0.0, -26.0), "+%d %s seeds" % [count, crop.display_name],
		Color(0.78, 0.9, 0.55), Balance.GATHER_WORD_SIZE)
	Vfx.spark(at + Vector2(0.0, -20.0), Color(0.72, 0.86, 0.5), 8, Vector2.UP, 120.0)
	Sfx.play_group("sfx_loot_drop", -8.0)
	_plots[index]["wild"] = false
	_plots[index]["crop_id"] = ""
	_plots[index]["growth"] = 0.0
	_plots[index]["health"] = 1.0
	(plot["soil"] as CanvasItem).visible = true
	_dress(index)
	return true


## Plants the seed that fits this ground best. Refused with nothing held.
func plant(index: int) -> bool:
	if index < 0 or index >= _plots.size():
		return false
	var plot: Dictionary = _plots[index]
	if bool(plot["wild"]) or not String(plot["crop_id"]).is_empty():
		return false
	var crop_id: String = best_seed_for(plot["at"] as Vector2)
	if crop_id.is_empty() or not RunState.take_seed(crop_id):
		return false
	_plots[index]["crop_id"] = crop_id
	_plots[index]["growth"] = 0.0
	_plots[index]["health"] = 1.0
	_plots[index]["wilting"] = false
	Vfx.dust(plot["at"] as Vector2, Color(0.42, 0.34, 0.24, 0.7), 4, 26.0)
	_dress(index)
	return true


## Pulls a ripe crop: Food to the run, practice to the Farmer, and sometimes
## a seed back.
func harvest(index: int) -> bool:
	if index < 0 or index >= _plots.size():
		return false
	var plot: Dictionary = _plots[index]
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	if crop == null or bool(plot["wild"]) or float(plot["growth"]) < 1.0:
		return false
	var level: int = MetaState.profession_level(CRAFT)
	var food: int = food_for(crop, level)
	_pay_food(crop, food)
	MetaState.gain_profession_xp(CRAFT, crop.xp)
	RunState.note_kept("harvests", 1.0)
	var at: Vector2 = plot["at"]
	var seed_back: bool = _roll().randf() < Balance.FARM_SEED_BACK_BASE + float(level) * Balance.FARM_SEED_BACK_PER_LEVEL
	if seed_back:
		RunState.add_seeds(crop.id, 1)
	Vfx.word(at + Vector2(0.0, -26.0), "+%d Food" % food + (" · a seed" if seed_back else ""),
		Color(0.95, 0.82, 0.45), Balance.GATHER_LUCKY_WORD_SIZE if seed_back else Balance.GATHER_WORD_SIZE)
	Vfx.spark(at + Vector2(0.0, -20.0), Color(0.95, 0.85, 0.5), 10, Vector2.UP, 140.0)
	Sfx.play_group("sfx_loot_drop", -6.0)
	_plots[index]["crop_id"] = ""
	_plots[index]["growth"] = 0.0
	_plots[index]["health"] = 1.0
	_plots[index]["wilting"] = false
	_dress(index)
	return true


## The Food is the run's, and the run is the host's to pay out: a guest asks
## by crop id, never by amount.
func _pay_food(crop: CropData, food: int) -> void:
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.HARVEST_CROP, [crop.id])
		return
	RunState.gain_currency(RunState.FOOD, food)


func _roll() -> RandomNumberGenerator:
	return RunState.rng("farm")


# --- Drawing and the prompt ----------------------------------------------------------

func _process(delta: float) -> void:
	if _plots.is_empty():
		return
	for index: int in _plots.size():
		_tick_plot(index, delta)
	var who: Node2D = _local_hero()
	if who == null:
		_set_prompt("", "")
		return
	var near: int = _plot_near(who.global_position)
	_near = near
	if near < 0:
		_set_prompt("", "")
		return
	var plot: Dictionary = _plots[near]
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	var source := who.get("input") as HeroInput
	var pressed: bool = source != null and source.pressed(HeroInput.BUTTON_INTERACT)
	if crop == null:
		var best: String = best_seed_for(plot["at"] as Vector2)
		var seed: CropData = ContentDB.crop(best)
		if seed == null:
			_set_prompt("A bare plot  ·  no seeds to plant", "")
			return
		_set_prompt("Plant  ·  %s  (%d)" % [seed.display_name, RunState.seed_count(best)], "PLANT")
		if pressed:
			plant(near)
		return
	if bool(plot["wild"]):
		_set_prompt("Wild %s  ·  take its seeds" % crop.display_name, "TAKE")
		if pressed:
			take_seeds(near)
		return
	if float(plot["growth"]) >= 1.0:
		_set_prompt("Harvest  ·  %s" % crop.display_name, "HARVEST")
		if pressed:
			harvest(near)
		return
	if bool(plot["wilting"]):
		_set_prompt("%s  ·  wilting, the ground is wrong for it" % crop.display_name, "")
	else:
		_set_prompt("%s  ·  growing, %d%%" % [crop.display_name, int(float(plot["growth"]) * 100.0)], "")


func _tick_plot(index: int, delta: float) -> void:
	var plot: Dictionary = _plots[index]
	var sprite: Sprite2D = plot["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	if crop == null:
		return
	var at: Vector2 = plot["at"]
	if bool(plot["wilting"]):
		# Drooping and browning, by how far gone it is.
		var gone: float = 1.0 - clampf(float(plot["health"]), 0.0, 1.0)
		sprite.modulate = Color.WHITE.lerp(Color(0.72, 0.58, 0.36), 0.35 + 0.6 * gone)
		sprite.rotation = deg_to_rad(-10.0 * gone)
	else:
		sprite.modulate = Color.WHITE
		sprite.rotation = 0.0
	# The tell: a thriving or ripe plant glints, and a ripe one breathes a
	# ring while the hero stands in reach.
	var glint_in: float = float(plot.get("glint_in", 0.0)) - delta
	if glint_in <= 0.0:
		glint_in = _jitter.randf_range(Balance.FARM_GLINT_SECONDS.x, Balance.FARM_GLINT_SECONDS.y)
		if not bool(plot["wilting"]):
			var ripe: bool = float(plot["growth"]) >= 1.0
			Vfx.spark(at + Vector2(0.0, -22.0), Color(0.95, 0.9, 0.55) if ripe else Color(0.7, 0.9, 0.5),
				3 + (2 if ripe else 0) + crop.rarity, Vector2.UP, 40.0)
	_plots[index]["glint_in"] = glint_in
	if _near == index and float(plot["growth"]) >= 1.0:
		var ring_in: float = float(plot.get("ring_in", 0.0)) - delta
		if ring_in <= 0.0:
			ring_in = Balance.GATHER_REACH_RING_SECONDS
			Vfx.ring(at, 52.0, Color(0.95, 0.85, 0.5, 0.45), 0.7, 2.0)
		_plots[index]["ring_in"] = ring_in
	else:
		_plots[index]["ring_in"] = 0.0


## The stage sprite for what stands in a plot, or nothing.
func _dress(index: int) -> void:
	var plot: Dictionary = _plots[index]
	var sprite: Sprite2D = plot["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var crop: CropData = ContentDB.crop(String(plot["crop_id"]))
	if crop == null:
		sprite.texture = null
		sprite.visible = false
		return
	var stage: int = stage_of(float(plot["growth"]))
	var path: String = crop.stage_path(stage)
	if not _art.has(path):
		_art[path] = load(path) if ResourceLoader.exists(path) else null
	var texture: Texture2D = _art[path] as Texture2D
	sprite.texture = texture
	sprite.visible = texture != null
	if texture != null:
		sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.42)
	# The soil sits under the plant's foot.
	var soil: Sprite2D = plot["soil"] as Sprite2D
	if soil != null and is_instance_valid(soil):
		soil.position = Vector2(0.0, -6.0)


static func stage_of(growth: float) -> int:
	if growth >= 1.0:
		return 3
	return clampi(int(floor(growth * 3.0)), 0, 2)


func _plot_near(at: Vector2) -> int:
	var best: int = -1
	var nearest: float = INF
	for index: int in _plots.size():
		var gap: float = at.distance_to(_plots[index]["at"] as Vector2)
		if gap <= Balance.FARM_RADIUS and gap < nearest:
			nearest = gap
			best = index
	return best


func _local_hero() -> Node2D:
	if field == null:
		return null
	var who := field.get("hero") as Node2D
	if who == null or not who.has_method("is_alive"):
		return null
	return who if bool(who.call("is_alive")) else null


func _set_prompt(text: String, button: String) -> void:
	if text == _prompt and button == _prompt_button:
		return
	_prompt = text
	_prompt_button = button
	EventBus.interact_prompt.emit(text, button)


# --- For the minimap and the gate ------------------------------------------------------

func plot_count() -> int:
	return _plots.size()


func plot_positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for plot: Dictionary in _plots:
		out.append(plot["at"] as Vector2)
	return out


## A copy of one plot's state, without its nodes.
func plot_state(index: int) -> Dictionary:
	if index < 0 or index >= _plots.size():
		return {}
	var plot: Dictionary = _plots[index]
	return {"at": plot["at"], "tile": plot["tile"], "crop_id": plot["crop_id"],
		"growth": plot["growth"], "health": plot["health"], "wilting": plot["wilting"],
		"wild": plot["wild"], "region": plot["region"]}


## Updates a plot's stage picture after the gate moved its growth by hand.
func redress(index: int) -> void:
	if index >= 0 and index < _plots.size():
		_dress(index)


func _exit_tree() -> void:
	if not _prompt.is_empty():
		EventBus.interact_prompt.emit("", "")
