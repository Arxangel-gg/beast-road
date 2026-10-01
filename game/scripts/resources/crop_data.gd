class_name CropData
extends GameData

## A crop the Farmer can grow (2026-09-14): what it wants of the ground, what
## it pays, and where it grows wild.
##
## Owner brief: farming as a slow skill tied to the climate grid's soil,
## moisture and temperature, with crops that adapt - or fail - to the ground
## they are put in. Data rather than code (working rule 3): another crop is a
## file, and the bands below are the whole of "does it grow here".
##
## The four stages of its art live at `res://art/crops/crop_<id>_<0..3>.png`:
## a seedling, a shoot, a green plant and the plant ready to pull.

## How rare the crop is, 0 (common) to 3. Rarer crops pay more Food and want
## narrower ground.
@export_range(0, 3) var rarity: int = 0

## Food a harvest pays at Farmer level 1, before the level's share.
@export var food_yield: int = 12

## Farmer experience a harvest pays; taking seeds from a wild plant pays a
## share of it.
@export var xp: int = 14

## Road the beast must walk for the crop to ripen on ground that fits it
## perfectly. `Balance.ACT_DISTANCE` is an act.
@export var grow_distance: float = 160.0

## The air the crop wants, in degrees: inside the band it grows at full
## speed, outside it the Farmer's tolerance decides how far it still grows.
@export var temp_min: float = 10.0
@export var temp_max: float = 26.0

## The ground it wants, 0 tinder to 1 standing water (`Climate.wetness_at`).
@export var wet_min: float = 0.15
@export var wet_max: float = 0.6

## Regions where the crop grows wild on the outskirts, by terrain id, which
## is where its seeds are first found.
@export var regions: Array[String] = []

## **What it lends a dish** (2026-09-30, `RunState.cook`). Cooked with a fish
## from the pantry, a crop pulled this run adds one more thing to the meal -
## and each is a share of something the Warden already has, read at the hero
## and clamped there by `Balance.COOK_DISH_CEILING`. **Never health**: what a
## meal heals is the fish's, so the recovery economy the meal cap bounds is
## exactly what it was. **Never a stat**: nothing here is an attribute point.
@export_range(0.0, 1.0, 0.01) var dish_stamina: float = 0.0
@export_range(0.0, 1.0, 0.01) var dish_ward: float = 0.0
@export_range(0.0, 1.0, 0.01) var dish_mana: float = 0.0
## How much longer the fish's own meal lasts, as a share of it.
@export_range(0.0, 1.0, 0.01) var dish_lingers: float = 0.0


## What it lends a dish, said the way the pantry says what a fish restores.
func dish_text() -> String:
	var parts: PackedStringArray = []
	if dish_stamina > 0.0:
		parts.append("%d%% stamina" % int(round(dish_stamina * 100.0)))
	if dish_ward > 0.0:
		parts.append("%d%% ward" % int(round(dish_ward * 100.0)))
	if dish_mana > 0.0:
		parts.append("%d%% mana" % int(round(dish_mana * 100.0)))
	if dish_lingers > 0.0:
		parts.append("the meal lasts %d%% longer" % int(round(dish_lingers * 100.0)))
	return ", ".join(parts)


## The art of one growth stage, 0 to 3.
func stage_path(stage: int) -> String:
	return "res://art/crops/crop_%s_%d.png" % [id, clampi(stage, 0, 3)]


func get_sprite_path() -> String:
	return stage_path(3)
