extends Node

## Animals arrive from the wild, not from the town square.
##
## Wildlife inherited the foliage rule for keeping off the city - 340 units,
## which is a reed's distance. Deer and wolves appeared close enough to the base
## to read as attacking it, and a predator that noticed the hero standing there
## was on them before the player saw it coming. Reported twice from play.
##
## The distance is the whole fix, so it is the thing measured: every point the
## spawner offers, over enough draws that a rare bad one would show.

const DRAWS: int = 600

## The least share of an act's roll a tier may hold and still count as present.
## A Legendary out of its own region sits near this; anything below it is
## content nobody will meet, which is the same as content that is not there.
const MIN_TIER_SHARE: float = 0.002

var _failures: int = 0


func _ready() -> void:
	var wildlife := Wildlife.new()
	wildlife.grid = BattleGrid.new()
	add_child(wildlife)

	var closest: float = INF
	var offered: int = 0
	for i: int in DRAWS:
		var at: Vector2 = wildlife.call("_clear_point")
		if at == Vector2.ZERO:
			continue
		offered += 1
		closest = minf(closest, at.length())

	# It must still find somewhere. A clearance that rejects the whole field
	# would read as "the wilderness is empty" rather than as a bug.
	_check(offered > DRAWS / 2,
		"the spawner must still find room, offered %d of %d" % [offered, DRAWS])
	_check(closest >= Balance.WILDLIFE_SPAWN_CLEARANCE,
		"nothing may arrive within %.0f of the city, closest was %.0f"
			% [Balance.WILDLIFE_SPAWN_CLEARANCE, closest])
	print("[wildlife] %d of %d points offered, closest %.0f (floor %.0f)"
		% [offered, DRAWS, closest, Balance.WILDLIFE_SPAWN_CLEARANCE])

	_test_rarity_coverage()
	_test_animation_coverage()
	_test_ecology(wildlife)

	if _failures == 0:
		print("[wildlife] PASS - arrivals keep their distance, every tier is "
			+ "reachable, every species animates, and predators hunt without "
			+ "eating the collection")
	else:
		printerr("[wildlife] FAIL - %d problem(s)" % _failures)

	# **Torn down before quitting.** Quitting on top of a live system reports
	# "resources still in use at exit", which is an ERROR line, and the release
	# check fails on any of those - a gate that prints one fails the pipeline it
	# belongs to however green its own verdict is.
	wildlife.grid = null
	wildlife.queue_free()
	for _frame: int in 8:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


## Every species has the sequences its own data says it needs.
##
## **A missing sequence is silent.** `_load_sequence` returns an empty array for
## a creature with no frames and the animator falls back to the static pose, so
## nothing errors and nothing warns - the animal simply stands there. Five of the
## six predators shipped that way for months while every harmless animal
## breathed, and it was found by counting files, not by playing.
##
## What is required is read from the resource rather than listed here, so adding
## a species adds its own requirements: everything needs an idle pose and a walk
## pair, anything that will fight needs an attack, and anything that leaves the
## ground needs a flight cycle. A flier is excused its walk - it is airborne
## whenever it is moving, so those frames would never be drawn.
func _test_animation_coverage() -> void:
	for kind: WildlifeData in ContentDB.wildlife():
		var base: String = kind.get_sprite_path()
		var idle: int = GameData.load_idle_frames(base).size()
		var move: int = GameData.load_move_frames(base).size()
		var fly: int = GameData.load_flight_frames(base).size()
		var attack: int = GameData.load_attack_frames(base).size()
		_check(idle >= 1, "%s has no idle frame, so it stands frozen" % kind.id)
		if kind.flies:
			_check(fly >= 2, "%s flies but has no flight cycle" % kind.id)
		else:
			_check(move >= 2, "%s has no walk cycle (%d frames)" % [kind.id, move])
		if kind.temperament >= WildlifeData.Temperament.TERRITORIAL:
			_check(attack >= 1, "%s will fight but has no attack frames" % kind.id)


## Four tiers, both temperaments, all three acts (owner request, 2026-08-31).
##
## The interesting half is that the acts are a *preference*, not a gate. Before
## this, `_refresh_kinds` dropped every species whose `acts` list omitted the
## current act, so Act III's roster was whatever happened to list a 3 - and a
## tier could simply be absent from a whole act with nothing to say so. The
## weighting replaced the filter, and this is what holds the replacement honest:
## it asserts reachability, which is the property the filter destroyed, rather
## than asserting frequency, which is a tuning question.
func _test_rarity_coverage() -> void:
	var kinds: Array = ContentDB.wildlife()
	_check(not kinds.is_empty(), "there must be wildlife to roll")
	for kind: WildlifeData in kinds:
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no sprite at %s" % [kind.id, kind.get_sprite_path()])

	# A share of the act's roll, not merely a weight above zero. `roll_weight`
	# never returns zero for anything in the roster, so "> 0.0" would have been
	# three identical assertions wearing an act number - it would pass on a
	# species one player in ten thousand would ever meet.
	for act: int in [1, 2, 3]:
		var total: float = 0.0
		for kind: WildlifeData in kinds:
			total += kind.roll_weight(act)
		_check(total > 0.0, "act %d can roll nothing at all" % act)
		if total <= 0.0:
			continue
		for hostile: bool in [false, true]:
			var share: Dictionary = {}
			for kind: WildlifeData in kinds:
				# Territorial and predatory are the two that will start a fight.
				var dangerous: bool = kind.temperament >= WildlifeData.Temperament.TERRITORIAL
				if dangerous != hostile:
					continue
				share[kind.rarity] = float(share.get(kind.rarity, 0.0)) 					+ kind.roll_weight(act) / total
			var side: String = "dangerous" if hostile else "harmless"
			for tier: int in [WildlifeData.Rarity.COMMON, WildlifeData.Rarity.UNCOMMON,
					WildlifeData.Rarity.RARE, WildlifeData.Rarity.LEGENDARY]:
				var seen: float = float(share.get(tier, 0.0))
				_check(seen >= MIN_TIER_SHARE,
					"act %d gives %s tier %d only %.2f%% of the roll (floor %.2f%%)"
						% [act, side, tier, seen * 100.0, MIN_TIER_SHARE * 100.0])


## Predators notice the small things, and cannot touch them.
##
## Owner request, 2026-09-01: the world should carry on when the player is not
## involved. The whole design rests on one bound, and it is the bound this tests:
## **a chase, never a meal.**
##
## `Wildlife._strike` accepts a Hero or an Enemy and refuses everything else. If
## that check is ever loosened - broadened to "anything with health", say, or
## given a group instead of two types - predators immediately start eating the
## wildlife, and the first thing a player loses is a Spirit Companion they were
## three encounters away from bonding. Nothing would report it; the animals would
## simply stop being there.
##
## Also that prey is not helpless: a predator inside the skittish radius has to
## start a bolt, or the chase is one animal walking at another that ignores it.
func _test_ecology(wildlife: Wildlife) -> void:
	var predator: WildlifeData = null
	var prey: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if predator == null and kind.is_hostile() and kind.aggro_radius > 0.0:
			predator = kind
		if prey == null and not kind.is_hostile() and kind.skittish_radius > 0.0:
			prey = kind
	_check(predator != null and prey != null,
		"the road needs something that hunts and something that runs")
	if predator == null or prey == null:
		return

	# A rabbit standing in front of a wolf.
	# Placed as a fraction of the predator's own reach rather than at a fixed
	# distance, so the test does not depend on which species happened to sort
	# first in the content directory.
	var rabbit := Sprite2D.new()
	rabbit.global_position = Vector2(
		predator.aggro_radius * Balance.WILDLIFE_PREY_INTEREST * 0.5, 0.0)
	wildlife.add_child(rabbit)
	var living: Array[Dictionary] = wildlife.get("_living")
	living.append({
		"data": prey, "sprite": rabbit, "dying": 0.0, "state": 1,
	})

	var noticed: Node2D = wildlife.call("_quarry_for", Vector2.ZERO, predator, null)
	_check(noticed == rabbit,
		"a predator with nothing else in reach must notice prey")

	# **The bound.** Pointed at it, the predator must be unable to hurt it.
	var before: int = living.size()
	wildlife.call("_strike", living[0], rabbit, predator, rabbit)
	_check(float(living[0].get("dying", 0.0)) <= 0.0,
		"a predator must not be able to kill wildlife - `_strike` accepts a Hero "
			+ "or an Enemy and nothing else, and that is what keeps the ecology "
			+ "atmosphere rather than a second attrition system")
	_check(living.size() == before, "and must not remove it from the field")

	# And prey runs. Asked at the rabbit's own position with the wolf beside it.
	var wolf := Sprite2D.new()
	wolf.global_position = rabbit.global_position 		+ Vector2(prey.skittish_radius * 0.4, 0.0)
	wildlife.add_child(wolf)
	living.append({
		"data": predator, "sprite": wolf, "dying": 0.0, "state": 1,
	})
	_check(bool(wildlife.call("_frightened", rabbit.global_position, prey)),
		"prey must bolt from a predator inside its skittish radius, or the hunt "
			+ "is one animal walking at another that has not noticed")

	living.clear()
	rabbit.queue_free()
	wolf.queue_free()


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[wildlife] FAIL: %s" % why)
