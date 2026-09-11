extends Node

## The scope a pond sits in, reduced to what `Fishing` asks of one, for
## `fishing_check`.
##
## Two questions: whose line is this, and where do I put the Food. The second is
## recorded rather than acted on, so a test can assert that a catch paid out
## without a battlefield existing.

## The hero this machine drives. `Fishing` reads it to find the angler.
var hero: Node2D = null

## What has been paid out here, by currency id.
var paid: Dictionary = {}


func spawn_loot(currency: String, amount: int, _at: Vector2) -> void:
	paid[currency] = int(paid.get(currency, 0)) + amount
