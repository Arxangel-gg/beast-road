class_name TrailerStage
extends Node

## **The live trailer's stage**: stands a road up the way the plan dealt it,
## puts the moments on it, and directs the Warden and the camera through each
## (owner, 2026-10-07: "Hyper epic trailers that are super aesthetically
## appealing and exciting and procedurally randomized for all. The player's
## look at and walking around etc should also be directed with randomized
## proceduralism that is natural").
##
## Every frame is the game running: a real road (`run.tscn`) through the doors a
## player's road goes through, a board built through `try_build`, weapons drafted
## through `take_road_card`, a boss summoned by its own director. What the stage
## owns is only what a film crew would: where the camera is, what time of day it
## is, and the Warden's hands (`Director`, a `HeroInput`).
##
## **The road is the one a Warden would have at that point** - towers on every
## road in the number and at the level that act's purse buys, the Arsenal as
## deep as the drafts by then deal, the spell slots the bosses have opened -
## and the Warden is dressed by `ProceduralWarden` for the same point.
##
## Nothing here is kept. The trailer holds saves for its whole length and reads
## the account back from the disk when it ends (`TrailerPlayer`); a road is
## `RunState.sandbox`, so it records no sighting, no kill and no best.

signal moment_ready

var run: Run = null
var field: Battlefield = null
var road: Dictionary = {}
var moment: Dictionary = {}
var cancelled: bool = false
## **Lighter**, once a moment has run slow on this machine (`TrailerPlayer`):
## half the bodies a fight sends, and the heaviest moment filmed as an ordinary
## fight - the trailer gets lighter rather than stopping before its climax.
var light: bool = false
## Seconds a stand-up may take before it is given up on; and how fast the world
## runs while it is hidden under a card.
var setup_time_scale: float = Balance.TRAILER_SETUP_TIME_SCALE

var _cam: Camera2D = null
var _director: Director = null
var _dice := RandomNumberGenerator.new()
var _rolling: bool = false
var _left: float = 0.0
var _total: float = 1.0
var _look_from: Vector2 = Vector2.ZERO
var _look_to: Vector2 = Vector2.ZERO
var _zoom_from: float = 1.0
var _zoom_to: float = 1.0
var _follow: Node2D = null
var _followed: Vector2 = Vector2.ZERO
var _phase: float = -1.0
var _beats: Array[Dictionary] = []


## **The Warden's hands, directed.** A `HeroInput` the stage steers through the
## doors a player's hands use: where to walk, what to look at, when to swing,
## dash, cast, sprint or ride. The look turns at a rate rather than snapping, so
## a head swinging from the town to the horde reads as a person turning.
class Director extends HeroInput:
	var goal: Vector2 = Vector2.INF
	var foe: Node2D = null
	var look_at: Vector2 = Vector2.INF
	var press: int = 0
	var hold: int = 0
	var reach: float = 78.0
	var arrive: float = 26.0
	var turn_rate: float = 5.0
	var _aim: Vector2 = Vector2.DOWN

	func move() -> Vector2:
		if hero == null:
			return Vector2.ZERO
		var target: Vector2 = goal
		var stop_at: float = arrive
		if foe != null and is_instance_valid(foe):
			target = foe.global_position
			stop_at = reach
		if not target.is_finite():
			return Vector2.ZERO
		var gap: Vector2 = target - hero.global_position
		if gap.length() <= stop_at:
			return Vector2.ZERO
		return gap.normalized()

	func aim(previous: Vector2) -> Vector2:
		if hero == null:
			return previous
		var wanted: Vector2 = Vector2.ZERO
		if foe != null and is_instance_valid(foe):
			wanted = foe.global_position - hero.global_position
		elif look_at.is_finite():
			wanted = look_at - hero.global_position
		else:
			wanted = move()
		if wanted.length() < 1.0:
			return _aim
		var step: float = clampf(turn_rate * hero.get_process_delta_time(), 0.0, 1.0)
		_aim = _aim.slerp(wanted.normalized(), step).normalized()
		return _aim

	func _read_press(button: int) -> bool:
		return press & button != 0

	func _read_hold(mask: int) -> bool:
		return hold & mask != 0

	func is_local() -> bool:
		return true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# --- The road ---------------------------------------------------------------

## Stands a dealt road up: a fresh run at its act, on its layout and seed, the
## Warden dressed for that point of the journey, the board, the Arsenal and the
## spells that point would have, and a wave on the road. Returns false when it
## could not, which the player answers by skipping the road.
func stand_up(plan_road: Dictionary) -> bool:
	take_down()
	road = plan_road
	_dice.seed = int(road.get("seed", 1)) * 31 + 7
	var act: int = clampi(int(road.get("act", 1)), 1, Balance.FINAL_ASCENT_ACT)
	RunState.reset(false, int(road.get("seed", 1)))
	RunState.sandbox = true
	RunState.map_mode = MapModes.sanitise(String(road.get("map", MapModes.FALLBACK)))
	RunState.map_varied = bool(road.get("varied", false))
	_stage_act(act)
	var tier: CampaignTierData = ContentDB.tier(String(road.get("tier", "")))
	if tier != null:
		RunState.tier_id = tier.id
	ProceduralWarden.wear(road.get("warden", {}) as Dictionary)
	_saddle_a_mount(act)
	_raise_the_town(act)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 12:
		await get_tree().process_frame
		if cancelled:
			return false
	field = run.battlefield
	if field == null or field.hero == null:
		return false
	_deafen(run)
	# **The road stands still while it is filmed.** Its walk is what opens a
	# crossroad, calls the act's boss and turns the day; a moment is seconds of a
	# road, and a crossroad's screen over a fight is not one of them.
	if run.journey != null:
		run.journey.process_mode = Node.PROCESS_MODE_DISABLED
	_cam = field.camera
	if _cam != null:
		_cam.set("target", null)
	if run.hud != null:
		run.hud.visible = false
	var fog: FogOfWar = field.fog()
	if fog != null:
		fog.reveal_all()
	var weather: String = String(road.get("weather", ""))
	if not weather.is_empty():
		RunState.weather_id = weather
		EventBus.weather_changed.emit(weather)
	field.hero.health.floor_hp = field.hero.health.max_hp * 0.55
	# Nothing ends a road that is only being filmed: the wall holds, as it does
	# for a party turning for home.
	if field.town != null and field.town.health != null:
		field.town.health.floor_hp = field.town.health.max_hp * 0.5
	_director = Director.new(field.hero)
	field.hero.input = _director
	_build_the_board(act)
	_draft_the_arsenal(act)
	_slot_the_spells(act)
	await _bring_a_wave()
	return not cancelled


## Takes the road down: the run freed, the clock given back.
func take_down() -> void:
	_rolling = false
	_beats.clear()
	_follow = null
	GameSpeed.restore()
	if run != null and is_instance_valid(run):
		run.queue_free()
	run = null
	field = null
	_director = null
	_cam = null


## The run's place on its road: the act, a stretch before its boss, its region
## and a Forge that opens every rung - as a player who walked there would stand.
func _stage_act(act: int) -> void:
	RunState.act = act
	var short: float = _dice.randf_range(8.0, 22.0)
	RunState.distance_travelled = maxf(Balance.act_end_distance(act)
		- Balance.WAVE_ROAD_DISTANCE * short, Balance.act_start_distance(act))
	RunState.wave_number = maxi(int(round(RunState.distance_travelled / Balance.WAVE_ROAD_DISTANCE)), 1)
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	if terrain != null:
		RunState.terrain_id = terrain.id
	RunState.building_tiers["forge"] = Balance.TOWER_LEVEL_CAP_BY_FORGE.size() - 1


## A horse in the stable, so a moment can ride: a pony early on, something
## grander late - in memory only, under held saves.
func _saddle_a_mount(act: int) -> void:
	var mounts: Array = ContentDB.mounts.keys()
	mounts.sort()
	if mounts.is_empty():
		return
	var index: int = clampi(int(floor(float(act - 1) / float(Balance.FINAL_ASCENT_ACT) * mounts.size())), 0, mounts.size() - 1)
	var id: String = String(mounts[(index + _dice.randi_range(0, 1)) % mounts.size()])
	if not MetaState.mounts.has(id):
		MetaState.mounts.append(id)
	MetaState.mount_saddled = id


## The town on Yuri's back, grown as far as a Warden this far along has grown it.
func _raise_the_town(act: int) -> void:
	var share: float = clampf(float(act) / float(Balance.FINAL_ASCENT_ACT), 0.0, 1.0)
	for building: BuildingData in ContentDB.buildings_sorted():
		# Never a locked plot: a trailer's town is lived in from its first road.
		RunState.building_tiers[building.id] = clampi(int(round(float(building.max_tier) * share)) + _dice.randi_range(0, 1),
			1, building.max_tier)
	RunState.building_tiers["forge"] = Balance.TOWER_LEVEL_CAP_BY_FORGE.size() - 1


## No hand of a player's reaches the road: the run and everything under it stop
## reading input, so a key or a click is the trailer's alone.
func _deafen(node: Node) -> void:
	node.set_process_input(false)
	node.set_process_unhandled_input(false)
	node.set_process_unhandled_key_input(false)
	node.set_process_shortcut_input(false)
	for child: Node in node.get_children():
		_deafen(child)


## **The board that act's purse buys**: a tower or two a road in Act I, a road
## lined with them near the summit, climbed to the rungs the Gold of that act
## reaches, a path taken at the split. Built and climbed through the player's
## own doors, so every tower is one the road could have stood up.
func _build_the_board(act: int) -> void:
	RunState.gain_every_currency(900000)
	var kinds: Array[TowerData] = []
	for kind: TowerData in ContentDB.base_towers():
		if not kind.is_well():
			kinds.append(kind)
	if kinds.is_empty():
		return
	var per_lane: int = clampi(1 + int(round(float(act - 1) * 0.85)) + _dice.randi_range(-1, 1), 1, 9)
	var level: int = clampi(1 + int(round(float(act - 1) * 0.75)), 1, 10)
	var built: Array[Vector2i] = []
	for lane: int in Balance.LANE_COUNT:
		for _n: int in per_lane:
			var anchor: Vector2i = field.free_anchor_near(lane, 9)
			var kind: TowerData = kinds[_dice.randi_range(0, kinds.size() - 1)]
			if field.try_build(anchor, kind).is_empty():
				built.append(anchor)
	for anchor: Vector2i in built:
		var climb: int = clampi(level + _dice.randi_range(-1, 1), 1, 10)
		for _step: int in climb - 1:
			if not field.try_upgrade(anchor).is_empty():
				break
			if RunState.level_at(anchor) == Balance.TOWER_SPECIALISE_LEVEL:
				var paths: Array[int] = [TowerData.Path.FOCUS, TowerData.Path.SPREAD, TowerData.Path.BULWARK]
				RunState.set_tower_path(anchor, paths[_dice.randi_range(0, paths.size() - 1)])


## The weapons the drafts by that act would have dealt, at the levels they would
## have grown to.
func _draft_the_arsenal(act: int) -> void:
	var deck: Array[String] = []
	for value: Variant in ContentDB.road_cards.values():
		var card := value as RoadCardData
		if card != null and card.is_weapon() and not card.retired and card.evolves_from.is_empty():
			deck.append(card.id)
	deck.sort()
	var count: int = clampi(1 + act / 2 + _dice.randi_range(0, 1), 1, 7)
	var levels: int = clampi(1 + (act - 1) / 2, 1, 5)
	for _pick: int in count:
		if deck.is_empty():
			break
		var id: String = deck.pop_at(_dice.randi_range(0, deck.size() - 1))
		var card: RoadCardData = ContentDB.road_card(id)
		for _level: int in mini(levels, card.max_level()):
			RunState.take_road_card(id)


## The spell slots the bosses have opened by that act, each holding a spell.
func _slot_the_spells(act: int) -> void:
	var ids: Array = ContentDB.spells.keys()
	ids.sort()
	var open: int = 2 if act <= 1 else (3 if act == 2 else Balance.HERO_MAX_SPELL_SLOTS)
	RunState.equipped_spells.clear()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var id: String = ""
		if slot < open and not ids.is_empty():
			id = String(ids.pop_at(_dice.randi_range(0, ids.size() - 1)))
		RunState.equipped_spells.append(id)
	EventBus.spells_changed.emit()


## The road rides on and the world runs fast, hidden, until a wave is well onto
## the road - or the stand-up runs out of time, and what is there is filmed.
func _bring_a_wave() -> void:
	Engine.time_scale = setup_time_scale
	var waited: float = 0.0
	while waited < Balance.TRAILER_SETUP_SECONDS and not cancelled:
		if RunState.is_preparation():
			run.set("_preparation_left", 0.0)
			run.call("_on_ride_on_requested")
		if _bodies().size() >= 8 and not RunState.is_preparation():
			break
		await get_tree().process_frame
		waited += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	var extra: float = 0.0
	while extra < 0.6 and not cancelled:
		await get_tree().process_frame
		extra += get_process_delta_time() / maxf(Engine.time_scale, 0.01)
	GameSpeed.restore()


# --- The moments ------------------------------------------------------------

## Puts a dealt moment on the road - hidden, under a cut, with the world running
## fast while it settles - and readies the camera and the Warden for it.
func prepare(dealt: Dictionary) -> void:
	moment = dealt
	_beats.clear()
	_follow = null
	_rolling = false
	_dice.seed = int(dealt.get("dice", 1))
	_phase = float(dealt.get("daylight", -1.0))
	if _phase >= 0.0:
		DayNight.call("_apply", _phase)
	if field == null:
		return
	_clear_the_air()
	if field.hero != null and field.hero.is_mounted():
		field.hero.dismount()
	if run != null:
		run.switch_scope(GameDirector.Scope.BATTLEFIELD)
		_cam = field.camera
		if _cam != null:
			_cam.set("target", null)
	if field.hero != null:
		field.hero.mana = field.hero.mana_max()
	var id: String = String(dealt.get("id", ""))
	if has_method("_stage_" + id):
		await call("_stage_" + id)
	else:
		await _stage_warden()
	if not _gone():
		moment_ready.emit()


## Whether the road was taken down under an await - a skip while a moment was
## being staged - so nothing goes on to touch it.
func _gone() -> bool:
	return cancelled or run == null or not is_instance_valid(run) or field == null


## Whether a moment is being filmed right now.
func is_rolling() -> bool:
	return _rolling


## **Every moment on a clean field.** The last moment's storm is let go - it
## forced the rain to full and stood a flood, and left on it is a heavy screen
## under every moment after it - and the bodies it sent are taken off, so a road
## of three moments films three packs, not one pack and the two before it.
func _clear_the_air() -> void:
	var sky: WeatherSky = field.sky()
	if sky != null and sky.forced_intensity >= 0.0:
		sky.forced_intensity = -1.0
		sky.set("_flood", 0.0)
		RunState.flood = 0.0
		var weather: String = String(road.get("weather", ""))
		RunState.weather_id = weather if not weather.is_empty() else "clear"
		EventBus.weather_changed.emit(RunState.weather_id)
	for body: Enemy in _bodies():
		body.queue_free()


## Rolls the moment for its seconds and returns when it is done.
func roll(seconds: float) -> void:
	_total = maxf(seconds, 0.1)
	_left = _total
	_rolling = true
	while _rolling and not cancelled:
		await get_tree().process_frame


func _process(delta: float) -> void:
	if not _rolling or field == null:
		return
	var real: float = delta / maxf(Engine.time_scale, 0.01)
	# The light is held where the moment set it - re-applied only if something
	# moved it, because applying it publishes to every light and tint on the
	# field, and doing that every frame cost the heavy moments half their rate.
	if _phase >= 0.0 and absf(DayNight.phase - _phase) > 0.0005:
		DayNight.call("_apply", _phase)
	_place_camera(1.0 - _left / _total, false)
	_direct(delta)
	for beat: Dictionary in _beats:
		_tick_beat(beat, delta)
	_left -= real
	if _left <= 0.0:
		_rolling = false


## Opening: Yuri walking, the city on its back.
func _stage_beast() -> void:
	if run == null:
		return
	run.switch_scope(GameDirector.Scope.BEAST)
	await _wait(0.6)


## The city on Yuri's back, the camera drifting over its roofs.
func _stage_town() -> void:
	if run == null:
		return
	run.switch_scope(GameDirector.Scope.TOWN)
	await _wait(0.5)
	if _gone():
		return
	if run.town != null and run.town.camera != null:
		_cam = run.town.camera
		var home: Vector2 = _cam.global_position
		var drift: Vector2 = moment.get("drift", Vector2.ZERO) as Vector2
		_camera(home - drift * 40.0, home + drift * 40.0, float(moment["zoom_from"]), float(moment["zoom_to"]))


## The whole field from above: four roads, a defence on each, the wave on all.
## The Warden walks out along a road, stops, and looks toward what is coming.
func _stage_wide() -> void:
	for each: int in Balance.LANE_COUNT:
		_send_a_pack(maxi(_pack_size() / 2, 4), Battlefield.lane_vector(each) * _dice.randf_range(820.0, 1100.0))
	var lane: int = _dice.randi_range(0, Balance.LANE_COUNT - 1)
	var out: Vector2 = Battlefield.lane_vector(lane)
	_stand(out * 360.0)
	_mode = &"stroll"
	_strolls = [out * 620.0, out * 760.0 + out.orthogonal() * 120.0]
	var drift: Vector2 = moment.get("drift", Vector2.ZERO) as Vector2
	_camera(drift * 120.0, -drift * 60.0, float(moment["zoom_from"]), float(moment["zoom_to"]))


## Preparation's work: towers rising out of their foundations one after another
## and climbing, the Warden walking among them looking at each.
func _stage_build() -> void:
	RunState.gain_every_currency(400000)
	var lane: int = _dice.randi_range(0, Balance.LANE_COUNT - 1)
	var centre: Vector2 = Battlefield.lane_vector(lane) * _dice.randf_range(520.0, 700.0)
	_stand(centre + Vector2(_dice.randf_range(-160.0, 160.0), 200.0))
	_mode = &"stroll"
	_strolls = [centre + Vector2(-120.0, 120.0), centre + Vector2(140.0, 80.0)]
	_beats.append({"kind": "build", "lane": lane, "every": _dice.randf_range(0.42, 0.62),
		"count": _dice.randi_range(4, 6), "left": 0.3, "built": [], "upgrades": 0})
	_camera(centre + Vector2(0.0, 30.0), centre + Vector2(0.0, -10.0),
		float(moment["zoom_from"]), float(moment["zoom_to"]))


## The Warden in the thick of it: into the wave, swinging, stepping out, the
## Arsenal turning round them.
func _stage_warden() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size(), _a_stretch_of_road())
	_stand(centre + _from_side(_dice.randf_range(260.0, 360.0)))
	_mode = &"fight"
	_casting = _dice.randf() < 0.35
	_follow_with(field.hero, moment.get("drift", Vector2.ZERO) as Vector2 * 40.0)


## A Warden of the casting kind, every spell coming off cooldown.
func _stage_spells() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size() + 4, _a_stretch_of_road())
	_stand(centre + _from_side(_dice.randf_range(320.0, 420.0)))
	_mode = &"fight"
	_casting = true
	_follow_with(field.hero, moment.get("drift", Vector2.ZERO) as Vector2 * 50.0)


## Out of the gate on horseback, down the road at a gallop, and the charge into
## the front of the wave.
func _stage_ride() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size(), _a_stretch_of_road())
	var from: Vector2 = centre + _from_side(_dice.randf_range(620.0, 760.0))
	_stand(from)
	if field.hero != null:
		field.hero.mount()
	await _wait(0.4)
	if _gone():
		return
	_mode = &"ride"
	_ride_target = centre
	_rammed = false
	_follow_with(field.hero, (centre - from).normalized() * 160.0)


## **A quiet morning at the water**: the Warden on a bank at first light, a
## look out over the pond and a line cast into it - the calm a trailer needs
## before its storm.
func _stage_pond() -> void:
	var ponds: Fishing = field.ponds()
	var list: Array = ponds.get("_ponds") as Array if ponds != null else []
	if list.is_empty():
		await _stage_wide()
		return
	var pond: Dictionary = list[_dice.randi_range(0, list.size() - 1)]
	# The heart, not the dig point: a pond's `at` can be dry ground beside water
	# that fell to one side, and a bank searched from there is in the water.
	var centre: Vector2 = pond.get("heart", pond.get("at", Vector2.ZERO)) as Vector2
	var bank: Vector2 = _bank_of(centre)
	_stand(bank)
	_mode = &"pond"
	_watch_point = centre
	_cast_in = _dice.randf_range(0.5, 1.0)
	_cast_hold = 0.0
	var drift: Vector2 = moment.get("drift", Vector2.ZERO) as Vector2
	_camera(bank.lerp(centre, 0.35) + drift * 30.0, bank.lerp(centre, 0.45) - drift * 20.0,
		float(moment["zoom_from"]), float(moment["zoom_to"]))


## A spot on dry ground at the edge of a pond, on its south side when it has
## one, so the Warden faces the water and the camera both.
func _bank_of(centre: Vector2) -> Vector2:
	var best: Vector2 = centre + Vector2(0.0, 200.0)
	var best_score: float = INF
	for slice: int in 16:
		var toward: Vector2 = Vector2.DOWN.rotated(TAU * float(slice) / 16.0)
		for step: int in range(2, 40):
			var at: Vector2 = centre + toward * float(step) * 18.0
			# Dry here and for two steps further out: the edge of a pond is a
			# slope of depth, and the first dry sample can be a wading spot.
			if field.water_depth_at(at) <= 0.001 and field.water_depth_at(at + toward * 18.0) <= 0.001 \
					and field.water_depth_at(at + toward * 36.0) <= 0.001:
				var score: float = float(step) + absf(toward.angle_to(Vector2.DOWN)) * 6.0
				if score < best_score:
					best_score = score
					best = at + toward * 48.0
				break
	return best


## **A Herald on the road**: a pack sent, one of it promoted to the gold body
## only the Warden can stop, and the Warden sprinting it down.
func _stage_herald() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size(), _a_stretch_of_road())
	var herald: Enemy = _nearest_body(centre, 700.0)
	if herald != null:
		herald.make_herald()
	_stand(centre + _from_side(_dice.randf_range(380.0, 460.0)))
	_mode = &"fight"
	_casting = false
	if herald != null:
		_director.foe = herald
		_keep_foe = true
	_follow_with(field.hero, moment.get("drift", Vector2.ZERO) as Vector2 * 50.0)


## The road at night: torches on every bend, the Warden fighting in the light
## of them.
func _stage_night() -> void:
	await _stage_warden()


## A storm: rain, the flood rising, lightning walking the road and the ground
## breaking. The Warden stands and watches it come.
func _stage_storm() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size(), _a_stretch_of_road())
	RunState.weather_id = _storm_weather()
	EventBus.weather_changed.emit(RunState.weather_id)
	var sky: WeatherSky = field.sky()
	var flood: float = _dice.randf_range(0.35, 0.6)
	if sky != null:
		sky.forced_intensity = 1.0
		sky.set("_flood", flood)
		RunState.flood = flood
	_stand(centre + _from_side(_dice.randf_range(220.0, 320.0)))
	_mode = &"watch"
	_watch_point = centre
	var drift: Vector2 = moment.get("drift", Vector2.ZERO) as Vector2
	_camera(centre + drift * 50.0, centre - drift * 50.0, float(moment["zoom_from"]), float(moment["zoom_to"]))
	_beats.append({"kind": "storm", "centre": centre, "left": 0.25,
		"quake_at": _dice.randf_range(1.6, 3.2), "quaked": false})


## A funnel walking through the wave, lifting what it catches - and the Warden
## backing away from it.
func _stage_tornado() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size(), _a_stretch_of_road())
	var side: float = 1.0 if _dice.randf() < 0.5 else -1.0
	_stand(centre + Vector2(-260.0 * side, 200.0))
	var sky: WeatherSky = field.sky()
	if sky != null:
		var funnel: Tornado = sky.spawn_tornado(centre + Vector2(-540.0 * side, -60.0),
			centre + Vector2(640.0 * side, 80.0), 30.0)
		if funnel != null:
			funnel.wander = 0.0
			_watched = funnel
	_mode = &"watch"
	_watch_point = centre
	_camera(centre + Vector2(-60.0 * side, 0.0), centre + Vector2(60.0 * side, -20.0),
		float(moment["zoom_from"]), float(moment["zoom_to"]))


## Something enormous crosses the field and breathes on what is under it; the
## camera rides with it, and the Warden on the ground looks up.
func _stage_dragon() -> void:
	var centre: Vector2 = _send_a_pack(_pack_size(), _a_stretch_of_road())
	_stand(centre + _from_side(_dice.randf_range(200.0, 300.0)))
	var sky: WeatherSky = field.sky()
	var wyrm: DragonPass = null
	if sky != null:
		var across: Vector2 = Vector2(1.0, _dice.randf_range(-0.35, 0.35)).normalized()
		if _dice.randf() < 0.5:
			across = -across
		wyrm = sky.send_dragon(centre - across * 1500.0, centre + across * 1500.0)
	await _wait(_dice.randf_range(0.6, 1.2))
	if _gone():
		return
	_mode = &"watch"
	_watch_point = centre
	_watched = wyrm
	if wyrm != null and is_instance_valid(wyrm):
		_follow_with(wyrm, Vector2.ZERO)
	else:
		_camera(centre, centre, float(moment["zoom_from"]), float(moment["zoom_to"]))


## An act's boss on the road, and the Warden going to meet it.
func _stage_boss() -> void:
	if run.boss_director == null or not run.boss_director.summon(RunState.act):
		await _stage_warden()
		return
	Engine.time_scale = setup_time_scale
	await _wait(0.5)
	GameSpeed.restore()
	if _gone():
		return
	var boss: Node2D = run.boss_director.get("_active") as Node2D
	if boss == null or not is_instance_valid(boss):
		await _stage_warden()
		return
	_stand(boss.global_position + _from_side(_dice.randf_range(300.0, 380.0)))
	_mode = &"fight"
	_casting = true
	_director.foe = boss
	_keep_foe = true
	_follow_with(boss, Vector2(0.0, -120.0))


## The last acts at their height: every road lined, the whole Arsenal turning,
## every spell thrown.
func _stage_peak() -> void:
	# The road's own draft is already the hand an act this late deals; a
	# second one put twice a real hand on the Warden and halved the frame rate.
	if light:
		await _stage_warden()
		return
	await _stage_spells()


# --- Directing ----------------------------------------------------------------

var _mode: StringName = &""
var _strolls: Array[Vector2] = []
var _pause_left: float = 0.0
var _swing_left: float = 0.0
var _swings: int = 0
var _step_out_left: float = 0.0
var _stepped_from: Node2D = null
var _casting: bool = false
var _keep_foe: bool = false
var _watch_point: Vector2 = Vector2.ZERO
var _watched: Node2D = null
var _ride_target: Vector2 = Vector2.ZERO
var _rammed: bool = false
var _glance_left: float = 0.0
var _cast_in: float = 0.0
var _cast_hold: float = 0.0


func _direct(delta: float) -> void:
	if _director == null or field == null or field.hero == null:
		return
	_director.press = 0
	_director.hold = 0
	field.hero.mana = field.hero.mana_max()
	match _mode:
		&"fight":
			_direct_fight(delta)
		&"stroll":
			_direct_stroll(delta)
		&"watch":
			_direct_watch(delta)
		&"ride":
			_direct_ride(delta)
		&"pond":
			_direct_pond(delta)


## **A fight with a rhythm.** In, a few swings with a breath between them, now
## and then a step out to one side and a dash back, a spell when one is ready -
## how often each is set by the moment's own temper, so no two fights move alike.
func _direct_fight(delta: float) -> void:
	var hero: Hero = field.hero
	var bold: float = float(moment.get("bold", 0.5))
	if not _keep_foe or _director.foe == null or not is_instance_valid(_director.foe):
		_director.foe = _nearest_body(hero.global_position, 900.0)
	if _director.foe == null:
		_director.goal = _busy_point()
		return
	if _step_out_left > 0.0:
		# A step out to one side, still looking at what it stepped away from.
		_step_out_left -= delta
		if _stepped_from != null and is_instance_valid(_stepped_from):
			var away: Vector2 = (hero.global_position - _stepped_from.global_position).normalized()
			_director.goal = hero.global_position + away.rotated(0.9 if _swings % 2 == 0 else -0.9) * 140.0
			_director.look_at = _stepped_from.global_position
		_director.foe = null
		if _step_out_left <= 0.0:
			_director.foe = _stepped_from if _stepped_from != null and is_instance_valid(_stepped_from) else null
			_director.goal = Vector2.INF
		return
	var gap: float = hero.global_position.distance_to(_director.foe.global_position)
	if gap > 300.0 and bold > 0.45:
		_director.hold |= HeroInput.HOLD_SPRINT
	_swing_left -= delta
	if gap <= _director.reach + 30.0 and _swing_left <= 0.0:
		_director.press |= HeroInput.BUTTON_ATTACK
		_swings += 1
		_swing_left = _dice.randf_range(0.16, 0.34)
		if _swings % _dice.randi_range(3, 5) == 0:
			_swing_left += _dice.randf_range(0.25, 0.55)
			if _dice.randf() < 0.45 + float(moment.get("restless", 0.5)) * 0.3:
				_step_out_left = _dice.randf_range(0.28, 0.42)
				_stepped_from = _director.foe
				_director.press |= HeroInput.BUTTON_DASH
	if _casting or bold > 0.6:
		for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
			if hero.spells != null and hero.spells.is_ready(slot) and gap < 560.0 \
					and _dice.randf() < 0.05 + bold * 0.08:
				_director.press |= HeroInput.spell_button(slot)
				break


## **A walk with somewhere to be.** To a point, a pause there looking at what
## matters - the wave, the town, a tower - and on to the next.
func _direct_stroll(delta: float) -> void:
	var hero: Hero = field.hero
	if _pause_left > 0.0:
		_pause_left -= delta
		_glance_left -= delta
		if _glance_left <= 0.0:
			_glance_left = _dice.randf_range(0.5, 1.1)
			_director.look_at = _something_to_look_at()
		_director.goal = Vector2.INF
		return
	if _strolls.is_empty():
		_strolls.append(hero.global_position + Vector2(_dice.randf_range(-200.0, 200.0), _dice.randf_range(-120.0, 120.0)))
	_director.goal = _strolls[0]
	_director.look_at = Vector2.INF
	if hero.global_position.distance_to(_strolls[0]) <= _director.arrive + 4.0:
		_strolls.pop_front()
		_pause_left = _dice.randf_range(0.5, 1.3)
		_glance_left = 0.0


## **Watching something come.** Standing, looking at it, a step or two back when
## it gets close, and a sprint away when it is right there.
func _direct_watch(delta: float) -> void:
	var hero: Hero = field.hero
	var at: Vector2 = _watch_point
	if _watched != null and is_instance_valid(_watched):
		at = _watched.global_position
	_director.look_at = at
	var gap: float = hero.global_position.distance_to(at)
	_pause_left -= delta
	if gap < 240.0:
		_director.goal = hero.global_position + (hero.global_position - at).normalized() * 200.0
		_director.hold |= HeroInput.HOLD_SPRINT
	elif _pause_left <= 0.0:
		# A shuffle: a step or two, the weight shifting, and still again.
		_pause_left = _dice.randf_range(0.9, 1.8)
		_director.goal = hero.global_position + Vector2(_dice.randf_range(-50.0, 50.0), _dice.randf_range(-30.0, 30.0))


## **At the water.** Still, looking out over it, and after a breath the cast:
## the interact held and let go, as a player casts.
func _direct_pond(delta: float) -> void:
	_director.goal = Vector2.INF
	_director.look_at = _watch_point
	if _cast_in > 0.0:
		_cast_in -= delta
		return
	if _cast_hold < 0.75:
		_cast_hold += delta
		_director.hold |= HeroInput.HOLD_INTERACT
		if _cast_hold <= delta:
			_director.press |= HeroInput.BUTTON_INTERACT


## **The charge.** At a gallop down the road at the wave, and the ram the moment
## the front of it is in reach; then on foot and fighting where it landed.
func _direct_ride(delta: float) -> void:
	var hero: Hero = field.hero
	if _rammed or not hero.is_mounted():
		_mode = &"fight"
		_direct_fight(delta)
		return
	var front: Enemy = _nearest_body(hero.global_position, 2000.0)
	var target: Vector2 = front.global_position if front != null else _ride_target
	_director.goal = target
	_director.look_at = target
	_director.hold |= HeroInput.HOLD_SPRINT
	if hero.global_position.distance_to(target) < 360.0:
		_director.press |= HeroInput.BUTTON_DASH
		_rammed = true


func _something_to_look_at() -> Vector2:
	var hero: Hero = field.hero
	var roll: float = _dice.randf()
	if roll < 0.5:
		var body: Enemy = _nearest_body(hero.global_position, 1400.0)
		if body != null:
			return body.global_position
	if roll < 0.75:
		return Vector2.ZERO
	return hero.global_position + Vector2.from_angle(_dice.randf_range(0.0, TAU)) * 300.0


# --- The camera ---------------------------------------------------------------

func _camera(look_from: Vector2, look_to: Vector2, zoom_from: float, zoom_to: float) -> void:
	_look_from = look_from
	_look_to = look_to
	_zoom_from = zoom_from
	_zoom_to = zoom_to
	_follow = null
	_place_camera(0.0, true)


## The camera on something that moves, leaning `lead` ahead of it, pushing in
## or pulling out between the moment's two zooms.
func _follow_with(node: Node2D, lead: Vector2) -> void:
	_look_from = lead
	_look_to = lead * 1.3
	_zoom_from = float(moment.get("zoom_from", 1.0))
	_zoom_to = float(moment.get("zoom_to", 1.0))
	_follow = node
	if node != null:
		_followed = node.global_position
	_place_camera(0.0, true)


func _place_camera(share: float, snap: bool) -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	var eased: float = smoothstep(0.0, 1.0, share)
	var at: Vector2 = _look_from.lerp(_look_to, eased)
	if _follow != null and is_instance_valid(_follow):
		var t: float = 1.0 if snap else 1.0 - exp(-3.5 * get_process_delta_time())
		_followed = _followed.lerp(_follow.global_position, t)
		at += _followed
	_cam.global_position = at
	var zoom: float = lerpf(_zoom_from, _zoom_to, eased)
	_cam.zoom = Vector2.ONE * zoom
	_cam.set("_wanted_zoom", zoom)


# --- Beats --------------------------------------------------------------------

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
				var kind: TowerData = kinds[_dice.randi_range(0, kinds.size() - 1)]
				if not kind.is_well() and field.try_build(anchor, kind).is_empty():
					built.append(anchor)
					# The Warden walks over to look at what just rose.
					_strolls.append(BattleGrid.tile_to_world(anchor) + Vector2(_dice.randf_range(-60.0, 60.0), 120.0))
			elif int(beat["upgrades"]) < built.size() * 3 and not built.is_empty():
				field.try_upgrade(built[int(beat["upgrades"]) % built.size()])
				beat["upgrades"] = int(beat["upgrades"]) + 1
				beat["left"] = float(beat["every"]) * 0.45
		"storm":
			var sky: WeatherSky = field.sky()
			if sky == null:
				return
			beat["left"] = float(beat["left"]) - delta
			var centre: Vector2 = beat["centre"]
			if float(beat["left"]) <= 0.0:
				beat["left"] = _dice.randf_range(0.4, 0.85)
				sky.strike_at(centre + Vector2(_dice.randf_range(-520.0, 520.0), _dice.randf_range(-300.0, 300.0)))
			if not bool(beat["quaked"]) and _total - _left >= float(beat["quake_at"]):
				beat["quaked"] = true
				sky.quake(1.0, ["quake"], centre + Vector2(_dice.randf_range(-120.0, 120.0), -40.0))


# --- The wave ---------------------------------------------------------------

## **A pack on the road ahead of the Warden**: the region's own breeds (and now
## and then a veteran of another road), at the road's own strength for its act,
## stood up on one road and placed along it - spread from a little before
## `toward` to a little past it - so the fight a moment films is there when the
## cut lands rather than somewhere up the road. Later acts send more, and now
## and then a champion or an elite among them. Returns where the pack stands.
func _send_a_pack(count: int, toward: Vector2 = Vector2.INF) -> Vector2:
	if field == null:
		return Vector2.ZERO
	var terrain: TerrainData = ContentDB.terrain_for_act(RunState.act)
	var roster: Array[EnemyData] = []
	if terrain != null:
		for id: String in terrain.enemy_ids + terrain.veteran_ids:
			var breed: EnemyData = ContentDB.enemy(id)
			if breed != null and breed.category == EnemyData.Category.BREED:
				roster.append(breed)
	if roster.is_empty():
		return _busy_point()
	var lane: int = _dice.randi_range(0, Balance.LANE_COUNT - 1)
	if toward.is_finite() and toward.length() > 1.0:
		var best: float = -INF
		for each: int in Balance.LANE_COUNT:
			var along: float = Battlefield.lane_vector(each).dot(toward.normalized())
			if along > best:
				best = along
				lane = each
	var hp: float = WaveDirector.road_hp_scale()
	var harm: float = WaveDirector.road_damage_scale()
	var sum := Vector2.ZERO
	var placed: int = 0
	for index: int in count:
		var breed: EnemyData = roster[_dice.randi_range(0, roster.size() - 1)]
		var rank: Enemy.Rank = Enemy.Rank.COMMON
		var roll: float = _dice.randf()
		if RunState.act >= 3 and roll < 0.04 + float(RunState.act) * 0.006:
			rank = Enemy.Rank.ELITE if roll < 0.02 else Enemy.Rank.CHAMPION
		var body: Enemy = field.spawn_enemy(breed, lane, hp, harm, 1.0, false, rank)
		if body == null:
			continue
		var road: PackedVector2Array = body.get("_route") as PackedVector2Array
		if road.size() < 2:
			continue
		var at: int = _route_index_near(road, toward if toward.is_finite() else road[road.size() / 2])
		var spread: int = clampi(at + int(round(_dice.randf_range(-3.0, 3.0) - float(index % 3))), 1, road.size() - 2)
		var spot: Vector2 = road[spread] + Vector2(_dice.randf_range(-46.0, 46.0), _dice.randf_range(-46.0, 46.0))
		body.take_up_road(road, spread, _dice.randf_range(-30.0, 30.0), spot)
		sum += spot
		placed += 1
	return sum / float(placed) if placed > 0 else _busy_point()


func _route_index_near(road: PackedVector2Array, near: Vector2) -> int:
	var best: int = road.size() / 2
	var gap: float = INF
	for index: int in road.size():
		var d: float = road[index].distance_squared_to(near)
		if d < gap:
			gap = d
			best = index
	return best


## How many bodies a fight moment sends: a handful in Act I, a crowd near the
## summit - more of them is most of what makes the late road look late.
func _pack_size() -> int:
	var size: int = clampi(6 + RunState.act * 2 + _dice.randi_range(-2, 3), 6, 24)
	return maxi(size / 2, 5) if light else size


# --- Helpers ------------------------------------------------------------------

func _wait(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0 and not cancelled:
		await get_tree().process_frame
		left -= get_process_delta_time() / maxf(Engine.time_scale, 0.01)


func _stand(at: Vector2) -> void:
	if field != null and field.hero != null:
		field.hero.global_position = at
		field.hero.velocity = Vector2.ZERO
	_keep_foe = false
	_watched = null
	_strolls.clear()
	_pause_left = 0.0
	_step_out_left = 0.0
	_stepped_from = null
	_swings = 0
	if _director != null:
		_director.goal = Vector2.INF
		_director.foe = null
		_director.look_at = Vector2.INF


## Somewhere out along one of the roads, past the first towers, where a fight
## has room to be filmed.
func _a_stretch_of_road() -> Vector2:
	return Battlefield.lane_vector(_dice.randi_range(0, Balance.LANE_COUNT - 1)) * _dice.randf_range(640.0, 900.0)


## A point off the road's line to one side, so the Warden comes at the wave from
## its flank rather than from its middle.
func _from_side(distance: float) -> Vector2:
	var angle: float = _dice.randf_range(0.6, 2.5) * (1.0 if _dice.randf() < 0.5 else -1.0)
	return Vector2.DOWN.rotated(angle) * distance


func _bodies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	if field == null:
		return out
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body != null and is_instance_valid(body) and not body.is_dying() and field.is_ancestor_of(body):
			out.append(body)
	return out


func _nearest_body(from: Vector2, within: float) -> Enemy:
	var best: Enemy = null
	var gap: float = within * within
	for body: Enemy in _bodies():
		var d: float = from.distance_squared_to(body.global_position)
		if d < gap:
			gap = d
			best = body
	return best


## The middle of the bodies nearest the town, or a point out along a road.
func _busy_point() -> Vector2:
	var bodies: Array[Vector2] = []
	for body: Enemy in _bodies():
		bodies.append(body.global_position)
	if bodies.is_empty():
		return Battlefield.lane_vector(_dice.randi_range(0, Balance.LANE_COUNT - 1)) * 700.0
	bodies.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.length() < b.length())
	var sum: Vector2 = Vector2.ZERO
	var take: int = mini(bodies.size(), 8)
	for index: int in take:
		sum += bodies[index]
	return sum / float(take)


func _storm_weather() -> String:
	for value: Variant in ContentDB.weathers.values():
		var weather := value as WeatherData
		if weather != null and weather.id == "downpour":
			return weather.id
	for value: Variant in ContentDB.weathers.values():
		var weather := value as WeatherData
		if weather != null and weather.precipitation == WeatherData.Precipitation.RAIN:
			return weather.id
	return RunState.weather_id
