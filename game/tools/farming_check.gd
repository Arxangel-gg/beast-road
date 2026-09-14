extends Node

## The Farmer (2026-09-14): plots on the outskirts, seeds from the wild,
## crops that grow by road walked at the pace the ground allows, and wilt
## where the ground is wrong.
##
##   godot --headless --path game res://tools/farming_check.tscn
##
## What this holds, in the order it would go wrong:
##
## - the crops are sound: every one has its four stages on disk, a band it
##   can live in, somewhere it grows wild, and the Farmer is a craft;
## - the plots lie on open ground beyond the city, spaced, with the region's
##   wild crops among them;
## - seeds are the run's: none at the start, taken from a wild plant, spent
##   by planting, gone with the reset;
## - a crop grows by road and never by the clock, at a pace the ground sets:
##   the same crop grows on ground that fits it and wilts on ground that
##   does not, and a wilting crop dies;
## - the Warden plants the seed that fits the ground best of those held;
## - a harvest pays Food once, and the Farmer's practice, and nothing else;
## - a practised Farmer tolerates further from the band and pays more, and
##   no attribute moves - the bound every craft is held to.

const SEED: int = 20260914

var _failures: int = 0
var _checked: int = 0
var _run: Run = null
var _field: Battlefield = null
var _farm: Farming = null


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	MetaState.profession_xp[Farming.CRAFT] = 0.0
	RunState.reset(false, SEED)
	RunState.terrain_id = "jungle"
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.battlefield
	_farm = _field.farming() if _field != null else null
	_check(_field != null and _farm != null, "the harness needs a battlefield and its farm")
	_test_the_crops()
	if _field != null and _farm != null:
		if _field.wave_director != null:
			_field.wave_director.stop()
		_field.sky().events_enabled = false
		_field.climate().reset()
		_test_the_plots()
		await _test_seeds_and_growth()
		_test_the_practice()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _f: int in 20:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[farming] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[farming] PASS - %d checks: the crops, the plots, seeds, growth by road and by ground, the harvest, the practice" % _checked)
	get_tree().quit(0)


func _test_the_crops() -> void:
	var crops: Array[CropData] = ContentDB.crops_sorted()
	_check(crops.size() >= 6, "six crops are authored (%d)" % crops.size())
	_check(Balance.PROFESSIONS.has(Farming.CRAFT), "the Farmer is a craft")
	var terrains: Array[String] = []
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var terrain: TerrainData = ContentDB.terrain_for_act(act)
		if terrain != null:
			terrains.append(terrain.id)
	for crop: CropData in crops:
		for stage: int in Farming.STAGES:
			_check(ResourceLoader.exists(crop.stage_path(stage)), "%s has its stage %d on disk" % [crop.id, stage])
		_check(crop.temp_min < crop.temp_max and crop.wet_min < crop.wet_max
			and crop.wet_min >= 0.0 and crop.wet_max <= 1.0, "%s has a band it can live in" % crop.id)
		_check(crop.food_yield > 0 and crop.xp > 0 and crop.grow_distance > 0.0, "%s pays and takes road" % crop.id)
		_check(not crop.regions.is_empty(), "%s grows wild somewhere" % crop.id)
		for region: String in crop.regions:
			_check(terrains.has(region), "%s grows wild in a region on the road (%s)" % [crop.id, region])
		_check(crop.grow_distance < Balance.ACT_DISTANCE * 0.75,
			"%s ripens inside an act on ground that fits it (%.0f of %.0f)" % [crop.id, crop.grow_distance, Balance.ACT_DISTANCE])
	# The fit rule, at the edges.
	var barley: CropData = ContentDB.crop("barley")
	if barley != null:
		_check(is_equal_approx(Farming.fit_for(barley, 20.0, 0.3, 1), 1.0), "inside both bands the fit is whole")
		_check(Farming.fit_for(barley, 60.0, 0.3, 1) == 0.0, "far outside it is nothing")
		var near_edge: float = Farming.fit_for(barley, barley.temp_max + 2.0, 0.3, 1)
		_check(near_edge > 0.0 and near_edge < 1.0, "a little outside is a little less (%.2f)" % near_edge)
		_check(Farming.fit_for(barley, barley.temp_max + 2.0, 0.3, 20) > near_edge,
			"and a practised Farmer's crop tolerates it better")


func _test_the_plots() -> void:
	var count: int = _farm.plot_count()
	_check(count >= Balance.FARM_PLOTS_PER_RUN, "the run laid its plots (%d)" % count)
	var wild: int = 0
	var open: bool = true
	var beyond: bool = true
	var spaced: bool = true
	var spots: PackedVector2Array = _farm.plot_positions()
	for index: int in count:
		var state: Dictionary = _farm.plot_state(index)
		var at: Vector2 = state["at"]
		if bool(state["wild"]):
			wild += 1
			var crop: CropData = ContentDB.crop(String(state["crop_id"]))
			_check(crop != null and crop.regions.has(RunState.terrain_id) and float(state["growth"]) >= 1.0,
				"a wild crop belongs to this region and stands ripe")
		if _field.grid.cell_at(BattleGrid.world_to_tile(at)) != BattleGrid.Cell.OPEN:
			open = false
		if at.length() < Balance.FISHING_TOWN_CLEARANCE:
			beyond = false
		for other: int in range(index + 1, count):
			if at.distance_to(spots[other]) < Balance.FARM_PLOT_SPACING * 0.99:
				spaced = false
	_check(wild >= 1 and wild <= Balance.FARM_WILD_PER_REGION, "the region's crops grow wild among them (%d)" % wild)
	_check(open, "every plot lies on open ground")
	_check(beyond, "and beyond the city")
	_check(spaced, "and spaced from the others")


func _test_seeds_and_growth() -> void:
	_check(RunState.seeds.is_empty(), "a run starts with no seeds")
	var wild_index: int = -1
	var empty_index: int = -1
	var other_empty: int = -1
	for index: int in _farm.plot_count():
		var state: Dictionary = _farm.plot_state(index)
		if bool(state["wild"]) and wild_index < 0:
			wild_index = index
		elif not bool(state["wild"]) and String(state["crop_id"]).is_empty():
			if empty_index < 0:
				empty_index = index
			elif other_empty < 0:
				other_empty = index
	if wild_index < 0 or empty_index < 0 or other_empty < 0:
		_check(false, "the harness needs a wild plant and two bare plots")
		return
	var wild_crop: String = String(_farm.plot_state(wild_index)["crop_id"])
	_check(not _farm.plant(empty_index), "nothing can be planted with no seeds")
	_check(not _farm.harvest(wild_index), "a wild plant is not a harvest")
	_check(_farm.take_seeds(wild_index), "seeds are taken from a wild plant")
	_check(RunState.seed_count(wild_crop) >= Balance.FARM_WILD_SEEDS.x, "into the pouch (%d)" % RunState.seed_count(wild_crop))
	_check(not bool(_farm.plot_state(wild_index)["wild"]) and String(_farm.plot_state(wild_index)["crop_id"]).is_empty(),
		"and its ground is a bare plot now")
	_check(not _farm.take_seeds(wild_index), "which has no more seeds to give")

	# Growth is by road, at the ground's pace. Barley on rest ground fits;
	# the ember pepper wants a heat the jungle does not have.
	RunState.seeds.clear()
	RunState.add_seeds("barley", 2)
	RunState.add_seeds("ember_pepper", 2)
	var at_empty: Vector2 = _farm.plot_state(empty_index)["at"]
	_check(_farm.best_seed_for(at_empty) == "barley", "of the seeds held, the barley fits this ground (%s)" % _farm.best_seed_for(at_empty))
	var seeds_before: int = RunState.seed_count("barley")
	_check(_farm.plant(empty_index), "the bare plot is planted")
	_check(RunState.seed_count("barley") == seeds_before - 1, "with a seed from the pouch")
	_check(String(_farm.plot_state(empty_index)["crop_id"]) == "barley", "and it is the barley")
	_check(not _farm.plant(empty_index), "a planted plot cannot be planted again")
	_farm._process(5.0)
	_check(is_zero_approx(float(_farm.plot_state(empty_index)["growth"])), "the clock grows nothing")
	_farm.grow_by(40.0)
	var grew: float = float(_farm.plot_state(empty_index)["growth"])
	_check(grew > 0.0 and grew < 1.0, "the road grows it (%.2f after 40)" % grew)
	# The same road on the wrong ground: the pepper wilts.
	RunState.seeds.clear()
	RunState.add_seeds("ember_pepper", 2)
	_check(_farm.plant(other_empty), "the pepper is planted on the same ground")
	_farm.grow_by(40.0)
	var pepper: Dictionary = _farm.plot_state(other_empty)
	_check(is_zero_approx(float(pepper["growth"])) and bool(pepper["wilting"]),
		"and wilts rather than grows on ground that is wrong for it (%.2f, wilting %s)" % [float(pepper["growth"]), str(pepper["wilting"])])
	_check(float(pepper["health"]) < 1.0, "losing its health to the road")
	# Warm the ground and the pepper takes: the ground is the whole rule.
	_field.climate().add_heat(pepper["at"] as Vector2, 22.0, 400.0)
	var fit_hot: float = _farm.fit_at(other_empty)
	_check(fit_hot > 0.5, "warmed, the ground fits the pepper (%.2f)" % fit_hot)
	_farm.grow_by(40.0)
	_check(float(_farm.plot_state(other_empty)["growth"]) > 0.0 and not bool(_farm.plot_state(other_empty)["wilting"]),
		"and it grows there (%.2f)" % float(_farm.plot_state(other_empty)["growth"]))
	_field.climate().reset()
	# Left on the wrong ground, a crop dies and the seed is gone.
	_farm.grow_by(Balance.FARM_WILT_DISTANCE * 1.5)
	_check(String(_farm.plot_state(other_empty)["crop_id"]).is_empty(), "left wilting, the crop dies and its plot is bare")
	# The harvest pays once.
	_farm.grow_by(Balance.ACT_DISTANCE * 2.0)
	_check(float(_farm.plot_state(empty_index)["growth"]) >= 1.0, "the barley ripens")
	var food_before: int = RunState.currency(RunState.FOOD)
	var xp_before: float = float(MetaState.profession_xp.get(Farming.CRAFT, 0.0))
	var barley: CropData = ContentDB.crop("barley")
	_check(_farm.harvest(empty_index), "and is harvested")
	var paid: int = RunState.currency(RunState.FOOD) - food_before
	# Trimmed at the door like every Food source (`CURRENCY_YIELD_SCALE`), so
	# the expectation is the trimmed figure, not the crop's raw number.
	var expected: int = int(floor(float(Farming.food_for(barley, 1))
		* float(Balance.CURRENCY_YIELD_SCALE.get(RunState.FOOD, 1.0))))
	_check(paid >= expected - 1 and paid > 0, "for Food (%d, about %d)" % [paid, expected])
	_check(float(MetaState.profession_xp.get(Farming.CRAFT, 0.0)) > xp_before, "and the Farmer's practice")
	_check(String(_farm.plot_state(empty_index)["crop_id"]).is_empty(), "leaving the plot bare")
	_check(not _farm.harvest(empty_index), "a bare plot pays nothing")
	_check(int(RunState.kept.get("harvests", 0)) == 1, "the debrief counts the harvest")
	# The reset takes the pouch.
	RunState.add_seeds("barley", 3)
	RunState.reset(false, SEED)
	RunState.terrain_id = "jungle"
	GameDirector.run_active = true
	_check(RunState.seeds.is_empty(), "seeds go with the run")
	await get_tree().process_frame


func _test_the_practice() -> void:
	var before: Array[int] = []
	for which: int in RunState.Attribute.size():
		before.append(RunState.attribute(which))
	var barley: CropData = ContentDB.crop("barley")
	var yield_low: int = Farming.food_for(barley, 1)
	MetaState.profession_xp[Farming.CRAFT] = MetaState.profession_xp_to_cap()
	var level: int = MetaState.profession_level(Farming.CRAFT)
	_check(level == Balance.PROFESSION_MAX_LEVEL, "the Farmer can be maxed (%d)" % level)
	_check(Farming.food_for(barley, level) > yield_low, "a practised Farmer pulls more from the same crop")
	var same: bool = true
	for which: int in RunState.Attribute.size():
		if RunState.attribute(which) != before[which]:
			same = false
	_check(same, "and no attribute moved: the craft touches nothing but the craft")
	MetaState.profession_xp[Farming.CRAFT] = 0.0


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[farming] " + message)
