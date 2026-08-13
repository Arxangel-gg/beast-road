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


## Captives taken from war-camp chieftains, put to work.
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
		_note("Nobody taken yet. Finish a raid.")
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
			return "next wave revealed"
		BuildingData.Effect.PRODUCTION:
			return "%.2f %s per distance" % [amount, RunState.currency_name(data.produced_currency)]
		BuildingData.Effect.TREASURY_CACHE:
			return "up to %d of each currency cached for the next run" % int(amount)
		BuildingData.Effect.MARKET:
			return "%d bounded exchanges per Preparation" % Balance.MARKET_TRADES_PER_PREPARATION
		_:
			return "%.2f" % amount
