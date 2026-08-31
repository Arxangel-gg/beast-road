class_name AmmoData
extends GameData

## What a ranged weapon spends (owner decision, 2026-08-31).
##
## `id = "ember_arrow"` -> `res://art/ammo/ammo_ember_arrow.png`
##
## **Ammunition is the price of range.** Range without a cost is just a better
## melee attack, so every shot spends one of these and the pool is finite. It is
## deliberately *not* an inventory of stacks competing with loot: it has its own
## purse on `RunState`, for the same reason Marks stay off the tower economy -
## a decision about arrows must never compete with the wall about to be overrun.

## Which weapons can fire it. Matches `RangedWeaponData.family`.
@export var family: String = "arrow"

## Which element the shot carries, indexing `TowerData.Element`. Standard
## ammunition is elementless and reads -1, so weather and terrain scaling leave
## it alone rather than quietly favouring the plainest option.
@export_range(-1, 3) var element: int = -1

## Multiplies the weapon's damage. Specialist ammunition usually trades raw
## damage for an effect, so most of these sit at or below 1.
@export_range(0.1, 4.0) var damage_scale: float = 1.0

## Status left behind, reusing the effects the towers already apply. Empty means
## the shot simply hits.
@export var burn_damage: float = 0.0
@export var burn_duration: float = 0.0
@export_range(0.1, 1.0) var slow_factor: float = 1.0
@export var slow_duration: float = 0.0
@export_range(0, 6) var chain_targets: int = 0
@export_range(0.0, 400.0) var blast_radius: float = 0.0

## How much a crafting batch makes, and what it costs in run currencies.
##
## A batch, never one at a time. Crafting a single arrow is a chore the player
## performs dozens of times; crafting eight is a decision they make once.
@export_range(1, 40) var craft_batch: int = 8
@export var craft_cost: Dictionary = {}

## How much of the ammunition purse one of these occupies.
##
## Specialist shots weigh more than plain ones, which is the whole of the
## scarcity model - there is no separate rarity tier, no encumbrance, and no
## second currency. A quiver holds fewer bombs than arrows.
@export_range(1, 8) var bulk: int = 1

## Starts known, without a blueprint. Exactly one ammunition should: a bow the
## player cannot feed is a bow they cannot evaluate.
@export var known_from_the_start: bool = false


func get_sprite_path() -> String:
	return GameData.derive_path("ammo", "ammo_", id)
