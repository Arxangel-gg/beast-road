class_name GearRow
extends RefCounted

## One piece of gear, drawn the same way everywhere it appears.
##
## **Three screens now show the same sword, and a player has to recognise it in
## all three.** The stash is where they judge it, the trade window is where they
## weigh it against somebody else's, and the Long Ledger is where they price it -
## and those are the same judgement made from three directions. Drawing it three
## ways would mean learning the layout three times, and drifting apart the first
## time one of them gained a field.
##
## Extracted from `TradeScreen`, which had it first and had it right: art, a
## rarity-coloured name, then the four things a decision actually needs on one
## line - what it competes with, how far it has been taken, what it grants, and
## what it is worth.

const ICON_SIZE: float = 40.0
const ATTRIBUTE_NAMES: Array[String] = ["Might", "Vigour", "Swiftness", "Focus"]


## Works for a partner's gear and for gear nobody owns yet, because everything
## it needs is derivable: kind, rarity and level are on the piece and the rest is
## looked up locally. Nothing about somebody else's sword has to be trusted in
## order to be *described*.
static func build(piece: Dictionary) -> HBoxContainer:
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Centred rather than filled: the row is two lines of text tall and a top
	# aligned icon hangs off the bottom of the shorter ones.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if kind != null:
		var art: String = kind.get_sprite_path()
		if ResourceLoader.exists(art):
			icon.texture = load(art) as Texture2D
		icon.modulate = Stash.rarity_colour(piece).lerp(Color.WHITE, 0.45)
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 14)
	title.text = "%s %s" % [Stash.rarity_name(piece),
		kind.display_name if kind != null else "Unknown"]
	title.add_theme_color_override("font_color",
		Stash.rarity_colour(piece).lerp(Color("e8e2d4"), 0.3))
	text.add_child(title)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color("9d9484"))
	if kind == null:
		detail.text = "gear this build does not know"
	else:
		# Marks are on the row because they are the only number in the game that
		# says what a piece is *worth*, and both the trade table and the ledger
		# exist to ask exactly that.
		detail.text = "%s  ·  Lv%d  ·  %s  ·  %d Marks%s" % [
			kind.slot_name(), int(piece.get("level", 1)),
			bonus_text(piece, kind),
			Stash.sell_price(piece),
			"  ·  KEPT" if Stash.is_favourite(piece) else ""]
		row.tooltip_text = kind.description
	text.add_child(detail)
	return row


## What a piece grants, as a sentence: "+7 Might, +3 Focus".
##
## One function rather than one per screen, for the reason `GearRow` exists at
## all: a piece has to read identically in the stash, the trade window and the
## Ledger, and three call sites formatting their own is three chances to drift.
static func bonus_text(piece: Dictionary, kind: GearData) -> String:
	var parts: PackedStringArray = []
	for affix: Dictionary in Stash.affixes(piece, kind):
		var which: int = clampi(int(affix["attribute"]), 0, ATTRIBUTE_NAMES.size() - 1)
		parts.append("+%d %s" % [int(affix["points"]), ATTRIBUTE_NAMES[which]])
	return ", ".join(parts)


## A band behind a row, edged in the piece's rarity.
##
## **The band is what joins a piece to the button beside it.** These panels are
## wide and the action sits at the right end, so without a background running the
## full width nothing says the two are the same row. The rarity edge is the
## second half: a stash of forty is scanned for what is worth acting on before
## any of the words are read.
static func band(inner: Control, piece: Dictionary, lit: bool) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	var rarity: Color = Stash.rarity_colour(piece)
	style.bg_color = Color(0.13, 0.16, 0.19, 0.9) if lit \
		else Color(0.07, 0.09, 0.11, 0.55)
	style.border_width_left = 4
	style.border_color = rarity.lerp(Color.WHITE, 0.35) if lit else rarity
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	box.add_theme_stylebox_override("panel", style)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(inner)
	return box
