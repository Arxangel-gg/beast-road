class_name ReviveBar
extends Node2D

## The marker over a downed hero, and the bar filling while somebody helps.
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

## Where a body is, once the body itself has stopped being drawn.
##
## A collapsed hero hides its sprite - it has to, or a corpse lies on the field
## looking alive - and the bar alone is a few pixels of outline at a distance.
## A partner crossing the map to help had nothing to walk *towards*. So a marker
## stands where they fell: visible from across the field, gone the moment they
## are up, and never drawn in a solo run because nobody is coming.
const MARKER_ART: String = "res://art/vfx/fallen_marker.png"

var _hero: Hero = null
var _last: float = -1.0
var _was_downed: bool = false

## Built the first time it is needed, so a run where nobody falls pays nothing.
var _marker: Sprite2D = null
var _sway: float = 0.0


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
	_show_marker(downed)
	queue_redraw()


## Plants or removes the stone. See `MARKER_ART`.
func _show_marker(downed: bool) -> void:
	if not downed:
		if _marker != null and is_instance_valid(_marker):
			_marker.queue_free()
			_marker = null
		return
	if _marker != null and is_instance_valid(_marker):
		_marker.visible = true
		return
	if not ResourceLoader.exists(MARKER_ART):
		return
	_marker = Sprite2D.new()
	_marker.texture = load(MARKER_ART) as Texture2D
	# Sits on the ground the hero fell on rather than at their head height, and
	# *behind* the bar, which is the thing being read.
	_marker.centered = false
	_marker.offset = Vector2(-_marker.texture.get_width() * 0.5,
		-_marker.texture.get_height())
	_marker.z_index = -1
	add_child(_marker)


## A slow breath on the stone, so a downed friend reads as urgent rather than as
## scenery. Cheap: one node, one property, only while somebody is actually down.
func _physics_process(delta: float) -> void:
	if _marker == null or not is_instance_valid(_marker) or not _marker.visible:
		return
	_sway += delta * 2.4
	var pulse: float = 0.5 + 0.5 * sin(_sway)
	_marker.modulate = Color(1.0, 1.0, 1.0).lerp(Color("8fd8a0"), pulse * 0.55)


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
