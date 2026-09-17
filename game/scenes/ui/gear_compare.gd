class_name GearCompare
extends PanelContainer

## Two pieces of gear side by side, and what swapping one for the other costs.
##
## Owner, 2026-09-17: *"Items hovered on at the Market should compare the gear
## slot with what the player currently has equipped, pulling up two side-by-side
## cards of pokemon-esque aesthetic and polished to max perfection showing the
## details and info of both cards, along with stat comparisons between the one
## hovered and the gear equipped by the player for easy comparison viewing."*
##
## **The question a shop has to answer is "is this better than what I am
## wearing", and every screen in this game made the player answer it from
## memory.** The Market lists what is on the shelf; the stash lists what is
## owned; nothing put the two together. So the comparison is the feature and the
## cards are how it is read.
##
## **It reads; it never decides.** Nothing here buys, equips, or changes a
## number - it asks `Stash` the same questions the road asks and lays the answers
## out. So it cannot disagree with the piece it is describing, which is the
## failure a second copy of the affix arithmetic would eventually be.
##
## **It never takes the pointer.** The whole card is `MOUSE_FILTER_IGNORE`,
## because it is opened *by* a hover: a panel that ate the pointer would close
## itself the instant it appeared, flicker, and reopen - the loop that makes
## tooltips feel broken.
##
## **And the pad opens it too.** A hover wired only to the mouse is a feature for
## one of the three ways this game is played, which is `UiJuice`'s standing rule
## and the one that always gets forgotten.

## Which way the difference reads. Green is not "bigger", it is "better for
## you" - and for a price, better is *lower*.
const BETTER: Color = Color(0.58, 0.84, 0.54)
const WORSE: Color = Color(0.88, 0.45, 0.40)
const SAME: Color = Color(0.62, 0.60, 0.56)

## The portrait at the top of a card. Large on purpose: the icon is the thing a
## player recognises a piece by, and at list size it is a bullet point.
const PORTRAIT: float = 96.0
const CARD_WIDTH: float = 250.0

var _held_card: VBoxContainer = null
var _offered_card: VBoxContainer = null
var _verdict: Label = null


func _ready() -> void:
	name = "GearCompare"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


func _build() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 10)
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(pair)

	# **Worn on the left, offered on the right**, which is the order the question
	# is asked in: what I have, then what this would be instead.
	_held_card = _card()
	pair.add_child(_held_card)
	_offered_card = _card()
	pair.add_child(_offered_card)

	_verdict = Label.new()
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.add_theme_font_size_override("font_size", 14)
	_verdict.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_verdict)


func _card() -> VBoxContainer:
	var card := VBoxContainer.new()
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	card.add_theme_constant_override("separation", 3)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


## Shows the offered piece beside whatever is worn in its slot.
##
## `piece` is a stash entry - `{kind, rarity, level, uid}` - which is the same
## shape the shelf, the stash and a drop all use, so this works for any of them.
func show_pair(piece: Dictionary) -> void:
	var kinds: Dictionary = ContentDB.gear_kinds
	var offered: GearData = kinds.get(String(piece.get("kind", "")), null) as GearData
	if offered == null:
		visible = false
		return
	var held: Dictionary = MetaState.equipped_piece(int(offered.slot))
	var held_kind: GearData = kinds.get(String(held.get("kind", "")), null) as GearData

	_fill(_held_card, held, held_kind, "WORN")
	_fill(_offered_card, piece, offered, "OFFERED")
	_say_the_difference(piece, offered, held, held_kind)
	visible = true


func hide_pair() -> void:
	visible = false


## One card: the portrait, the name, what it is, and what it grants.
func _fill(card: VBoxContainer, piece: Dictionary, kind: GearData,
		banner: String) -> void:
	for child: Node in card.get_children():
		child.queue_free()

	var head := Label.new()
	head.text = banner
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_font_size_override("font_size", 11)
	head.add_theme_color_override("font_color", Color("7d8479"))
	card.add_child(head)

	# **An empty slot is drawn as an empty slot, not left blank.** "You are
	# wearing nothing here" is the single most useful thing this card can say,
	# and a card that simply disappears says it by omission.
	if kind == null or piece.is_empty():
		var bare := Label.new()
		bare.text = "nothing worn"
		bare.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bare.add_theme_font_size_override("font_size", 15)
		bare.add_theme_color_override("font_color", Color("6d7469"))
		bare.custom_minimum_size = Vector2(0.0, PORTRAIT)
		card.add_child(bare)
		return

	var tint: Color = Stash.rarity_colour(piece)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var art: String = kind.get_sprite_path()
	if ResourceLoader.exists(art):
		portrait.texture = load(art) as Texture2D
	portrait.modulate = tint.lerp(Color.WHITE, 0.5)
	card.add_child(portrait)

	var name_line := Label.new()
	name_line.text = "%s %s" % [Stash.rarity_name(piece), kind.display_name]
	name_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_line.add_theme_font_size_override("font_size", 15)
	name_line.add_theme_color_override("font_color", tint.lerp(Color("efe9dc"), 0.2))
	card.add_child(name_line)

	var what := Label.new()
	what.text = "%s  ·  Level %d" % [kind.slot_name(), int(piece.get("level", 1))]
	what.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	what.add_theme_font_size_override("font_size", 12)
	what.add_theme_color_override("font_color", Color("8d968f"))
	card.add_child(what)

	for affix: Dictionary in Stash.affixes(piece, kind):
		var which: int = clampi(int(affix["attribute"]), 0,
			RunState.ATTRIBUTE_NAMES.size() - 1)
		card.add_child(_stat_line("+%d %s" % [int(affix["points"]),
			RunState.ATTRIBUTE_NAMES[which]], Color("c9c2b4")))
	for legend: GearAffixData in Stash.legendary_affixes(piece, kind):
		card.add_child(_stat_line(legend.line(), Color("e8a33d")))


func _stat_line(text: String, ink: Color) -> Label:
	var line := Label.new()
	line.text = text
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", ink)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


## The whole point: what changes, attribute by attribute.
##
## **Measured through `Stash.affixes`, which is what the hero actually reads.**
## A comparison that added up the numbers printed on the cards would agree with
## the cards and could still disagree with the game - and the failure would be a
## shop that promises a Might the Warden never gets.
func _say_the_difference(offered: Dictionary, offered_kind: GearData,
		held: Dictionary, held_kind: GearData) -> void:
	var count: int = RunState.ATTRIBUTE_NAMES.size()
	var change: Array[int] = []
	change.resize(count)
	change.fill(0)

	for affix: Dictionary in Stash.affixes(offered, offered_kind):
		var which: int = clampi(int(affix["attribute"]), 0, count - 1)
		change[which] += int(affix["points"])
	if held_kind != null and not held.is_empty():
		for affix: Dictionary in Stash.affixes(held, held_kind):
			var which: int = clampi(int(affix["attribute"]), 0, count - 1)
			change[which] -= int(affix["points"])

	var said: PackedStringArray = []
	var up: int = 0
	var down: int = 0
	for index: int in count:
		if change[index] == 0:
			continue
		said.append("%+d %s" % [change[index], RunState.ATTRIBUTE_NAMES[index]])
		if change[index] > 0:
			up += change[index]
		else:
			down -= change[index]

	if said.is_empty():
		_verdict.text = "the same, attribute for attribute"
		_verdict.add_theme_color_override("font_color", SAME)
		return
	_verdict.text = "  ·  ".join(said)
	# **Mixed is its own answer.** A piece that trades three Might for four
	# Focus is not "better"; it is a different build, and colouring it green
	# because the total rose would be the card making a decision the player is
	# there to make.
	var ink: Color = SAME
	if up > 0 and down == 0:
		ink = BETTER
	elif down > 0 and up == 0:
		ink = WORSE
	_verdict.add_theme_color_override("font_color", ink)
