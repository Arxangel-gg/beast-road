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
