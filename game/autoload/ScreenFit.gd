extends Node

## Makes the game usable on a screen it was not designed for.
##
## The project is authored against 1920x1080 with `canvas_items` stretch and an
## `expand` aspect. On a desktop that is exactly right. On a phone it is not
## close: a 390pt-wide browser viewport scales the whole game to about **0.2x**,
## because the scale Godot picks is `min(real / base)` and 390/1920 is 0.2. Every
## sprite, every button and every word ends up a fifth of its intended size, which
## reads as a camera pulled impossibly far out and a UI nobody can hit.
##
## `content_scale_factor` is the multiplier on top of that scale, and it is what
## this exists to set. Choosing it from the real viewport rather than from a
## device check means it is right for a small window on a desktop too, and there
## is no phone/not-phone branch to be wrong about.

## The logical width the game aims to present on a small screen.
##
## Not the base width. 1920 logical pixels on a phone is the problem, not the
## goal - the point is to hand the layout a *smaller* canvas so everything on it
## is drawn bigger.
##
## **1440 is a ceiling the HUD imposes, not a judgement about phones.** Anything
## smaller genuinely reads better on a handset - 720 makes the game roughly
## 2.7x its old size - but the HUD is authored for 16:9 and below about 1440 it
## stops fitting: the nav bar column runs past the bottom of a portrait screen,
## the action bar wraps into the spell slots, and `layout_check` catches every
## one of them. Those are layout problems with layout answers, and until the HUD
## is reworked for a narrow screen this is as far as scaling alone can go.
##
## So: 1.33x bigger than before, verified against `layout_check` at 430x932.
## Not the fix a phone deserves. Measurably better than 0.2x. [TUNE]
const PHONE_LOGICAL_WIDTH: float = 1440.0

## Below this real width, a screen is treated as small. A desktop window narrower
## than this has the same problem for the same reason and gets the same fix.
const SMALL_SCREEN_WIDTH: float = 900.0

## Below this, there is no display - a dummy window rather than a small one.
const REAL_DISPLAY_WIDTH: float = 240.0

## Bounds. Scaling up beyond this makes a phone show almost nothing at all, and
## below 1.0 would shrink a display that was already fine.
const MIN_FACTOR: float = 1.0
const MAX_FACTOR: float = 3.5


func _ready() -> void:
	# Runs before anything draws, and again whenever the window changes - a
	# browser tab is resized by rotating the phone, and a desktop window by
	# dragging it.
	get_tree().root.size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var window: Window = get_window()
	if window == null:
		return
	window.content_scale_factor = factor_for(Vector2(window.size), base_size())


## The size the project is authored against.
##
## `content_scale_size` is (0,0) unless somebody set it explicitly, and that
## means "use the project's viewport size" rather than "there is no base". Taking
## it literally would make the fit a no-op on exactly the machines that need it.
static func base_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080)))


## The multiplier that gives a small screen a sane logical size.
##
## Static and pure so a test can ask it about a screen nobody is holding.
static func factor_for(real: Vector2, base: Vector2) -> float:
	if real.x <= 0.0 or real.y <= 0.0 or base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	# **A display is never this small.** Headless runs on a dummy 64x64 window,
	# and taking that literally made every automated check behave as though it
	# were on the narrowest phone ever built - the desktop layout gate started
	# failing against a 1440-wide logical viewport nobody would ever see.
	if real.x < REAL_DISPLAY_WIDTH:
		return 1.0
	if real.x >= SMALL_SCREEN_WIDTH:
		return 1.0
	# The scale Godot applies before this multiplier.
	var fitted: float = minf(real.x / base.x, real.y / base.y)
	if fitted <= 0.0:
		return 1.0
	# Solve `real.x / (fitted * factor) == PHONE_LOGICAL_WIDTH`.
	var wanted: float = real.x / (fitted * PHONE_LOGICAL_WIDTH)
	return clampf(wanted, MIN_FACTOR, MAX_FACTOR)
