class_name FishData
extends GameData

## One kind of fish, pulled out of a pond beside the road.
##
## **Two payments, deliberately separate.** Catching one pays Food immediately -
## that is the run currency the owner asked fishing to feed, and it is spent on
## the road like any other Food. The fish *itself* goes to the stash and is
## eaten later for what is on this resource: health, a ward, a draught of mana.
##
## **Nothing here grants a stat.** Gear and levelling are the two capped scales
## the campaign tiers are tuned against (CLAUDE.md working rule 7), and a fish
## that raised an attribute would be a third one nobody is tuning. Every effect
## below is instantaneous and run-scoped: it restores what the road took.
##
## Art is derived from the id like everything else: a `FishData` with
## `id = "ember_carp"` draws `res://art/fish/fish_ember_carp.png`.

## How rare a fish is, which decides its colour, its odds and its patience.
## Deliberately the same four names the wildlife and the gear use, so a player
## reads one rarity ladder across the whole game rather than three.
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var rarity: Rarity = Rarity.COMMON

## Which regions this fish lives in, by terrain id. Empty means every water in
## the world holds it, which is how the two legendaries are authored.
@export var regions: Array[String] = []

## Relative odds of being the one that bites, among the fish eligible here.
@export_range(0.0, 10.0, 0.05) var weight: float = 1.0

## Seconds the line is in the water before this one takes it. Longer for the
## rare ones: patience is the price of the better fish, and standing still on a
## battlefield is what that price is actually made of.
@export_range(1.0, 60.0, 0.5) var patience: float = 6.0

## Food paid the moment it is landed.
@export_range(0, 200) var food: int = 6

## What eating it restores, each as a fraction of the hero's own maximum. All
## three may be set; a fish that restores nothing is caught for the Food and
## for the journal.
@export_range(0.0, 1.0, 0.01) var heal_fraction: float = 0.0
@export_range(0.0, 1.0, 0.01) var shield_fraction: float = 0.0
@export_range(0.0, 1.0, 0.01) var mana_fraction: float = 0.0


## Where this fish's icon lives. By convention from the id, like every other
## asset in the project (CLAUDE.md §4).
func get_sprite_path() -> String:
	return GameData.derive_path("fish", "fish_", id)


## Whether this fish can be pulled out of water in `terrain_id`.
func lives_in(terrain_id: String) -> bool:
	return regions.is_empty() or regions.has(terrain_id)


## The colour its rarity reads as. One ladder with the gear and the spirits.
func rarity_colour() -> Color:
	match rarity:
		Rarity.UNCOMMON:
			return Color("6fbf73")
		Rarity.RARE:
			return Color("5b8fd9")
		Rarity.LEGENDARY:
			return Color("d98f3a")
		_:
			return Color("c9c2b4")


func rarity_name() -> String:
	match rarity:
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Common"
