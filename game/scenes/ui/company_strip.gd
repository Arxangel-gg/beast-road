class_name CompanyStrip
extends VBoxContainer

## **The company at a glance** (owner, 2026-10-08: "make sure the hired
## mercenaries join players on their runs ... They should be fully
## implemented"). One line for each mercenary of this Warden's on the road: its
## name and order, how hurt it is, and the wounds it has left - so a company
## that walked out is a company the player can see, and one carried off to the
## inn says so where it stood.
##
## **A readout**: it reads the run and the company and changes nothing. Rows are
## made once a mercenary and painted on a clock (`COMPANY_STRIP_HZ`), never
## rebuilt, so a road with three mercenaries costs three labels and a bar each.

## The road this reads the company of.
var field: Battlefield = null
## Set by the HUD while a sheet a thumb is using wants the column.
var stood_down: bool = false
var _rows: Dictionary = {}
var _left: float = 0.0


func _init() -> void:
	name = "CompanyStrip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 2)
	visible = false


func _process(delta: float) -> void:
	_left -= delta
	if _left > 0.0:
		return
	_left = 1.0 / Balance.COMPANY_STRIP_HZ
	refresh()


## This Warden's own company on this road: on a host, everybody it mustered and
## none of a guest's; on a guest, the ones it brought.
static func own_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for row: Dictionary in RunState.company:
		if not bool(row.get("guest", false)):
			out.append(row)
	return out


## Paints every row now. Public so a gate need not wait out the clock.
func refresh() -> void:
	var own: Array[Dictionary] = own_rows()
	visible = not own.is_empty() and not stood_down
	var seen: Dictionary = {}
	for row: Dictionary in own:
		var uid: String = String(row.get("uid", ""))
		seen[uid] = true
		if not _rows.has(uid):
			_rows[uid] = _make_row(uid)
		_paint(_rows[uid] as Dictionary, row)
	for uid: Variant in _rows.keys():
		if seen.has(uid):
			continue
		var gone: Control = (_rows[uid] as Dictionary).get("line", null) as Control
		if gone != null and is_instance_valid(gone):
			gone.queue_free()
		_rows.erase(uid)


## What one row says, for a gate: `{text, wounds, ratio, bar}`.
func row_reading(uid: String) -> Dictionary:
	var row: Dictionary = _rows.get(uid, {}) as Dictionary
	if row.is_empty():
		return {}
	var bar := row["bar"] as ProgressBar
	return {
		"text": (row["name"] as Label).text,
		"wounds": (row["wounds"] as Label).text,
		"ratio": bar.value,
		"bar": bar.visible,
	}


func _make_row(uid: String) -> Dictionary:
	var line := HBoxContainer.new()
	line.name = "Merc_%s" % uid.replace("-", "_")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)
	add_child(line)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Color("e8dcc0"))
	title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	title.add_theme_constant_override("outline_size", 4)
	line.add_child(title)
	var bar := ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(Balance.COMPANY_STRIP_BAR_WIDTH, 6.0)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var trough := StyleBoxFlat.new()
	trough.bg_color = Color(0.05, 0.05, 0.06, 0.75)
	trough.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9ccf7a")
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", trough)
	bar.add_theme_stylebox_override("fill", fill)
	line.add_child(bar)
	var wounds := Label.new()
	wounds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wounds.custom_minimum_size = Vector2(28.0, 0.0)
	wounds.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wounds.add_theme_font_size_override("font_size", 13)
	wounds.add_theme_color_override("font_color", Color("d9a66a"))
	wounds.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	wounds.add_theme_constant_override("outline_size", 4)
	wounds.tooltip_text = "Wounds left before it is carried to the inn"
	line.add_child(wounds)
	return {"line": line, "name": title, "bar": bar, "fill": fill, "wounds": wounds}


func _paint(line: Dictionary, row: Dictionary) -> void:
	var uid: String = String(row.get("uid", ""))
	var title := line["name"] as Label
	var bar := line["bar"] as ProgressBar
	var wounds := line["wounds"] as Label
	var who: String = String(row.get("name", "A Warden"))
	var left: int = int(row.get("wounds", 0))
	wounds.text = "%d/%d" % [left, Balance.MERC_WOUNDS]
	if bool(row.get("out", false)):
		title.text = "%s  ·  at the inn" % who
		title.modulate = Color(1.0, 1.0, 1.0, 0.55)
		bar.visible = false
		return
	title.modulate = Color.WHITE
	var order: String = _order_of(uid)
	title.text = who if order.is_empty() else "%s  ·  %s" % [who, order]
	var ratio: float = field.company.health_ratio(uid) \
		if field != null and is_instance_valid(field) and field.company != null else -1.0
	bar.visible = true
	bar.value = clampf(ratio, 0.0, 1.0) if ratio >= 0.0 else 1.0
	var fill := line["fill"] as StyleBoxFlat
	fill.bg_color = Color("d0563c").lerp(Color("9ccf7a"), clampf(bar.value * 1.4, 0.0, 1.0))


## The order a mercenary is under, in the card's own short word. A guest's
## company thinks on the host, so a guest shows no order.
func _order_of(uid: String) -> String:
	if field == null or not is_instance_valid(field) or field.company == null:
		return ""
	var hands: MercenaryInput = field.company.mind(uid)
	if hands == null:
		return ""
	for entry: Array in MercenaryCard.ORDERS:
		if int(entry[0]) == hands.order:
			return String(entry[3])
	return ""
