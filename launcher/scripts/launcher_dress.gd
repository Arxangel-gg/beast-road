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
## **Things that hang, and only things that hang.** `menu_branch_mossy` was in
## this list and came out drawn vertically off a strand, which is a branch
## dangling by one end - the menu lays branches *along* the top, where a branch
## belongs, and hangs fruit off them. Until the launcher has somewhere to lay
## one, it carries only what a strand can legitimately hold.
const HANGERS: Array[String] = [
	"res://art/menu_frond.png",
	"res://art/menu_hanger_fruit.png",
	"res://art/menu_hanger_berries.png",
]

## How much of the window the carved border takes, and how far a frond hangs.
const BORDER: float = 34.0
const HANG: float = 0.30

## The corner bracket, as a multiple of the band's thickness. The band is inset
## by most of it so the two do not overlap - see `_draw_border`.
const CORNER_BOX: float = 1.9

## How far the end of a strand swings. The root barely moves; this is the tip.
const SWING: float = 7.0

## **Graded down, hard.** Foliage at full brightness in front of a dusk painting
## is the mistake this project has made three separate times on the menu - the
## birds came out black on black, the Warden came out black on black, and the
## first cut of this came out as fruit glowing in a dark doorway. These hang in
## shadow and are painted that way.
const LEAF_SHADE: Color = Color(0.62, 0.66, 0.58, 0.95)
const VINE_SHADE: Color = Color(0.20, 0.24, 0.18, 0.90)

## Drifting specks, so the window is never quite still while it waits.
const MOTES: int = 9

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
	_draw_motes(span)


## The carved band, inset so the corner brackets sit cleanly on the joins.
##
## **A missing piece leaves the launcher plain rather than broken**, which is the
## rule the game's frame is built under too: art that fails to load must never
## take the window with it.
func _draw_border(span: Vector2) -> void:
	if _edge == null:
		return
	var thick: float = BORDER
	var run: float = float(_edge.get_width()) * (thick / maxf(float(_edge.get_height()), 1.0))
	# **The band starts after the bracket, not under it.** The first cut tiled
	# from zero and then dropped a corner 2.4 times the band's thickness on top,
	# so every corner was two pieces of art arguing. The bracket is the join now
	# and the band runs between them.
	var box: float = thick * CORNER_BOX
	var shade := Color(0.86, 0.88, 0.84, 0.82)
	var from: float = box * 0.82
	var to_x: float = span.x - box * 0.82
	var to_y: float = span.y - box * 0.82

	var x: float = from
	while x < to_x:
		var wide: float = minf(run, to_x - x)
		var part: float = wide / run
		draw_texture_rect_region(_edge, Rect2(x, 0.0, wide, thick),
			Rect2(0.0, 0.0, float(_edge.get_width()) * part, float(_edge.get_height())),
			shade)
		draw_texture_rect_region(_edge, Rect2(x, span.y - thick, wide, thick),
			Rect2(0.0, 0.0, float(_edge.get_width()) * part, float(_edge.get_height())),
			shade)
		x += run
	var y: float = from
	while y < to_y:
		var tall: float = minf(run, to_y - y)
		var part: float = tall / run
		var region := Rect2(0.0, 0.0,
			float(_edge.get_width()) * part, float(_edge.get_height()))
		draw_set_transform(Vector2(thick, y), -PI * 0.5, Vector2.ONE)
		draw_texture_rect_region(_edge, Rect2(0.0, 0.0, tall, thick), region, shade)
		draw_set_transform(Vector2(span.x - thick, y + tall), PI * 0.5, Vector2.ONE)
		draw_texture_rect_region(_edge, Rect2(0.0, 0.0, tall, thick), region, shade)
		y += run
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if _corner == null:
		return
	# The painting is a top-left bracket; the other three are it mirrored, which
	# a negative width or height does without a second asset.
	draw_texture_rect(_corner, Rect2(0.0, 0.0, box, box), false, shade)
	draw_texture_rect(_corner, Rect2(span.x, 0.0, -box, box), false, shade)
	draw_texture_rect(_corner, Rect2(0.0, span.y, box, -box), false, shade)
	draw_texture_rect(_corner, Rect2(span.x, span.y, -box, -box), false, shade)


## The hanging foliage: a strand first, then what hangs off the end of it.
##
## **Rooted rather than placed.** The first cut put fruit along the top edge at
## full brightness with nothing above it, and a pear floating in a doorway reads
## as a sticker. Every hanging thing here grows from a strand that starts inside
## the frame, and the strand is what sways - the fruit at the end travels
## furthest, because a hanging thing is a pendulum and the root barely moves.
##
## **Graded down, hard.** Foliage at full brightness in front of a dusk painting
## is the mistake this project has made three separate times on the menu - the
## birds, the Warden, and then this. These hang in shadow.
func _draw_corners(span: Vector2) -> void:
	if _hangers.is_empty():
		return
	var reach: float = clampf(span.y * HANG, 120.0, 300.0)
	for side: int in 2:
		var root_x: float = BORDER * 1.5 if side == 0 else span.x - BORDER * 1.5
		var out: float = 1.0 if side == 0 else -1.0
		for index: int in _hangers.size():
			var art: Texture2D = _hangers[index]
			var own: float = float(index) * 1.7 + float(side) * 3.1
			# Two rates, so the corner has no period a person can catch - the
			# argument the menu's vines and the beast's tail are both built on.
			var sway: float = sin(_time * 0.43 + own) * 0.62 \
				+ sin(_time * 0.71 + own * 1.4) * 0.38
			var drop: float = reach * (0.34 + 0.30 * fposmod(own * 0.618, 1.0))
			var along: float = (0.55 + 0.80 * float(index)) * BORDER * 1.4
			var root := Vector2(root_x + out * along, BORDER * 0.5)
			var hang := Vector2(root.x + sway * SWING, root.y + drop)
			_draw_strand(root, hang)
			# The piece itself, hung off the end and swinging with it.
			var tall: float = reach * 0.42 * (0.72 + 0.34 * fposmod(own * 0.382, 1.0))
			var wide: float = tall * float(art.get_width()) \
				/ maxf(float(art.get_height()), 1.0)
			# **Kept inside the frame.** A pear half off the window is a crop
			# rather than a piece of art, and the right-hand corner produced one
			# on the first run.
			var left: float = hang.x - wide * 0.5 * out
			if out > 0.0:
				left = maxf(left, BORDER * 0.9)
			else:
				left = minf(left, span.x - BORDER * 0.9)
			draw_texture_rect(art,
				Rect2(left, hang.y, wide * out, tall), false, LEAF_SHADE)


## One strand, tapering and darker than what hangs off it.
##
## Drawn as a few short segments rather than a line so it can bend: a vine that
## is straight from root to fruit reads as a wire.
func _draw_strand(root: Vector2, tip: Vector2) -> void:
	var steps: int = 6
	var last: Vector2 = root
	for step: int in range(1, steps + 1):
		var t: float = float(step) / float(steps)
		# Eased so the bend is near the top, where a strand actually bends.
		var at: Vector2 = root.lerp(tip, t * t * (3.0 - 2.0 * t))
		draw_line(last, at, VINE_SHADE, maxf(3.0 * (1.0 - t * 0.55), 1.0), true)
		last = at


## A few motes drifting through the corners, so the window is never quite still
## while it waits on a download.
func _draw_motes(span: Vector2) -> void:
	for index: int in MOTES:
		var own: float = float(index) * 2.399963
		var drift: float = fposmod(_time * (0.03 + 0.02 * fposmod(own, 1.0)) + own, 1.0)
		var side: float = 1.0 if index % 2 == 0 else -1.0
		var x: float = span.x * (0.10 + 0.16 * fposmod(own * 0.618, 1.0))
		if side < 0.0:
			x = span.x - x
		var y: float = span.y * (0.08 + 0.74 * drift)
		var glow: float = sin(_time * 1.7 + own * 3.1) * 0.5 + 0.5
		var lit: float = 0.08 + 0.16 * glow
		draw_circle(Vector2(x + sin(_time * 0.6 + own) * 9.0, y), 2.2,
			Color(1.0, 0.86, 0.52, lit))
