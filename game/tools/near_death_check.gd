extends Node

## **The edge of death is heard** (`Vfx._tick_near_death`,
## `AudioBuses.set_near_death`, triage of 2026-10-07).
##
## Driven through the signal the vignette already listens to: above a fifth of
## health nothing changes; under it the world's buses close over - eased, never
## snapped - while the SFX bus, where flat sounds play, is left alone; a heart
## beats, faster the nearer the end; a Warden at nothing hears no heart and an
## open world; a settled run cannot raise it; and clearing the red edge
## releases the sound at once.

const TAG: String = "[near_death]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _held_phase: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_held_phase = RunState.phase
	RunState.phase = RunState.Phase.ROAD_BATTLE
	AudioBuses.ensure_placement()
	Vfx.clear_vignette()
	await _test_healthy()
	await _test_eased_and_clear()
	await _test_the_heart_quickens()
	await _test_down()
	await _test_settled()
	Vfx.clear_vignette()
	RunState.phase = _held_phase
	for stage: String in ["healthy", "eased", "heart", "down", "settled"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: quiet above a fifth, the world eased shut under it and the flat bus left clear, a heart that quickens, none at nothing, none once settled, and released with the red edge" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _health(current: float) -> void:
	EventBus.hero_health_changed.emit(current, 100.0)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _test_healthy() -> void:
	var before: int = Vfx.heartbeats
	_health(80.0)
	await _wait(0.6)
	_check(Vfx.near_death_share() <= 0.0, "a Warden at 80%% hears a closing world (%.2f)" % Vfx.near_death_share())
	_check(Vfx.heartbeats == before, "a Warden at 80%% hears a heart (%d beats)" % (Vfx.heartbeats - before))
	_check(not bool(AudioBuses.near_death_state(AudioBuses.AMBIENCE)["on"]),
		"the ambience is closed over at 80%")
	_reached.append("healthy")


func _test_eased_and_clear() -> void:
	var sfx_bus: int = AudioServer.get_bus_index(AudioBuses.SFX)
	var sfx_effects: int = AudioServer.get_bus_effect_count(sfx_bus)
	_health(10.0)
	# The awaited frame resumes before `Vfx` has ticked it, so a few.
	for _f: int in 3:
		await get_tree().process_frame
	_check(Vfx.near_death_share() > 0.0 and Vfx.near_death_share() < 0.45,
		"one frame after the blow the world is shut at once, not eased (%.2f of 0.5)" % Vfx.near_death_share())
	await _wait(1.0)
	_check(absf(Vfx.near_death_share() - 0.5) < 0.02,
		"at 10%% the world settles at half shut (%.2f)" % Vfx.near_death_share())
	for name: String in [AudioBuses.AMBIENCE, AudioBuses.WEATHER, AudioBuses.placement_name(2, false),
			AudioBuses.placement_name(0, true)]:
		var state: Dictionary = AudioBuses.near_death_state(name)
		_check(bool(state["on"]), "%s is not closed over at 10%%" % name)
		_check(float(state["cutoff"]) < 8000.0 and float(state["cutoff"]) > Balance.NEAR_DEATH_CUTOFF_HZ,
			"%s is closed to %.0f Hz at half, outside the eased range" % [name, float(state["cutoff"])])
	_check(AudioServer.get_bus_effect_count(sfx_bus) == sfx_effects
			and not bool(AudioBuses.near_death_state(AudioBuses.SFX)["on"]),
		"the SFX bus was closed over - the interface, the telegraphs and the heart must stay clear")
	_reached.append("eased")


func _test_the_heart_quickens() -> void:
	_health(10.0)
	await _wait(0.2)
	var start: int = Vfx.heartbeats
	await _wait(3.0)
	var shallow: int = Vfx.heartbeats - start
	_health(1.0)
	await _wait(0.6)
	start = Vfx.heartbeats
	await _wait(3.0)
	var deep: int = Vfx.heartbeats - start
	_check(shallow >= 2, "at 10%% the heart beat %d times in three seconds" % shallow)
	_check(deep > shallow, "the heart does not quicken nearer the end (%d at 10%%, %d at 1%%)" % [shallow, deep])
	_check(float(AudioBuses.near_death_state(AudioBuses.AMBIENCE)["cutoff"]) < 1500.0,
		"at 1%% the world is not nearly shut (%.0f Hz)" % float(AudioBuses.near_death_state(AudioBuses.AMBIENCE)["cutoff"]))
	_reached.append("heart")


func _test_down() -> void:
	_health(0.0)
	await _wait(1.0)
	var start: int = Vfx.heartbeats
	await _wait(1.5)
	_check(Vfx.heartbeats == start, "a Warden who is down hears a heart (%d beats)" % (Vfx.heartbeats - start))
	_check(Vfx.near_death_share() <= 0.0, "a Warden who is down hears a closed world (%.2f)" % Vfx.near_death_share())
	_check(not bool(AudioBuses.near_death_state(AudioBuses.AMBIENCE)["on"]),
		"the ambience stays closed over once the Warden is down")
	_reached.append("down")


func _test_settled() -> void:
	RunState.phase = RunState.Phase.ENDED
	_health(10.0)
	await _wait(0.6)
	_check(Vfx.near_death_share() <= 0.0, "a settled run closed the world over (%.2f)" % Vfx.near_death_share())
	RunState.phase = RunState.Phase.ROAD_BATTLE
	_health(10.0)
	await _wait(1.0)
	_check(Vfx.near_death_share() > 0.3, "the world did not close again on the road (%.2f)" % Vfx.near_death_share())
	Vfx.clear_vignette()
	_check(Vfx.near_death_share() <= 0.0 and not bool(AudioBuses.near_death_state(AudioBuses.AMBIENCE)["on"]),
		"clearing the red edge left the world closed over")
	var start: int = Vfx.heartbeats
	await _wait(1.2)
	_check(Vfx.heartbeats == start, "the heart beat on after the red edge was cleared")
	_reached.append("settled")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
