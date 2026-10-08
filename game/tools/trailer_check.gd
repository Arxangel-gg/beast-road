extends Node

## **The trailer opens the game once, is made live, and always lets go**
## (owner, 2026-10-01; live and procedural since 2026-10-07).
##
## Holds:
## - **Every trailer dealt is a journey**: three roads in three acts, each in its
##   own range, on a layout a player can be dealt, with no moment shown twice,
##   every moment one a recipe stages and its act inside the moment's own range,
##   the last moment a climax, the Warden the same person on every road in the
##   gear of that road's point of the journey - and a hundred seeds deal many
##   different trailers.
## - **The moments are data**: every line, range, light and zoom is authored and
##   sane, and every kind has a recipe.
## - **It opens only when welcome**: the setting on, not yet shown this launch,
##   not headless and not the web, and the screen-flash scale not turned down.
## - **Out of the splash and nowhere else**, as before.
## - **It plays**: a dealt trailer films its moments to the end, with the
##   Warden of each road dressed as the plan dealt them, the road a sandbox and
##   standing still, the score and the thumb controls held.
## - **Nothing is kept**: after it ends - finished or skipped, mid-moment or
##   while a road is standing up - the account is byte for byte what it was, the
##   clock, the score and the thumb controls are given back, and no road is left.
## - **Every way out works**: Escape, Enter, Space, a pad's A, B and Start, and
##   the Skip button, which is on the screen with nothing over it.

const TAG: String = "[trailer]"
const FIXTURE_DIR: String = "res://.automated_checks/trailer"
const FIXTURE_BASE: String = FIXTURE_DIR + "/probe.json"
const PLANS: int = 120

var _checks: int = 0
var _failures: int = 0
var _reached: Dictionary = {}
var _saved_root: String = ""
var _saved_slot: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_saved_root = MetaState.slot_root
	_saved_slot = MetaState.slot()
	_test_the_plans()
	_test_the_moments_are_data()
	_test_the_dragon_comes_quickly()
	_test_a_slow_machine_gets_a_lighter_trailer()
	_test_it_opens_only_when_welcome()
	_test_out_of_the_splash_and_nowhere_else()
	_open_the_fixture()
	await _test_it_plays()
	await _test_every_way_out()
	_close_the_fixture()
	for stage: String in ["plans", "moments", "lighter", "welcome", "splash", "plays", "skips"]:
		_check(_reached.has(stage), ("'%s' never reached its end - it aborted partway, and every "
			+ "check it had not made yet is a check nobody made") % stage)
	MetaState.resume_saves()
	TrailerPlayer.play_in_tests = false
	GameDirector.trailer_shown = false
	if _failures == 0:
		print(("%s PASS - %d checks: every trailer dealt is a journey over three acts with no "
			+ "moment twice and a climax last, the moments are data, it opens once and only "
			+ "when welcome, only out of the splash, films to the end with each road's Warden, "
			+ "keeps nothing however it ends, and every key and the Skip button let go") % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("%s %s" % [TAG, why])


# --- The plan -----------------------------------------------------------------

func _test_the_plans() -> void:
	var seen: Dictionary = {}
	var acts_seen: Dictionary = {}
	var maps_seen: Dictionary = {}
	var closers: Dictionary = {}
	var climbs: int = 0
	for index: int in PLANS:
		var plan: Dictionary = TrailerPlan.make(1000 + index * 7919)
		_check(var_to_str(plan) == var_to_str(TrailerPlan.make(1000 + index * 7919)),
			"one seed dealt two different trailers")
		var roads: Array = plan.get("roads", []) as Array
		_check(roads.size() == TrailerPlan.ROAD_ACTS.size(), "a trailer was dealt %d roads" % roads.size())
		var used: Dictionary = {}
		var person: Dictionary = {}
		var summary: PackedStringArray = []
		var last_place: int = -1
		var rarities: Array[float] = []
		for road_index: int in roads.size():
			var road: Dictionary = roads[road_index]
			var act: int = int(road["act"])
			var span: Array = TrailerPlan.ROAD_ACTS[road_index]
			_check(act >= int(span[0]) and act <= int(span[1]),
				"road %d was dealt act %d outside %s" % [road_index, act, span])
			acts_seen["%d:%d" % [road_index, act]] = true
			var map: String = String(road["map"])
			_check(MapModes.random_pool().has(map), "a road was dealt the layout '%s'" % map)
			maps_seen[map] = true
			var warden: Dictionary = road["warden"]
			_check(int(warden["act"]) == act and String(warden["tier"]) == String(road["tier"]),
				"road %d's Warden was dressed for act %d of %s, not act %d of %s"
				% [road_index, int(warden["act"]), warden["tier"], act, road["tier"]])
			var look: Dictionary = warden["look"]
			for key: String in TrailerPlan.PERSON:
				if person.has(key):
					_check(int(look[key]) == int(person[key]), "the Warden's %s changed between roads" % key)
				else:
					person[key] = look[key]
			var pieces: Dictionary = warden["pieces"]
			var total: float = 0.0
			for slot: Variant in pieces:
				total += float(int((pieces[slot] as Dictionary)["rarity"]))
			rarities.append(total / maxf(float(pieces.size()), 1.0))
			for moment: Dictionary in road["moments"] as Array:
				var id: String = String(moment["id"])
				var data: TrailerMomentData = ContentDB.trailer_moments.get(id, null) as TrailerMomentData
				_check(data != null, "a trailer dealt a moment there is no data for: %s" % id)
				if data == null:
					continue
				_check(not used.has(id), "a trailer showed '%s' twice" % id)
				used[id] = true
				_check(act >= data.first_act and act <= data.last_act,
					"'%s' was filmed in act %d, outside its acts %d-%d" % [id, act, data.first_act, data.last_act])
				_check(float(moment["seconds"]) >= data.seconds_min - 0.001 and float(moment["seconds"]) <= data.seconds_max + 0.001,
					"'%s' runs %.1f s" % [id, float(moment["seconds"])])
				_check(String(moment["line"]).is_empty() or data.lines.has(String(moment["line"])),
					"'%s' carries a line that is not its own" % id)
				last_place = int(data.place)
				summary.append("%d:%s" % [act, id])
		_check(last_place == TrailerMomentData.Place.LATE, "a trailer did not end on a climax (%s)" % ", ".join(summary))
		# **A moment marked always is in every cut** (owner, 2026-10-08:
		# "Trailer dragons missing").
		for value: Variant in ContentDB.trailer_moments.values():
			var always := value as TrailerMomentData
			if always != null and always.always:
				_check(used.has(always.id), "a trailer was dealt without '%s' (%s)"
					% [always.id, ", ".join(summary)])
		closers[summary[summary.size() - 1] if not summary.is_empty() else ""] = true
		if rarities.size() == 3 and rarities[2] >= rarities[0]:
			climbs += 1
		_check(float(plan["seconds"]) >= 25.0 and float(plan["seconds"]) <= 80.0,
			"a trailer was dealt %.0f seconds of moments" % float(plan["seconds"]))
		seen[", ".join(summary)] = true
	_check(seen.size() >= PLANS * 3 / 4, "%d seeds dealt only %d different trailers" % [PLANS, seen.size()])
	_check(acts_seen.size() >= 9, "only %d of the road-act pairs were ever dealt" % acts_seen.size())
	_check(maps_seen.size() >= 4, "only %d layouts were ever dealt" % maps_seen.size())
	_check(closers.size() >= 6, "the trailers end on only %d different moments" % closers.size())
	_check(climbs >= PLANS * 3 / 4, "the Warden's gear climbed from the first road to the last in only %d of %d" % [climbs, PLANS])
	_reached["plans"] = true


## **The trailer's dragon is over the pack in time to be seen** (owner,
## 2026-10-08). Staged the way the stage stages it - an authored plan and a
## hurried pass - and driven by hand: flying inside half a second, over the
## landing point well inside the shortest dragon moment, and on the ground there
## when the plan says it lands. The world's own pass is unhurried and is held to
## what it was.
func _test_the_dragon_comes_quickly() -> void:
	var data: TrailerMomentData = ContentDB.trailer_moments.get("dragon", null) as TrailerMomentData
	_check(data != null and data.always, "the dragon moment is not always dealt")
	if data == null:
		return
	var variant: String = ""
	for value: Variant in ContentDB.enemies.values():
		var kind := value as EnemyData
		if kind != null and kind.dragon_event_weight > 0.0:
			variant = kind.id
			break
	var centre := Vector2(200.0, -150.0)
	var reach: float = Balance.TRAILER_DRAGON_REACH
	var wyrm := DragonPass.new()
	wyrm.from = centre - Vector2.RIGHT * reach
	wyrm.to = centre + Vector2.RIGHT * reach
	wyrm.authored_plan = {"variant": variant, "rarity": 0, "landing": centre, "land": true,
		"fury": 1.25, "curve": Vector2.ZERO}
	add_child(wyrm)
	wyrm.set_process(false)
	_check(is_equal_approx(wyrm.pass_seconds, Balance.DRAGON_PASS_SECONDS)
			and is_equal_approx(wyrm.warning_seconds, Balance.DRAGON_WARNING_SECONDS),
		"the world's own pass is no longer the authored warning and crossing")
	wyrm.hurry(Balance.TRAILER_DRAGON_WARNING, Balance.TRAILER_DRAGON_CROSSING)
	var arrives: float = Balance.TRAILER_DRAGON_WARNING + Balance.TRAILER_DRAGON_CROSSING * 0.5
	_check(arrives < data.seconds_min * 0.5,
		"the trailer's dragon reaches the pack %.1f s into a moment of %.1f" % [arrives, data.seconds_min])
	wyrm.advance(Balance.TRAILER_DRAGON_WARNING + 0.05, 4)
	_check(bool(wyrm.get("_flying")), "the hurried dragon is not flying after its warning")
	wyrm.advance(Balance.TRAILER_DRAGON_CROSSING * 0.5, 40)
	_check(wyrm.is_landed() and wyrm.global_position.distance_to(centre) < 1.0,
		"the trailer's dragon did not land on the pack (%s, landed %s)"
			% [wyrm.global_position, wyrm.is_landed()])
	wyrm.queue_free()


func _test_the_moments_are_data() -> void:
	_check(ContentDB.trailer_moments.size() >= 10, "only %d trailer moments are authored" % ContentDB.trailer_moments.size())
	var stage := TrailerStage.new()
	var places: Dictionary = {}
	for value: Variant in ContentDB.trailer_moments.values():
		var moment := value as TrailerMomentData
		if moment == null:
			continue
		places[int(moment.place)] = true
		_check(stage.has_method("_stage_" + moment.id), "'%s' has no recipe to stage it" % moment.id)
		_check(moment.first_act >= 1 and moment.last_act <= Balance.FINAL_ASCENT_ACT and moment.first_act <= moment.last_act,
			"'%s' fits acts %d-%d" % [moment.id, moment.first_act, moment.last_act])
		_check(moment.seconds_min >= 3.0 and moment.seconds_max >= moment.seconds_min and moment.seconds_max <= 9.0,
			"'%s' runs %.1f-%.1f s" % [moment.id, moment.seconds_min, moment.seconds_max])
		_check(moment.zoom_min > 0.3 and moment.zoom_max >= moment.zoom_min and moment.zoom_max <= 2.0,
			"'%s' stands its camera at %.2f-%.2f" % [moment.id, moment.zoom_min, moment.zoom_max])
		_check(moment.daylight_min >= 0.0 and moment.daylight_max <= 1.0 and moment.daylight_min <= moment.daylight_max,
			"'%s' is lit %.2f-%.2f" % [moment.id, moment.daylight_min, moment.daylight_max])
		_check(not moment.lines.is_empty(), "'%s' has no line to say" % moment.id)
		for line: String in moment.lines:
			_check(line.length() >= 6 and line.length() <= 52, "'%s' says a line the screen cannot hold: %s" % [moment.id, line])
	for place: int in [TrailerMomentData.Place.OPEN, TrailerMomentData.Place.EARLY,
			TrailerMomentData.Place.MIDDLE, TrailerMomentData.Place.LATE]:
		_check(places.has(place), "no moment belongs in place %d of the cut" % place)
	stage.free()
	var text: TrailerText = ContentDB.trailer_text()
	_check(text != null and not text.opening.is_empty() and not text.tagline.is_empty() and text.act_card.contains("%s"),
		"the trailer's own words are missing")
	_reached["moments"] = true


## **A slow machine gets a lighter trailer before it gets none**: a moment a
## little over the floor lightens the rest (half the bodies, no peak), and only
## a moment under the floor after that ends it.
func _test_a_slow_machine_gets_a_lighter_trailer() -> void:
	var player := TrailerPlayer.new()
	var stage := TrailerStage.new()
	player.set("_stage", stage)
	player.filmed = ["warden"]
	player.set("_frames", 60)
	player.set("_frame_time", 60.0 / 55.0)
	_check(bool(player.call("_fast_enough")) and not stage.light, "a moment at 55 fps lightened the trailer")
	player.set("_frame_time", 60.0 / (Balance.TRAILER_MIN_FPS * 1.2))
	_check(bool(player.call("_fast_enough")) and stage.light,
		"a slow moment ended the trailer instead of lightening the rest")
	player.set("_frame_time", 60.0 / (Balance.TRAILER_MIN_FPS * 0.8))
	_check(not bool(player.call("_fast_enough")), "a moment under the floor after lightening did not end it")
	RunState.act = 9
	var light_pack: int = int(stage.call("_pack_size"))
	stage.light = false
	var full_pack: int = int(stage.call("_pack_size"))
	_check(light_pack < full_pack, "a lighter trailer sends packs of %d against %d" % [light_pack, full_pack])
	stage.free()
	player.free()
	_reached["lighter"] = true


# --- When it opens ------------------------------------------------------------------

func _test_it_opens_only_when_welcome() -> void:
	var kept: Dictionary = MetaState.settings.duplicate(true)
	TrailerPlayer.play_in_tests = true
	GameDirector.trailer_shown = false
	UserSettings.set_value(UserSettings.TRAILER_KEY, true)
	UserSettings.set_value(UserSettings.FLASH_KEY, 1.0)
	_check(TrailerPlayer.should_autoplay(), "a launch with the setting on does not open with the trailer")
	GameDirector.trailer_shown = true
	_check(not TrailerPlayer.should_autoplay(), "the trailer would open twice in one launch")
	GameDirector.trailer_shown = false
	UserSettings.set_value(UserSettings.TRAILER_KEY, false)
	_check(not TrailerPlayer.should_autoplay(), "the trailer opens with its setting off")
	UserSettings.set_value(UserSettings.TRAILER_KEY, true)
	UserSettings.set_value(UserSettings.FLASH_KEY, Balance.TRAILER_REDUCED_FLASH - 0.1)
	_check(not TrailerPlayer.should_autoplay(),
		"the trailer opens for a player who turned the screen flashes down")
	UserSettings.set_value(UserSettings.FLASH_KEY, 1.0)
	TrailerPlayer.play_in_tests = false
	_check(not TrailerPlayer.should_autoplay(), "the trailer would open headless, where there is no screen")
	_check(kept.has(UserSettings.TRAILER_KEY) or MetaState.settings.has(UserSettings.TRAILER_KEY),
		"'%s' is not a declared setting" % UserSettings.TRAILER_KEY)
	UserSettings.set_value(UserSettings.TRAILER_KEY, false)
	var text: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(text)
	UserSettings.set_value(UserSettings.TRAILER_KEY, true)
	if parsed is Dictionary and (parsed as Dictionary).get("settings") is Dictionary:
		MetaState.call("_read_settings", (parsed as Dictionary)["settings"])
	_check(not UserSettings.trailer_at_startup(), "turning the trailer off did not survive the save")
	MetaState.settings = kept
	_check(not FileAccess.file_exists("res://video/trailer.ogv"), "the old filmed trailer still ships beside the live one")
	_reached["welcome"] = true


func _test_out_of_the_splash_and_nowhere_else() -> void:
	var splash: String = FileAccess.get_file_as_string("res://scenes/ui/splash.gd")
	_check(splash.contains("GameDirector.after_splash()"), "the splash does not hand to after_splash")
	var director: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	var menu_at: int = director.find("func goto_menu() -> void:")
	var next_func: int = director.find("\nfunc ", menu_at + 10)
	var goto_menu_body: String = director.substr(menu_at, next_func - menu_at)
	_check(not goto_menu_body.contains("play_trailer") and not goto_menu_body.contains("after_splash"),
		"goto_menu opens the trailer - every way to the menu would replay it")
	var callers: PackedStringArray = []
	for path: String in _scripts("res://scenes") + _scripts("res://scripts") + _scripts("res://autoload"):
		var source: String = FileAccess.get_file_as_string(path)
		if source.contains("play_trailer") and not path.ends_with("GameDirector.gd"):
			callers.append(path)
	_check(callers.size() == 1 and callers[0].ends_with("main_menu.gd"),
		"play_trailer is reached from %s - it is the splash's and the menu door's alone" % ", ".join(callers))
	_check(director.contains("trailer_shown = true"), "play_trailer does not mark the launch as shown")
	_reached["splash"] = true


func _scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return found
	for sub: String in dir.get_directories():
		found.append_array(_scripts(folder.path_join(sub)))
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	return found


# --- Playing -------------------------------------------------------------------

func _player(seed: int) -> TrailerPlayer:
	var player := (load("res://scenes/ui/trailer_player.tscn") as PackedScene).instantiate() as TrailerPlayer
	player.leaves = false
	player.pace = 6.0
	player.plan_seed = seed
	add_child(player)
	return player


func _wait(seconds: float) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < int(seconds * 1000.0):
		await get_tree().process_frame


func _test_it_plays() -> void:
	var before: String = MetaState.serialized_save()
	var held_before: int = int(MetaState.get("_saves_held"))
	var player: TrailerPlayer = _player(4242)
	var road: Dictionary = (player.plan["roads"] as Array)[0]
	var looked: bool = false
	var started: int = Time.get_ticks_msec()
	while player.reason.is_empty() and Time.get_ticks_msec() - started < 90000:
		await get_tree().process_frame
		if not looked and not player.filmed.is_empty():
			looked = true
			_check(MetaState.saves_held(), "the account is not held while the trailer films")
			_check(TouchInput.held_off and MusicPlayer.score_held(), "the thumb controls or the score are not held")
			_check(RunState.sandbox, "the road being filmed is not a sandbox")
			_check(WardenLook.same(MetaState.look, (road["warden"] as Dictionary)["look"]),
				"the first road's Warden does not wear the look the plan dealt")
			var weapon: Dictionary = MetaState.equipped_piece(GearData.Slot.WEAPON)
			var dealt: Dictionary = ((road["warden"] as Dictionary)["pieces"] as Dictionary).get(GearData.Slot.WEAPON, {})
			_check(String(weapon.get("kind", "")) == String(dealt.get("kind", "")),
				"the first road's Warden carries %s, not the %s dealt" % [weapon.get("kind", ""), dealt.get("kind", "")])
			var stage := player.get_node_or_null("Stage") as TrailerStage
			if stage != null and stage.field != null and stage.field.hero != null:
				_check(stage.field.hero.input is TrailerStage.Director, "the Warden is not in the director's hands")
				_check(stage.run.journey == null or stage.run.journey.process_mode == Node.PROCESS_MODE_DISABLED,
					"the road walks while it is filmed, and a crossroad would open over a moment")
				# **No table is laid over a film** (owner, 2026-10-08: the
				# Arsenal's draft opened over the trailer and waited for a
				# press). A draft asked for, a portent and a fork, each through
				# the door that opens it in play.
				RunState.queue_augment("rank")
				stage.run.call("_on_augment_open_requested")
				stage.run.call("_offer_omens")
				stage.run.call("_open_crossroad", 0)
				var table: CrossroadScreen = stage.run.crossroad_ui
				_check(stage.run.filming(), "the road does not know it is being filmed")
				_check(table == null or not table.is_open(),
					"a draft, a portent or a fork opened over the trailer")
				_check(not stage.field.is_suspended(), "asking for a table froze the road under the film")
	_check(player.reason == "finished", "the trailer ended '%s', not finished" % player.reason)
	_check(player.filmed.size() >= 5, "the trailer filmed only %d moments: %s" % [player.filmed.size(), ", ".join(player.filmed)])
	_given_back(before, held_before, "a finished trailer")
	player.queue_free()
	await get_tree().process_frame
	_reached["plays"] = true


## Everything a trailer borrowed is back, however it ended.
func _given_back(before: String, held_before: int, how: String) -> void:
	var after: String = MetaState.serialized_save()
	# **Compared as content, not as text**: an account read back from the disk
	# writes its keys in the order the file held them, which is not the order
	# memory built them in. `JSON.stringify` sorts keys, so both sides are put
	# through it.
	_check(JSON.stringify(JSON.parse_string(after)) == JSON.stringify(JSON.parse_string(before)),
		"%s left the account changed: %s" % [how, _what_changed(before, after)])
	_check(int(MetaState.get("_saves_held")) == held_before, "%s left the saves held %d times rather than %d"
		% [how, int(MetaState.get("_saves_held")), held_before])
	_check(not GameDirector.run_active and not RunState.sandbox, "%s left a road running" % how)
	_check(is_equal_approx(Engine.time_scale, 1.0), "%s left the clock at %.2f" % [how, Engine.time_scale])
	_check(not TouchInput.held_off and not MusicPlayer.score_held(), "%s kept the thumb controls or the score" % how)
	var runs: int = 0
	for node: Node in get_tree().root.find_children("*", "Run", true, false):
		if not node.is_queued_for_deletion():
			runs += 1
	_check(runs == 0, "%s left %d roads standing" % [how, runs])


## The keys of the account that differ, and how, for a failure line that says
## what was kept rather than only that something was.
func _what_changed(before: String, after: String) -> String:
	var was: Variant = JSON.parse_string(before)
	var now: Variant = JSON.parse_string(after)
	if not (was is Dictionary and now is Dictionary):
		return "the save does not parse"
	var out: PackedStringArray = []
	for key: Variant in (was as Dictionary).keys() + (now as Dictionary).keys():
		var a: String = JSON.stringify((was as Dictionary).get(key, null))
		var b: String = JSON.stringify((now as Dictionary).get(key, null))
		if a != b and not out.has(String(key)):
			out.append("%s (%s -> %s)" % [String(key), a.left(160), b.left(160)])
	return "; ".join(out)


func _test_every_way_out() -> void:
	var presses: Array[Dictionary] = [
		{"name": "Escape", "event": _key(KEY_ESCAPE), "after": 0.3},
		{"name": "Enter", "event": _key(KEY_ENTER), "after": 2.5},
		# **Enter once the road is standing** (2026-10-08): the road is the
		# player's descendant and hears `_input` first, and its chat answers
		# Enter. Pressed on a timer, the sweep's load decided whether the road
		# was up yet - the one run it was, Enter opened the chat instead.
		{"name": "Enter on a standing road", "event": _key(KEY_ENTER), "after": 0.0,
			"road": true},
		# **And with something in the tree that eats Enter**: a node added to the
		# root after the trailer began hears `_input` before the player would.
		# The trailer's catcher must still hear it first, whatever stands below.
		{"name": "Enter past a node that eats it", "event": _key(KEY_ENTER), "after": 1.0,
			"hostile": true},
		{"name": "Space", "event": _key(KEY_SPACE), "after": 0.8},
		{"name": "a pad's A", "event": _pad(JOY_BUTTON_A), "after": 1.6},
		{"name": "a pad's B", "event": _pad(JOY_BUTTON_B), "after": 0.4},
		{"name": "a pad's Start", "event": _pad(JOY_BUTTON_START), "after": 3.0},
	]
	for press: Dictionary in presses:
		var before: String = MetaState.serialized_save()
		var held_before: int = int(MetaState.get("_saves_held"))
		var player: TrailerPlayer = _player(77 + presses.find(press))
		await _wait(float(press["after"]))
		if bool(press.get("road", false)):
			var waited: float = 0.0
			while waited < 20.0 and get_tree().root.find_children("*", "Run", true, false).is_empty():
				await _wait(0.1)
				waited += 0.1
			_check(not get_tree().root.find_children("*", "Run", true, false).is_empty(),
				"the trailer stood no road up to press Enter over")
			await _wait(0.5)
		var eater: EnterEater = null
		if bool(press.get("hostile", false)):
			eater = EnterEater.new()
			eater.name = "EnterEater"
			get_tree().root.add_child(eater)
			await get_tree().process_frame
		get_viewport().push_input(press["event"] as InputEvent)
		await get_tree().process_frame
		if eater != null:
			_check(not eater.ate, "a node that eats Enter heard it before the trailer did")
			eater.queue_free()
		_check(player.reason == "skipped", "%s did not skip the trailer (%s)"
			% [press["name"], player.reason if not player.reason.is_empty() else "still playing"])
		_given_back(before, held_before, "a trailer skipped by %s" % press["name"])
		player.queue_free()
		await get_tree().process_frame
	# The Skip button, where it is drawn and with nothing over it.
	var before_click: String = MetaState.serialized_save()
	var held_click: int = int(MetaState.get("_saves_held"))
	var clicked: TrailerPlayer = _player(91)
	await _wait(1.0)
	var skip := clicked.find_child("Skip", true, false) as Button
	_check(skip != null and skip.is_visible_in_tree(), "there is no Skip button on screen")
	if skip != null:
		var view: Rect2 = get_viewport().get_visible_rect()
		var rect: Rect2 = skip.get_global_rect()
		_check(view.encloses(rect), "the Skip button %s is not on the screen %s" % [rect, view])
		# Headless the viewport hovers nothing, so a pushed click cannot be the
		# test: what it would prove is that the button is the topmost listener.
		_check(skip.mouse_filter == Control.MOUSE_FILTER_STOP, "the Skip button does not take clicks")
		var above: PackedStringArray = []
		for node: Node in skip.get_parent().get_children():
			var control := node as Control
			if control == null or control == skip or control.get_index() < skip.get_index():
				continue
			if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().intersects(rect):
				above.append(String(control.name))
		_check(above.is_empty(), "%s lies over the Skip button and takes its clicks" % ", ".join(above))
		skip.pressed.emit()
		await get_tree().process_frame
		_check(clicked.reason == "skipped", "a click on Skip did not skip the trailer (%s)"
			% (clicked.reason if not clicked.reason.is_empty() else "still playing"))
	_given_back(before_click, held_click, "a trailer skipped by its button")
	clicked.queue_free()
	await get_tree().process_frame
	_reached["skips"] = true


func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


# --- The account ------------------------------------------------------------------

## A fixture account on disk, as `sandbox_check` uses: the trailer reads the
## account back from the disk when it ends, so the disk has to hold exactly
## what is in memory before it starts - and must never be a player's own.
func _open_the_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	MetaState.slot_root = FIXTURE_BASE
	_wipe_the_fixture()
	MetaState.call("_adopt_new_account")
	MetaState.resume_saves()
	MetaState.save_game()
	MetaState.finish_writes()


func _close_the_fixture() -> void:
	MetaState.hold_saves()
	_wipe_the_fixture()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
	MetaState.slot_root = _saved_root
	MetaState.set("_slot", _saved_slot)


func _wipe_the_fixture() -> void:
	var dir: DirAccess = DirAccess.open(FIXTURE_DIR)
	if dir == null:
		return
	for name: String in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FIXTURE_DIR.path_join(name)))


## A node that swallows Enter in `_input`, standing where a road's chat or an
## overlay would: added to the root after the trailer, so it is called before
## anything that came earlier.
class EnterEater extends Node:
	var ate: bool = false

	func _input(event: InputEvent) -> void:
		var key := event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_ENTER:
			ate = true
			get_viewport().set_input_as_handled()
