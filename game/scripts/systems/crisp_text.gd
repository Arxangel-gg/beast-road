class_name CrispText
extends Control

## **The type, which the grid steps over.**
##
## Owner, 2026-09-17: *"The pixelshader should apply to everything in the game if
## possible except for text"*, and, on the town scope, *"The text in the town
## view scope is not legible with the pixelshader so text must not be
## affected."*
##
## **This was muted-and-redrawn until 2026-09-17, and that is what broke it.**
## The first cut turned every caption transparent where it was authored and drew
## it again above the filter with `draw_string`. That is a second implementation
## of Godot's own text layout, and it drifted exactly where a second
## implementation drifts: a `Button` insets its caption by its style box and
## again by its icon, a `Label` has a vertical alignment of its own, a
## `LineEdit` has a caret column - and none of it was carried. The owner reported
## it as the interface toggle causing *"the text to get misaligned and out of
## position from where the texts used to be and are supposed to stay at"*.
##
## **So nothing is drawn twice now.** This walks the tree, collects where every
## piece of type is standing, and stamps those rectangles into a small mask that
## the grid's shader reads. The engine paints every string exactly where it
## always did; the filter simply does not touch those pixels. Text cannot move,
## because nothing moves it.
##
## Three other things fell out of that, each of which had been a rule to
## remember:
##
## - **There is no bound.** Eight `vec4`s held eight captions on screens that
##   routinely carry forty; a mask holds as many as the screen does.
## - **A `RichTextLabel` is no longer a special case.** Marked-up text, an editor,
##   a button with an icon in it and a plain label are all a rectangle.
## - **Nothing has to be put back.** There is no override to restore, so a screen
##   torn down with the filter on cannot leave its captions invisible, and a
##   control freed while this was watching it cannot be written to.
##
## **It reads the tree; it does not own it.** Nothing is re-parented, resized,
## recoloured or given a different child. Turn the node off and the frame is
## identical but for the grid running over the type - the same bound the fog of
## war and the phenotypes are held to.

## Controls that carry a string the grid must step over.
##
## Every kind, rather than the ones `draw_string` could reproduce: the mask does
## not care what is inside the rectangle.
const DRAWN: Array[String] = [
	"Label", "Button", "CheckBox", "CheckButton", "OptionButton", "LineEdit",
	"RichTextLabel", "TextEdit", "CodeEdit", "MenuButton", "LinkButton",
	"SpinBox",
]

## Kept so the release path below still knows what a muted control looked like.
##
## **Nothing mutes anything any more**, and this list is what `_release` walks to
## undo a mute left behind by a build that did. It is cheap, it runs once, and
## the alternative is a player who upgrades mid-session and finds one screen's
## captions permanently transparent.
const COLOURS: Array[String] = [
	"font_color", "font_hover_color", "font_pressed_color",
	"font_focus_color", "font_disabled_color", "font_hover_pressed_color",
	"font_uneditable_color", "font_placeholder_color",
]

## How coarse the mask is, in screen pixels to one mask texel. The reasoning
## is on the constant; it lives in `Balance` because it is a tuning value
## (working rule 4) and is read here so the arithmetic below says what it means.
const GRAIN: int = Balance.UI_PIXEL_FILTER_MASK_GRAIN

## Roots whose text the world's grid steps over. The world's grid is always
## under the interface, so these are the strings parented into a scope - the
## town's tier captions are the reported case.
var world_roots: Array[Node] = []

## Roots whose text the interface's grid steps over, and only while that grid is
## on.
var ui_roots: Array[Node] = []

## The interface's grid. A `PixelGrid` rather than a `PixelFilter`, because the
## main menu has the grid without the layer.
var ui_filter_grid: PixelGrid = null

## The world's grid, so the strings parented into a scope are stepped over there
## too. **Set by the caller that builds both**; left null it simply does not
## push, which is what the main menu did before it had one.
var world_filter_grid: PixelGrid = null

var _muted: Array[Dictionary] = []
var _rects: Array[Rect2] = []
var _ui_rects: Array[Rect2] = []
var _on: bool = false
var _ui: bool = false
var _signature: int = 0


func _ready() -> void:
	name = "CrispText"
	# Anchors *and* offsets - see `PixelGrid._ready`. The bare call keeps the
	# rect the control already has, which inside `_ready` is nothing at all.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# So the two switches in the video settings reach it while the game is
	# running. Without this a preference changes a saved value and nothing on
	# screen, which is how a setting reads as broken.
	add_to_group(Graphics.SETTINGS_GROUP)
	refresh_from_settings()


func refresh_from_settings() -> void:
	set_enabled(Graphics.pixel_filter(), Graphics.pixel_filter_ui())


## Both switches at once, because the second only means anything under the
## first: a sharp world under a blocky interface is this feature's own problem
## pointing the other way.
func set_enabled(on: bool, over_ui: bool) -> void:
	var changed: bool = on != _on or over_ui != _ui
	_on = on
	_ui = on and over_ui
	if changed:
		_release()
		_signature = 0
		if not _on:
			_clear_masks()


func enabled() -> bool:
	return _on


func over_ui() -> bool:
	return _ui


## How many pieces of type the grid is stepping over. For the gate, which has no
## screen to read and needs the difference between "protected the text" and
## "protected nothing" - a comparison of two nothings being the most dangerous
## shape a check can take.
func drawn() -> int:
	return _ui_rects.size() if _ui else _rects.size()


## Left at zero by design: nothing is muted any more. Kept because the gate asks
## it, and because "how many controls is this holding hostage" is worth being
## able to read as a number rather than inferring from an absence.
func muted() -> int:
	return _muted.size()


func _process(_delta: float) -> void:
	if not _on:
		return
	_gather()


## Walks the roots and records where every piece of type is standing.
func _gather() -> void:
	_rects.clear()
	_ui_rects.clear()

	# `Variant` loop variables, because a typed one casts on assignment - so a
	# root freed while this was watching it would throw here, before `_walk`
	# could guard it. Same reason the walk and the release both take one.
	for root: Variant in world_roots:
		_walk(root, _rects)
	_ui_rects.append_array(_rects)
	if _ui:
		for root: Variant in ui_roots:
			_walk(root, _ui_rects)

	# **Stamped only when something moved.** A mask is a texture upload, and a
	# screenful of captions whose rectangles are identical this frame is the
	# common case by a wide margin - a health figure changes its *text* forty
	# times a second and its rectangle never.
	var now: int = _fingerprint()
	if now == _signature:
		return
	_signature = now
	if world_filter_grid != null and is_instance_valid(world_filter_grid):
		world_filter_grid.set_text_mask(_stamp(_rects), _rects.size())
	if ui_filter_grid != null and is_instance_valid(ui_filter_grid):
		ui_filter_grid.set_text_mask(_stamp(_ui_rects), _ui_rects.size())


## A number that changes when any rectangle does. Rounded to the mask's own
## grain, because a rectangle that moved a third of a texel stamps the same mask.
func _fingerprint() -> int:
	var seed_at: int = _ui_rects.size() * 31 + _rects.size()
	for rect: Rect2 in _ui_rects:
		seed_at = seed_at * 31 + int(rect.position.x / float(GRAIN))
		seed_at = seed_at * 31 + int(rect.position.y / float(GRAIN))
		seed_at = seed_at * 31 + int(rect.size.x / float(GRAIN))
		seed_at = seed_at * 31 + int(rect.size.y / float(GRAIN))
		seed_at = seed_at & 0x3FFFFFFF
	return seed_at


## The mask itself: black everywhere, white where a string is standing.
##
## Rectangles are grown *outward* to whole texels. A texel that only half covers
## a glyph would take half the glyph into the grid with it, and half a letter
## sharp is worse than a whole one blocky.
func _stamp(rects: Array[Rect2]) -> Image:
	var view: Vector2 = get_viewport().get_visible_rect().size
	var wide: int = maxi(int(ceil(view.x / float(GRAIN))), 1)
	var tall: int = maxi(int(ceil(view.y / float(GRAIN))), 1)
	var mask: Image = Image.create_empty(wide, tall, false, Image.FORMAT_R8)
	mask.fill(Color(0.0, 0.0, 0.0, 1.0))
	for rect: Rect2 in rects:
		var from := Vector2i(int(floor(rect.position.x / float(GRAIN))),
			int(floor(rect.position.y / float(GRAIN))))
		var to := Vector2i(int(ceil(rect.end.x / float(GRAIN))),
			int(ceil(rect.end.y / float(GRAIN))))
		from.x = clampi(from.x, 0, wide)
		from.y = clampi(from.y, 0, tall)
		to.x = clampi(to.x, 0, wide)
		to.y = clampi(to.y, 0, tall)
		if to.x <= from.x or to.y <= from.y:
			continue
		mask.fill_rect(Rect2i(from, to - from), Color(1.0, 1.0, 1.0, 1.0))
	return mask


func _clear_masks() -> void:
	if world_filter_grid != null and is_instance_valid(world_filter_grid):
		world_filter_grid.set_text_mask(null, 0)
	if ui_filter_grid != null and is_instance_valid(ui_filter_grid):
		ui_filter_grid.set_text_mask(null, 0)


## Takes a `Variant` for the same reason the release does: a root freed while
## this was watching it cannot be typed as a `Node` without throwing on the spot.
func _walk(from: Variant, into: Array[Rect2]) -> void:
	if from == null or not is_instance_valid(from):
		return
	var node: Node = from as Node
	if node == null:
		return
	if node == self:
		return
	var control: Control = node as Control
	if control != null:
		if not control.is_visible_in_tree():
			# A hidden branch draws nothing, so nothing under it needs
			# protecting - and descending anyway would hold open a rectangle of
			# screen where a closed panel used to be.
			return
		if DRAWN.has(control.get_class()) and _says_something(control):
			into.append(control.get_global_rect())
		# **Type a script painted itself, which `get_class` can never see.**
		# `BarName` writes "HP", "MP" and "SP" on the pool bars with
		# `draw_string`, because a Label cannot be smaller than its own font
		# and one anchored to an eight-pixel bar hangs off the bottom of it.
		# So its class is `Control`, it is on no list here, and the grid ran
		# straight over the three captions in the top corner of the HUD -
		# which is exactly what the owner reported.
		#
		# A method rather than another class name: anything that draws its own
		# lettering can say where, and nothing here has to know what it is.
		# **A TabContainer's tabs are drawn by a child nothing walks to.** The
		# strip of tab labels belongs to an internal `TabBar` that is not in
		# `get_children()`, so the grid ran straight over the words on the
		# settings screen's tabs and over nothing else on it - which is the
		# owner's report of 2026-09-17, and the same shape as `BarName`.
		#
		# The bar's own rect rather than the container's: a `TabContainer` is as
		# big as the page inside it, and holding *that* open would take the
		# whole settings screen out of the grid.
		elif control is TabContainer:
			var bar: TabBar = (control as TabContainer).get_tab_bar()
			if bar != null and is_instance_valid(bar) 					and bar.is_visible_in_tree():
				into.append(bar.get_global_rect())
		elif control.has_method("crisp_rects"):
			for rect: Variant in control.call("crisp_rects"):
				into.append(rect as Rect2)
	for child: Node in node.get_children():
		_walk(child, into)


## Whether this control has anything on it worth stepping over. An empty label
## is a rectangle of nothing, and holding it open is a rectangle of the picture
## that quietly does not match the rest.
func _says_something(control: Control) -> bool:
	var said: Variant = control.get("text")
	if said != null and not String(said).is_empty():
		return true
	# A `SpinBox` keeps its string on the `LineEdit` inside it, and a
	# `RichTextLabel` has both `text` and marked-up content.
	var rich := control as RichTextLabel
	if rich != null:
		return not rich.get_parsed_text().is_empty()
	return control is SpinBox


## Puts back any override a build that muted left behind.
##
## **Nothing mutes any more**, so on a running game this walks an empty list. It
## survives because a save and a settings file outlive a build: a player who had
## the old filter on has controls carrying a transparent `font_color` override,
## and the code that knew how to undo that is the only thing that can.
func _release() -> void:
	for row: Dictionary in _muted:
		var who: Variant = row["control"]
		if who == null or not is_instance_valid(who):
			continue
		var control: Control = who as Control
		if control == null:
			continue
		for name_of: Variant in COLOURS:
			var key := StringName(String(name_of))
			var had: Variant = (row["had"] as Dictionary).get(String(name_of))
			if had == null:
				control.remove_theme_color_override(key)
			else:
				control.add_theme_color_override(key, had as Color)
	_muted.clear()


func _exit_tree() -> void:
	_release()
	_clear_masks()
