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

	if tier >= data.max_tier:
		_note("Fully built.")
		return

	var cost: float = BuildingData.tier_cost(tier + 1)
	var button := Button.new()
	button.text = "Build tier %d   ·   %d distance" % [tier + 1, int(cost)]
	button.custom_minimum_size = Vector2(0, 44)
	button.disabled = not busy_with.is_empty()
	button.pressed.connect(func() -> void:
		var problem: String = TownScope.try_start_construction(_building_id)
		if not problem.is_empty():
			_note(problem)
		_refresh())
	actions.add_child(button)

	if not busy_with.is_empty():
		var other: BuildingData = ContentDB.building(busy_with)
		_note("Already building %s. One at a time." % (other.display_name if other != null else busy_with))


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
		row.disabled = used >= total
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
			var plans: int = int(amount)
			return "%d tower blueprint%s" % [plans, "" if plans == 1 else "s"]
		BuildingData.Effect.WAVE_FORESIGHT:
			return "next wave revealed"
		_:
			return "%.2f" % amount
