class_name RoadCardData
extends GameData

## One card drafted at a crossroad and carried in a hand of five.
##
## Owner ruling, 2026-09-11: build Road Cards, after `IDEAS_REVIEW` §4 had
## refused them on the grounds that disciplines and omens already are a draft.
## That objection is correct and is what shapes this: a third pool must not be a
## third power scale.
##
## ## What a card may do
##
## Exactly what an omen may do. One entry in `Modifiers`, the same flat table
## relics, boss cores and portents feed, so nothing downstream learns that cards
## exist. A card that added a *mechanic* would be a content system wearing a
## card's clothes, and it would not be testable against the curve the acts are
## tuned to.
##
## ## What stops twenty crossroads from becoming twenty upgrades
##
## Two rules, and both are in `RunState.take_road_card` rather than here so that
## one function owns them and `road_card_check` can drive it.
##
## - **The hand holds five.** Twenty crossroads deal sixty cards and five are
##   kept, so most of a run's draft is refused. Once the hand is full every
##   later draw is a *replacement* decision, which is the interesting one.
## - **One card per effect key.** Five Rare tower-damage cards would be +110% on
##   one number; one is +22%. Drawing a better card for a key you already hold
##   swaps it, so rarity is an upgrade path rather than a stack.
##
## Between them, the most a hand can ever be worth is the five best cards on
## five different numbers - a quantity a curve can be read against, unlike an
## open-ended sum.
##
## ## And nothing persists
##
## A hand is run-scoped exactly as a socketed relic is (working rule 7).
## `road_card_check` asserts a fresh run deals a fresh hand; cards that survived
## into the next run would be an account-level difficulty setting nobody chose.

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
}

## `id = "dry_powder"` -> `res://art/icons/road_cards/card_dry_powder.png`
func get_sprite_path() -> String:
	return GameData.derive_path("icons/road_cards", "card_", id)


## The `Modifiers` key this card moves, and by how much.
##
## Signed as it acts, like an omen's halves: a card that makes building cheaper
## carries a negative `build_cost`. Unlike an omen, a card has no bane - the
## cost of a card is the slot it takes in a hand of five.
@export var effect_id: String = ""
@export var effect_magnitude: float = 0.0

## Which pool this card is drawn from, and how strong it is allowed to be.
@export var rarity: Rarity = Rarity.COMMON

## Earliest act this may be dealt. Rare cards open late so that the first hand
## is built out of small things and improved rather than rolled at once.
@export_range(1, 10) var first_act: int = 1

## What the card says under its name. Player-facing string in data, working
## rule 9 - and the reason a card carries one at all is that "+8% tower damage"
## is a number while "an hour with the stone, and everything on the wall bites"
## is a road that is telling you something.
@export_multiline var card_text: String = ""


## The cards a given run offers at a given crossroad.
##
## **Derived on both machines, never relayed**, the pattern the regional relic
## offer and the portent draw already use: the draw comes out of the run's own
## seeded stream, so a host and a guest compute the same three without a packet,
## and a shared seed reproduces its cards like everything else in a run.
##
## `held` is excluded by id rather than by effect key on purpose. A card for a
## key already in hand is the *upgrade* this design runs on, so it has to stay
## in the pool; only the exact card you are already holding is out.
##
## Sorted before shuffling, because `ContentDB.road_cards` is a dictionary and
## its order is an implementation detail. Shuffling an unordered list is not
## reproducible from a seed, which is a fault this project has recorded once.
static func offer(held: Array, act: int, count: int) -> Array[String]:
	var pool: Array[String] = []
	for id_value: Variant in ContentDB.road_cards:
		var card: RoadCardData = ContentDB.road_card(String(id_value))
		if card == null or held.has(card.id) or card.first_act > act:
			continue
		pool.append(card.id)
	if pool.size() < count or count <= 0:
		return []
	pool.sort()
	for index: int in range(pool.size() - 1, 0, -1):
		var other: int = RunState.rng("road_cards").randi_range(0, index)
		var swap: String = pool[index]
		pool[index] = pool[other]
		pool[other] = swap
	pool.resize(count)
	return pool
