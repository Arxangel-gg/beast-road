class_name ReviveBar
extends Node2D

## The bar over a downed hero, filling while their partner holds them up.
##
## Drawn in world space above the body rather than in the HUD, because the thing
## the player needs to judge is *distance*: whether they can reach their friend
## before the next pack does, and whether they dare stand there for three
## seconds. A bar in the corner of the screen answers none of that.
##
## Reads the hero and nothing else. The host owns the number and mirrors it, so
## this draws the same fill on both machines without knowing either exists.

## Above the health bar, which already sits over the hero's head.
const LIFT: float = -78.0
const WIDTH: float = 64.0
const HEIGHT: float = 7.0

var _hero: Hero = null
var _last: float = -1.0
var _was_downed: bool = false


func _init(for_hero: Hero = null) -> void:
	_hero = for_hero
	z_index = 40


func _process(_delta: float) -> void:
	if _hero == null or not is_instance_valid(_hero):
		return
	# Redrawn only when something changed. A bar that is not filling is the
	# common case by a very long way, and it should cost nothing to have.
	var downed: bool = _hero.is_downed()
	var progress: float = _hero.revive_progress()
	if downed == _was_downed and is_equal_approx(progress, _last):
		return
	_was_downed = downed
	_last = progress
	queue_redraw()


func _draw() -> void:
	if _hero == null or not _hero.is_downed():
		return
	var origin := Vector2(-WIDTH * 0.5, LIFT)
	var frame := Rect2(origin, Vector2(WIDTH, HEIGHT))
	draw_rect(frame.grow(1.0), Color(0.03, 0.04, 0.05, 0.78))
	draw_rect(frame, Color(0.16, 0.18, 0.20, 0.9))
	var progress: float = _hero.revive_progress()
	if progress > 0.0:
		draw_rect(Rect2(origin, Vector2(WIDTH * progress, HEIGHT)),
			Color("8fd8a0"))

	# The prompt only while nobody is actually helping. Once the bar is moving it
	# is saying the same thing twice, and a downed player has enough on screen.
	if progress > 0.0:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var hint: String = "Hold E"
	var width: float = font.get_string_size(hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12).x
	draw_string(font, Vector2(-width * 0.5, LIFT - 6.0), hint,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Color("d8e4de"))
