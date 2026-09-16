extends Node

## The wave library: every act has formations of its own, and a quiet one ends.
##
##   godot --headless --path game res://tools/wave_library_check.tscn
##
## Owner ruling, 2026-09-15: build the wave-type library first, then set the wave
## count by measuring what it supports.
##
## **The library was already half built and capped at three acts.** Ten
## formations existed and `WaveArchetypeData.minimum_act` was
## `@export_range(1, 3)` on a ten-act road, so acts IV to X drew from exactly the
## pool Act I did. **That is the sixth hardcoded three-act range in this
## project**, after the relic counter, the Chronicle's `minimum_act`, the
## campaign tiers' boss table, `wildlife_spawn_check` and the enemy affixes - and
## every one of them was silent, because a range that is too small does not error,
## it just never deals the thing nobody authored for the acts it excludes.
##
## **Four ways this goes wrong, and three of them say nothing:**
##
## - **An act with nothing of its own.** The failure above. Checked per act, and
##   the pool must *grow* - a last act drawing from the first act's set is a
##   campaign whose formations stopped meaning anything two thirds along.
## - **A formation nothing can deal.** One naming a signature enemy that does not
##   exist, or asking for a lane pattern the road cannot make, is content that
##   draws and then does nothing it says.
## - **A quiet wave that never ends.** A wave closes when its queue is empty and
##   no bodies stand. A calm formation has an empty queue by construction, so it
##   must close on the next tick - and if it did not, the run would stop for ever
##   on a wave with nothing in it, which is the worst failure in this file.
## - **A quiet wave that pays.** Its price is a wave of purse the player does not
##   get. If a calm wave earned kill income it would be a strictly better wave and
##   every player would want them all.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_act_has_formations()
	_test_every_formation_can_be_dealt()
	await _test_a_quiet_wave_ends()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[wave-library] PASS - %d checks over %d formations: every act "
			+ "draws from its own pool, every formation can be dealt, and a "
			+ "quiet wave ends without paying")
			% [_checks, ContentDB.wave_archetypes.size()])
	else:
		push_error("[wave-library] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Every act meets formations of its own, and the pool grows.**
func _test_every_act_has_formations() -> void:
	var pool_at: Dictionary = {}
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var count: int = 0
		for value: Variant in ContentDB.wave_archetypes.values():
			var wave := value as WaveArchetypeData
			if wave != null and wave.minimum_act <= act:
				count += 1
		pool_at[act] = count
		_check(count >= 4,
			("act %d draws from %d formations, which is a procession rather "
				+ "than a campaign") % [act, count])
	_check(int(pool_at[Balance.ACT_COUNT]) > int(pool_at[1]),
		("act %d draws from the same %d formations as act 1 - the back of the "
			+ "road never meets anything it has not already seen")
			% [Balance.ACT_COUNT, int(pool_at[1])])
	var latest: int = 0
	for value: Variant in ContentDB.wave_archetypes.values():
		var wave := value as WaveArchetypeData
		if wave != null:
			latest = maxi(latest, wave.minimum_act)
	_check(latest >= Balance.ACT_COUNT - 2,
		("the latest formation in the game arrives in act %d of %d, so the last "
			+ "acts have nothing of their own") % [latest, Balance.ACT_COUNT])


## **A formation that cannot be dealt is content nobody meets.**
func _test_every_formation_can_be_dealt() -> void:
	var calm_count: int = 0
	for value: Variant in ContentDB.wave_archetypes.values():
		var wave := value as WaveArchetypeData
		if wave == null:
			continue
		_check(not wave.display_name.strip_edges().is_empty(),
			"%s has no name to show" % wave.id)
		_check(not wave.description.strip_edges().is_empty(),
			"%s says nothing about itself" % wave.id)
		_check(wave.selection_weight > 0.0,
			"%s can never be drawn, so it is content nobody meets" % wave.id)
		_check(wave.minimum_act >= 1 and wave.minimum_act <= Balance.ACT_COUNT,
			"%s first appears in act %d of %d"
				% [wave.id, wave.minimum_act, Balance.ACT_COUNT])
		if not wave.signature_enemy_id.is_empty():
			_check(ContentDB.enemy(wave.signature_enemy_id) != null,
				("%s names '%s' as its signature and no such breed exists - the "
					+ "formation deals and its centrepiece never arrives")
					% [wave.id, wave.signature_enemy_id])
		if wave.calm:
			calm_count += 1
			# A quiet wave that is common is not a breather, it is the game
			# taking the afternoon off.
			_check(wave.selection_weight <= 0.5,
				("%s is quiet and weighted %.2f - a breather that comes often "
					+ "is the road not happening") % [wave.id, wave.selection_weight])
			_check(wave.minimum_act >= 3,
				("%s is quiet and may be dealt in act %d - the opening is where "
					+ "a player is learning that waves arrive")
					% [wave.id, wave.minimum_act])
	_check(calm_count >= 1, "nothing in the library is ever quiet")
	_check(calm_count <= 3,
		"%d of the formations are quiet, which is a lot of nothing" % calm_count)


## **Driven on the real director**, because the failure worth catching is a wave
## with nothing in it that therefore never ends.
func _test_a_quiet_wave_ends() -> void:
	var quiet: WaveArchetypeData = null
	for value: Variant in ContentDB.wave_archetypes.values():
		var wave := value as WaveArchetypeData
		if wave != null and wave.calm:
			quiet = wave
			break
	_check(quiet != null, "a quiet formation is needed to drive one")
	if quiet == null:
		return
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null, "there must be a field to send a wave at")
	if field == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	var director: WaveDirector = field.wave_director
	# **Stopped to clear the road, then started again to measure it.**
	#
	# `_process` returns on its first line while the director is stopped, so a
	# hand-driven tick against a stopped director measures nothing and reads as a
	# wave that never ends - which is exactly what the first cut of this gate
	# reported, and it was the harness rather than the director.
	director.stop()
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()
	for _frame: int in 3:
		await get_tree().process_frame
	_check(field.enemy_count() <= 0,
		"the road must be empty before a quiet wave is measured on it")
	director.set("_running", true)

	var purse_before: int = RunState.currency(RunState.GOLD)
	var waves_before: int = RunState.wave_number
	director.set("_preview_archetype", quiet)
	director.set("_preview_lanes", [0] as Array[int])
	director.call("_begin_wave")
	_check(bool(director.get("_wave_active")),
		"a quiet wave did not start")
	_check(RunState.wave_number == waves_before + 1,
		"a quiet wave did not count as a wave")
	_check((director.get("_spawn_queue") as Array).is_empty(),
		"a quiet wave queued %d bodies"
			% (director.get("_spawn_queue") as Array).size())

	# **And it ends.** The same door every other wave ends through: an empty
	# queue with nothing standing. If this hangs, the run hangs.
	var waited: float = 0.0
	while waited < 3.0 and bool(director.get("_wave_active")):
		director.call("_process", 1.0 / 60.0)
		waited += 1.0 / 60.0
	_check(not bool(director.get("_wave_active")),
		("a quiet wave was still running after %.1fs - a wave with nothing in "
			+ "it that cannot end is a run that cannot continue") % waited)
	# **And it paid nothing.** Its price is the purse it did not earn.
	_check(RunState.currency(RunState.GOLD) <= purse_before,
		"a quiet wave paid %d Gold, which makes it a strictly better wave"
			% (RunState.currency(RunState.GOLD) - purse_before))

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[wave-library] " + why)
