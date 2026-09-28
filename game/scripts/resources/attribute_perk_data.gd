class_name AttributePerkData
extends GameData

## **A threshold's perk** (docs/GEAR_REWORK_2026-09-28.md §2): what every
## `ATTRIBUTE_THRESHOLD` points in one attribute unlock, a tier at a time, to
## `ATTRIBUTE_PERK_TIERS`. A perk is a *named* thing on the Warden card, never
## a bigger multiplier: each moves one number through a door the game already
## has - the finisher, the quiet regen, the dash's rest, a cast's cost, a
## shove - and adds no point. Reached by points on the capped scale (working
## rule 7); `WardenSheet.perk_of` is the one reader.
##
## No picture: a perk is a line on the card.

## `RunState.Attribute` this perk belongs to.
@export var attribute: int = 0
## What one tier is worth, as a share the door multiplies by.
@export var per_tier: float = 0.05
## The words after the figure on the card: "the finisher hits", "of health a
## second comes back out of combat"...
@export var unit: String = ""


func get_sprite_path() -> String:
	return ""


## The card's line for a Warden holding `tiers` of it, and the next threshold.
func line(tiers: int, points: int) -> String:
	var roman: Array[String] = ["", "I", "II", "III", "IV", "V"]
	var next_at: int = (tiers + 1) * Balance.ATTRIBUTE_THRESHOLD
	if tiers <= 0:
		return "%s at %d: %s %d%%" % [display_name, next_at, unit, int(round(per_tier * 100.0))]
	var held: String = "%s %s: %s %d%%" % [display_name, roman[clampi(tiers, 0, roman.size() - 1)],
		unit, int(round(per_tier * float(tiers) * 100.0))]
	if tiers < Balance.ATTRIBUTE_PERK_TIERS:
		held += "  ·  next at %d" % next_at
	return held
