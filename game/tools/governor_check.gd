extends Node

## The frame-time governor (2026-09-24), held to what it promises.
##
##   godot --headless --path game res://tools/governor_check.tscn
##
## Driven with a clock of its own through `sample`, because headless frames
## cost nothing and prove nothing. It steps down on slow windows and never
## below Low, steps up on fast ones and never above the machine's own preset,
## does nothing at all once the player has chosen, does nothing under a frame
## cap the player set, does nothing outside combat, and tells the HUD each time.

var _failures: Array[String] = []
var _said: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held: Dictionary = Graphics.to_dictionary()
	var held_phase: int = RunState.phase
	Graphics.from_dictionary({})
	_check(Graphics.is_automatic(), "a save with no preset must be automatic")
	var top: String = Graphics.default_preset()
	_check(Graphics.preset() == top, "with nothing chosen the preset is the machine's")

	var governor := QualityGovernor.new()
	governor.measure_headless = true
	governor.say = _hear
	add_child(governor)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_settle(governor)

	# --- Down, and never below Low ---------------------------------------------
	var ladder: Array[String] = Graphics.PRESET_LADDER
	var at: int = ladder.find(top)
	_feed(governor, 0.030, Balance.GOVERNOR_SLOW_WINDOWS)
	_check(Graphics.preset() == ladder[maxi(at - 1, 0)],
		"two slow windows should step %s down one, got %s" % [top, Graphics.preset()])
	_check(_said.size() == 1, "a step was not said on the HUD (%d)" % _said.size())
	for _more: int in ladder.size():
		_feed(governor, 0.030, Balance.GOVERNOR_SLOW_WINDOWS)
	# Amended 2026-09-25: the floor is Minimal now, the rung below Low that a
	# 2019 phone at 6 fps needed somewhere to step to.
	_check(Graphics.preset() == Graphics.PRESET_MINIMAL, "slow frames should end on Minimal")
	_check(Graphics.torch_light_every() == Balance.TORCH_LIGHT_EVERY_LOW,
		"Minimal should carry fewer torch light nodes")
	_check(not Graphics.lights_allowed(), "Minimal should enable no light at all")
	_check(Graphics.governed_preset() == Graphics.PRESET_MINIMAL,
		"the governed level should be remembered for the next launch")

	# --- Up, and never above the machine's own -------------------------------
	_feed(governor, 0.006, Balance.GOVERNOR_FAST_WINDOWS)
	_check(Graphics.preset() == ladder[1], "twelve fast windows should step Minimal up one")
	for _more: int in ladder.size() + 1:
		_feed(governor, 0.006, Balance.GOVERNOR_FAST_WINDOWS)
	_check(Graphics.preset() == top,
		"fast frames must never climb past the machine's own %s (got %s)" % [top, Graphics.preset()])

	# --- A middling frame moves nothing ----------------------------------------
	_feed(governor, 0.014, Balance.GOVERNOR_SLOW_WINDOWS + Balance.GOVERNOR_FAST_WINDOWS)
	_check(Graphics.preset() == top, "a frame inside the band moved the preset")

	# --- A frame cap the player set is not a struggling device -----------------
	Graphics.set_fps_cap(30)
	_settle(governor)
	_feed(governor, 0.034, Balance.GOVERNOR_SLOW_WINDOWS + 1)
	_check(Graphics.preset() == top, "34 ms frames under a 30 fps cap are the cap, not the device")
	Graphics.set_fps_cap(0)

	# --- Outside combat nothing is measured ------------------------------------
	RunState.set_phase(RunState.Phase.PREPARATION)
	_feed(governor, 0.030, Balance.GOVERNOR_SLOW_WINDOWS + 2)
	_check(Graphics.preset() == top, "Preparation's frames stepped the preset")
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)

	# --- A chosen preset is never second-guessed --------------------------------
	Graphics.apply_preset(Graphics.PRESET_ULTRA)
	_check(not Graphics.is_automatic(), "choosing a preset should end automatic mode")
	_settle(governor)
	_feed(governor, 0.030, Balance.GOVERNOR_SLOW_WINDOWS + 2)
	_check(Graphics.preset() == Graphics.PRESET_ULTRA, "the governor moved a preset the player chose")
	Graphics.set_automatic()
	_check(Graphics.is_automatic() and Graphics.preset() == top,
		"Auto should hand the choice back to the machine's preset")

	# --- Render at the logical size, only where it saves (2026-09-25) --------
	var base := Vector2(1920.0, 1080.0)
	var phone := Vector2(2280.0, 1080.0)
	var phone_factor: float = 2280.0 / 1680.0
	_check(absf(Graphics.logical_pixel_ratio(phone, base, phone_factor) - phone_factor) < 0.01,
		"a 2280x1080 phone at the phone fit should draw %.2f screen pixels a logical one, got %.2f"
			% [phone_factor, Graphics.logical_pixel_ratio(phone, base, phone_factor)])
	_check(absf(Graphics.logical_pixel_ratio(Vector2(2560.0, 1440.0), base, 1.0) - 1.3333) < 0.01,
		"a 1440p screen at the desktop fit is 1.33 screen pixels a logical one")
	_check(absf(Graphics.logical_pixel_ratio(Vector2(1920.0, 1080.0), base, 1.0) - 1.0) < 0.01,
		"a 1080p screen at the desktop fit is one pixel a pixel")
	Graphics.apply_preset(Graphics.PRESET_MINIMAL)
	_check(Graphics.renders_at_logical_size(phone, phone_factor),
		"Minimal on a phone should render at the logical size")
	_check(not Graphics.renders_at_logical_size(Vector2(1920.0, 1080.0), 1.0),
		"a 1080p screen saves nothing and keeps canvas_items")
	_check(not Graphics.renders_at_logical_size(Vector2(1920.0, 1080.0), 0.8),
		"an interface slider below one must never supersample")
	_check(not Graphics.grade_enabled() and not Graphics.pixel_filter(),
		"Minimal runs neither full-screen copy by default")
	Graphics.apply_preset(Graphics.PRESET_LOW)
	_check(Graphics.renders_at_logical_size(phone, phone_factor),
		"Low on a phone should render at the logical size")
	_check(Graphics.lights_allowed(), "Low still lights")
	Graphics.apply_preset(Graphics.PRESET_HIGH)
	_check(not Graphics.renders_at_logical_size(phone, phone_factor),
		"High keeps the screen's own resolution")
	_check(Graphics.physics_rate_for(120.0, 0) == 120,
		"a desktop at 120 Hz still ticks at 120 (the phone pin is in physics_rate)")
	var graphics_source: String = FileAccess.get_file_as_string("res://scripts/systems/graphics.gd")
	_check(graphics_source.contains("OS.has_feature(\"mobile\") and refresh > float(Balance.PHYSICS_RATE_MOBILE)"),
		"a phone's physics tick is not pinned")
	_check(graphics_source.find("preset() != PRESET_LOW") < 0,
		"a comparison against Low alone hands Minimal the look it was built to drop")
	Graphics.set_automatic()

	# --- The run stands one up and the HUD hears it ----------------------------
	var run_source: String = FileAccess.get_file_as_string("res://scenes/run/run.gd")
	_check(run_source.contains("QualityGovernor.new()"), "the run stands no governor up")

	RunState.set_phase(held_phase)
	Graphics.from_dictionary(held)
	MetaState.resume_saves()
	for problem: String in _failures:
		push_error("[governor] " + problem)
	print("[governor] %s" % ("PASS - the frame governs the preset and the player governs the frame"
		if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


## Begins a measurement the way a scope change does, and walks the settle out
## on frames inside the band - the first cut fed 250 ms "frames" here, which
## the governor rightly read as two slow windows once it had settled.
func _settle(governor: QualityGovernor) -> void:
	governor.rest()
	var left: float = Balance.GOVERNOR_SETTLE_SECONDS + 0.5
	while left > 0.0:
		governor.sample(0.014)
		left -= 0.014


## Feeds `windows` full windows of frames at `frame` seconds each.
func _feed(governor: QualityGovernor, frame: float, windows: int) -> void:
	var left: float = Balance.GOVERNOR_WINDOW_SECONDS * float(windows) + frame * 2.0
	while left > 0.0:
		governor.sample(frame)
		left -= frame


func _hear(kicker: String, title: String, _note: String) -> void:
	_said.append("%s %s" % [kicker, title])


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
