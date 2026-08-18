class_name CommandSystem
extends Node

## Battle-only tactical orders (GDD v4 §15).
##
## Command is generated here from hero facts on EventBus and spent here on
## battlefield targets. RunState owns the meter and telemetry; the HUD only
## requests an order and presents the result.

const OVERDRIVE: String = "overdrive"
const RALLY_ROAD: String = "rally_road"
const LAST_STAND: String = "last_stand"

@export var battlefield: Battlefield


func _ready() -> void:
	EventBus.hero_enemy_hit.connect(_on_hero_enemy_hit)
	EventBus.hero_dashed.connect(_on_hero_dashed)


func use_order(order_id: String, anchor: Vector2i) -> String:
	if not RunState.is_command_combat():
		return "Command orders are available during battle."
	match order_id:
		OVERDRIVE:
			return _use_overdrive(anchor)
		RALLY_ROAD:
			return _use_rally(RunState.tower_lane(anchor))
		LAST_STAND:
			return _use_last_stand()
		_:
			return "Unknown Command order."


func _use_overdrive(anchor: Vector2i) -> String:
	var tower: Tower = battlefield.tower_at_anchor(anchor) if battlefield != null else null
	if tower == null:
		return "Select a built tower for Overdrive."
	if not RunState.can_spend_command(Balance.COMMAND_OVERDRIVE_COST):
		return _need(Balance.COMMAND_OVERDRIVE_COST)
	if not RunState.spend_command(Balance.COMMAND_OVERDRIVE_COST, OVERDRIVE):
		return _need(Balance.COMMAND_OVERDRIVE_COST)
	tower.command_overdrive(Balance.COMMAND_OVERDRIVE_DURATION)
	EventBus.command_order_used.emit(OVERDRIVE, RunState.tower_lane(anchor), 0, tower.global_position)
	return ""


func _use_rally(lane: int) -> String:
	if battlefield == null or lane < 0 or lane >= Balance.LANE_COUNT:
		return "Select a road to Rally."
	if not RunState.can_spend_command(Balance.COMMAND_RALLY_COST):
		return _need(Balance.COMMAND_RALLY_COST)
	if not RunState.spend_command(Balance.COMMAND_RALLY_COST, RALLY_ROAD):
		return _need(Balance.COMMAND_RALLY_COST)

	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and battlefield.is_ancestor_of(enemy) and enemy.lane == lane:
			enemy.apply_stagger(Balance.COMMAND_RALLY_STAGGER)
	for built: Tower in battlefield.all_towers():
		if built.lane() == lane:
			built.command_rally(Balance.COMMAND_RALLY_SHIELD)

	var at: Vector2 = Battlefield.lane_vector(lane) * Balance.TOWER_SLOT_RADIUS
	EventBus.command_order_used.emit(RALLY_ROAD, lane, -1, at)
	return ""


func _use_last_stand() -> String:
	if battlefield == null or battlefield.town == null:
		return "The Town Hall cannot answer the order."
	if RunState.last_stand_used:
		return "Last Stand was already used this battle."
	if not RunState.can_spend_command(Balance.COMMAND_LAST_STAND_COST):
		return _need(Balance.COMMAND_LAST_STAND_COST)
	if not RunState.spend_command(Balance.COMMAND_LAST_STAND_COST, LAST_STAND):
		return _need(Balance.COMMAND_LAST_STAND_COST)

	RunState.last_stand_used = true
	battlefield.town.health.add_invulnerability(Balance.COMMAND_LAST_STAND_DURATION)
	for built: Tower in battlefield.all_towers():
		built.command_reset_attack()
	EventBus.command_order_used.emit(LAST_STAND, -1, -1, battlefield.town.global_position)
	return ""


func _on_hero_enemy_hit(_enemy_id: String, lane: int, priority: bool,
		interrupted: bool, _at: Vector2) -> void:
	if battlefield == null or not RunState.is_command_combat():
		return
	var pressure: float = battlefield.lane_pressure(lane)
	if pressure < Balance.COMMAND_CAUTION_PRESSURE:
		return
	var pressure_scale: float = remap(pressure, Balance.COMMAND_CAUTION_PRESSURE,
		1.0, 1.0, 1.65)
	var earned: float = Balance.COMMAND_HERO_HIT_GAIN * pressure_scale
	if priority:
		earned += Balance.COMMAND_PRIORITY_HIT_GAIN
	if interrupted:
		earned += Balance.COMMAND_INTERRUPT_GAIN
	RunState.gain_command(earned)


func _on_hero_dashed(_iframes: float) -> void:
	if battlefield == null or not RunState.is_command_combat() \
			or battlefield.hero == null:
		return
	var hero_at: Vector2 = battlefield.hero.global_position
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not battlefield.is_ancestor_of(enemy) \
				or not enemy.is_telegraphing():
			continue
		if enemy.global_position.distance_to(hero_at) <= Balance.COMMAND_PERFECT_DODGE_RADIUS:
			RunState.gain_command(Balance.COMMAND_PERFECT_DODGE_GAIN)
			Vfx.word(hero_at, "PERFECT DODGE", Color("e8a33d"), 24)
			return


func _need(cost: float) -> String:
	return "Need %d Command." % int(ceil(maxf(cost - RunState.command, 0.0)))
