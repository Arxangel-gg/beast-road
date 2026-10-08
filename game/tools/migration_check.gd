extends Node

## **Migrations** (triage of 2026-10-07, adapted: "a herd crossing as one
## arrival through the existing arrival door").
##
##   godot --headless --path game res://tools/migration_check.tscn
##
## Holds that the migrants are harmless species with a line of their own that
## fits the banner, spread over most of the road; that an act's crossing is
## decided once, the same for the same road, about as often as authored, and
## without moving the arrivals' own dice; that a crossing is a herd of one
## species walking a line that keeps off the town at a steady pace rather than a
## flight; that the cap refuses a herd it has no room for; and that the road
## says it, on every screen.

const TAG: String = "[migration]"

var _run: Run = null
var _field: Battlefield = null
var _animals: Wildlife = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _said: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261010)
	GameDirector.run_active = true
	_test_the_migrants()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_field.hero.global_position = _field.town_position()
	_animals = _field.wildlife_system()
	if _check(_animals != null, "the field has no wildlife"):
		_animals.clear()
		# Stood still: the gate drives it by hand, so nothing arrives between.
		_animals.process_mode = Node.PROCESS_MODE_DISABLED
		EventBus.wildlife_migrating.connect(_on_migrating)
		_test_the_plan()
		_test_a_herd_crosses()
		_test_the_cap()
	_test_the_wiring()
	for stage: String in ["migrants", "plan", "herd", "cap", "wiring"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: harmless migrants with lines of their own, a crossing decided once an act on its own dice, a herd walking a line clear of the town, refused by the cap, and said on every screen" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
	return ok


func _on_migrating(kind_id: String, _from: Vector2, _to: Vector2) -> void:
	_said.append(kind_id)


func _test_the_migrants() -> void:
	var migrants: int = 0
	var acts: Dictionary = {}
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null or not kind.migrates:
			continue
		migrants += 1
		_check(not kind.is_hostile(), "%s hunts and migrates" % kind.id)
		_check(not kind.migration_line.is_empty() and kind.migration_line.length() <= 52,
			"%s's crossing line is %d characters, the banner holds 52" % [kind.id, kind.migration_line.length()])
		_check(not kind.acts.is_empty(), "%s migrates and belongs to no act" % kind.id)
		for act: int in kind.acts:
			acts[act] = true
	_check(migrants >= 10, "%d migrating species" % migrants)
	_check(acts.size() >= 8, "herds cross in only %d of the road's acts" % acts.size())
	_reached.append("migrants")


func _test_the_plan() -> void:
	var crossings: int = 0
	var planned: int = 0
	for seed_value: int in 30:
		RunState.run_seed = 900 + seed_value
		for act: int in range(1, Balance.ACT_COUNT + 1):
			if Wildlife.migrants_for(act).is_empty():
				continue
			var held: int = _animals.dice().state
			_animals.plan_migration(act)
			var due: float = _animals.migration_due()
			_check(_animals.dice().state == held, "planning a crossing moved the arrivals' own dice")
			_animals.plan_migration(act)
			_check(is_equal_approx(_animals.migration_due(), due), "the same road planned act %d twice differently" % act)
			planned += 1
			if due >= 0.0:
				crossings += 1
				_check(due >= Balance.WILDLIFE_MIGRATION_DELAY.x and due <= Balance.WILDLIFE_MIGRATION_DELAY.y,
					"a crossing due in %.1f s, outside its window" % due)
	var share: float = float(crossings) / float(maxi(planned, 1))
	_check(absf(share - Balance.WILDLIFE_MIGRATION_CHANCE) < 0.12,
		"herds crossed %.2f of acts, authored %.2f" % [share, Balance.WILDLIFE_MIGRATION_CHANCE])
	RunState.run_seed = 20261010
	_reached.append("plan")


func _test_a_herd_crosses() -> void:
	_animals.clear()
	_said.clear()
	var deer: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and kind.id == "deer":
			deer = kind
	if not _check(deer != null and deer.migrates, "the deer do not migrate"):
		_reached.append("herd")
		return
	var walked: int = _animals.start_migration(deer)
	_check(walked >= Balance.WILDLIFE_MIGRATION_MIN and walked <= Balance.WILDLIFE_MIGRATION_SIZE.y,
		"%d walked on in a herd" % walked)
	_check(_said.has("deer"), "the road never said the herd")
	var herd: Array[Dictionary] = []
	var group: int = -1
	for animal: Dictionary in _animals.living():
		if bool(animal.get("migrating", false)):
			herd.append(animal)
	_check(herd.size() == walked, "%d migrating animals for a herd of %d" % [herd.size(), walked])
	var town: Vector2 = _field.town_position()
	for animal: Dictionary in herd:
		_check((animal["data"] as WildlifeData).id == "deer", "a herd of deer has a stranger in it")
		_check(int(animal["state"]) == Wildlife.State.LEAVING, "a migrant is not on its way")
		if group < 0:
			group = int(animal["group_id"])
		_check(int(animal["group_id"]) == group, "a herd walks as more than one group")
		var start: Vector2 = animal["home"] as Vector2
		var goal: Vector2 = animal["goal"] as Vector2
		var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(town, start, goal)
		_check(nearest.distance_to(town) >= Balance.WILDLIFE_MIGRATION_TOWN_CLEAR - 200.0,
			"a migrant's line passes %d from the town" % int(nearest.distance_to(town)))
	if not herd.is_empty():
		var lead: Dictionary = herd[0]
		var sprite := lead["sprite"] as Node2D
		var from: Vector2 = sprite.global_position
		for _tick: int in 20:
			_animals._process_measured(0.05)
		var moved: float = sprite.global_position.distance_to(from)
		var walk: float = deer.speed * Balance.WILDLIFE_MIGRATION_PACE
		_check(moved > walk * 0.5 and moved < walk * 1.2,
			"a migrant covered %d in a second, its crossing pace is %d and its flight %d" % [int(moved), int(walk), int(deer.speed * deer.flee_speed_scale)])
		var toward: Vector2 = (lead["goal"] as Vector2) - from
		_check((sprite.global_position - from).dot(toward) > 0.0, "a migrant walked away from where it is going")
	_animals.clear()
	# And the timed path: a crossing due comes when its clock runs out.
	_said.clear()
	Wildlife.migrations_in_tests = true
	RunState.act = 1
	_animals.plan_migration(1)
	_animals.set("_migration_left", 0.05)
	_animals.set("_hush_left", 0.0)
	_animals._tick_migration(0.1)
	_check(_said.size() == 1, "a crossing whose clock ran out never came")
	_check(_animals.migration_due() < 0.0, "a crossing that came is still due")
	Wildlife.migrations_in_tests = false
	_animals.set("_migration_left", 0.05)
	_animals._tick_migration(0.1)
	_check(_said.size() == 1, "a headless road sent a crossing nobody asked for")
	_animals.clear()
	_reached.append("herd")


func _test_the_cap() -> void:
	_animals.clear()
	var filler: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and kind.id == "rabbit":
			filler = kind
	var cap: int = int(round(float(Balance.WILDLIFE_MAX) * Graphics.foliage_scale()))
	if filler != null:
		var town: Vector2 = _field.town_position()
		for index: int in cap - Balance.WILDLIFE_MIGRATION_MIN + 1:
			_animals._spawn(filler, town + Vector2(400.0 + float(index) * 30.0, 500.0))
	var room: int = cap - _animals.living().size()
	_check(room < Balance.WILDLIFE_MIGRATION_MIN, "the harness left %d of room" % room)
	_check(_animals.start_migration(null) == 0 or Wildlife.migrants_for(RunState.act).is_empty(),
		"a herd walked on with room for %d" % room)
	_animals.clear()
	_reached.append("cap")


func _test_the_wiring() -> void:
	var relay: String = FileAccess.get_file_as_string("res://scripts/systems/coop_relay.gd")
	_check(relay.contains("[\"wildlife_migrating\", _on_wildlife_migrating]"), "the relay does not carry a crossing out")
	_check(relay.contains("Fact.WILDLIFE_MIGRATING:") and relay.contains("bus.wildlife_migrating.emit("),
		"the relay does not bring a crossing in")
	_check(FileAccess.get_file_as_string("res://scenes/ui/hud.gd").contains("wildlife_migrating.connect"),
		"the HUD does not say a crossing")
	_reached.append("wiring")
