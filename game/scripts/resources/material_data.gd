class_name MaterialData
extends GameData

## Something the hero dug up or cut down, kept between runs, and spent at the
## forge. Wood, ore and gems.
##
## **This is a new kind of persistence and it is bounded here.** `MetaState`
## writes only what CLAUDE.md §7 sanctions; materials are added to that list on
## 2026-09-13 with one rule: **a material is an input to the Smithy and nothing
## else.** It grants no attribute, buys no tower, pays no wave and cannot be
## exchanged for a run currency. What it makes is *gear*, which is already on
## the capped scale levelling shares - so the third power scale this project
## keeps refusing does not arrive through the back of a mine.
##
## The other half of that bound is that a new account starts with none of it
## (owner brief), which is why nothing anywhere grants a material except working
## a node with the craft that node wants.

## Wood, Ore or Gem. A gem is the one a smith can set into a piece, which is
## what makes it worth more than its weight.
enum Kind { WOOD, ORE, GEM }

@export var kind: Kind = Kind.WOOD

## 0 (common) to 3. A gem's rarity is what tilts the rarity of what is forged
## with it; wood and ore decide how good a piece the forge may attempt at all.
@export_range(0, 3) var rarity: int = 0

## What one of these is worth at the forge, as a share of what a piece costs.
@export_range(1, 200) var forge_value: int = 1


func get_sprite_path() -> String:
	return GameData.derive_path("icons/ui", "ui_", id)


func kind_name() -> String:
	match kind:
		Kind.WOOD:
			return "Wood"
		Kind.ORE:
			return "Ore"
		_:
			return "Gem"
