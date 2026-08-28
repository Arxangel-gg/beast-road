class_name ChronicleObjectiveData
extends GameData

## One account-wide deed recorded in the Chronicle.
##
## A deed is a one-time mastery objective, evaluated from the authoritative run
## summary. It awards Tools, which only widen the content pool; it never grants
## combat stats. Both the rule and its player-facing framing live here, so adding
## or rebalancing an objective is a data change rather than a branch in the run.

enum Metric {
	ACT_REACHED,
	KILLS,
	TOWERS_BUILT,
	TOWER_UPGRADES,
	RAIDS_COMPLETED,
	CHIEFTAINS_TAKEN,
	TOWN_DAMAGE,
	WOUNDS,
}

enum Comparison {
	AT_LEAST,
	AT_MOST,
}

## Stable presentation order on the Chronicle screen.
@export var order: int = 0

## The run-summary measurement this deed reads.
@export var metric: Metric = Metric.ACT_REACHED

## Inclusive threshold, interpreted by `comparison`.
@export var target: float = 1.0
@export var comparison: Comparison = Comparison.AT_LEAST

## Additional gates for compound feats such as a flawless Act II arrival.
@export_range(1, 3) var minimum_act: int = 1
@export var requires_victory: bool = false

## One-time horizontal reward. Intentionally small beside ordinary run payout.
@export_range(0, 4) var tool_reward: int = 1


func is_met(summary: Dictionary) -> bool:
	if int(summary.get("act", 1)) < minimum_act:
		return false
	if requires_victory and not bool(summary.get("victory", false)):
		return false
	var measured: float = value_from(summary)
	return measured >= target if comparison == Comparison.AT_LEAST else measured <= target


func value_from(summary: Dictionary) -> float:
	var key: String = _summary_key()
	return float(summary.get(key, 0.0))


func _summary_key() -> String:
	match metric:
		Metric.ACT_REACHED:
			return "act"
		Metric.KILLS:
			return "kills"
		Metric.TOWERS_BUILT:
			return "towers_built"
		Metric.TOWER_UPGRADES:
			return "tower_upgrades"
		Metric.RAIDS_COMPLETED:
			return "raids"
		Metric.CHIEFTAINS_TAKEN:
			return "chieftains"
		Metric.TOWN_DAMAGE:
			return "town_damage"
		Metric.WOUNDS:
			return "wounds"
	return "act"
