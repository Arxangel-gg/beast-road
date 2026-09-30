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
var world_roots: Array[Node] = []:
	set(value):
		world_roots = value
		_stale = true

## Roots whose text the interface's grid steps over, and only while that grid is
## on.
var ui_roots: Array[Node] = []:
	set(value):
		ui_roots = value
		_stale = true

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
## **The controls that can carry type, kept rather than found every frame**
## (2026-09-30). The walk descended every node under every root on every
## frame, and the world's roots are the battlefield, the town and the beast -
## thousands of bodies, plants, torches and shots for the handful of strings
## among them. Measured at Act X it was most of the three and a half
## milliseconds the pixel filter cost. The roots are walked once when they are
## handed over; after that a Control joining the tree under one of them is
## added the moment it arrives and one leaving is dropped, so the list is
## always the walk's answer. Every frame only the watched controls are read -
## whether shown, what they say, where they are - so the mask is as exact as
## it was. Keyed by instance id to [control, kind, over the interface]: kind 0
## a string it draws, 1 a tab strip, 2 a control naming its own rectangles.
var _watched: Dictionary = {}
var _stale: bool = true


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
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)


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


func _on_node_added(node: Node) -> void:
	var control := node as Control
	if control == null or _stale:
		return
	for root: Variant in world_roots:
		if is_instance_valid(root) and ((root as Node) == node or (root as Node).is_ancestor_of(node)):
			_watch(control, false)
			return
	for root: Variant in ui_roots:
		if is_instance_valid(root) and ((root as Node) == node or (root as Node).is_ancestor_of(node)):
			_watch(control, true)
			return


func _on_node_removed(node: Node) -> void:
	if node is Control:
		_watched.erase(node.get_instance_id())


func _watch(control: Control, ui: bool) -> void:
	if control == self:
		return
	var kind: int = -1
	if DRAWN.has(control.get_class()):
		kind = 0
	elif control is TabContainer:
		kind = 1
	elif control.has_method("crisp_rects"):
		kind = 2
	if kind >= 0:
		_watched[control.get_instance_id()] = [control, kind, ui]


## Every control under a root that can carry type, shown or not - whether it
## is shown is asked when it is read, every frame, so a panel opening needs
## no walk.
func _collect(from: Variant, ui: bool) -> void:
	if from == null or not is_instance_valid(from):
		return
	var node: Node = from as Node
	if node == null or node == self:
		return
	var control: Control = node as Control
	if control != null:
		_watch(control, ui)
	for child: Node in node.get_children():
		_collect(child, ui)


## One watched control's rectangles, if it is shown and says something: the
## same three cases the walk read, asked of one control rather than a tree.
##
## **Type a script painted itself** names its own rectangles (`crisp_rects`):
## `BarName` writes HP, MP and SP with `draw_string`, so its class is `Control`
## and no class list could see it - the grid ran over those captions until it
## said where they were. **A TabContainer's tabs** are drawn by an internal
## `TabBar` that is not in `get_children()`, and the bar's own rect is held
## rather than the container's, which is as big as the page under it.
func _read(entry: Array, into: Array[Rect2]) -> void:
	var held: Variant = entry[0]
	if not is_instance_valid(held):
		return
	var control: Control = held as Control
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree():
		return
	match int(entry[1]):
		0:
			if _says_something(control):
				into.append(control.get_global_rect())
		1:
			var bar: TabBar = (control as TabContainer).get_tab_bar()
			if bar != null and is_instance_valid(bar) and bar.is_visible_in_tree():
				into.append(bar.get_global_rect())
		2:
			for rect: Variant in control.call("crisp_rects"):
				into.append(rect as Rect2)


## Walks the roots and records where every piece of type is standing.
func _gather() -> void:
	_rects.clear()
	_ui_rects.clear()
	if _stale:
		_stale = false
		_watched.clear()
		# `Variant` loop variables, because a typed one casts on assignment - so
		# a root freed while this was watching it would throw here, before
		# `_collect` could guard it. Same reason the release takes one.
		for root: Variant in world_roots:
			_collect(root, false)
		for root: Variant in ui_roots:
			_collect(root, true)
	for entry: Variant in _watched.values():
		if not bool((entry as Array)[2]):
			_read(entry as Array, _rects)
	_ui_rects.append_array(_rects)
	if _ui:
		for entry: Variant in _watched.values():
			if bool((entry as Array)[2]):
				_read(entry as Array, _ui_rects)

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
