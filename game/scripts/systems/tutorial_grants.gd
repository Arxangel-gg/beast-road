class_name TutorialGrants

## **Everything the Walk pays out, in one function, paid once.**
##
## The rule, and it is the whole design: *the Walk grants knowledge and objects.
## It never grants capital, levels, worn power, spells or tower unlocks.* Every
## line below is on that side of it, and the reasoning for each is written
## beside it rather than in a document nobody opens.
##
## **One function, two doors.** The chain-cut calls it and the skip calls it,
## and nothing else does. A skipper is granted exactly what a walker earns:
## any other split makes skipping a mechanical penalty, which makes the tutorial
## a tax rather than a gift - and this codebase holds one bound over every
## optional system, which is that opting out must not cost power. A walker and
## a skipper stand on the first frame of Act I identical.
##
## **The guard is read back from disk, not only written to it.** A once-only
## flag that is serialized and never parsed fires on every launch; this project
## has shipped that exact fault, and it handed out a free sword each time.
## `MetaState.tutorial_walk_done` is written by `mark_walk_done` and read by
## `_read_stats`, and the Walk's gate round-trips a save to prove it.
##
## **What does not cross, and why each would be a real fault:**
##
## - **No Gold, Wood, Food or Stone.** Everything earned in the valley is the
##   Walk's own `RunState` and dies with it. `STARTING_GOLD` is still 0 and
##   `_test_opening_envelope` asserts it, so the opening envelope is untouched
##   by construction: the Walk changes neither the purse nor the enemy.
## - **No spell.** `RunState._equip_starting_spells` falls back to the whole
##   library when `unlocked_spells` is empty, so granting one spell *narrows*
##   the starting pair to one - the gift would make the hero weaker.
## - **No hero experience and no levels.** `curve_report` keys "measured on a
##   NEW account" on the hero's level, and the 0.479-0.563 band was solved on a
##   level-1 account. A tutorial that handed out a level would make every later
##   measurement a measurement of a different game.
## - **No run statistics.** `best_distance` drives which acts may be started
##   from and `runs_started` is what offers the Walk in the first place; writing
##   either would unlock an act for somebody who has not played, and hide the
##   tutorial from them.
## - **No Marks, Shards, Tools, Sigils, ascension, Chronicle or leaderboard.**
## - **`MetaState.tutorial_done` is not set.** Co-op waits for a real road, and
##   the Walk is not one.

## One Common bond, and which. The rabbit that keeps pace with the Warden from
## the long field onward is the one that answers at the end, so the companion
## the account starts with is a creature they have actually met.
const COMPANION_SPECIES: String = "rabbit"

## One common fish, from the pond the Walk fishes.
const FISH_ID: String = "silt_minnow"

## The plan off the smith's post.
##
## **First in `earn_next_blueprint`'s sort order on purpose.** Blueprints are
## bought with Tools in sorted id order, so granting a mid-ladder plan hands
## over a Tools purchase *and* reorders the ladder so the next rung skips one.
## Granting the first simply starts the ladder one rung along, which is a thing
## that can be said honestly.
const BLUEPRINT_ID: String = "plan_barbed_arrow"

## What the valley's timber and copper amount to. Small: a material is an input
## to the Smithy and nothing else, and this is a handful rather than a haul.
const TIMBER: int = 6
const ORE: int = 4

## A little practice, in the three crafts the valley can honestly teach. A
## craft touches nothing but its own craft, so none of this moves an attribute.
const PRACTICE: int = 20


## Pays the ledger. Returns what was granted, for the card and for the gate.
##
## Idempotent by the guard rather than by luck: called twice, the second call
## grants nothing and says so.
static func award() -> Dictionary:
	if MetaState.tutorial_walk_done:
		return {}
	var given: Dictionary = {
		"blueprint": "",
		"bond": "",
		"fish": "",
		"materials": {},
		"practice": [],
	}

	if _has_blueprint(BLUEPRINT_ID) and MetaState.learn_blueprint(BLUEPRINT_ID):
		given["blueprint"] = BLUEPRINT_ID

	# Written through the same door an egg carried home writes: the key a
	# sighting would eventually write, and nothing else. No level, no stat, no
	# second kind of spirit - a raised companion is no stronger than a met one.
	if ContentDB.wildlife_kinds.has(COMPANION_SPECIES):
		if MetaState.bond_from_egg(COMPANION_SPECIES, 0, false):
			given["bond"] = COMPANION_SPECIES

	if ContentDB.fish_kinds.has(FISH_ID) and MetaState.take_fish(FISH_ID):
		given["fish"] = FISH_ID

	var stock: Dictionary = {}
	var timber: String = _commonest(MaterialData.Kind.WOOD)
	var ore: String = _commonest(MaterialData.Kind.ORE)
	if not timber.is_empty() and MetaState.gain_material(timber, TIMBER):
		stock[timber] = TIMBER
	if not ore.is_empty() and MetaState.gain_material(ore, ORE):
		stock[ore] = ORE
	given["materials"] = stock

	var practised: Array[String] = []
	for craft: String in ["angler", "woodcutter", "miner"]:
		if Balance.PROFESSIONS.has(craft):
			MetaState.gain_profession_xp(craft, PRACTICE)
			practised.append(craft)
	given["practice"] = practised

	MetaState.mark_walk_done()
	return given


## Whether the Walk should be offered on the front door.
##
## **Derived rather than stored.** A flag defaulting false would send every
## existing account - the owner's at level 81 included - to the tutorial on the
## next launch. An account that has taken a road has answered this question.
static func should_offer() -> bool:
	return MetaState.runs_started <= 0 and not MetaState.tutorial_walk_done


static func _has_blueprint(id: String) -> bool:
	for value: Variant in ContentDB.blueprints.values():
		var plan := value as BlueprintData
		if plan != null and plan.id == id:
			return true
	return false


## The commonest material of a kind, read off the content rather than named, so
## a region added later cannot leave the valley handing out something that no
## longer exists.
static func _commonest(kind: int) -> String:
	var best: String = ""
	var rarity: int = 99
	for material: MaterialData in ContentDB.materials_sorted():
		if material.kind == kind and material.rarity < rarity:
			rarity = material.rarity
			best = material.id
	return best
