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
## An alias so this file reads the one list rather than a copy of it. A
## fifth attribute arriving here and nowhere else drew "+3 " with no name.
const ATTRIBUTE_NAMES: Array[String] = RunState.ATTRIBUTE_NAMES


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
		LegendaryGleam.dress(icon, piece)
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 14)
	# The name wraps too: "Beastcalled Chainbroken Coalpaint Edge" is not short.
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(180.0, 0.0)
	title.text = "%s %s" % [Stash.rarity_name(piece),
		Stash.display_name(piece, kind) if kind != null else "Unknown"]
	title.add_theme_color_override("font_color",
		Stash.rarity_colour(piece).lerp(Color("e8e2d4"), 0.3))
	text.add_child(title)

	var detail := Label.new()
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color("9d9484"))
	# **It wraps, and that is a layout fix in three screens at once.**
	#
	# This line is a long join - slot, level, every bonus the piece carries, its
	# price - and a Beastcalled piece at maximum level wears five bonuses. A
	# `Label` that cannot wrap reports the whole of that as its *minimum* width,
	# so every row using this was about eight hundred pixels wide at its
	# narrowest and the Ledger's panel came out 917 on a 720-wide phone.
	#
	# Found by `exchange_render_check` on its first run; `layout_check` had never
	# opened that screen. The stash and the trade table were carrying the same
	# minimum and getting away with it because their panels are wider.
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(180.0, 0.0)
	if kind == null:
		detail.text = "gear this build does not know"
	else:
		# Marks are on the row because they are the only number in the game that
		# says what a piece is *worth*, and both the trade table and the ledger
		# exist to ask exactly that.
		detail.text = "%s  ·  Lv%d  ·  %s  ·  %d Marks%s%s" % [
			kind.slot_name(), int(piece.get("level", 1)),
			bonus_text(piece, kind),
			Stash.sell_price(piece),
			"  ·  KEPT" if Stash.is_favourite(piece) else "",
			set_text(kind)]
		row.tooltip_text = kind.description
	text.add_child(detail)
	# **Its wear, when it has worn** (2026-10-07), in the colour of its band.
	var wear: String = durability_text(piece, kind)
	if not wear.is_empty():
		var worn := Label.new()
		worn.name = "Durability"
		worn.add_theme_font_size_override("font_size", 12)
		worn.add_theme_color_override("font_color", durability_colour(Stash.durability_band(piece)))
		worn.text = wear
		text.add_child(worn)
	return row


## What a piece grants, as a sentence: "+7 Might, +3 Focus".
##
## One function rather than one per screen, for the reason `GearRow` exists at
## all: a piece has to read identically in the stash, the trade window and the
## Ledger, and three call sites formatting their own is three chances to drift.
## **A piece's wear, as a line** (2026-10-07): what is left, what it holds, and
## what that costs it. Empty for a piece that has never worn or never will.
static func durability_text(piece: Dictionary, kind: GearData) -> String:
	if kind == null or Stash.durability_original(piece, kind) <= 0 or not piece.has("dur"):
		return ""
	var made: int = int(piece.get("dur_orig", Stash.durability_original(piece, kind)))
	var most: int = Stash.durability_max(piece, kind)
	var state: String = ""
	match Stash.durability_band(piece):
		1:
			state = "  ·  worn - half its benefits"
		2:
			state = "  ·  BROKEN - nothing until mended"
	return "Durability %d / %d%s%s" % [Stash.durability(piece, kind), most,
		"  (was %d)" % made if most < made else "", state]


## The colour a band reads in: whole, worn yellow, broken red.
static func durability_colour(band: int) -> Color:
	match band:
		1:
			return Color("e8c25a")
		2:
			return Color("e0584a")
	return Color("9fb39a")


static func bonus_text(piece: Dictionary, kind: GearData) -> String:
	var parts: PackedStringArray = []
	# A shield says what its guard does first: that is what it is for.
	# A unique says its rule first: the rule is why it is worn.
	if kind != null and kind.is_unique():
		parts.append("UNIQUE - " + kind.unique_text)
	if kind != null and kind.is_shield():
		parts.append("Guard %d, takes %d%% of a blow, %d%% of the shove, %d°" % [
			int(round(Stash.guard_capacity(piece, kind))), int(round(kind.guard_share * 100.0)),
			int(round(kind.guard_knockback * 100.0)), int(round(kind.guard_arc))])
	for affix: Dictionary in Stash.affixes(piece, kind):
		var which: int = clampi(int(affix["attribute"]), 0, ATTRIBUTE_NAMES.size() - 1)
		parts.append("+%d %s" % [int(affix["points"]), ATTRIBUTE_NAMES[which]])
	# The legendary affixes after the points, so the line reads "+7 Might, +3
	# Focus, +6% tower damage" and a player learns what the word on the name
	# means by reading it once.
	for legend: GearAffixData in Stash.legendary_affixes(piece, kind):
		parts.append(legend.line() + grant_note(legend))
	# And the set gems, so a gemmed piece on the trade table or the Ledger reads
	# as the piece it is.
	for gem: Dictionary in Stash.gem_affixes(piece):
		var stone: MaterialData = ContentDB.material(String(gem["gem"]))
		parts.append("+%d%% %s (%s)" % [int(round(float(gem["magnitude"]) * 100.0)),
			Modifiers.label(String(gem["key"])),
			stone.display_name if stone != null else String(gem["gem"])])
	return ", ".join(parts)


## **A grant for a skill the Warden does not hold is dormant, and the row says
## so** (R7, §2.5) - as a set piece says "3/5" - rather than reading as a
## number that quietly does nothing. Live for a learned skill and for the form
## in use.
static func grant_note(legend: GearAffixData) -> String:
	if legend == null or not legend.is_grant():
		return ""
	var root: String = DisciplineUpgrades.root_of(ContentDB.discipline_node(legend.branch_id))
	if root.is_empty() or MetaState.owns_discipline(root) or root == MetaState.discipline_form:
		return ""
	var skill: DisciplineNodeData = ContentDB.discipline_node(root)
	return " (dormant: %s not learned)" % (skill.display_name if skill != null else root)


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


## **Which set a piece belongs to, and how much of it is on.**
##
## Sets shipped on 2026-09-15 with `Modifiers.set_pieces_worn` documented as
## being "for the screens and the gate" - and it was called by the gate and by
## nothing else. So the only thing that ever told a player a set existed was the
## ring of motes at their feet once it was already **finished**, and the only way
## to find the fourth Emberwind piece was to have noticed the first three.
##
## That is the argument the discipline synergies were built under, word for word:
## *"a synergy discovered by accident is a coincidence rather than a build."* It
## is truer of a set, because a set asks the player to pass over better gear in
## five slots to get there.
##
## On the row rather than in a panel, because this is the line a player reads
## while deciding what to wear.
static func set_text(kind: GearData) -> String:
	if kind == null:
		return ""
	var set_data: GearSetData = ContentDB.gear_set_of(kind.id)
	if set_data == null or set_data.members.is_empty():
		return ""
	return "  ·  %s %d/%d" % [set_data.display_name,
		Modifiers.set_pieces_worn(set_data.id), set_data.members.size()]
