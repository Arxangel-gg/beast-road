class_name UiPanels

## The shape a window keeps, whatever happens to be in it.
##
## Owner, 2026-09-17: *"a number of UI windows that are available in the Hold had
## their close button moved up top or positioned weird when the close buttons
## should be at the bottom of the panels for all of the panels!"*
##
## **The button was never moved.** Every one of these screens already adds Close
## last, into a column, which is the bottom. What moved is the *panel*: it was
## given a width floor and a height floor of zero, so it is exactly as tall as
## its contents - and a vendor with four things on the shelf, a codex filtered to
## one entry or a pen holding two animals collapses into a strip floating in the
## middle of the screen with Close directly under it. A button at the bottom of a
## panel that is barely there reads as a button at the top of the space.
##
## The stash was fixed this way on 2026-09-16 and the note above its own `_refit`
## says so in as many words. This is that fix, taken out of the one screen that
## had it so the other ten can share it rather than each growing their own copy.
##
## **A share of the screen rather than a number**, because these windows are read
## on a phone and on a desktop: a flat 860 is most of a laptop and taller than a
## landscape phone has. And a ceiling on top of the share, because a window that
## grows with a 4K monitor is a window with a hand's width of empty plate in it.

## How much of the screen a window may take, and the most it may ever be.
##
## Not in `Balance`: these are the proportions of a *window*, which is layout
## rather than tuning, and `balance_reach_check` would rightly ask what gameplay
## reads them.
const SCREEN_SHARE: Vector2 = Vector2(0.94, 0.82)
const CEILING: Vector2 = Vector2(980.0, 860.0)


## The name of the spacer, so a second call finds it rather than adding another.
const SPACER: StringName = &"BottomSpacer"


## Pins whatever comes last in a column to the bottom of it.
##
## Owner, 2026-09-17: the Hold's windows *"had their close button moved up top
## or positioned weird when the close buttons should be at the bottom of the
## panels for all of the panels"*.
##
## **Correct by construction rather than by arithmetic.** The button is already
## the last child of its column on every one of these screens - measured, with
## node paths - and it still came out at the top of a window with sixteen
## hundred units of nothing under it. Which container failed to hand its slack
## to which child differs per screen, and reasoning about it one screen at a
## time is how five of them ended up wrong in five different ways.
##
## An expanding spacer immediately above the last row takes *all* the slack,
## whatever produced it. It cannot be defeated by a scroll that did not expand,
## by a minimum that was measured too small, or by a panel that turned out
## taller than its contents - the three separate causes behind the five
## screens. `menu_layout_check` holds the outcome rather than any of the
## causes.
##
## Idempotent: screens rebuild their columns, and a spacer per rebuild would be
## a column of spacers.
static func pin_last_to_bottom(column: Control) -> void:
	if column == null or not is_instance_valid(column):
		return
	var count: int = column.get_child_count()
	if count == 0:
		return
	# **Nothing to do if something already takes the slack**, and doing it anyway
	# is a regression rather than a no-op: two expanding children *share* the
	# spare height, so a spacer beside a list halves the list. The Chronicle's
	# entries then stopped overflowing, which took its scrollbar away and broke
	# three of its own interaction checks - caught by `menu_layout_check` in the
	# run after this was added.
	for index: int in range(count):
		var child: Control = column.get_child(index) as Control
		if child == null or child.name == SPACER:
			continue
		if child.size_flags_vertical & Control.SIZE_EXPAND != 0:
			return
	var existing: Node = column.get_node_or_null(NodePath(String(SPACER)))
	var spacer: Control = existing as Control
	if spacer == null:
		spacer = Control.new()
		spacer.name = SPACER
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(spacer)
	# Second from the end, so the row it is pushing down stays last.
	column.move_child(spacer, maxi(column.get_child_count() - 2, 0))


## Gives a window its floor, and hands the slack to whatever scrolls inside it.
##
## `body` is the part that absorbs the difference - usually the `ScrollContainer`
## holding the list. Without it the column would distribute the new height
## between every child, which stretches the heading and the buttons instead of
## the list and leaves Close floating in a gap of its own.
static func seat(panel: Control, body: Control = null,
		widest: float = CEILING.x) -> void:
	if panel == null or not is_instance_valid(panel) or not panel.is_inside_tree():
		return
	var screen: Vector2 = panel.get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(
		minf(widest, screen.x - Balance.UI_PANEL_MARGIN * 2.0),
		minf(screen.y * SCREEN_SHARE.y, CEILING.y))
	if body != null and is_instance_valid(body):
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL


## The floor on its own, for a screen that sizes its panel in its own way and
## only wants the height.
static func tall_for(panel: Control) -> float:
	if panel == null or not panel.is_inside_tree():
		return 0.0
	var screen: Vector2 = panel.get_viewport().get_visible_rect().size
	return minf(screen.y * SCREEN_SHARE.y, CEILING.y)
