extends Node

## Captures the Guide's demonstration pictures (owner brief, 2026-09-12:
## "how-to sections with demonstration screenshots") into
## `res://art/guide/<id>.png`, one per `GuideSectionData.image`.
##
## A tool rather than a gate: it drives the real run through every state a
## section explains - a build, a wave, the night, a pond, a camp, a raid, a
## dungeon, the screens - and photographs each at 640x360. What it writes is
## **shipped art**, so a run of it is followed by `--import` and a commit, and
## `guide_check` holds that every section's picture exists.
##
##   godot --path game --resolution 1280x720 res://tools/guide_shots.tscn
##
## Every setup is guarded and every picture is taken even when a setup finds
## nothing to show: a section with a plain picture of the road beats one with
## no picture, and a tool that died on the ninth shot of thirty-eight shipped
## nothing.

const OUT: String = "res://art/guide/"
## **How big a guide picture is written.**
##
## 640x360 until 2026-09-16, which is a three-times downscale off a 1920-wide
## frame - and the owner's repeated note about these was that they are low
## quality and need "more in game zoom". Half the complaint is the zoom, which is
## per-shot; the other half is this, which is every shot at once. 960x540 is the
## same 16:9 the Guide lays them out in, so nothing about the page moves.
##
## `docs/ASSET_MANIFEST.md` records the size of every one of them and
## `asset_report` checks it, so this number and those rows move together.
## **What lands on disk**, downsampled from whatever the screen actually is.
##
## Raised from 960x540 with the move to fullscreen (owner, 2026-09-16: "do it in
## fullscreen for higher quality images"). The Guide lays these out 16:9, so the
## shape does not move; `ASSET_MANIFEST` records the size and `asset_report`
## checks it, which is why changing this is a manifest edit as well.
const SIZE := Vector2i(1280, 720)

var run: Run = null
var _written: PackedStringArray = []

## **Which pictures this run is for**, empty meaning all of them.
##
## Owner, 2026-09-16: "properly resolve the ones with screenshot issues
## individually instead of running the full sequence for 1 focused issue each
## time." The sequence still *runs* - a picture's subject is often a state three
## shots earlier put the run into - but an unwanted one settles for a few frames
## instead of seventy and is never written, which is the whole of the cost.
##
##     godot --path game res://tools/guide_shots.tscn -- --only=fishing,reel
var _only: PackedStringArray = []

## How many towers this run has put up, so each picture draws a different one.
var _towers_built: int = 0

## **What the current picture put on the field**, and how to take it off again.
##
## Owner, 2026-09-16: a boss, its projectiles and a sent predator were all still
## standing in the photographs after theirs. Taking the boss off by name was the
## shape of a fix that has to be written again for every next thing, so a shot
## that stages something registers the way to unstage it and `_settle` empties
## the list. Nothing has to know what the last picture did.
var _staged: Array[Callable] = []


## Registers a node to be taken off the field before the next picture.
##
## **The id is captured, not the node.** A lambda holding a freed object errors
## at the *call* - "Lambda capture at index 0 was freed" - before its own body
## runs, so guarding inside it does nothing; this project has paid for that once
## already with three scopes following the sun through a lambda. An `int`
## survives whatever happens to the thing it names.
func _stage(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var id: int = node.get_instance_id()
	_staged.append(func() -> void:
		var it: Object = instance_from_id(id)
		if it != null and is_instance_valid(it):
			(it as Node).queue_free())


## Registers any way of taking something off, for things a `queue_free` cannot
## honestly remove.
func _stage_undo(undo: Callable) -> void:
	_staged.append(undo)


func _asked_for() -> PackedStringArray:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			return arg.substr(7).split(",", false)
	return PackedStringArray()


func _wanted(id: String) -> bool:
	return _only.is_empty() or _only.has(id)


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	# **Every once-ever cinematic is marked seen before the run starts.**
	#
	# `MilestoneCinematics` inks the field over for the first boss, the first
	# raid and the rest, and on a profile that has never played they all still
	# owe. The boss picture was photographed *through* one - a dark brown
	# rectangle with a health bar on top of it - and any other shot could have
	# been. Held saves, so nothing is written to the player's account.
	for beat: MilestoneCinematicData in ContentDB.milestone_cinematics_sorted():
		MetaState.mark_milestone_cinematic_seen(beat.id)
	# **Fullscreen, because the source frame is what decides the quality.**
	#
	# A 1280x720 window downsampled to the file is barely a downsample at all;
	# the monitor's own resolution through a Lanczos filter is. `_capture` crops
	# to 16:9 before it resizes, so a screen of any shape is handled rather than
	# squashed.
	get_window().mode = Window.MODE_FULLSCREEN
	_only = _asked_for()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	RunState.reset(false, 20260912)
	GameDirector.run_active = true
	run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 16:
		await get_tree().process_frame
	RunState.gain_every_currency(2400)
	var field: Battlefield = run.battlefield

	# --- The road, in Preparation ---------------------------------------------------
	# The one picture the card belongs in stands it back up itself - `_settle`
	# takes it down before every shot, which is what keeps it out of the rest.
	await _shot("preparation", func() -> void:
		_apt_post("preparation")
		GameDirector.set_build_mode(true)
		_show_preparation_card(true),
		func() -> void: _apt_post("preparation"))
	GameDirector.set_build_mode(false)
	# Stood off and looked at, like everything else with a subject - and closed
	# in on, because the owner asked for the wells "zoomed in in game more" with
	# the interaction showing, and any emplacement read across a whole
	# battlefield is a speck.
	# **Standing well below it, not beside it** (owner, 2026-09-16: a well must
	# not be "blocked/faded by player positioned behind it"). An emplacement is
	# the subject of these three, and a Warden a body's width away overlaps it;
	# mostly below and a little to the side leaves the structure clear, and the
	# gap between them is itself what the section is teaching.
	await _made_subject_shot("towers", func() -> Vector2: return _build_some(false),
		Vector2(24.0, 258.0), 1.0)
	await _made_subject_shot("wells", func() -> Vector2: return _build_some(true),
		Vector2(20.0, 246.0), 1.0)
	await _made_subject_shot("traps", func() -> Vector2: return _place_trap(),
		Vector2(18.0, 196.0), 1.0)
	await _shot("town", func() -> void: run.switch_scope(GameDirector.Scope.TOWN))
	await _shot("act_track", func() -> void: run.switch_scope(GameDirector.Scope.BEAST))
	_copy("act_track", "glossary_a")
	run.switch_scope(GameDirector.Scope.BATTLEFIELD)

	# --- Water ----------------------------------------------------------------------------
	var pond: Vector2 = _pond_centre()
	var bank: Vector2 = _pond_bank(pond)
	# **On the shore, with the line in the water** (owner, 2026-09-16: "player
	# needs to not be inside the pond but outside by its water shore and needs to
	# cast the line into it"). Standing beside water is a picture of a pond; what
	# the section is about is the cast, so all three are driven for real.
	#
	# The charge gauge is what *depth* looks like: a longer hold throws further
	# and further out is deeper water holding the rarer fish, so the picture for
	# depth is the throw being aimed rather than a second photograph of the same
	# shoreline.
	var middle: Vector2 = _pond_aim(pond, bank)
	await _water_shot("fishing", bank, Fishing.State.WAITING, 1.0, middle)
	await _water_shot("depth", bank, Fishing.State.CHARGING, 1.0, middle)
	# **The reel is a state, not a place** (owner: "reeling in a fish screenshot
	# is not showing that at all"). It was a copy of the swimming picture - a
	# hero in the water, which is the one thing a player cannot be doing while
	# fishing. Driven through `Fishing`'s own doors and photographed on the frame
	# the line goes tight, because a hooked fish does not wait seventy frames.
	#
	# **Taken before the swimming picture and not after**: `_swimming` carries
	# hysteresis and is only cleared by a tick on dry ground, so an angler
	# photographed straight after a swim is still being told to get out of the
	# water however dry the ground under them is.
	await _water_shot("reel", bank, Fishing.State.REELING, 1.0, middle)
	await _shot("swimming", func() -> void: _stand_at(pond))
	await _subject_shot("farming", _wild_crop(), Vector2(70.0, 50.0), 1.0)
	# Further off than the rest: a camp is a place rather than an object, and
	# standing on top of one photographs a tent.
	await _subject_shot("camps", _camp_centre(), Vector2(150.0, 130.0), 0.85)
	# **A real sign, stood at**, and taken here with the other field pictures
	# rather than down among the copies: by the time the rift shots have run the
	# hero has been put back beside the town, and the first cut photographed the
	# town square with a caption about tracking.
	# **The act is put back afterwards.** The trail needs an act it can begin in
	# and pushes the run to II; nothing put it back, so every later picture was
	# taken in a run whose act had quietly moved - which is how the act-boss
	# photograph came out holding an Act II boss under a HUD reading Act I.
	var act_was: int = RunState.act
	await _made_subject_shot("mythic_trail",
		func() -> Vector2: return _stand_at_a_trail_sign(run),
		Vector2(84.0, 58.0), 1.0)
	RunState.act = act_was
	await _subject_shot("forks", _barrier_at(), Vector2(126.0, 104.0), 0.9)

	# --- The fight ---------------------------------------------------------------------------
	await _shot("party_events", func() -> void:
		_apt_post("party_events")
		EventBus.party_event_prompt.emit(0, 0, "Ren", 20.0, false),
		func() -> void: _apt_post("party_events"))
	EventBus.party_event_prompt_closed.emit()
	# The spirit is the subject, so it is what gets looked at once it is called.
	await _shot("spirits", func() -> void:
		_apt_post("spirits"); _bond_a_spirit(),
		func() -> void:
			var hero: Hero = run.battlefield.hero
			if hero != null and hero.spirit != null and is_instance_valid(hero.spirit):
				_look_at((hero.spirit as Node2D).global_position))
	_copy("spirits", "summons")
	run.call("_on_ride_on_requested")
	await _let_a_wave_arrive()
	await _shot("waves", func() -> void: _apt_combat_post("waves"),
		func() -> void: _apt_combat_post("waves"))
	_copy("waves", "hud")
	_copy("waves", "loop")
	_copy("waves", "bow")
	_crop("waves", "spells", Rect2(0.25, 0.8, 0.5, 0.2))
	_crop("waves", "currencies", Rect2(0.0, 0.0, 0.42, 0.22))
	await _shot("healing", func() -> void:
		_apt_combat_post("healing")
		if field.hero != null and field.hero.health != null:
			field.hero.health.take_damage(field.hero.health.max_hp * 0.45,
				field.hero.global_position + Vector2.LEFT * 30.0),
		func() -> void: _apt_combat_post("healing"))
	await _shot("night", func() -> void:
		_apt_combat_post("night"); DayNight.call("_apply", 0.78),
		func() -> void: _apt_combat_post("night"))
	# **The torches**, which are what the night is *about* from a player's seat:
	# a lane goes dark as its flames go out, and darkness is pressure rather than
	# decoration. Taken at night for the same reason - a torch at noon is a post.
	await _shot("torches", func() -> void: _apt_post("torches"),
		func() -> void: _apt_post("torches"))
	DayNight.call("_apply", 0.30)

	# --- The sky, the ground, and the earth -------------------------------------------
	#
	# Eight systems the Guide had nothing to say about (owner, 2026-09-16), each
	# driven through its own public door rather than by setting a state, so what
	# is photographed is the event the game actually runs.
	# **Through the bus the weather actually changes on.** Setting a field on the
	# sky would leave every other listener - the climate, the wildfire's dryness,
	# the flood - believing it was still clear.
	await _weather_shot("weather", func() -> void:
		EventBus.weather_changed.emit("downpour"), 90)
	await _weather_shot("temperature", func() -> void:
		var ground: Climate = run.battlefield.climate()
		var hero: Hero = run.battlefield.hero
		if ground != null and hero != null:
			# A hot spot and a cold one either side, so the picture shows the
			# *difference* rather than a number nobody is shown anyway.
			ground.add_heat(hero.global_position + Vector2(-200.0, 0.0), 260.0, 26.0)
			ground.add_wet(hero.global_position + Vector2(220.0, 40.0), 240.0, 0.9))
	# **The strike is thrown six frames before the shutter.** `_draw_bolt` fades
	# its lines out over 0.15 seconds and `_take` waits seventy frames, so a bolt
	# made in the drive is long gone by the time the picture is taken - which is
	# why this picture has never had lightning in it.
	await _weather_shot("lightning", func() -> void:
		EventBus.weather_changed.emit("downpour"), 60,
		func() -> void:
			var sky: WeatherSky = run.battlefield.sky()
			var hero: Hero = run.battlefield.hero
			if sky != null and hero != null:
				var at: Vector2 = hero.global_position + Vector2(180.0, -120.0)
				sky.strike_at(at)
				_hush()
				_look_at(at))
	await _weather_shot("flood", func() -> void:
		RunState.flood = 0.85
		var sky: WeatherSky = run.battlefield.sky()
		if sky != null:
			sky.set("_flood", 0.85))
	RunState.flood = 0.0
	# **Lit at brush, and held until it is a blaze.** `start_wildfire` picks its
	# own point anywhere on the field and refuses it unless unburnt brush is
	# close, so on a Warden posted on a road it is a coin toss whether anything
	# shows at all - which the owner photographed.
	await _weather_shot("wildfire", func() -> void:
		var fire: Wildfire = run.battlefield.wildfire()
		var hero: Hero = run.battlefield.hero
		var leaves: Foliage = run.battlefield.foliage_node()
		if fire == null or hero == null or leaves == null:
			return
		var blaze: Vector2 = _brush_near(hero.global_position + Vector2(180.0, -60.0), 520.0)
		if not blaze.is_finite():
			return
		for near: Dictionary in leaves.plants_near(blaze, 170.0):
			fire.ignite_near(near["at"], 30.0, 1.0)
		_wildfire_at = blaze, 420,
		func() -> void: _look_at(_wildfire_at),
		func() -> bool:
			var fire: Wildfire = run.battlefield.wildfire()
			return fire != null and fire.fire_count() >= 6)
	await _weather_shot("quake", func() -> void:
		var sky: WeatherSky = run.battlefield.sky()
		if sky != null:
			# **The warning, not the quake.** The line, the rising tremor and
			# every animal running is the thing worth teaching; the shake itself
			# is a frame of blur.
			sky.warn_quake(0.85))
	await _weather_shot("tornado", func() -> void:
		var sky: WeatherSky = run.battlefield.sky()
		var hero: Hero = run.battlefield.hero
		if sky != null and hero != null:
			sky.spawn_tornado(hero.global_position + Vector2(-520.0, -180.0),
				hero.global_position + Vector2(260.0, 60.0)), 120)
	# **The moment it lands**, which is the one frame that carries the whole
	# event: the blast rings leaving, the plume, and the crater it has just put
	# in the road. A shutter at a fixed seventy frames fired mid-warning, before
	# the stone was even drawn - `METEOR_WARNING` is 2.2 seconds and the stone
	# shows for the last 0.55 of them.
	_the_stone = 0
	await _weather_shot("meteor", func() -> void:
		var sky: WeatherSky = run.battlefield.sky()
		var hero: Hero = run.battlefield.hero
		if sky == null or hero == null:
			return
		_meteor_at = hero.global_position + Vector2(210.0, -70.0)
		var stone: Meteor = sky.drop_meteor(_meteor_at)
		if stone != null:
			_the_stone = stone.get_instance_id(), 300,
		func() -> void: _look_at(_meteor_at),
		func() -> bool:
			var stone: Variant = instance_from_id(_the_stone) if _the_stone != 0 else null
			return stone != null and is_instance_valid(stone as Object) 				and bool((stone as Meteor).get("_landed")))
	await _weather_shot("charged_ground", func() -> void:
		var sky: WeatherSky = run.battlefield.sky()
		var hero: Hero = run.battlefield.hero
		if sky != null and hero != null:
			# A strike leaves a storm core; the towers of that element standing on
			# it hit harder for a while. That charged ground is the picture.
			sky.strike_at(hero.global_position + Vector2(120.0, -40.0)), 60)
	# **Where two of them meet** (owner, 2026-09-16: "show that some elemental
	# disasters can blend together"). Not a third system pretending to be one -
	# each of these is a rule the game already runs, photographed at the moment it
	# applies rather than after a guessed number of frames.
	_the_whirl = 0
	await _weather_shot("fire_whirl", _drive_a_fire_whirl, 900,
		func() -> void:
			var funnel: Tornado = _the_funnel()
			if funnel != null:
				_look_at(funnel.global_position),
		func() -> bool:
			# **Burning *and* near enough to photograph.** A funnel picks fire up
			# `TORNADO_AOE` before it reaches the blaze, which on this bearing is
			# off the top of the window; it is aimed past the fire toward the
			# Warden, so a moment later it carries the fire into frame.
			var funnel: Tornado = _the_funnel()
			return funnel != null and funnel.burning() \
				and funnel.global_position.distance_to(
					run.battlefield.hero.global_position) < 430.0)
	await _weather_shot("conductive_flood", func() -> void:
		# Water conducts: a strike over standing water chains further, and every
		# body in it is soaked and takes it harder.
		RunState.flood = 0.9
		var sky: WeatherSky = run.battlefield.sky()
		if sky != null:
			sky.set("_flood", 0.9), 70,
		func() -> void:
			var sky: WeatherSky = run.battlefield.sky()
			var hero: Hero = run.battlefield.hero
			if sky != null and hero != null:
				var at: Vector2 = hero.global_position + Vector2(150.0, -90.0)
				sky.strike_at(at)
				_hush()
				_look_at(at))
	RunState.flood = 0.0
	# Long enough for the brush to be properly alight and no longer: the heat
	# veil deepens the whole time a heatwave stands, and at ten seconds it is a
	# red wash over a picture nobody can read. The strike is **not** repeated at
	# the shutter - every strike opens a storm core, and its full-screen banner
	# is the charged-ground picture's subject standing over this one.
	await _weather_shot("dry_lightning", _drive_dry_lightning, 420,
		func() -> void: _look_at(_dry_at),
		func() -> bool:
			# A strike lights one plant. The picture is of brush *catching*, so
			# it waits for the blaze to spread rather than for the strike to land
			# - and stops as soon as it has, because the heat veil deepens for as
			# long as a heatwave stands.
			var fire: Wildfire = run.battlefield.wildfire()
			return fire != null and fire.fire_count() >= 5)
	await _weather_shot("wrath", func() -> void:
		var hero: Hero = run.battlefield.hero
		EventBus.wrath_warned.emit("unrest_2",
			hero.global_position if hero != null else Vector2.ZERO, 4.0))
	_copy("night", "glossary_c")
	DayNight.call("_apply", 0.18)

	# --- The screens ------------------------------------------------------------------
	await _shot("crossroads", func() -> void: run.crossroad_ui.open(1))
	run.crossroad_ui.visible = false
	# **Turning for home, at a fork** (owner, 2026-09-16: extraction at a
	# crossroad needs its own Guide entry and picture). The card is only on the
	# panel when the run says it may be, so the run is told to offer it - the
	# same door `Run._open_crossroad` opens it through.
	await _shot("extraction", func() -> void:
		run.crossroad_ui.extraction_offered = true
		run.crossroad_ui.extraction_marks = Run.homecoming_marks(RunState.act, true)
		run.crossroad_ui.visible = true
		run.crossroad_ui.open(2))
	run.crossroad_ui.extraction_offered = false
	run.crossroad_ui.visible = false
	await _shot("cards", func() -> void:
		run.crossroad_ui.visible = true
		run.call("_offer_road_cards"))
	run.crossroad_ui.visible = false
	RunState.pending_road_cards = []
	await _shot("relics", func() -> void:
		# **Rolled for real**, through `Journey`'s own documented seam - the same
		# draw a completed road makes, with its eligibility and duplicate rules.
		# Opened with an empty pool the card is a title over nothing, which is
		# what the owner was shown.
		if run.journey != null:
			RunState.pending_road_relics = run.journey.regional_relic_choices_for_test(
				RunState.act)
		run.crossroad_ui.visible = true
		run.crossroad_ui.open_relic_reward())
	run.crossroad_ui.visible = false
	_copy("relics", "glossary_b")
	var stash: StashScreen = StashScreen.new()
	add_child(stash)
	await _shot("stash", func() -> void: _stock_the_stash(); stash.open())
	# **Gear is a slot, not the whole stash.** The two pictures were the same
	# photograph, so the section about gear illustrated the section about the
	# stash - which is the fault in miniature.
	await _shot("gear", func() -> void:
		_pick_tab(stash, GearData.name_of_slot(GearData.Slot.WEAPON)))
	await _shot("pantry", func() -> void: _pick_tab(stash, "Fish"))
	# **A catch to share** (owner: "Sharing a catch doesn't show fish or the
	# ability to share it"). Both buttons the section is about are offered only
	# when there is somebody to take the fish, so the picture needed a wounded
	# player beside the hero before it could show either of them.
	await _shot("sharing_fish", func() -> void:
		_stand_a_hurt_partner(); stash.call("_refresh"))
	# **The Ledger is the Ledger, not the stash.** Reported by the owner as the
	# trading picture being wrong; it was a photograph of a different screen.
	#
	# Taken last of this block, and that is the fix to the picture above it: the
	# Exchange is a screen of its own laid over the stash, and nothing took it
	# down again - so the pantry used to be photographed through the Ledger.
	await _shot("trading", func() -> void:
		_screen_shot(func() -> Node: return ExchangeScreen.new(), "Exchange"))
	for node: Node in get_children():
		if node.name.ends_with("Shot"):
			node.queue_free()
	stash.queue_free()
	await _shot("controls", func() -> void: _open_settings("Controls"))
	await _shot("coop", func() -> void: _open_coop())
	await _shot("account", func() -> void: _open_hub())
	for node: Node in get_children():
		if node.name in ["HubShot", "CoopShot", "SettingsShot"]:
			node.queue_free()
	for _f: int in 4:
		await get_tree().process_frame

	# --- The places you go ------------------------------------------------------------
	await _shot("raids", func() -> void:
		field.suspend()
		run.raid.visible = true
		run.raid.process_mode = Node.PROCESS_MODE_INHERIT
		run.raid.begin()
		run.raid.activate())
	# **Waited out rather than assumed.** See `_close_arena`: with a renderer a
	# rift finishes over several seconds, and everything photographed in the
	# meantime is photographed inside the arena that is closing.
	await _close_arena(run.raid, {"partial": true, "died": false, "kills": 14},
		EventBus.raid_ended, 12.0)
	await _shot("rifts", func() -> void:
		field.suspend()
		run.rift.visible = true
		run.rift.process_mode = Node.PROCESS_MODE_INHERIT
		run.rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
		run.rift.activate())
	await _close_arena(run.rift, {"closed": true, "left": true},
		EventBus.rift_ended, 12.0)

	# **The map, opened.** The fog is in every battlefield picture and so is a
	# corner of the road, but the minimap is hidden until it is asked for - so
	# the two sections about seeing where you are were illustrated by a road
	# with no map on it.
	await _shot("minimap", func() -> void:
		if run.hud != null:
			run.hud.call("_toggle_minimap"))
	# The fog itself is the thing the map is drawn from, so it is photographed
	# with the map open beside it and the hero somewhere the road is unexplored.
	await _shot("fog", func() -> void: _stand_at(_camp_centre()))
	if run.hud != null:
		run.hud.call("_toggle_minimap")
	_stand_at(Vector2.ZERO)
	# **A tower's paths are read on the tower's own sheet**, and only once it has
	# reached the fifth level - which is the decision the section is about. The
	# ladder is climbed through `try_upgrade` so the sheet is the one the game
	# would actually have offered.
	await _shot("tower_paths", func() -> void:
		var anchor: Vector2i = _a_built_tower()
		if anchor.x > -900:
			_raise_a_tower(anchor, 5)
			if run.hud != null:
				run.hud.call("_open_build_panel", anchor))
	if run.hud != null:
		run.hud.call("_close_build_panel")
	# And a trap's levels are read on the road sheet, for the same reason.
	await _shot("trap_levels", func() -> void:
		for key: Variant in RunState.traps:
			RunState.gain_every_currency(6000)
			run.battlefield.try_upgrade_trap(key as Vector2i)
			if run.hud != null:
				run.hud.call("_open_road_panel", key as Vector2i)
			break)
	if run.hud != null:
		run.hud.call("_close_build_panel")
	_copy("spirits", "spirit_upkeep")
	# **A boss picture with a boss in it** (owner: "No act boss is visible in the
	# demo screenshot but should be"). It was a copy of the ordinary wave
	# photograph, so the section about fighting an act boss showed a road of
	# marchers. Summoned for real and framed close, but not so close that the
	# thing itself is a spoiler - it is a silhouette at the end of a road, which
	# is how a player first meets one anyway.
	await _shot("boss_fight", func() -> void:
		if run.boss_director != null:
			# The act the run is *in*, so the thing on the road and the act named
			# at the top of the screen are the same act.
			run.boss_director.summon(RunState.act)
		# **Stood there in the setup, not in the late beat.** The fog is stamped
		# ten times a second and hides what has never been seen, so a camera
		# snapped somewhere six frames before the shutter photographs the dark.
		# Seventy frames is long enough for the ground around the boss to be lit.
		_face_the_boss(),
		func() -> void: _face_the_boss())
	_zoom(0.0)
	# **Something that has had enough of being hunted** (owner brief,
	# 2026-09-13: over-farming a species sends a savage of it after you). It was
	# a photograph of a camp, which is a different thing entirely.
	await _made_subject_shot("hunted", func() -> Vector2: return _send_a_hunter(),
		Vector2(-120.0, 90.0), 1.0)
	# **A nest picture with a nest in it** (owner: "Nests and eggs not visible in
	# screenshot image"). It was a copy of the trail-sign photograph.
	await _made_subject_shot("nesting", func() -> Vector2: return _lay_a_nest(),
		Vector2(74.0, 54.0), 1.0)
	# **The fifth attribute is read on the Mansion's hero page**, which is where
	# the section says to go - the picture was of the town square.
	await _shot("attributes", func() -> void: _open_mansion(0))
	# And the Arcane tree is a page of the same sheet. It was a copy of the
	# spells crop, which shows the bar rather than the tree.
	await _shot("arcane", func() -> void: _open_mansion(2, 3))
	if run.town_panel != null:
		run.town_panel.call("close")
	run.switch_scope(GameDirector.Scope.BATTLEFIELD)
	for _f: int in 8:
		await get_tree().process_frame
	# **And the Forge is the Forge.** Same fault, same answer.
	await _shot("forge", func() -> void:
		_screen_shot(func() -> Node: return SmithyScreen.new(), "Smithy"))
	for node: Node in get_children():
		if node.name.ends_with("Shot"):
			node.queue_free()
	for _f: int in 8:
		await get_tree().process_frame
	# **A seam worth stopping at**, for the two sections about the crafts. They
	# were copies of a tower picture and of the resource counters, neither of
	# which has a gather node anywhere in it.
	await _subject_shot("gathering", _a_gather_node(), Vector2(56.0, 40.0), 1.0)
	_crop("gathering", "crafts", Rect2(0.2, 0.15, 0.6, 0.7))
	# **A bow with an arrow in the air.** It was a photograph of an ordinary
	# wave, because the hero starts a run melee-only and nothing in this tool
	# had ever put a bow in their hands.
	await _shot("bow", func() -> void: _arm_the_bow(), func() -> void: _loose_an_arrow())
	# **And what the road throws back.** Every shooter standing looses at once,
	# six frames before the shutter.
	await _shot("enemy_shots", func() -> void: _zoom(1.3),
		func() -> void: _make_the_shooters_fire())
	_zoom(0.0)
	RunState.ranged_id = ""
	# **The Quartermaster's button, lit.** It is disabled while there is nothing
	# its cheapest order would mend, so the section about the standing orders was
	# illustrated by a Preparation screen with a greyed button on it.
	await _shot("quartermaster", func() -> void:
		_hurt_the_defences(); GameDirector.set_build_mode(true))
	GameDirector.set_build_mode(false)

	print("[guide-shots] wrote %d pictures to %s" % [_written.size(),
		ProjectSettings.globalize_path(OUT)])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)


# --- Set-ups -----------------------------------------------------------------------------

## A couple of towers on legal ground near the town, so the picture shows a
## defence rather than a field.
## Builds a few emplacements and **returns where the first one stands**, so the
## picture can be framed on it rather than on wherever the hero happened to be.
##
## **Three towers, three different towers, in three different places** (owner,
## 2026-09-16). The first cut drew one kind and built three of it, and before
## that it took whatever sorted first - so every tower picture in the Guide was
## the same electric spire, three times over.
##
## Drawn without replacement from what the account has unlocked, on anchors
## shuffled out of a band rather than taken in scan order, all on a seeded stream
## keyed by how many pictures have built already: the board varies between
## sections and the same run still produces the same board twice.
func _build_some(well: bool) -> Vector2:
	var field: Battlefield = run.battlefield
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guide-build:%d" % _towers_built)
	_towers_built += 1

	var wanted: int = 1 if well else 3
	var kinds: Array[TowerData] = []
	if well:
		var draw: TowerData = ContentDB.tower("healing_well")
		if draw != null:
			kinds.append(draw)
	else:
		# **What the build sheet itself offers**, not every tower in the game.
		# `ContentDB.towers` includes the ten *fusions*, which cannot be placed at
		# all - they are made by fusing neighbours - so a random draw across the
		# whole table refused every anchor with "nothing beside this tile fuses
		# into Bastion" and the towers picture came out with no towers in it.
		var roster: Array[TowerData] = []
		for candidate: TowerData in ContentDB.unlocked_base_towers():
			if candidate != null and not candidate.is_well():
				roster.append(candidate)
		# Sorted before it is shuffled: `ContentDB.towers` is a Dictionary and
		# its order is not something to build a seeded draw on.
		roster.sort_custom(func(a: TowerData, b: TowerData) -> bool: return a.id < b.id)
		for _pick: int in wanted:
			if roster.is_empty():
				break
			kinds.append(roster.pop_at(rng.randi_range(0, roster.size() - 1)))
	if kinds.is_empty():
		return Vector2.ZERO

	var spots: Array[Vector2i] = _open_anchors(rng)
	var first := Vector2.ZERO
	var built: int = 0
	for anchor: Vector2i in spots:
		if built >= kinds.size():
			break
		if not field.placement_problem(anchor).is_empty():
			continue
		if not field.try_build(anchor, kinds[built]).is_empty():
			continue
		# **The frontmost one is the subject**, not the first one laid. The Warden
		# stands below whatever this returns, and standing below the *first*
		# tower put them on top of whichever of the others happened to be laid
		# lower down the screen - which is the overlap the owner asked to be rid
		# of. The lowest emplacement has nothing below it to stand on.
		var here: Vector2 = BattleGrid.tile_to_world(anchor)
		if built == 0 or here.y > first.y:
			first = here
		built += 1
	if built < kinds.size():
		var names: PackedStringArray = []
		for kind: TowerData in kinds:
			names.append(kind.id)
		print("[guide-shots] built %d of %d (%s), gold %d"
			% [built, kinds.size(), ", ".join(names), RunState.currency(RunState.GOLD)])
	return first


## **A cluster of legal ground, in a varied order.**
##
## Two cuts were wrong before this one. The scan used to walk rings out from the
## exact middle and take the first anchors it met, so every picture put its
## builds into the same tidy arc; shuffling the whole band instead scattered
## three towers across a quarter of the map, and the picture then showed one of
## them with the Warden standing on it.
##
## What a board actually looks like is a few emplacements **together**, so a
## seeded legal anchor is taken as a centre and its neighbours are offered - then
## shuffled among themselves, so which of them each tower takes still varies. The
## cluster moves between pictures and the arrangement inside it moves with it.
func _open_anchors(rng: RandomNumberGenerator) -> Array[Vector2i]:
	var field: Battlefield = run.battlefield
	var middle := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	var legal: Array[Vector2i] = []
	for ring: int in range(3, 16):
		for dx: int in range(-ring, ring + 1):
			for dy: int in [-ring, ring]:
				for tile: Vector2i in [middle + Vector2i(dx, dy), middle + Vector2i(dy, dx)]:
					if field.placement_problem(tile).is_empty():
						legal.append(tile)
	if legal.is_empty():
		return legal
	var centre: Vector2i = legal[rng.randi_range(0, legal.size() - 1)]
	legal.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a - centre).length_squared() < Vector2(b - centre).length_squared())
	var near: Array[Vector2i] = legal.slice(0, mini(9, legal.size()))
	for index: int in range(near.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap_tile: Vector2i = near[index]
		near[index] = near[other]
		near[other] = swap_tile
	# The rest stay on the end as a fallback: a cluster that turns out to be
	# fully occupied must not leave a picture with nothing built in it.
	near.append_array(legal.slice(mini(9, legal.size())))
	return near


## Lays a trap and **returns the tile it went on**, for the same reason.
func _place_trap() -> Vector2:
	var field: Battlefield = run.battlefield
	# The trap varies for the same reason the towers do.
	var kinds: Array[TrapData] = []
	for id: Variant in ContentDB.traps:
		var candidate: TrapData = ContentDB.traps[id] as TrapData
		if candidate != null:
			kinds.append(candidate)
	kinds.sort_custom(func(a: TrapData, b: TrapData) -> bool: return a.id < b.id)
	var data: TrapData = null
	if not kinds.is_empty():
		var pick := RandomNumberGenerator.new()
		pick.seed = hash("guide-trap-kind:%d" % _towers_built)
		data = kinds[pick.randi_range(0, kinds.size() - 1)]
	if data == null:
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guide-trap:%d" % _towers_built)
	_towers_built += 1
	for tile: Vector2i in _open_anchors(rng):
		if field.try_place_trap(tile, data).is_empty():
			return BattleGrid.tile_to_world(tile)
	return Vector2.ZERO


func _stand_at(at: Vector2) -> void:
	var hero: Hero = run.battlefield.hero
	if hero != null:
		hero.global_position = at


## **The camera, actually moved.**
##
## `zoom_level` is an `@export` the rig reads once in `_ready`, so setting it
## from here after the scene is up did nothing whatsoever - every "zoomed"
## picture this tool has taken since it was written was at the authored framing.
## `_wanted_zoom` is what the wheel moves and what `_process` eases toward.
##
## Clamped to the band the rig itself enforces on a player, because a Guide
## picture framed closer than the game will ever allow is a promise it does not
## keep. `0.0` means the authored default.
func _zoom(level: float) -> void:
	var cam: Node = run.battlefield.camera
	if cam == null:
		return
	var wanted: float = Balance.CAMERA_ZOOM if level <= 0.0 else level
	cam.set("_wanted_zoom", clampf(wanted,
		Balance.CAMERA_ZOOM_BATTLEFIELD_MIN, Balance.CAMERA_ZOOM_BATTLEFIELD_MAX))


## A wild crop on the outskirts, or the first plot, or somewhere off the road.
func _wild_crop() -> Vector2:
	var farm: Farming = run.battlefield.farming()
	if farm != null:
		for index: int in farm.plot_count():
			if bool(farm.plot_state(index)["wild"]):
				return farm.plot_state(index)["at"]
		if farm.plot_count() > 0:
			return farm.plot_state(0)["at"]
	return Vector2(-900.0, 900.0)


## **Dry ground beside the water**, close enough to cast from.
##
## Offsetting a fixed distance from the middle was right while a pond was a
## circle and wrong the moment ponds became blobs on a lattice: the hero stood in
## the lake and the game told them so, in the photograph, in the section about
## fishing. The field already answers how deep the water is anywhere, so the
## shore is *searched for* - the first dry step out of the middle, whatever shape
## this pond happens to be.
## **How much dry ground has to be under and around the angler**, so the picture
## reads as a bank rather than as somebody standing on the waterline.
const SHORE_CLEAR: float = 92.0

## The throw this tool aims for: far enough that the line is plainly a cast,
## inside `FISHING_CAST_MAX` with room to spare.
const CAST_IDEAL: float = 250.0


## **A place to cast from**: clear dry ground, a throw away from the water.
##
## Both halves are the owner's (2026-09-16) - "well outside the pond's waters"
## and "casting the line into the center". Searched rather than offset, because a
## pond is a blob of Wang tiles and every one is a different shape and, since
## sizes vary, a different size: the same offset that is a bank on one is the
## middle of another.
##
## **Measured to the water, not to the pond's middle.** The first cut asked for
## ground a castable distance from the *centre*, which on a thirteen-tile pond is
## underwater - so the search found nothing, fell back, and left the Warden out
## of range charging a throw that could never leave.
func _pond_bank(centre: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_error: float = INF
	for step: int in range(2, 46):
		var out: float = float(step) * 20.0
		for slice: int in 24:
			var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * float(slice) / 24.0) * out
			if not _dry_all_round(at, SHORE_CLEAR):
				continue
			var swim: float = _reach_to_water(at, centre)
			if swim >= INF or swim > Balance.FISHING_CAST_MAX * 0.8:
				continue
			var error: float = absf(swim - CAST_IDEAL * 0.45)
			if error < best_error:
				best_error = error
				best = at
	if best_error < INF:
		return best
	for step: int in range(2, 46):
		var out: float = float(step) * 20.0
		for slice: int in 16:
			var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * float(slice) / 16.0) * out
			if _dry_all_round(at, 34.0) and _reach_to_water(at, centre) < INF:
				return at
	return centre + Vector2(0.0, 160.0)


## How far the first water is, walking from `at` toward `towards`. `INF` when the
## line reaches the far side without finding any.
func _reach_to_water(at: Vector2, towards: Vector2) -> float:
	var field: Battlefield = run.battlefield
	var heading: Vector2 = (towards - at).normalized()
	var span: float = at.distance_to(towards) + 64.0
	var walked: float = 16.0
	while walked < span:
		if field.water_depth_at(at + heading * walked) > 0.05:
			return walked
		walked += 16.0
	return INF


## Dry underfoot **and** dry for `reach` in every direction.
##
## A single sample lands on the waterline as often as on the bank, and a hero
## whose feet are in the shallows is told to get out of the water - which is what
## the fishing and reel pictures were photographs of. At `SHORE_CLEAR` it also
## means there is visible shore between the Warden and the water, which is the
## half of that the owner asked for the second time.
func _dry_all_round(at: Vector2, reach: float) -> bool:
	var field: Battlefield = run.battlefield
	if field.water_depth_at(at) > 0.0:
		return false
	for slice: int in 12:
		var heading: Vector2 = Vector2.RIGHT.rotated(TAU * float(slice) / 12.0)
		if field.water_depth_at(at + heading * reach) > 0.0:
			return false
	return true


## **The water the line lands in**: as far toward the middle as a cast will
## carry, which on a small pond is the middle and on a large one is as deep as
## the line goes.
##
## A float that lands on dry ground is a *miss* - `Fishing._touch_down` says so -
## and one aimed past `FISHING_CAST_MAX` never leaves the hand at all.
func _pond_aim(centre: Vector2, bank: Vector2) -> Vector2:
	var field: Battlefield = run.battlefield
	var heading: Vector2 = (centre - bank).normalized()
	var ceiling: float = minf(bank.distance_to(centre), Balance.FISHING_CAST_MAX * 0.86)
	var best: Vector2 = centre
	var found: bool = false
	var walked: float = 24.0
	while walked <= ceiling:
		var at: Vector2 = bank + heading * walked
		if field.water_depth_at(at) > 0.05:
			best = at
			found = true
		walked += 14.0
	return best if found else centre


func _pond_centre() -> Vector2:
	var ponds: Variant = run.battlefield.get("_ponds")
	if ponds != null and ponds.has_method("pond_positions"):
		var spots: PackedVector2Array = ponds.pond_positions()
		if not spots.is_empty():
			return spots[0]
	return Vector2(900.0, 900.0)


func _camp_centre() -> Vector2:
	var camps: Camps = run.battlefield.camps()
	if camps != null:
		var sites: Variant = camps.get("_sites")
		if sites is Array and not (sites as Array).is_empty():
			return (sites as Array)[0].get("centre", Vector2.ZERO)
	return Vector2(0.0, -1600.0)


func _barrier_at() -> Vector2:
	var grid: BattleGrid = run.battlefield.grid
	if grid != null and not grid.barriers.is_empty():
		var pair: Array = grid.barriers[0]
		if not pair.is_empty():
			return (pair[0] as Dictionary).get("at", Vector2.ZERO) + Vector2(0.0, 80.0)
	return Vector2(0.0, -1900.0)


func _bond_a_spirit() -> void:
	var key: String = SpiritBond.key("fox", 0, false)
	if not ContentDB.wildlife_kinds.has("fox"):
		for id: Variant in ContentDB.wildlife_kinds:
			key = SpiritBond.key(String(id), 0, false)
			break
	MetaState.spirit_bonded[key] = true
	MetaState.equip_spirit(key)


## A clutch on the ground beside the hero, for the nesting picture.
##
## Laid through `WildlifeNests.lay` - the same door the ecology lays one through
## - rather than by dropping a sprite, so what is photographed is a real nest
## with a real clutch in it and not a prop that looks like one.
func _lay_a_nest() -> Vector2:
	var nests: WildlifeNests = run.battlefield.nests()
	var hero: Hero = run.battlefield.hero
	if nests == null or hero == null:
		return Vector2.ZERO
	var layer: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and kind.lays_eggs:
			layer = kind
			break
	if layer == null:
		print("[guide-shots] warning: no laying species to leave a clutch")
		return Vector2.ZERO
	var clutch: Array[Dictionary] = []
	for _egg: int in 3:
		clutch.append({"stage": WildlifeFamilies.Stage.BABY,
			"rarity": int(layer.rarity), "shiny": false})
	var at: Vector2 = hero.global_position + Vector2(60.0, 30.0)
	nests.lay(layer, at, clutch, 0)
	return at


## **Somebody beside you, and hurt**, for the picture about sharing a catch.
##
## The stash only offers "Share" when there is a wounded player within
## `FISH_SHARE_RANGE` - a button that always refuses teaches nothing - so the
## section about handing a fish over was illustrated by a pantry with no way to
## hand anything over. Stood through `CoopHeroes.spawn_partner`, which with no
## session builds the ordinary second hero, rather than by faking a body.
func _stand_a_hurt_partner() -> void:
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero
	var crew: CoopHeroes = field.get("_coop_heroes") as CoopHeroes
	if crew == null or hero == null:
		return
	var mate: Hero = crew.spawn_partner()
	if mate == null or not is_instance_valid(mate):
		return
	mate.global_position = hero.global_position + Vector2(-72.0, 14.0)
	if mate.health != null:
		mate.health.take_damage(mate.health.max_hp * 0.55, mate.global_position)
	# A second Warden standing about in every later picture is the same fault the
	# boss had; see `_stage`.
	_stage(mate)


## The anchor of a tower that is actually standing, or a tile nothing is on.
func _a_built_tower() -> Vector2i:
	for key: Variant in RunState.towers:
		return key as Vector2i
	return Vector2i(-999, -999)


## Buys a tower up the ladder as far as the purse and the Forge allow.
##
## Through `try_upgrade`, so the Forge's bands and the path choice at level five
## are the real ones - a tower whose level was assigned would show a path sheet
## the game would never have offered.
func _raise_a_tower(anchor: Vector2i, to_level: int) -> void:
	for _step: int in to_level:
		RunState.gain_every_currency(6000)
		if not run.battlefield.try_upgrade(anchor).is_empty():
			return


## A tree or a seam on the outskirts, for the gathering picture.
func _a_gather_node() -> Vector2:
	var nodes: Gathering = run.battlefield.gathering()
	if nodes == null:
		return Vector2.ZERO
	var dug: Array = nodes.get("_nodes") as Array
	if dug == null or dug.is_empty():
		# Said out loud: a picture of the crafts with no seam in it is the fault
		# this whole pass is about, and silence is how it shipped the first time.
		print("[guide-shots] warning: no gather nodes on the field to photograph")
		return Vector2.ZERO
	# **The one furthest from any edge of the map**, not the first one dug and not
	# the one nearest the middle either. Seams sit on the outskirts by design, so
	# "nearest the centre" still picks one against the western border and a third
	# of that photograph is the black beyond the edge of the world. What the
	# frame wants is clearance on every side, which is a different measurement.
	var best := Vector2.ZERO
	var roomiest: float = -INF
	for entry: Dictionary in dug:
		var at: Vector2 = entry.get("at", Vector2.ZERO) as Vector2
		var room: float = minf(BattleGrid.HALF_EXTENT - absf(at.x),
			BattleGrid.HALF_EXTENT - absf(at.y))
		if room > roomiest:
			roomiest = room
			best = at
	print("[guide-shots] gather nodes: %d, framing the one at %s (%.0f from the edge)"
		% [dug.size(), str(best), roomiest])
	return best


## The Mansion, on one of its three pages.
##
## `open` resets the page whenever the plot changes, so the page is set after it
## and the sheet redrawn - setting it first would be overwritten in silence.
func _open_mansion(page: int, tree_filter: int = -1) -> void:
	_park_clear()
	RunState.building_tiers["sanctum"] = maxi(RunState.building_tier("sanctum"), 2)
	RunState.hero_skill_points = maxi(RunState.hero_skill_points, 3)
	RunState.hero_attribute_points = maxi(RunState.hero_attribute_points, 2)
	run.switch_scope(GameDirector.Scope.TOWN)
	var sheet: TownPanel = run.town_panel
	if sheet == null:
		return
	sheet.open("sanctum")
	sheet.set("_mansion_page", page)
	sheet.set("_tree_filter", tree_filter)
	sheet.call("_refresh")


## A bow in hand, arrows in the quiver, and one of them in the air.
##
## Split in two because a shot lives about a third of a second: the bow is put
## in the hero's hands with everything else, and the arrow is loosed six frames
## before the shutter through `just_before`.
func _arm_the_bow() -> void:
	for id: Variant in ContentDB.ranged_weapons:
		RunState.ranged_id = String(id)
		break
	for id: Variant in ContentDB.ammo_kinds:
		RunState.gain_ammo(String(id), 40)
	var hero: Hero = run.battlefield.hero
	if hero != null and hero.ranged != null:
		RunState.ammo_id = ""
		hero.ranged.cycle_ammo()
	_zoom(1.5)


func _loose_an_arrow() -> void:
	var hero: Hero = run.battlefield.hero
	if hero == null or hero.ranged == null:
		return
	var aim := Vector2.RIGHT
	var quarry: Enemy = _nearest_body(hero.global_position)
	if quarry != null:
		aim = (quarry.global_position - hero.global_position).normalized()
	hero.ranged.request(aim, hero.global_position)


## The nearest body on the road, for something to aim at.
func _nearest_body(from: Vector2) -> Enemy:
	var best: Enemy = null
	var best_distance: float = 1.0e9
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		var distance: float = body.global_position.distance_to(from)
		if distance < best_distance:
			best_distance = distance
			best = body
	return best


## **Every shooter on the road looses at once**, for the picture about what the
## ranged breeds throw. Called six frames before the shutter for the same reason
## the arrow is: a thrown thing does not wait.
func _make_the_shooters_fire() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if body.data.shot == null:
			continue
		body.call("_loose_a_shot", body.data.contact_damage)


## Something for the Quartermaster to mend.
##
## The Orders button is disabled while there is nothing its cheapest order would
## do, so a picture of the Quartermaster taken on an unmarked road is a picture
## of a greyed button.
func _hurt_the_defences() -> void:
	var field: Battlefield = run.battlefield
	if field.town != null and field.town.health != null:
		field.town.health.take_damage(field.town.health.max_hp * 0.35,
			field.town.global_position)
	for key: Variant in RunState.towers:
		var tower: Tower = field.tower_at_anchor(key as Vector2i)
		if tower != null:
			# Through `hurt`, which is the one door a tower is damaged by: its
			# pool is private and everything else in the game asks this.
			tower.hurt(tower.data.max_hp * 0.4, tower.global_position)
	RunState.gain_every_currency(6000)


## **A picture of a thing standing on the field.**
##
## Stand a little off it, look at it, and look at it *again* six frames before
## the shutter: `Hero.face`'s hold lapses, and `_look_at` computes the camera's
## lean from where the rig has eased to - so aiming once in the setup is aiming
## from the wrong place seventy frames later.
func _subject_shot(id: String, at: Vector2, offset: Vector2, zoom: float) -> void:
	await _shot(id, func() -> void:
		_stand_at(at + offset)
		_zoom(zoom)
		_look_at(at),
		func() -> void: _look_at(at))
	_zoom(0.0)


## The same, for a subject that does not exist until the picture makes it - a
## tower to build, a trap to lay, a nest to leave, an animal to send.
##
## `make` returns where the thing ended up, which is why every one of those
## helpers now returns a position instead of standing the hero somewhere and
## forgetting where.
func _made_subject_shot(id: String, make: Callable, offset: Vector2, zoom: float) -> void:
	var at: Array[Vector2] = [Vector2.ZERO]
	await _shot(id, func() -> void:
		at[0] = make.call() as Vector2
		_stand_at(at[0] + offset)
		_zoom(zoom)
		_look_at(at[0]),
		func() -> void: _look_at(at[0]))
	_zoom(0.0)


## **Somewhere a player would actually be standing, looking where they would
## actually be looking.**
##
## The hero starts on the town square, so every picture with no subject of its
## own was taken there - the same spot several times over, and not a spot anybody
## defends from. This puts the Warden out on one of the four roads, a third to
## two thirds of the way to the gate, facing the way the road comes in.
##
## **Which road, how far along and the step either side are seeded by the
## picture's own name**, so the set has the variety of somebody playing rather
## than one pose repeated - and seeded rather than randomised, so the same run
## produces the same set twice. Returns what the Warden is looking at, so a
## caller with something better in mind can override it.
func _apt_post(tag: String) -> Vector2:
	var field: Battlefield = run.battlefield
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guide-post:" + tag)
	var route: PackedVector2Array = field.lane_path(rng.randi_range(0, Balance.LANE_COUNT - 1))
	if route.size() < 3:
		return Vector2.ZERO
	# `lane_path` runs from the spawn to the town, so a lower index is further
	# out - which is the way anything arrives from and the way to be looking.
	var at: int = clampi(int(round(float(route.size() - 1) * rng.randf_range(0.34, 0.66))),
		1, route.size() - 2)
	var here: Vector2 = route[at]
	var outward: Vector2 = (route[at - 1] - here).normalized()
	_stand_at(here + Vector2(rng.randf_range(-44.0, 44.0), rng.randf_range(-34.0, 34.0)))
	var look: Vector2 = here + outward * 340.0
	_look_at(look)
	return look


## The same, but **where the fighting is**.
##
## A wave picture with no bodies in it is a picture of an empty road, and a
## seeded verge is empty four times in five - the wave is on one lane and the
## Warden was standing on another. This puts them a short walk off the middle of
## whatever has arrived, looking at it; which side they stand on is seeded, so
## the set still varies. It falls back to a road post only when nothing is out.
func _apt_combat_post(tag: String) -> void:
	var hero: Hero = run.battlefield.hero
	if hero == null:
		return
	var busy: Vector2 = _where_the_wave_is()
	if busy.x >= INF:
		_look_at(_apt_post(tag))
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("guide-combat:" + tag)
	_stand_at(busy + Vector2.RIGHT.rotated(rng.randf() * TAU) * rng.randf_range(160.0, 230.0))
	_look_at(busy)


## **Waits until there is actually a wave on the road.**
##
## Riding on starts the clock rather than the wave, and the first bodies then
## have to walk in from the spawn - so a fixed three hundred frames was a guess,
## and it was the wrong one: the wave picture had **no enemies in it at all**,
## which is the one thing the section is about. It waits for bodies to arrive and
## nudges the director once if the road stays empty, rather than counting frames
## and hoping.
func _let_a_wave_arrive() -> void:
	var director: WaveDirector = run.battlefield.wave_director
	for frame: int in 1200:
		if _where_the_wave_is().x < INF:
			# A moment more, so the front of it is properly on screen rather than
			# a single body one step off the spawn.
			for _f: int in 90:
				await get_tree().process_frame
			return
		# **Asked again until it takes.** `Run._on_ride_on_requested` spends a
		# *breather* when one is open and returns without starting anything, so a
		# single call left the run sitting in Preparation - measured: phase=0,
		# prep=true, the director not deploying, and the wave picture with no
		# bodies in it at all. Asked once every half second until the phase
		# actually leaves Preparation, which is what a player pressing the button
		# would do.
		if RunState.is_preparation() and frame % 30 == 0:
			run.call("_on_ride_on_requested")
		await get_tree().process_frame
	print("[guide-shots] warning: no wave arrived to photograph (phase %d, prep %s)"
		% [RunState.phase, str(RunState.is_preparation())])


## The middle of what is on the road, or `INF` if nothing is.
##
## Camp bodies are skipped: they stand in their own clearing on the outskirts and
## never take a route, so averaging them in drags the frame off the wave and out
## into the trees - the same shape as camp lords drifting the road's own purse.
func _where_the_wave_is() -> Vector2:
	var total := Vector2.ZERO
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body == null or not is_instance_valid(body) or body.is_queued_for_deletion():
			continue
		if body.is_in_group(Enemy.CAMP_GROUP):
			continue
		total += body.global_position
		count += 1
	if count == 0:
		return Vector2.ONE * INF
	return total / float(count)


## **Neutral framing**: the cursor on the Warden, so the rig's lean is zero.
##
## The default for any battlefield picture that has no particular subject. A
## picture that *has* one moves the cursor onto it afterwards, which is what the
## lean is for.
## What each system that shares `EventBus.interact_prompt` currently believes it
## is showing. Five of them emit on that one signal and each caches its own last
## value, so a system that clears can wipe another's live prompt and never
## re-assert it - measured rather than assumed.
func _report_prompt(tag: String) -> void:
	var parts: PackedStringArray = []
	for pair: Array in [
			["gather", run.battlefield.gathering()],
			["farm", run.battlefield.farming()],
			["gates", run.battlefield.rift_gates()],
			["pond", run.battlefield.ponds()]] as Array[Array]:
		var owner: Object = pair[1] as Object
		if owner == null:
			continue
		parts.append("%s=%s" % [String(pair[0]), String(owner.get("_prompt"))])
	print("[guide-shots] prompt(%s): %s" % [tag, ", ".join(parts)])


func _park_on_hero() -> void:
	var hero: Hero = run.battlefield.hero if run.battlefield != null else null
	if hero != null:
		_look_at(hero.global_position)


## **Clear of every control**, for a picture of a screen.
##
## The cursor moves no camera over a menu, but whatever sits under it wears its
## hover state - so a photograph of the Ledger came out with one of its buttons
## looking pressed by nobody. The dark left margin is outside every panel this
## game centres.
func _park_clear() -> void:
	var view: Vector2 = get_viewport().get_visible_rect().size
	Input.warp_mouse(Vector2(view.x * 0.02, view.y * 0.5))


## The funnel being driven through a blaze, held by **id**: a `Tornado` dies on
## its own clock, and casting a freed object is an error in itself - raised
## before `is_instance_valid` could ever run.
var _the_whirl: int = 0
## Where the dry strike is thrown, and how many fires the sky had lit before it.
const _DRY_STRIKE := Vector2(170.0, -70.0)
var _dry_fires: int = 0
var _dry_at: Vector2 = Vector2.INF
## Where the wildfire picture's blaze was lit.
var _wildfire_at: Vector2 = Vector2.INF
## The falling stone, held by id, and where it is coming down.
var _the_stone: int = 0
var _meteor_at: Vector2 = Vector2.INF


## **The nearest thing that will actually burn.**
##
## Fire needs fuel and the Warden is posted on a road, so a point taken as an
## offset from the hero is bare dirt about as often as not. This asks the foliage
## itself, which is the same list `Wildfire.ignite_near` draws from, so a point it
## returns is a point that catches.
func _brush_near(want: Vector2, reach: float) -> Vector2:
	var leaves: Foliage = run.battlefield.foliage_node()
	if leaves == null:
		return Vector2.INF
	var stand: Array[Dictionary] = leaves.plants_near(want, reach)
	if stand.is_empty():
		return Vector2.INF
	var best: Vector2 = Vector2.INF
	var nearest: float = INF
	for plant: Dictionary in stand:
		var here: Vector2 = plant["at"]
		var away: float = here.distance_to(want)
		if away < nearest:
			nearest = away
			best = here
	return best


func _the_funnel() -> Tornado:
	if _the_whirl == 0:
		return null
	var held: Variant = instance_from_id(_the_whirl)
	if held == null or not is_instance_valid(held as Object):
		return null
	return held as Tornado


## **A funnel driven through a blaze**, which is what a fire whirl is: `Tornado`
## picks the fire up when there is heat within `TORNADO_AOE` of it and carries it
## for `TORNADO_FIRE_SECONDS`, lighting what it passes.
##
## The blaze is lit where the funnel will cross rather than by `start_wildfire`,
## which picks its own point somewhere on the field - a fire behind the camera is
## a fire the picture cannot show. `ignite_near` lights the nearest unburnt plant
## within its radius, so this widens the search until it finds one.
func _drive_a_fire_whirl() -> void:
	var sky: WeatherSky = run.battlefield.sky()
	var hero: Hero = run.battlefield.hero
	var fire: Wildfire = run.battlefield.wildfire()
	if sky == null or hero == null or fire == null:
		return
	var blaze: Vector2 = _brush_near(hero.global_position + Vector2(-280.0, 0.0), 560.0)
	if not blaze.is_finite():
		return
	# A stand rather than a plant: one burning fern is a spark, and `heat_at`
	# has to read over `TORNADO_AOE` for the funnel to pick anything up.
	for near: Dictionary in run.battlefield.foliage_node().plants_near(blaze, 190.0):
		fire.ignite_near(near["at"], 30.0, 1.0)
	# **Aimed through the blaze**, from beyond it, ending short of the Warden -
	# so the funnel crosses the fire in frame instead of walking past it.
	var along: Vector2 = (blaze - hero.global_position).normalized()
	var funnel: Tornado = sky.spawn_tornado(blaze + along * 720.0, blaze - along * 200.0)
	if funnel != null:
		_the_whirl = funnel.get_instance_id()


## **A strike with no rain behind it, under a heatwave.**
##
## `_dry_lightning` refuses on wet ground and then *rolls* `LIGHTNING_IGNITE_CHANCE`,
## so one strike is a coin toss and a picture that rolls is not a picture. This
## asks until it takes, the way `_let_a_wave_arrive` does - the sky's own
## `wildfires` count is the answer, and `until` watches it.
func _drive_dry_lightning() -> void:
	var sky: WeatherSky = run.battlefield.sky()
	var hero: Hero = run.battlefield.hero
	if sky == null or hero == null:
		return
	EventBus.weather_changed.emit("heatwave")
	RunState.rain_intensity = 0.0
	sky.set("_rain", 0.0)
	_dry_fires = sky.wildfires
	# **At the brush, not at an offset.** `_dry_lightning` lights the nearest
	# unburnt plant within `LIGHTNING_RADIUS`, and a Warden posted on a road has
	# none - the first cut struck bare dirt forty times and lit nothing.
	_dry_at = _brush_near(hero.global_position + _DRY_STRIKE, 560.0)
	if not _dry_at.is_finite():
		_dry_at = hero.global_position + _DRY_STRIKE
	# The ground has to be tinder for the rule to apply at all, and a heatwave
	# is what bakes it - given directly here rather than waited out over the
	# minutes of road the climate would take to dry on its own.
	var ground: Climate = run.battlefield.climate()
	if ground != null:
		ground.add_heat(_dry_at, 300.0, Balance.LIGHTNING_RADIUS * 3.0)
		ground.add_wet(_dry_at, -0.25, Balance.LIGHTNING_RADIUS * 3.0)
	for _ask: int in 40:
		if sky.wildfires > _dry_fires:
			break
		sky.strike_at(_dry_at + Vector2(randf_range(-70.0, 70.0), randf_range(-50.0, 50.0)))


## **A clear day again** (owner, 2026-09-16: "weather effects ie Flood etc must be
## removed when moving on to screenshots unrelated").
##
## The eleven weather and wrath pictures each drive a *standing state* - a
## downpour, a knee-deep flood, a blaze, a funnel - rather than putting a node on
## the field, so `_stage` has nothing to free. They are put back through the
## systems' own fields instead of by rebuilding the scope, because a rebuild
## would re-roll every pond, seam and animal and make each picture a different
## world, which is the opposite of what a Guide wants.
func _clear_the_sky() -> void:
	var field: Battlefield = run.battlefield
	if field == null:
		return
	RunState.flood = 0.0
	_hush()
	var sky: WeatherSky = field.sky()
	if sky != null:
		# Every strike still in the air (owner, 2026-09-16: "lightning strike
		# never got removed after its screenshots got taken").
		sky.clear_bolts()
		sky.set("_flood", 0.0)
		sky.set("_charge", 0.0)
		sky.set("_quake_warning_left", 0.0)
		sky.set("_quake_pending", -1.0)
		sky.set("_pending_tornado", {})
		EventBus.weather_changed.emit("clear")
	# **The funnels and the falling stones are children of the *field*.**
	# `spawn_tornado` and `drop_meteor` both end in `field.add_child`, so the
	# first cut of this walked the sky's children, found none, and left every
	# funnel standing in the pictures that followed (owner, 2026-09-16).
	for born: Node in field.get_children():
		if born is Tornado or born is Meteor:
			born.queue_free()
	for funnel: Node in get_tree().get_nodes_in_group(Tornado.GROUP):
		funnel.queue_free()
	# **The blaze, put out through its own door.** A flood left standing soaks
	# the ground and a soaked field will not take a fire, so without this the
	# wildfire picture is a photograph of wet grass - which is the owner's "flood
	# preventing wildfire".
	var fire: Wildfire = field.get("_wildfire") as Wildfire
	if fire != null and is_instance_valid(fire):
		fire.call("_clear")
	var charged: WrathZones = field.zones()
	if charged != null:
		charged.clear()
	# And the ground's own heat and wet, which a heatwave or a flood leaves
	# behind and which the next picture would otherwise be taken through.
	var ground: Climate = field.climate()
	if ground != null:
		ground.reset()


## **The card in the middle of the screen, taken down.**
##
## A storm core announces itself and every strike opens one, so a bolt thrown six
## frames before the shutter puts "STORM CORE" across the picture it is the
## subject of. The banner is a real thing the game says and it belongs in the
## charged-ground picture; everywhere else it is somebody else's subject.
func _hush() -> void:
	var hud: HUD = run.hud if run != null else null
	if hud == null:
		return
	var card: Variant = hud.get("_region_card")
	if card != null and is_instance_valid(card as Object):
		(card as CanvasItem).visible = false
	var tween: Variant = hud.get("_region_tween")
	if tween != null and (tween as Tween).is_valid():
		(tween as Tween).kill()


## **The Warden looks at the subject, and so does the camera.**
##
## Owner, 2026-09-16: "have the player aim towards whatever it is focusing on for
## each screenshot". Two separate things answer to that and only one of them is
## the sprite.
##
## `CameraRig` adds `CAMERA_MOUSE_LEAN` of the distance to the **mouse** - capped
## at `CAMERA_MOUSE_LEAN_MAX` - to where it wants to be. There is no player here,
## so that lean was toward wherever the desktop cursor was left: an arbitrary
## shove of up to 57 units, different on every run and every machine, in every
## picture this tool has taken. Warping the cursor onto the subject makes it
## deliberate - the frame leans toward the thing the section is about.
func _look_at(at: Vector2) -> void:
	var hero: Hero = run.battlefield.hero
	if hero == null:
		return
	var toward: Vector2 = at - hero.global_position
	if toward.length() > 1.0:
		hero.face(toward.normalized())
	var cam: Camera2D = run.battlefield.camera as Camera2D
	if cam == null:
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var on_screen: Vector2 = (at - cam.get_screen_center_position()) * cam.zoom + view * 0.5
	# Only if it lands on the window: warping the cursor off-screen would leave
	# the lean pointing at a place the camera can never reach.
	if Rect2(Vector2.ZERO, view).has_point(on_screen):
		Input.warp_mouse(on_screen)


## **Beside the boss, with the whole of it in frame, looking at it.**
##
## Measured rather than assumed. The act bosses draw 384x384 at scale 2.2 - 844
## world units - and the sprite's centre sits **363 units above** the body's own
## position, so a camera level with the boss's feet needs 815 units of headroom
## above it. The first three cuts guessed and clipped its head off every time.
##
## **The hero is what gets placed, not the camera**: the rig eases toward the
## hero every frame, so a camera snapped anywhere else drifts back before the
## shutter opens. The zoom is solved from the measurement so a boss authored at
## another scale still fits, and it is clamped to the band a player can reach.
##
## The arrival card comes down and the health bar stays: the bar is what a boss
## fight looks like, the card is what the second before one looks like.
func _face_the_boss() -> void:
	var standing: Variant = run.boss_director.get("_active") if run.boss_director != null else null
	if standing == null or not is_instance_valid(standing):
		return
	var boss := standing as Node2D
	var hero: Hero = run.battlefield.hero
	if boss == null or hero == null:
		return

	var art: Sprite2D = null
	for node: Node in _walk(boss):
		var sprite := node as Sprite2D
		if sprite != null and sprite.texture != null:
			art = sprite
			break
	var middle: Vector2 = art.global_position if art != null else boss.global_position
	var half: float = art.texture.get_height() * absf(art.global_scale.y) * 0.5 \
		if art != null else 200.0

	# **Level with the mount's flank, not below its feet.** The rig centres on the
	# hero, so a Warden standing under the boss spends the whole bottom half of
	# the frame on empty ground to buy headroom for its head. Measured: the art
	# runs from 785 above the body's position to 59 below it, so standing level
	# with its middle halves the headroom and the animal fills the picture.
	hero.global_position = boss.global_position + Vector2(-320.0, -260.0)

	# Wide enough that the whole animal fits above the Warden, with a margin.
	var headroom: float = absf(hero.global_position.y - (middle.y - half)) + 110.0
	var view: Vector2 = get_viewport().get_visible_rect().size
	_zoom(view.y * 0.5 / maxf(headroom, 1.0))

	var cam: Node2D = run.battlefield.camera as Node2D
	if cam != null:
		cam.global_position = hero.global_position
	_look_at(middle)

	var hud: HUD = run.hud
	if hud != null:
		var card: Control = hud.get("_region_card") as Control
		if card != null:
			var fade: Tween = hud.get("_region_tween") as Tween
			if fade != null and fade.is_valid():
				fade.kill()
			card.visible = false
		var line: Label = hud.get("_message") as Label
		if line != null:
			line.text = ""
		hud.set("_message_left", 0.0)


## **What is actually painting the frame**, printed rather than guessed at.
##
## Three passes were spent on a boss picture that came out a dark brown
## rectangle - blamed on the fog, then on a once-ever cinematic, and it was
## neither. One print said it in one line: `dark=1.00 tint=(0.3,0.31,0.4)` is
## `DayNight`'s deep tint, so the road was underground, so a rift had never come
## back up. This project's own recurring lesson is that a model of a thing is not
## the thing - so the tool says what it is photographing through.
##
## Only full-screen veils are listed. Everything else on a battlefield is a
## rectangle of some kind, and a list of nine hundred of them says nothing.
func _report_light(tag: String) -> void:
	var tint: CanvasModulate = run.battlefield.get("_day_tint_node") as CanvasModulate
	var view: Vector2 = get_viewport().get_visible_rect().size
	var veils: PackedStringArray = []
	for layer: Node in [Vfx, run, run.battlefield] as Array[Node]:
		for node: Node in _walk(layer):
			var rect := node as ColorRect
			if rect == null or not rect.visible or rect.color.a <= 0.02:
				continue
			if rect.size.x < view.x * 0.9 or rect.size.y < view.y * 0.9:
				continue
			veils.append("%s a=%.2f" % [rect.name, rect.color.a])
	print("[guide-shots] light(%s): dark=%.2f tint=%s canvas=%s under=%s frozen=%s veils=[%s]"
		% [tag, DayNight.darkness, str(DayNight.tint),
			str(tint.color) if tint != null else "none", str(DayNight.underground),
			str(run.battlefield.is_suspended()), ", ".join(veils)])


## A species that has had enough of being hunted, for the picture about it.
## **A savage put beside the Warden, not on the horizon.**
##
## `_send_a_savage` places one at the edge of the field and sets it hunting,
## which is right for the game and useless for a photograph - by the time the
## shutter opens it is still a speck several screens away. It is moved onto the
## Warden's own ground afterwards, which is the state the section is about:
## something has had enough of being hunted and has found you.
func _send_a_hunter() -> Vector2:
	var animals: Wildlife = run.battlefield.get("_wildlife") as Wildlife
	var hero: Hero = run.battlefield.hero
	if animals == null or hero == null:
		return Vector2.ZERO
	# An animal is a record in `_living` carrying its own sprite - there is no
	# node group to search, which is why the roster is read rather than the tree.
	var living: Array = animals.get("_living") as Array
	var before: int = living.size() if living != null else 0
	# **Something that reads as a threat.** The first species in the roster is
	# whatever happens to sort first - the picture came out with a Warden being
	# menaced by a squirrel. A predator with real damage is what the section is
	# about, and it is chosen by what the species *declares* rather than by id.
	var hunter: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null or kind.mythic:
			continue
		if kind.temperament != WildlifeData.Temperament.PREDATORY:
			continue
		if hunter == null or kind.damage > hunter.damage:
			hunter = kind
	if hunter == null:
		for kind: WildlifeData in ContentDB.wildlife():
			if kind != null and not kind.mythic:
				hunter = kind
				break
	if hunter != null:
		print("[guide-shots] hunted: %s" % hunter.id)
		animals.call("_send_a_savage", hunter)
	living = animals.get("_living") as Array
	if living == null or living.size() <= before:
		print("[guide-shots] warning: no savage arrived to photograph")
		return hero.global_position
	var at: Vector2 = hero.global_position + Vector2(150.0, -40.0)
	var beast := (living[living.size() - 1] as Dictionary).get("sprite") as Node2D
	if beast != null and is_instance_valid(beast):
		beast.global_position = at
	# **Retired through the system that owns it**, not by freeing its sprite.
	#
	# An animal is a *record* in `Wildlife._living` that happens to carry a
	# sprite; freeing the sprite behind the system's back leaves the record
	# pointing at a dead node, and every tick afterwards casts it - `threat_to`,
	# `_quarry_for`, `_steered_direction` and `_retire` itself all errored on the
	# savage for the rest of the run. `_retire` is the door that takes both away.
	var index: int = living.size() - 1
	_stage_undo(func() -> void:
		var roster: Array = animals.get("_living") as Array
		if roster != null and index >= 0 and index < roster.size():
			animals.call("_retire", index))
	return at


func _stock_the_stash() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _piece: int in 12:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 1, rng)
		if not piece.is_empty():
			MetaState.receive_gear(piece)
	for id: Variant in ContentDB.fish_kinds:
		MetaState.fish[String(id)] = 2


func _pick_tab(screen: Node, title: String) -> void:
	_park_clear()
	for node: Node in _walk(screen):
		if node is TabContainer:
			var tabs := node as TabContainer
			for index: int in tabs.get_tab_count():
				if tabs.get_tab_title(index).begins_with(title):
					tabs.current_tab = index
					return
		elif node is Button and (node as Button).text.begins_with(title):
			(node as Button).pressed.emit()
			return


func _open_settings(tab: String) -> void:
	_park_clear()
	var layer := CanvasLayer.new()
	layer.name = "SettingsShot"
	add_child(layer)
	var panel := SettingsPanel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	panel.position = (Vector2(get_window().size) - panel.size) * 0.5
	_pick_tab(panel, tab)
	panel.position = (Vector2(get_window().size) - panel.size) * 0.5


func _open_coop() -> void:
	_park_clear()
	for node: Node in get_children():
		if node.name == "SettingsShot":
			node.queue_free()
	var scene: Resource = load("res://scenes/ui/coop_screen.gd")
	if scene == null:
		return
	var screen: Node = (scene as GDScript).new()
	screen.name = "CoopShot"
	add_child(screen)
	if screen.has_method("open"):
		screen.call("open")


## **Stands one screen up on its own and photographs it.**
##
## Written because a great many Guide pictures were `_copy`s of a handful of base
## shots - `gear`, `trading` and `forge` were all the same photograph of the
## stash, and the owner reported each of them separately as showing the wrong
## thing. They were not wrong so much as *absent*: a section about the Forge
## illustrated with a picture of the stash is a picture of something else.
##
## A screen that can be built and opened needs no game state behind it, which is
## what makes these the ones worth converting first.
func _screen_shot(maker: Callable, tag: String) -> void:
	_park_clear()
	for node: Node in get_children():
		if node.name.ends_with("Shot"):
			node.queue_free()
	var screen: Node = maker.call()
	if screen == null:
		return
	screen.name = tag + "Shot"
	add_child(screen)
	if screen.has_method("open"):
		screen.call("open")


func _open_hub() -> void:
	_park_clear()
	for node: Node in get_children():
		if node.name == "CoopShot":
			node.queue_free()
	var hub: HubScreen = HubScreen.new()
	hub.name = "HubShot"
	add_child(hub)
	if hub.has_method("open"):
		hub.open()


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out


# --- The camera ---------------------------------------------------------------------------

## **`just_before` runs six frames before the shutter, not seventy.**
##
## Everything else here sets a state up and lets it settle. A shot in the air
## does not settle - an arrow and a thrown javelin both live about a third of a
## second, so one loosed at the start of the wait is on the ground long before
## the picture is taken. That is the whole reason `bow` and `enemy_shots` were
## photographs of an ordinary wave.
func _shot(id: String, setup: Callable, just_before: Callable = Callable()) -> void:
	await _settle()
	await _take(id, setup, just_before)


## **The picture itself, with the clearing already done.**
##
## Split out of `_shot` because `_weather_shot` has to settle *before* it drives
## the sky rather than after: the settle clears the sky (owner, 2026-09-16, so
## that a standing flood does not prevent the next picture's wildfire), so a
## second one between the drive and the shutter drained every flood, put out
## every blaze and freed every funnel one frame after it was made. Every weather
## picture was a photograph of a clear day.
func _take(id: String, setup: Callable, just_before: Callable = Callable()) -> void:
	setup.call()
	get_tree().paused = false
	var wanted: bool = _wanted(id)
	for _f: int in (70 if wanted else 8):
		await get_tree().process_frame
	if not wanted:
		return
	if just_before.is_valid():
		just_before.call()
		for _f: int in 6:
			await get_tree().process_frame
	_capture(id)


## **Ends an arena and waits for it to hand the road back.**
##
## `RaidArena` and `RiftArena` finish on the frame *only when nobody is
## watching* - `_finish` says so in as many words, because a gate should not hang
## on an animation. With a renderer a rift plays its collapse: falling rock, a
## full-screen shade, a shake, and `DayNight` held underground until `_surface()`
## at the very end. The tool called `_finish` and moved on, so every picture from
## the rift shot onward was taken below ground through a closing dungeon.
##
## `Run` already puts the world back on these signals, so this waits for the real
## return rather than performing a second one of its own.
func _close_arena(arena: Node, result: Dictionary, done: Signal, seconds: float) -> void:
	var landed: Array[bool] = [false]
	var mark: Callable = func(_reward: Dictionary) -> void: landed[0] = true
	# **Connected before the knock.** A rift awaits several seconds of collapse
	# before it answers; a raid answers on the same frame, inside the call - so
	# connecting afterwards loses that race every time, and the first cut sat out
	# the whole ceiling warning about an arena that had already closed.
	done.connect(mark, CONNECT_ONE_SHOT)
	arena.call("_finish", result)
	var waited: float = 0.0
	while not landed[0] and waited < seconds:
		waited += get_process_delta_time()
		await get_tree().process_frame
	if done.is_connected(mark):
		done.disconnect(mark)
	if not landed[0]:
		print("[guide-shots] warning: an arena did not finish inside %.0fs" % seconds)
	# The return switches scope and rebuilds the field's view; let it settle.
	for _f: int in 12:
		await get_tree().process_frame


## **Everything the last picture left on screen, taken down.**
##
## Owner, 2026-09-16: "some screenshots in the sequence do not wait for unrelated
## UI elements to close so they do not appear in the following screenshots." They
## did not wait because nothing ever closed them - a tower sheet opened for the
## paths picture was still open for the Mansion one, a boss's name card was still
## fading across the attributes page, and the hero had been hurt for the healing
## picture twenty shots earlier so every screen since wore a red wound vignette.
##
## Run at the *start* of a shot rather than at the end of the one before, because
## a picture is only ever spoiled by what is on screen when its own shutter
## opens - and that way a shot taken alone under `--only` is as clean as one
## taken in sequence.
func _settle() -> void:
	if run == null:
		return
	for node: Node in get_children():
		if node.name.ends_with("Shot"):
			node.queue_free()
	var hud: HUD = run.hud
	if hud != null:
		hud.call("_close_build_panel")
		var road: Control = hud.get("_road_panel") as Control
		if road != null:
			road.visible = false
		# The region card fades over several seconds on a tween of its own, so
		# hiding it is not enough - the tween would bring it back.
		var card: Control = hud.get("_region_card") as Control
		if card != null:
			var fade: Tween = hud.get("_region_tween") as Tween
			if fade != null and fade.is_valid():
				fade.kill()
			card.visible = false
			card.modulate.a = 0.0
		var line: Label = hud.get("_message") as Label
		if line != null:
			line.text = ""
		hud.set("_message_left", 0.0)
	if run.town_panel != null:
		run.town_panel.close()
	if run.crossroad_ui != null:
		run.crossroad_ui.visible = false
	# **Above ground, on the road, with nothing else on screen.**
	#
	# Waiting for the arenas is the fix; this is the net. The world being
	# underground is not something any picture can see coming, and the one that
	# inherited it read as a dark brown rectangle with a health bar over it.
	if DayNight.underground:
		DayNight.set_underground(false)
	for arena: CanvasItem in [run.raid, run.rift] as Array[CanvasItem]:
		if arena != null and arena.visible:
			arena.visible = false
			(arena as Node).process_mode = Node.PROCESS_MODE_DISABLED
	for node: Node in _walk(run):
		if node.name == "CollapseShade":
			node.queue_free()
	if run.battlefield != null and run.battlefield.is_suspended():
		run.battlefield.resume()
	# **The line comes out of the water.**
	#
	# `Fishing` takes it out when the angler *moves*, and it reads `own_speed` -
	# which a teleport never raises. So walking the Warden to the next subject
	# left a float sitting in a pond several screens away with the line drawn all
	# the way to it, in every picture after the water ones.
	var ponds: Fishing = run.battlefield.ponds() if run.battlefield != null else null
	if ponds != null and ponds.is_fishing():
		ponds.call("_abandon", "")
	_clear_the_sky()
	# **And the cursor.** See `_park_on_hero`: left where the desktop had it, it
	# is an arbitrary shove in the frame of every battlefield picture.
	_park_on_hero()
	# **The party feed keeps what it was told.** Building three towers for the
	# towers picture writes three "Red built ..." lines, and they then sat in the
	# corner of every photograph taken after it.
	var feed: Node = hud.get("_party_log") as Node if hud != null else null
	if feed != null:
		for line: Node in feed.get_children():
			line.queue_free()
		feed.set("_lines", [] as Array[Label])
	_show_preparation_card(false)
	# **Everything the last picture staged.** A summoned boss keeps standing and
	# keeps the top of the screen; a savage sent for the hunted picture is still
	# hunting; a wounded partner is still standing about. Taken off rather than
	# killed: a death runs the act-end cinematics, and this is a photograph
	# session.
	for undo: Callable in _staged:
		undo.call()
	_staged.clear()
	var standing: Variant = run.boss_director.get("_active") if run.boss_director != null else null
	if standing != null and is_instance_valid(standing):
		(standing as Node).queue_free()
		run.boss_director.set("_active", null)
	# **And anything already in the air.** A boss's volley, a mortar's fall and a
	# ground strike all outlive whatever threw them - deliberately, because a
	# blow already thrown must land even if its thrower does not. True in a game,
	# wrong in a photograph of the next section.
	for group: StringName in [Enemy.SUMMON_GROUP, &"enemy_shots", &"ground_strikes"]:
		for shot: Node in get_tree().get_nodes_in_group(group):
			if is_instance_valid(shot):
				shot.queue_free()
	for node: Node in _walk(run.battlefield):
		if node is EnemyProjectile or node is EnemyGroundStrike or node is HeroArrow:
			node.queue_free()
	if hud != null:
		var bar: CanvasItem = hud.get("_boss_panel") as CanvasItem
		if bar != null:
			bar.visible = false
	# **A wound outlives the picture that wanted it.** `Vfx` is an autoload and
	# the vignette is its own layer, so the 45% the healing shot took off the
	# hero tinted every screen photographed after it.
	var hero: Hero = run.battlefield.hero if run.battlefield != null else null
	if hero != null and hero.health != null:
		hero.health.heal(hero.health.max_hp)
	Vfx.clear_vignette()
	for _f: int in 4:
		await get_tree().process_frame


## **The Preparation card**, which is on screen for the whole of Preparation and
## therefore in the middle of nearly every picture this tool takes.
##
## Faded rather than hidden: `visible` is assigned from the phase on two separate
## refreshes and would be back within a frame, and `modulate` is nobody else's.
func _show_preparation_card(on: bool) -> void:
	if run == null or run.hud == null:
		return
	var card: CanvasItem = run.hud.get("_preparation_panel") as CanvasItem
	if card != null:
		card.modulate.a = 1.0 if on else 0.0


## **The shutter**: the frame, cropped square to 16:9, down to `SIZE`.
##
## The crop is what makes fullscreen safe. The frame is whatever shape the
## monitor is, and resizing a 16:10 or 21:9 grab straight to 16:9 squashes
## everything in it - a squashed Warden is a worse picture than a small one.
func _capture(id: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var wide: int = image.get_width()
	var tall: int = image.get_height()
	var cut_w: int = mini(wide, int(round(float(tall) * 16.0 / 9.0)))
	var cut_h: int = mini(tall, int(round(float(cut_w) * 9.0 / 16.0)))
	if cut_w < wide or cut_h < tall:
		image = image.get_region(Rect2i((wide - cut_w) / 2, (tall - cut_h) / 2,
			cut_w, cut_h))
	image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(OUT + id + ".png")
	_written.append(id)
	print("[guide-shots] %s" % id)



## **One picture of the sky, the ground or the earth's anger.**
##
## Settled, driven through the system's own door, and given `let_it_run` frames
## to develop before the shutter - a wildfire on the frame it is lit is one
## burning plant, and a funnel on the frame it is born is a smudge of dust.
## **One picture of the sky.**
##
## `drive` makes the standing state - a downpour, a knee-deep flood, a blaze -
## and `let_it_run` gives it the frames it needs to look like itself. `until`, if
## given, ends that wait the moment the thing being photographed has actually
## happened, so a funnel is driven until it *is* carrying fire rather than for a
## number of frames somebody guessed. `just_before` is for anything that does not
## live long enough to be waited on: a bolt draws for nine frames and the shutter
## is seventy away, so a strike made in `drive` has already gone out.
func _weather_shot(id: String, drive: Callable, let_it_run: int = 0,
		just_before: Callable = Callable(), until: Callable = Callable()) -> void:
	if not _wanted(id):
		return
	await _settle()
	_apt_post(id)
	drive.call()
	for _frame: int in let_it_run:
		if until.is_valid() and bool(until.call()):
			break
		await get_tree().process_frame
	# **No second settle.** See `_take`: settling here would clear the sky that
	# was just driven.
	#
	# The banner is taken down for every one of these but `charged_ground`,
	# whose subject it *is*: a flood opens a basin and a strike opens a storm
	# core, and each announces itself across the middle of somebody else's
	# picture (owner, 2026-09-16).
	if id != "charged_ground":
		_hush()
	await _take(id, func() -> void: _hush() if id != "charged_ground" else null,
		just_before)


## **One water picture**: a clean screen, the rod taken, the pond driven to one
## state, the shutter, and the hands given back.
##
## `_shot_now` has no settling time of its own by design - a hooked fish does not
## wait - so the settle happens here, before the rod is picked up, rather than
## inside it.
func _water_shot(id: String, bank: Vector2, want: int, zoom: float,
		aim_at: Vector2 = Vector2.INF) -> void:
	if not _wanted(id):
		return
	await _settle()
	var own_hands: HeroInput = run.battlefield.hero.input
	_zoom(zoom)
	if await _fish_to(bank, want, aim_at, id):
		pass
	else:
		# A pond can be fished out and a picture is not worth failing a run over.
		await _shot(id, func() -> void: _stand_at(bank); _zoom(zoom))
	_hands_back(own_hands)
	_zoom(0.0)


## **Hands that hold a button rather than latch it.**
##
## `RemoteHeroInput` spends a press on whoever reads it first, which on a hero is
## the seam, the well and the gate long before `Fishing` looks - so a scripted
## press never reached the water. A real keyboard does not work that way either:
## `LocalHeroInput` reports the action's edge and every reader that frame gets
## the same answer. This is that, scripted.
class SteadyHands extends HeroInput:
	var press: int = 0
	var hold: int = 0

	func move() -> Vector2:
		return Vector2.ZERO

	func aim(previous: Vector2) -> Vector2:
		return previous

	func pressed(button: int) -> bool:
		return press & button != 0

	func held(mask: int) -> bool:
		return hold & mask != 0

	func is_local() -> bool:
		return false


## **The shutter on its own**, for a subject with a clock on it.
##
## `_shot` settles for seventy frames first, which is what every standing picture
## wants and what a hooked fish cannot survive. Two frames is enough for the
## interface to have drawn the state that was just reached.
func _shot_now(id: String) -> void:
	for _f: int in 2:
		await get_tree().process_frame
	_capture(id)


## **A line in the water and a fish on the end of it.**
##
## Driven through `Fishing`'s own doors with a scripted input rather than by
## setting its state: a press to charge, a release to cast, the wait, a press on
## the bite. Returns whether it got there - a pond can be fished out, and a
## picture is not worth failing a tool run over.
## **Drives the pond to one state**, from `bank`, casting at `aim_at`.
##
## The aim is the owner's second fishing note (2026-09-16): the Warden must face
## the middle of the pond and put the line in it. Two things carry that, and
## neither is a state being set directly.
##
## `Hero.face` is the door a guest's hero is turned by, and it is called **every
## frame** rather than once - `_facing_hold` lapses, and a scripted input returns
## "wherever you were already pointing", so a single call would be forgotten by
## the time the release happened.
##
## And the release waits on the *charge*. Under `FISHING_TAP_CHARGE` the line
## goes to the nearest water instead of along the aim, which is the shortest
## throw there is; the charge is held until the reach it buys matches the
## distance to the aim, read off the same two constants `_let_fly` reads.
func _fish_to(bank: Vector2, want: int, aim_at: Vector2 = Vector2.INF,
		shutter: String = "") -> bool:
	var field: Battlefield = run.battlefield
	var hero: Hero = field.hero
	var ponds: Fishing = field.ponds()
	if hero == null or ponds == null:
		return false
	_stand_at(bank)
	hero.velocity = Vector2.ZERO
	var was: HeroInput = hero.input
	var hands := SteadyHands.new(hero)
	hero.input = hands
	var aiming: bool = aim_at.x < INF and aim_at.y < INF
	# The charge whose reach lands the float exactly on the aim point.
	var throw: float = bank.distance_to(aim_at) if aiming else 0.0
	var charge_to: float = clampf(
		inverse_lerp(Balance.FISHING_CAST_MIN, Balance.FISHING_CAST_MAX, throw),
		Balance.FISHING_TAP_CHARGE + 0.06, 1.0)
	var reached: bool = false
	var frames: int = 0
	# Long enough for a slow wait. A bite is rolled against the pond's own
	# clock, so this is a ceiling rather than an expectation.
	while frames < 1800 and not reached:
		var here: int = ponds.state()
		if aiming:
			# Every frame: the hold lapses, and the aim is what decides where the
			# line goes at the moment it leaves the hand.
			hero.face((aim_at - hero.global_position).normalized())
		hands.press = 0
		hands.hold = 0
		if here == want and want == Fishing.State.REELING:
			# **Played, not merely entered.** The first frame of a reel is the
			# marker wherever it happened to start; what teaches the minigame is
			# the marker *inside the green*, which is the one thing it asks for.
			# So it is played the way a player plays it - pull while the marker
			# is under the band's middle, ease off above it - and the shutter
			# waits until it is centred and the catch is visibly under way.
			var tension: float = float(ponds.get("_tension"))
			var band: float = float(ponds.get("_band_centre"))
			var half: float = float(ponds.get("_band_half"))
			if tension < band:
				hands.hold = HeroInput.HOLD_INTERACT
			if absf(tension - band) <= half * 0.3 \
					and float(ponds.get("_progress")) > 0.2:
				print("[guide-shots] reel: tension %.3f in band %.3f +-%.3f, %d%% landed"
					% [tension, band, half, int(float(ponds.get("_progress")) * 100.0)])
				reached = true
		elif here == want:
			# **Hold whatever this state is held by**, so the picture is of a
			# state still running rather than of one letting go.
			hands.hold = HeroInput.HOLD_INTERACT
			reached = true
		else:
			match here:
				Fishing.State.READY:
					hands.press = HeroInput.BUTTON_INTERACT
					hands.hold = HeroInput.HOLD_INTERACT
				Fishing.State.CHARGING:
					# Held until the throw is long enough to reach the middle,
					# then let go - the release is the cast. Without an aim point
					# this lets go at once, which is a tap: the line then goes to
					# the nearest water rather than along the aim.
					if aiming and float(ponds.get("_charge")) < charge_to:
						hands.hold = HeroInput.HOLD_INTERACT
				Fishing.State.BITE:
					hands.press = HeroInput.BUTTON_INTERACT
					hands.hold = HeroInput.HOLD_INTERACT
				_:
					# Waiting and casting: hold the rod, and never press - a press
					# on a waiting line reels it back in empty.
					hands.hold = HeroInput.HOLD_INTERACT
		hero.velocity = Vector2.ZERO
		# **Photographed on the frame that satisfied the condition**, not two
		# frames later. A reel's marker moves several percent a frame, so a
		# shutter that opens afterwards photographs a different moment - which is
		# what made tightening the window produce no better a picture and
		# eventually no picture at all.
		if reached and not shutter.is_empty():
			await RenderingServer.frame_post_draw
			_capture(shutter)
		frames += 1
		await get_tree().process_frame
	if not reached:
		print("[guide-shots] fishing: wanted state %d, stuck in %d after %d frames (%s)"
			% [want, ponds.state(), frames, String(ponds.get("_prompt"))])
		hero.input = was
	return reached


## The hands go back to the player after a scripted sequence.
func _hands_back(driver: HeroInput) -> void:
	var hero: Hero = run.battlefield.hero
	if hero != null:
		hero.input = driver


## The hero, beside the first sign of whatever this run is about.
##
## Laid rather than waited for: the trail begins in the act its quarry belongs
## to, and a photograph should not depend on the run having got there.
func _stand_at_a_trail_sign(run: Run) -> Vector2:
	var trail: MythicTrail = run.battlefield.trail()
	if trail == null:
		return Vector2.ZERO
	RunState.act = maxi(RunState.act, 2)
	trail.scatter()
	var where: Dictionary = trail.report()
	var places: Array = where.get("signs", [])
	if places.is_empty():
		print("[guide-shots] warning: the trail laid no signs to photograph")
		return Vector2.ZERO
	return places[0] as Vector2

func _copy(from: String, to: String) -> void:
	if not _wanted(to):
		return
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(OUT + from + ".png"))
	if image == null:
		return
	image.save_png(OUT + to + ".png")
	_written.append(to)


## A region of a picture, as fractions, blown back up to the picture's size.
func _crop(from: String, to: String, part: Rect2) -> void:
	if not _wanted(to):
		return
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(OUT + from + ".png"))
	if image == null:
		return
	var rect := Rect2i(int(part.position.x * image.get_width()), int(part.position.y * image.get_height()),
		int(part.size.x * image.get_width()), int(part.size.y * image.get_height()))
	var piece: Image = image.get_region(rect)
	piece.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	piece.save_png(OUT + to + ".png")
	_written.append(to)
