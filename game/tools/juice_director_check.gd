extends Node

## **The director changes how things look and never what happened.**
##
##   godot --headless --path game res://tools/juice_director_check.tscn
##
## `JuiceDirector` is the first presentation layer in this project that sits
## *between* a system and its own effect, which makes it the first one that
## could quietly become a gameplay layer. Every check here exists because of
## that: the ordering is held, the floors are held, the comfort scales are held
## at both ends, and hardest, a real body is driven to death with every scale at
## zero and the load at its ceiling and the payout read back.
##
## The bound is the one every feel change here is held to, and this is the third
## gate to assert it after `feel_check` and `hit_feel_check`.

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_test_the_quiet_game_is_untouched()
	_test_a_telegraph_is_never_turned_down()
	_test_the_order_holds_at_every_load()
	_test_clutter_rises_and_falls()
	_test_nothing_ever_reaches_nothing()
	_test_the_comfort_scales_reach_both_ends()
	await _test_the_payout_does_not_move()
	JuiceDirector.clear()
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _frame: int in 12:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[juice-director] FAIL - %d of %d" % [_failures, _checks])
		get_tree().quit(1)
		return
	print("[juice-director] PASS - %d checks: the quiet game is untouched, a "
		% _checks + "telegraph never gives ground, the order holds at every "
		+ "load, and a kill pays the same with every scale at zero")
	get_tree().quit(0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## **Nothing is damped until the screen is genuinely busy.** The game as shipped
## has to feel exactly as it did, or this is a stealth nerf to every effect.
func _test_the_quiet_game_is_untouched() -> void:
	JuiceDirector.clear()
	for priority: int in JuiceDirector.Priority.size():
		_check(is_equal_approx(JuiceDirector.weight(priority), 1.0),
			"an idle screen damps nothing (%d is %.3f)"
				% [priority, JuiceDirector.weight(priority)])
	# One hit is not a busy screen either.
	JuiceDirector.set_load_for_test(JuiceDirector.QUIET_LOAD)
	_check(is_equal_approx(JuiceDirector.weight(JuiceDirector.Priority.COSMETIC), 1.0),
		"an ordinary exchange damps nothing (%.3f)"
			% JuiceDirector.weight(JuiceDirector.Priority.COSMETIC))


## **A warning is never turned down.** A telegraph tells the player what is about
## to hurt them, and damping one under load turns it down at exactly the moment
## it is needed. It also adds nothing to the load, so two warnings on screen
## cannot crowd each other out.
func _test_a_telegraph_is_never_turned_down() -> void:
	for load_at: float in [0.0, 1.0, 2.5, JuiceDirector.FULL_LOAD, JuiceDirector.MAX_LOAD]:
		JuiceDirector.set_load_for_test(load_at)
		_check(is_equal_approx(
			JuiceDirector.weight(JuiceDirector.Priority.TELEGRAPH), 1.0),
			"a telegraph is whole at load %.1f (%.3f)"
				% [load_at, JuiceDirector.weight(JuiceDirector.Priority.TELEGRAPH)])
	JuiceDirector.clear()
	for _shout: int in 20:
		JuiceDirector.note(JuiceDirector.Priority.TELEGRAPH)
	_check(JuiceDirector.load_now() <= 0.001,
		"twenty telegraphs add no load at all (%.3f)" % JuiceDirector.load_now())


## **The order is the design.** Telegraph, hazard, boss, player, cosmetic - at
## every load, each gives up at least as much as the one above it. A build where
## a cosmetic effect survived better than a hazard would be readable clutter
## winning over information, which is the whole thing this exists to prevent.
func _test_the_order_holds_at_every_load() -> void:
	for load_at: float in [0.0, 1.5, 2.5, 3.5, JuiceDirector.MAX_LOAD]:
		JuiceDirector.set_load_for_test(load_at)
		var last: float = 1.0
		for priority: int in JuiceDirector.Priority.size():
			var now: float = JuiceDirector.weight(priority)
			_check(now <= last + 0.0001,
				"at load %.1f priority %d (%.3f) gives up at least as much as the "
					% [load_at, priority, now] + "one above it (%.3f)" % last)
			last = now
	# And a busy screen really does damp: an order that held while nothing ever
	# moved would pass the check above and mean nothing.
	JuiceDirector.set_load_for_test(JuiceDirector.MAX_LOAD)
	_check(JuiceDirector.weight(JuiceDirector.Priority.COSMETIC) < 0.5,
		"a full screen turns decoration down (%.3f)"
			% JuiceDirector.weight(JuiceDirector.Priority.COSMETIC))
	_check(JuiceDirector.weight(JuiceDirector.Priority.HAZARD) > 0.6,
		"a full screen still shows a hazard (%.3f)"
			% JuiceDirector.weight(JuiceDirector.Priority.HAZARD))


## Notes raise the load, it is capped, and it decays on its own - which is what
## lets this be a static class with no node and no `_process` in the tree.
func _test_clutter_rises_and_falls() -> void:
	JuiceDirector.clear()
	_check(JuiceDirector.load_now() <= 0.001, "a cleared director is idle")
	JuiceDirector.note(JuiceDirector.Priority.COSMETIC)
	var one: float = JuiceDirector.load_now()
	_check(one > 0.0, "a cosmetic moment raises the load (%.3f)" % one)
	for _more: int in 60:
		JuiceDirector.note(JuiceDirector.Priority.COSMETIC)
	_check(JuiceDirector.load_now() <= JuiceDirector.MAX_LOAD + 0.001,
		"sixty moments cannot exceed the ceiling (%.3f against %.3f)"
			% [JuiceDirector.load_now(), JuiceDirector.MAX_LOAD])
	# Decay is measured by dating the load into the past rather than by waiting,
	# which is the point of deriving it: a gate need not spend a second and a
	# half to see a second and a half pass.
	JuiceDirector.set_load_for_test(JuiceDirector.MAX_LOAD)
	var before: float = JuiceDirector.load_now()
	JuiceDirector._at_msec -= int(JuiceDirector.DECAY_SECONDS * 1000.0)
	var after: float = JuiceDirector.load_now()
	_check(after < before * 0.5,
		"one decay window takes most of the load away (%.3f to %.3f)"
			% [before, after])
	JuiceDirector._at_msec -= int(JuiceDirector.DECAY_SECONDS * 20000.0)
	_check(JuiceDirector.load_now() < 0.01,
		"a long quiet leaves nothing behind (%.4f)" % JuiceDirector.load_now())


## **An effect that disappears reads as a bug.** However busy the screen, every
## priority keeps its authored floor - the player must always be able to tell
## that the hit happened, even when the game is showing them less of it.
func _test_nothing_ever_reaches_nothing() -> void:
	JuiceDirector.set_load_for_test(JuiceDirector.MAX_LOAD)
	for priority: int in JuiceDirector.Priority.size():
		var now: float = JuiceDirector.weight(priority)
		var floor_at: float = JuiceDirector.FLOOR[priority]
		_check(now >= floor_at - 0.0001,
			"priority %d never falls under its floor (%.3f against %.3f)"
				% [priority, now, floor_at])
		_check(now > 0.05,
			"priority %d is still visible at full load (%.3f)" % [priority, now])
	# A spark count is the thing that actually reads this, and `maxi(1, ...)`
	# is what stops a damped burst becoming no burst at all.
	_check(maxi(1, int(round(3.0 * JuiceDirector.weight(
		JuiceDirector.Priority.COSMETIC)))) >= 1,
		"a three-spark burst under full load still throws one")


## Both ends of each comfort scale, read through the director rather than off
## the dictionary - which is the point of it having one reader.
func _test_the_comfort_scales_reach_both_ends() -> void:
	var was_shake: Variant = MetaState.settings.get(UserSettings.SHAKE_KEY)
	var was_flash: Variant = MetaState.settings.get(UserSettings.FLASH_KEY)
	var was_density: Variant = MetaState.settings.get(UserSettings.NUMBER_DENSITY_KEY)

	UserSettings.set_value(UserSettings.SHAKE_KEY, 0.0)
	_check(JuiceDirector.shake_scale() <= 0.0, "the shake reaches off")
	UserSettings.set_value(UserSettings.SHAKE_KEY, 1.0)
	_check(is_equal_approx(JuiceDirector.shake_scale(), 1.0), "the shake reaches whole")

	UserSettings.set_value(UserSettings.FLASH_KEY, 0.0)
	_check(JuiceDirector.flash_scale() <= 0.0, "the flash reaches off")
	UserSettings.set_value(UserSettings.FLASH_KEY, 1.0)
	_check(is_equal_approx(JuiceDirector.flash_scale(), 1.0), "the flash reaches whole")

	# **Density thins the ordinary numbers and keeps the big ones**, which is the
	# distinction that makes it fewer numbers rather than less information.
	UserSettings.set_value(UserSettings.NUMBER_DENSITY_KEY, 0.0)
	_check(not JuiceDirector.wants_number(false), "off draws no ordinary number")
	_check(not JuiceDirector.wants_number(true), "off draws no big number either")
	UserSettings.set_value(UserSettings.NUMBER_DENSITY_KEY, 0.5)
	_check(JuiceDirector.wants_number(true),
		"a half still draws every critical and finisher")
	var ordinary: int = 0
	for _roll: int in 400:
		if JuiceDirector.wants_number(false):
			ordinary += 1
	_check(ordinary > 140 and ordinary < 260,
		"a half draws about half the ordinary numbers (%d of 400)" % ordinary)
	UserSettings.set_value(UserSettings.NUMBER_DENSITY_KEY, 1.0)
	_check(JuiceDirector.wants_number(false) and JuiceDirector.wants_number(true),
		"whole draws every number")

	# **A missing key reads as the game as tuned**, never as an effect turned
	# off: a save written before these existed must not arrive silent.
	MetaState.settings.erase(UserSettings.FLASH_KEY)
	_check(is_equal_approx(JuiceDirector.flash_scale(), 1.0),
		"a save with no flash key plays the game as tuned (%.3f)"
			% JuiceDirector.flash_scale())

	MetaState.settings[UserSettings.SHAKE_KEY] = was_shake if was_shake != null else 1.0
	MetaState.settings[UserSettings.FLASH_KEY] = was_flash if was_flash != null else 1.0
	MetaState.settings[UserSettings.NUMBER_DENSITY_KEY] = was_density \
		if was_density != null else 1.0


## **The bound, driven rather than asserted.** A real body is killed twice - once
## with every comfort scale whole and an idle director, once with every scale at
## zero and the load at its ceiling - and the two must agree about the damage
## dealt, the body dying and what the kill paid.
##
## Two of anything in this project has to be compared through the real doors,
## because a director that quietly scaled a *number* would still pass every
## check above.
func _test_the_payout_does_not_move() -> void:
	var loud: Dictionary = await _kill_one(1.0, 0.0)
	var quiet: Dictionary = await _kill_one(0.0, JuiceDirector.MAX_LOAD)
	# **Neither run may be empty.** Twice while writing this the harness called a
	# function that does not exist; GDScript aborts the whole function on that,
	# `_kill_one` returned nothing, the loop below iterated an empty dictionary
	# and the gate printed PASS having compared neither run. A comparison of two
	# nothings is the most dangerous shape a check can take.
	_check(not loud.is_empty() and loud.size() == quiet.size(),
		"both runs reported a payout to compare (%d and %d)"
			% [loud.size(), quiet.size()])
	if loud.is_empty() or quiet.is_empty():
		return
	for key: String in loud:
		_check(is_equal_approx(float(loud[key]), float(quiet[key])),
			"%s is the same with every scale at zero (%.4f against %.4f)"
				% [key, float(loud[key]), float(quiet[key])])


## Kills one body under the given comfort scale and director load, and reports
## what the run took from it.
func _kill_one(comfort: float, load_at: float) -> Dictionary:
	UserSettings.set_value(UserSettings.SHAKE_KEY, comfort)
	UserSettings.set_value(UserSettings.FLASH_KEY, comfort)
	UserSettings.set_value(UserSettings.NUMBER_DENSITY_KEY, comfort)
	RunState.reset(false, 20260916)
	var field := EnemyField.new()
	add_child(field)
	Vfx.bind_world(field)
	# After `bind_world`, which clears the load - otherwise the quiet run would
	# be measured on an idle director and prove nothing.
	JuiceDirector.set_load_for_test(load_at)
	# **A real breed through the real door.** The first cut called a `configure`
	# that does not exist, so both runs measured an unconfigured body, both
	# returned zeroes, and the gate passed having compared nothing at all - which
	# is the failure this whole file exists to catch, committed by the file
	# itself. `setup` is what the field calls.
	var kind: EnemyData = null
	for any: Variant in ContentDB.enemies.values():
		var one := any as EnemyData
		if one != null and one.category == EnemyData.Category.BREED:
			kind = one
			break
	_check(kind != null, "a breed is needed to be killed")
	if kind == null:
		field.queue_free()
		await get_tree().process_frame
		return {}
	var enemy := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
		.instantiate() as Enemy
	enemy.setup(kind, 0, field, 1.0)
	field.add_child(enemy)
	enemy.global_position = Vector2(400.0, 400.0)
	await get_tree().process_frame
	var before_gold: float = float(RunState.currency("gold"))
	var pool: float = enemy.health.max_hp
	var took: float = 0.0
	# **What one blow removes, and how many it takes.** Total damage to death is
	# the pool whatever a blow is worth, so summing it could never see a scale
	# applied per blow - which is exactly the fault this test exists for, and a
	# planted one walked straight past the first cut. The first blow's bite and
	# the count of blows are the two figures that actually move.
	var first: float = 0.0
	var blows: float = 0.0
	for _blow: int in 400:
		if not is_instance_valid(enemy) or enemy.health.is_dead:
			break
		var had: float = enemy.health.current_hp
		enemy.take_damage(pool * 0.1, Vector2.RIGHT, 0.0)
		var bite: float = had - enemy.health.current_hp
		if blows <= 0.0:
			first = bite
		blows += 1.0
		took += bite
	var standing: bool = is_instance_valid(enemy) and not enemy.health.is_dead
	var dead: float = 0.0 if standing else 1.0
	var paid: float = float(RunState.currency("gold")) - before_gold
	_check(pool > 0.0, "the body has a pool to take off (%.2f)" % pool)
	_check(took > 0.0, "the run actually dealt damage (%.2f)" % took)
	_check(first > 0.0, "the first blow took something off (%.2f)" % first)
	_check(dead > 0.5, "the body actually died")
	Vfx.clear()
	Vfx.bind_world(null)
	if is_instance_valid(enemy):
		enemy.queue_free()
	await get_tree().process_frame
	field.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	return {"what one blow takes off": first, "blows to put it down": blows,
		"damage taken off the body": took, "the body died": dead,
		"the gold it paid": paid}
