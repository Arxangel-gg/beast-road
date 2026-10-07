extends Node

## **A personal best is said once** (`PersonalBest`, triage of 2026-10-07).
##
## Driven through the signal the journey emits as the road advances: a first
## road has nothing worth beating; a road short of the best says nothing; the
## step past it says it once, and never again on that road; a Walk and a
## sandbox never say it; a fresh road may say it again; and the debrief says
## the same thing from the summary the director builds.

const TAG: String = "[personal-best]"

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held_best: float = MetaState.best_distance
	var best := PersonalBest.new()
	add_child(best)
	_test_the_call(best)
	await _test_the_debrief()
	MetaState.best_distance = held_best
	RunState.reset()
	for stage: String in ["call", "debrief"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: nothing on a first road or short of the best, said once past it, never on a Walk or in a sandbox, again on a fresh road, and on the debrief" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _road(best: float) -> void:
	MetaState.best_distance = best
	RunState.reset()


func _walk(distance: float) -> void:
	EventBus.distance_changed.emit(distance, 100.0)


func _test_the_call(best: PersonalBest) -> void:
	_road(120.0)
	_walk(500.0)
	_check(best.said == 0, "a first road's best of 120 was said to be beaten")
	_road(1000.0)
	_check(is_equal_approx(RunState.best_to_beat, 1000.0), "the road did not take the account's best as it began")
	_walk(900.0)
	_check(best.said == 0, "a road short of the best said it was further")
	_walk(1001.0)
	_check(best.said == 1 and RunState.best_called, "passing the best was not said")
	_walk(1400.0)
	_walk(2000.0)
	_check(best.said == 1, "the best was said %d times on one road" % best.said)
	_road(1000.0)
	_walk(1100.0)
	_check(best.said == 2, "a fresh road past the best was not said")
	_road(1000.0)
	RunState.walking = true
	_walk(1500.0)
	RunState.walking = false
	_check(best.said == 2, "a Walk said it beat the best")
	_road(1000.0)
	RunState.sandbox = true
	_walk(1500.0)
	RunState.sandbox = false
	_check(best.said == 2, "a sandbox said it beat the best")
	_reached.append("call")


func _test_the_debrief() -> void:
	var scene: PackedScene = load("res://scenes/ui/results_screen.tscn") as PackedScene
	var screen: Node = scene.instantiate()
	add_child(screen)
	await get_tree().process_frame
	var summary: Dictionary = {"victory": false, "seed": 1, "roads": [], "distance": 1500.0, "act": 2,
		"wave": 5, "kills": 12, "deaths": 1, "last_blow": "", "time": 90.0, "planning_time": 20.0,
		"kept": {}, "earth": {}, "unlocks": [], "chronicle": [], "new_best_distance": true}
	screen.call("show_results", false, summary)
	await get_tree().process_frame
	var body: RichTextLabel = screen.get("body") as RichTextLabel
	_check(body != null and body.get_parsed_text().contains("further than you have ever walked"),
		"the debrief does not say the best was beaten")
	summary["new_best_distance"] = false
	screen.call("show_results", false, summary)
	await get_tree().process_frame
	_check(body != null and not body.get_parsed_text().contains("further than you have ever walked"),
		"the debrief says a best was beaten that was not")
	screen.queue_free()
	_reached.append("debrief")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
