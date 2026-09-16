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
		GameDirector.set_build_mode(true); _show_preparation_card(true))
	GameDirector.set_build_mode(false)
	await _shot("towers", func() -> void: _build_some(false); _zoom(1.4))
	# Zoomed: the owner asked for the wells "zoomed in in game more" with the
	# interaction showing, and a well read across a whole battlefield is a speck.
	await _shot("wells", func() -> void: _build_some(true); _zoom(1.7))
	await _shot("traps", func() -> void: _place_trap(); _zoom(1.5))
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
	var middle: Vector2 = _pond_aim(pond)
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
	await _shot("farming", func() -> void: _stand_at(_wild_crop() + Vector2(64.0, 36.0)))
	await _shot("camps", func() -> void: _stand_at(_camp_centre()))
	# **A real sign, stood at**, and taken here with the other field pictures
	# rather than down among the copies: by the time the rift shots have run the
	# hero has been put back beside the town, and the first cut photographed the
	# town square with a caption about tracking.
	# **The act is put back afterwards.** The trail needs an act it can begin in
	# and pushes the run to II; nothing put it back, so every later picture was
	# taken in a run whose act had quietly moved - which is how the act-boss
	# photograph came out holding an Act II boss under a HUD reading Act I.
	var act_was: int = RunState.act
	await _shot("mythic_trail", func() -> void: _stand_at_a_trail_sign(run))
	RunState.act = act_was
	await _shot("forks", func() -> void: _stand_at(_barrier_at()))
	_stand_at(Vector2.ZERO)

	# --- The fight ---------------------------------------------------------------------------
	await _shot("party_events", func() -> void:
		EventBus.party_event_prompt.emit(0, 0, "Ren", 20.0, false))
	EventBus.party_event_prompt_closed.emit()
	await _shot("spirits", func() -> void: _bond_a_spirit())
	_copy("spirits", "summons")
	run.call("_on_ride_on_requested")
	for _f: int in 300:
		await get_tree().process_frame
	await _shot("waves", func() -> void: pass)
	_copy("waves", "hud")
	_copy("waves", "loop")
	_copy("waves", "bow")
	_crop("waves", "spells", Rect2(0.25, 0.8, 0.5, 0.2))
	_crop("waves", "currencies", Rect2(0.0, 0.0, 0.42, 0.22))
	await _shot("healing", func() -> void:
		if field.hero != null and field.hero.health != null:
			field.hero.health.take_damage(field.hero.health.max_hp * 0.45,
				field.hero.global_position + Vector2.LEFT * 30.0))
	await _shot("night", func() -> void: DayNight.call("_apply", 0.78))
	_copy("night", "glossary_c")
	DayNight.call("_apply", 0.18)

	# --- The screens ------------------------------------------------------------------
	await _shot("crossroads", func() -> void: run.crossroad_ui.open(1))
	run.crossroad_ui.visible = false
	await _shot("cards", func() -> void:
		run.crossroad_ui.visible = true
		run.call("_offer_road_cards"))
	run.crossroad_ui.visible = false
	RunState.pending_road_cards = []
	await _shot("relics", func() -> void:
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
	# **Waited out rather than assumed.** See `_wait_for`: with a renderer these
	# finish over several seconds, and everything photographed in the meantime is
	# photographed inside the arena that is closing.
	run.raid.call("_finish", {"partial": true, "died": false, "kills": 14})
	await _wait_for(EventBus.raid_ended, 12.0)
	await _shot("rifts", func() -> void:
		field.suspend()
		run.rift.visible = true
		run.rift.process_mode = Node.PROCESS_MODE_INHERIT
		run.rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
		run.rift.activate())
	run.rift.call("_finish", {"closed": true, "left": true})
	await _wait_for(EventBus.rift_ended, 12.0)

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
	await _shot("hunted", func() -> void: _send_a_hunter(); _zoom(1.5))
	_zoom(0.0)
	# **A nest picture with a nest in it** (owner: "Nests and eggs not visible in
	# screenshot image"). It was a copy of the trail-sign photograph.
	await _shot("nesting", func() -> void: _lay_a_nest(); _zoom(1.8))
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
	await _shot("gathering", func() -> void:
		_stand_at(_a_gather_node() + Vector2(48.0, 34.0)); _zoom(1.8))
	_crop("gathering", "crafts", Rect2(0.2, 0.15, 0.6, 0.7))
	_zoom(0.0)
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
func _build_some(well: bool) -> void:
	var field: Battlefield = run.battlefield
	var data: TowerData = null
	if well:
		data = ContentDB.tower("healing_well")
	else:
		for id: Variant in ContentDB.towers:
			var candidate: TowerData = ContentDB.towers[id] as TowerData
			if candidate != null and not candidate.is_well():
				data = candidate
				break
	if data == null:
		return
	var built: int = 0
	var middle := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	for ring: int in range(3, 12):
		for dx: int in range(-ring, ring + 1):
			for dy: int in [-ring, ring]:
				for anchor: Vector2i in [middle + Vector2i(dx, dy), middle + Vector2i(dy, dx)]:
					if built >= (1 if well else 3):
						return
					if field.placement_problem(anchor).is_empty():
						if field.try_build(anchor, data).is_empty():
							built += 1
							if built == 1:
								_stand_at(BattleGrid.tile_to_world(anchor) + Vector2(60.0, 40.0))


func _place_trap() -> void:
	var field: Battlefield = run.battlefield
	var data: TrapData = null
	for id: Variant in ContentDB.traps:
		data = ContentDB.traps[id] as TrapData
		if data != null:
			break
	if data == null:
		return
	var middle := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	for ring: int in range(3, 12):
		for dx: int in range(-ring, ring + 1):
			for tile: Vector2i in [middle + Vector2i(dx, -ring), middle + Vector2i(dx, ring)]:
				if field.try_place_trap(tile, data).is_empty():
					_stand_at(BattleGrid.tile_to_world(tile) + Vector2(50.0, 30.0))
					return


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


## **A place to cast from**: clear dry ground, a good throw from the middle.
##
## Both halves are the owner's (2026-09-16) - "well outside the pond's waters"
## and "casting the line into the center". Searched rather than offset, because a
## pond is a blob of Wang tiles and every one is a different shape: the same
## offset that is a bank on one is the middle of another.
func _pond_bank(centre: Vector2) -> Vector2:
	var best := Vector2.ZERO
	var best_error: float = INF
	for step: int in range(5, 30):
		var out: float = float(step) * 10.0
		if out < Balance.FISHING_CAST_MIN + 40.0 or out > Balance.FISHING_CAST_MAX - 40.0:
			continue
		for slice: int in 24:
			var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * float(slice) / 24.0) * out
			if not _dry_all_round(at, SHORE_CLEAR):
				continue
			var error: float = absf(out - CAST_IDEAL)
			if error < best_error:
				best_error = error
				best = at
	if best_error < INF:
		return best
	# Nothing on this pond has a clear bank at a castable distance. Fall back to
	# the old rule - a body's width of dry ground - rather than to nothing.
	for step: int in range(2, 30):
		var out: float = float(step) * 20.0
		for slice: int in 16:
			var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * float(slice) / 16.0) * out
			if _dry_all_round(at, 34.0):
				return at
	return centre + Vector2(0.0, 160.0)


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


## **The water the line is meant to land in**: the pond's middle, or the nearest
## real water to it if the middle happens to be a tile the mask left dry.
##
## A float that lands on dry ground is a *miss* - `Fishing._touch_down` says so -
## so aiming at a point nobody checked was water would photograph the line coming
## back empty.
func _pond_aim(centre: Vector2) -> Vector2:
	var field: Battlefield = run.battlefield
	if field.water_depth_at(centre) > 0.05:
		return centre
	for step: int in range(1, 12):
		var out: float = float(step) * 16.0
		for slice: int in 12:
			var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * float(slice) / 12.0) * out
			if field.water_depth_at(at) > 0.05:
				return at
	return centre


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
func _lay_a_nest() -> void:
	var nests: WildlifeNests = run.battlefield.nests()
	var hero: Hero = run.battlefield.hero
	if nests == null or hero == null:
		return
	var layer: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and kind.lays_eggs:
			layer = kind
			break
	if layer == null:
		return
	var clutch: Array[Dictionary] = []
	for _egg: int in 3:
		clutch.append({"stage": WildlifeFamilies.Stage.BABY,
			"rarity": int(layer.rarity), "shiny": false})
	nests.lay(layer, hero.global_position + Vector2(60.0, 30.0), clutch, 0)


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
		return Vector2.ZERO
	return dug[0].get("at", Vector2.ZERO) as Vector2


## The Mansion, on one of its three pages.
##
## `open` resets the page whenever the plot changes, so the page is set after it
## and the sheet redrawn - setting it first would be overwritten in silence.
func _open_mansion(page: int, tree_filter: int = -1) -> void:
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
	var boss: Node2D = run.boss_director.get("_active") as Node2D if run.boss_director != null else null
	var hero: Hero = run.battlefield.hero
	if boss == null or not is_instance_valid(boss) or hero == null:
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
func _send_a_hunter() -> void:
	var animals: Wildlife = run.battlefield.get("_wildlife") as Wildlife
	if animals == null:
		return
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null or kind.mythic:
			continue
		animals.call("_send_a_savage", kind)
		return


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


## **Waits for an arena to hand the road back.**
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
func _wait_for(done: Signal, seconds: float) -> void:
	var landed: Array[bool] = [false]
	var mark: Callable = func(_reward: Dictionary) -> void: landed[0] = true
	done.connect(mark, CONNECT_ONE_SHOT)
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
	# **The party feed keeps what it was told.** Building three towers for the
	# towers picture writes three "Red built ..." lines, and they then sat in the
	# corner of every photograph taken after it.
	var feed: Node = hud.get("_party_log") as Node if hud != null else null
	if feed != null:
		for line: Node in feed.get_children():
			line.queue_free()
		feed.set("_lines", [] as Array[Label])
	_show_preparation_card(false)
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
	if await _fish_to(bank, want, aim_at):
		await _shot_now(id)
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
func _fish_to(bank: Vector2, want: int, aim_at: Vector2 = Vector2.INF) -> bool:
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
		if here == want:
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
func _stand_at_a_trail_sign(run: Run) -> void:
	var trail: MythicTrail = run.battlefield.trail()
	if trail == null:
		return
	RunState.act = maxi(RunState.act, 2)
	trail.scatter()
	var where: Dictionary = trail.report()
	var places: Array = where.get("signs", [])
	if places.is_empty():
		return
	var at: Vector2 = places[0]
	if run.battlefield.hero != null:
		run.battlefield.hero.global_position = at + Vector2(90.0, 30.0)

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
