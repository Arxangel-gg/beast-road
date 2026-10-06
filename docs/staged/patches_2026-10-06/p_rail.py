import sys; sys.path.insert(0, r"C:\Users\Hamed\AppData\Local\Temp\claude\E--Arxangel-GameDev-BeastRoad\19c67aba-492a-46b1-b9b8-c51fb20d916f\scratchpad")
from patchlib import patch

patch("scenes/ui/hud.gd", [(
r'''const ELEMENT_RAIL_WIDTH: float = 150.0
''',
r'''const ELEMENT_RAIL_WIDTH: float = 150.0
## **The tabs are the element's mark on a thumb** (owner, 2026-10-06: "Build-
## tower menu tabs as element icons (mobile, maybe all)"). The rail spent 150
## of the sheet's width on four names a glyph already says, and the touch pass
## then inflated each to a thumb's full height; the tab is a square of the
## mark now, the count rides under it, and the name is the tooltip.
const ELEMENT_TAB_TOUCH_SIZE: float = 76.0
const ELEMENT_TAB_ICON_TOUCH: int = 36
'''), (
r'''		var towers: Array = by_element.get(element, [])
		var pick := Button.new()
		pick.custom_minimum_size = Vector2(ELEMENT_RAIL_WIDTH, BUILD_ROW_HEIGHT)
		var total: int = towers.size() + (locked.get(element, []) as Array).size()
		pick.text = "%s  %d/%d" % [TowerData.element_name(element), towers.size(), total]
		pick.icon = IconKit.element_sized(element, 26)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.focus_mode = Control.FOCUS_NONE
		pick.toggle_mode = true
		pick.button_pressed = element == _build_element
		pick.disabled = towers.is_empty()
		pick.add_theme_color_override("font_color", TowerData.element_colour(element))
		pick.tooltip_text = "%s  -  %d of %d unlocked" % [
			TowerData.element_name(element), towers.size(), total]
''',
r'''		var towers: Array = by_element.get(element, [])
		var pick := Button.new()
		pick.custom_minimum_size = Vector2(ELEMENT_RAIL_WIDTH, BUILD_ROW_HEIGHT)
		var total: int = towers.size() + (locked.get(element, []) as Array).size()
		# What the tab stands for, readable whatever it draws: the gate picks
		# the fullest element off these rather than off the words.
		pick.set_meta(&"element", element)
		pick.set_meta(&"unlocked", towers.size())
		pick.set_meta(&"total", total)
		pick.text = "%s  %d/%d" % [TowerData.element_name(element), towers.size(), total]
		pick.icon = IconKit.element_sized(element, 26)
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.focus_mode = Control.FOCUS_NONE
		pick.toggle_mode = true
		pick.button_pressed = element == _build_element
		pick.disabled = towers.is_empty()
		pick.add_theme_color_override("font_color", TowerData.element_colour(element))
		pick.tooltip_text = "%s  -  %d of %d unlocked" % [
			TowerData.element_name(element), towers.size(), total]
		if touch_ui():
			# **The mark is the tab** (2026-10-06). Sized here and kept from the
			# touch pass; the count sits in the tab's foot in the element's own
			# colour, and the name stays in the tooltip.
			pick.text = ""
			pick.set_meta(IconKit.ICON_ON_TOP, true)
			pick.set_meta(UiMetrics.SELF_SIZED, true)
			pick.custom_minimum_size = Vector2(ELEMENT_TAB_TOUCH_SIZE, ELEMENT_TAB_TOUCH_SIZE)
			pick.alignment = HORIZONTAL_ALIGNMENT_CENTER
			pick.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			pick.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
			pick.expand_icon = false
			pick.icon = IconKit.element_sized(element, ELEMENT_TAB_ICON_TOUCH)
			var count := Label.new()
			count.name = "Count"
			count.text = "%d/%d" % [towers.size(), total]
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			# Nine, because the touch pass that follows grows every label.
			count.add_theme_font_size_override("font_size", 9)
			count.add_theme_color_override("font_color", TowerData.element_colour(element))
			pick.add_child(count)
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			count.offset_top = -16.0
			count.offset_bottom = -3.0
''')])

patch("tools/road_sheet_check.gd", [(
r'''	for row: Button in _rows_of(_hud.get("_build_list") as Control):
		if not row.toggle_mode:
			continue
		# The rail writes the element's name and its count into the button.
		var count: int = row.text.split(" ")[-1].to_int()
		if count > most:
			most = count
			fullest = row
''',
r'''	for row: Button in _rows_of(_hud.get("_build_list") as Control):
		if not row.toggle_mode:
			continue
		# The rail writes what each tab stands for on the button (2026-10-06);
		# on a thumb the words are gone and the mark is the tab, so the count
		# is read off the button and not off its text.
		var count: int = int(row.get_meta(&"unlocked", row.text.split(" ")[-1].to_int()))
		if _touch:
			_check(row.text.is_empty() and row.icon != null
					and row.size.x <= HUD.ELEMENT_TAB_TOUCH_SIZE + 1.0,
				"on a thumb the element tab for %s is %.0f wide and says '%s' - the mark is the tab"
					% [str(row.get_meta(&"element", -1)), row.size.x, row.text])
			var foot: Label = row.get_node_or_null("Count") as Label
			_check(foot != null and foot.text == "%d/%d" % [count, int(row.get_meta(&"total", -1))],
				"the tab's foot does not say its count")
		else:
			_check(not row.text.is_empty(), "on a desktop an element tab lost its name")
		if count > most:
			most = count
			fullest = row
''')])
