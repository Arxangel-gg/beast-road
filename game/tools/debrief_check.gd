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
	screen.call("show_results", false, summary)
	await get_tree().process_frame
	var body: RichTextLabel = screen.get("body") as RichTextLabel
	_check(body != null, "the results screen has a body")
	if body != null:
		var text: String = body.get_parsed_text()
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
	screen.queue_free()
	await get_tree().process_frame
