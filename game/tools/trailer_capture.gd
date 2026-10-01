extends Node

## Films one shot of the trailer from the real game (owner, 2026-10-01: *"make
## the trailer for our game ... implemented in the beginning of the game before
## the main menu transitions in"*).
##
## Every frame of the trailer is the game running: a seeded road, staged through
## the same doors a player's road goes through, with a scripted Warden at the
## controls and a camera the harness owns. Nothing is painted over it here - the
## titles are laid on in the edit, where they belong.
##
##   movie_offscreen.sh <profile> 1920 1080 <out.avi> 60 res://tools/trailer_capture.tscn --shot=<id>
##
## The shot list is data (`trailer/shots.json` at the repository root): which
## stage, which act, which seed, the light, the weather, how long, and where the
## camera starts and ends. The harness prints `[trailer] roll <frame>` the frame
## the shot is ready, so the edit can cut the warm-up off by frame count - Movie
## Maker records from the first frame the process draws. Saves are held, music is
## muted (the edit lays the score), and nothing is written to the account.

const DEFAULT_SHOTS: String = "../trailer/shots.json"

var run: Run = null
var shot: Dictionary = {}
var field: Battlefield = null
var _cam: Camera2D = null
var _rolling: bool = false
var _roll_left: float = 0.0
var _roll_total: float = 1.0
var _pilot: Pilot = null
## Where the camera is looking at the start and end of the shot, and its zoom.
var _look_from: Vector2 = Vector2.ZERO
var _look_to: Vector2 = Vector2.ZERO
var _zoom_from: float = 1.0
var _zoom_to: float = 1.0
## When set, the camera looks at this node (plus the drift) rather than a point.
var _follow: Node2D = null
var _followed: Vector2 = Vector2.ZERO
var _daylight: float = -1.0
var _beats: Array[Dictionary] = []
var _calibrate: bool = false


## **The Warden, scripted.** A `HeroInput` the harness steers: it walks to the
## body it is told to fight, swings once in reach, and casts the slots it is
## asked to the moment they come off cooldown. Read through the same doors a
## player's hands are, so every swing and every cast is the game's own.
class Pilot extends HeroInput:
	var goal: Vector2 = Vector2.INF
	var foe: Node2D = null
	var press: int = 0
	var reach: float = 78.0

	func move() -> Vector2:
		if hero == null:
			return Vector2.ZERO
		var aim_at: Vector2 = foe.global_position if foe != null and is_instance_valid(foe) else goal
		if not aim_at.is_finite():
			return Vector2.ZERO
		var gap: Vector2 = aim_at - hero.global_position
		if gap.length() <= reach:
			return Vector2.ZERO
		return gap.normalized()

	func aim(previous: Vector2) -> Vector2:
		if hero != null and foe != null and is_instance_valid(foe):
			var toward: Vector2 = foe.global_position - hero.global_position
			if toward.length() > 1.0:
				return toward.normalized()
		return previous

	func _read_press(button: int) -> bool:
		return press & button != 0

	func _read_hold(_mask: int) -> bool:
		return false

	func is_local() -> bool:
		return true


func _ready() -> void:
	var wanted: String = ""
	var path: String = ProjectSettings.globalize_path("res://").path_join(DEFAULT_SHOTS)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			wanted = argument.trim_prefix("--shot=")
		elif argument.begins_with("--shots="):
			path = argument.trim_prefix("--shots=")
		elif argument == "--calibrate":
			_calibrate = true
	shot = _find_shot(path, wanted)
	if shot.is_empty():
		push_error("[trailer] no shot '%s' in %s" % [wanted, path])
		get_tree().quit(1)
		return
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.runs_started = maxi(MetaState.runs_started, 12)
	for beat: MilestoneCinematicData in ContentDB.milestone_cinematics_sorted():
		MetaState.mark_milestone_cinematic_seen(beat.id)
	WardenGlass.mark_offered()
	Graphics.apply_preset(Graphics.PRESET_ULTRA)
	# The score is laid in the edit; what is recorded is the world.
	AudioBuses.ensure()
	var music: int = AudioServer.get_bus_index(AudioBuses.MUSIC)
	if music >= 0:
		AudioServer.set_bus_mute(music, true)
	_daylight = float(shot.get("daylight", -1.0))
	var stage: String = String(shot.get("stage", ""))
	if stage == "menu":
		await _stage_menu()
	else:
		await _stand_up_the_road()
		await call("_stage_" + stage)
	_roll()


func _find_shot(path: String, wanted: String) -> Dictionary:
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (parsed is Dictionary):
		return {}
	for entry: Variant in (parsed as Dictionary).get("shots", []):
		if entry is Dictionary and String((entry as Dictionary).get("id", "")) == wanted:
			return entry as Dictionary
	return {}


# --- The road -----------------------------------------------------------------------


func _stand_up_the_road() -> void:
	var act: int = int(shot.get("act", 1))
	RunState.reset(false, int(shot.get("seed", 20261001)))
	# **Never the Classic layout.** Its roads are the pinwheel the owner retired
	# from the new modes (2026-09-23); a trailer is a first impression and shows
	# the battlefields the game is moving to.
	RunState.map_mode = String(shot.get("map", MapModes.CITADEL))
	# A town worth looking at: every building raised to its top before the town is
	# laid out, so it is drawn whole rather than as a row of locked plots.
	if bool(shot.get("town_full", false)):
		for building: BuildingData in ContentDB.buildings_sorted():
			RunState.building_tiers[building.id] = building.max_tier
	if act > 1:
		var staging: GDScript = load("res://tools/perf_check.gd") as GDScript
		staging.call("stage_late_act", act, float(shot.get("waves_short", 12.0)))
	_dress_the_warden(String(shot.get("warden", "the trailer's warden")))
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	field = run.battlefield
	_cam = field.camera
	if _cam != null:
		_cam.set("target", null)
	if run.hud != null:
		run.hud.visible = bool(shot.get("hud", false))
	var fog: FogOfWar = field.fog()
	if fog != null and bool(shot.get("reveal", true)):
		fog.reveal_all()
	if not String(shot.get("weather", "")).is_empty():
		RunState.weather_id = String(shot["weather"])
		EventBus.weather_changed.emit(RunState.weather_id)
	if field.hero != null:
		field.hero.health.floor_hp = field.hero.health.max_hp * 0.6
		_pilot = Pilot.new(field.hero)
		field.hero.input = _pilot


## **A Warden dressed for the road.** A look and a full set of gear rolled from a
## name, as the Hold rolls its strangers, and every piece worn through the door
## a player's stash equips through - so what is filmed is a Warden the game can
## produce, armour, cape and weapon showing on the body.
func _dress_the_warden(who: String) -> void:
	var rolled: Dictionary = HoldYard.stranger_of(who)
	MetaState.look = (rolled["look"] as Dictionary).duplicate(true)
	var dice := RandomNumberGenerator.new()
	dice.seed = absi(hash("trailer-gear:" + who))
	for slot: int in Hero.DRESS_SLOTS:
		var kinds: Array[String] = HoldYard._wearable_kinds(slot)
		if kinds.is_empty():
			continue
		var kind: String = kinds[dice.randi_range(0, kinds.size() - 1)]
		if MetaState.take_gear(Stash.make(kind, 6, 30)):
			MetaState.equip(slot, MetaState.stash.size() - 1)


func _ride_on() -> void:
	for _attempt: int in 40:
		if not RunState.is_preparation():
			return
		run.set("_preparation_left", 0.0)
		run.call("_on_ride_on_requested")
		await get_tree().process_frame


## Waits until bodies are on the road and a little way in.
func _let_a_wave_arrive(seconds: float = 6.0) -> void:
	var waited: float = 0.0
	while waited < 40.0:
		if get_tree().get_nodes_in_group(Enemy.GROUP).size() >= 6:
			break
		if RunState.is_preparation():
			await _ride_on()
		await get_tree().process_frame
		waited += get_process_delta_time()
	await _wait(seconds)


func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _towers(count_per_lane: int, level: int, lanes: Array = [0, 1, 2, 3]) -> Array[Vector2i]:
	RunState.gain_every_currency(400000)
	RunState.building_tiers["forge"] = Balance.TOWER_LEVEL_CAP_BY_FORGE.size() - 1
	var kinds: Array[TowerData] = ContentDB.base_towers()
	var built: Array[Vector2i] = []
	var index: int = 0
	for lane: Variant in lanes:
		for _n: int in count_per_lane:
			var anchor: Vector2i = field.free_anchor_near(int(lane), 9)
			var kind: TowerData = kinds[(index * 7 + int(lane) * 3) % kinds.size()]
			index += 1
			if kind.is_well():
				kind = kinds[(index * 5) % kinds.size()]
			if field.try_build(anchor, kind).is_empty():
				built.append(anchor)
	for anchor: Vector2i in built:
		for _step: int in level - 1:
			if not field.try_upgrade(anchor).is_empty():
				break
			if RunState.level_at(anchor) == Balance.TOWER_SPECIALISE_LEVEL:
				RunState.set_tower_path(anchor, TowerData.Path.SPREAD)
	return built


func _arm(cards: Array, levels: int) -> void:
	for id: Variant in cards:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card == null:
			continue
		for _level: int in mini(levels, card.max_level()):
			RunState.take_road_card(String(id))


func _slot_spells(ids: Array) -> void:
	RunState.equipped_spells.clear()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		RunState.equipped_spells.append(String(ids[slot]) if slot < ids.size() else "")
	EventBus.spells_changed.emit()


func _camera(look_from: Vector2, look_to: Vector2, zoom_from: float, zoom_to: float,
		follow: Node2D = null) -> void:
	_look_from = look_from
	_look_to = look_to
	_zoom_from = zoom_from
	_zoom_to = zoom_to
	_follow = follow
	if follow != null:
		_followed = follow.global_position
	_place_camera(0.0, true)


func _place_camera(share: float, snap: bool) -> void:
	if _cam == null:
		return
	var eased: float = smoothstep(0.0, 1.0, share)
	var at: Vector2 = _look_from.lerp(_look_to, eased)
	if _follow != null and is_instance_valid(_follow):
		var t: float = 1.0 if snap else 1.0 - exp(-4.0 * get_process_delta_time())
		_followed = _followed.lerp(_follow.global_position, t)
		at += _followed
	_cam.global_position = at
	var zoom: float = lerpf(_zoom_from, _zoom_to, eased)
	_cam.zoom = Vector2.ONE * zoom
	_cam.set("_wanted_zoom", zoom)


# --- The recipes ----------------------------------------------------------------------


## Yuri walking at dawn: the city on its back, the road under its feet.
func _stage_beast() -> void:
	await _ride_on()
	run.switch_scope(GameDirector.Scope.BEAST)
	if run.hud != null:
		run.hud.visible = false
	await _wait(1.0)


## The Town, the refuge on the beast's back.
func _stage_town() -> void:
	run.switch_scope(GameDirector.Scope.TOWN)
	if run.hud != null:
		run.hud.visible = false
	await _wait(1.0)
	if run.town != null and run.town.camera != null:
		_cam = run.town.camera
		var home: Vector2 = _cam.global_position
		_camera(home + _vec("look_from", Vector2.ZERO), home + _vec("look_to", Vector2.ZERO),
			float(shot.get("zoom_from", _cam.zoom.x)), float(shot.get("zoom_to", _cam.zoom.x)))


## The whole field from above: four roads, a defence on each, a wave on all of them.
func _stage_wide() -> void:
	_towers(int(shot.get("towers", 3)), int(shot.get("level", 4)))
	await _let_a_wave_arrive(float(shot.get("settle", 7.0)))
	_stand_hero(_vec("hero_at", Battlefield.lane_vector(0) * 700.0))
	_camera(_vec("look_from", Vector2.ZERO), _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 0.4)), float(shot.get("zoom_to", 0.5)))


## The Warden in the thick of it: swinging, the Arsenal turning round them.
func _stage_warden() -> void:
	_towers(1, 3)
	_arm(shot.get("cards", []), int(shot.get("card_levels", 3)))
	_slot_spells(shot.get("spells", []))
	var lane: int = int(shot.get("lane", 0))
	_stand_hero(Battlefield.lane_vector(lane) * float(shot.get("out", 700.0)))
	await _let_a_wave_arrive(float(shot.get("settle", 9.0)))
	_camera(_vec("look_from", Vector2.ZERO), _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 1.0)), float(shot.get("zoom_to", 1.05)), field.hero)
	_beats.append({"kind": "fight", "spells": bool(shot.get("cast", false))})


## Preparation: towers rise from their foundations one after another, then climb.
func _stage_build() -> void:
	RunState.gain_every_currency(400000)
	RunState.building_tiers["forge"] = Balance.TOWER_LEVEL_CAP_BY_FORGE.size() - 1
	var lane: int = int(shot.get("lane", 0))
	var centre: Vector2 = Battlefield.lane_vector(lane) * float(shot.get("out", 620.0))
	_stand_hero(centre + Vector2(0.0, 220.0))
	_camera(centre + _vec("look_from", Vector2.ZERO), centre + _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 0.9)), float(shot.get("zoom_to", 1.0)))
	_beats.append({"kind": "build", "lane": lane, "every": float(shot.get("every", 0.5)),
		"count": int(shot.get("count", 6)), "left": 0.6, "built": [], "upgrades": 0})
	await _wait(0.5)


## A storm: rain, the flood, lightning walking the road, and the ground breaking.
func _stage_storm() -> void:
	_towers(2, 4)
	await _let_a_wave_arrive(float(shot.get("settle", 8.0)))
	var sky: WeatherSky = field.sky()
	var centre: Vector2 = _busy_point()
	_stand_hero(centre + Vector2(-160.0, 120.0))
	if sky != null:
		sky.forced_intensity = 1.0
		sky.set("_flood", float(shot.get("flood", 0.55)))
		RunState.flood = float(shot.get("flood", 0.55))
	_camera(centre + _vec("look_from", Vector2.ZERO), centre + _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 0.7)), float(shot.get("zoom_to", 0.78)))
	_beats.append({"kind": "storm", "centre": centre, "left": 0.3,
		"quake_at": float(shot.get("quake_at", 3.0)), "quaked": false})


## A funnel walking through a wave, lifting what it catches.
func _stage_tornado() -> void:
	_towers(2, 3)
	await _let_a_wave_arrive(float(shot.get("settle", 9.0)))
	var centre: Vector2 = _busy_point()
	_stand_hero(centre + Vector2(-260.0, 200.0))
	var sky: WeatherSky = field.sky()
	if sky != null:
		var funnel: Tornado = sky.spawn_tornado(centre + Vector2(-520.0, -60.0),
			centre + Vector2(620.0, 80.0), 30.0)
		if funnel != null:
			funnel.wander = 0.0
	_camera(centre + _vec("look_from", Vector2.ZERO), centre + _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 0.75)), float(shot.get("zoom_to", 0.8)))


## Something enormous crosses the field and breathes on what is under it.
func _stage_dragon() -> void:
	_towers(2, 4)
	await _let_a_wave_arrive(float(shot.get("settle", 8.0)))
	var centre: Vector2 = _busy_point()
	_stand_hero(centre + Vector2(-220.0, 240.0))
	var sky: WeatherSky = field.sky()
	var wyrm: DragonPass = null
	if sky != null:
		wyrm = sky.send_dragon(centre + Vector2(-1500.0, -700.0), centre + Vector2(1500.0, 500.0))
	await _wait(float(shot.get("lead", 2.0)))
	# The camera rides with the animal: at a field's width it is a speck.
	_camera(_vec("look_from", Vector2.ZERO), _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 0.6)), float(shot.get("zoom_to", 0.66)),
		wyrm if wyrm != null and is_instance_valid(wyrm) else null)
	if wyrm == null:
		_camera(centre, centre, float(shot.get("zoom_from", 0.6)), float(shot.get("zoom_to", 0.66)))


## An act boss steps onto the road and the Warden goes to meet it.
func _stage_boss() -> void:
	_towers(1, 4)
	_arm(shot.get("cards", []), 3)
	await _ride_on()
	await _wait(1.0)
	if run.boss_director != null:
		run.boss_director.summon(RunState.act)
	await _wait(float(shot.get("settle", 2.5)))
	var boss: Node2D = run.boss_director.get("_active") as Node2D if run.boss_director != null else null
	if boss == null or not is_instance_valid(boss):
		push_warning("[trailer] no boss stood up")
		return
	_stand_hero(boss.global_position + Vector2(-260.0, 160.0))
	_pilot.foe = boss
	_camera(_vec("look_from", Vector2(0.0, -120.0)), _vec("look_to", Vector2(0.0, -140.0)),
		float(shot.get("zoom_from", 0.62)), float(shot.get("zoom_to", 0.7)), boss)
	_beats.append({"kind": "fight", "spells": true, "keep_foe": true})


## The last act at its height: forty towers, the whole Arsenal, every spell.
func _stage_peak() -> void:
	var staging: GDScript = load("res://tools/perf_check.gd") as GDScript
	staging.call("build_late_board", field, ContentDB.base_towers())
	_arm(shot.get("cards", []), 5)
	_slot_spells(shot.get("spells", []))
	await _let_a_wave_arrive(float(shot.get("settle", 10.0)))
	_stand_hero(_busy_point())
	_camera(_vec("look_from", Vector2.ZERO), _vec("look_to", Vector2.ZERO),
		float(shot.get("zoom_from", 0.7)), float(shot.get("zoom_to", 0.62)), field.hero)
	_beats.append({"kind": "fight", "spells": true})


## A fork in the road: the cards dealt for the next stretch.
func _stage_crossroad() -> void:
	if run.hud != null:
		run.hud.visible = true
	await _ride_on()
	await _wait(1.5)
	run.call("_open_crossroad", 1)
	await _wait(0.2)


## The main menu as a returning player sees it.
func _stage_menu() -> void:
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _wait(1.0)
	# **The title card, not the front door.** The menu's own painting, title and
	# campfire, with the doors, the account's numbers and the build stamp put
	# away: an end card reads the name of the game, not a column of buttons.
	if bool(shot.get("clean", false)):
		for name: String in ["MenuScroll", "Stats", "Version"]:
			var node := menu.find_child(name, true, false) as CanvasItem
			if node != null:
				node.visible = false
		for node: Node in menu.find_children("*", "Label", true, false):
			var label := node as Label
			if label != null and label.is_visible_in_tree():
				label.visible = false


# --- Rolling --------------------------------------------------------------------------


func _roll() -> void:
	_roll_total = float(shot.get("seconds", 8.0))
	_roll_left = _roll_total
	_rolling = true
	print("[trailer] roll %d %s" % [Engine.get_frames_drawn(), String(shot.get("id", ""))])
	if _calibrate:
		var flash := ColorRect.new()
		flash.color = Color.WHITE
		flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var layer := CanvasLayer.new()
		layer.layer = 120
		layer.add_child(flash)
		add_child(layer)
		await get_tree().process_frame
		layer.queue_free()


func _process(delta: float) -> void:
	if not _rolling:
		return
	if _daylight >= 0.0:
		DayNight.call("_apply", _daylight)
	_place_camera(1.0 - _roll_left / maxf(_roll_total, 0.01), false)
	_tick_pilot(delta)
	for beat: Dictionary in _beats:
		_tick_beat(beat, delta)
	_roll_left -= delta
	if _roll_left <= 0.0:
		_rolling = false
		print("[trailer] cut %d" % Engine.get_frames_drawn())
		Sfx.stop_immediately()
		MusicPlayer.stop_immediately()
		Ambience.stop_immediately()
		get_tree().quit(0)


var _swing_left: float = 0.0


func _tick_pilot(delta: float) -> void:
	if _pilot == null or field == null or field.hero == null:
		return
	_pilot.press = 0
	var hero: Hero = field.hero
	hero.mana = hero.mana_max()
	var fighting: bool = false
	for beat: Dictionary in _beats:
		if String(beat.get("kind", "")) == "fight":
			fighting = true
	if not fighting:
		return
	var keep: bool = false
	for beat: Dictionary in _beats:
		keep = keep or bool(beat.get("keep_foe", false))
	if not keep or _pilot.foe == null or not is_instance_valid(_pilot.foe):
		_pilot.foe = _nearest_body(hero.global_position)
	if _pilot.foe == null:
		return
	var gap: float = hero.global_position.distance_to(_pilot.foe.global_position)
	_swing_left -= delta
	if gap <= _pilot.reach + 30.0 and _swing_left <= 0.0:
		_swing_left = 0.22
		_pilot.press |= HeroInput.BUTTON_ATTACK
	var casting: bool = false
	for beat: Dictionary in _beats:
		casting = casting or bool(beat.get("spells", false))
	if casting:
		for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
			if hero.spells.is_ready(slot) and gap < 520.0:
				_pilot.press |= HeroInput.spell_button(slot)
				break


func _tick_beat(beat: Dictionary, delta: float) -> void:
	match String(beat.get("kind", "")):
		"build":
			beat["left"] = float(beat["left"]) - delta
			if float(beat["left"]) > 0.0:
				return
			beat["left"] = float(beat["every"])
			var built: Array = beat["built"]
			if built.size() < int(beat["count"]):
				var kinds: Array[TowerData] = ContentDB.base_towers()
				var anchor: Vector2i = field.free_anchor_near(int(beat["lane"]), 6)
				var kind: TowerData = kinds[(built.size() * 5 + 2) % kinds.size()]
				if kind.is_well():
					kind = kinds[(built.size() * 5 + 3) % kinds.size()]
				if field.try_build(anchor, kind).is_empty():
					built.append(anchor)
			elif int(beat["upgrades"]) < built.size() * 3:
				var anchor: Vector2i = built[int(beat["upgrades"]) % built.size()]
				field.try_upgrade(anchor)
				beat["upgrades"] = int(beat["upgrades"]) + 1
				beat["left"] = float(beat["every"]) * 0.45
		"storm":
			var sky: WeatherSky = field.sky()
			if sky == null:
				return
			beat["left"] = float(beat["left"]) - delta
			var centre: Vector2 = beat["centre"]
			if float(beat["left"]) <= 0.0:
				beat["left"] = randf_range(0.45, 0.9)
				sky.strike_at(centre + Vector2(randf_range(-520.0, 520.0), randf_range(-300.0, 300.0)))
			var spent: float = _roll_total - _roll_left
			if not bool(beat["quaked"]) and spent >= float(beat["quake_at"]):
				beat["quaked"] = true
				sky.quake(1.0, ["quake"], centre + Vector2(80.0, -40.0))


func _nearest_body(from: Vector2) -> Enemy:
	var best: Enemy = null
	var gap: float = INF
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body == null or not is_instance_valid(body) or body.is_dying():
			continue
		var d: float = from.distance_squared_to(body.global_position)
		if d < gap:
			gap = d
			best = body
	return best


## The middle of the bodies nearest the town, or a point on the first road.
func _busy_point() -> Vector2:
	var bodies: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body != null and is_instance_valid(body):
			bodies.append(body.global_position)
	if bodies.is_empty():
		return Battlefield.lane_vector(0) * 700.0
	bodies.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() < b.length())
	var sum: Vector2 = Vector2.ZERO
	var take: int = mini(bodies.size(), 8)
	for index: int in take:
		sum += bodies[index]
	return sum / float(take)


func _stand_hero(at: Vector2) -> void:
	if field != null and field.hero != null:
		field.hero.global_position = at
		field.hero.velocity = Vector2.ZERO


func _vec(key: String, fallback: Vector2) -> Vector2:
	var value: Variant = shot.get(key, null)
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float((value as Array)[0]), float((value as Array)[1]))
	return fallback
