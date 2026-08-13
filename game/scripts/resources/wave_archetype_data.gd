class_name WaveArchetypeData
extends GameData

## An authored tactical problem for the wave director.
##
## Raw count and stat growth decide how hard a wave is. This resource decides
## why it is hard: a fast rush, one armoured lane, an opposite-lane pincer, or
## pressure everywhere at once. Keeping these as content means designers can
## tune the run's vocabulary without adding branches to WaveDirector.

enum LanePattern {
	## Uses the normal one-to-four-lane act progression.
	ESCALATING,
	## Concentrates the whole budget into one lane.
	FOCUSED,
	## Always attacks two opposite lanes.
	OPPOSITES,
	## Attacks every lane.
	ALL,
}

@export var lane_pattern: LanePattern = LanePattern.ESCALATING
@export_range(1, 3) var minimum_act: int = 1
@export var minimum_act_wave: int = 1
@export var selection_weight: float = 1.0
@export var night_weight_multiplier: float = 1.0

@export var count_scale: float = 1.0
@export var hp_scale: float = 1.0
@export var damage_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var spawn_spacing_scale: float = 1.0

## A signature unit added to each attacked lane. Empty means the terrain breed
## carries the pattern by itself. The id is validated by the balance gate.
@export var signature_enemy_id: String = ""
@export var signature_count_per_lane: int = 0
@export var extra_elites: int = 0


func is_available(act: int, act_wave: int) -> bool:
	return act >= minimum_act and act_wave >= minimum_act_wave
