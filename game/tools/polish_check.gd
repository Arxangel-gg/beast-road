extends Node

## The polish taken from Core Keeper (2026-09-23), held to what each one promises.
##
##   godot --headless --path game res://tools/polish_check.tscn
##
## Three things, each a presentation that must change nothing but presentation:
##
##   * **The music settles when the road is safe.** Preparation on a live road
##     filters and trims the music bus; a wave opens it again. Neither the
##     player's music slider nor the post-boss hush may move, and outside the
##     battlefield it never settles - a raid is not a safe place.
##   * **Flowers glow at night.** A share of the flower patches carries a halo
##     that is dark by day and lit by night, never more than the cap.
##   * **You look like what you wear.** A set worn in full puts its colour on a
##     cloak left as painted, never over a dye the player chose - and every place
##     this machine draws or sends its own Warden uses the worn look, so a
##     partner, the Hold's seats and the lobby all see the same one.

const SEED: int = 20260923

var _failures: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	await _check_the_music()
	await _check_the_glow()
	_check_the_set_colours()
	for problem: String in _failures:
		push_error("[polish] " + problem)
	print("[polish] %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	GameDirector.run_active = false
	AudioBuses.set_calm(0.0)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 12:
		await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


func _check_the_music() -> void:
	var slider: float = float(MetaState.settings.get("music_volume", 0.8))
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	RunState.set_phase(RunState.Phase.PREPARATION)
	_check(MusicPlayer.should_be_calm(), "Preparation on the battlefield should settle the music")
	await _wait_for(func() -> bool: return AudioBuses.calm_share() >= 1.0, 8.0)
	_check(AudioBuses.calm_share() >= 1.0,
		"the music never settled in Preparation (%.2f)" % AudioBuses.calm_share())
	var bus: int = AudioServer.get_bus_index(AudioBuses.MUSIC)
	var filter: AudioEffectLowPassFilter = null
	for index: int in AudioServer.get_bus_effect_count(bus):
		var effect: AudioEffect = AudioServer.get_bus_effect(bus, index)
		if effect is AudioEffectLowPassFilter:
			filter = effect as AudioEffectLowPassFilter
			_check(AudioServer.is_bus_effect_enabled(bus, index), "the calm filter is on the bus but off")
	_check(filter != null, "the music bus carries no calm filter")
	if filter != null:
		_check(absf(filter.cutoff_hz - Balance.MUSIC_CALM_CUTOFF_HZ) < 1.0,
			"settled, the filter sits at %.0f Hz rather than %.0f" % [filter.cutoff_hz,
				Balance.MUSIC_CALM_CUTOFF_HZ])
	_check(is_equal_approx(float(MetaState.settings.get("music_volume", 0.8)), slider),
		"settling the music moved the player's slider")
	_check(is_equal_approx(AudioBuses.hush_share(), 1.0), "settling the music touched the hush")

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	await _wait_for(func() -> bool: return AudioBuses.calm_share() <= 0.001, 8.0)
	_check(AudioBuses.calm_share() <= 0.001, "a wave never opened the music back up (calm %.2f, phase %d, calm wanted %s)"
		% [AudioBuses.calm_share(), RunState.phase, MusicPlayer.should_be_calm()])
	if filter != null:
		for index: int in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, index) == filter:
				_check(not AudioServer.is_bus_effect_enabled(bus, index),
					"the filter is still on with the music fully open")

	RunState.set_phase(RunState.Phase.PREPARATION)
	GameDirector.current_scope = GameDirector.Scope.RAID
	_check(not MusicPlayer.should_be_calm(), "a raid must never count as a safe place")
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	GameDirector.run_active = false
	_check(not MusicPlayer.should_be_calm(), "with no road under way the music must not settle")
	AudioBuses.set_calm(0.0)


func _check_the_glow() -> void:
	_check(Foliage.glows("res://art/foliage/plant_jungle_flower.png"), "a flower should be able to glow")
	_check(Foliage.glows("res://art/foliage/prop_mushrooms.png"), "mushrooms should be able to glow")
	_check(not Foliage.glows("res://art/foliage/plant_jungle_fern.png"), "a fern must not glow")
	_check(not Foliage.glows("res://art/foliage/prop_rock.png"), "a rock must not glow")
	var flower: Texture2D = load("res://art/foliage/plant_jungle_flower.png") as Texture2D
	if flower != null:
		var colour: Color = Foliage.glow_colour(flower)
		_check(colour.s > 0.15, "a flower's glow came out grey (%s) - it should be its petals' colour" % colour)

	RunState.reset(false, SEED)
	GameDirector.run_active = true
	var run := (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 24:
		await get_tree().process_frame
	var foliage: Foliage = _find_foliage(run)
	_check(foliage != null, "no foliage on the field")
	if foliage != null:
		var count: int = foliage.glow_count()
		_check(count > 0, "not one flower on the field carries a glow")
		_check(count <= Balance.FOLIAGE_GLOW_MAX, "%d halos against a cap of %d" % [count,
			Balance.FOLIAGE_GLOW_MAX])
		var held: float = DayNight.darkness
		DayNight.darkness = 0.0
		await _seconds(0.6)
		_check(foliage.glow_brightness() <= 0.001,
			"flowers glow at midday (%.2f)" % foliage.glow_brightness())
		DayNight.darkness = 1.0
		await _seconds(0.6)
		_check(foliage.glow_brightness() >= Balance.FOLIAGE_GLOW_STRENGTH * 0.6,
			"flowers stay dark at deep night (%.2f)" % foliage.glow_brightness())
		DayNight.darkness = held
		print("[polish] %d flowers glow on this field" % count)
	run.queue_free()
	GameDirector.run_active = false
	for _frame: int in 8:
		await get_tree().process_frame


func _check_the_set_colours() -> void:
	var red := Color.from_hsv(0.0, 0.8, 0.9)
	var plain: Dictionary = WardenLook.plain()
	var worn: Dictionary = WardenLook.with_set_colour(plain, red)
	_check(absf(float(worn[WardenLook.KEY_CLOAK]) - wrapf(0.0 - WardenLook.CLOAK_HUE, -0.5, 0.5)) < 0.001,
		"a red set should turn the painted cloak red, got %s" % worn)
	_check(is_equal_approx(float(worn[WardenLook.KEY_SASH]), 0.0), "a set colour touched the sash")
	var chosen: Dictionary = WardenLook.clean({WardenLook.KEY_CLOAK: 0.2, WardenLook.KEY_SASH: 0.0})
	_check(WardenLook.same(WardenLook.with_set_colour(chosen, red), chosen),
		"a set colour overrode a cloak the player dyed")
	_check(WardenLook.same(WardenLook.with_set_colour(plain, Color(0.5, 0.5, 0.5)), plain),
		"a grey set gave the cloak a hue")
	_check(WardenLook.same(WardenLook.with_set_colour(plain, Color(0, 0, 0, 0)), plain),
		"no set changed the cloak")
	_check(WardenLook.same(WardenLook.worn(), WardenLook.mine()) or Modifiers.completed_set() != null,
		"with no full set worn, the drawn look must be the saved one")
	# Every place this machine draws or sends its own Warden wears the set.
	# The dye slider alone reads the saved look, because that is what it edits.
	for path: String in ["res://scenes/hero/hero.gd", "res://scripts/systems/coop_heroes.gd",
			"res://scripts/systems/coop_party.gd", "res://scripts/systems/hold_session.gd",
			"res://autoload/Coop.gd", "res://scenes/ui/coop_party_portrait.gd",
			"res://scenes/ui/hub_screen.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#") or not line.contains("WardenLook.mine()"):
				continue
			if line.contains("slider.value"):
				continue
			_check(false, "%s draws or sends the saved look rather than the worn one: %s"
				% [path, line.strip_edges()])


func _find_foliage(root: Node) -> Foliage:
	if root is Foliage:
		return root as Foliage
	for child: Node in root.get_children():
		var found: Foliage = _find_foliage(child)
		if found != null:
			return found
	return null


func _wait_for(done: Callable, limit: float) -> void:
	var clock: float = 0.0
	while clock < limit and not bool(done.call()):
		await get_tree().process_frame
		clock += get_process_delta_time()


func _seconds(span: float) -> void:
	var clock: float = 0.0
	while clock < span:
		await get_tree().process_frame
		clock += get_process_delta_time()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
