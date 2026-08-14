class_name CrossroadScreen
extends CanvasLayer

## The choice at a segment boundary (GDD §8). Combat is frozen behind this.
##
## Two cards are drawn from five authored road promises. Each also carries an
## independent danger/reward tier, so the player compares both destination and
## commitment rather than choosing among three hardcoded legacy buttons.

signal road_chosen(option_id: String)
signal relic_chosen(relic_id: String)

@export var panel: Control
@export var title: Label
@export var options_box: VBoxContainer

## Width of an option card. Wide enough that no description wraps to three lines,
## which is what makes three cards different heights and the column look broken.
const CARD_WIDTH: float = 700.0

## Matches the theme's button text inset, so a description lines up under the
## name it belongs to instead of starting somewhere near it.
const TEXT_INDENT: int = 34

var _rng := RandomNumberGenerator.new()
var _relic_followup_segment: int = -1
var _open_segment: int = 0


func _ready() -> void:
	_rng = RunState.rng("roads")
	panel.visible = false


func open(segment_index: int) -> void:
	if not RunState.pending_road_relics.is_empty():
		open_relic_reward(segment_index)
		return
	_open_roads(segment_index)


func _open_roads(segment_index: int) -> void:
	_open_segment = segment_index
	for child: Node in options_box.get_children():
		child.queue_free()

	title.text = "Crossroad  ·  segment %d of %d" % [
		segment_index, int(Balance.JOURNEY_TOTAL_DISTANCE / Balance.SEGMENT_DISTANCE)]

	for offer: Dictionary in draw_offers(segment_index):
		_add_option(offer["road"] as RoadData, offer["difficulty"] as RoadDifficultyData)

	panel.visible = true


## Public test/replay seam: cards and diagnostics use the same authored draw,
## so seed validation never has to reimplement crossroad randomness.
func draw_offers(segment_index: int) -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	var pool: Array[RoadData] = ContentDB.roads_sorted()
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
	_relic_followup_segment = followup_segment
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
			button.icon = load(path)
			button.expand_icon = true
			button.icon_max_width = 44
		button.tooltip_text = "%s\n%s" % [relic.display_name, relic.description]
		button.pressed.connect(_choose_relic.bind(relic.id))
		options_box.add_child(button)
	panel.visible = true


func _choose_relic(relic_id: String) -> void:
	if not RunState.pending_road_relics.has(relic_id):
		return
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

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var button := Button.new()
	button.text = "%s  ·  %s" % [difficulty.display_name.to_upper(), road.display_name]
	button.custom_minimum_size = Vector2(0.0, 54.0)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", difficulty.card_colour)
	IconKit.on_button(button, road.icon_id, 26)
	button.pressed.connect(func() -> void: _choose(road.id, difficulty.id))
	box.add_child(button)

	var text := Label.new()
	text.text = "%s\n%s\n%s" % [road.promise, road.consequence,
		_exact_consequences(road, difficulty)]
	text.add_theme_font_size_override("font_size", 16)
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
func _choose(road_id: String, difficulty_id: String) -> void:
	RunState.active_road_id = road_id
	RunState.active_road_difficulty_id = difficulty_id
	RunState.record_road_choice(_open_segment, road_id, difficulty_id)
	panel.visible = false
	road_chosen.emit(road_id)
