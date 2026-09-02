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
	_pointer.position = at * get_viewport().get_visible_rect().size 		- _pointer.size * 0.5


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
	_add_reroll()
	panel.visible = true


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
	_road_row = null
	_relic_followup_segment = followup_segment
	_buttons.clear()
	_sent_pointer = Vector2.ZERO
	_resolving = false
	for child: Node in options_box.get_children():
		child.queue_free()
	title.text = "RELIC HUNT COMPLETE  ·  choose one Rimebound treasure" \
		if RunState.act == 3 else "RELIC HUNT COMPLETE  ·  choose one regional treasure"
	for relic_id: String in RunState.pending_road_relics:
		var relic: RelicData = ContentDB.relic(relic_id)
		if relic == null:
			continue
		var button := Button.new()
		button.text = "%s\n%s" % [relic.display_name.to_upper(), relic.description]
		button.custom_minimum_size = Vector2(CARD_WIDTH, 68.0)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var path: String = relic.get_sprite_path()
		if ResourceLoader.exists(path):
			UiMetrics.row_icon(button, load(path), 44)
		button.tooltip_text = "%s\n%s" % [relic.display_name, relic.description]
		button.pressed.connect(_choose_relic.bind(relic.id))
		_buttons[relic.id] = button
		options_box.add_child(button)
	panel.visible = true


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
	# The host votes like everybody else rather than deciding by clicking.
	cast_vote(HOST_VOTER, road_id, difficulty_id)
	_await_answer(road_id)


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
	fade.tween_property(mark, "position", mark.position - Vector2(0.0, 34.0), 0.9)		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
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
