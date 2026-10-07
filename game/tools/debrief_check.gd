extends Node

## The debrief says what the road paid whatever happened, and what the earth
## did. Both are counted on the real paths - XP through `gain_hero_xp`, a
## material through `gain_material`, a fish through `take_fish`, gear through
## `receive_gear`, a bond through `record_spirit_encounter` - and the earth's
## events where they are seen, so a guest's line agrees with the host's. Then
## the results screen is stood up with a summary and read back.
##
##   godot --headless --path game res://tools/debrief_check.tscn
##
## The failure this guards is a counter authored and never fed: a "KEPT"
## line that says "nothing this time" after a run that levelled twice.

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	_test_the_gains_are_counted_where_they_are_banked()
	_test_every_death_names_what_did_it()
	_test_the_earth_is_counted_where_it_is_seen()
	await _test_the_debrief_says_both()
	await _test_the_last_seconds_are_told()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[debrief] PASS - %d checks: the gains are counted where they are banked, "
			% _checks + "the earth where it is seen, and the debrief says both")
	else:
		for failure: String in _failures:
			push_error("[debrief] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


## **The final seconds, by source** (2026-10-07, the death recap): a blow
## older than the window is not in it, sources are grouped and the heaviest
## comes first, and the debrief says it on a fall and never on a victory.
func _test_the_last_seconds_are_told() -> void:
	RunState.reset()
	RunState.run_time_seconds = 0.0
	RunState.note_blow("Bog Maw", 10.0)
	RunState.run_time_seconds = 20.0
	RunState.note_blow("Saltthorn", 5.0)
	RunState.run_time_seconds = 21.0
	RunState.note_blow("Saltthorn", 7.0)
	RunState.run_time_seconds = 22.0
	RunState.note_blow("Ember Shaman", 30.0)
	var recap: Array[Dictionary] = RunState.death_recap()
	_check(recap.size() == 2, "the recap names %d sources, not the two in its window" % recap.size())
	if recap.size() == 2:
		_check(String(recap[0]["source"]) == "Ember Shaman" and is_equal_approx(float(recap[0]["total"]), 30.0),
			"the heaviest source does not come first")
		_check(String(recap[1]["source"]) == "Saltthorn" and int(recap[1]["count"]) == 2 and is_equal_approx(float(recap[1]["total"]), 12.0),
			"two blows from one source are not one line")
	for entry: Dictionary in recap:
		_check(String(entry["source"]) != "Bog Maw", "a blow from long before the end is in the last seconds")
	var scene: PackedScene = load("res://scenes/ui/results_screen.tscn") as PackedScene
	var screen: Node = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var summary: Dictionary = {"victory": false, "seed": 1, "roads": [], "distance": 10.0, "act": 2,
		"wave": 5, "kills": 12, "deaths": 1, "last_blow": "Ember Shaman for 30", "recap": recap,
		"time": 90.0, "planning_time": 20.0, "kept": {}, "earth": {}, "unlocks": [], "chronicle": []}
	screen.call("show_results", false, summary)
	await get_tree().process_frame
	var body: RichTextLabel = screen.get("body") as RichTextLabel
	var fell: String = body.get_parsed_text() if body != null else ""
	_check(fell.contains("Last seconds") and fell.contains("Ember Shaman x1 30") and fell.contains("Saltthorn x2 12"),
		"a fall's debrief does not tell its last seconds")
	screen.call("show_results", true, summary)
	await get_tree().process_frame
	_check(not body.get_parsed_text().contains("Last seconds"), "a victory's debrief tells last seconds nobody died in")
	screen.queue_free()
	RunState.reset()
	await get_tree().process_frame


## **Every way a Warden can die names what did it.**
##
## `note_blow` was called by the things that swing: bodies, ground strikes, the
## earth's events through `strike_the_players`, a bubble in a pond. It was not
## called by the three deaths a player is least able to explain for themselves -
## drowning, the Wildblight's venom, and a dungeon collapsing - so the debrief
## confidently named whatever had last touched them, which on a collapse is the
## body they fought on the way in and on a drowning can be a region ago.
##
## Source rather than behaviour, because driving a real drowning needs water, a
## real collapse needs a dungeon and a real blight needs a rabid animal - three
## harnesses for a check whose whole content is "this call exists". The fault was
## an omission, and an omission is exactly what a source walk sees.
func _test_every_death_names_what_did_it() -> void:
	var paths: Dictionary = {
		"res://scenes/hero/hero.gd": ["Deep water", "The Wildblight"],
		"res://scenes/rift/rift_arena.gd": ["The collapse"],
	}
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_check(false, "%s is missing" % path)
			continue
		var text: String = file.get_as_text()
		for name: String in (paths[path] as Array):
			_check(text.contains("note_blow(\"%s\"" % name),
				("%s no longer names \"%s\" as a cause of death, so the debrief "
					+ "will name the last thing that happened to touch them")
					% [path, name])


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _test_the_gains_are_counted_where_they_are_banked() -> void:
	_check(RunState.kept.is_empty(), "a fresh run has kept something already")
	# XP, enough for at least one level.
	var level: int = RunState.hero_level
	RunState.gain_hero_xp(RunState.hero_xp_for_level(level) + 5.0)
	_check(float(RunState.kept.get("xp", 0.0)) > 0.0, "XP gained was not kept")
	if RunState.hero_level > level:
		_check(float(RunState.kept.get("levels", 0.0)) >= 1.0, "a level gained was not kept")
	# A material, by the real store.
	var material_id: String = ""
	for node: Variant in ContentDB.gather_nodes.values():
		var kind := node as GatherNodeData
		if kind != null and not kind.material_id.is_empty():
			material_id = kind.material_id
			break
	_check(not material_id.is_empty(), "a material id to bank")
	if not material_id.is_empty():
		var before: float = float(RunState.kept.get("materials", 0.0))
		_check(MetaState.gain_material(material_id, 3), "the store refused %s" % material_id)
		_check(is_equal_approx(float(RunState.kept.get("materials", 0.0)), before + 3.0),
			"three materials banked and %.0f kept" % float(RunState.kept.get("materials", 0.0)))
	# A fish, by the real pantry.
	var fish_id: String = ""
	for value: Variant in ContentDB.fish_kinds.values():
		var fish := value as FishData
		if fish != null:
			fish_id = fish.id
			break
	_check(not fish_id.is_empty(), "a fish id to bank")
	if not fish_id.is_empty() and MetaState.take_fish(fish_id):
		_check(float(RunState.kept.get("fish", 0.0)) >= 1.0, "a fish kept was not counted")
	# Gear, by the real stash.
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 0, RunState.rng("gear"))
	_check(not piece.is_empty(), "a piece to bank")
	if not piece.is_empty():
		var result: Dictionary = MetaState.receive_gear(piece)
		if bool(result.get("stored", false)):
			_check(float(RunState.kept.get("gear", 0.0)) >= 1.0, "a piece stored was not counted")
	# A bond: counted exactly as often as the journal says one was made.
	var species: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null:
			species = kind
			break
	if species != null:
		var bonded: int = 0
		var before: float = float(RunState.kept.get("spirits", 0.0))
		for _i: int in 60:
			var result: Dictionary = MetaState.record_spirit_encounter(species.id, 0, false)
			bonded += (result.get("bonded", []) as Array).size()
		_check(is_equal_approx(float(RunState.kept.get("spirits", 0.0)), before + float(bonded)),
			"%d bonds made and %.0f kept" % [bonded, float(RunState.kept.get("spirits", 0.0)) - before])
	# Craft XP.
	var craft: String = String(Balance.PROFESSIONS[0])
	var craft_before: float = float(RunState.kept.get("craft_xp", 0.0))
	MetaState.gain_profession_xp(craft, 7)
	_check(is_equal_approx(float(RunState.kept.get("craft_xp", 0.0)), craft_before + 7.0), "craft XP was not kept")
	# And a fresh run keeps nothing.
	var snapshot: Dictionary = RunState.kept.duplicate(true)
	RunState.reset()
	_check(RunState.kept.is_empty(), "a reset run still keeps the last run's gains")
	RunState.kept = snapshot


func _test_the_earth_is_counted_where_it_is_seen() -> void:
	RunState.earth_events.clear()
	var sky := WeatherSky.new()
	add_child(sky)
	# Seen, not done: the handlers every machine runs when it is told.
	EventBus.lightning_struck.emit(Vector2(400.0, 400.0), 100.0)
	EventBus.lightning_struck.emit(Vector2(-400.0, 400.0), 100.0)
	EventBus.earthquake.emit(0.5, 1.0, Vector2.ZERO, 1)
	_check(int(RunState.earth_events.get("strikes", 0)) == 2, "two strikes seen and %d counted" % int(RunState.earth_events.get("strikes", 0)))
	_check(int(RunState.earth_events.get("quakes", 0)) == 1, "a quake seen and %d counted" % int(RunState.earth_events.get("quakes", 0)))
	sky.queue_free()


func _test_the_debrief_says_both() -> void:
	var scene: PackedScene = load("res://scenes/ui/results_screen.tscn") as PackedScene
	_check(scene != null, "the results screen scene loads")
	if scene == null:
		return
	var screen: Node = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var summary: Dictionary = {"victory": false, "seed": 1, "roads": [], "distance": 10.0, "act": 2,
		"wave": 5, "kills": 12, "deaths": 1, "last_blow": "lightning for 40", "time": 90.0,
		"planning_time": 20.0, "kept": {"xp": 120.0, "levels": 2.0, "materials": 3.0, "gear": 1.0},
		"earth": {"strikes": 2, "quakes": 1}, "unlocks": [], "chronicle": []}
	# **The strip** (2026-10-06): the tiles and the bars are read off the same
	# summary as the body, and the experience bar off the account - so the
	# account is set to a known level and pool first.
	var kept_level: int = MetaState.hero_level
	var kept_xp: float = MetaState.hero_xp
	MetaState.hero_level = 3
	MetaState.hero_xp = 50.0
	screen.call("show_results", false, summary)
	await get_tree().process_frame
	var tiles: Dictionary = screen.call("tile_targets")
	_check(int(tiles.get("killed", -1)) == 12, "the killed tile says 12 (%s)" % str(tiles.get("killed")))
	_check(int(tiles.get("in combat", -1)) == 90, "the combat tile holds the seconds")
	_check(tiles.size() == 5, "five tiles, one row (%d)" % tiles.size())
	var killed_tile: Node = screen.get("_tiles").get_node_or_null("Tile_killed")
	var number: Label = killed_tile.find_child("Number", true, false) as Label \
		if killed_tile != null else null
	_check(number != null and number.text == "12", "headless, the tile has already counted (%s)"
		% (number.text if number != null else "no tile"))
	var bars: Dictionary = screen.call("bar_shares")
	var needed: float = RunState.hero_xp_for_level(3)
	var xp: Dictionary = bars.get("xp", {})
	_check(is_equal_approx(float(xp.get("share", -1.0)), 50.0 / needed),
		"the experience bar shows the account's pool (%.4f for %.4f)" % [float(xp.get("share", -1.0)), 50.0 / needed])
	_check(is_equal_approx(float(xp.get("gain", -1.0)), 50.0 / needed),
		"the road's +120 XP lights the whole of a 50-point pool (%.4f)" % float(xp.get("gain", -1.0)))
	var road: Dictionary = bars.get("road", {})
	_check(is_equal_approx(float(road.get("share", -1.0)), 10.0 / Balance.JOURNEY_TOTAL_DISTANCE),
		"the road bar shows the distance walked")
	_check(int(road.get("ticks", 0)) == Balance.ACT_COUNT, "the road bar ticks every act")
	MetaState.hero_level = kept_level
	MetaState.hero_xp = kept_xp
	var body: RichTextLabel = screen.get("body") as RichTextLabel
	_check(body != null, "the results screen has a body")
	if body != null:
		var text: String = body.get_parsed_text()
		_check(body.text.contains("[img=") and body.text.find("[img=") < body.text.find("DEFENCE"),
			"the DEFENCE section wears its mark")
		_check(text.contains("THE EARTH"), "the debrief does not name the earth")
		_check(text.contains("2 strikes") and text.contains("1 quake"), "the debrief does not count what the earth did")
		_check(text.contains("KEPT") and text.contains("+120 XP") and text.contains("2 levels")
			and text.contains("3 materials") and text.contains("1 piece of gear"),
			"the debrief does not say what was kept: %s" % text.substr(maxi(text.find("KEPT") - 4, 0), 160))
		_check(text.contains("the road ends, this does not"), "a loss should say what does not end")
	# A win with nothing from the earth says nothing about it.
	summary["victory"] = true
	summary["earth"] = {}
	summary["kept"] = {}
	screen.call("show_results", true, summary)
	await get_tree().process_frame
	if body != null:
		var text: String = body.get_parsed_text()
		_check(not text.contains("THE EARTH"), "a quiet run's debrief names the earth")
		_check(text.contains("nothing this time"), "an empty run should say so")
	var quiet: Dictionary = screen.call("bar_shares")
	_check(is_zero_approx(float((quiet.get("xp", {}) as Dictionary).get("gain", 1.0))),
		"a road that paid nothing lights no share of the bar")
	# A buried Warden's report shows no experience bar: the account it would
	# read is a new one, and a bar for it would read as something kept.
	summary["buried"] = true
	screen.call("show_results", false, summary)
	await get_tree().process_frame
	_check(not (screen.call("bar_shares") as Dictionary).has("xp"), "a burial shows no experience bar")
	summary.erase("buried")
	screen.queue_free()
	await get_tree().process_frame
