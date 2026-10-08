class_name ArsenalStrip
extends HBoxContainer

## The Arsenal on the HUD: one tile a weapon, its readiness as an arc, its
## level as pips, the Warden's own weapons first and the board's after a gap.
##
## `docs/AUTO_ARSENAL_2026-09-27.md` built the weapons and left them invisible
## between drafts - a player held eight things that fired on their own and the
## only place they were listed was the pause screen. A weapon whose clock a
## player can see is one they can fight *around*: step in as the pulse is due,
## hold the line while the guard reforms.
##
## **A readout reads.** It asks each Arsenal for `readout()` on a clock and
## draws it; it changes no number, rolls no die, sends nothing and is read by
## nothing. Built on a desktop only: a landscape phone's combat row has no
## width to give and the pad is full, so a thumb reads the hand on the pause
## screen as before.

const TILE: float = 40.0
const ICON: float = 30.0
const GAP: float = 14.0
const PIP: float = 4.0

var hero: Hero = null
var board: Battlefield = null

var _redraw_left: float = 0.0
var _tiles: Array[_Tile] = []
var _spacer: Control = null


class _Tile extends Control:
	var card: RoadCardData = null
	var level: int = 1
	var share: float = 1.0
	var icon: TextureRect = null

	func _init() -> void:
		custom_minimum_size = Vector2(TILE, TILE)
		mouse_filter = Control.MOUSE_FILTER_PASS
		icon = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2((TILE - ICON) * 0.5, (TILE - ICON) * 0.5 - 2.0)
		icon.size = Vector2(ICON, ICON)
		add_child(icon)

	func show_card(shown: RoadCardData, at_level: int, ready: float) -> void:
		if card != shown:
			card = shown
			var path: String = shown.get_sprite_path()
			icon.texture = load(path) as Texture2D if ResourceLoader.exists(path) else null
			tooltip_text = "%s  ·  %s" % [shown.display_name, shown.description]
		level = at_level
		share = clampf(ready, 0.0, 1.0)
		queue_redraw()

	func _draw() -> void:
		var tint: Color = card.weapon_data().tint if card != null and card.weapon_data() != null else Color("cfd6d0")
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.05, 0.06, 0.07, 0.82))
		draw_rect(rect, Color(tint.r, tint.g, tint.b, 0.35), false, 1.0)
		# The readiness arc round the mark, gold as it fills.
		var centre: Vector2 = size * 0.5 - Vector2(0.0, 2.0)
		if share < 0.999:
			draw_arc(centre, ICON * 0.56, -PI * 0.5, -PI * 0.5 + TAU, 40,
				Color(0.0, 0.0, 0.0, 0.45), 3.0, true)
			icon.modulate = Color(0.55, 0.55, 0.55, 0.85)
		else:
			icon.modulate = Color.WHITE
		draw_arc(centre, ICON * 0.56, -PI * 0.5, -PI * 0.5 + TAU * share, 40,
			Color("f2c96b") if share >= 0.999 else tint.lerp(Color("f2c96b"), 0.5), 3.0, true)
		# A pip a level, along the bottom edge.
		var pips: int = clampi(level, 1, 5)
		var width: float = float(pips) * PIP + float(pips - 1) * 2.0
		var x: float = (size.x - width) * 0.5
		for pip: int in pips:
			draw_rect(Rect2(x + float(pip) * (PIP + 2.0), size.y - PIP - 2.0, PIP, PIP), Color("f2c96b"))


func _ready() -> void:
	name = "ArsenalStrip"
	add_theme_constant_override("separation", 4)
	alignment = BoxContainer.ALIGNMENT_END
	size_flags_vertical = Control.SIZE_SHRINK_END
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(delta: float) -> void:
	_redraw_left -= delta
	if _redraw_left > 0.0:
		return
	_redraw_left = 1.0 / Balance.ARSENAL_STRIP_HZ
	refresh()


## The hand as it stands this moment. Public so a gate can read it back
## without waiting on the clock.
func refresh() -> void:
	var rows: Array[Dictionary] = []
	var own: int = 0
	if hero != null and is_instance_valid(hero) and hero.arsenal != null:
		rows = hero.arsenal.readout()
		own = rows.size()
	if board != null and is_instance_valid(board) and board.board_arsenal() != null:
		rows.append_array(board.board_arsenal().readout())
	if rows.size() > Balance.ARSENAL_STRIP_MAX:
		rows.resize(Balance.ARSENAL_STRIP_MAX)
		own = mini(own, Balance.ARSENAL_STRIP_MAX)
	visible = not rows.is_empty()
	# Reuse the tiles: a strip rebuilt ten times a second would be ten
	# allocations a second for a picture that mostly has not changed.
	while _tiles.size() < rows.size():
		var tile := _Tile.new()
		_tiles.append(tile)
		add_child(tile)
	for at: int in _tiles.size():
		var tile: _Tile = _tiles[at]
		if at >= rows.size():
			tile.visible = false
			continue
		tile.visible = true
		var row: Dictionary = rows[at]
		tile.show_card(row["card"] as RoadCardData, int(row["level"]), float(row["share"]))
	# The gap between the Warden's weapons and the board's.
	if _spacer == null:
		_spacer = Control.new()
		_spacer.custom_minimum_size = Vector2(GAP, 0.0)
		_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_spacer)
	_spacer.visible = own > 0 and rows.size() > own
	if _spacer.visible:
		move_child(_spacer, own)


## How many tiles are showing, for a gate.
func shown() -> int:
	var count: int = 0
	for tile: _Tile in _tiles:
		if tile.visible:
			count += 1
	return count


func tile_share(at: int) -> float:
	return _tiles[at].share if at >= 0 and at < _tiles.size() else -1.0
