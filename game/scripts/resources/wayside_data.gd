class_name WaysideData
extends GameData

## **A wayside encounter** (2026-09-25, `docs/IDEAS_REVIEW_2026-09-25.md` §4 and
## §8): something on the outskirts that stops and asks.
##
## Every other event out there is something that happens - a trail, a nest, a
## blight, a savage. This is the one that is walked up to and answered, from a
## few choices, and **each choice is a door the game already has**: a piece of
## gear on the ground, a sighting toward a bond, the purse, a heal, a share of
## a level, the savage a species already sends, the earth's own anger. What is
## new is only the composition, which is why adding one is adding files.
##
## **Nothing persists.** An encounter is the act's, like a nest or a trail, and
## is gone with the region. Its choices are `WaysideChoiceData`, one file each,
## named by `choice_ids` - the data layer here is flat, and a list of names is
## the one container a `.tres` cannot get subtly wrong.

## What stands there.
enum Scene {
	## A painted prop: `get_sprite_path()`.
	PROP,
	## An animal of the region, at `animal_rarity`: its own painting, laid here.
	ANIMAL,
}

## Shown on the card and the prompt. An ANIMAL encounter may carry one `%s`,
## which is the animal's name.
@export var title: String = ""
@export_multiline var text: String = ""
@export var scene: Scene = Scene.PROP
## For an ANIMAL encounter: the rarity of the animal the road lays here.
@export_range(0, 3) var animal_rarity: int = 1
## Earliest act it may be laid in.
@export_range(1, 11) var first_act: int = 2
## Relative weight among the encounters an act may lay.
@export var weight: float = 1.0
## The choices, in the order the card offers them. "Walk on" is the card's
## own and is not authored.
@export var choice_ids: PackedStringArray = PackedStringArray()


## `id = "overturned_cart"` -> `res://art/battlefield/wayside_overturned_cart.png`
func get_sprite_path() -> String:
	return GameData.derive_path("battlefield", "wayside_", id)


## The title with the animal's name in it, when it wants one.
func title_for(animal_name: String) -> String:
	if title.contains("%s"):
		return title % animal_name
	return title
