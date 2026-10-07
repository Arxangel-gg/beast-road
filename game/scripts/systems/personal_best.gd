class_name PersonalBest
extends Node

## **A personal best is said once, with ceremony** (triage of 2026-10-07).
##
## The road passing the furthest this account has ever walked is the one record
## a player can feel arriving rather than read afterwards, so it is said the
## moment it happens: a word over the Warden, a ring and rays, the achievement's
## horn and a line on the banner - once a road, and never on a first road (the
## account's best has to be worth beating, `PERSONAL_BEST_MIN_DISTANCE`), a
## Walk or a sandbox. The debrief says it again. It reads the distance and the
## account's best as the road began (`RunState.best_to_beat`) and writes
## nothing: the best itself is still settled where every statistic is.

## How many times this has been said, for the gate.
var said: int = 0


func _ready() -> void:
	EventBus.distance_changed.connect(_on_distance)


func _on_distance(distance: float, _to_crossroad: float) -> void:
	if RunState.best_called or not worth_saying(distance):
		return
	RunState.best_called = true
	said += 1
	EventBus.preparation_warning.emit("Further than you have ever walked.")
	Sfx.play_group("sfx_achievement", -2.0)
	var hero: Node2D = get_tree().get_first_node_in_group(Hero.GROUP) as Node2D
	if hero == null:
		return
	var at: Vector2 = hero.global_position + Vector2(0.0, -96.0)
	Vfx.word(at, "FURTHER THAN EVER", Balance.PERSONAL_BEST_COLOUR, 34)
	Vfx.ring(hero.global_position, 150.0, Balance.PERSONAL_BEST_COLOUR, 0.6, 6.0)
	Vfx.rays(hero.global_position, Balance.PERSONAL_BEST_COLOUR, 12, 140.0, PI * 0.125)


## Whether a road at `distance` has just beaten a best worth beating.
static func worth_saying(distance: float) -> bool:
	if RunState.walking or RunState.sandbox:
		return false
	return RunState.best_to_beat >= Balance.PERSONAL_BEST_MIN_DISTANCE \
		and distance > RunState.best_to_beat
