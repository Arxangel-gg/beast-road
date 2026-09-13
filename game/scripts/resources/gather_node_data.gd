class_name GatherNodeData
extends GameData

## A thing on the outskirts that can be worked: a tree to fell, a seam to break,
## a geode to crack open.
##
## Owner brief, 2026-09-13: woodcutting, mining and smithing beside the Angler,
## with resource nodes of different rarities, cooldowns, gems out of the ground,
## and nodes that sit **beyond the inner square the roads make**, rarer the
## further out they are and rarer still until the craft is practised.
##
## Data rather than code (working rule 3): another tree is a file. What a node
## is worth, how long it takes, how deep into the craft it wants you to be and
## how far from the city it grows all live here, so the placement rule is one
## piece of arithmetic reading a table rather than a chain of ids.

## Which craft this trains and which tool it wants. Only ids in
## `Balance.PROFESSIONS` are ever read from a save or trained.
@export var craft: String = "woodcutter"

## How rare this node is, 0 (common) to 3. Rarity decides three things at once -
## how often it is rolled, how far out it can be found, and how practised the
## hero has to be - so a Duskstone geode is a thing you go looking for rather
## than a thing you walk past.
@export_range(0, 3) var rarity: int = 0

## What comes out of it, by `MaterialData.id`, and how much per swing.
@export var material_id: String = ""
@export_range(1, 12) var material_per_swing: int = 1

## How many swings it holds before it is worked out.
@export_range(1, 24) var swings: int = 4

## How long one swing takes, before the craft's own speed is applied.
@export var swing_seconds: float = 1.6

## Experience for the craft, per swing.
@export_range(1, 200) var xp_per_swing: int = 6

## How practised the hero must be before this node will appear at all.
@export_range(1, 20) var min_level: int = 1

## Roughly how often this is rolled against its siblings, before rarity and
## distance have their say.
@export_range(0.0, 10.0) var weight: float = 1.0

## Regions this node prefers. Empty means anywhere. A *preference* rather than
## a gate, the way `WildlifeData.acts` is - a Glass Fields willow should be
## mostly a Glass Fields thing without the other nine regions having a hole in
## them where a tree ought to be.
@export var regions: Array[String] = []


func get_sprite_path() -> String:
	return GameData.derive_path("battlefield", "node_", id)


## How much likelier this node is in `region` than out of it.
func region_weight(region: String) -> float:
	if regions.is_empty():
		return 1.0
	return Balance.GATHER_REGION_FAVOUR if regions.has(region) \
		else Balance.GATHER_REGION_ELSEWHERE


## Whether a hero this practised may find it.
func within_reach(level: int) -> bool:
	return level >= min_level
