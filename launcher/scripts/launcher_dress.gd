class_name LauncherDress
extends Control

## The carved border and the corner foliage, so the launcher looks like the game.
##
## **Owner, 2026-09-16: "The launcher is outdated and needs the new aesthetics
## and polish for production ready release! It should be more like the main menu
## scene now!"** It was: the backdrop was a flat-colour pixel horizon from long
## before the painterly key art, and there was no border and no foliage at all,
## so the first thing anybody sees of this game looked like a different game.
##
## **A drawing, not a port.** The menu's own `MenuFrame` and `MenuFoliage` are
## several hundred lines each of shader, wobble, sheen and per-strand placement,
## and they live in the *game* project - the launcher is its own Godot project
## and cannot reach across. What it needs is the *look*, not the machinery: one
## `_draw` laying the same carved edge and corner art the menu uses, with the
## same hanging fronds in the top corners.
##
## **It breathes and it never loops.** Two rates on every sway, the same trick
## the menu's vines use and for the same reason: a motion with a period a person
## can catch is worse than no motion. Redrawn at a fixed rate rather than every
## frame, because this is a window that spends most of its life waiting on a
## download and should not spin a core to do it.

const CORNER_ART: String = "res://art/menu_frame_corner.png"
const EDGE_ART: String = "res://art/menu_frame_edge.png"

## The hanging pieces, and which corner each belongs in. Drawn mirrored on the
## right, exactly as the menu does it.
const HANGERS: Array[String] = [
	"res://art/menu_frond.png",
	"res://art/menu_hanger_fruit.png",
	"res://art/menu_hanger_berries.png",
	"res://art/menu_branch_mossy.png",
]

## How much of the window the carved border takes, and how far a frond hangs.
const BORDER: float = 34.0
const HANG: float = 0.30

## Redraws a second. The menu runs its frame at 24; this waits on downloads.
const HZ: float = 20.0

var _corner: Texture2D = null
var _edge: Texture2D = null
var _hangers: Array[Texture2D] = []
var _time: float = 0.0
var _drawn_at: float = -1.0


func _ready() -> void:
	name = "Dress"
	# Drawn over the backdrop and under everything a player presses.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_corner = _load(CORNER_ART)
	_edge = _load(EDGE_ART)
	for path: String in HANGERS:
		var art: Texture2D = _load(path)
		if art != null:
			_hangers.append(art)


static func _load(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _process(delta: float) -> void:
	_time += delta
	if _time - _drawn_at < 1.0 / HZ:
		return
	_drawn_at = _time
	queue_redraw()


func _draw() -> void:
	# **The viewport's size, not this control's.** A `Control` added from code
	# has no size until the next layout pass, and `_draw` can run before one - so
	# reading `size` drew a border 0 pixels wide and the launcher came out
	# looking exactly as it had before. The window is what this is framing, and
	# the window always knows how big it is.
	var span: Vector2 = get_viewport_rect().size
	if span.x < 64.0 or span.y < 64.0:
		return
	_draw_border(span)
	_draw_corners(span)


## The carved edge, tiled along all four sides with the corner art over the
## joins. **A missing piece leaves the launcher plain rather than broken**, which
## is the same rule the game's frame is built under: art that fails to load must
## never take the window with it.
func _draw_border(span: Vector2) -> void:
	if _edge == null:
		return
	var thick: float = BORDER
	var run: float = float(_edge.get_width()) * (thick / maxf(float(_edge.get_height()), 1.0))
	var shade := Color(1.0, 1.0, 1.0, 0.68)
	var across: int = int(ceil(span.x / maxf(run, 1.0)))
	for step: int in across:
		var x: float = float(step) * run
		draw_texture_rect(_edge, Rect2(x, 0.0, run, thick), false, shade)
		draw_texture_rect(_edge, Rect2(x + run, span.y, -run, -thick), false, shade)
	var down: int = int(ceil(span.y / maxf(run, 1.0)))
	for step: int in down:
		var y: float = float(step) * run
		# Turned on their side: the same carving runs up the jambs.
		draw_set_transform(Vector2(thick, y), -PI * 0.5, Vector2.ONE)
		draw_texture_rect(_edge, Rect2(0.0, 0.0, run, thick), false, shade)
		draw_set_transform(Vector2(span.x - thick, y + run), PI * 0.5, Vector2.ONE)
		draw_texture_rect(_edge, Rect2(0.0, 0.0, run, thick), false, shade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _corner == null:
		return
	var box: float = thick * 2.4
	draw_texture_rect(_corner, Rect2(0.0, 0.0, box, box), false, shade)
	draw_texture_rect(_corner, Rect2(span.x, 0.0, -box, box), false, shade)
	draw_texture_rect(_corner, Rect2(0.0, span.y, box, -box), false, shade)
	draw_texture_rect(_corner, Rect2(span.x, span.y, -box, -box), false, shade)


## The hanging foliage, in the two top corners.
##
## Each piece keeps its own clock so the corner is never two copies of one
## motion, and the sway is two rates rather than one so it has no period a
## person can catch - the argument the menu's vines are built on.
func _draw_corners(span: Vector2) -> void:
	if _hangers.is_empty():
		return
	var reach: float = minf(span.y * HANG, 300.0)
	for side: int in 2:
		var edge: float = BORDER * 0.6 if side == 0 else span.x - BORDER * 0.6
		var out: float = 1.0 if side == 0 else -1.0
		for index: int in _hangers.size():
			var art: Texture2D = _hangers[index]
			var own: float = float(index) * 1.7 + float(side) * 3.1
			var sway: float = sin(_time * 0.43 + own) * 0.62 \
				+ sin(_time * 0.71 + own * 1.4) * 0.38
			var tall: float = reach * (0.62 + 0.30 * fposmod(own * 0.618, 1.0))
			var wide: float = tall * float(art.get_width()) \
				/ maxf(float(art.get_height()), 1.0)
			var along: float = (0.18 + 0.26 * float(index)) * reach
			var at := Vector2(edge + out * along + sway * 5.0, -tall * 0.10)
			# Graded down: these hang in front of a lit scene and a piece at full
			# brightness reads as a sticker rather than as foliage in shadow.
			var shade := Color(0.78, 0.80, 0.74, 0.92)
			draw_texture_rect(art,
				Rect2(at.x, at.y, wide * out, tall), false, shade)
