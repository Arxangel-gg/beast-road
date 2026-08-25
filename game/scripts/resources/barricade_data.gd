class_name BarricadeData
extends GameData

## One kind of barricade, raised across a road during Preparation.
##
## **A barricade does not reroute anything.** Enemies in this game follow their
## lane's waypoints and there is no pathfinder to send them a different way — a
## wall that made them go around would mean writing one, and a pathfinder is a
## far larger thing than a wall.
##
## So a barricade is an *obstacle to break*, not a maze piece. Enemies that meet
## one stop and attack it until it falls, which needs no pathing change at all:
## the enemy targeting is already field-mediated, so a barricade with a `Health`
## is simply another thing the field can offer as a target.
##
## **The broken entrances are the player's, not the map's.** The row asked for "a
## perimeter with broken entrances", and the honest way to get that is not a
## prefab ring with gaps designed in — it is that barricades are placed one tile
## at a time and the gaps are wherever the player did not spend. The funnel is
## then a decision somebody made rather than a shape they were handed.

## How much damage it takes to break.
@export_range(20.0, 20000.0) var max_hp: float = 900.0

## What it costs to raise. Keys match `RunState`'s currency ids.
@export var cost: Dictionary = {}

## Slow applied to anything standing against it, while it stands.
##
## A wall that only had health would be a speed bump with extra steps. Slowing
## what is hitting it is what makes a partial line worth building: the gap is
## faster than the wall, so the wall *shapes* where they go.
@export_range(0.05, 1.0) var slow_factor: float = 1.0

@export var colour: Color = Color(0.72, 0.6, 0.44)


## Which way a barricade is turned, chosen from the road it stands on.
##
## A wall drawn lying along the road is not a wall, it is a fence. The image has
## to cross the lane, so which image to use is a question about the *road*, not
## about the barricade - a straight run wants the piece that crosses it, and a
## corner wants the diagonal, flipped to follow which way the corner turns.
enum Facing { ACROSS, ALONG, DIAGONAL }


func get_sprite_path() -> String:
	return GameData.derive_path("barricades", "barricade_", id)


## The image for one orientation. `ACROSS` is the ordinary sprite, so a barricade
## that ships only one piece still works everywhere.
func sprite_path_for(facing: Facing) -> String:
	var base: String = get_sprite_path()
	match facing:
		Facing.ALONG:
			return "%s_along.png" % base.get_basename()
		Facing.DIAGONAL:
			return "%s_diagonal.png" % base.get_basename()
		_:
			return base
