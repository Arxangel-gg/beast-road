class_name WildlifeData
extends GameData

## One kind of animal that lives off the roads.
##
## Data, like everything else that can be added to (working rule 3): a new
## creature is a `.tres` and a sprite, never a branch in the spawner. The sprite
## path is derived from the id by the usual convention, so `id = "fox"` loads
## `res://art/wildlife/wildlife_fox.png` and its idle frames follow from that.

## Which acts this creature belongs to. Empty means all of them.
##
## A deer in the ash wastes of Act III would be saying the wrong thing about the
## place, and the point of ambient life is that it describes where you are.
@export var acts: Array[int] = []

## How likely this one is, relative to the others available.
@export_range(0.0, 10.0) var weight: float = 1.0

## How many arrive together. A fox is alone; deer are not.
@export_range(1, 8) var group_min: int = 1
@export_range(1, 8) var group_max: int = 1

## World units per second while moving.
@export_range(4.0, 240.0) var speed: float = 34.0

## How far it will wander from where it arrived, in world units.
@export_range(0.0, 900.0) var roam: float = 240.0

## How close something frightening gets before it bolts.
##
## Zero means nothing frightens it, which is right for a raven: they are the
## animals that turn up *because* of a battle rather than in spite of one.
@export_range(0.0, 900.0) var skittish_radius: float = 260.0

## Multiplier on how fast it moves while fleeing.
@export_range(1.0, 6.0) var flee_speed_scale: float = 2.6

## True for anything that arrives and leaves by air.
##
## A flier ignores the ground rules on the way in and on the way out - it is
## crossing the sky, not the field - and obeys them only while it is down.
@export var flies: bool = false

## Drawn size, as a multiple of the sprite's own pixels.
##
## Judge these against the hero, not against each other: the hero is 128px of art
## at `HERO_SPRITE_SCALE` 1.75, so about 224 world units tall. A deer stands with
## its back at roughly a person's shoulder, so it wants ~200 units — which at
## 64px of art means a scale near 3, not near 1. The first pass had every one of
## these under 1 and they read as toys on the grass.
@export_range(0.2, 6.0) var scale: float = 1.0

## True when the source art faces right. All six ship facing **left**.
##
## Declared rather than assumed, because assuming is what went wrong: the flip
## was written for right-facing art against sprites that were drawn facing left,
## so every animal in the game walked backwards.
@export var art_faces_right: bool = false

## Seconds this creature stays before wandering off, as a range.
@export_range(4.0, 600.0) var stay_min: float = 30.0
@export_range(4.0, 600.0) var stay_max: float = 90.0


func get_sprite_path() -> String:
	return GameData.derive_path("wildlife", "wildlife_", id)
