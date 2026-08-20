extends Node

## Release gate for milestone data, first-view routing, assets and input safety.

const EXPECTED_IDS: Array[String] = [
	"act2", "act3", "chainmaker", "drowned_choir", "mirrorfang",
	"rust_crown", "summit",
]

var _failures: PackedStringArray = []


func _ready() -> void:
	var cinematics: Array[MilestoneCinematicData] = ContentDB.milestone_cinematics_sorted()
	var ids: Array[String] = []
	for data: MilestoneCinematicData in cinematics:
		ids.append(data.id)
		_check(not data.trigger_id.is_empty(), "%s must name a trigger id" % data.id)
		_check(not data.eyebrow.is_empty(), "%s must have an eyebrow" % data.id)
		_check(not data.display_name.is_empty(), "%s must have a title" % data.id)
		_check(not data.description.is_empty(), "%s must have narrative copy" % data.id)
		_check(ResourceLoader.exists(data.get_sprite_path()),
			"%s must resolve its convention sprite" % data.id)
		_check(ResourceLoader.exists(data.get_backdrop_path()),
			"%s must resolve its convention backdrop" % data.id)
	_check(ids == EXPECTED_IDS, "the seven authored milestone ids must load in stable order")

	var total_seconds: float = Balance.MILESTONE_CINEMATIC_FADE_IN_SECONDS \
		+ Balance.MILESTONE_CINEMATIC_HOLD_SECONDS \
		+ Balance.MILESTONE_CINEMATIC_FADE_OUT_SECONDS
	_check(total_seconds < 10.0, "an unattended milestone must remain below ten seconds")
	_check(Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS <= 1.0,
		"deliberate skip must answer within one second")

	_check(_match_count(MilestoneCinematicData.Trigger.ACT_STARTED, "desert") == 1,
		"Act II must have one regional transition")
	_check(_match_count(MilestoneCinematicData.Trigger.ACT_STARTED, "snow") == 1,
		"Act III must have one regional transition")
	_check(_match_count(MilestoneCinematicData.Trigger.BOSS_DEFEATED, "rust_crown") == 1,
		"Mogrun's defeat must open one Final Ascent transition")
	for boss_id: String in ["drowned_choir", "mirrorfang", "rust_crown", "chainmaker"]:
		_check(_match_count(MilestoneCinematicData.Trigger.BOSS_SPAWNED, boss_id) == 1,
			"%s must have one boss introduction" % boss_id)

	# Headless suites must never pause on a cinematic unless this focused gate
	# explicitly opts in.
	_check(not bool(MilestoneCinematics.call("_presentation_available")),
		"ordinary headless tools must suppress presentation")

	var old_seen: Variant = MetaState.settings.get("milestone_cinematics_seen", [])
	MetaState.settings["milestone_cinematics_seen"] = ["act2"]
	_check(MetaState.milestone_cinematic_seen("act2"), "seen ids must be readable")
	_check(not MetaState.milestone_cinematic_seen("act3"), "unseen ids must stay unseen")
	_check(MetaState.serialized_save().contains("milestone_cinematics_seen"),
		"first-view state must be part of the persistent settings schema")
	MetaState.settings[MetaState.MILESTONE_CINEMATICS_SEEN_KEY] = "damaged"
	_check(not MetaState.milestone_cinematic_seen("act2"),
		"a malformed seen list must repair to a fresh list")

	# The director must queue an unseen signal exactly once and decline a replay.
	var queue: Array = MilestoneCinematics.get("_queue") as Array
	queue.clear()
	MilestoneCinematics.force_presentation_for_tests = true
	MilestoneCinematics.set("_draining", true)
	MetaState.settings["milestone_cinematics_seen"] = []
	MilestoneCinematics.call("_enqueue_matches",
		MilestoneCinematicData.Trigger.ACT_STARTED, "desert")
	MilestoneCinematics.call("_enqueue_matches",
		MilestoneCinematicData.Trigger.ACT_STARTED, "desert")
	_check(queue.size() == 1, "an unseen transition must queue exactly once")
	queue.clear()
	MetaState.settings["milestone_cinematics_seen"] = ["act2"]
	MilestoneCinematics.call("_enqueue_matches",
		MilestoneCinematicData.Trigger.ACT_STARTED, "desert")
	_check(queue.is_empty(), "a seen transition must fall back to the HUD card")
	MilestoneCinematics.force_presentation_for_tests = false
	MilestoneCinematics.set("_draining", false)
	MetaState.settings["milestone_cinematics_seen"] = old_seen

	var sample: MilestoneCinematicData = ContentDB.milestone_cinematics.get(
		"mirrorfang", null) as MilestoneCinematicData
	var overlay := MilestoneCinematic.new()
	add_child(overlay)
	overlay.call("_apply", sample)
	_check(overlay.get_node("Frame/Backdrop").texture != null,
		"boss composition must load its regional backdrop")
	_check(overlay.get_node("Frame/BossPortrait").texture != null,
		"boss composition must load its portrait")
	_check(overlay.get_node("Frame/CopySafeArea/Copy/Title").text == sample.display_name,
		"overlay copy must come from data")

	# A short pointer release advances; a held touch crosses the deliberate-skip
	# threshold. Invoke the input contract without waiting through a presentation.
	overlay.set("_running", true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	overlay.call("_input", release)
	_check(bool(overlay.get("_advance")), "mouse/touch release must advance")
	overlay.set("_advance", false)
	overlay.set("_pointer_held", true)
	overlay.call("_process", Balance.MILESTONE_CINEMATIC_SKIP_HOLD_SECONDS + 0.01)
	_check(bool(overlay.get("_skipped")), "held pointer input must skip on mobile")
	overlay.set("_running", false)

	# The live presentation must stop every system behind it and restore the
	# exact prior pause state when dismissed.
	overlay.play(sample)
	await get_tree().process_frame
	_check(get_tree().paused, "a live milestone must pause gameplay")
	overlay.set("_advance", true)
	await overlay.finished
	_check(not get_tree().paused, "dismissal must restore an unpaused run")
	overlay.queue_free()
	# Let deferred deletion release the generated gradient and loaded textures
	# before the process exits. CI treats resource leaks as errors, correctly.
	await get_tree().process_frame

	_finish()


func _match_count(trigger: MilestoneCinematicData.Trigger, trigger_id: String) -> int:
	var count: int = 0
	for data: MilestoneCinematicData in ContentDB.milestone_cinematics_sorted():
		if data.matches(trigger, trigger_id):
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("[milestone-cinematics] PASS — 3 transitions, 4 bosses, persistence, skip and headless isolation")
	else:
		for failure: String in _failures:
			push_error("[milestone-cinematics] " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
