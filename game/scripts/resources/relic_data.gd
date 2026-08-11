class_name RelicData
extends GameData

## A relic (GDD §3.2, §6). Ordinary relics only do anything while socketed in
## the Town Hall. Boss cores are the exception: permanent, always-active, never
## socketed — set `is_boss_core` and they bypass the socket limit entirely.
##
## `id = "01"` -> `res://art/icons/relics/relic_01.png`
## `id = "core_rust_crown"` -> `res://art/icons/relics/relic_core_rust_crown.png`

@export var is_boss_core: bool = false

## Which act's boss dropped this core. 0 for ordinary relics.
@export var source_act: int = 0

## Effect key resolved by the relic system, plus its magnitude. Keeping the
## effect as data rather than a script per relic is what makes twenty relics a
## twenty-line file instead of twenty files.
@export var effect_id: String = ""

@export var effect_magnitude: float = 0.0


func get_sprite_path() -> String:
	return GameData.derive_path("icons/relics", "relic_", id)
