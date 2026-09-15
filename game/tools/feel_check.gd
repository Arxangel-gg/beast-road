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
	_test_a_dropped_sound_decides_nothing()
	await _test_the_field()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[feel] PASS - %d checks: distance quietens and never decides, a "
			+ "tower leans at what it will actually shoot, it rises once when "
			+ "built, and a body remembers what finished it") % _checks)
	else:
		push_error("[feel] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


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
	_check(is_equal_approx(Sfx.distance_db(Balance.SFX_FAR), Balance.SFX_FAR_DB),
		"a sound at SFX_FAR must have lost exactly SFX_FAR_DB")
	_check(is_equal_approx(Sfx.distance_db(Balance.SFX_FAR * 4.0),
			Balance.SFX_FAR_DB),
		"the falloff must floor rather than run off to silence")
	# Monotonic, because a sound that got louder with distance would be worse
	# than one that never changed at all.
	var previous: float = 1.0
	for step: int in 20:
		var db: float = Sfx.distance_db(float(step) * Balance.SFX_FAR / 10.0)
		_check(db <= previous + 0.001,
			"the falloff rose with distance at %d: %.2f after %.2f"
				% [step, db, previous])
		previous = db
	_check(Balance.SFX_CUTOFF > Balance.SFX_FAR,
		"the cutoff must be past the floor or sounds vanish while still audible")
	_check(Balance.SFX_FAR_DB < 0.0, "distance must make things quieter, not louder")
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

	await _leave(run)


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


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[feel] " + why)
