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
@export var command_system: Node
@export var hud: HUD
@export var crossroad_ui: CrossroadScreen
@export var results_ui: ResultsScreen
@export var pause_ui: PauseMenu
@export var town_panel: TownPanel

var _scope: GameDirector.Scope = GameDirector.Scope.BATTLEFIELD

## Set while a raid or crossroad has taken over, so scope switching is refused
## rather than silently leaving a frozen battlefield behind.
var _locked: bool = false
var _preparation_left: float = 0.0
var _coverage_warning_acknowledged: bool = false
var _pending_boss_act: int = 0


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
	EventBus.wave_cleared.connect(_on_wave_cleared)

	crossroad_ui.road_chosen.connect(_on_road_chosen)
	crossroad_ui.relic_chosen.connect(_on_road_relic_chosen)
	town.plot_selected.connect(town_panel.open)
	hud.scope_requested.connect(switch_scope)
	hud.horn_requested.connect(_on_horn_requested)
	hud.raid_requested.connect(_on_raid_requested)
	hud.extract_requested.connect(_on_extract_requested)
	hud.ride_on_requested.connect(_on_ride_on_requested)
	hud.command_requested.connect(_on_command_requested)

	boss_director.battlefield = battlefield
	command_system.battlefield = battlefield

	# Claim the starting scope explicitly.
	#
	# `_scope` is already BATTLEFIELD, so switch_scope(BATTLEFIELD) early-returns
	# and `battlefield.activate()` never runs at start-up. Activation is what puts
	# the hero into the "hero" group — Hero._ready() deliberately leaves it, because
	# there are two Hero instances (battlefield and raid) and whichever scope is
	# live has to claim its own.
	#
	# So until the player switched to the town and back, *nothing at all* was in
	# that group, and everything keyed on it silently did nothing: torch relighting,
	# the see-through fade on towers and the town, and two Vfx hooks. Each of those
	# reads `get_first_node_in_group("hero")` and quietly returns on null, so there
	# was no error anywhere — just four features that were never once observed
	# working.
	battlefield.activate()

	EventBus.run_started.emit()
	switch_scope(GameDirector.Scope.BATTLEFIELD)
	_enter_preparation(true)


func _process(delta: float) -> void:
	if not RunState.is_preparation() or _preparation_left <= 0.0:
		return
	_preparation_left = maxf(_preparation_left - delta, 0.0)
	# The counter is a reward window, never an auto-start. Once it reaches zero
	# the formation remains safely paused until the player chooses Ride On.
	EventBus.preparation_changed.emit(_preparation_left, true)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		pause_ui.toggle()
		get_viewport().set_input_as_handled()
		return
	if _locked:
		return
	if event is InputEventMouseButton and event.pressed:
		var wheel := event as InputEventMouseButton
		if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_ladder(1)
			get_viewport().set_input_as_handled()
			return
		if wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_ladder(-1)
			get_viewport().set_input_as_handled()
			return
	# Number keys jump between scopes; the whole point of the run layer is that
	# moving between them is cheap.
	if event.is_action_pressed(&"scope_battlefield"):
		switch_scope(GameDirector.Scope.BATTLEFIELD)
	elif event.is_action_pressed(&"scope_town"):
		switch_scope(GameDirector.Scope.TOWN)
	elif event.is_action_pressed(&"scope_beast"):
		switch_scope(GameDirector.Scope.BEAST)


## Wheel-in moves toward tactical detail; wheel-out moves toward the whole
## journey. Battlefield consumes steps internally until its wide limit, then
## the next detent crosses to Town and the following one to Beast.
func _zoom_ladder(direction: int) -> void:
	match _scope:
		GameDirector.Scope.BATTLEFIELD:
			var rig := battlefield.camera as CameraRig
			if direction > 0:
				if rig != null:
					rig.zoom_by(1)
			elif rig == null or not rig.zoom_by(-1):
				switch_scope(GameDirector.Scope.TOWN)
		GameDirector.Scope.TOWN:
			if direction > 0:
				switch_scope(GameDirector.Scope.BATTLEFIELD)
				var rig := battlefield.camera as CameraRig
				if rig != null:
					rig.reset_to_wide()
			else:
				switch_scope(GameDirector.Scope.BEAST)
		GameDirector.Scope.BEAST:
			if direction > 0:
				beast.set_zoomed_out(false)
				switch_scope(GameDirector.Scope.TOWN)


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
	if RunState.phase == RunState.Phase.ROAD_BATTLE:
		war_horn.blow()


func _on_raid_requested() -> void:
	if not RunState.is_command_combat() or not war_horn.raid_available() or _locked:
		return
	if battlefield.hero == null or not battlefield.hero.is_alive():
		return
	_locked = true
	RunState.set_phase(RunState.Phase.RAID)
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

	if battlefield.hero != null:
		if bool(reward.get("died", false)):
			# A raid down ejects immediately with its new Wound rather than making
			# the player wait for the battlefield hero's normal down timer.
			battlefield.hero.apply_raid_wound()
		else:
			battlefield.hero.sync_from_run_state()
	battlefield.resume()
	journey.start()
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_locked = false
	_scope = GameDirector.Scope.RAID  # forces the switch below to take effect
	switch_scope(GameDirector.Scope.BATTLEFIELD)


func _apply_raid_reward(reward: Dictionary) -> void:
	var value: int = int(reward.get("resources", 0))
	RunState.gain_currency(RunState.GOLD, int(round(value * 0.55)))
	RunState.gain_currency(RunState.FOOD, int(round(value * 0.30)))
	RunState.gain_currency(RunState.STONE, int(round(value * 0.15)))

	var captive_id: String = String(reward.get("captive_id", ""))
	if not captive_id.is_empty() and ContentDB.captive(captive_id) != null:
		RunState.captives.append(captive_id)
		RunState.chieftains_taken += 1

	var relic_id: String = String(reward.get("relic_id", ""))
	if not relic_id.is_empty():
		RunState.held_relics.append(relic_id)

	# The Draught is a carried item rather than a currency (v4 §698), and holding
	# one is the whole of its state - the carry limit is one.
	var item_id: String = String(reward.get("item_id", ""))
	if item_id == "resurrection_draught" and not RunState.has_resurrection_draught:
		RunState.has_resurrection_draught = true
		var draught: ItemData = ContentDB.item(item_id)
		if draught != null:
			EventBus.preparation_warning.emit(draught.acquire_line)


# --- Act bosses -------------------------------------------------------------

## The boss threshold can arrive during a wave, but final Preparation waits for
## that complete formation to resolve before the boss replaces it.
func _on_act_boss_due(act: int) -> void:
	_pending_boss_act = act
	journey.stop()
	# A distance threshold can be crossed while a formation is still alive. Let
	# that wave resolve before opening Preparation; freezing enemies mid-attack
	# made the phase look like a broken wave overlap.
	#
	# Shares `_road_is_busy` with the crossroad, which had the same problem and
	# not this fix: the boss half was repaired and the fork half was left, so a
	# crossroad reached mid-wave still opened Preparation on a live pack. One
	# function now answers "is there still a fight here" for both.
	if _road_is_busy():
		EventBus.preparation_warning.emit(
			"The Act %d boss is ahead. Clear the road first." % act)
		return
	if not RunState.pending_road_relics.is_empty():
		_locked = true
		RunState.set_phase(RunState.Phase.PREPARATION)
		battlefield.suspend()
		crossroad_ui.open_relic_reward()
		return
	_begin_boss_preparation(act)


func _begin_boss_preparation(act: int) -> void:
	RunState.hearthmend()
	if battlefield.hero != null:
		battlefield.hero.apply_hearthmend()
	if battlefield.town != null and battlefield.town.health != null:
		battlefield.town.health.current_hp = RunState.town_hp
		battlefield.town.health.changed.emit(
			battlefield.town.health.current_hp, battlefield.town.health.max_hp)
	_enter_preparation(false)
	EventBus.preparation_warning.emit(
		"FINAL PREPARATION  ·  the Act %d boss waits beyond this road." % act)


func _on_boss_defeated(_boss_id: String, act: int) -> void:
	if act >= Balance.ACT_COUNT:
		RunState.set_phase(RunState.Phase.ENDED)
		GameDirector.end_run(true)
		return
	journey.resume_after_boss()
	# A new act means new ground underfoot.
	battlefield.refresh_terrain()
	_enter_preparation(false)


# --- Crossroads -------------------------------------------------------------

## A crossroad the beast has reached but cannot stop at yet, or -1.
##
## Crossroads fire on distance walked, which pays no attention to whether a
## formation is still on the road - so one routinely landed in the middle of a
## fight. The modal suspended the battlefield, the player chose a road, and then
## `_on_road_chosen` resumed the battlefield and opened Preparation on top of it:
## the surviving pack woke up and went back to eating the towers during the one
## phase that is supposed to be safe planning time.
##
## It was worse than it looked. `enter_preparation` documents its own precondition
## - "Preparation only starts after WaveDirector has proved its queue and living
## enemy count are empty" - and this was the one path that did not honour it, so
## `wave_director.stop()` froze the remaining spawn queue while the enemies
## already on the field kept attacking, and the wave could never close.
##
## The journey has already parked itself at the junction by this point, so there
## is nothing to lose by waiting: finish the fight, then choose the road.
var _pending_crossroad: int = -1


func _on_crossroad_reached(segment_index: int) -> void:
	if _road_is_busy():
		_pending_crossroad = segment_index
		EventBus.preparation_warning.emit(
			"The road forks ahead. Clear this formation and the beast will stop.")
		return
	_open_crossroad(segment_index)


func _open_crossroad(segment_index: int) -> void:
	_pending_crossroad = -1
	_locked = true
	# The modal is part of safe planning time, not combat telemetry.
	RunState.set_phase(RunState.Phase.PREPARATION)
	battlefield.suspend()
	crossroad_ui.open(segment_index)


## Anything still to fight: a pack on the field, or one still walking on.
## Both halves matter - counting only the living declares an empty road during
## the gap between two spawns.
func _road_is_busy() -> bool:
	if battlefield == null:
		return false
	if battlefield.wave_director != null and battlefield.wave_director.is_deploying():
		return true
	return battlefield.enemy_count() > 0


func _on_road_chosen(option_id: String) -> void:
	journey.resolve_crossroad(option_id)
	RunState.refresh_discipline_offers()
	battlefield.resume()
	_locked = false
	_scope = GameDirector.Scope.CROSSROAD
	switch_scope(GameDirector.Scope.BATTLEFIELD)
	_enter_preparation(false)


func _on_road_relic_chosen(_relic_id: String) -> void:
	# At a normal crossroad the same modal immediately reveals the road cards.
	# At an act boundary it hands control back to the already-pending boss gate.
	if _pending_boss_act <= 0:
		return
	_locked = false
	battlefield.resume()
	_on_act_boss_due(_pending_boss_act)


# --- Preparation and Command ----------------------------------------------

## True while the current Preparation is a between-wave breather rather than the
## long one before a road or a boss. Both wait for Ride On; a breather alone has
## a ten-second early-departure reward window.
var _breather: bool = false

## The wave number the last breather followed.
##
## One breather per wave, and this is what enforces it. Without it the run gets
## stuck: a breather ends, the next wave has not begun spawning yet, so the road
## still reads as clear and another breather opens immediately. The wave timer
## never gets its moment and the run sits on wave one forever, taking a ten
## second breather from a fight that stopped happening.
var _breather_after_wave: int = 0


## A pause between waves, once the road is clear of the last one.
##
## The player asked for this and the run had no place for it: Preparation existed
## only at a run's start, either side of a boss, and after a crossroad. Between
## waves the game simply never stopped, so the one phase where building is legal
## was unreachable for the whole middle of a road.
##
## The next formation never starts underneath a player who is reading a tower,
## repairing a lane or moving between scopes. Choosing Ride On early pays a small
## tempo reward; waiting past ten seconds simply forfeits it.
## True when a breather actually opened. The caller has to know, because a
## refusal leaves the wave director stopped and somebody must restart it.
func _enter_wave_breather(wave: int) -> bool:
	if _breather or wave <= _breather_after_wave:
		return false
	_breather = true
	RunState.begin_preparation_market()
	_breather_after_wave = wave
	RunState.set_phase(RunState.Phase.PREPARATION)
	battlefield.enter_preparation()
	journey.stop()
	_preparation_left = Balance.PREPARATION_BETWEEN_WAVES
	_coverage_warning_acknowledged = true
	EventBus.preparation_changed.emit(_preparation_left, true)
	EventBus.preparation_warning.emit("The road is clear. Ride early for bonus Gold, or prepare as long as you need.")
	return true


## Ends a breather and lets the next wave come.
func _end_wave_breather() -> void:
	var reward_ratio: float = clampf(_preparation_left \
		/ maxf(Balance.PREPARATION_BETWEEN_WAVES, 0.01), 0.0, 1.0)
	var reward: int = int(round(float(Balance.PREPARATION_EARLY_GOLD_MAX) * reward_ratio))
	if reward > 0:
		RunState.gain_currency(RunState.GOLD, reward)
		EventBus.preparation_warning.emit("EARLY DEPARTURE  ·  +%d Gold" % reward)
	_breather = false
	_preparation_left = 0.0
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	RunState.begin_command_battle()
	battlefield.wave_director.resume_after_breather()
	battlefield.begin_battle()
	journey.start()
	EventBus.preparation_changed.emit(0.0, false)


## WaveDirector owns both halves of "clear": its authored spawn queue and the
## living enemies in the field. This is a fact, never an estimate from a timer.
func _on_wave_cleared(wave: int) -> void:
	if RunState.phase != RunState.Phase.ROAD_BATTLE or _locked:
		return
	if _pending_boss_act > 0:
		_begin_boss_preparation(_pending_boss_act)
		return
	# A crossroad that arrived mid-fight has been waiting for exactly this. It
	# takes precedence over the breather rather than following it: both are
	# Preparation, and stacking one on the other is two stops at one junction.
	if _pending_crossroad >= 0:
		_open_crossroad(_pending_crossroad)
		return
	if _enter_wave_breather(wave):
		return

	# The breather was refused - one per wave, which is what stops the run
	# stalling on a repeat - but the road still has to carry on. `_close_wave`
	# stops the director, and the only things that restart it are Ride On and the
	# end of a breather. With no breather, neither happens: no further wave ever
	# spawns and no Preparation ever opens, which is a dead run with a clear road.
	#
	# Reported after the Act 1 boss, where it needs only ordinary play to hit: a
	# wave that began during the boss fight closes after the act's Preparation has
	# already claimed that wave number, so the breather declines and nothing is
	# left running.
	battlefield.wave_director.start()


func _enter_preparation(initial: bool) -> void:
	_breather = false
	RunState.begin_preparation_market()
	_breather_after_wave = RunState.wave_number
	RunState.set_phase(RunState.Phase.PREPARATION)
	battlefield.enter_preparation()
	journey.stop()
	_preparation_left = 0.0
	_coverage_warning_acknowledged = false
	EventBus.preparation_changed.emit(_preparation_left, true)


func _on_ride_on_requested() -> void:
	if not RunState.is_preparation():
		return
	if _breather:
		# Skipping a breather is always allowed: it is a window, not a gate.
		_end_wave_breather()
		return
	var uncovered: Array[int] = _uncovered_roads()
	if not uncovered.is_empty() and not _coverage_warning_acknowledged:
		_coverage_warning_acknowledged = true
		var names: PackedStringArray = []
		for lane: int in uncovered:
			names.append(HUD.LANE_NAMES[lane])
		EventBus.preparation_warning.emit(
			"Uncovered road%s: %s. Press Ride On again to accept the risk." % [
				"s" if uncovered.size() > 1 else "", ", ".join(names)])
		return

	var next_phase: RunState.Phase = RunState.Phase.BOSS \
		if _pending_boss_act > 0 else RunState.Phase.ROAD_BATTLE
	RunState.set_phase(next_phase)
	RunState.begin_command_battle()
	if next_phase == RunState.Phase.ROAD_BATTLE:
		journey.start()
	battlefield.begin_battle()
	if _pending_boss_act > 0:
		var boss_act: int = _pending_boss_act
		_pending_boss_act = 0
		boss_director.summon(boss_act)
	EventBus.preparation_changed.emit(0.0, false)


func _uncovered_roads() -> Array[int]:
	var result: Array[int] = []
	for lane: int in Balance.LANE_COUNT:
		if RunState.slot_is_empty(lane, 0) and RunState.slot_is_empty(lane, 2):
			result.append(lane)
	return result


func _on_command_requested(order_id: String, lane: int, slot: int) -> void:
	var problem: String = command_system.use_order(order_id, lane, slot)
	if not problem.is_empty():
		EventBus.preparation_warning.emit(problem)


# --- Ending -----------------------------------------------------------------

func _on_run_ended(victory: bool, summary: Dictionary) -> void:
	_locked = true
	RunState.set_phase(RunState.Phase.ENDED)
	journey.stop()
	battlefield.suspend()
	raid.process_mode = Node.PROCESS_MODE_DISABLED
	results_ui.show_results(victory, summary)
