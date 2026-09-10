class_name MerchantData
extends GameData

## Someone who comes to town to sell you things, and may one day stay.
##
## The owner asked for three things on 2026-09-08 - "unlockable stationary town
## vendors as well as traveling merchants that appear in town sometimes", and
## "maybe an alchemist who can sell the players potions". Those read as three
## systems and are one: **a merchant is a traveller until you have done enough
## business with them, and then they settle.** Residency is the progression, and
## it is the same person either way, with the same stock, the same prices and
## the same sheet.
##
## Building them as one system rather than three is not only tidier - it is what
## makes the unlock mean anything. A separate "stationary vendor" the player
## simply switches on is a menu entry; a traveller who liked your trade enough to
## move in is a thing that happened to *you*.
##
## `id = "alchemist"` -> `res://art/city/merchant_alchemist.png`, like everything
## else in the project.

## Which pool this merchant's stock is drawn from.
##
## **Every arm here is implemented.** `ItemData` records what happens otherwise:
## an enum value nothing can fulfil is authorable, drawable and completely inert,
## and `item_check` now fails the build on one. `merchant_check` does the same
## for this enum, so adding an arm without a stock roller is a red gate rather
## than an empty shop.
enum Trade {
	## Carried consumables. The Alchemist.
	POTIONS,
	## Run-scoped relics, which the Town Hall can then socket.
	RELICS,
	## Ammunition and the means to hold a road: quivers and barricades.
	MUNITIONS,
}

@export var trade: Trade = Trade.POTIONS

## What they say when their sheet opens. Flavour, and the only place a merchant
## has a voice - kept in data because working rule 9 puts player-facing strings
## there and because a vendor's patter is exactly the kind of copy that gets
## rewritten twice before release.
@export_multiline var greeting: String = ""

## The line shown the moment they decide to stay for good.
@export_multiline var settle_line: String = ""

## How many offers they carry per visit. Small on purpose: a merchant with eight
## things is a shop screen, and a shop screen is a spreadsheet. Three is a
## choice.
@export_range(1, 6) var stock_size: int = 3

## How many *distinct* goods you must ever have bought from them before they
## settle in town permanently.
##
## Distinct rather than a running total, for two reasons. It cannot be ground out
## by buying the same tonic nine times, so the threshold reads as "you have
## really traded with this person" rather than as a counter. And it needs no new
## save shape at all: each purchase records a `traded:<merchant>:<good>` entry in
## the codex list, which is an unlocked ID in exactly the sense working rule 7
## already sanctions, and `MetaState.seen_count` counts the prefix.
@export_range(1, 12) var settle_trades: int = 3

## Relative chance of being the traveller who turns up, against the others who
## could. Ignored once settled: a resident is always there.
@export_range(0.0, 8.0, 0.1) var arrival_weight: float = 1.0

## Earliest act this merchant travels in. The Relic Peddler waits, because a
## relic bought on wave two is a build decided before the run has said anything.
@export_range(1, 3) var first_act: int = 1

## How many waves a visit lasts. Departure is the pressure: an offer that is
## there forever is a menu, and one that leaves is a decision.
@export_range(1, 20) var stay_waves: int = 4

## Gold price per good, before the per-trade jitter. Sized against
## `Balance.TOWER_BUILD_COST` - a merchant's goods are priced in towers-not-built,
## because that is the actual thing being given up.
@export_range(0, 600) var price_gold: int = 70

## A second currency alongside the Gold, so that not every purchase is measured
## against the same wall. Empty means Gold only.
@export var price_currency: String = ""

@export_range(0, 400) var price_amount: int = 0


func get_sprite_path() -> String:
	return GameData.derive_path("city", "merchant_", id)
