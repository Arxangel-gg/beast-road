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

## An augment draft closed - taken, skipped, or put off till later. The run lets
## the field go on it if it was the one that held it.
signal augment_closed()

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
## The row the cards are dealt into: a box for a draft, a flow for a hand.
var _road_row: Container = null

## **Whether the table holds an augment draft** (2026-09-26) rather than one of
## the crossroad's own choices. Set by `open_augment_draft` and dropped by every
## other door onto the panel.
##
## **And it decides what is behind the cards.** A draft opens in a breather with
## the board standing, and whether a Rampart card is worth more than a Warden one
## is a question about that board - so the crossroad's painting gives way to a
## scrim and the road shows through it, dimmed and still. A crossroad, a relic
## and a portent keep the painting: they are places and moments, and a draft is
## neither. Set on the flag rather than at each door, because every door onto the
## panel sets the flag and not every door would remember a second line.
var _augment_open: bool = false:
	set(value):
		_augment_open = value
		_wear_backdrop(not value)
var _scrim: ColorRect = null
## Which `_fit_play_cards` is the current one; see its first lines.
var _fit_generation: int = 0
## Banish is armed: the next card pressed leaves the deck rather than the draft.
var _banishing: bool = false
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


## The painting behind a crossroad, or the scrim behind a draft. The painting is
## hidden by its own `self_modulate`, which draws nothing of the texture and
## leaves the cards - its children - exactly as they are.
func _wear_backdrop(painted: bool) -> void:
	if panel == null:
		return
	var art := panel.get_node_or_null(^"Art") as TextureRect
	if art != null:
		art.self_modulate.a = 1.0 if painted else 0.0
	if _scrim == null and not painted:
		_scrim = ColorRect.new()
		_scrim.name = "DraftScrim"
		_scrim.color = Balance.AUGMENT_DRAFT_SCRIM
		_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.add_child(_scrim)
		panel.move_child(_scrim, 0)
		_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _scrim != null:
		_scrim.visible = not painted


## Whether the table is drawn over the road rather than over a painting.
func shows_the_road() -> bool:
	var art := panel.get_node_or_null(^"Art") as TextureRect if panel != null else null
	return art != null and is_zero_approx(art.self_modulate.a) \
		and _scrim != null and _scrim.visible


func _ready() -> void:
	UiFonts.set_role(get_node_or_null(^"Panel/Art/Box/Title") as Control, UiFonts.Role.TITLE)
	EventBus.coop_road_votes.connect(_on_coop_road_votes)
	_rng = RunState.rng("roads")
	panel.visible = false
	EventBus.coop_pointer_moved.connect(_on_partner_pointer)
	EventBus.coop_relic_chosen.connect(_on_coop_relic_chosen)
	EventBus.coop_omen_chosen.connect(_on_coop_omen_chosen)
	EventBus.coop_road_card_chosen.connect(_on_coop_road_card_chosen)
	EventBus.augment_offer_changed.connect(_on_augment_offer_changed)
	EventBus.coop_last_scar_accepted.connect(_on_coop_last_scar_accepted)


func open(segment_index: int) -> void:
	_augment_open = false
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
	_road_row = _card_row()
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
	# The road home (2026-09-30): it asked for "marks", which was never drawn.
	IconKit.on_button(_extract_button, "distance", 24)
	_extract_button.pressed.connect(_choose_extraction)
	box.add_child(_extract_button)
	var note := Label.new()
	# **It says that leaving is a fight now** (2026-09-16). The card used to end
	# the paragraph on "kept where they stand", which was true when a return
	# settled on the press; it now opens sixteen seconds of combat the wall can be
	# worn by, and this card is the last thing a player reads before it.
	note.text = ("The road behind you closes first - hold the gate while the beast "
		+ "pulls away, and the front comes home in whatever state that fight "
		+ "leaves it. You always reach home. Come back to this act rather than to "
		+ "the first.")
	note.add_theme_font_size_override("font_size", 16)
	note.add_theme_color_override("font_color", Color("9a9384"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	_add_momentum_line(box)
	options_box.add_child(card)


## **What pushing on has bought**, on the card where it is spent.
##
## Momentum is a real number: every fork passed without banking raises it, it
## pays `kill_resources` and half as much `resource_rate`, and it is what decides
## whether this card is offered at all (`Run.extraction_open`). It was shown to
## the player **nowhere** - the only mention of it anywhere in the interface was
## a code comment in this file.
##
## Here rather than on the HUD because this is the moment it means something: the
## choice on this screen is bank it or keep pushing, and the number is the size of
## what pushing has already earned.
func _add_momentum_line(box: VBoxContainer) -> void:
	var push: float = clampf(RunState.momentum, 0.0, Balance.MOMENTUM_MAX)
	if push <= 0.0:
		return
	var line := Label.new()
	line.text = ("Pushing on has paid you +%d%% from every body and +%d%% from the "
		+ "road. Banking is what you are weighing it against.") % [
		int(round(push * 100.0)), int(round(push * 50.0))]
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_color_override("font_color", Color("c2b48a"))
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(line)


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
	_augment_open = false
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
	_road_row = _card_row()
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
	Color("b8c1bc"), Color("8fd6a4"), Color("8fb6ef"), Color("c79bf0"), Color("d8a85f"),
]
## Indexed by `RoadCardData.Rarity`. Epic arrived with augments (2026-09-26); the
## portents, which have no rarity of their own, wear Legendary.
const RARITY_WORD: Array[String] = ["COMMON", "UNCOMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_LEGENDARY: int = 4

## Portrait, and wide enough for two stat rows without wrapping. Three of these
## sit across the panel with room around them.
const PLAY_CARD := Vector2(286.0, 404.0)
## Longer than this, a card's value is a sentence and goes on its own wrapped
## line under its name rather than beside it.
const PLAY_CARD_INLINE_CHARS: int = 18
const PLAY_CARD_ART: int = 150
## The face's inset inside the card, horizontally and vertically.
const PLAY_CARD_INSET := Vector2(14.0, 12.0)
## A dealt card flips in from edge-on and settles with a little overshoot.
const CARD_DEAL_SECONDS: float = 0.34
const CARD_DEAL_FROM := Vector2(0.06, 0.92)
## A card under the cursor or the pad lifts toward the player.
const CARD_HOVER_SCALE: float = 1.045
const CARD_HOVER_SECONDS: float = 0.12
## How much wider than `PLAY_CARD` a card may grow on a short screen, the
## smallest the illustration may shrink to, and the air under the cards.
const PLAY_CARD_WIDEST: float = 1.7
const PLAY_CARD_ART_MIN: int = 64
const PLAY_CARD_FOOT: float = 16.0

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
	face.offset_left = PLAY_CARD_INSET.x
	face.offset_right = -PLAY_CARD_INSET.x
	face.offset_top = PLAY_CARD_INSET.y
	face.offset_bottom = -PLAY_CARD_INSET.y
	face.set_meta(&"play_face", true)
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
	face.set_meta(&"art", art)

	# **What it does, in the numbers it does it by.**
	#
	# A figure sits beside its name; a *sentence* - a portent's bane and boon -
	# goes under its name and wraps to the card (owner, 2026-09-22: portents
	# "do not properly wrap or have proper alignment"). On one line beside the
	# name, a sentence set the card face wider than the card and ran across the
	# cards beside it.
	face.clip_contents = true
	for pair: Array in stats:
		var value: String = String(pair[1])
		if value.length() > PLAY_CARD_INLINE_CHARS:
			var heading: Label = _card_line(String(pair[0]).to_upper(), 12,
				Color("9aa39e"), HORIZONTAL_ALIGNMENT_LEFT)
			face.add_child(heading)
			var said: Label = _card_line(value, 14, tint.lightened(0.15),
				HORIZONTAL_ALIGNMENT_LEFT)
			said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			said.custom_minimum_size.x = 0.0
			face.add_child(said)
			continue
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var label: Label = _card_line(String(pair[0]), 15, Color("9aa39e"),
			HORIZONTAL_ALIGNMENT_LEFT)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(_card_line(value, 15, tint.lightened(0.15),
			HORIZONTAL_ALIGNMENT_RIGHT))
		face.add_child(row)

	var rule := ColorRect.new()
	rule.color = Color(tint.r, tint.g, tint.b, 0.28)
	rule.custom_minimum_size = Vector2(0.0, 1.0)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(rule)

	var words: Label = _card_line(flavour, 14, Color("a8b0aa"),
		HORIZONTAL_ALIGNMENT_CENTER)
	UiFonts.set_role(words, UiFonts.Role.FLAVOUR, 15)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = 0.0
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
	# A keystone moves no number, so it says what it is instead of "+100%".
	if effect_id.begins_with("keystone_"):
		return "Keystone"
	if effect_id == "chain_targets" or effect_id == "wave_foresight" \
			or effect_id == Modifiers.ARSENAL_COUNT:
		return "%+d" % int(round(magnitude))
	return "%+d%%" % int(round(magnitude * 100.0))


## "tower_damage" -> "Tower damage". The keys are authored in snake_case and a
## card is read by a person.
static func effect_label(effect_id: String) -> String:
	# Authored on `Modifiers` rather than derived here. The derived form
	# title-cased every word, so relics promised "Hero Max Hp" and one treasure
	# card printed "Captive Output" above a description that says "Oathbound".
	return Modifiers.label(effect_id)


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
	_fit_play_cards()


## **A row of cards is centred** (2026-09-25). An `HBoxContainer` packs its
## children to the left by default, so three cards on a wide screen stood in
## the left half of it (owner's screenshot of the portents). One helper for the
## roads, the relics and the portents, so the three cannot disagree.
func _card_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	return row


## **Every card as tall as its tallest face needs** (2026-09-25). A card is a
## `Button` of a fixed size with its face laid inside it, and a `Button` does
## not grow to fit children - so a portent whose bane, boon and flavour needed
## more height than the card had grew its face past the card's bottom edge,
## and the clip on the face clipped nothing because it clips to its own grown
## rect (owner's screenshot: the flavour sentence under the cards). Measured
## after two layout passes, because an autowrapped label only knows its height
## once it has been given its width; then every card in the row takes the
## tallest, so the three read as one hand.
##
## Then the deal: each card flips in from edge-on on `scale`, which a
## container does not own - the first entrance tweened position and fought
## the row. A look and never a fact.
func _fit_play_cards() -> void:
	# **A fit belongs to the cards it was started for** (2026-09-26). It waits
	# on layout passes, and a draft redrawn meanwhile - a reroll, a banish, a
	# host's answer to a guest - frees the cards this one is holding; the next
	# line then read a freed button. A newer fit ends the older one.
	_fit_generation += 1
	var generation: int = _fit_generation
	if not await _settle(2) or generation != _fit_generation:
		return
	var cards: Array[Button] = []
	for node: Node in _entrance_cards():
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		var card := node as Button
		if card != null and play_face(card) != null:
			cards.append(card)
	if cards.is_empty():
		return
	# **The room first, then the fit** (2026-09-25). On a landscape phone the
	# touch fonts wrap a portent to 658 units against a 777-unit screen with
	# the title above it, and the row had a thousand units of width to spare.
	# So a card that would run off the bottom first widens into its share of
	# the row - the text wraps less - and only then does the illustration give
	# up height, down to `PLAY_CARD_ART_MIN`. `layout_check` holds that every
	# card ends on the screen at every shape.
	var room: float = _card_room(cards[0])
	var tallest: float = _tallest_face(cards)
	if tallest > room:
		var row := cards[0].get_parent() as Control
		var gaps: float = float(row.get_theme_constant("separation")) * float(cards.size() - 1) \
			if row != null else 0.0
		var share: float = ((row.size.x if row != null else PLAY_CARD.x) - gaps) / float(cards.size())
		var width: float = clampf(share, PLAY_CARD.x, PLAY_CARD.x * PLAY_CARD_WIDEST)
		for card: Button in cards:
			card.custom_minimum_size.x = width
		if not await _settle(2) or generation != _fit_generation:
			return
		tallest = _tallest_face(cards)
	if tallest > room:
		var art_height: float = maxf(float(PLAY_CARD_ART) - (tallest - room), float(PLAY_CARD_ART_MIN))
		for card: Button in cards:
			var art := play_face(card).get_meta(&"art", null) as Control
			if art != null:
				art.custom_minimum_size.y = art_height
		if not await _settle(2) or generation != _fit_generation:
			return
		tallest = _tallest_face(cards)
	for card: Button in cards:
		card.custom_minimum_size.y = ceilf(tallest)
	if not await _settle(1) or generation != _fit_generation:
		return
	var step: int = 0
	for card: Button in cards:
		if not is_instance_valid(card):
			continue
		card.pivot_offset = card.size * 0.5
		card.scale = CARD_DEAL_FROM
		var deal: Tween = create_tween()
		deal.tween_interval(float(step) * CARD_ENTRANCE_STAGGER)
		deal.tween_callback(Sfx.play_group.bind("sfx_ui_move", -6.0, float(step) * 0.05))
		deal.tween_property(card, "scale", Vector2.ONE, CARD_DEAL_SECONDS) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		card.set_meta(&"juice_tween", deal)
		if not card.mouse_entered.is_connected(_lift_card):
			card.mouse_entered.connect(_lift_card.bind(card, true))
			card.focus_entered.connect(_lift_card.bind(card, true))
			card.mouse_exited.connect(_lift_card.bind(card, false))
			card.focus_exited.connect(_lift_card.bind(card, false))
		step += 1


## Waits `frames` layout passes; false if the screen left the tree meanwhile.
func _settle(frames: int) -> bool:
	for _frame: int in frames:
		await get_tree().process_frame
		if not is_inside_tree():
			return false
	return true


## The height a card may take: from its own top to the foot of the screen.
func _card_room(card: Control) -> float:
	var screen: Rect2 = card.get_viewport().get_visible_rect()
	return screen.end.y - card.get_global_rect().position.y - PLAY_CARD_FOOT


## The tallest face in the row, with its inset, at the widths it has now.
func _tallest_face(cards: Array[Button]) -> float:
	var tallest: float = PLAY_CARD.y
	for card: Button in cards:
		var face: Control = play_face(card)
		if face != null:
			tallest = maxf(tallest, face.get_combined_minimum_size().y + PLAY_CARD_INSET.y * 2.0)
	return tallest


## The face a play card carries, or null for any other kind of card.
static func play_face(card: Control) -> Control:
	for child: Node in card.get_children():
		if child.has_meta(&"play_face"):
			return child as Control
	return null


func _lift_card(card: Button, up: bool) -> void:
	if not is_instance_valid(card):
		return
	var running: Variant = card.get_meta(&"juice_tween", null)
	if running is Tween and (running as Tween).is_valid():
		(running as Tween).kill()
	card.pivot_offset = card.size * 0.5
	var lift: Tween = create_tween()
	lift.tween_property(card, "scale", Vector2.ONE * (CARD_HOVER_SCALE if up else 1.0),
		CARD_HOVER_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	card.set_meta(&"juice_tween", lift)


## The cards an entrance should play on: whatever is laid out in the row when
## there is one, and the column's own children when there is not.
func _entrance_cards() -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in options_box.get_children():
		if child is HBoxContainer:
			out.append_array(child.get_children())
		elif child is ScrollContainer:
			# The drop choice's lane: a flow of cards inside a scroll.
			for lane_child: Node in child.get_children():
				if lane_child is FlowContainer:
					out.append_array(lane_child.get_children())
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
	_augment_open = false
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
	_road_row = _card_row()
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
		_play_card(omen.id, omen.display_name, RARITY_LEGENDARY, omen.get_sprite_path(),
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
	_augment_open = false
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
	_augment_open = false
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
	var centred: HBoxContainer = _card_row()
	centred.add_theme_constant_override("separation", 22)
	centred.alignment = BoxContainer.ALIGNMENT_CENTER
	centred.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_road_row = centred
	options_box.add_child(_road_row)
	for card_id: String in RunState.pending_road_cards:
		var card: RoadCardData = ContentDB.road_card(card_id)
		if card == null:
			continue
		_play_card(card.id, card.display_name, int(card.rarity),
			card.get_sprite_path(), augment_rows(card), card.card_text,
			_choose_road_card.bind(card.id))
	_road_row = null
	_dress_options()
	panel.visible = true


## The line under a card's text: what it does, and what it costs the hand.
func _replacement_for(card: RoadCardData) -> String:
	for held: String in RunState.target_hand(card):
		var other: RoadCardData = ContentDB.road_card(held)
		if other == null:
			continue
		# A keystone replaces the keystone held, whatever it re-routes.
		if card.keystone and other.keystone:
			return other.display_name
		if other.key() == card.key():
			return other.display_name
	return ""


func _card_button(card: RoadCardData, replaces: String) -> Button:
	var button := Button.new()
	var note: String = ""
	if not replaces.is_empty():
		note = "\nReplaces %s." % replaces
	elif RunState.hand_is_full_for(card):
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
	if _needs_a_drop(card):
		_pending_take = card_id
		_open_drop_choice(card)
		return
	_send_road_card(card_id, "")


## Stage two: a full hand, and one of the cards is not coming any further.
## `on_leave` takes the card being kept and the one being left; the crossroad's
## own draft sends the pair to the party, an augment draft takes it at once.
func _open_drop_choice(card: RoadCardData, on_leave: Callable = Callable()) -> void:
	_buttons.clear()
	for child: Node in options_box.get_children():
		child.queue_free()
	title.text = "%s  ·  leave one behind" % card.display_name.to_upper()
	# The hand is shown as the cards it is: choosing which of eight to leave
	# behind is a comparison between eight things, and a column of rows does
	# not support one.
	#
	# **A row that wraps, in a lane that scrolls** (owner, 2026-09-30: the list
	# was *"not properly centered with cards going offscreen on the right side
	# without scroll support"*). A hand of eight in one row is wider than any
	# screen this game runs on, and an `HBoxContainer` does not know that.
	# The cards flow into as many centred rows as the width allows, and the
	# lane scrolls when two rows are taller than the panel - so a card is
	# never off the edge in either direction.
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var lane := ScrollContainer.new()
	lane.name = "HandLane"
	lane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lane.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UiMetrics.prepare_scroll(lane, TouchInput.is_showing())
	options_box.add_child(lane)
	var flow := HFlowContainer.new()
	flow.name = "Hand"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 14)
	flow.add_theme_constant_override("v_separation", 14)
	lane.add_child(flow)
	_road_row = flow
	for held: String in RunState.target_hand(card):
		var other: RoadCardData = ContentDB.road_card(held)
		if other == null:
			continue
		var leave: Callable = on_leave if on_leave.is_valid() else _send_road_card
		var level: int = RunState.card_level(other.id)
		# The whole of what the card does, not its first two lines: a player
		# is choosing what to give up, and a card cut to two lines reads as
		# worth less than it is (owner: *"the list is too limited"*).
		var what: Array = weapon_rows(other, level, level).slice(0, 4) if other.is_weapon() \
			else [[effect_label(other.effect_id), effect_figure(other.effect_id, other.magnitude_at(level))]]
		what.append(["Level", _level_word(other, level)])
		what.append(["", "LEAVE THIS ONE"])
		var button: Button = _play_card(other.id, other.display_name,
			int(other.rarity), other.get_sprite_path(), what,
			other.card_text, leave.bind(_pending_take, held))
		_buttons[held] = button
	# `_play_card` seats each card in the row; adding it to the box as well
	# asked a parented node for a second parent.
	_road_row = null
	# **And the choice can be refused** (owner: *"unable to abort the card
	# upgrade selected if players decide not to leave any of their cards
	# behind"*). Keeping the hand puts the draft back exactly as it was.
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_CENTER
	var keep := Button.new()
	keep.name = "KeepHand"
	keep.text = "KEEP MY HAND  ·  take nothing"
	keep.custom_minimum_size = Vector2(0.0, 46.0)
	keep.add_theme_font_size_override("font_size", 18)
	keep.tooltip_text = "Leave nothing behind and go back to the cards on the table."
	keep.pressed.connect(_keep_the_hand)
	_keep_hand_button = keep
	foot.add_child(keep)
	options_box.add_child(foot)
	_dress_options()
	panel.visible = true


## The refusal on the leave-one-behind table, while that table is the one
## showing. Escape presses it (`close_top_layer`).
var _keep_hand_button: Button = null


## **What Escape may close here, topmost first** (owner, 2026-10-01: *"Pressing
## Esc while any menu is open should close the highest layer menu first each
## time it's pressed"*). Only what can be refused without deciding anything:
## the leave-one-behind table goes back to the cards, a Banish armed by mistake
## is disarmed, and the draft is put off - **Later**, which banks it exactly as
## the button does. A fork, a relic, a portent and the pass home are decisions
## the road is waiting on, so Escape leaves them alone and the run pauses
## instead. Returns whether anything closed.
func close_top_layer() -> bool:
	if not is_open():
		return false
	if is_instance_valid(_keep_hand_button) \
			and _keep_hand_button.is_inside_tree() \
			and not _keep_hand_button.is_queued_for_deletion():
		_keep_the_hand()
		return true
	if not _augment_open:
		return false
	if _banishing:
		_arm_banish()
		return true
	close_augment_draft()
	return true


## Refuses the drop: the take is forgotten and the table is laid again.
func _keep_the_hand() -> void:
	_pending_take = ""
	if _augment_open:
		open_augment_draft()
	else:
		open_road_card_choice()


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


# --- Augments -------------------------------------------------------------------------------

## What each source is called on the table, by `Augments.SOURCE_*`.
const AUGMENT_TITLES: Dictionary = {
	"rank": "ROAD RANK %s",
	"boss": "THE BOSS'S SPOILS",
	"camp": "WHAT THE CAMP HELD",
	"raid": "WHAT THE RAID BROUGHT BACK",
	"rift": "WHAT THE RIFT GAVE UP",
	"mythic": "WHAT THE LEGEND LEFT",
	"tempering": "TEMPERING",
}
const BRANCH_WORD: Array[String] = ["Warden", "Rampart", "Hearth"]

## **What a weapon card says** (the Arsenal, 2026-09-27): not a number on a table
## but what it does - how it kills and where it stands, what it hits for in this
## Warden's hands at this act, how many it throws, and how often. Each moves
## `from` -> `to` when the card is taken again, so a level is a visible change.
## By `ArsenalWeaponData.Pattern` and `Anchor`, appended as those are.
const WEAPON_SHAPE: Array[String] = ["Orbit", "Seeker", "Chain", "Pulse", "Trail",
	"Strike", "On a kill", "Arc", "Ward", "Mend", "Retort", "Guard", "Field"]
const WEAPON_PLACE: Array[String] = ["at your side", "on every tower", "at the town"]
const WEAPON_UNIT: Array[String] = ["orbs", "bolts", "jumps", "", "", "falls", "spirits",
	"arcs", "", "", "", "stones", ""]


static func weapon_rows(card: RoadCardData, from: int, to: int) -> Array:
	var weapon: ArsenalWeaponData = card.weapon_data()
	if weapon == null:
		return []
	var shape: String = WEAPON_SHAPE[clampi(int(weapon.pattern), 0, WEAPON_SHAPE.size() - 1)]
	var place: String = WEAPON_PLACE[clampi(int(weapon.anchor), 0, WEAPON_PLACE.size() - 1)]
	var rows: Array = [[shape, place]]
	# **A defence says its share, never a hit** (docs/ARSENAL_DEFENSIVE_2026-09-28.md):
	# a ward as a share of the pool, a mend of what is missing, a field its slow.
	match weapon.pattern:
		ArsenalWeaponData.Pattern.WARD:
			rows.append(["Ward", _share_text(weapon, from, to, "of health")])
		ArsenalWeaponData.Pattern.MEND:
			rows.append(["Mends", _share_text(weapon, from, to, "of what is missing")])
		ArsenalWeaponData.Pattern.FIELD:
			rows.append(["Slows", "%d%%" % int(round((1.0 - weapon.slow) * 100.0))])
		ArsenalWeaponData.Pattern.GUARD:
			if weapon.damage > 0.0:
				rows.append(["Throws back", "%d" % int(round(Arsenal.preview_hit(weapon, to)))])
		_:
			var hit_from: float = Arsenal.preview_hit(weapon, from)
			var hit_to: float = Arsenal.preview_hit(weapon, to)
			rows.append(["Hit", ("%d" % int(round(hit_to))) if from == to
				else ("%d → %d" % [int(round(hit_from)), int(round(hit_to))])])
	var unit: String = WEAPON_UNIT[clampi(int(weapon.pattern), 0, WEAPON_UNIT.size() - 1)]
	if not unit.is_empty():
		var many_from: int = weapon.count_at(from)
		var many_to: int = weapon.count_at(to)
		rows.append([unit.capitalize(), ("%d" % many_to) if many_from == many_to
			else ("%d → %d" % [many_from, many_to])])
	if weapon.every_kills > 0:
		rows.append(["Every", "%d kills" % weapon.every_kills])
	elif weapon.pattern == ArsenalWeaponData.Pattern.RETORT:
		rows.append(["When struck", "once in %.1f s" % weapon.cooldown])
	elif weapon.pattern == ArsenalWeaponData.Pattern.GUARD:
		rows.append(["A stone reforms", "every %.0f s" % weapon.cooldown])
	elif weapon.pattern != ArsenalWeaponData.Pattern.ON_KILL \
			and weapon.pattern != ArsenalWeaponData.Pattern.FIELD:
		rows.append(["Every", "%.1f s" % weapon.cooldown])
	if not card.evolves_from.is_empty():
		var base: RoadCardData = ContentDB.road_card(card.evolves_from)
		rows.append(["Evolves", base.display_name if base != null else card.evolves_from])
	return rows


static func _share_text(weapon: ArsenalWeaponData, from: int, to: int, of: String) -> String:
	var pct_from: int = int(round(weapon.share_at(from) * 100.0))
	var pct_to: int = int(round(weapon.share_at(to) * 100.0))
	if pct_from == pct_to:
		return "%d%% %s" % [pct_to, of]
	return "%d%% → %d%% %s" % [pct_from, pct_to, of]


## **Opens the oldest banked augment draft**, dealing it if it has not been.
## Returns whether a draft is on the table; with none waiting the panel closes.
func open_augment_draft() -> bool:
	if not RunState.deal_next_augment():
		close_augment_draft()
		return false
	_road_row = null
	_relic_followup_segment = -1
	_buttons.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	_pending_take = ""
	_augment_open = true
	for child: Node in options_box.get_children():
		child.queue_free()
	var tempering: bool = RunState.augment_offer_source == Augments.SOURCE_TEMPERING
	var heading: String = String(AUGMENT_TITLES.get(RunState.augment_offer_source,
		"AN AUGMENT"))
	if heading.contains("%s"):
		heading = heading % RunState.act_numeral(RunState.road_rank)
	var waiting: int = RunState.augments_waiting()
	var more: String = "" if waiting <= 1 else "  ·  %d more waiting" % (waiting - 1)
	if _banishing:
		title.text = "%s  ·  choose a card to banish for this road" % heading
	elif tempering:
		title.text = "%s  ·  one card grows%s" % [heading, more]
	else:
		title.text = "%s  ·  keep one%s" % [heading, more]
	options_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_road_row = _card_row()
	_road_row.add_theme_constant_override("separation", 22)
	_road_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	options_box.add_child(_road_row)
	for card_id: String in RunState.augment_offer:
		var card: RoadCardData = ContentDB.road_card(card_id)
		if card == null:
			continue
		_play_card(card.id, card.display_name, int(card.rarity),
			card.get_sprite_path(), augment_rows(card), card.card_text,
			_choose_augment.bind(card.id))
	_road_row = null
	options_box.add_child(_augment_tools(tempering))
	_dress_options()
	panel.visible = true
	return true


## **A guest's draft is the host's to change** (per-Warden hands, 2026-09-26):
## a choice is asked, the screen holds still, and the host's answer - the seat
## told whole, a refusal included - redraws it or closes it.
func _waits_on_the_host() -> bool:
	return Coop.is_guest() and RunState.hands_split


func _on_augment_offer_changed() -> void:
	if not _waits_on_the_host() or not _augment_open:
		return
	_resolving = false
	open_augment_draft.call_deferred()


## Closes the draft without taking anything from it. It stays banked.
func close_augment_draft() -> void:
	var was: bool = _augment_open
	_augment_open = false
	_banishing = false
	if was:
		panel.visible = false
		augment_closed.emit()


func is_augment_open() -> bool:
	return _augment_open and is_open()


## **What a card does, at the level it would be taken at**, and what it costs
## the hand. Shared by the crossroad's draft and the augment draft, so a card
## cannot say one thing at a fork and another after a boss.
func augment_rows(card: RoadCardData) -> Array:
	var held: bool = RunState.holds_card(card.id)
	var now: int = RunState.card_level(card.id)
	var next: int = now + 1 if held else _inherited_level(card)
	var rows: Array = []
	if card.is_weapon():
		rows = weapon_rows(card, now if held else next, next)
	else:
		var figure: String = effect_figure(card.effect_id, card.magnitude_at(next))
		if held:
			figure = "%s → %s" % [effect_figure(card.effect_id, card.magnitude_at(now)), figure]
		rows = [[effect_label(card.effect_id), figure]]
	if card.max_level() > 1:
		rows.append(["Level", ("%s → %s" % [RunState.act_numeral(now),
			RunState.act_numeral(next)]) if held else _level_word(card, next)])
	var branch_word: String = BRANCH_WORD[clampi(int(card.branch), 0, BRANCH_WORD.size() - 1)]
	rows.append(["Branch", ("%s keystone" % branch_word) if card.branch_needs > 0 else branch_word])
	var replaces: String = "" if held else _replacement_for(card)
	if not replaces.is_empty():
		rows.append(["Replaces", replaces])
	elif not held and RunState.hand_is_full_for(card):
		rows.append(["Hand", "full"])
	return rows


## "II of V" - a card's level against how far it can grow.
func _level_word(card: RoadCardData, level: int) -> String:
	if card.max_level() <= 1:
		return "Once"
	return "%s of %s" % [RunState.act_numeral(level), RunState.act_numeral(card.max_level())]


## The level a new card arrives at: a better card for a key already held keeps
## the levels the old one grew (`RunState.take_road_card`).
func _inherited_level(card: RoadCardData) -> int:
	for held: String in RunState.target_hand(card):
		var other: RoadCardData = ContentDB.road_card(held)
		if other != null and not other.keystone and not card.keystone \
				and other.key() == card.key():
			return clampi(RunState.card_level(held), 1, card.max_level())
	return 1


## Whether taking this card means choosing one to leave.
func _needs_a_drop(card: RoadCardData) -> bool:
	return not RunState.holds_card(card.id) and RunState.hand_is_full_for(card) \
		and _replacement_for(card).is_empty()


## Reroll, Banish, Skip and Later, under the cards.
func _augment_tools(tempering: bool) -> HBoxContainer:
	var tools := HBoxContainer.new()
	tools.alignment = BoxContainer.ALIGNMENT_CENTER
	tools.add_theme_constant_override("separation", 14)
	var reroll: Button = _tool_button("Reroll  ·  %d" % RunState.augment_rerolls,
		_reroll_augment)
	reroll.disabled = RunState.augment_rerolls <= 0
	reroll.tooltip_text = "Deal this draft again. Skipping a draft banks one."
	tools.add_child(reroll)
	var banish: Button = _tool_button("Banish  ·  %d" % RunState.augment_banishes,
		_arm_banish)
	banish.toggle_mode = true
	banish.button_pressed = _banishing
	banish.disabled = tempering or RunState.augment_banishes <= 0
	banish.tooltip_text = "Take a card out of the deck for the rest of this road, and deal its place again."
	tools.add_child(banish)
	var skip: Button = _tool_button("Skip  ·  +1 reroll", _skip_augment)
	skip.tooltip_text = "Pass on this draft and bank a reroll for a later one."
	tools.add_child(skip)
	# **What is left in the deck**, so a banish is a decision about something
	# countable and the rarer cards are known to still be in there.
	var deck: Label = _card_line("Deck  ·  %d" % Augments.candidates(RunState.hand_of(),
		RunState.levels_of(), RunState.act, RunState.augment_banished).size(),
		16, Color("9aa39e"), HORIZONTAL_ALIGNMENT_CENTER)
	deck.tooltip_text = "Cards this draft could still deal: the deck, less what is banished and what is already as good as it gets."
	deck.mouse_filter = Control.MOUSE_FILTER_PASS
	tools.add_child(deck)
	var later: Button = _tool_button("Later", close_augment_draft)
	later.tooltip_text = "Close the draft. It stays banked and opens again at the next breather."
	tools.add_child(later)
	return tools


func _tool_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 46.0)
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(on_press)
	return button


func _choose_augment(card_id: String) -> void:
	if _resolving or not _augment_open or not RunState.augment_offer.has(card_id):
		return
	if _banishing:
		_banishing = false
		if _waits_on_the_host():
			_resolving = RunState.banish_augment(card_id)
			return
		if not RunState.banish_augment(card_id):
			# Said rather than swallowed: a press that does nothing reads as a
			# card that cannot be banished for a reason the player has to guess.
			title.text = "%s  ·  nothing left to banish with" % title.text.get_slice("  ·  ", 0)
			return
		open_augment_draft()
		return
	var card: RoadCardData = ContentDB.road_card(card_id)
	if card == null:
		return
	if RunState.augment_offer_source != Augments.SOURCE_TEMPERING and _needs_a_drop(card):
		_pending_take = card_id
		_open_drop_choice(card, _take_augment)
		return
	_take_augment(card_id, "")


func _take_augment(card_id: String, drop: String) -> void:
	_pending_take = ""
	if _waits_on_the_host():
		_resolving = RunState.resolve_augment(card_id, drop)
		return
	if not RunState.resolve_augment(card_id, drop):
		open_augment_draft()
		return
	# Straight on to the next banked draft, if there is one.
	if RunState.augments_waiting() > 0:
		open_augment_draft()
	else:
		close_augment_draft()


func _reroll_augment() -> void:
	_banishing = false
	if _waits_on_the_host():
		_resolving = RunState.reroll_augment()
		return
	if RunState.reroll_augment():
		open_augment_draft()


func _arm_banish() -> void:
	_banishing = not _banishing
	open_augment_draft()


func _skip_augment() -> void:
	_banishing = false
	if _waits_on_the_host():
		_resolving = RunState.skip_augment()
		return
	RunState.skip_augment()
	if RunState.augments_waiting() > 0:
		open_augment_draft()
	else:
		close_augment_draft()


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
		button.modulate = Color.WHITE if String(id) == picked_id \
			else Color(1.0, 1.0, 1.0, 0.45)


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
	UiFonts.set_role(mark, UiFonts.Role.HEADING, 22)
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
