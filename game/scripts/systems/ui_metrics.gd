class_name UiMetrics
extends RefCounted

## The interface's spacing numbers, in the one place both halves can reach.
##
## These are used by two things that cannot see each other:
##
## * `tools/theme_builder.gd`, which bakes them into `ui_theme.tres`. It runs
##   under `run_tool.gd`, which replaces the main loop — so **no autoload
##   exists** and it cannot read `Balance`.
## * `scenes/ui/hud.gd`, which lines runtime-positioned children up with the
##   padding the theme already applies. It ships, and `export_presets.cfg`
##   excludes `tools/*` — so it cannot read `ThemeBuilder`.
##
## That second one is not hypothetical. The HUD held
## `const BUILD_ROW_PRICE_INSET := float(ThemeBuilder.PAD_BUTTON_X)` for exactly
## one release. In the editor it was fine. In an exported build `ThemeBuilder` is
## not in the .pck, so `hud.gd` failed to *parse* — which meant no HUD at all and
## no tower slot ever wired to a click handler. Every headless gate passed,
## because every headless gate runs from source.
##
## So: anything both the theme and the running game need to agree about lives
## here, in `scripts/`, which ships.

# --- Padding -----------------------------------------------------------------
#
# One set of numbers for the whole interface rather than a judgement call at each
# call site. Every frame in the art has a decorative border with bolts in the
# corners, and content has to clear the bolts, not the straight run of frame
# between them — so these are measured against the deepest intrusion.
#
# Symmetric on both axes. Asymmetric padding is invisible until you notice it,
# and then it is the only thing you can see.

## Buttons. 34 clears the corner bolt on `ui_button`; 14 centres a 17px line in a
## 42px row instead of leaving it sitting low in its box.
const PAD_BUTTON_X: int = 34
const PAD_BUTTON_Y: int = 14

## The ornate panel frame is the deepest in the set — its corner pieces reach
## about 40px in, so less than this puts a heading on the ironwork.
const PAD_PANEL_X: int = 38
const PAD_PANEL_Y: int = 32

## The spell slot's own frame, as a fraction of the drawn size.
##
## `ui_slot.png` is a riveted border around a dark interior, and its border is
## about 23% of the width. Content was being placed 13px from the edge of a
## 118px slot - well inside the ironwork - so icons and names sat on the frame
## rather than in it.
##
## A fraction rather than pixels because the slot is drawn stretched: a fixed
## inset would be right at one size and wrong at every other.
const SLOT_INSET_X: float = 0.23
const SLOT_INSET_Y: float = 0.20

## The plain dark frame is a thin border and needs far less.
const PAD_DARK_X: int = 20
const PAD_DARK_Y: int = 16

# --- Touch layout ------------------------------------------------------------

## Per-control mobile metrics.
##
## Scaling the CanvasLayer only makes the interface blurrier and clips the outer
## controls. A phone needs taller hit rectangles, more breathing room and more
## legible type while retaining the horizontal measurements that make the HUD
## fit. These helpers therefore touch the actual controls and can restore their
## desktop values when the touch override changes at runtime.
const TOUCH_STATE: StringName = &"beast_road_touch_metrics"

## Set on a control that has already been given its touch size by whoever built
## it, so this pass leaves its dimensions alone.
##
## **Without it, such a control is sized for a thumb twice.** The rule here is
## `minimum.y * UI_TOUCH_SCALE`, which is right for a control authored at desktop
## size and wrong for one that already asked for 120 - it becomes 240. The scope
## rail did: six buttons that should occupy 768px of column took 1480 and ran off
## the bottom of a phone, and the ability slots came out twice as tall as they
## were drawn for, eating the view they sit in front of.
##
## Fonts and padding are still grown. It is only the size that is already right.
const SELF_SIZED: StringName = &"beast_road_self_sized"

## Optional per-control target for dense, owner-sized sheets. Layout checks read
## the same value, so a deliberately compact row cannot quietly regress below
## the size its owner designed for.
const TOUCH_TARGET_HEIGHT: StringName = &"beast_road_touch_target_height"


## Gives every long surface the same visible, draggable and focusable route.
##
## Wheel scrolling remains native. The exposed bar covers mouse users without a
## wheel; focus-follow and a focusable Range cover keyboard/controller; and the
## ScrollContainer's drag path covers touch. Keeping this here prevents the
## co-op screen, settings and the in-run build sheet from drifting apart again.
static func prepare_scroll(scroll: ScrollContainer, touch_layout: bool = false) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.scroll_deadzone = Balance.UI_SCROLL_DRAG_DEADZONE
	scroll.focus_mode = Control.FOCUS_ALL
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar == null:
		return
	bar.custom_minimum_size.x = Balance.UI_TOUCH_SCROLLBAR_WIDTH \
		if touch_layout else Balance.UI_SCROLLBAR_WIDTH
	bar.step = Balance.UI_SCROLL_STEP
	bar.focus_mode = Control.FOCUS_ALL
	bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	bar.tooltip_text = "Drag to scroll · Arrow keys and Page Up/Down also work"


static func apply_touch_tree(root: Node, enabled: bool) -> void:
	if root is Control:
		_apply_touch_control(root as Control, enabled)
	for child: Node in root.get_children():
		apply_touch_tree(child, enabled)


static func _apply_touch_control(control: Control, enabled: bool) -> void:
	if enabled:
		if control.has_meta(TOUCH_STATE):
			return
		var state: Dictionary = {
			"minimum": control.custom_minimum_size,
			"font_override": control.has_theme_font_size_override("font_size"),
			"font_size": control.get_theme_font_size("font_size"),
			"separation_override": control.has_theme_constant_override("separation"),
			"separation": control.get_theme_constant("separation"),
		}
		control.set_meta(TOUCH_STATE, state)

		var minimum: Vector2 = control.custom_minimum_size
		if control.has_meta(SELF_SIZED):
			# Sized by its owner for exactly this case. Grow the type, not the box.
			if control is BaseButton or control is LineEdit:
				_grow_font(control, true)
			elif control is Label or control is RichTextLabel:
				_grow_font(control)
			return
		if control is BaseButton or control is LineEdit:
			minimum.y = maxf(minimum.y * Balance.UI_TOUCH_SCALE,
				Balance.UI_TOUCH_MIN_TARGET_HEIGHT)
			if minimum.x > 0.0:
				minimum.x = maxf(minimum.x, Balance.UI_TOUCH_MIN_TARGET_WIDTH)
			_grow_font(control, true)
		elif control is Slider:
			minimum.y = maxf(minimum.y, Balance.UI_TOUCH_MIN_TARGET_HEIGHT * 0.72)
		elif control is PanelContainer:
			# A panel with an authored floor keeps that intent, with enough extra
			# room for the larger children and frame padding. Content-sized panels
			# grow naturally from those children and need no arbitrary floor.
			if minimum.x > 0.0:
				minimum.x *= Balance.UI_TOUCH_PANEL_SCALE
			if minimum.y > 0.0:
				minimum.y *= Balance.UI_TOUCH_PANEL_SCALE
		elif control is Label or control is RichTextLabel:
			_grow_font(control)
		control.custom_minimum_size = minimum

		if control is Container:
			var separation: int = control.get_theme_constant("separation")
			if separation > 0:
				control.add_theme_constant_override("separation",
					maxi(separation + 2,
						int(round(float(separation) * Balance.UI_TOUCH_GAP_SCALE))))
		return

	if not control.has_meta(TOUCH_STATE):
		return
	var state: Dictionary = control.get_meta(TOUCH_STATE) as Dictionary
	control.custom_minimum_size = state.get("minimum", Vector2.ZERO) as Vector2
	if bool(state.get("font_override", false)):
		control.add_theme_font_size_override("font_size", int(state.get("font_size", 16)))
	else:
		control.remove_theme_font_size_override("font_size")
	if bool(state.get("separation_override", false)):
		control.add_theme_constant_override("separation", int(state.get("separation", 0)))
	else:
		control.remove_theme_constant_override("separation")
	control.remove_meta(TOUCH_STATE)


static func _grow_font(control: Control, enforce_button_floor: bool = false) -> void:
	var current: int = control.get_theme_font_size("font_size")
	if current <= 0:
		return
	var floor_size: int = Balance.UI_TOUCH_MIN_FONT_SIZE if enforce_button_floor else 0
	control.add_theme_font_size_override("font_size",
		maxi(floor_size,
			maxi(current + 1, int(round(float(current) * Balance.UI_TOUCH_FONT_SCALE)))))


# --- Floating panels ---------------------------------------------------------
#
# Four separate reports - a pause menu sitting low and off the bottom, a
# building sheet running off the right edge, a Close button that could not be
# pressed, a leaderboard whose only way out was above the top of the screen -
# were one mistake made four times: a panel authored as a fixed rectangle at
# 1920x1080 and then drawn on a phone, where `ScreenFit` hands the layout a
# canvas around 1680x775.
#
# Two things went wrong every time, and both are fixed here rather than in each
# screen. A `Control` whose content needs more room than its offsets describe
# **grows from its top-left**, because `grow_horizontal`/`grow_vertical` default
# to `GROW_DIRECTION_END` and only `set_anchors_preset` sets them otherwise -
# which a `.tscn` storing bare anchor values never does. And nothing clamped the
# result to the screen, so the overflow simply left.

## Docks a panel against one side of the screen, bounded by it.
##
## The panel is given a real rect rather than a minimum: its height is the
## screen less two margins, its width a share of the screen within bounds. That
## makes the panel's size an input to its children instead of an output of them,
## which is the whole reason the building sheet could run off the edge.
##
## `right` docks it against the trailing edge; the default is the left, which is
## where the building sheets now live (owner decision, 2026-09-01) so they no
## longer sit under the combat rail on the right of the screen.
static func dock_panel(panel: Control, right: bool = false) -> void:
	if panel.get_viewport() == null:
		return
	var screen: Vector2 = panel.get_viewport_rect().size
	if screen.x <= 1.0 or screen.y <= 1.0:
		return
	var margin: float = Balance.UI_PANEL_MARGIN
	var width: float = clampf(screen.x * Balance.UI_SIDE_PANEL_SHARE,
		minf(Balance.UI_SIDE_PANEL_MIN_WIDTH, screen.x - margin * 2.0),
		Balance.UI_SIDE_PANEL_MAX_WIDTH)
	var height: float = maxf(screen.y - margin * 2.0, 120.0)
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_END
	panel.offset_left = screen.x - width - margin if right else margin
	panel.offset_top = margin
	panel.offset_right = panel.offset_left + width
	panel.offset_bottom = margin + height
	# Belt and braces: a child that still insists on more room is cut off at the
	# panel's edge rather than being allowed to drag the panel past the screen.
	panel.clip_contents = true


## Centres a panel on the screen and keeps it there whatever its content asks
## for. `PRESET_CENTER` alone does not: it sets the anchors and leaves the grow
## directions pointing down and right, so a panel that outgrows its authored
## offsets slides off the bottom-right corner - which is exactly what the pause
## menu did once a third button joined it.
static func centre_panel(panel: Control) -> void:
	if panel.get_viewport() == null:
		return
	var screen: Vector2 = panel.get_viewport_rect().size
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	if screen.x <= 1.0 or screen.y <= 1.0:
		return
	# A ceiling, not a size. The panel still shrinks to its content; it simply
	# may not grow past the screen it is drawn on.
	panel.size = panel.size.min(Vector2(
		screen.x * Balance.UI_CENTRE_PANEL_WIDTH_SHARE - Balance.UI_PANEL_MARGIN,
		screen.y * Balance.UI_CENTRE_PANEL_HEIGHT_SHARE - Balance.UI_PANEL_MARGIN))


## The tallest a scrolling region may be inside a centred panel, given whatever
## else that panel has to show. Screens used to hardcode this - the leaderboard
## asked for 520 - and a fixed number is right at one screen height and wrong at
## every other.
## The room a scroll may take, with everything *else* in its column measured
## rather than guessed.
##
## `scroll_room` takes the reservation as a number, and a number written down
## once drifts the moment the panel gains a row. The stash's was 300, chosen
## when its filter row was one row of three buttons; it became a 3x3 grid plus
## two sweep buttons on 2026-09-01 and the reservation was not revisited - so the
## column grew past the screen, and because a `CenterContainer` overflows equally
## in both directions the Close button went off the bottom edge. On a phone that
## is a screen with no way out of it.
##
## Measuring cannot drift. Add a row and the scroll gives up exactly that row.
static func scroll_room_measured(scroll: Control, column: Control,
		extra: float = 0.0) -> float:
	var reserved: float = extra
	var separation: float = 0.0
	if column is BoxContainer:
		separation = float(column.get_theme_constant("separation"))
	var counted: int = 0
	for child: Node in column.get_children():
		var control := child as Control
		if control == null or control == scroll or not control.visible:
			continue
		reserved += control.get_combined_minimum_size().y
		counted += 1
	reserved += separation * float(maxi(counted, 1))
	return scroll_room(scroll, reserved)


static func scroll_room(node: Control, reserved: float) -> float:
	if node.get_viewport() == null:
		return 260.0
	var screen: Vector2 = node.get_viewport_rect().size
	if screen.y <= 1.0:
		return 260.0
	return maxf(160.0, screen.y * Balance.UI_CENTRE_PANEL_HEIGHT_SHARE
		- Balance.UI_PANEL_MARGIN * 2.0 - reserved)


## A row inside a side sheet: wraps rather than widens.
##
## This is the other half of `dock_panel`. Bounding the panel achieves nothing
## while a single button inside it reports a 412-unit minimum width for its cost
## line, because a `ScrollContainer` with horizontal scrolling disabled passes
## its child's minimum width straight through. Wrapping turns that 412 into the
## floor below, and the sheet keeps the width the screen gave it.
static func wrap_row(control: Control) -> void:
	control.custom_minimum_size.x = Balance.UI_PANEL_ROW_MIN_WIDTH
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if control is Button:
		(control as Button).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		(control as Button).clip_text = true
	elif control is Label:
		(control as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## Puts an icon on a button at a size that is actually applied.
##
## `icon_max_width` is a **theme constant on Button, not a property**, so every
## `button.icon_max_width = 38` in this codebase raised
## "Invalid assignment of property or key 'icon_max_width'" at runtime, aborted
## the function that set it, and drew the icon at its natural 128px - which on a
## 44px row means the icon is the row. `IconKit` had already written the reason
## down; the assignments were made anyway. This is the one call site now.
static func row_icon(button: Button, texture: Texture2D, pixels: int) -> void:
	if texture == null:
		return
	button.icon = texture
	button.expand_icon = false
	button.add_theme_constant_override("icon_max_width", pixels)
