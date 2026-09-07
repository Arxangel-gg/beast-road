class_name ChronicleGoals
extends Node

## The pin is a local preference. Progress is the host's run, never a second
## kill counter; selecting a goal cannot grant or change a reward.
const COPY: ChronicleText = preload("res://data/ui/chronicle_text.tres")
const SETTING: String = "chronicle_goal"
const COUNTERS: Array[String] = [
	"kills", "towers_built", "tower_upgrades", "raids", "chieftains", "wounds",
]
var _send_left: float = 0.0


func _ready() -> void:
	EventBus.coop_chronicle_progress.connect(_receive_progress)
	EventBus.run_started.connect(func() -> void: _send_left = 0.0)


func _process(delta: float) -> void:
	if not GameDirector.run_active or not Coop.is_host() or not Coop.partner_present():
		return
	_send_left -= delta
	if _send_left <= 0.0:
		_send_left = Balance.CHRONICLE_SYNC_INTERVAL
		publish_progress()


func selected_id() -> String:
	var value: Variant = MetaState.settings.get(SETTING, "")
	if not value is String or ContentDB.chronicle_objective(value) == null:
		return ""
	return value


func select(id: String) -> bool:
	if not id.is_empty() and (ContentDB.chronicle_objective(id) == null
			or MetaState.objective_completed(id)):
		return false
	if selected_id() == id:
		return true
	MetaState.settings[SETTING] = id
	MetaState.save_game()
	return true


static func local_progress(victory: bool = false, final: bool = false) -> Dictionary:
	return {
		"seed": RunState.run_seed, "victory": victory, "final": final, "act": RunState.act,
		"kills": RunState.enemies_killed, "towers_built": RunState.towers_built,
		"tower_upgrades": RunState.tower_upgrades, "raids": RunState.raids_completed,
		"chieftains": RunState.chieftains_taken, "town_damage": RunState.town_damage_taken,
		"wounds": RunState.wounds_suffered,
	}


func progress() -> Dictionary:
	if Coop.is_guest():
		return RunState.chronicle_host_progress
	return local_progress()


## Sent on the same reliable channel immediately before RUN_ENDED as well as
## periodically. The guest must receive the final hit before paying deeds out.
func publish_progress(victory: bool = false, final: bool = false) -> void:
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_chronicle_progress.emit(local_progress(victory, final))


func _receive_progress(payload: Dictionary) -> void:
	var relay: CoopRelay = Coop.relay()
	if not Coop.is_guest() or relay == null or not relay.is_replaying():
		return
	var valid: Dictionary = validated_progress(payload, RunState.run_seed)
	if not valid.is_empty():
		RunState.chronicle_host_progress = valid


## Reject a whole malformed snapshot rather than manufacture zero wounds or
## zero town damage: either of those could incorrectly earn a flawless deed.
static func validated_progress(payload: Dictionary, seed_value: int) -> Dictionary:
	if not payload.get("seed") is int or int(payload.seed) != seed_value:
		return {}
	if not payload.get("victory") is bool or not payload.get("final") is bool \
			or not payload.get("act") is int:
		return {}
	if int(payload.act) < 1 or int(payload.act) > Balance.FINAL_ASCENT_ACT:
		return {}
	var out: Dictionary = {"seed": seed_value, "act": payload.act,
		"victory": payload.victory, "final": payload.final}
	for key: String in COUNTERS:
		if not payload.get(key) is int or int(payload[key]) < 0:
			return {}
		out[key] = payload[key]
	var damage: Variant = payload.get("town_damage")
	if not (damage is float or damage is int):
		return {}
	if not is_finite(float(damage)) or float(damage) < 0.0:
		return {}
	out["town_damage"] = float(damage)
	return out


static func reward_summary(local: Dictionary, guest: bool, mirrored: Dictionary) -> Dictionary:
	if not guest:
		return local
	var valid: Dictionary = validated_progress(mirrored, int(local.get("seed", 0)))
	if valid.is_empty() or not bool(valid.final) \
			or bool(valid.victory) != bool(local.get("victory", false)):
		return {}
	return valid


static func status_for(objective: ChronicleObjectiveData, summary: Dictionary) -> String:
	if summary.is_empty():
		return COPY.waiting
	var value: float = objective.value_from(summary)
	if objective.comparison == ChronicleObjectiveData.Comparison.AT_MOST \
			and value > objective.target:
		return COPY.failed
	var parts: PackedStringArray = []
	if objective.comparison == ChronicleObjectiveData.Comparison.AT_LEAST:
		if value < objective.target:
			parts.append(COPY.progress % [int(value), int(ceil(objective.target))])
	else:
		parts.append(COPY.intact)
	if int(summary.get("act", 1)) < objective.minimum_act:
		parts.append(COPY.act_gate % objective.minimum_act)
	if objective.requires_victory and not bool(summary.get("victory", false)):
		parts.append(COPY.victory_required)
	if parts.is_empty() or objective.is_met(summary):
		return COPY.eligible
	return " · ".join(parts)


func hud_text() -> String:
	if not GameDirector.run_active:
		return ""
	var id: String = selected_id()
	if id.is_empty() or MetaState.objective_completed(id):
		return ""
	var objective: ChronicleObjectiveData = ContentDB.chronicle_objective(id)
	return COPY.hud % [objective.display_name, status_for(objective, progress())]


static func reward_text(objective: ChronicleObjectiveData) -> String:
	return (COPY.reward_one if objective.tool_reward == 1 else COPY.reward) % objective.tool_reward
