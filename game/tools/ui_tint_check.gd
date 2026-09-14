extends Node

## Does the interface follow the world without becoming harder to read?
##
##   godot --headless --path game res://tools/ui_tint_check.tscn
##
## `UiTint` grades the HUD's frames to the act and the hour (owner brief,
## 2026-09-14). Adaptive interfaces are usually a bad idea, and the reason is
## always the same one: they end up *dimming* the thing a player has to read on
## exactly the screens that were already dark. This gate holds the two rules
## that stop that happening here.
##
## **The tint never darkens.** Deep night is (0.13, 0.17, 0.33). Used directly
## it would take every button to a fifth of its value on the darkest screen in
## the game. `_normalised` divides the tint by its own luminance, so what
## survives is the *hue* - cold and blue - and none of the darkness.
##
## **And it never touches text.** It moves `StyleBoxTexture.modulate_color`,
## which is the ornate frame art, and no font colour anywhere. A player is
## never asked to read a word through this.

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_no_hour_makes_the_interface_darker()
	_test_the_hue_actually_follows_the_hour()
	_test_a_frame_is_tinted_and_a_font_is_not()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[ui-tint] PASS - %d checks: the interface follows the light and never dims"
			% _checks)
	else:
		for failure: String in _failures:
			push_error("[ui-tint] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## **The whole point.** Walk the day and confirm the tint's own brightness never
## drops below one, whatever colour the sky is.
func _test_no_hour_makes_the_interface_darker() -> void:
	for step: int in 48:
		var phase: float = float(step) / 48.0
		DayNight._apply(phase)
		var tint: Color = _settled(UiTint.for_the_world())
		var value: float = 0.2126 * tint.r + 0.7152 * tint.g + 0.0722 * tint.b
		_check(value >= 0.985,
			("at phase %.2f the interface tint is worth %.3f - anything under "
				+ "one dims the frames, and the darkest hours are exactly when "
				+ "a player can least afford it") % [phase, value])
		# And nothing may blow out either: a tint over one would bloom the
		# frame art on a bright afternoon.
		_check(maxf(maxf(tint.r, tint.g), tint.b) <= 1.6,
			"at phase %.2f a channel reaches %.2f, which will bloom"
				% [phase, maxf(maxf(tint.r, tint.g), tint.b)])


## It has to actually *do* something, or the safety above is the safety of a
## feature that is switched off.
func _test_the_hue_actually_follows_the_hour() -> void:
	DayNight._apply(0.28)
	var noon: Color = _settled(UiTint.for_the_world())
	DayNight._apply(0.85)
	var night: Color = _settled(UiTint.for_the_world())
	var apart: float = absf(noon.r - night.r) + absf(noon.g - night.g) \
		+ absf(noon.b - night.b)
	_check(apart > UiTint.STEP * 2.0,
		("midday and deep night grade the interface to within %.3f of each "
			+ "other - the tint is not following the light at all") % apart)
	# Night is the cold one. If that ever inverts, the sign is wrong somewhere.
	_check(night.b - night.r > noon.b - noon.r,
		"deep night does not grade the interface colder than midday")


## Frames move; fonts do not.
func _test_a_frame_is_tinted_and_a_font_is_not() -> void:
	var button := Button.new()
	button.text = "Probe"
	var art := StyleBoxTexture.new()
	art.modulate_color = Color.WHITE
	button.add_theme_stylebox_override("normal", art)
	var font_before: Color = Color(0.9, 0.85, 0.8)
	button.add_theme_color_override("font_color", font_before)
	add_child(button)
	button.add_to_group(UiTint.GROUP)

	DayNight._apply(0.85)
	UiTint.apply(get_tree(), UiTint.for_the_world(), true)
	var after: StyleBoxTexture = button.get_theme_stylebox("normal") as StyleBoxTexture
	_check(after != null, "the probe lost its stylebox")
	if after != null:
		_check(not after.modulate_color.is_equal_approx(Color.WHITE),
			"the frame was not tinted at all")
	_check(button.get_theme_color("font_color").is_equal_approx(font_before),
		"the font colour moved - this may never touch text")
	button.queue_free()


## What `UiTint` actually hands the frames, read off a real control.
##
## **This mirrored `_normalised` in its first cut and was worthless.** The
## reasoning at the time was that a gate should assert the contract rather than
## agree with the implementation - which sounds right and produced a gate that
## tested its own copy of the arithmetic. Proved by deleting the normalisation
## from `UiTint` entirely: the gate went green, with the interface now dimming
## itself at midnight.
##
## So it drives the real thing. A probe button is enrolled and painted, and what
## is measured is the `modulate_color` that actually reaches a frame.
func _settled(wanted: Color) -> Color:
	if _probe == null:
		_probe = Button.new()
		var art := StyleBoxTexture.new()
		art.modulate_color = Color.WHITE
		_probe.add_theme_stylebox_override("normal", art)
		add_child(_probe)
		_probe.add_to_group(UiTint.GROUP)
	UiTint.apply(get_tree(), wanted, true)
	var painted: StyleBoxTexture = _probe.get_theme_stylebox("normal") as StyleBoxTexture
	if painted == null:
		return Color.WHITE
	return painted.modulate_color


var _probe: Button = null
