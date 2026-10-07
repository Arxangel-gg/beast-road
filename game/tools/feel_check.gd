extends Node

## The four feel changes of 2026-09-15, each driven rather than read back.
##
##   godot --headless --path game res://tools/feel_check.tscn
##
## From `docs/IDEAS_REVIEW_2026-09-15b.md`: of six gaps named out of the fifth
## forwarded list, two turned out to be built already and these four were real -
## sound that knows where it is, a tower that leans at what it is about to
## shoot, a tower that is built rather than placed, and a body that comes apart
## by whatever finished it.
##
## **The bound all four share is that nothing about damage moves**, and that is
## what most of this file checks. Every one of them is presentation; each is the
## last thing its caller does; and turning any of them off has to leave the run
## identical. The failures worth gating are therefore not "does it look right" -
## no gate can see that - but:
##
## - **A sound that decides something.** `play_at` drops a sound past the cutoff.
##   If a caller ever came to depend on that call having happened, dropping it
##   would change the game, silently, only for players standing far away.
## - **A headless ear.** There is no camera in a gate, so `play_at` must be
##   exactly `play`. If it were not, every other gate in this project would be
##   quietly measuring a different game from the one that ships.
## - **A tell that lies.** The tower's lean reads the same `_acquire_targets`
##   the shot does. If it ever asked a second question, the lean would point at
##   a body the tower is not firing on - which is worse than no lean at all.
## - **A rise that repeats.** A tower climbs out of the ground when it is built.
##   `_sync_towers` runs on every change and for a guest being handed a whole
##   field, so a rise triggered there would have six-wave-old towers re-emerging
##   whenever a neighbour was sold.
## - **An element that sticks.** The death mark is a *window*, and a mark that
##   never expired would make every body that ever touched fire die in embers.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_ear()
	_test_a_burst_is_heard_as_its_first_few()
	await _test_a_streak_counts_what_falls_near()
	_test_a_scope_change_is_a_cut()
	_test_a_dropped_sound_decides_nothing()
	await _test_a_sound_has_a_side_and_a_wall()
	await _test_the_field()
	_test_a_voice_comes_from_where_it_is()
	await _test_the_hush_hands_the_room_back()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[feel] PASS - %d checks: distance quietens and never decides, a "
			+ "tower leans at what it will actually shoot, it rises once when "
			+ "built, a body remembers what finished it, and the hush hands the "
			+ "room back") % _checks)
	else:
		push_error("[feel] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **The quiet after a boss ducks the room and never touches the mix.**
##
## The failure worth gating is silent and permanent: a hush that is interrupted -
## by a scene change, a gate tearing the audio down, a second boss - and never
## resolves leaves the master fader at a tenth for the rest of the process, with
## every slider on the settings screen still reading what the player chose. There
## is no error, nothing sounds broken, and the game is simply quiet forever.
func _test_the_hush_hands_the_room_back() -> void:
	var was: Dictionary = MetaState.settings.duplicate(true)
	MusicPlayer.end_hush()
	_check(is_equal_approx(AudioBuses.hush_share(), 1.0),
		"the room starts open (%.3f)" % AudioBuses.hush_share())

	MusicPlayer.hush(Balance.BOSS_HUSH_SECONDS, Balance.BOSS_HUSH_DEPTH)
	for _frame: int in 20:
		await get_tree().process_frame
	_check(AudioBuses.hush_share() < 0.9,
		"the room actually goes quiet (%.3f)" % AudioBuses.hush_share())
	# **Never to nothing.** Total silence reads as the audio having crashed;
	# the world should still be faintly there underneath.
	_check(AudioBuses.hush_share() >= Balance.BOSS_HUSH_DEPTH - 0.001,
		"the room is never taken away entirely (%.3f)" % AudioBuses.hush_share())

	# **And a hush cut short still resolves.** This is the whole reason the check
	# exists: everything that tears the audio down goes through `stop_immediately`
	# and it must hand the room back.
	MusicPlayer.stop_immediately()
	_check(is_equal_approx(AudioBuses.hush_share(), 1.0),
		"a hush cut short hands the room straight back (%.3f)"
			% AudioBuses.hush_share())

	# **It ducks; it does not mix.** Not one fader may have moved, or a player
	# would find their music quieter after an act with the slider still saying
	# otherwise.
	for key: String in UserSettings.VOLUME_KEYS:
		_check(is_equal_approx(float(MetaState.settings.get(key, -1.0)),
			float(was.get(key, -1.0))),
			"%s is exactly where the player left it" % key)


## **Headless, there is no ear, and that is load-bearing.**
##
## Every other gate in this project plays sounds. If `play_at` attenuated or
## dropped anything without a camera, they would all be hearing a different game
## from the one that ships, and a sound-related failure would reproduce nowhere.
func _test_the_ear() -> void:
	Sfx.stop_listening()
	_check(not Sfx.is_listening(), "a gate must start with nobody listening")
	_check(is_equal_approx(Sfx.distance_db(0.0), 0.0),
		"a sound at the ear must not be quietened: %.2f dB" % Sfx.distance_db(0.0))
	_check(is_equal_approx(Sfx.distance_db(Balance.SFX_NEAR * 0.5), 0.0),
		"a sound inside SFX_NEAR must play at its authored level")
	# **Re-cut 2026-10-01** (owner: *"attenuation radius volume of sfx"*): the
	# invariants were a straight line to a floor at SFX_FAR and a floor held to
	# the cutoff. What is held now is the open-air rule - a doubling of distance
	# costs SFX_DB_PER_DOUBLING - and that a sound has faded to near silence by
	# the time it reaches the cutoff, so crossing it is not a step.
	var double: float = Sfx.distance_db(Balance.SFX_NEAR * 2.0) - Sfx.distance_db(Balance.SFX_NEAR * 4.0)
	_check(absf(double - Balance.SFX_DB_PER_DOUBLING) < 0.01,
		"a doubling of distance must cost %.1f dB, cost %.2f" % [Balance.SFX_DB_PER_DOUBLING, double])
	var edge: float = Sfx.distance_db(Balance.SFX_CUTOFF - 1.0)
	_check(edge <= -24.0,
		"a sound at the cutoff must be all but gone before it is dropped, was %.1f dB" % edge)
	# Monotonic, because a sound that got louder with distance would be worse
	# than one that never changed at all.
	for reach: float in [0.55, 1.0, 1.7]:
		var previous: float = 1.0
		for step: int in 40:
			var db: float = Sfx.distance_db(float(step) * Balance.SFX_CUTOFF * reach / 39.0, reach)
			_check(db <= previous + 0.001,
				"the falloff rose with distance at %d (reach %.2f): %.2f after %.2f"
					% [step, reach, db, previous])
			previous = db
	# **A quake carries and a footstep does not.** At one distance the bigger
	# sound is the louder, and the small one's cutoff comes far sooner.
	var at: float = Balance.SFX_NEAR * 3.0
	_check(Sfx.distance_db(at, Sfx.reach_of("sfx_quake")) > Sfx.distance_db(at, Sfx.reach_of("sfx_footstep_dirt")),
		"at %.0f a quake is no louder than a footstep" % at)
	_check(Sfx.reach_of("sfx_footstep_dirt_3") < 1.0 and Sfx.reach_of("sfx_quake") > 1.0,
		"a footstep's take must carry less than standard and a quake more")
	_check(is_equal_approx(Sfx.reach_of("sfx_never_listed"), 1.0),
		"an unlisted sound must carry the standard reach")
	for prefix: Variant in Balance.SFX_REACH:
		_check(String(prefix).begins_with("sfx_") and float(Balance.SFX_REACH[prefix]) > 0.0,
			"SFX_REACH lists %s, which is no sound id prefix or carries nothing" % prefix)
	# **With nobody listening, the far side of the world is still audible.**
	#
	# This is the check that matters most to every *other* gate in this project.
	# Headless there is no camera, so an ear that attenuated anyway would drop
	# sounds a hundred gates are standing on - and it would do it invisibly,
	# because a missing sound errors nowhere. Caught by removing the guard in
	# `play_at`, which this then names.
	var quiet: int = int(Sfx.debug_state().get("starts", 0))
	Sfx.play_at("sfx_enemy_die", Vector2(Balance.SFX_CUTOFF * 9.0, 0.0))
	_check(int(Sfx.debug_state().get("starts", 0)) > quiet,
		("with nobody listening, a sound must play wherever it happened - "
			+ "otherwise every headless gate hears a different game"))
	Sfx.stop_immediately()
	# **And with an ear, each sound is dropped at its own reach.** Driven through
	# `play_at` itself, because a reach the table knows and the door ignores is a
	# footstep heard across the field.
	Sfx.listen_from(Vector2.ZERO)
	var heard: int = int(Sfx.debug_state().get("starts", 0))
	Sfx.play_group_at("sfx_footstep_dirt", Vector2(Balance.SFX_CUTOFF * 0.7, 0.0))
	_check(int(Sfx.debug_state().get("starts", 0)) == heard,
		"a footstep %.0f away was played - it carries %.2f of the standard reach"
			% [Balance.SFX_CUTOFF * 0.7, Sfx.reach_of("sfx_footstep_dirt")])
	heard = int(Sfx.debug_state().get("starts", 0))
	Sfx.play_at("sfx_quake", Vector2(Balance.SFX_CUTOFF * 1.2, 0.0))
	_check(int(Sfx.debug_state().get("starts", 0)) > heard,
		"a quake %.0f away was dropped - it carries %.2f of the standard reach"
			% [Balance.SFX_CUTOFF * 1.2, Sfx.reach_of("sfx_quake")])
	Sfx.stop_listening()
	Sfx.stop_immediately()


## **A streak counts what falls near the Warden, and nothing else** (2026-09-30).
## Kills close together near the Warden build it and reach a tier; a kill across
## the map does not count; the window lapsing ends it. And it is a look: the
## script names no run or account state at all, and the battlefield stands it up.
## **A change of view is a cut from dark, under the HUD** (2026-09-30). Headless
## there is no picture, so the rule is read off the source: the run stands it
## up, it sits below the HUD's layer, it takes no click, and it names no run or
## account state - a look and nothing else.
func _test_a_scope_change_is_a_cut() -> void:
	var run_source: String = FileAccess.get_file_as_string("res://scenes/run/run.gd")
	_check(run_source.contains("ScopeCut.new()"), "nothing stands the scope cut up")
	var hud_source: String = FileAccess.get_file_as_string("res://scenes/ui/hud.gd")
	var at: int = hud_source.find("\tlayer = ")
	var hud_layer: int = int(hud_source.substr(at + 9, 4).strip_edges()) if at >= 0 else -1
	_check(hud_layer > 0 and ScopeCut.LAYER < hud_layer,
		"the scope cut (layer %d) is not under the HUD (layer %d)" % [ScopeCut.LAYER, hud_layer])
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/scope_cut.gd")
	var code: String = ""
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	_check(code.contains("MOUSE_FILTER_IGNORE"), "the scope cut can take a click")
	_check(not code.contains("RunState.") and not code.contains("MetaState."),
		"the scope cut reads or writes the run - it must be a look and nothing else")


func _test_a_streak_counts_what_falls_near() -> void:
	var warden := Node2D.new()
	add_child(warden)
	var streak := KillStreak.new()
	streak.hero_getter = func() -> Node2D: return warden
	add_child(streak)
	var near: Vector2 = Vector2(120.0, 0.0)
	for _kill: int in Balance.KILL_STREAK_TIERS[0]:
		EventBus.enemy_died.emit("probe", near)
	_check(streak.count() == Balance.KILL_STREAK_TIERS[0] and streak.tier() == 0,
		"%d kills beside the Warden made a streak of %d at tier %d"
		% [Balance.KILL_STREAK_TIERS[0], streak.count(), streak.tier()])
	EventBus.enemy_died.emit("probe", Vector2(Balance.KILL_STREAK_REACH * 3.0, 0.0))
	_check(streak.count() == Balance.KILL_STREAK_TIERS[0],
		"a kill across the map was counted in the Warden's streak")
	var waited: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited < int(Balance.KILL_STREAK_WINDOW * 1000.0) + 120:
		await get_tree().process_frame
	_check(streak.count() == 0, "the streak outlived its window")
	EventBus.enemy_died.emit("probe", near)
	_check(streak.count() == 1, "a kill after the window did not start a new streak")
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/kill_streak.gd")
	var code: String = ""
	for line: String in source.split("\n"):
		if not line.strip_edges().begins_with("#"):
			code += line + "\n"
	_check(not code.contains("RunState.") and not code.contains("MetaState."),
		"the streak reads or writes the run - it must be a look and nothing else")
	_check(FileAccess.get_file_as_string("res://scenes/battlefield/battlefield.gd")
		.contains("_build_kill_streak()"), "nothing stands the streak up on the field")
	streak.queue_free()
	warden.queue_free()
	Sfx.stop_immediately()
	await get_tree().process_frame


## **A burst is heard as its first few sounds, and a flat one is never
## refused** (2026-09-30). Twice the per-frame allowance of different world
## sounds in one frame starts no more than the allowance; a flat sound in the
## same frame still starts, because the interface, a telegraph and the wall
## are never counted. Only while a camera listens.
func _test_a_burst_is_heard_as_its_first_few() -> void:
	Sfx.stop_immediately()
	Sfx.listen_from(Vector2.ZERO)
	var ids: Array = []
	for id: Variant in (Sfx.get("_streams") as Dictionary).keys():
		if String(id).begins_with("sfx_") and ids.size() < Balance.SFX_WORLD_STARTS_PER_FRAME * 2 + 1:
			ids.append(String(id))
	_check(ids.size() > Balance.SFX_WORLD_STARTS_PER_FRAME * 2,
		"not enough distinct sounds to make a burst of")
	var before: int = int(Sfx.debug_state().get("starts", 0))
	for index: int in Balance.SFX_WORLD_STARTS_PER_FRAME * 2:
		Sfx.play_at(String(ids[index]), Vector2(10.0, 0.0))
	var world: int = int(Sfx.debug_state().get("starts", 0)) - before
	_check(world >= 1 and world <= Balance.SFX_WORLD_STARTS_PER_FRAME,
		"a burst of %d world sounds in one frame started %d, allowed %d"
		% [Balance.SFX_WORLD_STARTS_PER_FRAME * 2, world, Balance.SFX_WORLD_STARTS_PER_FRAME])
	var flat_before: int = int(Sfx.debug_state().get("starts", 0))
	Sfx.play(String(ids[ids.size() - 1]))
	_check(int(Sfx.debug_state().get("starts", 0)) == flat_before + 1,
		"a flat sound in a full frame was refused - flat sounds are never counted")
	Sfx.stop_listening()
	Sfx.stop_immediately()


## **A placed sound is heard from its side, and through what stands between**
## (owner, 2026-10-07). Read off the real buses and the real voice: a sound
## left of the ear goes to a bus panned left and one right to one panned right,
## a sound the field says is behind a wall goes to the muffled bus with its
## low-pass and is quieter, and a flat sound - the interface, a telegraph - goes
## to SFX as it always did, on a voice a placed sound used a moment before.
func _test_a_sound_has_a_side_and_a_wall() -> void:
	# A frame of its own: the burst above spent this frame's world starts.
	await get_tree().process_frame
	Sfx.stop_immediately()
	var walled: Array[bool] = [false]
	var wall: Callable = func(_from: Vector2, _to: Vector2) -> bool: return walled[0]
	Sfx.listen_from(Vector2.ZERO, wall)
	var left: Dictionary = Sfx.placement(Vector2(-Balance.SFX_PAN_REACH, 0.0))
	var right: Dictionary = Sfx.placement(Vector2(Balance.SFX_PAN_REACH, 0.0))
	var middle: Dictionary = Sfx.placement(Vector2(0.0, 600.0))
	_check(_pan_of(String(left["bus"])) < -0.3 and _pan_of(String(right["bus"])) > 0.3,
		"a sound hard left is panned %.2f and hard right %.2f"
		% [_pan_of(String(left["bus"])), _pan_of(String(right["bus"]))])
	_check(absf(_pan_of(String(middle["bus"]))) < 0.01, "a sound straight ahead is not centred")
	_check(not bool(left["muffled"]) and is_zero_approx(float(left["db"])),
		"a sound with nothing between it and the ear was muffled")
	walled[0] = true
	var behind: Dictionary = Sfx.placement(Vector2(300.0, 0.0))
	_check(bool(behind["muffled"]) and float(behind["db"]) < 0.0 and _has_low_pass(String(behind["bus"])),
		"a sound behind a wall was not heard through it (%s)" % [behind])
	walled[0] = false
	# The voice: placed, then flat on the same pool.
	Sfx.play_at("sfx_enemy_die", Vector2(-Balance.SFX_PAN_REACH * 0.9, 0.0))
	var placed: AudioStreamPlayer = _last_voice()
	_check(placed != null and placed.bus.begins_with("SFX_P"),
		"a placed sound went to %s, not to a placement bus" % (placed.bus if placed != null else "no voice"))
	Sfx.stop_immediately()
	Sfx.play("sfx_ui_confirm")
	var flat: AudioStreamPlayer = _last_voice()
	_check(flat != null and flat.bus == AudioBuses.SFX,
		"a flat sound went to %s - a reused voice kept the last placement" % (flat.bus if flat != null else "no voice"))
	# Every placement bus reaches SFX, so the fader and the hush reach it.
	for step: int in AudioBuses.PAN_STEPS:
		for muffled: bool in [false, true]:
			var index: int = AudioServer.get_bus_index(AudioBuses.placement_name(step, muffled))
			_check(index >= 0 and AudioServer.get_bus_send(index) == AudioBuses.SFX,
				"placement bus %s does not send to SFX" % AudioBuses.placement_name(step, muffled))
	Sfx.stop_listening()
	Sfx.stop_immediately()


func _pan_of(bus_name: String) -> float:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	for effect: int in AudioServer.get_bus_effect_count(index):
		var panner := AudioServer.get_bus_effect(index, effect) as AudioEffectPanner
		if panner != null:
			return panner.pan
	return 0.0


func _has_low_pass(bus_name: String) -> bool:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		return false
	for effect: int in AudioServer.get_bus_effect_count(index):
		if AudioServer.get_bus_effect(index, effect) is AudioEffectLowPassFilter:
			return true
	return false


## The voice that started last: the playing one, of the pool.
func _last_voice() -> AudioStreamPlayer:
	for voice: Variant in (Sfx.get("_voices") as Array):
		var player := voice as AudioStreamPlayer
		if player != null and player.playing:
			return player
	return null


## **A dropped sound must decide nothing.**
##
## `play_at` refuses a sound past the cutoff. That is only safe because it is the
## last thing any caller does - so the proof is that the call, made from the far
## side of the world, leaves the run exactly as it was and starts no voice.
func _test_a_dropped_sound_decides_nothing() -> void:
	var before: Array = [RunState.enemies_killed, RunState.towers_built,
		RunState.distance_travelled]
	Sfx.listen_from(Vector2.ZERO)
	_check(Sfx.is_listening(), "the ear must take a position when told one")
	var near_state: Dictionary = Sfx.debug_state()
	Sfx.play_at("sfx_enemy_die", Vector2(Balance.SFX_CUTOFF * 4.0, 0.0))
	var far_state: Dictionary = Sfx.debug_state()
	_check(int(far_state.get("starts", 0)) == int(near_state.get("starts", 0)),
		"a sound past the cutoff must not start a voice")
	var after: Array = [RunState.enemies_killed, RunState.towers_built,
		RunState.distance_travelled]
	_check(before == after, "playing a sound changed the run")
	Sfx.stop_listening()
	_check(not Sfx.is_listening(), "the ear must let go when told to")


## **Driven on the real field**, because three of the four are properties of a
## live tower and a live body and cannot be read off a constant.
func _test_the_field() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null, "there must be a field to build on")
	if field == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(4000)

	# --- A tower is built rather than placed --------------------------------
	var anchor: Vector2i = _a_free_plot(field)
	_check(anchor != Vector2i(-9999, -9999), "the field must have somewhere to build")
	var kind: TowerData = _a_shooting_tower()
	_check(kind != null, "there must be a tower that shoots")
	if anchor == Vector2i(-9999, -9999) or kind == null:
		await _leave(run)
		return
	var refused: String = field.try_build(anchor, kind)
	_check(refused.is_empty(), "the build was refused: %s" % refused)
	for _frame: int in 3:
		await get_tree().process_frame
	var built: Tower = field.tower_at_anchor(anchor)
	_check(built != null, "no tower node appeared on the plot that was bought")
	if built == null:
		await _leave(run)
		return
	# Mid-rise the sprite is smaller and lower than it will settle at. Measured
	# rather than asserted off the constant, because what matters is that the
	# idle and the rise agree about one sprite - two systems assigning the same
	# property is a fault this project has already shipped once.
	var rising_scale: float = built.sprite.scale.y
	var rising_y: float = built.sprite.position.y
	_check(rising_scale > 0.0, "a rising tower must still have a size")
	await _settle(Balance.TOWER_RISE_SECONDS + 0.25)
	_check(built.sprite.scale.y > rising_scale,
		"the tower never grew out of its foundation: %.3f then %.3f"
			% [rising_scale, built.sprite.scale.y])
	_check(built.sprite.position.y < rising_y,
		"the tower never came up out of the ground: %.1f then %.1f"
			% [rising_y, built.sprite.position.y])
	var settled_scale: float = built.sprite.scale.y
	var settled_y: float = built.sprite.position.y

	# **And it does not rise again.** `_sync_towers` runs whenever anything about
	# the field's towers changes - and for a guest, over a whole standing field.
	field.refresh_towers()
	await _settle(0.12)
	var again: Tower = field.tower_at_anchor(anchor)
	if again != null:
		_check(absf(again.sprite.position.y - settled_y) < 6.0,
			("a standing tower rose again when the field was re-synced: %.1f "
				+ "against %.1f") % [again.sprite.position.y, settled_y])

	# --- The lean points where the shot will go -----------------------------
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	# **An empty road, or this measures the road.** A wave walking past is a
	# body for the tower to lean at, and a tower shooting the probe is health
	# coming off it for reasons that have nothing to do with an element mark.
	field.wave_director.stop()
	var animals: Node = field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	for _settle_frame: int in 3:
		await get_tree().process_frame
	await _settle(0.3)
	var flat: float = built.sprite.rotation
	var mark: Enemy = _stand_a_body(field, built.global_position
		+ Vector2(built.effective_range() * 0.5, 0.0))
	_check(mark != null, "a body is needed to lean at")
	if mark != null:
		await _settle(0.55)
		var leaned: float = built.sprite.rotation
		_check(absf(leaned - flat) > 0.002,
			"the tower never leaned at a body standing inside its reach")
		# **And it leans the right way.** A tell pointing away from the thing it
		# is about to shoot is worse than no tell at all.
		_check(leaned > flat,
			"the tower leaned away from a body on its right: %.4f from %.4f"
				% [leaned, flat])
		# The lean is small. A structure is drawn front-on with a slight
		# top-down angle, and one turned to face a flank is lying on its side.
		_check(absf(leaned) < deg_to_rad(Balance.TOWER_AIM_DEGREES * 2.5),
			"the lean is %.1f degrees, which is a tower falling over"
				% rad_to_deg(leaned))
		_check(built.sprite.scale.y > settled_scale * 0.8,
			"leaning must not resize the tower: %.3f from %.3f"
				% [built.sprite.scale.y, settled_scale])
		mark.queue_free()
		await _settle(0.7)
		_check(absf(built.sprite.rotation - flat) < deg_to_rad(1.5),
			"the tower stayed leaning at a body that is no longer there")

	# --- A body remembers what finished it ----------------------------------
	var victim: Enemy = _stand_a_body(field, built.global_position
		+ Vector2(0.0, built.effective_range() * 3.0 + 900.0))
	if victim != null:
		victim.mark_element(TowerData.Element.FIRE)
		var before_hp: float = victim.health.current_hp
		victim.take_damage(1.0, victim.global_position + Vector2(40.0, 0.0), 0.0)
		_check(victim.health.current_hp < before_hp,
			"marking an element must not stop a blow landing")
		# Nothing reads the mark but the death, so the proof it is inert is that
		# the body is unchanged while the window runs out.
		victim.mark_element(TowerData.Element.WATER)
		var held: float = victim.health.current_hp
		await _settle(Balance.DEATH_ELEMENT_MEMORY + 0.4)
		_check(not victim.is_dying(),
			"the probe died on its own, which makes the rest of this meaningless")
		# Never equal: a body standing on the road heals a little, which is the
		# road working. What the bound forbids is the mark *taking* anything.
		_check(victim.health.current_hp >= held - 0.01,
			"an expiring element mark cost the body %.2f health"
				% (held - victim.health.current_hp))
		# And the death itself: a marked body dies, and the run is unchanged by
		# how it looked doing it.
		var killed_before: int = RunState.enemies_killed
		victim.mark_element(TowerData.Element.EARTH)
		victim.take_damage(victim.health.max_hp * 10.0,
			victim.global_position + Vector2(40.0, 0.0), 0.0)
		await _settle(0.15)
		_check(RunState.enemies_killed == killed_before + 1,
			"a body marked with an element must still count as a kill")

	await _test_a_blow_is_anticipated(field)
	await _test_a_body_falls_the_way_it_was_struck(field, built.global_position
		+ Vector2(0.0, built.effective_range() * 3.0 + 1400.0))
	await _test_the_road_settles(field)
	_test_a_level_is_a_pillar_of_light(field)
	await _leave(run)


## **Levelling up is a pillar of light** (owner, 2026-10-06), on the ink and
## nothing else, and a partner's level goes through the same door - both held
## by the source, because the fault either way is an omission.
func _test_a_level_is_a_pillar_of_light(field: Battlefield) -> void:
	var light: VfxInk = Vfx.ink()
	_check(light != null, "no additive ink to draw a level on")
	if light == null:
		return
	light.clear()
	var at: Vector2 = field.hero.global_position if field.hero != null else Vector2.ZERO
	var lights_before: int = Vfx.live_light_bursts()
	Vfx.level_burst(at, 7, true)
	_check(light.live_beams() >= 2, "a level drew %d pillars, wanted the pillar and its core" % light.live_beams())
	_check(light.live_rings() >= 2, "a level drew %d rings, wanted two leaving the feet" % light.live_rings())
	_check(light.live() >= Balance.LEVEL_BURST_MOTES + 2, "a level drew %d records, too few for its motes" % light.live())
	_check(Vfx.live_light_bursts() == lights_before + 1 or not Graphics.light_bursts(),
		"a level threw %d lights, wanted one" % (Vfx.live_light_bursts() - lights_before))
	light.clear()
	Vfx.level_burst(at, 7, false)
	_check(light.live_beams() >= 2 and light.live_rings() >= 2,
		"a partner's level is not the same picture (%d pillars, %d rings)" % [light.live_beams(), light.live_rings()])
	light.clear()
	var juice: String = FileAccess.get_file_as_string("res://scripts/systems/party_juice.gd")
	_check(juice.contains("Vfx.level_burst(at, level, false)"),
		"a partner's level does not go through the one door")
	var vfx: String = FileAccess.get_file_as_string("res://autoload/Vfx.gd")
	_check(vfx.contains("level_burst(_hero_position(), level, true)"),
		"this machine's level does not go through the one door")


## **The road settles after a held wave** (2026-09-30): the cell where most fell
## hangs with haze for `SETTLE_SECONDS` and then is clean; a cell where too few
## fell does not; a new wave stops it at once; and it writes nothing.
func _test_the_road_settles(field: Battlefield) -> void:
	var settling: Settling = field.settling()
	_check(settling != null, "the field has no Settling")
	if settling == null:
		return
	var thick := Vector2(400.0, 400.0)
	var thin := Vector2(-900.0, 400.0)
	EventBus.wave_started.emit(99, [])
	for _n: int in Balance.SETTLE_MIN_FALLEN + 2:
		settling._on_enemy_died("bogkin", thick + Vector2(randf_range(-20.0, 20.0), 0.0))
	settling._on_enemy_died("bogkin", thin)
	settling._on_wave_cleared(99)
	var spots: Array[Dictionary] = settling.spots()
	_check(spots.size() == 1, "%d spots settled, wanting the one where most fell" % spots.size())
	if spots.size() == 1:
		var cell: float = Balance.SETTLE_CELL
		_check((spots[0]["at"] as Vector2).distance_to(thick) < cell,
			"the settling is at %s, not where the bodies fell" % str(spots[0]["at"]))
	await _settle(Balance.SETTLE_SECONDS * 0.5)
	_check(not settling.spots().is_empty(), "the settling was gone halfway through")
	await _settle(Balance.SETTLE_SECONDS * 0.5 + 0.3)
	_check(settling.spots().is_empty(), "the settling outlived SETTLE_SECONDS")
	for _n: int in Balance.SETTLE_MIN_FALLEN + 2:
		settling._on_enemy_died("bogkin", thick)
	settling._on_wave_cleared(100)
	_check(not settling.spots().is_empty(), "a second held wave settles too")
	settling._on_wave_started(101, [])
	_check(settling.spots().is_empty(), "a new wave did not stop the settling")
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/settling.gd")
	var reads: int = source.count("RunState.")
	_check(reads == source.count("RunState.wind"),
		"Settling touches RunState for more than the wind - a look must write nothing")


## **A warned blow swells toward its landing** (2026-09-30). A blow coming down
## on the Warden starts the riser so that it ends on the frame the blow lands; a
## blow far off, or one too quick for the riser, starts none.
func _test_a_blow_is_anticipated(field: Battlefield) -> void:
	var hero: Hero = field.hero
	var at: Vector2 = hero.global_position
	var near: EnemyGroundStrike = _strike(field, at, 1.4)
	var far: EnemyGroundStrike = _strike(field, at + Vector2(2400.0, 0.0), 1.4)
	var quick: EnemyGroundStrike = _strike(field, at, 0.2)
	# Shorter than the riser and long enough for it: the riser is played faster
	# to fit, which is the half a long warning never exercises.
	var short: EnemyGroundStrike = _strike(field, at + Vector2(20.0, 0.0), 0.5)
	var short_pitch: float = 0.0
	var short_left: float = 0.0
	var before: int = int((Sfx.debug_state().get("active", {}) as Dictionary).get("sfx_telegraph_rise", 0))
	var heard: bool = false
	var near_pitch: float = 0.0
	var near_left: float = 0.0
	var far_pitch: float = -1.0
	var quick_pitch: float = -1.0
	var waited: float = 0.0
	while waited < 2.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if is_instance_valid(near):
			near_pitch = near.rise_pitch
			near_left = near.rise_left
		if is_instance_valid(far):
			far_pitch = far.rise_pitch
		if is_instance_valid(quick):
			quick_pitch = quick.rise_pitch
		if is_instance_valid(short):
			short_pitch = short.rise_pitch
			short_left = short.rise_left
		var active: int = int((Sfx.debug_state().get("active", {}) as Dictionary).get("sfx_telegraph_rise", 0))
		heard = heard or active > before
	_check(near_pitch > 0.0 and heard, "a blow coming down on the Warden started no riser")
	_check(near_left > 0.0 and absf(Balance.TELEGRAPH_RISE_SECONDS / near_pitch - near_left) < 0.01,
		"the riser ends %.3fs from the landing, wanting it on the landing"
			% absf(Balance.TELEGRAPH_RISE_SECONDS / maxf(near_pitch, 0.001) - near_left))
	_check(near_pitch <= Balance.TELEGRAPH_RISE_FASTEST, "the riser played faster than its ceiling")
	_check(short_pitch > 1.2 and short_left > 0.0
		and absf(Balance.TELEGRAPH_RISE_SECONDS / short_pitch - short_left) < 0.01,
		"a half-second warning's riser ends %.3fs from the landing at %.2fx, wanting it played faster to land on it"
			% [absf(Balance.TELEGRAPH_RISE_SECONDS / maxf(short_pitch, 0.001) - short_left), short_pitch])
	_check(is_zero_approx(far_pitch), "a blow far from the Warden started a riser (%.2f)" % far_pitch)
	_check(is_zero_approx(quick_pitch), "a blow too quick for a riser started one (%.2f)" % quick_pitch)
	var source: String = FileAccess.get_file_as_string("res://scenes/battlefield/enemy_ground_strike.gd")
	_check(source.contains("Sfx.play_group(\"sfx_telegraph_rise\"") and not source.contains("play_group_at(\"sfx_telegraph_rise\""),
		"the riser is a telegraph and plays flat, never quietened by distance")


func _strike(field: Battlefield, at: Vector2, delay: float) -> EnemyGroundStrike:
	var strike := EnemyGroundStrike.new()
	strike.shape = EnemyGroundStrike.Shape.CIRCLE
	strike.reach = 90.0
	strike.delay = delay
	strike.damage = 0.0
	strike.position = at
	field.add_child(strike)
	return strike


## **A body goes down the way it was struck** (owner, 2026-10-07): killed from
## its left it is shoved and tips to its right about its feet, flashes white
## with the blow, and comes apart only after it is down; a dismissed summon
## only fades. Read off the real body's sprite.
func _test_a_body_falls_the_way_it_was_struck(field: Battlefield, near: Vector2) -> void:
	var body: Enemy = _stand_a_body(field, near + Vector2(0.0, 300.0))
	if body == null:
		_check(false, "no body to watch fall")
		return
	var home: Vector2 = body.sprite.position
	body.take_damage(body.health.max_hp * 10.0, body.global_position + Vector2(-60.0, 0.0), 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(body.sprite.self_modulate.r > 1.2, "a killing blow did not flash the body white")
	await _settle(Balance.ENEMY_DEATH_FALL_SECONDS + 0.04)
	if is_instance_valid(body):
		_check(body.sprite.rotation > 0.4, "a body struck from its left did not tip to its right (%.2f)"
			% body.sprite.rotation)
		_check(body.sprite.position.x > home.x + Balance.ENEMY_DEATH_SLIDE * 0.5,
			"a body struck from its left was not shoved right (%.1f from %.1f)"
			% [body.sprite.position.x, home.x])
		_check(is_instance_valid(body) and body.is_dying() and not body.is_queued_for_deletion(),
			"a body came apart before it was down")
	var summoned: Enemy = _stand_a_body(field, near + Vector2(200.0, 300.0))
	if summoned != null:
		var turn: float = summoned.sprite.rotation
		summoned.dismiss()
		await _settle(Balance.ENEMY_DEATH_FADE * 0.6)
		if is_instance_valid(summoned):
			_check(absf(summoned.sprite.rotation - turn) < 0.01, "a dismissed summon fell over like a kill")


func _settle(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _leave(run: Run) -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


## A plot the field itself says is buildable.
##
## Asked through `placement_problem`, which is the one function the build door
## and the placement cursor both go through - a gate that decided for itself
## what counts as open ground would be a second opinion about the map.
func _a_free_plot(field: Battlefield) -> Vector2i:
	for lane: int in 4:
		var candidate: Vector2i = field.free_anchor_near(lane, 8)
		if field.placement_problem(candidate).is_empty():
			return candidate
	return Vector2i(-9999, -9999)


func _a_shooting_tower() -> TowerData:
	var ids: Array = ContentDB.towers.keys()
	ids.sort()
	for id: String in ids:
		var kind := ContentDB.towers[id] as TowerData
		if kind == null or kind.is_well() or kind.damage <= 0.0:
			continue
		return kind
	return null


## A body that stands where it is put, because this gate is about what a tower
## and a corpse look like rather than about what either of them decides.
func _stand_a_body(field: Battlefield, at: Vector2) -> Enemy:
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	var kind: EnemyData = null
	for id: String in ids:
		var data := ContentDB.enemies[id] as EnemyData
		if data != null and data.category == EnemyData.Category.BREED:
			kind = data
			break
	if kind == null:
		return null
	var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
		.instantiate() as Enemy
	body.setup(kind, RunState.act, field, 1.0, 1.0, 1.0)
	field.add_child(body)
	body.global_position = at
	return body


## **A voice comes from the animal, not from the listener.**
##
## `play_at` exists, quietens by distance and hands its voice back past the
## cutoff - and every wildlife vocalisation and almost every companion sound was
## played flat, so a wolf across the outskirts was exactly as loud as one at the
## Warden's feet. `sfx_companion_down` in that same file has used `play_at` since
## it was written and nothing else in it did.
##
## It mattered more from 2026-09-16, when twenty-three species that had been mute
## were given voices: that fix made the road far noisier with sounds that did not
## attenuate, so it had to come with this one.
##
## **Narrowly scoped on purpose.** This is not a rule that every `Sfx.play` must
## carry a position - most should not. A menu click, a purse, the Warden's own
## breath and a hero standing at the pond they are fishing are all correctly
## flat, and "121 unpositioned call sites" is a count rather than a fault list.
## Only the files that make world sounds away from the camera are held.
##
## **It said "the two files" and there were three.** `wildlife_families.gd`
## announces a birth and a Wildblight frenzy - both at a place on the field,
## both with the position already in hand - and both were flat, so a birth
## across the outskirts was as loud as one underfoot. It was missed because
## the first pass went looking in the files named after the things that make
## noise, and a birth is made by the *families* system rather than by the
## animal. Found by reading the call sites while surveying what wildlife plays,
## not by anything failing.
func _test_a_voice_comes_from_where_it_is() -> void:
	var watched: Dictionary = {
		"res://scripts/systems/wildlife.gd": ["Sfx.play(kind.vocal_sfx"],
		"res://scripts/systems/wildlife_families.gd": ["Sfx.play(kind.vocal_sfx"],
		"res://scenes/battlefield/companion.gd": ["Sfx.play(_vocal",
			"Sfx.play(\"sfx_companion_"],
	}
	for path: String in watched:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			_check(false, "%s is missing" % path)
			continue
		var text: String = file.get_as_text()
		for flat: String in (watched[path] as Array):
			_check(not text.contains(flat),
				("%s plays `%s` with no position, so it is as loud from across the "
					+ "map as from underfoot") % [path, flat])


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[feel] " + why)
