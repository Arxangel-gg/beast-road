class_name CrossroadScreen
extends CanvasLayer

## The choice at a segment boundary (GDD §8). Combat is frozen behind this.
##
## Two cards are drawn from five authored road promises. Each also carries an
## independent danger/reward tier, so the player compares both destination and
## commitment rather than choosing among three hardcoded legacy buttons.

## The host's own vote, under an id no transport can produce.
const HOST_VOTER: int = 0

## voter id -> road id, and road id -> the difficulty that came with it.
var _votes: Dictionary = {}
var _vote_difficulty: Dictionary = {}

## Seconds left before the fork settles on the votes it has. Zero when idle.
var _vote_left: float = 0.0

signal road_chosen(option_id: String)
signal relic_chosen(relic_id: String)
## The road home was answered: true to turn for home, false to push on.
signal homecoming_decided(go_home: bool)

## The party turned for home at an ordinary fork rather than at an act's end.
signal extraction_chosen()

## Whether the fork offers the road home at all, and what it pays. Set by the
## run before it opens the screen, because whether a return may be taken is a
## fact about the *run* - the host owns the ending, and a headless gate is never
## held on a question.
var extraction_offered: bool = false
var extraction_marks: int = 0
var _extract_button: Button = null

## The last road-home offer's figures, for a gate to read back.
var last_homecoming: Dictionary = {}

@export var panel: Control

## The option buttons by road id, so a partner's choice can be pointed at.
var _buttons: Dictionary = {}

## The roads currently on the table, as [road id, difficulty id] pairs.
var _offers: Array[PackedStringArray] = []

## The partner's crosshair while the fork is open, and where it last was.
var _pointer: Control = null
var _sent_pointer: Vector2 = Vector2.ZERO
var _pointer_clock: float = 0.0

## True between a click this machine cannot settle and the host's answer.
var _resolving: bool = false
@export var title: Label
@export var options_box: VBoxContainer

## Width of an option card. Wide enough that no description wraps to three lines,
## which is what makes three cards different heights and the column look broken.
## Minimum width of a road card. The cards expand to share the row, so this is
## a floor rather than a size - it stops a single offer collapsing to its text.
const CARD_WIDTH: float = 460.0

## How a fork arrives: each card a beat after the one before it.
##
## A decision that fades up in sequence lands; three cards appearing together is
## a dialog box. Short enough that nobody waiting to press is kept waiting.
const CARD_ENTRANCE_SECONDS: float = 0.22
const CARD_ENTRANCE_STAGGER: float = 0.07

## How wide a portent's icon is drawn on its card. Sized against the three lines
## of text beside it rather than against the source art, which is 128.
const OMEN_ICON: int = 64

## Matches the theme's button text inset, so a description lines up under the
## name it belongs to instead of starting somewhere near it.
const TEXT_INDENT: int = 34

var _rng := RandomNumberGenerator.new()
var _relic_followup_segment: int = -1
var _open_segment: int = 0

## The row the road cards sit in. Rebuilt per crossroad; relic rewards do not use
## it and stay in the column, which is the right shape for a list.
var _road_row: HBoxContainer = null
var _last_scar_button: Button = null


## The partner's cursor, and this player's, while the fork is open.
##
## **This is the one screen where seeing somebody else's hand matters.** Two
## people are deciding one thing together, and without it the only signal either
## gets is the screen closing. With it you can hover over the road you want,
## watch your friend hover over another, and argue about it before anybody
## commits.
##
## Sent as a fraction of the viewport rather than in pixels: the two are not
## necessarily looking at the same size of window, and a pixel position would put
## the pointer somewhere else entirely on a different display.
func _process(delta: float) -> void:
	_tick_vote(delta)
	_tick_holograms(delta)
	if not is_open() or not Coop.partner_present():
		return
	_pointer_clock -= delta
	if _pointer_clock > 0.0:
		return
	_pointer_clock = Balance.COOP_POINTER_INTERVAL
	var view: Vector2 = get_viewport().get_visible_rect().size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	var at: Vector2 = get_viewport().get_mouse_position() / view
	# Only when it has actually moved. A cursor sitting still does not need
	# twenty packets a second saying so.
	if at.distance_to(_sent_pointer) < 0.004:
		return
	_sent_pointer = at
	EventBus.coop_pointer_moved.emit(at)


## Draws the partner's cursor where they say it is.
func _on_partner_pointer(at: Vector2) -> void:
	# The same signal carries this player's own cursor outward. Only the copy that
	# arrived over the wire describes somebody else's hand.
	var relay: CoopRelay = Coop.relay()
	if relay == null or not relay.is_replaying():
		return
	if not is_open():
		return
	if _pointer == null or not is_instance_valid(_pointer):
		_pointer = _build_pointer()
	_pointer.visible = true
	_pointer.position = at * get_viewport().get_visible_rect().size \
			- _pointer.size * 0.5


func _build_pointer() -> Control:
	var mark := Label.new()
	mark.text = "◆"
	mark.add_theme_font_size_override("font_size", 34)
	mark.add_theme_color_override("font_color", Balance.COOP_PARTNER_TINT)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2(34.0, 34.0)
	# On the layer rather than inside the panel, so the position it is given is
	# the screen position the partner reported rather than an offset into a
	# container that is itself laid out differently on the other machine.
	add_child(mark)
	return mark


func _hide_pointer() -> void:
	if _pointer != null and is_instance_valid(_pointer):
		_pointer.visible = false


func _ready() -> void:
	EventBus.coop_road_votes.connect(_on_coop_road_votes)
	_rng = RunState.rng("roads")
	panel.visible = false
	EventBus.coop_pointer_moved.connect(_on_partner_pointer)
	EventBus.coop_relic_chosen.connect(_on_coop_relic_chosen)
	EventBus.coop_omen_chosen.connect(_on_coop_omen_chosen)
	EventBus.coop_road_card_chosen.connect(_on_coop_road_card_chosen)
	EventBus.coop_last_scar_accepted.connect(_on_coop_last_scar_accepted)


func open(segment_index: int) -> void:
	if not RunState.pending_road_relics.is_empty():
		open_relic_reward(segment_index)
		return
	_open_roads(segment_index)


func _open_roads(segment_index: int) -> void:
	_open_segment = segment_index
	_buttons.clear()
	# A fork carries no votes from the last one.
	_votes.clear()
	_vote_difficulty.clear()
	_vote_left = 0.0
	_offers.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	for child: Node in options_box.get_children():
		child.queue_free()

	title.text = "Crossroad  ·  segment %d of %d" % [
		segment_index, int(Balance.JOURNEY_TOTAL_DISTANCE / Balance.SEGMENT_DISTANCE)]

	# Side by side, not stacked. This is a choice between two roads and it reads
	# as one when they are next to each other at the same size; stacked in a
	# narrow column they read as a list, and the screen was a quarter full.
	# The column has to expand before the row inside it can, or the cards sit at
	# their minimum height in the top third and the screen looks half-drawn.
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_row = HBoxContainer.new()
	_road_row.add_theme_constant_override("separation", 26)
	_road_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_box.add_child(_road_row)

	for offer: Dictionary in draw_offers(segment_index):
		_add_option(offer["road"] as RoadData, offer["difficulty"] as RoadDifficultyData)

	_add_last_scar_offer()
	_add_extraction_offer()
	_add_reroll()
	_dress_options()
	panel.visible = true


## **Turn for home, from the fork** (owner, 2026-09-16).
##
## Expedition persistence was recorded as "the road is put down at a crossroad
## and picked up next time", and `Run._open_crossroad` prices momentum as "the
## momentum a player refused to bank" - but the only door to banking was the
## homecoming pass at an act's end. So a player passed fork after fork paying for
## a decision that was never on the table.
##
## The same ending as the pass, read off the same arithmetic, so the fork and the
## act end cannot disagree about what a return is worth. Whether it is offered at
## all is the *run's* call - see `Run.extraction_open` - because the host owns
## the ending and a headless gate must never be held on a question.
func _add_extraction_offer() -> void:
	_extract_button = null
	if not extraction_offered:
		return
	var card := PanelContainer.new()
	card.theme_type_variation = &"InnerPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	_extract_button = Button.new()
	_extract_button.text = "TURN FOR HOME  ·  bank this front and keep %d Marks" % extraction_marks
	# **Weighted like the decision it is.** It ends the run: at the size of a
	# footnote it read as one, under two road cards that each fill a third of
	# the screen.
	_extract_button.custom_minimum_size = Vector2(0.0, 62.0)
	_extract_button.add_theme_font_size_override("font_size", 21)
	_extract_button.add_theme_color_override("font_color", Color("9fd7a8"))
	IconKit.on_button(_extract_button, "marks", 24)
	_extract_button.pressed.connect(_choose_extraction)
	box.add_child(_extract_button)
	var note := Label.new()
	note.text = ("The wall, the towers and their damage are kept where they stand. "
		+ "Come back to this act rather than to the first.")
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color("9a9384"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	options_box.add_child(card)


## Taken once: the run is ending, and a second press while it settles would
## settle it twice. Same guard the road choices use.
func _choose_extraction() -> void:
	if _resolving:
		return
	_resolving = true
	if _extract_button != null:
		_extract_button.disabled = true
	panel.visible = false
	extraction_chosen.emit()


## Sigil rank 2's redraw, offered only while the run still holds a charge.
##
## Below the pair rather than beside it, and worded with the count, because the
## charge is per *run*: a player who cannot see that it is their only one will
## spend it on the first pair they mildly dislike.
func _add_reroll() -> void:
	if RunState.crossroad_rerolls_left <= 0:
		return
	var button := Button.new()
	button.text = "Redraw this pair  ·  %d left this run" % RunState.crossroad_rerolls_left
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(_reroll)
	options_box.add_child(button)


## Optional vow, not a third road. It changes the cost of whichever road the
## party chooses and therefore sits beneath the pair rather than competing with
## either destination.
func _add_last_scar_offer() -> void:
	_last_scar_button = null
	if not RunState.can_offer_last_scar() and not RunState.last_scar_pending:
		return
	var challenge: Resource = ContentDB.run_challenge("last_scar")
	if challenge == null:
		return
	var card := PanelContainer.new()
	card.theme_type_variation = &"InnerPanel"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	_last_scar_button = Button.new()
	_last_scar_button.text = String(challenge.get("button_line"))
	_last_scar_button.custom_minimum_size = Vector2(0.0, 48.0)
	_last_scar_button.add_theme_color_override("font_color", Color("ef8065"))
	IconKit.on_button(_last_scar_button, "last_scar", 24)
	_last_scar_button.pressed.connect(_accept_last_scar)
	box.add_child(_last_scar_button)
	# **What the vow actually asks, in words.** `offer_line` says it plainly -
	# "take no new Wound, keep the Town Hall above 60%, and bring down the
	# marked pursuer" - and was read by nothing, so the only explanation a
	# player ever got was the four-token summary below it, which is a reminder
	# for somebody who already knows rather than an offer to somebody deciding.
	var offer: String = String(challenge.get("offer_line"))
	if not offer.is_empty():
		var says := Label.new()
		says.text = offer
		says.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		says.add_theme_font_size_override("font_size", 15)
		says.add_theme_color_override("font_color", Color("e8d8cf"))
		box.add_child(says)
	var line := Label.new()
	line.text = "%s\n%s" % [String(challenge.get("condition_line")),
		String(challenge.get("reward_line"))]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color("d8b3aa"))
	box.add_child(line)
	options_box.add_child(card)
	if RunState.last_scar_pending:
		_show_last_scar_accepted()


func _accept_last_scar() -> void:
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.ACCEPT_LAST_SCAR)
			if _last_scar_button != null:
				_last_scar_button.disabled = true
				var challenge: Resource = ContentDB.run_challenge("last_scar")
				if challenge != null:
					_last_scar_button.text = String(challenge.get("waiting_line"))
		return
	_accept_last_scar_authoritative()


func accept_last_scar_request() -> void:
	if is_open():
		_accept_last_scar_authoritative()


func _accept_last_scar_authoritative() -> void:
	if not RunState.accept_last_scar():
		return
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_last_scar_accepted.emit()
	_show_last_scar_accepted()


func _on_coop_last_scar_accepted() -> void:
	var relay: CoopRelay = Coop.relay()
	if not Coop.is_guest() or relay == null or not relay.is_replaying():
		return
	RunState.mirror_accept_last_scar()
	if _last_scar_button == null:
		_add_last_scar_offer()
	else:
		_show_last_scar_accepted()


func _show_last_scar_accepted() -> void:
	if _last_scar_button == null:
		return
	var challenge: Resource = ContentDB.run_challenge("last_scar")
	if challenge == null:
		return
	_last_scar_button.disabled = true
	_last_scar_button.text = String(challenge.get("sworn_line"))
	_last_scar_button.add_theme_color_override("font_color", Color("ffb08d"))
	EventBus.preparation_warning.emit(String(challenge.get("accepted_line")))


func _reroll() -> void:
	if RunState.crossroad_rerolls_left <= 0:
		return
	RunState.crossroad_rerolls_left -= 1
	# The reroll count is part of the fork's seed, so spending one redraws the
	# offers deterministically - the same new set on every machine, and the same
	# set again on a seeded replay.
	_open_roads(_open_segment)


## Public test/replay seam: cards and diagnostics use the same authored draw,
## so seed validation never has to reimplement crossroad randomness.
func draw_offers(segment_index: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var pool: Array[RoadData] = ContentDB.roads_sorted()
	# **Seeded per fork, not drawn from a running stream.**
	#
	# This used the run's shared "roads" stream, whose position depends on how
	# many times *this machine* has drawn from it. In co-op that is not the same
	# number on both sides - the host opens a fork the guest is told about, a
	# reroll advances one and not the other - and once the two streams part, every
	# later fork offers different roads to each player.
	#
	# It presented as a fork that would not settle: the guest voted for a road the
	# host's screen did not have, so the vote was dropped and nothing closed. Two
	# real games caught it about one run in three, with the host showing
	# `relic_hunt, long_march` while the guest was looking at `chieftain_trail`.
	#
	# Derived from the run seed, the segment and the rerolls spent, so it is the
	# same on every machine however each one got here, still different at every
	# fork, and still different after a reroll.
	_rng = RandomNumberGenerator.new()
	_rng.seed = hash("roads:%d:%d:%d" % [RunState.run_seed, segment_index,
		RunState.crossroad_rerolls_left])
	_shuffle_roads(pool)
	for i: int in mini(Balance.CROSSROAD_OPTIONS_SHOWN, pool.size()):
		offers.append({
			"road": pool[i],
			"difficulty": _pick_difficulty(segment_index),
		})
	return offers


## Relic Hunt resolves only after its danger has been survived. Present its
## authored regional reward before the next road (or the act boss) can begin.
func open_relic_reward(followup_segment: int = -1) -> void:
	# **A card with nothing on it is a dead end**, and a caller guarding is not
	# the same as the screen being safe - `Run` checks the pool before calling,
	# and the Guide's own shot tool did not, which is how a "RELIC HUNT COMPLETE"
	# with no options underneath it reached the owner. The refusal lives here so
	# there is one of it.
	if RunState.pending_road_relics.is_empty():
		push_warning("crossroad: asked to offer relics with none pending")
		return
	_road_row = null
	_relic_followup_segment = followup_segment
	_buttons.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	for child: Node in options_box.get_children():
		child.queue_free()
	title.text = "RELIC HUNT COMPLETE  ·  choose one Rimebound treasure" \
		if RunState.act == 3 else "RELIC HUNT COMPLETE  ·  choose one regional treasure"
	# **Side by side, as cards** (owner, 2026-09-16: bigger, clearer, easier to
	# press). These were the one bare `Button` on a screen whose other choices
	# have been proper cards since they were written; three of them stacked in a
	# column with a name and a description crammed into one string read as a list
	# of rows rather than as a choice between treasures.
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_row = HBoxContainer.new()
	_road_row.add_theme_constant_override("separation", 22)
	_road_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_box.add_child(_road_row)
	for relic_id: String in RunState.pending_road_relics:
		var relic: RelicData = ContentDB.relic(relic_id)
		if relic == null:
			continue
		# A relic carries no rarity of its own, so every regional treasure is dealt
		# at the same rank - the choice between them is what they *do*, which is
		# the stat row.
		_play_card(relic.id, relic.display_name, 2, relic.get_sprite_path(),
			[[effect_label(relic.effect_id),
				effect_figure(relic.effect_id, relic.effect_magnitude)],
				["Region", "Act %d" % relic.region]],
			relic.description, _choose_relic.bind(relic.id))
	_road_row = null
	_dress_options()
	panel.visible = true


## **One choice, drawn the way this screen draws a choice.**
##
## The same grammar as `_add_option`: a dark plate, a tall button carrying the
## name and the mark at a size a thumb can find, and the description wrapped
## underneath at reading size rather than folded into the button's own label.
## Shared by the relics and the portents because they are the same moment.
## **What a card looks like**, and the one table its colour comes from.
##
## Cool grey to gold: a Common reads as stock, a Rare as something worth the slot
## it takes. The border, the name and the ribbon all read from here, so a card
## cannot say Rare in one place and look Common in another.
const RARITY_TINT: Array[Color] = [
	Color("b8c1bc"), Color("8fd6a4"), Color("8fb6ef"), Color("d8a85f"),
]
const RARITY_WORD: Array[String] = ["COMMON", "UNCOMMON", "RARE", "LEGENDARY"]

## Portrait, and wide enough for two stat rows without wrapping. Three of these
## sit across the panel with room around them.
const PLAY_CARD := Vector2(286.0, 404.0)
const PLAY_CARD_ART: int = 150

## The rarity from which a card wears the travelling sheen. Highest only: a
## hologram on everything is wallpaper.
const HOLO_FROM_RARITY: int = 2

## How bright the sheen is, and how long it takes to cross. Low, because the card
## has to stay readable underneath it - the additive layer is a highlight, not a
## wash.
const HOLO_STRENGTH: float = 0.5
const HOLO_SWEEP_SECONDS: float = 3.4

## Every holographic skin on screen, ticked from `_process`.
var _holo_skins: Array[ColorRect] = []
var _holo_clock: float = 0.0


## **One choice, as a card.**
##
## `stats` is an array of `[label, value]` pairs - what the thing actually does,
## in the numbers it does it by. `flavour` is the line in data that says it in
## words (working rule 9).
func _play_card(id: String, name_line: String, rarity: int, icon_path: String,
		stats: Array, flavour: String, on_press: Callable) -> Button:
	var tint: Color = RARITY_TINT[clampi(rarity, 0, RARITY_TINT.size() - 1)]

	# The whole card is the button: a card you have to find a button inside is a
	# card that is harder to press than the row it replaced.
	var button := Button.new()
	button.custom_minimum_size = PLAY_CARD
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_stylebox_override("normal", _card_face(tint, 0.0))
	button.add_theme_stylebox_override("hover", _card_face(tint, 0.35))
	button.add_theme_stylebox_override("pressed", _card_face(tint, 0.5))
	button.add_theme_stylebox_override("focus", _card_face(tint, 0.35))
	button.tooltip_text = "%s\n%s" % [name_line, flavour]
	button.pressed.connect(on_press)
	_buttons[id] = button

	var face := VBoxContainer.new()
	face.add_theme_constant_override("separation", 6)
	face.set_anchors_preset(Control.PRESET_FULL_RECT)
	face.offset_left = 14.0
	face.offset_right = -14.0
	face.offset_top = 12.0
	face.offset_bottom = -12.0
	# Every part of the face is decoration; the press belongs to the card.
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(face)

	face.add_child(_card_line(name_line.to_upper(), 19, tint,
		HORIZONTAL_ALIGNMENT_CENTER, true))
	face.add_child(_card_line(RARITY_WORD[clampi(rarity, 0, RARITY_WORD.size() - 1)],
		12, tint.darkened(0.15), HORIZONTAL_ALIGNMENT_CENTER))

	# **The art, framed.** A picture floating on the plate reads as an icon that
	# happened to land there; a recess makes it the card's illustration.
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _art_recess(tint))
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(0.0, float(PLAY_CARD_ART))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(icon_path):
		art.texture = load(icon_path) as Texture2D
	frame.add_child(art)
	face.add_child(frame)

	# **What it does, in the numbers it does it by.**
	for pair: Array in stats:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = _card_line(String(pair[0]), 15, Color("9aa39e"),
			HORIZONTAL_ALIGNMENT_LEFT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(_card_line(String(pair[1]), 15, tint.lightened(0.15),
			HORIZONTAL_ALIGNMENT_RIGHT))
		face.add_child(row)

	var rule := ColorRect.new()
	rule.color = Color(tint.r, tint.g, tint.b, 0.28)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(rule)

	var words: Label = _card_line(flavour, 14, Color("a8b0aa"),
		HORIZONTAL_ALIGNMENT_CENTER)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	face.add_child(words)

	if rarity >= HOLO_FROM_RARITY:
		_make_holographic(button, tint)

	if _road_row != null:
		_road_row.add_child(button)
	else:
		options_box.add_child(button)
	return button


## The plate a card is printed on: dark, with its rarity around the edge.
func _card_face(tint: Color, lift: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.055, 0.062, 0.068, 0.96).lerp(
		Color(tint.r, tint.g, tint.b, 0.96), 0.06 + lift * 0.12)
	box.border_color = Color(tint.r, tint.g, tint.b, 0.55 + lift * 0.45)
	box.set_border_width_all(2)
	box.set_corner_radius_all(9)
	box.set_content_margin_all(10.0)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	box.shadow_size = 6
	return box


## The recess the illustration sits in.
func _art_recess(tint: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.03, 0.035, 0.04, 0.92)
	box.border_color = Color(tint.r, tint.g, tint.b, 0.30)
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	box.set_content_margin_all(4.0)
	return box


func _card_line(text: String, size: int, tint: Color, align: int,
		shadowed: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", tint)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if shadowed:
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
		label.add_theme_constant_override("shadow_offset_y", 2)
	return label


## **The sheen the best cards wear.**
##
## `ui_hologram.gdshader` is the interface's own skin - the one `UiJuice` lays
## over a hovered control - rather than `title_hologram`, which paints a
## *texture* from the inside and on a plain rect outputs a solid white card. This
## one declares `blend_add`, and that is a safety rule rather than a look: an
## additive layer can only add light, so no line on the card loses contrast to
## it. `ui_juice_check` reads that blend mode off the shader and refuses
## `blend_mix`. Mouse-transparent, because a decoration must never eat a press.
func _make_holographic(card: Control, tint: Color) -> void:
	var shader: Shader = load("res://scripts/shaders/ui_hologram.gdshader") as Shader
	if shader == null:
		return
	var skin := ColorRect.new()
	skin.name = "Holo"
	skin.set_anchors_preset(Control.PRESET_FULL_RECT)
	skin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skin.color = Color(1, 1, 1, 1)
	var paint := ShaderMaterial.new()
	paint.shader = shader
	paint.set_shader_parameter("strength", HOLO_STRENGTH)
	paint.set_shader_parameter("glow", Color(tint.r, tint.g, tint.b, 1.0))
	skin.material = paint
	card.add_child(skin)
	_holo_skins.append(skin)


## The sheen travels. Driven rather than looped inside the shader so every card
## on screen shares one clock and no two drift apart.
func _tick_holograms(delta: float) -> void:
	if _holo_skins.is_empty():
		return
	_holo_clock += delta
	for index: int in range(_holo_skins.size() - 1, -1, -1):
		var skin: ColorRect = _holo_skins[index]
		if skin == null or not is_instance_valid(skin):
			_holo_skins.remove_at(index)
			continue
		var paint := skin.material as ShaderMaterial
		if paint == null:
			continue
		# The sheen crosses the card and rests, over and over. `sweep` is where
		# the band is, from below the card to past its top; outside 0..1 the
		# shader draws none, which is the rest between passes.
		var cycle: float = fposmod(_holo_clock / HOLO_SWEEP_SECONDS, 1.0)
		paint.set_shader_parameter("sweep", -0.35 + cycle * 1.9)
		paint.set_shader_parameter("strength", HOLO_STRENGTH)


## **"+18%" or "+1 chain target".**
##
## The same rule `GearAffixData.line` follows - `chain_targets` and
## `wave_foresight` are whole counts and everything else is a fraction - because
## two formats for one table of numbers is how a card ends up promising "+0.18
## chain targets".
static func effect_figure(effect_id: String, magnitude: float) -> String:
	if effect_id == "chain_targets" or effect_id == "wave_foresight":
		return "%+d" % int(round(magnitude))
	return "%+d%%" % int(round(magnitude * 100.0))


## "tower_damage" -> "Tower damage". The keys are authored in snake_case and a
## card is read by a person.
static func effect_label(effect_id: String) -> String:
	return effect_id.replace("_", " ").capitalize() if not effect_id.is_empty() else "Effect"


func _add_treasure_card(id: String, name_line: String, body: String,
		icon_path: String, tint: Color, on_press: Callable) -> void:
	var card := PanelContainer.new()
	card.theme_type_variation = &"InnerPanel"
	card.custom_minimum_size = Vector2(CARD_WIDTH * 0.72, 0.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# **Shrink to its content, not to the panel.** Expanding vertically is right
	# for the two road cards, which fill a row between them; a single treasure
	# offered on its own then stretched into a tall empty plate.
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var button := Button.new()
	button.text = name_line.to_upper()
	button.custom_minimum_size = Vector2(0.0, 64.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", tint)
	button.tooltip_text = "%s\n%s" % [name_line, body]
	if ResourceLoader.exists(icon_path):
		UiMetrics.row_icon(button, load(icon_path), 48)
	button.pressed.connect(on_press)
	_buttons[id] = button
	box.add_child(button)

	var text := Label.new()
	text.text = body
	text.add_theme_font_size_override("font_size", 18)
	text.add_theme_constant_override("line_spacing", 6)
	text.add_theme_color_override("font_color", Color("bcc9c4"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", TEXT_INDENT)
	indent.add_theme_constant_override("margin_right", 8)
	indent.add_theme_constant_override("margin_bottom", 4)
	indent.add_child(text)
	box.add_child(indent)

	if _road_row != null:
		_road_row.add_child(card)
	else:
		options_box.add_child(card)


## **Every choice answers being touched, and arrives rather than appears.**
##
## `UiJuice.enrol` is what gives a control its hover, focus and tap hologram. The
## HUD and the main menu both call it and this screen never did - so the one
## screen that is nothing *but* choices was the one whose choices sat inert. The
## cards are rebuilt on every open, so it is enrolled on every open.
##
## And they come in one after another: a fork that fades up in sequence lands as
## a decision, where three cards appearing at once is a dialog box.
func _dress_options() -> void:
	UiJuice.enrol(get_tree(), panel)
	# **The fade only.** The first cut lifted each card and tweened it back, and
	# a container re-sets its children's positions on every layout pass - so the
	# tween and the `HBoxContainer` fought and the three cards came out drawn on
	# top of one another with two of them invisible. A container owns position
	# and size; it does not own `modulate`.
	var step: int = 0
	for card: Node in _entrance_cards():
		var item := card as Control
		if item == null:
			continue
		item.modulate.a = 0.0
		var rise: Tween = create_tween()
		rise.tween_interval(float(step) * CARD_ENTRANCE_STAGGER)
		rise.tween_property(item, "modulate:a", 1.0, CARD_ENTRANCE_SECONDS) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		step += 1


## The cards an entrance should play on: whatever is laid out in the row when
## there is one, and the column's own children when there is not.
func _entrance_cards() -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in options_box.get_children():
		if child is HBoxContainer:
			out.append_array(child.get_children())
		else:
			out.append(child)
	return out


## The portents, at the end of an act. One cost, one reward, kept for the run.
##
## Built on the relic reward rather than beside it, deliberately: this is the
## same moment, the same panel and the same one-choice-for-the-party rule, and a
## second flow would be a second place for the co-op handshake to be subtly
## wrong. The card leads with the **cost**, because the cost is the decision.
func open_omen_choice() -> void:
	# The same refusal, for the same reason. `Run._offer_omens` will not open on
	# fewer than three cards; this is what stops a second caller from doing so.
	if RunState.pending_omens.is_empty():
		push_warning("crossroad: asked to read portents with none pending")
		return
	_road_row = null
	_relic_followup_segment = -1
	_buttons.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	for child: Node in options_box.get_children():
		child.queue_free()
	title.text = "THE ROAD AHEAD  ·  read one portent"
	# The same card grammar the roads and the relics use. The portents were three
	# stacked buttons with the name, the bane and the boon folded into one label,
	# and the boon - the half a player is actually deciding on - was the line that
	# got clipped whenever the icon set the row's height.
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_row = HBoxContainer.new()
	_road_row.add_theme_constant_override("separation", 22)
	_road_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	options_box.add_child(_road_row)
	for omen_id: String in RunState.pending_omens:
		var omen: OmenData = ContentDB.omen(omen_id)
		if omen == null:
			continue
		# **The cost first.** A portent is a bargain and the bane is the half that
		# decides it, which is why the card leads with it - the same reasoning the
		# screen was built under.
		_play_card(omen.id, omen.display_name, 3, omen.get_sprite_path(),
			[["Bane", omen.bane_text], ["Boon", omen.boon_text]],
			omen.portent, _choose_omen.bind(omen.id))
	_road_row = null
	_dress_options()
	panel.visible = true


## The road home (2026-09-14): the act's boss is down, and the party may
## turn for home or push on. Two cards, the purse on each - what a return
## pays now, what the next act would pay, and what a fall keeps - so the
## decision is made with the numbers in view rather than remembered.
func open_homecoming(act: int, home_marks: int, next_marks: int, fall_marks: int) -> void:
	_road_row = null
	_relic_followup_segment = -1
	_buttons.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	for child: Node in options_box.get_children():
		child.queue_free()
	last_homecoming = {"act": act, "home": home_marks, "next": next_marks, "fall": fall_marks}
	title.text = "THE PASS BEHIND YOU  ·  Act %d is yours" % act
	var ahead: TerrainData = ContentDB.terrain_for_act(act + 1)
	var where: String = ahead.display_name if ahead != null else "the road ahead"
	var push := _homecoming_card("PUSH ON\nAct %d, %s. Come home from it with %d Marks - or fall there, and keep %d." % [
		act + 1, where, next_marks, fall_marks], false)
	var home := _homecoming_card("TURN FOR HOME\nBring home %d Marks and everything kept. The road ends here, as a return." % home_marks, true)
	_buttons["push"] = push
	_buttons["home"] = home
	options_box.add_child(push)
	options_box.add_child(home)
	panel.visible = true
	push.grab_focus.call_deferred()


func _homecoming_card(text: String, go_home: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(CARD_WIDTH, 96.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.pressed.connect(_decide_homecoming.bind(go_home))
	return button


func _decide_homecoming(go_home: bool) -> void:
	if _resolving:
		return
	_resolving = true
	_buttons.clear()
	panel.visible = false
	homecoming_decided.emit(go_home)


func _choose_omen(omen_id: String) -> void:
	if _resolving or not RunState.pending_omens.has(omen_id):
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return
		relay.request(CoopRelay.Request.CHOOSE_OMEN, [omen_id])
		_await_answer(omen_id)
		return
	if Coop.partner_present():
		EventBus.coop_omen_chosen.emit(omen_id)
	_apply_omen(omen_id)


## The other player read it. One portent, one road, both screens close.
func accept_partner_omen(omen_id: String) -> void:
	if not RunState.pending_omens.has(omen_id):
		return
	_flash_partner_pick(omen_id)
	_apply_omen(omen_id)


func _apply_omen(omen_id: String) -> void:
	_resolving = false
	RunState.taken_omens.append(omen_id)
	RunState.pending_omens.clear()
	# Rebuilt here rather than by a signal handler somewhere else, because the
	# next thing that happens is a wave being priced against these numbers.
	Modifiers.rebuild()
	EventBus.omen_taken.emit(omen_id)
	panel.visible = false


## A guest asked for a portent. Host side only, like every other request.
func accept_omen_request(omen_id: String) -> void:
	if _resolving or not RunState.pending_omens.has(omen_id):
		return
	if Coop.partner_present():
		EventBus.coop_omen_chosen.emit(omen_id)
	_apply_omen(omen_id)


func _on_coop_omen_chosen(omen_id: String) -> void:
	accept_partner_omen(omen_id)


## The card a player has settled on while the panel asks what to leave behind.
## Empty at every other moment, and cleared on both the apply and the reopen so
## a cancelled draft cannot carry a stale take into the next crossroad.
var _pending_take: String = ""


## The draft at a crossroad. Three cards, a hand of five, one choice.
##
## Built on the portent flow rather than beside it, for the reason that flow was
## built on the relic reward: this is the same panel and the same
## one-choice-for-the-party rule, and a second handshake is a second place for
## co-op to be subtly wrong.
##
## **Two stages, one message.** Taking a card whose effect key the hand already
## holds is a swap and settles at once. Taking a new key with five cards in hand
## has to give something up, so the panel asks which - and only then does the
## pair travel, as one request. Sending the take and the drop separately would
## have made a disconnect between them leave a hand of four.
func open_road_card_choice() -> void:
	_road_row = null
	_relic_followup_segment = -1
	_buttons.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	_pending_take = ""
	for child: Node in options_box.get_children():
		child.queue_free()
	title.text = "WHAT THE ROAD TAUGHT  ·  keep one"
	# **The one draft that carries a real rarity**, so this is where the colour
	# coding and the sheen actually mean something: a Common reads as stock and a
	# Rare wears the travelling highlight.
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_row = HBoxContainer.new()
	_road_row.add_theme_constant_override("separation", 22)
	_road_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_road_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options_box.add_child(_road_row)
	for card_id: String in RunState.pending_road_cards:
		var card: RoadCardData = ContentDB.road_card(card_id)
		if card == null:
			continue
		var rows: Array = [[effect_label(card.effect_id),
			effect_figure(card.effect_id, card.effect_magnitude)]]
		var replaces: String = _replacement_for(card)
		if not replaces.is_empty():
			rows.append(["Replaces", replaces])
		elif RunState.road_card_hand_is_full():
			rows.append(["Hand", "full"])
		_play_card(card.id, card.display_name, int(card.rarity),
			card.get_sprite_path(), rows, card.card_text,
			_choose_road_card.bind(card.id))
	_road_row = null
	_dress_options()
	panel.visible = true


## The line under a card's text: what it does, and what it costs the hand.
func _replacement_for(card: RoadCardData) -> String:
	for held: String in RunState.road_cards:
		var other: RoadCardData = ContentDB.road_card(held)
		if other != null and other.effect_id == card.effect_id:
			return other.display_name
	return ""


func _card_button(card: RoadCardData, replaces: String) -> Button:
	var button := Button.new()
	var note: String = ""
	if not replaces.is_empty():
		note = "\nReplaces %s." % replaces
	elif RunState.road_card_hand_is_full():
		note = "\nYour hand is full. You will choose what to leave."
	button.text = "%s\n%s%s" % [card.display_name.to_upper(), card.card_text, note]
	var art: String = card.get_sprite_path()
	if ResourceLoader.exists(art):
		button.icon = load(art) as Texture2D
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", OMEN_ICON)
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	button.custom_minimum_size = Vector2(CARD_WIDTH, 112.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.tooltip_text = card.description
	return button


func _choose_road_card(card_id: String) -> void:
	if _resolving or not RunState.pending_road_cards.has(card_id):
		return
	var card: RoadCardData = ContentDB.road_card(card_id)
	if card == null:
		return
	if RunState.road_card_hand_is_full() and _replacement_for(card).is_empty():
		_pending_take = card_id
		_open_drop_choice(card)
		return
	_send_road_card(card_id, "")


## Stage two: five cards in hand, and one of them is not coming any further.
func _open_drop_choice(card: RoadCardData) -> void:
	_buttons.clear()
	for child: Node in options_box.get_children():
		child.queue_free()
	title.text = "%s  ·  leave one behind" % card.display_name.to_upper()
	# The hand is shown as the cards it is: choosing which of five to leave
	# behind is a comparison between five things, and a column of rows does not
	# support one.
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_row = HBoxContainer.new()
	_road_row.add_theme_constant_override("separation", 14)
	_road_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_road_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options_box.add_child(_road_row)
	for held: String in RunState.road_cards:
		var other: RoadCardData = ContentDB.road_card(held)
		if other == null:
			continue
		var button: Button = _play_card(other.id, other.display_name,
			int(other.rarity), other.get_sprite_path(),
			[[effect_label(other.effect_id),
				effect_figure(other.effect_id, other.effect_magnitude)],
				["", "LEAVE THIS ONE"]],
			other.card_text, _send_road_card.bind(_pending_take, held))
		_buttons[held] = button
		options_box.add_child(button)
	panel.visible = true


func _send_road_card(card_id: String, drop: String) -> void:
	if _resolving:
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return
		relay.request(CoopRelay.Request.CHOOSE_ROAD_CARD, [card_id, drop])
		_await_answer(card_id)
		return
	if Coop.partner_present():
		EventBus.coop_road_card_chosen.emit(card_id, drop)
	_apply_road_card(card_id, drop)


## The other player kept one. One card, one road, both screens close.
func accept_partner_road_card(card_id: String, drop: String) -> void:
	if not RunState.pending_road_cards.has(card_id):
		return
	_flash_partner_pick(card_id)
	_apply_road_card(card_id, drop)


func _apply_road_card(card_id: String, drop: String) -> void:
	_resolving = false
	_pending_take = ""
	# `RunState` owns both hand rules so that one function decides and the gate
	# can drive the real one.
	var dropped: String = RunState.take_road_card(card_id, drop)
	RunState.pending_road_cards.clear()
	EventBus.road_card_taken.emit(card_id, dropped)
	panel.visible = false


## A guest asked for a card. Host side only, like every other request.
func accept_road_card_request(card_id: String, drop: String) -> void:
	if _resolving or not RunState.pending_road_cards.has(card_id):
		return
	if Coop.partner_present():
		EventBus.coop_road_card_chosen.emit(card_id, drop)
	_apply_road_card(card_id, drop)


func _on_coop_road_card_chosen(card_id: String, drop: String) -> void:
	accept_partner_road_card(card_id, drop)


func _choose_relic(relic_id: String) -> void:
	if _resolving or not RunState.pending_road_relics.has(relic_id):
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return
		relay.request(CoopRelay.Request.CHOOSE_RELIC, [relic_id])
		_await_answer(relic_id)
		return
	if Coop.partner_present():
		EventBus.coop_relic_chosen.emit(relic_id)
	_apply_relic(relic_id)


## The other player took the relic. One reward, one winner, both screens close.
func accept_partner_relic(relic_id: String) -> void:
	if not RunState.pending_road_relics.has(relic_id):
		return
	_flash_partner_pick(relic_id)
	_apply_relic(relic_id)


func _apply_relic(relic_id: String) -> void:
	_resolving = false
	RunState.held_relics.append(relic_id)
	RunState.pending_road_relics.clear()
	relic_chosen.emit(relic_id)
	var followup: int = _relic_followup_segment
	_relic_followup_segment = -1
	if followup >= 0:
		_open_roads(followup)
	else:
		panel.visible = false


## One road, as a framed card.
##
## The description used to be a bare Label sitting directly on the key art with
## no padding and no plate behind it — pale text over a photographic background
## of rocks and sunlight, which is unreadable roughly half the time depending on
## what the art happens to be doing behind that line. Putting each option on its
## own dark plate fixes the contrast and the padding in one move.
func _add_option(road: RoadData, difficulty: RoadDifficultyData) -> void:
	if road == null or difficulty == null:
		return
	var card := PanelContainer.new()
	card.theme_type_variation = &"InnerPanel"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var button := Button.new()
	button.text = "%s  ·  %s" % [difficulty.display_name.to_upper(), road.display_name]
	button.custom_minimum_size = Vector2(0.0, 64.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_color_override("font_color", difficulty.card_colour)
	IconKit.on_button(button, road.icon_id, 26)
	button.pressed.connect(func() -> void: _choose(road.id, difficulty.id))
	_buttons[road.id] = button
	_offers.append(PackedStringArray([road.id, difficulty.id]))
	box.add_child(button)

	var text := Label.new()
	text.text = "%s\n%s\n%s" % [road.promise, road.consequence,
		_exact_consequences(road, difficulty)]
	text.add_theme_font_size_override("font_size", 18)
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Leading, because these are three separate claims about the road and they
	# ran together as one paragraph at the old size.
	text.add_theme_constant_override("line_spacing", 7)
	text.add_theme_color_override("font_color", Color("bcc9c4"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Indented to the button's own text inset, so the description reads as
	# belonging to the road above it rather than as a separate loose line.
	text.custom_minimum_size = Vector2(0.0, 0.0)
	var indent := MarginContainer.new()
	indent.add_theme_constant_override("margin_left", TEXT_INDENT)
	indent.add_theme_constant_override("margin_right", 8)
	indent.add_theme_constant_override("margin_bottom", 4)
	indent.add_child(text)
	box.add_child(indent)

	if _road_row != null:
		_road_row.add_child(card)
	else:
		options_box.add_child(card)


func _shuffle_roads(roads: Array[RoadData]) -> void:
	for index: int in range(roads.size() - 1, 0, -1):
		var other: int = _rng.randi_range(0, index)
		var swap: RoadData = roads[index]
		roads[index] = roads[other]
		roads[other] = swap


func _pick_difficulty(segment_index: int) -> RoadDifficultyData:
	var tiers: Array[RoadDifficultyData] = ContentDB.road_difficulties_sorted()
	if tiers.is_empty():
		return null
	# The first decision cannot spring the highest tier on a player who has not
	# seen one complete regional road yet. From the second crossroad onward every
	# tier can appear and is stated explicitly on the card.
	var available: int = mini(tiers.size(), 2 if segment_index <= 1 else 3)
	return tiers[_rng.randi_range(0, available - 1)]


func _exact_consequences(road: RoadData, difficulty: RoadDifficultyData) -> String:
	var distance: int = int(round(Balance.SEGMENT_DISTANCE * road.distance_scale))
	var minutes: float = float(distance) / maxf(Balance.BEAST_BASE_SPEED, 0.01) / 60.0
	var count: int = int(round((road.count_scale * difficulty.count_scale - 1.0) * 100.0))
	var stats: int = int(round((road.hp_scale * difficulty.stat_scale - 1.0) * 100.0))
	var tier: int = RunState.foresight_tier()
	var intelligence: PackedStringArray = [
		"%d distance" % distance,
		"~%.1f min" % minutes,
	]
	# The unbuilt state shows only known categories. Every tier turns another
	# uncertainty into a decision-quality fact.
	if tier >= 1:
		intelligence.append("%+d%% bodies" % count)
		intelligence.append("%+d%% durability" % stats)
	else:
		intelligence.append("threat details unknown")
	if tier >= 2:
		intelligence.append("%d reward roll%s" % [difficulty.reward_rolls,
			"" if difficulty.reward_rolls == 1 else "s"])
	else:
		intelligence.append("reward depth unknown")
	if tier >= 3:
		intelligence.append(_reward_categories(road))
	else:
		var known: PackedStringArray = []
		if road.guaranteed_regional_relic:
			known.append("Regional relic")
		if road.guarantees_raid_charge:
			known.append("Raid Charge")
		intelligence.append(", ".join(known) if not known.is_empty() else "supplies")
	return " · ".join(intelligence)


func _reward_categories(road: RoadData) -> String:
	var rewards: PackedStringArray = []
	for currency: Variant in road.reward_currencies:
		rewards.append(String(currency).capitalize())
	if road.guaranteed_regional_relic:
		rewards.append("Regional relic choice")
	if road.guarantees_raid_charge:
		rewards.append("Full Raid Charge")
	return ", ".join(rewards) if not rewards.is_empty() else "standard supplies"


## Applies the road's effect, then hands control back to the run.
## Somebody clicked a road. Exactly one of them decides it.
##
## "Whoever chooses first chooses for both" needs an arbiter, because *first* is
## not a thing either machine can work out alone - two clicks half a frame apart
## look simultaneous from both sides, and both would apply their own road. So the
## guest asks and waits, the host answers, and the answer comes back as a fact
## that both machines apply identically. The host is first if it clicked first;
## the guest is first if its request landed before the host's click.
func _choose(road_id: String, difficulty_id: String) -> void:
	if _resolving:
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay == null:
			return
		# Still `CHOOSE_ROAD` on the wire. The host reads it as a vote now, but
		# an older host reads it as a choice and settles the fork immediately -
		# which is the behaviour that shipped, so a mixed party degrades rather
		# than deadlocking. See `CoopRelay.Fact.ROAD_VOTES`.
		relay.request(CoopRelay.Request.CHOOSE_ROAD, [road_id, difficulty_id])
		_await_answer(road_id)
		return
	if not Coop.partner_present():
		_apply_choice(road_id, difficulty_id)
		return
	host_vote(road_id, difficulty_id)


## The host taking its turn in the fork: one vote, then a wait.
##
## Its own function rather than two lines inside `_choose`, because those two
## lines are where the co-op deadlock lived and `_choose` cannot be driven
## without a live peer - it branches on `Coop.partner_present()`. A bug that can
## only be reached through a socket is a bug no gate will ever hold.
##
## The wait is `_await_votes`, which greys the buttons, and **not**
## `_await_answer`, which also sets `_resolving`. That flag means "this machine
## can no longer decide anything", and three functions honour it: `cast_vote`,
## `_tick_vote` and `_resolve_votes`. A host that set it by voting had closed its
## own fork against the partner it was waiting for.
func host_vote(road_id: String, difficulty_id: String) -> void:
	cast_vote(HOST_VOTER, road_id, difficulty_id)
	_await_votes(road_id)


## One player's vote. Host side; `voter` is the transport id, or `HOST_VOTER`.
##
## **A fork used to be settled by whoever clicked first**, which meant the faster
## player decided every road for the whole party and the slower one never had a
## say in where their own run went. Votes are counted instead, and the count is
## shown while it is happening so the decision is visible rather than reported.
func cast_vote(voter: int, road_id: String, difficulty_id: String) -> void:
	if not is_open() or _resolving or not Coop.is_host():
		return
	if not _buttons.has(road_id):
		# **Never silent.** A vote for a road this screen does not have means the
		# two machines drew different offers, which is a desync rather than a
		# stray click - and dropped quietly it presents as a fork that simply
		# never resolves, with nothing anywhere saying why.
		push_warning("[crossroad] vote for '%s' from %d, which is not on this screen (%s)"
			% [road_id, voter, ", ".join(PackedStringArray(_buttons.keys()))])
		return
	if _votes.is_empty():
		_vote_left = Balance.CROSSROAD_VOTE_SECONDS
	_votes[voter] = road_id
	_vote_difficulty[road_id] = difficulty_id
	if voter != HOST_VOTER:
		_flash_partner_pick(road_id)
	_publish_tally()
	if _votes.size() >= _expected_voters():
		_resolve_votes()


# --- What the fork looks like from outside ----------------------------------
#
# Four readers, added for `crossroad_vote_check`. The rule for electing a road
# was already testable - `winning_road` is static and pure for that reason - and
# the *sequencing* around it was not, which is where the deadlock lived and why
# six green tests said nothing about it.

## The roads currently on offer, in the order they are drawn.
func road_ids() -> Array:
	var out: Array = []
	for id: Variant in _buttons:
		out.append(String(id))
	return out


## How many votes are in, before any of them are counted into a tally.
func vote_count() -> int:
	return _votes.size()


## True once the fork has produced an answer and closed.
func is_settled() -> bool:
	return not RunState.active_road_id.is_empty()


## Whether this machine has stopped accepting answers.
##
## Named rather than inferred, because it is the mechanism of the co-op deadlock
## rather than a symptom of it: `cast_vote`, `_tick_vote` and `_resolve_votes`
## all refuse while it is set, so a host that set it by voting had shut its own
## fork.
func is_resolving() -> bool:
	return _resolving


## How many players the fork is waiting for.
func _expected_voters() -> int:
	return maxi(Coop.party().size(), 1) if Coop.is_host() else 1


## Which road a set of votes elects. `votes` is voter id -> road id.
##
## Static and free of the screen, the party and the network on purpose: the rule
## for settling a fork is the part that has to be *identical* everywhere and the
## part worth testing, and neither is true of a function that needs a live socket
## and a built UI to call. `crossroad_vote_check` drives this directly.
##
## Ties go to the host - not because the host deserves the road, but because a
## tie has to break the same way on every machine, and the host is the only
## participant every machine agrees exists. A tie the host did not vote in falls
## to the first road that reached the winning count, which is the only other
## ordering all machines share.
static func winning_road(votes: Dictionary) -> String:
	if votes.is_empty():
		return ""
	var tally: Dictionary = {}
	for voter: Variant in votes:
		var road: String = String(votes[voter])
		tally[road] = int(tally.get(road, 0)) + 1

	var best: String = ""
	var best_count: int = -1
	# Iterated over the votes rather than the tally so "first to reach the count"
	# means first *cast*, which every machine sees in the same order.
	for voter: Variant in votes:
		var road: String = String(votes[voter])
		if int(tally[road]) > best_count:
			best = road
			best_count = int(tally[road])
	if votes.has(HOST_VOTER):
		var host_road: String = String(votes[HOST_VOTER])
		if int(tally.get(host_road, 0)) == best_count:
			return host_road
	return best


func _tally() -> Dictionary:
	var out: Dictionary = {}
	for voter: Variant in _votes:
		var road: String = String(_votes[voter])
		out[road] = int(out.get(road, 0)) + 1
	return out


func _publish_tally() -> void:
	var tally: Dictionary = _tally()
	var voters: int = _expected_voters()
	_show_tally(tally, voters)
	var relay: CoopRelay = Coop.relay()
	if relay != null:
		relay.road_votes(tally, voters)


## Settles the fork on the votes cast.
##
## Ties go to the host. Not because the host deserves the road, but because a
## tie has to break the same way on every machine and the host is the only
## participant every other machine agrees exists - and it is already the one that
## declares the fork and owns the seeded stream the offers came from. A tie with
## no host vote falls to the first road that reached the tied count, which is
## the only other ordering all machines share.
func _resolve_votes() -> void:
	if _resolving or _votes.is_empty():
		return
	var best: String = winning_road(_votes)
	if best.is_empty():
		return
	var difficulty: String = String(_vote_difficulty.get(best, ""))
	_vote_left = 0.0
	_votes.clear()
	# Announced before it is applied, so every screen closes on the same result
	# rather than a frame later with the road already changed under it.
	EventBus.coop_road_chosen.emit(best, difficulty)
	_apply_choice(best, difficulty)


## A guest voted. Host side.
##
## `voter` is the transport id the request arrived on, so four players cast four
## votes and one player clicking four times casts one. It was ignored entirely
## while the fork was first-click-wins, because a single click ended the question.
func accept_road_request(road_id: String, difficulty_id: String, voter: int = 0) -> void:
	if not is_open() or _resolving:
		return
	cast_vote(voter, road_id, difficulty_id)


## The guest asked for the relic. Host side.
func accept_relic_request(relic_id: String) -> void:
	if not is_open() or _resolving:
		return
	if not RunState.pending_road_relics.has(relic_id):
		return
	_flash_partner_pick(relic_id)
	_choose_relic(relic_id)


## Locks the fork after a click that this machine cannot settle by itself.
##
## Without it the guest can click three roads while one request is in flight, and
## the host would answer the first while the player believes they chose the last.
func _await_answer(picked_id: String) -> void:
	_resolving = true
	_dim_to(picked_id)


## Locks the *host's* fork after it has voted, without locking the vote itself.
##
## **This is the deadlock that stopped co-op runs**, reported from play on
## 2026-09-10: "voting at crossroads got stuck with only 1 of the 2 player's
## votes and not allowing for the other player to vote".
##
## The host used to call `_await_answer` after casting its own vote, which sets
## `_resolving`. Three separate things test that flag before doing anything:
## `cast_vote` refuses while it is set, `_tick_vote` refuses, and
## `_resolve_votes` refuses. So the moment the host voted, the partner's vote was
## dropped on arrival, the countdown that exists to settle a fork nobody finishes
## stopped counting, and the resolution that would have ended it declined to run.
## One vote in, two players waiting, and no way forward.
##
## It only happened when the **host** clicked first. Guest-first works: the
## guest's own `_resolving` is local to its machine, the host is still open when
## the request lands, and the host's later click completes the count. So the fork
## deadlocked on roughly half of all forks, which is exactly how it reads in a
## report - intermittent, and fatal when it happens.
##
## The fix is to separate "this player has committed" from "this machine cannot
## decide anything further". Only the second belongs to `_resolving`.
func _await_votes(picked_id: String) -> void:
	_dim_to(picked_id)


func _dim_to(picked_id: String) -> void:
	for id: Variant in _buttons:
		var button: Button = _buttons[id] as Button
		if button == null or not is_instance_valid(button):
			continue
		button.disabled = true
		button.modulate = Color.WHITE if String(id) == picked_id 			else Color(1.0, 1.0, 1.0, 0.45)


## The other player chose. Take it and close.
##
## Deliberately identical to choosing it here, minus the announcement: the fork
## has one answer and both machines have to reach the same one, so there is no
## second path where a partner's road is applied differently from your own.
func accept_partner_choice(road_id: String, difficulty_id: String) -> void:
	if not is_open():
		return
	_flash_partner_pick(road_id)
	_apply_choice(road_id, difficulty_id)


func _apply_choice(road_id: String, difficulty_id: String) -> void:
	_resolving = false
	RunState.active_road_id = road_id
	RunState.active_road_difficulty_id = difficulty_id
	RunState.start_last_scar_road()
	RunState.record_road_choice(_open_segment, road_id, difficulty_id)
	panel.visible = false
	_hide_pointer()
	road_chosen.emit(road_id)


## Whether the fork is currently in front of the player.
func is_open() -> bool:
	return panel != null and panel.visible


## The first road on the table, as [road id, difficulty id]. Empty if none.
##
## Public for the co-op harness, which has to click a road the *other* process
## also drew - naming one in the test would only prove the test can spell.
func first_offer() -> PackedStringArray:
	return _offers[0] if not _offers.is_empty() else PackedStringArray()


func _on_coop_relic_chosen(relic_id: String) -> void:
	var relay: CoopRelay = Coop.relay()
	if relay == null or not relay.is_replaying():
		return
	accept_partner_relic(relic_id)


## Marks the option a partner took, for the moment before the screen closes.
##
## Small, and worth it: without it a crossroad simply vanishes and the player is
## on a road nobody told them about. With it they see *which* one, and that their
## friend picked it.
func _flash_partner_pick(picked_id: String) -> void:
	var button: Button = _buttons.get(picked_id, null) as Button
	if button == null or not is_instance_valid(button):
		return
	button.modulate = Balance.COOP_PARTNER_TINT
	# Parented to the layer, not the panel: the panel is about to hide, and the
	# whole point of this label is to still be readable after it does.
	var mark := Label.new()
	mark.text = "THEY CHOSE"
	mark.add_theme_font_size_override("font_size", 22)
	mark.add_theme_color_override("font_color", Balance.COOP_PARTNER_TINT)
	mark.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.03, 0.95))
	mark.add_theme_constant_override("outline_size", 6)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)
	mark.position = button.get_global_rect().get_center() - Vector2(58.0, 14.0)
	var fade: Tween = mark.create_tween()
	fade.set_parallel(true)
	fade.tween_property(mark, "position", mark.position - Vector2(0.0, 34.0), 0.9) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	fade.tween_property(mark, "modulate:a", 0.0, 0.9).set_delay(0.35)
	fade.chain().tween_callback(mark.queue_free)


## Runs down the fork's patience. Host side only - a guest counts nothing,
## because the host is the one that settles it and two clocks would disagree.
func _tick_vote(delta: float) -> void:
	if _vote_left <= 0.0 or _resolving or not Coop.is_host():
		return
	_vote_left -= delta
	if _vote_left <= 0.0:
		_resolve_votes()


## Paints the running count onto the road cards.
##
## Shown on every machine, including the one that is only watching: the point of
## counting votes rather than racing clicks is that the party can see where the
## party stands before it is decided.
func _show_tally(tally: Dictionary, voters: int) -> void:
	for id: Variant in _buttons:
		var button: Button = _buttons[id] as Button
		if button == null or not is_instance_valid(button):
			continue
		var count: int = int(tally.get(String(id), 0))
		var base: String = String(button.get_meta("vote_base_text", button.text))
		if not button.has_meta("vote_base_text"):
			button.set_meta("vote_base_text", base)
		button.text = base if count <= 0 else "%s   (%d/%d)" % [base, count, voters]


func _on_coop_road_votes(tally: Dictionary, voters: int) -> void:
	if not is_open():
		return
	_show_tally(tally, voters)
