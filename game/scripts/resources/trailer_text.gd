class_name TrailerText
extends GameData

## The words the live trailer says between its moments (working rule 9): the
## card that names each road, the opening and the closing, and the Skip button.

## The card before a road: the act in Roman numerals, then the region's name.
@export var act_card: String = "Act %s"
## A line under the act card, one of which is said on each road's card.
@export var road_lines: Array[String] = []
## The words before the first road.
@export var opening: String = ""
## The last card: under the wordmark.
@export var tagline: String = ""
@export var skip: String = "Skip"
## What the Skip button's tooltip says.
@export var skip_hint: String = ""
