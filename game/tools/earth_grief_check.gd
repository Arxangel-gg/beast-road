extends Node

## **The earth minds every death, in the area, and keeps karma** (owner,
## 2026-10-01: *"Death of any wildlife from any means besides from other
## wildlife naturally should affect the earth's wrath in the area. Earth's
## wrath needs to be elevated ... procedural with randomness as well as natural
## wisdom and luck and karma factors"*):
##
##   godot --headless --path game res://tools/earth_grief_check.tscn
##
## - **By cause**: an animal the earth, a fire or a flood killed is heat at its
##   share of a kill and never the floor; one a dragon killed is a kill and
##   more, floor and all; one another animal killed is nothing; one a strike
##   killed no longer pays the player.
## - **In the area**: grief lies where the death was, not across the field, and
##   fades on its half-life.
## - **Natural wisdom**: the earth's blows lean into grieved ground - and with
##   nothing grieved, they land exactly where they always did, on the same dice.
## - **The ground presses**: a Warden standing in grief feels more hazard.
## - **Karma**: a harmless kill costs, a mercy gives, it drifts home, and the
##   road says so as it crosses a sign.
## - **Luck**: a kind party gets near misses and a cruel one is sought out by a
##   telegraphed blow, never by lightning.
## - **Temper**: great events are rare, rarer for the kind; a great quake is
##   answered by an aftershock.

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run = null
var _field: Battlefield = null
var _sky: WeatherSky = null
var _said: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20261013)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_sky = _field.sky()
	_check(_sky != null and _sky.grief != null, "the field stands no sky that grieves")
	if _sky != null and _sky.grief != null:
		_sky.events_enabled = false
		EventBus.sky_warned.connect(func(_line: String, title: String) -> void: _said.append(title))
		_test_by_cause()
		await _test_a_strike_pays_nobody()
		_test_in_the_area()
		_test_natural_wisdom()
		_test_the_ground_presses()
		_test_karma()
		_test_luck_and_the_cruel()
		_test_temper()
		_test_a_guest_breathes_the_same_ash()
	_check(_finished == 9, "%d of 9 tests reached their end" % _finished)
	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.run_active = false
	_run.queue_free()
	MetaState.resume_saves()
	if _failures == 0:
		print("[earth-grief] PASS - %d checks: every death counted by its cause, grief in the area, blows that lean into it, ground that presses, karma that moves and is said, luck and the cruel sought out, and a rare great temper" % _checks)
	else:
		push_error("[earth-grief] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _calm() -> void:
	_sky.set("_wrath_floor", 0.0)
	_sky.set("_wrath_heat", 0.0)
	_sky.grief.clear()
	RunState.karma = 0.0


func _heat() -> float:
	return float(_sky.get("_wrath_heat"))


func _floor() -> float:
	return float(_sky.get("_wrath_floor"))


func _test_by_cause() -> void:
	_calm()
	var at: Vector2 = Vector2(1800.0, 900.0)
	EventBus.wildlife_fell.emit("stag", at, 0, false, "earth")
	var earth: float = _heat()
	_check(is_equal_approx(earth, Balance.WRATH_HEAT_PER_KILL * float(Balance.WRATH_FALL_SCALE["earth"])),
		"an animal the earth killed was %.4f heat, not its share of a kill" % earth)
	_check(is_zero_approx(_floor()), "an animal the earth killed raised the floor")
	_calm()
	EventBus.wildlife_fell.emit("stag", at, 0, false, "fire")
	_check(_heat() > earth, "an animal a fire killed was minded no more than one a quake did")
	_calm()
	EventBus.wildlife_fell.emit("stag", at, 0, false, "dragon")
	_check(_floor() > 0.0, "a dragon's kill did not reach the floor")
	_check(_heat() >= Balance.WRATH_HEAT_PER_KILL * Balance.WRATH_DRAGON_KILL_SCALE - 0.0001,
		"a dragon's kill was not counted as a kill and more")
	# The cycle: an animal another animal killed announces nothing.
	_calm()
	var fell: Array[String] = []
	var listen: Callable = func(_k: String, _a: Vector2, _r: int, _s: bool, cause: String) -> void:
		fell.append(cause)
	EventBus.wildlife_fell.connect(listen)
	var wild: Wildlife = _field.wildlife()
	var prey: Dictionary = _place(_grazer(), Vector2(1500.0, 1500.0))
	wild.call("_wound", wild.living().find(prey), prey, 99999.0, false, "cycle")
	_check(fell.is_empty(), "an animal another animal killed was announced as %s" % str(fell))
	var victim: Dictionary = _place(_grazer(), Vector2(1600.0, 1500.0))
	wild.call("_wound", wild.living().find(victim), victim, 99999.0, false, "earth")
	_check(fell == ["earth"], "an animal the earth killed was not announced as the earth's (%s)" % str(fell))
	EventBus.wildlife_fell.disconnect(listen)
	_check(is_zero_approx(_floor()), "the cycle or the earth reached the floor")
	_finished += 1


func _test_a_strike_pays_nobody() -> void:
	_calm()
	var wild: Wildlife = _field.wildlife()
	wild.clear()
	var at: Vector2 = Vector2(1700.0, 1700.0)
	_place(_grazer(), at)
	var food_before: int = RunState.currency(RunState.FOOD)
	var drops_before: int = get_tree().get_nodes_in_group(LootDrop.GROUP).size()
	_check(wild.wound_near(at, 200.0, 99999.0), "a strike found no animal to strike")
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(LootDrop.GROUP).size() == drops_before
		and RunState.currency(RunState.FOOD) == food_before,
		"an animal a strike killed paid the player as if they had hunted it")
	_check(_heat() > 0.0 and is_zero_approx(_floor()), "a strike's kill was not the earth's grief")
	_finished += 1


func _grazer() -> WildlifeData:
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.is_hostile() and not kind.mythic and not kind.flies and not kind.amphibious \
				and not kind.steals and not kind.hoards:
			return kind
	return null


func _place(kind: WildlifeData, at: Vector2) -> Dictionary:
	var wild: Wildlife = _field.wildlife()
	wild.call("_spawn", kind, at)
	var living: Array[Dictionary] = wild.living()
	var animal: Dictionary = living[living.size() - 1]
	(animal["sprite"] as Sprite2D).global_position = at
	animal["state"] = Wildlife.State.SETTLED
	return animal


## **A guest breathes the same ash** (2026-10-01). The host tells each patch of
## grief it lays (`coop_grief_laid`) only in company, and a guest's sheet lays
## what it is told and nothing of its own - a kill a guest's copy hears lays
## nothing, because why an animal died is the host's to know.
func _test_a_guest_breathes_the_same_ash() -> void:
	_calm()
	var told: Array[Vector2] = []
	var listen := func(at: Vector2, _amount: float) -> void: told.append(at)
	EventBus.coop_grief_laid.connect(listen)
	var here: Vector2 = Vector2(-1500.0, 1400.0)
	EventBus.wildlife_killed.emit("stag", 3, here, 2, false, false)
	_check(told.is_empty(), "grief was told to a guest on a solo road")
	_calm()
	Coop.set("_state", Coop.State.HOSTING)
	EventBus.wildlife_killed.emit("stag", 3, here, 2, false, false)
	Coop.set("_state", Coop.State.OFFLINE)
	_check(told.size() == 1 and told[0].is_equal_approx(here),
		"the host did not tell its grief to a guest (%d told)" % told.size())
	var host_has: float = _sky.grief.at(here)
	# The same sky as a guest's: told grief lands, its own kills lay none.
	_calm()
	_sky.set("_mirror", true)
	EventBus.wildlife_killed.emit("stag", 3, here, 2, false, false)
	_check(_sky.grief.total() <= 0.0, "a guest laid grief of its own from a kill it heard")
	EventBus.coop_grief_laid.emit(here, float(Balance.WRATH_RARITY_SCALE[2]))
	_check(absf(_sky.grief.at(here) - host_has) < host_has * 0.02 + 0.001,
		"a guest's told grief is %.3f where the host's is %.3f" % [_sky.grief.at(here), host_has])
	_sky.set("_mirror", false)
	EventBus.coop_grief_laid.disconnect(listen)
	_calm()
	_finished += 1


func _test_in_the_area() -> void:
	_calm()
	var here: Vector2 = Vector2(-1600.0, -1400.0)
	var there: Vector2 = Vector2(1700.0, 1500.0)
	EventBus.wildlife_killed.emit("stag", 3, here, 2, false, false)
	var near: float = _sky.grief.at(here)
	_check(near > 0.0, "a kill laid no grief where it happened")
	_check(_sky.grief.at(there) < near * 0.05, "grief spread across the field, not the area")
	var whole: float = _sky.grief.total()
	_sky.grief.tick(Balance.WRATH_GRIEF_HALF_LIFE)
	_check(absf(_sky.grief.total() - whole * 0.5) < whole * 0.02,
		"grief did not fade by half over its half-life (%.3f of %.3f)" % [_sky.grief.total(), whole])
	_finished += 1


func _test_natural_wisdom() -> void:
	_calm()
	# Nothing grieved: the very points the uniform roll gives, and the stream
	# handed in moves exactly as before.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 777
	b.seed = 777
	var same: bool = true
	for _i: int in 60:
		if _sky.call("_pick_strike_point", a) != _sky.call("_uniform_point", b):
			same = false
	_check(same, "with nothing grieved, the earth's blows landed somewhere else than they always did")
	# Grieved at one place: the blows lean into it, and still never move the
	# caller's own stream.
	var wronged: Vector2 = Vector2(-1500.0, 1300.0)
	for _kill: int in 12:
		EventBus.wildlife_killed.emit("stag", 3, wronged, 3, false, false)
	a.seed = 4242
	b.seed = 4242
	var into: int = 0
	var draws: int = 400
	for _i: int in draws:
		var spot: Vector2 = _sky.call("_pick_strike_point", a)
		_sky.call("_uniform_point", b)
		if spot.distance_to(wronged) <= Balance.WRATH_GRIEF_RADIUS:
			into += 1
	_check(float(into) / float(draws) >= Balance.WRATH_GRIEF_PULL_MAX * 0.6,
		"only %d of %d blows fell in grieved ground" % [into, draws])
	_check(into < draws, "every blow fell in grief - wisdom is a lean, not a leash")
	_check(a.randi() == b.randi(), "grief moved the stream the caller handed in")
	_check(_sky.grief_placed > 0, "the gate counted no blow the earth placed in grief")
	_finished += 1


func _test_the_ground_presses() -> void:
	_calm()
	var hero: Hero = _field.hero
	hero.global_position = Vector2(1400.0, -1400.0)
	var clean: float = _sky.hazard_boost()
	for _kill: int in 6:
		EventBus.wildlife_killed.emit("stag", 3, hero.global_position, 2, false, false)
	var grieved: float = _sky.hazard_boost()
	_check(grieved > clean * 1.2, "a Warden standing in grief felt no more of the earth (%.2f against %.2f)" % [grieved, clean])
	_check(grieved <= clean * (1.0 + Balance.WRATH_GRIEF_HAZARD) + 0.0001, "grief pressed past its bound")
	hero.global_position = Vector2(-1400.0, 1400.0)
	_check(is_equal_approx(_sky.hazard_boost(), clean), "grief elsewhere pressed on a Warden standing clear of it")
	_finished += 1


func _test_karma() -> void:
	_calm()
	var wild: Wildlife = _field.wildlife()
	wild.clear()
	var deer: Dictionary = _place(_grazer(), Vector2(1200.0, 1200.0))
	var weight: float = float(Balance.WRATH_RARITY_SCALE[clampi(WildlifeFamilies.rarity_of(deer), 0,
		Balance.WRATH_RARITY_SCALE.size() - 1)])
	wild.call("_wound", wild.living().find(deer), deer, 99999.0, true)
	_check(is_equal_approx(RunState.karma, -Balance.KARMA_HARMLESS_KILL * weight),
		"a harmless animal killed cost %.3f karma, not its rarity's %.3f" % [RunState.karma,
			-Balance.KARMA_HARMLESS_KILL * weight])
	RunState.karma = 0.0
	var sick: Dictionary = _place(_grazer(), Vector2(1300.0, 1200.0))
	sick["blight"] = WildlifeFamilies.Blight.FRENZIED
	wild.call("_wound", wild.living().find(sick), sick, 99999.0, true)
	_check(is_equal_approx(RunState.karma, Balance.KARMA_MERCY), "a blighted animal put out of its misery gave no karma")
	RunState.karma = 0.8
	_sky.call("_tick_karma", 10.0)
	_check(RunState.karma < 0.8 and RunState.karma > 0.0, "karma did not drift toward nothing")
	_said.clear()
	_sky.set("_karma_told", 0)
	RunState.karma = Balance.KARMA_SIGN_FROM + 0.05
	_sky.call("_tick_karma", 0.01)
	_check(_said.has("THE ROAD REMEMBERS KINDNESS"), "kindness crossed its sign and the road said nothing")
	RunState.karma = -Balance.KARMA_SIGN_FROM - 0.05
	_sky.call("_tick_karma", 0.01)
	_check(_said.has("THE EARTH KNOWS YOU"), "cruelty crossed its sign and the road said nothing")
	_said.clear()
	_sky.call("_tick_karma", 0.01)
	_check(_said.is_empty(), "the road said its sign twice")
	_finished += 1


func _test_luck_and_the_cruel() -> void:
	_calm()
	var hero: Hero = _field.hero
	hero.global_position = Vector2(1200.0, 1300.0)
	var near_at: Vector2 = hero.global_position + Vector2(60.0, 0.0)
	RunState.karma = 1.0
	var misses: int = _sky.near_misses
	var moved: int = 0
	for _i: int in 400:
		var landed: Vector2 = _sky.call("_fated", near_at, false)
		if landed.distance_to(hero.global_position) >= Balance.WRATH_LUCK_NUDGE - 1.0:
			moved += 1
	var share: float = float(moved) / 400.0
	var expect: float = minf(Balance.WRATH_LUCK_BASE + Balance.WRATH_LUCK_KARMA, Balance.WRATH_LUCK_MAX)
	_check(absf(share - expect) < 0.08, "a kind party's near misses were %.2f, not about %.2f" % [share, expect])
	_check(_sky.near_misses - misses == moved, "the near misses counted were not the ones moved")
	RunState.karma = -1.0
	moved = 0
	for _i: int in 400:
		var landed: Vector2 = _sky.call("_fated", near_at, false)
		if landed.distance_to(hero.global_position) >= Balance.WRATH_LUCK_NUDGE - 1.0:
			moved += 1
	_check(moved == 0, "a cruel party still had %d near misses" % moved)
	# The cruel are sought out by a telegraphed blow, never by lightning.
	var off_at: Vector2 = hero.global_position + Vector2(Balance.WRATH_LUCK_REACH * 2.0, 0.0)
	var found: int = 0
	var bolts_found: int = 0
	for _i: int in 400:
		if (_sky.call("_fated", off_at, true) as Vector2).distance_to(hero.global_position) < 1.0:
			found += 1
		if (_sky.call("_fated", off_at, false) as Vector2).distance_to(hero.global_position) < 1.0:
			bolts_found += 1
	_check(absf(float(found) / 400.0 - Balance.WRATH_KARMA_SEEK) < 0.08,
		"a cruel party was sought %d times in 400, not about %.0f" % [found, Balance.WRATH_KARMA_SEEK * 400.0])
	_check(bolts_found == 0, "lightning, which gives no warning, sought out the cruel")
	RunState.karma = 1.0
	found = 0
	for _i: int in 400:
		if (_sky.call("_fated", off_at, true) as Vector2).distance_to(hero.global_position) < 1.0:
			found += 1
	_check(found == 0, "a kind party was sought out by the earth")
	RunState.karma = 0.0
	_finished += 1


func _test_temper() -> void:
	_calm()
	var great: int = 0
	var rolls: int = 3000
	_said.clear()
	for _i: int in rolls:
		if _sky.call("_great"):
			great += 1
	var share: float = float(great) / float(rolls)
	_check(absf(share - Balance.WRATH_GREAT_CHANCE) < 0.015,
		"great events came %.3f of the time, not about %.3f" % [share, Balance.WRATH_GREAT_CHANCE])
	_check(_said.has("THE EARTH ROARS"), "a great event was not said")
	RunState.karma = -1.0
	great = 0
	for _i: int in rolls:
		if _sky.call("_great"):
			great += 1
	var cruel_share: float = float(great) / float(rolls)
	_check(cruel_share > share + 0.02, "a cruel party's earth was in no greater temper (%.3f)" % cruel_share)
	_check(cruel_share <= Balance.WRATH_GREAT_MAX + 0.015, "a cruel party's earth raged past its bound")
	RunState.karma = 0.0
	# A great quake is answered by an aftershock, warned in its turn.
	_sky.set("_quake_warning_left", 0.0)
	_sky.set("_quake_left", 0.0)
	_sky.set("_aftershock_magnitude", 0.4)
	_sky.set("_aftershock_left", 0.2)
	_sky.call("_tick_wrath", 0.3)
	_check(float(_sky.get("_quake_warning_left")) > 0.0, "the aftershock owed never shook")
	_sky.set("_quake_warning_left", 0.0)
	_sky.set("_quake_pending", -1.0)
	_finished += 1


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[earth-grief] " + why)
