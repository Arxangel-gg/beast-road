class_name QualityGovernor
extends Node

## Steps the graphics preset by what a frame actually costs (2026-09-24).
##
## The owner: "auto settings detection and configuration for all platforms and
## any device". `Graphics.preset_for_machine` already picks a preset by the
## adapter's *name* - a discrete card, an integrated chip, a phone - and a name
## cannot know about a hot laptop, a browser tab on a Chromebook or a phone
## three years older than the one the roster was tuned on. This is the other
## half: **measure the frame in combat and step the preset to what the device
## can hold.**
##
## - Only while the player has never chosen a preset (`Graphics.is_automatic`).
##   A saved choice is never second-guessed - that rule predates this and this
##   does not soften it. The settings screen offers "Auto" to hand the choice
##   back.
## - Only in combat on the road, after a settle, in windows of
##   `GOVERNOR_WINDOW_SECONDS`: a scope change and an act's first frames are
##   loads, not the frame.
## - Down when two windows in a row average past `GOVERNOR_STEP_DOWN_MS` (or the
##   player's own frame cap plus slack - a 30 fps cap is 33 ms by choice, not a
##   struggling device); up when twelve in a row are comfortably under
##   `GOVERNOR_STEP_UP_MS`, and never above what the machine was judged for by
##   name, or "the frame is fine" becomes a slow ratchet toward Ultra.
## - The step is said on the HUD once, so a change nobody asked for is never a
##   change nobody was told about.
##
## A look, never a fact: a preset moves shadows, particles, foliage, the
## bloom, the shading and the torch lights, and not one number the fight reads.

## The HUD's announcement, handed in by the run so this holds no HUD.
var say: Callable = Callable()
## Headless frames are fake; the gate turns this on to drive `sample` itself.
var measure_headless: bool = false

var _window_seconds: float = 0.0
var _window_ms: float = 0.0
var _window_frames: int = 0
var _slow_windows: int = 0
var _fast_windows: int = 0
var _settle: float = 0.0


func _ready() -> void:
	EventBus.scope_changed.connect(_on_scope_changed)
	EventBus.act_started.connect(_on_act_started)
	rest()


func _on_scope_changed(_scope: int) -> void:
	rest()


func _on_act_started(_act: int, _terrain: String) -> void:
	rest()


## Starts a fresh settle and an empty window. Anything that loads is not the
## frame. Public so a harness can begin a measurement cleanly.
func rest() -> void:
	_settle = Balance.GOVERNOR_SETTLE_SECONDS
	_window_seconds = 0.0
	_window_ms = 0.0
	_window_frames = 0
	_slow_windows = 0
	_fast_windows = 0


func _process_measured(delta: float) -> void:
	if DisplayServer.get_name() == "headless" and not measure_headless:
		return
	sample(delta)


## One frame's cost. Public so the gate can hand in a clock of its own.
func sample(delta: float) -> void:
	if not Graphics.is_automatic():
		return
	if not RunState.is_command_combat():
		rest()
		return
	if _settle > 0.0:
		_settle -= delta
		return
	_window_seconds += delta
	_window_ms += delta * 1000.0
	_window_frames += 1
	if _window_seconds < Balance.GOVERNOR_WINDOW_SECONDS:
		return
	var average: float = _window_ms / maxf(float(_window_frames), 1.0)
	_window_seconds = 0.0
	_window_ms = 0.0
	_window_frames = 0
	var slow_at: float = Balance.GOVERNOR_STEP_DOWN_MS
	if Graphics.fps_cap() > 0:
		slow_at = maxf(slow_at, 1000.0 / float(Graphics.fps_cap()) * Balance.GOVERNOR_CAP_SLACK)
	if average > slow_at:
		_slow_windows += 1
		_fast_windows = 0
		if _slow_windows >= Balance.GOVERNOR_SLOW_WINDOWS:
			_slow_windows = 0
			_step(-1)
	elif average < Balance.GOVERNOR_STEP_UP_MS:
		_fast_windows += 1
		_slow_windows = 0
		if _fast_windows >= Balance.GOVERNOR_FAST_WINDOWS:
			_fast_windows = 0
			_step(1)
	else:
		_slow_windows = 0
		_fast_windows = 0


func _step(direction: int) -> void:
	var ladder: Array[String] = Graphics.PRESET_LADDER
	var index: int = ladder.find(Graphics.preset())
	if index < 0:
		return
	var to: int = index + direction
	if to < 0 or to >= ladder.size():
		return
	if direction > 0 and to > ladder.find(Graphics.default_preset()):
		return
	Graphics.govern(ladder[to])
	UserSettings.store_presentation()
	if say.is_valid():
		say.call("GRAPHICS", "%s to %s" % ["Eased" if direction < 0 else "Raised",
			ladder[to].capitalize()], "Measured on this device. Settings to choose.")


## `FrameProfile` bucket "p_quality_governor": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"p_quality_governor", started)
