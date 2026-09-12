class_name AchievementData
extends GameData

## One achievement: a statistic the account keeps anyway, and the number at
## which it is worth saying so (owner brief, 2026-09-12).
##
## **An achievement is a statistic with a threshold, and nothing else.** It
## grants no power, no unlock and no currency: working rule 7 sanctions run
## statistics, and this is those statistics being *named*. `MetaState.stat`
## is the one place the numbers live; an achievement whose key names a
## statistic that does not exist can never unlock, and `guide_check` refuses
## it.

@export var title: String = ""
## The `MetaState.stat` key this reads.
@export var stat: String = ""
## The value at which it unlocks.
@export var threshold: float = 1.0
## An `IconKit` icon name.
@export var icon: String = "upgrade"
@export var order: int = 0


func is_met() -> bool:
	return MetaState.stat(stat) >= threshold


func progress() -> float:
	if threshold <= 0.0:
		return 1.0
	return clampf(MetaState.stat(stat) / threshold, 0.0, 1.0)
