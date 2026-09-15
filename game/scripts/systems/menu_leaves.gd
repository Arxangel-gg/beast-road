class_name MenuLeaves
extends Node2D

## Leaves that let go of the hanging vines and fall through the menu.
##
## **Owner brief, 2026-09-15:** "add falling leaf particles that sometimes
## procedurally fall from the hanging vines on the main menu screen. Some leaves
## fall behind the buttons, some more rarely fall in front of the menu buttons."
##
## **They fall from the vines rather than from the top of the screen**, which is
## the whole difference between weather and a place. A leaf begins at a point on
## a strand that is actually there - the corner hands them over - so it reads as
## something letting go rather than as an effect switched on.
##
## **Two layers, and the rarer one is in front.** A leaf that crosses the
## interface is the one that makes the screen feel three-dimensional, and it is
## also the one that can hide a word, so it is uncommon and small and moves
## quickly through. The common case falls behind the buttons where it can only
## ever add depth.
##
## Drawn with the same painted leaf sprays the vines are made of, tumbling on
## their own axis and drifting on the corner's own gust, so a leaf and the
## strand it fell from are moving in the same air.

## The art a leaf is cut from. The same sprays the strands carry, so a leaf is
## recognisably off *these* vines.
const ART: Array[String] = [
	"res://art/ui/menu_leaves.png",
	"res://art/ui/menu_frond.png",
	"res://art/ui/menu_tendril.png",
]

## Where leaves may let go, in this node's space, and what tint they take. The
## stage refreshes it whenever the corners are laid out.
var sources: Array[Dictionary] = []
var span: Vector2 = Vector2(1920.0, 1080.0)

var _leaves: Array[Dictionary] = []
var _art: Array[Texture2D] = []
var _time: float = 0.0
var _next: float = 1.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	for path: String in ART:
		if ResourceLoader.exists(path):
			_art.append(load(path) as Texture2D)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)


## Where the leaves come from: one entry per strand the corners are drawing.
func fall_from(points: Array[Dictionary]) -> void:
	sources = points


func _process(delta: float) -> void:
	_time += delta
	_next -= delta
	if _next <= 0.0:
		_next = _rng.randf_range(Balance.MENU_LEAF_EVERY.x, Balance.MENU_LEAF_EVERY.y)
		_drop()
	var falling: Array[Dictionary] = []
	for leaf: Dictionary in _leaves:
		_carry(leaf, delta)
		if float(leaf["at"].y) < span.y + 80.0:
			falling.append(leaf)
	_leaves = falling
	queue_redraw()


## One leaf lets go.
func _drop() -> void:
	if sources.is_empty() or _art.is_empty():
		return
	if _leaves.size() >= Balance.MENU_LEAF_CEILING:
		return
	var from: Dictionary = sources[_rng.randi() % sources.size()]
	# **In front only now and then.** See the note at the top: the rare layer is
	# the one that sells the depth and the one that can cover a word.
	var in_front: bool = _rng.randf() < Balance.MENU_LEAF_FRONT_SHARE
	_leaves.append({
		"at": from["at"] as Vector2,
		"art": _rng.randi() % _art.size(),
		"tint": from.get("tint", Color.WHITE) as Color,
		"size": span.y * Balance.MENU_LEAF_SIZE * _rng.randf_range(0.7, 1.25)
			* (0.78 if in_front else 1.0),
		"spin": _rng.randf_range(-2.2, 2.2),
		"turn": _rng.randf() * TAU,
		# A leaf does not fall straight: it swings across its own drift on a
		# slow beat, which is most of what makes one read as a leaf rather than
		# as a falling object.
		"swing": _rng.randf_range(18.0, 54.0),
		"beat": _rng.randf_range(0.7, 1.6),
		"phase": _rng.randf() * TAU,
		"fall": span.y * _rng.randf_range(0.035, 0.075) * (1.35 if in_front else 1.0),
		"front": in_front,
	})


func _carry(leaf: Dictionary, delta: float) -> void:
	var at: Vector2 = leaf["at"]
	var sway: float = sin(_time * float(leaf["beat"]) + float(leaf["phase"]))
	at.x += sway * float(leaf["swing"]) * delta
	at.y += float(leaf["fall"]) * delta
	leaf["at"] = at
	leaf["turn"] = float(leaf["turn"]) + float(leaf["spin"]) * delta * (0.3 + absf(sway))


func _draw() -> void:
	for leaf: Dictionary in _leaves:
		var texture: Texture2D = _art[int(leaf["art"])]
		if texture == null:
			continue
		var wide: float = float(leaf["size"])
		var tall: float = wide * float(texture.get_height()) \
			/ maxf(float(texture.get_width()), 1.0)
		# A leaf edge-on is a line: the swing is drawn as a squash across its
		# own width, which costs nothing and reads as a tumble in three
		# dimensions rather than a spin in two.
		var edge: float = 0.35 + 0.65 * absf(cos(float(leaf["turn"]) * 0.5))
		draw_set_transform(leaf["at"] as Vector2, float(leaf["turn"]), Vector2.ONE)
		draw_texture_rect(texture,
			Rect2(-wide * 0.5 * edge, -tall * 0.5, wide * edge, tall), false,
			leaf["tint"] as Color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How many leaves are in the air, and how many of those are in front. For the
## gate, which has no other way to ask whether the rare layer is rare.
func counts() -> Vector2i:
	var front: int = 0
	for leaf: Dictionary in _leaves:
		if bool(leaf["front"]):
			front += 1
	return Vector2i(_leaves.size(), front)


## Advance the fall by hand. For the gate, which has no frames to spend.
func advance(delta: float) -> void:
	_process(delta)
