extends Node

var _failures: PackedStringArray = []
var _run: Run


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	_run = load("res://scenes/run/run.tscn").instantiate() as Run
	add_child(_run)
	await get_tree().process_frame
	RunState.gain_currency(RunState.GOLD, 9999)
	RunState.gain_currency(RunState.WOOD, 9999)

	for data: TowerData in ContentDB.base_towers():
		_check(data.max_hp > 0.0, "%s has no structure durability" % data.id)

	var tower_data: TowerData = ContentDB.tower("ember_spire")
	var anchor: Vector2i = _run.battlefield.free_anchor_near(0)
	_check(_run.battlefield.try_build(anchor, tower_data).is_empty(),
		"test tower could not be built")
	await get_tree().process_frame
	var tower: Tower = _run.battlefield.tower_at_anchor(anchor)
	var health: Health = Health.of(tower)
	_check(health != null and health.max_hp > 0.0,
		"ordinary towers must expose Health")
	_check(tower.get("_damage_flames").size() >= 2,
		"tower silhouette did not produce smart damage-fire anchors")

	health.take_damage(health.max_hp * 0.58, Vector2.ZERO)
	await get_tree().process_frame
	_check(tower.needs_repair(), "damaged tower did not become repairable")
	var burning: int = 0
	for flame: Flame in tower.get("_damage_flames"):
		if flame.is_lit():
			burning += 1
	_check(burning >= 2, "heavily damaged tower did not ignite staged damage fires")
	var before: float = health.current_hp
	_check(_run.battlefield.try_repair_tower(anchor).is_empty() \
			and health.current_hp > before,
		"Preparation repair did not restore tower durability")

	await _check_firing_poses()
	var burrower: Enemy = _run.battlefield.spawn_enemy(ContentDB.enemy("burrower"), 0, 1.0)
	await get_tree().process_frame
	_check(burrower._pick_target() == tower,
		"tower-targeting enemy did not prefer the structure in its lane")

	# A support-foot plant is one authored event shared by camera, hero, enemies
	# and structures. Test its physical recipients here; CameraRig owns its
	# deterministic timing assertion in balance_test.
	EventBus.beast_step_landed.emit(Vector2(14.0, 5.0), 1.0)
	# By name, so a rename of the field does not fail here as a null cast that
	# takes the whole gate down with it - which is exactly what happened when
	# `_beast_impulse` became `_shoved`.
	var nudged: Variant = _run.battlefield.hero.get("_shoved")
	_check(nudged is Vector2 and (nudged as Vector2).length() > 0.0,
		"beast step did not nudge the hero (the field may have been renamed)")
	_check((burrower.get("_knockback") as Vector2).length() > 0.0,
		"beast step did not disturb enemies")
	_check(absf(float(tower.get("_step_wobble"))) > 0.0,
		"beast step did not wobble towers")

	# Firing shoves the tower and the shove settles.
	#
	# Both halves matter and the second is the one that rots quietly: a kick that
	# never fully decays leaves every tower on the field permanently a few pixels
	# off its own base, which nobody notices for months and then reads as the art
	# being misaligned.
	#
	# **Driven with a fixed delta rather than by awaiting real frames.** The kick
	# decays over `TOWER_FIRE_KICK_SECONDS` (0.17s) and the shove is squared, so
	# two frames totalling 116ms leave it under the half pixel asserted below.
	# A sweep running seventy-six gates back to back produces frames that long
	# regularly, and this gate failed once in a full sweep and passed three bare
	# re-runs — it was measuring machine load, not the code.
	#
	# Ticking the real function by hand keeps the subject identical and makes the
	# arithmetic the only variable.
	# **Nothing in its sights while the kick is measured.**
	#
	# A tower leans at what it is about to shoot (2026-09-15), and that lean is a
	# *second* legitimate offset from rest which persists for as long as a body
	# stands in reach. With the burrower still on the field this read 2.89 off and
	# named it as a kick that never settled, which it was not.
	#
	# The body goes rather than the bar moving: the half-pixel assertion below is
	# the whole point of this block, and a gate loosened to fit a feature stops
	# catching the failure it was written for.
	burrower.queue_free()
	await get_tree().process_frame

	const STEP: float = 1.0 / 60.0
	var home: Vector2 = tower.sprite.position
	tower.kick(tower.origin() + Vector2(200.0, 0.0))
	tower.call("_tick_step_wobble", STEP)
	_check(tower.sprite.position.distance_to(home) > 0.5,
		"firing must shove the tower off its rest position")
	_check(tower.sprite.position.x < home.x,
		"and shove it away from what it shot at, not toward it")
	var settle: float = Balance.TOWER_FIRE_KICK_SECONDS + 0.2
	var waited: float = 0.0
	while waited < settle:
		tower.call("_tick_step_wobble", STEP)
		waited += STEP
	_check(tower.sprite.position.distance_to(home) < 0.5,
		"and the shove must settle back, %.2f off"
			% tower.sprite.position.distance_to(home))

	# The city moves when it is carried and when it is hit.
	#
	# It had neither. A 512px city cannot breathe the way a tower does without
	# reading as wobbling masonry, so its idle is the beast's gait - which is also
	# the truthful answer, since it is standing on the beast's back. And being
	# struck flashed it white while it otherwise stood there as though nothing had
	# touched it: shaking the camera says "you were hit", shaking the city says
	# "the city was hit", and only the first sentence was being spoken.
	var town: TownCore = _run.battlefield.town
	if town != null and town.sprite != null:
		# Ticked to a true standstill first, with a fixed delta, for the reason
		# the tower block above uses one: the gait the beast step kicked decays on
		# its own clock, so a snapshot taken mid-decay is a moving target and
		# "returns to within half a pixel of it" measures the phase rather than
		# the shudder. Both channels reach zero and `_tick_motion` then returns on
		# its first line, so this settles rather than spins.
		for _calm: int in 600:
			town.call("_tick_motion", 1.0 / 60.0)
		var rest: Vector2 = town.sprite.position
		var upright: float = town.sprite.rotation
		EventBus.beast_step_landed.emit(Vector2.RIGHT, 1.0)
		await get_tree().process_frame
		_check(not is_equal_approx(town.sprite.rotation, upright),
			"the city must rock when the beast puts a foot down")

		# **The ring over the city shows only while the city is hurt.** A ring
		# that is always there is furniture, and the walls are whole for most
		# of a good run - so the one thing on the field that ends the run would
		# have become something the eye stopped reading.
		# Searched from the run rather than from the town: `_setup_visual_depth`
		# reparents the visual host into the battlefield's sorted layer, so the
		# ring is not a descendant of the `TownCore` node that owns it.
		var ring: Control = _find_ring(_run)
		_check(ring != null, "the city has no health ring")
		if ring != null:
			_check(not ring.visible, "the ring is drawn while the city is whole")

		town.health.take_damage(20.0, town.global_position + Vector2(300.0, 0.0))
		await get_tree().process_frame
		if ring != null:
			# Two frames: the ring is refreshed in `_process`, which has not run
			# yet on the frame the blow landed.
			await get_tree().process_frame
			_check(ring.visible,
				"the city took a blow and its ring stayed hidden")
		_check(town.sprite.position.distance_to(rest) > 0.5,
			"and must shudder when it is struck")
		var town_settle: float = Balance.TOWN_JOLT_SECONDS + 0.5
		var town_waited: float = 0.0
		while town_waited < town_settle:
			town.call("_tick_motion", 1.0 / 60.0)
			town_waited += 1.0 / 60.0
		_check(town.sprite.position.distance_to(rest) < 0.5,
			"and both must settle, %.2f off" % town.sprite.position.distance_to(rest))

	if _failures.is_empty():
		print("[structure] PASS — durability, repair, siege targeting, damage fires, "
			+ "step impulse, host/guest firing poses, recoil and a city that rocks and shudders")
	else:
		for failure: String in _failures:
			push_error("[structure] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


## Exercise the host's shared kick and the actual guest notification path. The
## puppet has an empty field, as happens when the target dies before delivery.
func _check_firing_poses() -> void:
	var scene := load("res://scenes/battlefield/tower.tscn") as PackedScene
	for value: Variant in ContentDB.towers.values():
		var data := value as TowerData
		if data == null:
			continue
		var id: String = data.id
		var one := scene.instantiate() as Tower
		one.setup(data, 1, Vector2i(40, 40), _run.battlefield)
		add_child(one)
		one.set_process(false)
		var poses: Array[Texture2D] = GameData.load_attack_frames(one.data.get_sprite_path())
		_check(poses.size() == 3, "%s needs three firing poses" % id)
		if poses.size() == 3:
			for remote: bool in [false, true]:
				one.puppet = remote
				if remote:
					one.fire_remote(one.origin() + Vector2.RIGHT * 200.0)
				else:
					one.kick(one.origin() + Vector2.RIGHT * 200.0)
				_check(one.sprite.texture == poses[0], "%s discharge must start immediately" % id)
				var frozen_left: float = one._attack_left
				await get_tree().process_frame
				await get_tree().process_frame
				_check(one._attack_left == frozen_left and one.sprite.texture == poses[0],
					"a suspended tower's discharge must not advance on a detached timer")
				one._tick_step_wobble(Balance.TOWER_FIRE_ANIMATION_SECONDS * 0.5)
				_check(one.sprite.texture == poses[1], "%s discharge must advance" % id)
				one._tick_step_wobble(Balance.TOWER_FIRE_ANIMATION_SECONDS * 0.3)
				_check(one.sprite.texture == poses[2], "%s must show the recovery pose" % id)
				one.kick(one.origin())
				_check(one.sprite.texture == poses[0], "%s rapid fire must restart the discharge" % id)
				one._tick_step_wobble(Balance.TOWER_FIRE_ANIMATION_SECONDS + 0.01)
				_check(one._idle_frames.has(one.sprite.texture), "%s must return to idle" % id)
			# Simulate a not-yet-authored tower without tying this fallback to an
			# id that the next art batch may legitimately upgrade.
			one._attack_frames.clear()
			one.kick(one.origin())
			one._tick_step_wobble(0.01)
			_check(one._idle_frames.has(one.sprite.texture),
				"missing discharge art must retain the authored idle fallback")
		one.queue_free()
		await get_tree().process_frame


## The city's health ring, wherever it ended up in the visual host.
func _find_ring(from: Node) -> Control:
	for child: Node in from.get_children():
		if child.name == "HealthRing":
			return child as Control
		var deeper: Control = _find_ring(child)
		if deeper != null:
			return deeper
	return null
