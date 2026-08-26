class_name PlacementCursor
extends Node2D

## The build cursor for free placement (GDD §13).
##
## Replaces the twelve fixed `TowerSlot` nodes. With placement free there is
## nothing to pre-instantiate and nothing to click on, so this draws the 2x2
## footprint under the mouse, says whether it is legal, marks fusion tiles, and
## turns a click into an anchor.
##
## It draws nothing at all outside Preparation. Building is locked to Preparation
## (`RunState.can_build_now`), and a grid overlay hovering over a live battle is
## noise on top of the fight.

## The player clicked a legal tile. The HUD opens the build panel on it.
signal tile_clicked(anchor: Vector2i)

## A *road* tile was clicked, which is a different question with a different
## answer: plots take towers, roads take traps and barricades.
##
## Its own signal rather than a flag on the one above, because the two open
## different panels offering different things, and a caller that had to ask
## "which kind was it" before it could act would be the same decision made twice.
signal road_tile_clicked(tile: Vector2i)

## How often the hover is recomputed. The mouse moves continuously; the *tile*
## under it does not, and re-querying placement legality every frame is work for
## an answer that changes a few times a second.
const HOVER_INTERVAL: float = 0.05

var _field: Battlefield = null
var _hover: Vector2i = Vector2i(-999, -999)
var _legal: bool = false

## True when a tower cannot go here but *something* can - a road takes traps and
## barricades. Drawn amber rather than red, because the two are different
## answers and one colour for both told the player a lie: a red box on a road
## reads as "nothing here", and then a trap drops onto it happily.
var _road: bool = false
var _fusions: Array[Dictionary] = []
var _timer: float = 0.0


func setup(field: Battlefield) -> void:
	_field = field


func _ready() -> void:
	z_index = 5
	EventBus.tower_changed.connect(func(_a: Vector2i) -> void: queue_redraw())
	EventBus.phase_changed.connect(func(_n: int, _p: int) -> void: queue_redraw())
	EventBus.build_mode_changed.connect(func(_b: bool) -> void: queue_redraw())


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = HOVER_INTERVAL
	if not _is_active() or not _field.visible:
		if _hover.x != -999:
			_hover = Vector2i(-999, -999)
			queue_redraw()
		return

	var tile: Vector2i = _anchor_under_mouse()
	if tile == _hover:
		return
	_hover = tile
	_legal = _field.placement_problem(tile).is_empty()
	_road = not _legal and _field.grid != null 		and _field.grid.cell_at(tile) == BattleGrid.Cell.ROAD
	_fusions = RunState.combinations_for_tile(tile)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active() or not _field.visible:
		return
	var click := event as InputEventMouseButton
	if click == null or click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return

	# On release, not on press, and that is what makes touch work.
	#
	# Godot emulates a mouse from finger 0, and the emulated events arrive
	# *before* the real touch event - so at press time nothing yet knows the
	# finger belongs to a thumb stick. By release it does. Acting on release also
	# means a player can slide off a plot to cancel, which is the behaviour a
	# mouse already had everywhere else in this interface.
	if TouchInput.owns_pointer():
		return
	var tile: Vector2i = _anchor_under_mouse()
	# An occupied tile is still worth clicking: that is how a built tower is
	# inspected, upgraded and sold. Only genuinely unbuildable ground is ignored,
	# so a misclick on a road does not close whatever the player had open.
	if _field.placement_problem(tile).is_empty() or not RunState.tile_is_empty(tile):
		tile_clicked.emit(tile)
		get_viewport().set_input_as_handled()
		return

	# A road, which until now did nothing at all - and was therefore the reason
	# traps and barricades shipped with no way to reach them. The exact tile
	# under the cursor rather than the 2x2 anchor: a trap occupies one tile, and
	# offsetting it half a footprint would lay it on the tile beside the one the
	# player pointed at.
	var exact: Vector2i = BattleGrid.world_to_tile(get_global_mouse_position())
	if _field.grid.cell_at(exact) == BattleGrid.Cell.ROAD:
		road_tile_clicked.emit(exact)
		get_viewport().set_input_as_handled()


## Which anchor the mouse is over.
##
## The mouse points at a tile, but a tower is 2x2, so the anchor is offset half a
## footprint up and left - otherwise the footprint would always hang down-right
## of the cursor and never feel centred on it.
func _anchor_under_mouse() -> Vector2i:
	var at: Vector2 = get_global_mouse_position()
	return BattleGrid.world_to_tile(at) - Vector2i(BattleGrid.FOOTPRINT - 1, BattleGrid.FOOTPRINT - 1)


## Whether placement is legal right now. Deliberately *not* a question about
## visibility: Godot already stops drawing an invisible subtree, and folding the
## scope's visibility in here made "can the player build" depend on which scope
## happens to be on screen. Input checks visibility separately.
func _is_active() -> bool:
	# Build mode as well as the phase. Preparation is now two things - laying
	# towers down and fighting off whatever wandered in - and a grid overlay that
	# swallows the left mouse button during the fight half would make the second
	# one impossible. See `GameDirector.build_mode`.
	return _field != null and _field.grid != null and RunState.can_build_now() 		and GameDirector.build_mode


func _draw() -> void:
	if not _is_active() or _hover.x == -999:
		return

	var tile_size := Vector2(BattleGrid.TILE, BattleGrid.TILE)
	var origin: Vector2 = BattleGrid.tile_to_world(_hover) - tile_size * 0.5
	var span: Vector2 = tile_size * float(BattleGrid.FOOTPRINT)

	# Occupied reads as neutral rather than as an error: clicking a built tower is
	# a legitimate thing to do, and a red box over your own tower says "broken".
	var occupied: bool = not RunState.tile_is_empty(_hover)
	var fill: Color
	if occupied:
		fill = Color(0.85, 0.80, 0.72, 0.16)
	elif _legal:
		fill = Color(0.62, 0.90, 0.72, 0.18)
	elif _road:
		# Amber: the wrong thing for *this* tool, not forbidden ground.
		fill = Color(0.92, 0.73, 0.26, 0.20)
	else:
		fill = Color(0.78, 0.29, 0.22, 0.20)
	draw_rect(Rect2(origin, span), fill, true)
	draw_rect(Rect2(origin, span), Color(fill.r, fill.g, fill.b, 0.85), false, 2.0)

	# Amber deserves a sentence as well as a colour. A player who has not yet
	# found the trap panel has no way to learn what the second colour means, and
	# a legend nobody reads is not a legend.
	if _road and not occupied:
		var font: Font = ThemeDB.fallback_font
		if font != null:
			var say: String = "road - lay a trap or raise a barricade"
			var width: float = font.get_string_size(say,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13).x
			draw_string(font, origin + Vector2(span.x * 0.5 - width * 0.5, -8.0),
				say, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Color("f0c268"))

	# Fusion tiles are the reason placement is a puzzle rather than a scatter, so
	# they are called out on the ground and the parents that make them are named
	# by drawing the pair that would fuse.
	if _legal and not _fusions.is_empty():
		draw_rect(Rect2(origin, span), Color("e8a33d", 0.30), true)
		draw_rect(Rect2(origin - Vector2(3, 3), span + Vector2(6, 6)),
			Color("e8a33d", 0.95), false, 3.0)
		for option: Dictionary in _fusions:
			for key: String in ["a", "b"]:
				var parent: Vector2i = option[key]
				var at: Vector2 = BattleGrid.tile_to_world(parent) - tile_size * 0.5
				draw_rect(Rect2(at, span), Color("e8a33d", 0.55), false, 2.0)
