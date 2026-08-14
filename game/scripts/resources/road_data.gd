class_name RoadData
extends GameData

## One authored promise/cost pair offered at a crossroad (GDD §30). The active
## road id lives in RunState; systems read these values instead of branching on
## a road name, so adding a sixth road remains a content change.

@export var icon_id: String = "distance"
@export_multiline var promise: String = ""
@export_multiline var consequence: String = ""

## Physical length relative to a standard 300-distance road. Journey progress
## is divided by this value while production uses physical distance walked.
@export var distance_scale: float = 1.0
@export var resource_rate_scale: float = 1.0
@export var construction_scale: float = 1.0

@export var count_scale: float = 1.0
@export var hp_scale: float = 1.0
@export var damage_scale: float = 1.0
@export var speed_scale: float = 1.0
@export var spawn_spacing_scale: float = 1.0
@export var elite_budget_bonus: float = 0.0
@export var raid_charge_scale: float = 1.0

## Per reward roll, settled only when the chosen road is completed.
@export var reward_currencies: Dictionary = {}
@export var guaranteed_regional_relic: bool = false
@export var guarantees_raid_charge: bool = false

