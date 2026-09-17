class_name PixelFilter
extends CanvasLayer

## **One grid for the whole world** (owner, 2026-09-17).
##
## The first brief: *"can you apply a pixel art shader to the whole screen? One
## that is perfectly polished and optimized, and also include it in the settings
## toggle, in hopes that this will give a more cohesive look to the whole game."*
##
## **What it is actually fixing.** The sprites are pixel art on their own grid;
## everything the engine draws beside them - blood fans, flame cones, the fog's
## soft edge, a bar's fill, a ring at a telegraph - is drawn at device resolution
## and sits on no grid at all. That is two materials in one frame, and snapping
## the finished picture to a single grid is what puts them on the same one.
##
## **Where it sits is the whole of what it covers, and there are two of it.** A
## screen filter pixelates what was drawn below it and cannot touch what is drawn
## above, so one at `Balance.UI_PIXEL_FILTER_LAYER` takes every scope and leaves
## the HUD alone, and a second at `UI_PIXEL_FILTER_UI_LAYER` takes the HUD too
## when the owner's second switch asks for it: *"a toggle in the settings for
## whether the pixelshader should also affect UI panel windows, buttons, and
## images etc as well except for text."*
##
## **Two instances rather than one that moves**, because they answer to two
## preferences and a player may want the first without the second. One node
## hopping between layer 15 and layer 24 would be one switch pretending to be
## two.
##
## **Neither of them ever takes the type.** `CrispText` sits above both and
## redraws every string sharp, having muted the copy underneath - a blocky glyph
## under a sharp one is a fringe rather than a letter. What it cannot redraw it
## hands back here as an exempt rectangle.
##
## The grid itself is `PixelGrid`, which is a `Control` so that the main menu -
## one tree drawing in order, with no layers to sit between - can put the same
## thing between its painted art and its buttons.

## Which switch this filter answers to, and therefore what it is over.
enum Covers {WORLD, INTERFACE}

var covers: Covers = Covers.WORLD

var _grid: PixelGrid = null


func _ready() -> void:
	name = "PixelFilter" if covers == Covers.WORLD else "PixelFilterUI"
	layer = Balance.UI_PIXEL_FILTER_LAYER if covers == Covers.WORLD 		else Balance.UI_PIXEL_FILTER_UI_LAYER
	# So the switch in the video settings reaches it while the game is running,
	# rather than changing a saved value and nothing on screen - which is how a
	# setting reads as broken, and is why this group exists.
	add_to_group(Graphics.SETTINGS_GROUP)
	_grid = PixelGrid.new()
	_grid.name = "Grid"
	add_child(_grid)
	refresh_from_settings()


## Reads the setting. Named to match the other display preferences, because
## `Graphics.apply_to_scene` calls this on every node that has it.
func refresh_from_settings() -> void:
	set_enabled(Graphics.pixel_filter() if covers == Covers.WORLD 		else Graphics.pixel_filter_ui())


func set_enabled(on: bool) -> void:
	if _grid != null:
		_grid.set_enabled(on)


func enabled() -> bool:
	return _grid != null and _grid.enabled()


## The band itself, for `CrispText` to hand its exempt rectangles to. Valid
## from the moment this node is added to a tree, since `add_child` runs
## `_ready` there and then.
func grid() -> PixelGrid:
	return _grid


func set_exclusions(rects: Array[Rect2]) -> void:
	if _grid != null:
		_grid.set_exclusions(rects)


func exclusions() -> int:
	return _grid.exclusions() if _grid != null else 0


## Kept on this class as well as on `PixelGrid`, because the gate and the
## settings readout both ask whichever of the two they can see.
static func block_for(view: Vector2) -> float:
	return PixelGrid.block_for(view)


static func block_at(view: Vector2, want: float) -> float:
	return PixelGrid.block_at(view, want)
