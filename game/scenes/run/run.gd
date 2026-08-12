class_name Run
extends Node

## Owns one run: the four scopes, the overlays, and the rules for moving
## between them (GDD §9).
##
## The battlefield is the only scope that keeps simulating while you are looking
## at something else — the town and the beast are windows onto a fight that is
## still happening. A raid and a crossroad both freeze it (GDD §6.3).

@export var battlefield: Battlefield
@export var town: TownScope
@export var beast: BeastScope
@export var raid: RaidArena
@export var journey: Journey
@export var war_horn: WarHorn
@export var boss_director: BossDirector
@export var hud: HUD
@export var crossroad_ui: CrossroadScreen
@export var results_ui: ResultsScreen
@export var pause_ui: PauseMenu
@export var town_panel: TownPanel

var _scope: GameDirector.Scope = GameDirector.Scope.BATTLEFIELD

## Set while a raid or crossroad has taken over, so scope switching is refused
## rather than silently leaving a frozen battlefield behind.
var _locked: bool = false


func _ready() -> void:
	MusicPlayer.follow_situation()
	raid.visible = false
	raid.process_mode = Node.PROCESS_MODE_DISABLED
	town.visible = false
	beast.visible = false

	EventBus.crossroad_reached.connect(_on_crossroad_reached)
	EventBus.act_boss_due.connect(_on_act_boss_due)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.raid_ended.connect(_on_raid_ended)
	EventBus.run_ended.connect(_on_run_ended)

	crossroad_ui.road_chosen.connect(_on_road_chosen)
	town.plot_selected.connect(town_panel.open)
	hud.scope_requested.connect(switch_scope)
	hud.horn_requested.connect(_on_horn_requested)
	hud.raid_requested.connect(_on_raid_requested)
	hud.extract_requested.connect(_on_extract_requested)

	boss_director.battlefield = battlefield
	journey.start()
	EventBus.run_started.emit()
	switch_scope(GameDirector.Scope.BATTLEFIELD)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		pause_ui.toggle()
		get_viewport().set_input_as_handled()
		return
	if _locked:
		return
	# Number keys jump between scopes; the whole point of the run layer is that
	# moving between them is cheap.
	if event.is_action_pressed(&"scope_battlefield"):
		switch_scope(GameDirector.Scope.BATTLEFIELD)
	elif event.is_action_pressed(&"scope_town"):
		switch_scope(GameDirector.Scope.TOWN)
	elif event.is_action_pressed(&"scope_beast"):
		switch_scope(GameDirector.Scope.BEAST)


func switch_scope(scope: GameDirector.Scope) -> void:
	if _locked or scope == _scope:
		return
	if scope == GameDirector.Scope.RAID:
		return  # Raids are entered through _on_raid_requested, never directly.

	_scope = scope
	GameDirector.current_scope = scope

	battlefield.visible = scope == GameDirector.Scope.BATTLEFIELD
	town.visible = scope == GameDirector.Scope.TOWN
	beast.visible = scope == GameDirector.Scope.BEAST

	# The battlefield keeps running while you are in the town or on the beast.
	# That is deliberate: leaving the fight to manage something has to cost.
	if scope != GameDirector.Scope.TOWN:
		town_panel.close()
	if scope == GameDirector.Scope.TOWN:
		town.refresh()
		town.activate()
	elif scope == GameDirector.Scope.BEAST:
		beast.activate()
	else:
		battlefield.activate()

	EventBus.scope_changed.emit(int(scope))


# --- War horn and raid ------------------------------------------------------

func _on_horn_requested() -> void:
	war_horn.blow()


func _on_raid_requested() -> void:
	if not war_horn.raid_available() or _locked:
		return
	_locked = true
	war_horn.consume_charge()

	# Frozen, not stopped: the wave resumes mid-flight exactly as it was.
	battlefield.suspend()
	journey.stop()
	town.visible = false
	beast.visible = false

	raid.visible = true
	raid.process_mode = Node.PROCESS_MODE_INHERIT
	raid.begin()
	raid.activate()

	_scope = GameDirector.Scope.RAID
	GameDirector.current_scope = _scope
	EventBus.scope_changed.emit(int(_scope))


func _on_extract_requested() -> void:
	raid.extract()


func _on_raid_ended(reward: Dictionary) -> void:
	_apply_raid_reward(reward)

	raid.visible = false
	raid.process_mode = Node.PROCESS_MODE_DISABLED

	battlefield.resume()
	journey.start()
	_locked = false
	_scope = GameDirector.Scope.RAID  # forces the switch below to take effect
	switch_scope(GameDirector.Scope.BATTLEFIELD)


func _apply_raid_reward(reward: Dictionary) -> void:
	RunState.gain_resources(int(reward.get("resources", 0)))

	var captive_id: String = String(reward.get("captive_id", ""))
	if not captive_id.is_empty() and ContentDB.captive(captive_id) != null:
		RunState.captives.append(captive_id)
		RunState.chieftains_taken += 1

	var relic_id: String = String(reward.get("relic_id", ""))
	if not relic_id.is_empty():
		RunState.held_relics.append(relic_id)


# --- Act bosses -------------------------------------------------------------

## The battlefield keeps running: the boss arrives *into* the fight, it does not
## replace it.
func _on_act_boss_due(act: int) -> void:
	boss_director.summon(act)


func _on_boss_defeated(_boss_id: String, act: int) -> void:
	if act >= Balance.ACT_COUNT:
		GameDirector.end_run(true)
		return
	journey.resume_after_boss()
	# A new act means new ground underfoot.
	battlefield.refresh_terrain()


# --- Crossroads -------------------------------------------------------------

func _on_crossroad_reached(segment_index: int) -> void:
	_locked = true
	battlefield.suspend()
	crossroad_ui.open(segment_index)


func _on_road_chosen(option_id: String) -> void:
	journey.resolve_crossroad(option_id)
	battlefield.resume()
	_locked = false
	_scope = GameDirector.Scope.CROSSROAD
	switch_scope(GameDirector.Scope.BATTLEFIELD)


# --- Ending -----------------------------------------------------------------

func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	_locked = true
	journey.stop()
	battlefield.suspend()
	raid.process_mode = Node.PROCESS_MODE_DISABLED
	results_ui.show_results(victory, summary)
