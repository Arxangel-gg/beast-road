extends Node
## The fast-forward (2026-09-21), and the one rule that makes it safe: the
## clock's base rate has one owner, and everything that borrows the clock gives
## it back to that owner rather than to a literal.
##
## - **A hitstop gives the clock back at the chosen rate.** Before this the
##   freeze, the boss-fall slow and three doors in `GameDirector` each wrote
##   `Engine.time_scale = 1.0` when they were done, so a 2x toggle laid beside
##   them would have been undone by the first blow that landed. Driven on a
##   real `Hitstop` with the wall clock, because reading the constant back
##   would pass on a build that restores to one.
## - **Company refuses it.** A guest's world is facts on the host's clock, and
##   a host that is merely listening may be joined - so any session at all
##   holds the road at one speed.
## - **Every reset goes through the owner.** A source walk, because the fault
##   it catches is a *new* door writing the literal, and nothing else can see
##   a door that has not been driven.

const TAG: String = "[game-speed]"
const OWNER: String = "res://scripts/systems/game_speed.gd"
const ROOTS: Array[String] = ["res://scenes", "res://scripts", "res://autoload"]

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	_test_the_base_rate_has_one_owner()
	_test_a_hitstop_gives_the_clock_back()
	_test_company_refuses_it()
	_test_every_reset_goes_through_it()
	_finish()


func _test_the_base_rate_has_one_owner() -> void:
	GameSpeed.reset()
	_check(is_equal_approx(Engine.time_scale, 1.0) and not GameSpeed.is_fast(),
		"a reset is one speed")
	_check(Balance.GAME_SPEED_FAST > 1.0 and Balance.GAME_SPEED_FAST <= 3.0,
		"the fast rate is faster than the road and not a slideshow (%.1f)" % Balance.GAME_SPEED_FAST)
	GameSpeed.set_fast(true)
	_check(GameSpeed.is_fast() and is_equal_approx(Engine.time_scale, Balance.GAME_SPEED_FAST),
		"fast is the authored rate (%.2f)" % Engine.time_scale)
	GameSpeed.set_fast(false)
	_check(is_equal_approx(Engine.time_scale, 1.0), "and it comes back to one")
	GameSpeed.set_fast(true)
	GameSpeed.reset()
	_check(not GameSpeed.is_fast() and is_equal_approx(Engine.time_scale, 1.0),
		"a run beginning forgets the choice")


func _test_a_hitstop_gives_the_clock_back() -> void:
	GameSpeed.set_fast(true)
	var stop := Hitstop.new()
	add_child(stop)
	stop.call("_on_requested", 0.02)
	_check(is_equal_approx(Engine.time_scale, Balance.HITSTOP_TIME_SCALE),
		"the freeze takes the clock (%.3f)" % Engine.time_scale)
	OS.delay_msec(60)
	stop.call("_process", 0.0)
	_check(is_equal_approx(Engine.time_scale, Balance.GAME_SPEED_FAST),
		"and gives it back at the chosen rate, not at one (%.2f)" % Engine.time_scale)
	stop.queue_free()
	GameSpeed.reset()


func _test_company_refuses_it() -> void:
	var was: int = int(Coop.get("_state"))
	for state: int in [Coop.State.HOSTING, Coop.State.CONNECTING, Coop.State.CONNECTED]:
		Coop.set("_state", state)
		GameSpeed.reset()
		GameSpeed.set_fast(true)
		_check(not GameSpeed.is_fast() and is_equal_approx(Engine.time_scale, 1.0),
			"a session in state %d holds the road at one speed" % state)
		_check(not GameSpeed.allowed(), "and says so (state %d)" % state)
	Coop.set("_state", was)
	GameSpeed.reset()
	_check(GameSpeed.allowed(), "alone, it is allowed")


func _test_every_reset_goes_through_it() -> void:
	var offenders: Array[String] = []
	for root: String in ROOTS:
		for path: String in _scripts_under(root):
			if path == OWNER:
				continue
			var text: String = FileAccess.get_file_as_string(path)
			if text.contains("Engine.time_scale = 1.0"):
				offenders.append(path)
	_check(offenders.is_empty(),
		"every clock restore goes through GameSpeed; these write the literal: %s" % [offenders])


func _scripts_under(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while not name.is_empty():
		var path: String = root.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				out.append_array(_scripts_under(path))
		elif name.ends_with(".gd"):
			out.append(path)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _check(condition: bool, why: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failures += 1
	push_error("%s %s" % [TAG, why])
	return false


func _finish() -> void:
	for _frame: int in 6:
		await get_tree().process_frame
	if _failures == 0:
		print("%s PASS - %d checks" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
