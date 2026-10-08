class_name PingMark
extends Node2D

## **One ping on the field**: a glyph standing over the point on a stalk of its
## own colour, rings leaving the ground under it, the speaker's name, and for a
## warning a sharper beat. It lives `PING_SECONDS` and frees itself.
##
## A picture: nothing reads it but the map and the edge of the screen, which
## point at where it stands.

var data: PingData = null
var seat: int = 0
var who: String = ""
var age: float = 0.0
var _icon: Texture2D = null


func setup(ping: PingData, from_seat: int, speaker: String) -> void:
	data = ping
	seat = from_seat
	who = speaker
	_icon = IconKit.ui(ping.icon) if ping != null else null


func colour() -> Color:
	return data.colour if data != null else Color.WHITE


func _process(delta: float) -> void:
	age += delta
	if age >= Balance.PING_SECONDS:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	var fade: float = clampf(age / 0.12, 0.0, 1.0) * clampf((Balance.PING_SECONDS - age) / 0.6, 0.0, 1.0)
	var tint: Color = data.colour
	# Rings leave the ground, flattened because the camera looks down and along.
	var rate: float = 1.6 if data.alert else 1.1
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	for index: int in 2:
		var wave: float = fmod(age * rate + float(index) * 0.5, 1.0)
		draw_arc(Vector2.ZERO, 16.0 + 74.0 * wave, 0.0, TAU, 40,
			Color(tint, 0.9 * (1.0 - wave) * fade), 4.0, true)
	draw_circle(Vector2.ZERO, 22.0, Color(tint, 0.22 * fade))
	draw_circle(Vector2.ZERO, 11.0, Color(tint, 0.65 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# The stalk and the glyph over it, dropped in and bobbing.
	var drop: float = clampf(age / 0.22, 0.0, 1.0)
	var lift: float = 92.0 + 30.0 * (1.0 - drop) * (1.0 - drop) + 5.0 * sin(age * 4.0)
	draw_line(Vector2.ZERO, Vector2(0.0, -lift + 24.0), Color(tint, 0.7 * fade), 3.0, true)
	var size: float = 56.0 * (1.0 + 0.35 * (1.0 - drop))
	if data.alert:
		size *= 1.0 + 0.1 * maxf(0.0, sin(age * 9.0))
	var middle := Vector2(0.0, -lift)
	# A glow in the ping's own colour, so the colour is what is seen first.
	var glow: float = 0.26 + (0.14 * maxf(0.0, sin(age * 9.0)) if data.alert else 0.0)
	draw_circle(middle, size * 0.95, Color(tint, glow * 0.5 * fade))
	draw_circle(middle, size * 0.78, Color(tint, glow * fade))
	draw_circle(middle, size * 0.62, Color(0.03, 0.04, 0.04, 0.78 * fade))
	draw_arc(middle, size * 0.62, 0.0, TAU, 32, Color(tint, 0.95 * fade), 3.5, true)
	if _icon != null:
		draw_texture_rect(_icon, Rect2(middle - Vector2.ONE * size * 0.5, Vector2.ONE * size),
			false, Color(1.0, 1.0, 1.0, fade))
	var font: Font = UiFonts.face(UiFonts.Role.HEADING)
	if font != null and not who.is_empty():
		var width: float = font.get_string_size(who, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var at: Vector2 = middle + Vector2(-width * 0.5, -size * 0.62 - 10.0)
		draw_string_outline(font, at, who, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6,
			Color(0.02, 0.03, 0.03, 0.9 * fade))
		draw_string(font, at, who, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color(CoopParty.colour_of(seat), fade))
