class_name TownPanel
extends CanvasLayer

## The town's management surface (GDD §5).
##
## Opens on whichever plot the player clicked. Everything it does goes through
## TownScope's static API, which is the part that was already tested — this
## script only draws what RunState says and offers the moves that are legal.
##
## One build slot at a time is enforced by the API, not here, so the panel can
## never disagree with the run about what is under construction.

@export var panel: PanelContainer
@export var title: Label
@export var body: Label
@export var actions: VBoxContainer
@export var progress: ProgressBar
@export var progress_label: Label
@export var close_button: Button

var _building_id: String = ""


func _ready() -> void:
	panel.visible = false
	close_button.pressed.connect(close)
	EventBus.construction_started.connect(func(_id: String, _t: int) -> void: _refresh())
	EventBus.construction_progress.connect(_on_progress)
	EventBus.construction_completed.connect(func(_id: String, _t: int) -> void: _refresh())
	EventBus.relic_socketed.connect(func(_id: String) -> void: _refresh())
	EventBus.relic_unsocketed.connect(func(_id: String) -> void: _refresh())
	EventBus.captive_assigned.connect(func(_c: String, _b: String) -> void: _refresh())
	EventBus.discipline_trained.connect(func(_id: String, _food: int) -> void: _refresh())
	EventBus.discipline_equipped.connect(func(_slot: int, _id: String) -> void: _refresh())
	EventBus.discipline_respecced.connect(func(_food: int, _uses: int) -> void: _refresh())


func open(building_id: String) -> void:
	_building_id = building_id
	panel.visible = true
	_refresh()


func close() -> void:
	panel.visible = false


func is_open() -> bool:
	return panel.visible


func _on_progress(building_id: String, ratio: float) -> void:
	if building_id != String(RunState.construction.get("id", "")):
		return
	progress.value = ratio
	progress_label.text = "%d%%" % int(ratio * 100.0)


## The level readout and the four attributes, with a button each.
##
## Placed on the Mansion beside discipline training rather than on its own
## screen: both are "what has the hero become this run", and splitting them puts
## the two halves of one decision in two places.
##
## Spendable outside Preparation on purpose. Training a discipline is a
## Preparation action because it changes the loadout and costs Food the defence
## also wants; placing a point you already earned is not a decision against the
## towers, and making a player wait to spend it turns a reward into a chore.
func _build_attributes() -> void:
	var title := Label.new()
	title.text = "LEVEL %d" % RunState.hero_level
	if RunState.hero_level < Balance.HERO_MAX_LEVEL:
		title.text += "  ·  %d%% to next" % int(RunState.hero_level_progress() * 100.0)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("e8a33d"))
	actions.add_child(title)

	var pools := Label.new()
	pools.text = "%d attribute point%s  ·  %d skill point%s  ·  %d of %d nodes trained" % [
		RunState.hero_attribute_points, "" if RunState.hero_attribute_points == 1 else "s",
		RunState.hero_skill_points, "" if RunState.hero_skill_points == 1 else "s",
		RunState.trained_discipline_nodes.size(), RunState.discipline_cap()]
	pools.add_theme_font_size_override("font_size", 13)
	pools.add_theme_color_override("font_color", Color("b8ae98"))
	actions.add_child(pools)

	const NAMES: Array[String] = ["Might", "Vigour", "Swiftness", "Focus"]
	const BLURBS: Array[String] = [
		"Damage on every swing.",
		"Maximum health.",
		"Movement and swing speed.",
		"Command generation and spell power.",
	]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for index: int in NAMES.size():
		var button := Button.new()
		button.text = "%s
%d" % [NAMES[index], RunState.attribute(index)]
		button.tooltip_text = BLURBS[index]
		button.custom_minimum_size = Vector2(0.0, 50.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 12)
		button.disabled = RunState.hero_attribute_points <= 0
		button.pressed.connect(func() -> void:
			var problem: String = RunState.spend_attribute_point(index)
			if not problem.is_empty():
				_note(problem)
			_refresh())
		row.add_child(button)
	actions.add_child(row)


func _refresh() -> void:
	for child: Node in actions.get_children():
		child.queue_free()

	var data: BuildingData = ContentDB.building(_building_id)
	if data == null:
		title.text = "—"
		body.text = ""
		return

	var tier: int = RunState.building_tier(_building_id)
	title.text = "%s   ·   %s" % [
		data.display_name,
		"Tier %d" % tier if tier > 0 else "Not built",
	]

	var lines: PackedStringArray = [data.description]
	if tier > 0:
		lines.append("Now: %s" % _effect_text(data, tier))
	if tier < data.max_tier:
		lines.append("Next: %s" % _effect_text(data, tier + 1))
	body.text = "\n".join(lines)

	_show_construction(data, tier)

	# Buildings that do something beyond a tier number get their own controls.
	match data.effect:
		BuildingData.Effect.RELIC_SLOTS:
			_show_relics()
		BuildingData.Effect.CAPTIVE_LABOUR:
			_show_captives()
		BuildingData.Effect.MARKET:
			_show_market()
		BuildingData.Effect.HERO_UPGRADE:
			_show_disciplines()
		_:
			pass


func _show_construction(data: BuildingData, tier: int) -> void:
	var busy_with: String = String(RunState.construction.get("id", ""))
	var building_this: bool = busy_with == _building_id

	progress.visible = building_this
	progress_label.visible = building_this
	if building_this:
		var done: float = float(RunState.construction.get("distance_done", 0.0))
		var needed: float = maxf(float(RunState.construction.get("distance_needed", 1.0)), 1.0)
		progress.value = done / needed
		progress_label.text = "%d of %d distance" % [int(done), int(needed)]
		return
	if not RunState.can_build_now():
		_note("Read only during battle. Return in Preparation to make changes.")
		return

	if tier >= data.max_tier:
		_note("Fully built.")
		return

	var distance_cost: float = BuildingData.tier_cost(tier + 1)
	var wood_cost: int = data.wood_cost_at(tier + 1)
	var button := Button.new()
	button.text = "Build tier %d   ·   %d Wood   ·   %d distance" % [
		tier + 1, wood_cost, int(distance_cost)]
	button.custom_minimum_size = Vector2(0, 44)
	button.disabled = not busy_with.is_empty() \
		or not RunState.can_afford_cost({RunState.WOOD: wood_cost}) \
		or not MetaState.building_unlocked(data.id)
	button.pressed.connect(func() -> void:
		var problem: String = TownScope.try_start_construction(_building_id)
		if not problem.is_empty():
			_note(problem)
		_refresh())
	actions.add_child(button)

	if not busy_with.is_empty():
		var other: BuildingData = ContentDB.building(busy_with)
		_note("Already building %s. One at a time." % (other.display_name if other != null else busy_with))
	elif not MetaState.building_unlocked(data.id):
		_note("Unlock this plot through its account milestone; it will still begin unbuilt each run.")


func _show_market() -> void:
	if RunState.building_tier("market") <= 0:
		return
	_note("Exchanges left this Preparation: %d   ·   %d given → %d received" % [
		RunState.market_trades_remaining, Balance.MARKET_TRADE_LOT,
		Balance.MARKET_TRADE_RETURN])
	if not RunState.can_build_now():
		return
	for pair: Array in [[RunState.WOOD, RunState.GOLD], [RunState.FOOD, RunState.GOLD],
			[RunState.GOLD, RunState.STONE], [RunState.STONE, RunState.WOOD]]:
		var from_id: String = pair[0]
		var to_id: String = pair[1]
		var trade := Button.new()
		trade.text = "%d %s  →  %d %s" % [Balance.MARKET_TRADE_LOT,
			RunState.currency_name(from_id), Balance.MARKET_TRADE_RETURN,
			RunState.currency_name(to_id)]
		trade.custom_minimum_size = Vector2(0, 38)
		trade.disabled = RunState.market_trades_remaining <= 0 \
			or not RunState.can_afford_cost({from_id: Balance.MARKET_TRADE_LOT})
		trade.pressed.connect(func() -> void:
			var problem: String = TownScope.try_market_trade(from_id, to_id)
			if not problem.is_empty():
				_note(problem)
			_refresh())
		actions.add_child(trade)
	var service := Button.new()
	service.text = "ACT %d CONTRACT" % RunState.act
	service.custom_minimum_size = Vector2(0, 42)
	service.tooltip_text = "One rotating bounded service per act. Never a free conversion loop."
	service.disabled = RunState.market_service_bought_this_act()
	service.pressed.connect(func() -> void:
		var problem: String = TownScope.try_market_service()
		if not problem.is_empty():
			_note(problem)
		_refresh())
	actions.add_child(service)


func _show_disciplines() -> void:
	var tier: int = RunState.building_tier("sanctum")
	if tier <= 0:
		_note("Build the Hero Mansion to reveal discipline training.")
		return
	_note("Trained %d / %d  ·  Food pays for training  ·  mix disciplines freely" % [
		RunState.trained_discipline_nodes.size(), Balance.DISCIPLINE_MAX_TRAINED])

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 5)
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var equipped: DisciplineNodeData = RunState.discipline_node_in_slot(slot)
		var slot_name: String = ["ATTACK", "DEFENSE", "POWER", "ULTIMATE"][slot]
		var unlocked: bool = slot < 2 or RunState.act >= slot
		var slot_button := Button.new()
		slot_button.custom_minimum_size = Vector2(92.0, 48.0)
		slot_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_button.text = "%s\n%s" % [slot_name,
			equipped.display_name if equipped != null else ("EMPTY" if unlocked else "LOCKED")]
		slot_button.add_theme_font_size_override("font_size", 10)
		slot_button.disabled = true
		if equipped != null and ResourceLoader.exists(equipped.get_sprite_path()):
			slot_button.icon = load(equipped.get_sprite_path())
			slot_button.icon_max_width = 30
		slot_row.add_child(slot_button)
	actions.add_child(slot_row)

	_build_attributes()

	var offer_title := Label.new()
	offer_title.text = "ROAD OFFERS"
	offer_title.add_theme_font_size_override("font_size", 16)
	offer_title.add_theme_color_override("font_color", Color("e8a33d"))
	actions.add_child(offer_title)
	if RunState.discipline_offers.is_empty():
		RunState.refresh_discipline_offers()
	for id: String in RunState.discipline_offers:
		var offered: DisciplineNodeData = ContentDB.discipline_node(id)
		if offered == null:
			continue
		var card := Button.new()
		card.text = "%s  ·  %s  ·  %d Food" % [
			offered.display_name, offered.slot_name(), offered.food_cost]
		card.custom_minimum_size = Vector2(0.0, 54.0)
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.tooltip_text = "%s discipline  ·  Mansion tier %d\n%s" % [
			offered.discipline_name(), offered.mansion_tier, offered.description]
		if ResourceLoader.exists(offered.get_sprite_path()):
			card.icon = load(offered.get_sprite_path())
			card.icon_max_width = 38
		card.disabled = not RunState.is_preparation() \
			or RunState.trained_discipline_nodes.size() >= Balance.DISCIPLINE_MAX_TRAINED \
			or not RunState.can_afford_cost({RunState.FOOD: offered.food_cost})
		card.pressed.connect(func() -> void:
			var problem: String = RunState.try_train_discipline(id)
			if not problem.is_empty():
				_note(problem)
			_refresh())
		actions.add_child(card)

	if not RunState.trained_discipline_nodes.is_empty():
		var trained_title := Label.new()
		trained_title.text = "TRAINED LOADOUT"
		trained_title.add_theme_font_size_override("font_size", 16)
		trained_title.add_theme_color_override("font_color", Color("b8ae98"))
		actions.add_child(trained_title)
	for id: String in RunState.trained_discipline_nodes:
		var trained: DisciplineNodeData = ContentDB.discipline_node(id)
		if trained == null:
			continue
		var row := Button.new()
		row.text = "%s  ·  %s%s" % [trained.display_name, trained.slot_name(),
			"  ·  EQUIPPED" if RunState.equipped_discipline_slots.has(id) else ""]
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.custom_minimum_size = Vector2(0.0, 44.0)
		row.tooltip_text = trained.description
		if ResourceLoader.exists(trained.get_sprite_path()):
			row.icon = load(trained.get_sprite_path())
			row.icon_max_width = 30
		row.disabled = not RunState.is_preparation() or not trained.is_active_slot() \
			or not trained.is_slot_unlocked(RunState.act) \
			or RunState.equipped_discipline_slots.has(id)
		row.pressed.connect(func() -> void:
			var problem: String = RunState.try_equip_discipline(id)
			if not problem.is_empty():
				_note(problem)
			_refresh())
		actions.add_child(row)

	var respec := Button.new()
	respec.text = "Respec disciplines  ·  %d Food" % RunState.discipline_respec_cost()
	respec.custom_minimum_size = Vector2(0.0, 46.0)
	respec.tooltip_text = "Return to the curated Attack and Defense starters. Cost rises each use."
	respec.disabled = not RunState.is_preparation() \
		or not RunState.can_afford_cost({RunState.FOOD: RunState.discipline_respec_cost()})
	respec.pressed.connect(func() -> void:
		var problem: String = RunState.try_respec_disciplines()
		if not problem.is_empty():
			_note(problem)
		_refresh())
	actions.add_child(respec)


## Relic sockets. Only socketed relics do anything at all, which is the entire
## reason the Town Hall exists.
func _show_relics() -> void:
	var used: int = RunState.socketed_relics.size()
	var total: int = RunState.relic_slot_count()
	_note("Sockets  %d / %d" % [used, total])

	for relic_id: String in RunState.socketed_relics:
		var relic: RelicData = ContentDB.relics.get(relic_id, null) as RelicData
		if relic == null:
			continue
		var row := Button.new()
		row.text = "◆ %s   —   remove" % relic.display_name
		row.tooltip_text = relic.description
		row.disabled = not RunState.can_build_now()
		row.pressed.connect(func() -> void:
			TownScope.unsocket_relic(relic_id)
			_refresh())
		actions.add_child(row)

	for relic_id: String in RunState.held_relics:
		var relic: RelicData = ContentDB.relics.get(relic_id, null) as RelicData
		if relic == null:
			continue
		var row := Button.new()
		row.text = "◇ %s   —   socket" % relic.display_name
		row.tooltip_text = relic.description
		row.disabled = used >= total or not RunState.can_build_now()
		row.pressed.connect(func() -> void:
			var problem: String = TownScope.try_socket_relic(relic_id)
			if not problem.is_empty():
				_note(problem)
			_refresh())
		actions.add_child(row)

	if RunState.socketed_relics.is_empty() and RunState.held_relics.is_empty():
		_note("No relics yet. Take one from a war camp.")

	for core_id: String in RunState.boss_cores:
		var core: RelicData = ContentDB.relics.get(core_id, null) as RelicData
		if core != null:
			_note("★ %s  —  always active" % core.display_name)


## Oathbound leaders won from war camps and assigned a one-run duty. Internal
## save names remain compatible with v3; no captivity framing reaches players.
func _show_captives() -> void:
	var here: int = 0
	for value: Variant in RunState.captive_assignments.values():
		if String(value) == _building_id:
			here += 1
	_note("Assigned  %d / %d" % [here, Balance.CAPTIVES_PER_BUILDING])
	if not RunState.can_build_now():
		_note("Read only during battle.")
		return

	if RunState.captives.is_empty():
		_note("No Oathbound leader yet. Complete a raid.")
		return

	for captive_id: String in RunState.captives:
		var captive: CaptiveData = ContentDB.captive(captive_id)
		if captive == null:
			continue
		var assigned_to: String = String(RunState.captive_assignments.get(captive_id, ""))
		var row := Button.new()
		if assigned_to == _building_id:
			row.text = "%s   —   working here" % captive.display_name
			row.disabled = true
		else:
			# The verb is data, not a string literal: the framing of this system
			# is explicitly unsettled (GDD §6.3).
			row.text = "%s %s" % [captive.acquire_verb, captive.display_name]
			row.pressed.connect(func() -> void:
				var problem: String = TownScope.try_assign_captive(captive_id, _building_id)
				if not problem.is_empty():
					_note(problem)
				_refresh())
		actions.add_child(row)


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("b8ae98"))
	actions.add_child(label)


func _effect_text(data: BuildingData, tier: int) -> String:
	var amount: float = data.effect_at(tier)
	match data.effect:
		BuildingData.Effect.RELIC_SLOTS:
			var slots: int = int(amount)
			return "%d relic socket%s" % [slots, "" if slots == 1 else "s"]
		BuildingData.Effect.RESOURCE_RATE:
			return "+%d%% resources from walking" % int(amount * 100.0)
		BuildingData.Effect.HERO_UPGRADE:
			return "+%d%% hero health, speed and cooldowns" % int(amount * 100.0)
		BuildingData.Effect.CAPTIVE_LABOUR:
			var details: int = int(amount)
			return "%d work detail%s" % [details, "" if details == 1 else "s"]
		BuildingData.Effect.BLUEPRINTS:
			return "tower mastery level %d unlocked" % clampi(
				Balance.TOWER_BASE_LEVEL_CAP + tier, 1, Balance.TOWER_MAX_LEVEL)
		BuildingData.Effect.WAVE_FORESIGHT:
			match tier:
				1:
					return "formation lanes and road threat values revealed"
				2:
					return "wave scale, intent and road reward depth revealed"
				_:
					return "signature threats and exact road rewards revealed"
		BuildingData.Effect.PRODUCTION:
			return "%.2f %s per distance" % [amount, RunState.currency_name(data.produced_currency)]
		BuildingData.Effect.TREASURY_CACHE:
			return "up to %d of each currency cached for the next run" % int(amount)
		BuildingData.Effect.MARKET:
			return "%d bounded exchanges per Preparation" % Balance.MARKET_TRADES_PER_PREPARATION
		_:
			return "%.2f" % amount
