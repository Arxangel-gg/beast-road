extends Node

## Resolves every relic and boss core into a flat table of modifiers (GDD §5).
##
## Relics only act while socketed in the Town Hall; boss cores are permanent and
## unsocketed. Both end up here, so nothing downstream has to know the
## difference — a tower asks for `TOWER_DAMAGE` and gets a number.
##
## Rebuilt on socket changes rather than recomputed per call: this is read
## inside tower fire loops, and walking the relic list per shot would be the
## most-executed code in the game for no reason.

# Effect keys. These are the strings relic `.tres` files use in `effect_id`.
const TOWER_DAMAGE: String = "tower_damage"
const TOWER_RANGE: String = "tower_range"
const TOWER_ARMOUR: String = "tower_armour"
const CHAIN_TARGETS: String = "chain_targets"
const BURN_DAMAGE: String = "burn_damage"
const SLOW_STRENGTH: String = "slow_strength"
const KNOCKBACK: String = "knockback"

const HERO_DAMAGE: String = "hero_damage"
const HERO_SPEED: String = "hero_speed"
const HERO_MAX_HP: String = "hero_max_hp"
const DASH_COOLDOWN: String = "dash_cooldown"

const TOWN_MAX_HP: String = "town_max_hp"
const RESOURCE_RATE: String = "resource_rate"
const KILL_RESOURCES: String = "kill_resources"
const CAPTIVE_OUTPUT: String = "captive_output"
const BUILD_COST: String = "build_cost"
const BEAST_SPEED: String = "beast_speed"
const RAID_CHARGE: String = "raid_charge"
const ENEMY_DAMAGE: String = "enemy_damage"
const WAVE_FORESIGHT: String = "wave_foresight"

var _totals: Dictionary = {}


func _ready() -> void:
	EventBus.relic_socketed.connect(_on_relics_changed)
	EventBus.relic_unsocketed.connect(_on_relics_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.run_started.connect(rebuild)
	rebuild()


## Summed magnitude for an effect. 0.0 when nothing grants it.
func value(effect_id: String) -> float:
	return float(_totals.get(effect_id, 0.0))


## Convenience for the common "1.0 + bonus" multiplier shape.
func multiplier(effect_id: String) -> float:
	return 1.0 + value(effect_id)


func has(effect_id: String) -> bool:
	return _totals.has(effect_id)


func rebuild() -> void:
	_totals.clear()
	# Socketed relics act; held ones do not. That is the entire point of the
	# Town Hall (GDD §5).
	for relic_id: String in RunState.socketed_relics:
		_add(ContentDB.relics.get(relic_id, null) as RelicData)
	for core_id: String in RunState.boss_cores:
		_add(ContentDB.relics.get(core_id, null) as RelicData)


func _add(relic: RelicData) -> void:
	if relic == null or relic.effect_id.is_empty():
		return
	_totals[relic.effect_id] = float(_totals.get(relic.effect_id, 0.0)) + relic.effect_magnitude


func _on_relics_changed(_relic_id: String) -> void:
	rebuild()


func _on_boss_defeated(_boss_id: String, _act: int) -> void:
	rebuild()
