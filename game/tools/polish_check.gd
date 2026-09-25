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
##
## And the visual pass that followed it the same day:
##
##   * **Light takes the ground's colour.** A pool is its light times the earth
##     under it, lifted so dark earth tints rather than puts it out, and white
##     earth changes nothing.
##   * **The town is shelter at night**, every tower throws its element on the
##     ground, and ore and gems glow where timber does not - all dark at noon.
##   * **Towers shade with the light's direction.** Only a tower carries the
##     shading, its own light stands above it, and the sun sweeps from the right
##     at dawn to the left at dusk and is gone at night. Whether it *looks* right
##     is `shade_probe`'s question, windowed: headless there is no light.
##   * **A third dye and presets.** The leather is appended, so a two-number row
##     from an older partner still means cloak and sash, and every preset is a
##     look the sliders could have made.

const SEED: int = 20260923

var _failures: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	await _check_the_music()
	await _check_the_glow()
	_check_the_set_colours()
	_check_the_bounce()
	_check_the_leather()
	_check_the_bloom_and_the_splash()
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
	await _check_the_night_lights(run)
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
	# The dye sliders alone read the saved look, because that is what they edit -
	# including when a preset moves them.
	for path: String in ["res://scenes/hero/hero.gd", "res://scripts/systems/coop_heroes.gd",
			"res://scripts/systems/coop_party.gd", "res://scripts/systems/hold_session.gd",
			"res://autoload/Coop.gd", "res://scenes/ui/coop_party_portrait.gd",
			"res://scenes/ui/hub_screen.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		for line: String in text.split("\n"):
			if line.strip_edges().begins_with("#") or not line.contains("WardenLook.mine()"):
				continue
			if line.contains("slider.value") or line.contains("slider.set_value_no_signal"):
				continue
			_check(false, "%s draws or sends the saved look rather than the worn one: %s"
				% [path, line.strip_edges()])


## Everything the visual pass laid on a real field, lit and unlit.
func _check_the_night_lights(run: Node) -> void:
	var field: Battlefield = _find(run, func(n: Node) -> bool: return n is Battlefield) as Battlefield
	_check(field != null, "no battlefield under the run")
	if field == null:
		return
	var town: Node = _find(field, func(n: Node) -> bool: return n is TownCore)
	var town_glow: GroundGlow = _glow_under(town)
	_check(town_glow != null, "the town lays no pool of light")
	var town_lit: bool = false
	if town != null:
		for child: Node in town.get_children():
			if child is PointLight2D and (child as PointLight2D).color.is_equal_approx(
					Balance.TOWN_NIGHT_LIGHT_COLOUR):
				town_lit = true
	_check(town_lit, "the town carries no warm light of its own")

	RunState.gain_every_currency(5000)
	var tower_data: TowerData = ContentDB.tower("ember_spire")
	var anchor: Vector2i = field.free_anchor_near(0)
	var refused: String = field.try_build(anchor, tower_data)
	_check(refused.is_empty(), "could not build a tower to look at: %s" % refused)
	for _frame: int in 4:
		await get_tree().process_frame
	var tower: Tower = _find(field, func(n: Node) -> bool: return n is Tower) as Tower
	_check(tower != null, "no tower stood up")
	if tower != null:
		_check(_glow_under(tower) != null, "a tower throws no light on the ground")
		var material: ShaderMaterial = tower.sprite.material as ShaderMaterial
		if Graphics.polish_shaders():
			_check(material != null and is_equal_approx(float(material.get_shader_parameter(
				"shade_strength")), Balance.TOWER_SHADE_STRENGTH),
				"a tower does not shade with the light")
			_check(tower.sprite.light_mask & Balance.SUN_RELIEF_LAYER != 0,
				"a shaded tower does not carry the sun's layer, so the sun never reaches it")
		# The Warden turns to the light too (2026-09-25), at a body's strength.
		var warden: Hero = field.hero
		if warden != null and Graphics.polish_shaders():
			var worn := warden.sprite.material as ShaderMaterial
			_check(worn != null and is_equal_approx(float(worn.get_shader_parameter(
				"shade_strength")), Balance.BODY_SHADE_STRENGTH),
				"the Warden does not shade with the light")
			_check(warden.sprite.light_mask & Balance.SUN_RELIEF_LAYER != 0,
				"the Warden does not carry the sun's layer")
		var own_light: PointLight2D = tower.get("_light") as PointLight2D
		_check(own_light != null and is_equal_approx(own_light.height, Balance.TOWER_LIGHT_HEIGHT),
			"a tower's own light is not raised above it, so it shades the tower from its own foot")

	var torch: Torch = _find(field, func(n: Node) -> bool: return n is Torch) as Torch
	if torch != null:
		var pool: Sprite2D = torch.get("_pool") as Sprite2D
		var wanted: Color = GroundGlow.bounced(Balance.TORCH_LIGHT_COLOUR,
			field.ground_colour(torch.global_position))
		_check(pool != null and _near_colour(pool.modulate, wanted),
			"a torch's pool is not the colour of its flame on this ground (%s against %s)"
				% [pool.modulate if pool != null else Color.BLACK, wanted])

	var glows: Array[GroundGlow] = []
	_collect_glows(field, glows)
	# Which gather art is timber, read off the materials rather than the names.
	var timber: PackedStringArray = []
	for file: String in DirAccess.get_files_at("res://data/gather"):
		if not file.ends_with(".tres"):
			continue
		var kind: GatherNodeData = load("res://data/gather/" + file) as GatherNodeData
		var material_data: MaterialData = ContentDB.material(kind.material_id) if kind != null else null
		if material_data != null and material_data.kind == MaterialData.Kind.WOOD:
			timber.append(kind.get_sprite_path())
	_check(not timber.is_empty(), "found no timber to hold the seams against")
	var seams: int = 0
	var timber_glows: int = 0
	for glow: GroundGlow in glows:
		var node: Node = glow.get_parent()
		# By the art rather than the node's name: every node after the first is
		# renamed by the engine on arrival, and only the first keeps "GatherNode".
		if node is Sprite2D and (node as Sprite2D).texture != null \
				and (node as Sprite2D).texture.resource_path.contains("/node_"):
			if timber.has((node as Sprite2D).texture.resource_path):
				timber_glows += 1
			else:
				seams += 1
	_check(timber_glows == 0, "%d trees glow at night - timber is not ore" % timber_glows)
	_check(seams > 0, "not one ore or gem seam glows on this field")
	print("[polish] %d pools and halos on this field, %d of them on seams" % [glows.size(), seams])

	var sun: SunRelief = _find(field, func(n: Node) -> bool: return n is SunRelief) as SunRelief
	_check((sun != null) == Graphics.polish_shaders(),
		"the sun's relief must stand exactly when towers are shaded")
	var held_phase: float = DayNight.phase
	var held_dark: float = DayNight.darkness
	if sun != null:
		_check(sun.range_item_cull_mask == Balance.SUN_RELIEF_LAYER,
			"the sun reaches more than the shaded towers (mask %d)" % sun.range_item_cull_mask)
		DayNight.darkness = 0.0
		for pair: Vector2 in [Vector2(0.0, 90.0), Vector2(0.25, 0.0), Vector2(0.5, -90.0)]:
			DayNight.phase = pair.x
			await get_tree().process_frame
			await get_tree().process_frame
			_check(absf(sun.rotation_degrees - pair.y) < 0.5,
				"at phase %.2f the sun should stand at %d degrees, not %.1f"
					% [pair.x, int(pair.y), sun.rotation_degrees])
		DayNight.darkness = 1.0
		await get_tree().process_frame
		await get_tree().process_frame
		_check(not sun.visible and sun.energy <= 0.002, "the sun lights the towers at night")

	DayNight.darkness = 0.0
	await _seconds(0.3)
	var lit_at_noon: int = 0
	for glow: GroundGlow in glows:
		if is_instance_valid(glow) and glow.visible:
			lit_at_noon += 1
	_check(lit_at_noon == 0, "%d pools of light show at midday" % lit_at_noon)
	DayNight.darkness = 1.0
	await _seconds(0.3)
	if town_glow != null:
		_check(town_glow.visible and town_glow.modulate.a >= Balance.TOWN_NIGHT_POOL_ALPHA * 0.8,
			"the town's pool stays dark at deep night (%.2f)" % town_glow.modulate.a)
	DayNight.phase = held_phase
	DayNight.darkness = held_dark

	# **A big blow throws a real light** (2026-09-24): capped, gone with its
	# life, and off on Low. Every count is of lights in the tree, because a
	# light out of the tree lights nothing.
	var held_graphics: Dictionary = Graphics.to_dictionary()
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_HIGH})
	var before: int = get_tree().get_nodes_in_group(Vfx.LIGHT_BURST_GROUP).size()
	for index: int in Balance.LIGHT_BURST_MAX + 3:
		Vfx.light_burst(Vector2(120.0 * float(index), 0.0), Color.WHITE, 300.0, 1.5, 0.25)
	await get_tree().process_frame
	var standing: int = get_tree().get_nodes_in_group(Vfx.LIGHT_BURST_GROUP).size() - before
	_check(standing >= 1, "a big blow throws no light at all")
	_check(standing <= Balance.LIGHT_BURST_MAX,
		"%d burst lights stand at once against a cap of %d" % [standing, Balance.LIGHT_BURST_MAX])
	await _seconds(0.6)
	_check(get_tree().get_nodes_in_group(Vfx.LIGHT_BURST_GROUP).size() - before == 0,
		"a burst light outlived its life")
	# A blow after the last one has died: the list still holds the freed
	# lights, and the first cut's `filter` threw on them and made no light -
	# which this passed, because nothing here had ever thrown twice.
	Vfx.light_burst(Vector2.ZERO, Color.WHITE, 300.0, 1.5, 0.25)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(Vfx.LIGHT_BURST_GROUP).size() - before == 1,
		"a blow after the last light died threw no light")
	await _seconds(0.6)
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_LOW})
	Vfx.light_burst(Vector2.ZERO, Color.WHITE, 300.0, 1.5, 0.25)
	await get_tree().process_frame
	_check(get_tree().get_nodes_in_group(Vfx.LIGHT_BURST_GROUP).size() - before == 0,
		"Low still throws burst lights")
	Graphics.from_dictionary(held_graphics)
	for path: String in ["res://scripts/systems/meteor.gd", "res://scripts/systems/sky.gd",
			"res://scenes/battlefield/enemy.gd", "res://scripts/systems/dragon_breath.gd"]:
		_check(FileAccess.get_file_as_string(path).contains("Vfx.light_burst("),
			"%s no longer throws a light at its blow" % path.get_file())


## The pure half of the bounce.
func _check_the_bounce() -> void:
	var warm: Color = Balance.TORCH_LIGHT_COLOUR
	_check(_near_colour(GroundGlow.bounced(warm, Color.WHITE), warm),
		"white ground must leave a light its own colour")
	_check(_near_colour(GroundGlow.bounced(warm, Color.BLACK), warm),
		"black ground must tint a light or leave it - never put it out")
	var on_moss: Color = GroundGlow.bounced(warm, Color(0.2, 0.55, 0.25))
	_check(on_moss.g / maxf(on_moss.r, 0.001) > warm.g / maxf(warm.r, 0.001) + 0.02,
		"a warm light on green moss must come out greener than it went in")
	var on_snow: Color = GroundGlow.bounced(warm, Color(0.75, 0.82, 0.95))
	_check(on_snow.b / maxf(on_snow.r, 0.001) > warm.b / maxf(warm.r, 0.001),
		"a warm light on snow must come out bluer than it went in")
	var peak: float = maxf(warm.r, maxf(warm.g, warm.b))
	for ground: Color in [Color(0.2, 0.55, 0.25), Color(0.6, 0.3, 0.2), Color(0.3, 0.3, 0.35)]:
		var landed: Color = GroundGlow.bounced(warm, ground)
		_check(absf(maxf(landed.r, maxf(landed.g, landed.b)) - peak) < 0.08,
			"a pool's brightness moved with the ground (%s on %s) - the ground tints, never dims" % [landed, ground])


## The third dye and the presets.
func _check_the_leather() -> void:
	_check(WardenLook.KEYS.size() == 3 and WardenLook.KEYS[2] == WardenLook.KEY_LEATHER,
		"the leather must be appended after the cloak and the sash - the wire packs by position")
	var old_row: Array = [0.2, -0.1]
	var read: Dictionary = WardenLook.unpack(old_row)
	_check(is_equal_approx(float(read[WardenLook.KEY_CLOAK]), 0.2)
		and is_equal_approx(float(read[WardenLook.KEY_SASH]), -0.1)
		and is_equal_approx(float(read[WardenLook.KEY_LEATHER]), 0.0),
		"a two-number row from an older partner must still mean cloak and sash, leather painted")
	var dyed := {WardenLook.KEY_CLOAK: 0.1, WardenLook.KEY_SASH: 0.2, WardenLook.KEY_LEATHER: -0.3}
	_check(WardenLook.same(WardenLook.unpack(WardenLook.pack(dyed)), dyed),
		"the leather does not survive the wire")
	_check(WardenLook.same(WardenLook.preset(0), WardenLook.plain()),
		"the first preset must be the painted Warden")
	var seen: Array[Array] = []
	for index: int in WardenLook.PRESETS.size():
		var look: Dictionary = WardenLook.preset(index)
		_check(WardenLook.same(WardenLook.clean(look), look),
			"preset %s is not a look the sliders could make" % WardenLook.PRESETS[index]["label"])
		var row: Array = WardenLook.pack(look)
		_check(not seen.has(row), "preset %s repeats another" % WardenLook.PRESETS[index]["label"])
		seen.append(row)
	var held: Dictionary = WardenLook.mine()
	MetaState.set_whole_look(WardenLook.preset(1))
	_check(WardenLook.same(WardenLook.mine(), WardenLook.preset(1)), "a preset did not take")
	MetaState.set_whole_look(held)
	var dresser: String = FileAccess.get_file_as_string("res://scripts/systems/warden_look.gd")
	var shader: String = FileAccess.get_file_as_string("res://scripts/shaders/warden_look.gdshaderinc")
	_check(dresser.contains("\"look_leather\"") and shader.contains("uniform float look_leather"),
		"the leather is saved and packed but never reaches the shader")
	# **Amended 2026-09-25 (owner: "shaded bodies wanted").** Towers shade at
	# their own strength and every body at `BODY_SHADE_*`, set in exactly one
	# place each: `tower.gd` and `ActorShade`. A third writer is a second opinion
	# about how a body meets the light.
	for path: String in _scripts("res://scenes") + _scripts("res://scripts"):
		if path.ends_with("tower.gd") or path.ends_with("actor_shade.gd"):
			continue
		if FileAccess.get_file_as_string(path).contains("\"shade_strength\""):
			_check(false, ("%s sets a shade strength - bodies are dressed by ActorShade "
				+ "and towers by tower.gd, and nowhere else") % path)
	# Both actor shaders read the one light: a body in blood and a body in
	# polish must turn to it the same way.
	for shader_path: String in ["res://scripts/shaders/actor_polish.gdshader",
			"res://scripts/shaders/blood_stain.gdshader"]:
		var code: String = FileAccess.get_file_as_string(shader_path)
		_check(code.contains("actor_shade.gdshaderinc") and code.contains("SHADE_NORMAL("),
			"%s does not shade with the light" % shader_path.get_file())
	# And the two doors that dress every body actually dress it.
	for door: String in ["res://scripts/systems/blood_stain.gd",
			"res://scripts/systems/actor_polish.gd"]:
		_check(FileAccess.get_file_as_string(door).contains("ActorShade.dress("),
			"%s attaches a body's material without turning it to the light" % door.get_file())


## The bloom (2026-09-24) rides the grade's pass and reads the screen's mip
## chain; the boot splash is the studio splash's own dark. Headless draws
## neither, so both are held by what they are made of.
func _check_the_bloom_and_the_splash() -> void:
	var grade: String = FileAccess.get_file_as_string("res://scripts/shaders/color_grade.gdshader")
	_check(grade.contains("filter_linear_mipmap"),
		"the grade reads the screen without mipmaps, so the bloom has no blur to read")
	_check(grade.contains("textureLod(screen_tex, SCREEN_UV, 0.0)"),
		"the picture must be read at mip 0 - an automatic level would soften the whole frame")
	var driver: String = FileAccess.get_file_as_string("res://scripts/systems/color_grade.gd")
	_check(driver.contains("if Graphics.bloom() else 0.0"),
		"the bloom switch is not what decides the bloom")
	_check(Balance.BLOOM_THRESHOLD_DAY > Balance.BLOOM_THRESHOLD_NIGHT + 0.3,
		"the day's threshold must sit well above the night's, or a sunlit field hazes")
	var held: Dictionary = Graphics.to_dictionary()
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_LOW})
	_check(not Graphics.bloom_chosen(), "the bloom must be off by default on Low")
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_HIGH})
	_check(Graphics.bloom_chosen(), "the bloom must be on by default on High")
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_HIGH, Graphics.KEY_BLOOM: false})
	_check(not Graphics.bloom_chosen(), "turning the bloom off did not turn it off")
	Graphics.from_dictionary(held)
	_check(not bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)),
		"the boot splash still shows an image - the first thing a player sees is Godot's logo")
	var splash: Node = (load("res://scenes/ui/splash.tscn") as PackedScene).instantiate()
	var background: ColorRect = _find(splash, func(n: Node) -> bool: return n is ColorRect) as ColorRect
	var boot: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	_check(background != null and _near_colour(background.color, boot),
		"the boot splash (%s) is not the studio splash's own background (%s) - the handoff flashes"
			% [boot, background.color if background != null else Color.BLACK])
	splash.free()


func _scripts(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	for file: String in dir.get_files():
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub: String in dir.get_directories():
		found.append_array(_scripts(folder.path_join(sub)))
	return found


func _near_colour(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.02 and absf(a.g - b.g) < 0.02 and absf(a.b - b.b) < 0.02


func _glow_under(node: Node) -> GroundGlow:
	if node == null:
		return null
	for child: Node in node.get_children():
		if child is GroundGlow:
			return child as GroundGlow
	return null


func _collect_glows(node: Node, out: Array[GroundGlow]) -> void:
	if node is GroundGlow:
		out.append(node as GroundGlow)
	for child: Node in node.get_children():
		_collect_glows(child, out)


func _find(root: Node, wanted: Callable) -> Node:
	if bool(wanted.call(root)):
		return root
	for child: Node in root.get_children():
		var found: Node = _find(child, wanted)
		if found != null:
			return found
	return null


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
