class_name CraftTalentData
extends GameData

## **A craft's talent** (2026-09-30, `IDEAS_REVIEW_2026-09-23` §4.2): at each of
## `Balance.CRAFT_TALENT_LEVELS` a craft offers two, and the Warden keeps one -
## the Angler's shorter wait *or* its wider bite window. Crafts become builds.
##
## **The bound every craft lives under is unchanged**: a talent moves one number
## of its own craft and nothing about the fight. It is a share the craft's own
## reader multiplies by (`CraftTalents.value`), capped by
## `Balance.CRAFT_TALENT_CEILING`, and read in that craft's script and nowhere
## else - `craft_talent_check` walks every script for a reader outside it.
##
## No picture: a talent is a line on the Warden's card.

## `Balance.PROFESSIONS` id this talent belongs to.
@export var craft: String = ""
## The craft level it opens at; one of `Balance.CRAFT_TALENT_LEVELS`.
@export var level: int = 10
## The number it moves, named for the craft's reader (`wait`, `bite`, `swing`...).
@export var key: String = ""
## What it is worth: a share for a rate or a chance, a count for `swings`.
@export var amount: float = 0.0


func get_sprite_path() -> String:
	return ""
