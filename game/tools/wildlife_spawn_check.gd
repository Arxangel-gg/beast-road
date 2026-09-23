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
	_test_every_species_is_voiced_or_declared_silent()
	_test_a_voice_is_pitched_by_the_body()
	_test_animation_coverage()
	_test_ecology(wildlife)
	_test_hoarders(wildlife)
	_test_the_road_goes_quiet(wildlife)
	_test_a_savage_is_actually_savage(wildlife)
	_test_a_hunter_keeps_to_the_players(wildlife)

	if _failures == 0:
		print("[wildlife] PASS - arrivals keep their distance, every tier is "
			+ "reachable, every species animates, predators hunt without eating "
			+ "the collection, and the road goes quiet before a boss")
	else:
		push_error("[wildlife] FAIL - %d problem(s)" % _failures)

	# **Torn down before quitting.** Quitting on top of a live system reports
	# "resources still in use at exit", which is an ERROR line, and the release
	# check fails on any of those - a gate that prints one fails the pipeline it
	# belongs to however green its own verdict is.
	wildlife.grid = null
	wildlife.queue_free()
	# The hush test emits `act_boss_due` and `boss_defeated` on the real bus, and
	# whatever else is listening answers - eight frames is not enough for what
	# that wakes up to be collected again, which showed as leaked instances at
	# exit. Silence first, then give it room, the same way `momentum_check` does.
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 40:
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
		_check(idle >= 4, "%s needs at least four idle poses" % kind.id)
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
	# Every act on the road, not the first three. The seven regions added on
	# 2026-09-11 had no species listing them, and because `roll_weight` treats
	# the act list as a preference rather than a gate, that did not read as
	# missing content - it read as seven regions with no ecology of their own,
	# every animal equally unlikely in each. A loop over [1, 2, 3] could not
	# have seen it.
	for act: int in range(1, Balance.ACT_COUNT + 1):
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


## The road empties before a boss, and fills again once it is down.
##
## Owner request, 2026-09-02. **The warning is the absence**, so what this holds
## is that the absence actually happens and actually ends:
##
## 1. Wildlife stops arriving while something is coming.
## 2. Harmless animals already out there leave.
## 3. The boss falling brings them back - a warning that never lifts is not a
##    warning, it is a wilderness that died.
## 4. It is capped, so a run where `boss_defeated` never arrives cannot leave the
##    road silent for the rest of the act with nothing to say why.
## A hoarder is a prize with a clock: it drops the Gold it carried when it is
## killed, a shiny one always drops gear, and when its patience runs out it
## rifts away rather than walking off the field.
func _test_hoarders(wildlife: Wildlife) -> void:
	var hoarder: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.hoards:
			hoarder = kind
			break
	_check(hoarder != null, "the road needs at least one animal that hoards")
	if hoarder == null:
		return
	_check(hoarder.hoard_gold_max >= hoarder.hoard_gold_min and hoarder.hoard_gold_max > 0,
		"a hoarder must carry Gold, or the chase pays nothing")
	_check(not hoarder.is_hostile() and hoarder.skittish_radius > 0.0,
		"a hoarder runs from the hero rather than fighting; that is the whole chase")
	_check(hoarder.flee_speed_scale * hoarder.speed > Balance.HERO_MOVE_SPEED,
		"a hoarder must outrun a walking hero, or the bow has no reason here")

	var ledger := GDScript.new()
	ledger.source_code = LEDGER_SOURCE
	ledger.reload()
	var stub := EnemyField.new()
	stub.set_script(ledger)
	add_child(stub)
	var previous_field: Node = wildlife.field
	wildlife.field = stub
	var body := Sprite2D.new()
	body.global_position = Vector2(200.0, 0.0)
	wildlife.add_child(body)

	wildlife.call("_drop_the_hoard", {"elite": false, "shiny": false}, hoarder, body.global_position)
	var gold: int = int(stub.get("gold"))
	_check(gold >= hoarder.hoard_gold_min and gold <= hoarder.hoard_gold_max,
		"a killed hoarder must drop the Gold it carried; dropped %d" % gold)
	wildlife.call("_drop_the_hoard", {"elite": false, "shiny": true}, hoarder, body.global_position)
	_check(int(stub.get("gear")) >= 1, "a shiny hoarder must always drop gear")

	var animal: Dictionary = {
		"data": hoarder, "sprite": body, "dying": 0.0, "state": 1,
		"patience": 0.0, "swing": 0.0, "goal": body.global_position,
		"pause": 1.0, "home": body.global_position, "elite": false,
	}
	var alive: bool = bool(wildlife.call("_tick_one", animal, 0.016))
	_check(not alive and bool(animal.get("rifted", false)),
		"a hoarder out of patience must rift away rather than walk off the field")

	wildlife.field = previous_field
	body.queue_free()
	stub.queue_free()


func _test_the_road_goes_quiet(wildlife: Wildlife) -> void:
	var living: Array[Dictionary] = wildlife.get("_living")
	living.clear()
	var prey: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if not kind.is_hostile():
			prey = kind
			break
	if prey == null:
		_check(false, "the road needs something harmless to leave it")
		return

	# Deliberately not parented into the tree. This is the last test the gate
	# runs, so a `queue_free` here never gets a frame to happen in and the
	# release check reports the sprite as a leaked instance. Unparented, it can
	# be freed outright the moment it is done with.
	var deer := Sprite2D.new()
	deer.global_position = Vector2(700.0, 0.0)
	living.append({"data": prey, "sprite": deer, "dying": 0.0, "state": 1})

	_check(not wildlife.is_hushed(), "the road is not holding its breath yet")
	EventBus.act_boss_due.emit(RunState.act)
	_check(wildlife.is_hushed(), "a boss falling due must empty the road")
	_check(int(living[0]["state"]) == 3,
		"and everything harmless on it must leave, state is %d"
			% int(living[0]["state"]))
	_check(Balance.WILDLIFE_HUSH_SECONDS > 0.0
			and Balance.WILDLIFE_HUSH_SECONDS < 900.0,
		"the hush must be capped at something a run can outlive, is %.0fs"
			% Balance.WILDLIFE_HUSH_SECONDS)

	EventBus.boss_defeated.emit("probe", RunState.act)
	_check(not wildlife.is_hushed(),
		"and the road must come back to life once the boss is down")

	living.clear()
	deer.free()


## A field that only counts what lands on it, for the hoarder test.
const LEDGER_SOURCE: String = "extends \"res://scripts/systems/enemy_field.gd\"\nvar gold: int = 0\nvar gear: int = 0\nfunc spawn_loot(currency: String, amount: int, _at: Vector2) -> void:\n\tif currency == \"gold\":\n\t\tgold += amount\nfunc spawn_gear(_piece: Dictionary, _at: Vector2) -> void:\n\tgear += 1\n"


## **Every species has a voice, or is declared silent on purpose.**
##
## Thirty-three of fifty-one species carried no `vocal_sfx` - including every
## animal added for acts IV to X - so two thirds of the ecology was mute and
## nothing said whether that was a decision. Voices are *shared* here and always
## have been (the griffon takes the hawk's, the moonstag the deer's), so the fix
## for most of them was a judgement rather than a recording.
##
## The ledger is the point. A blank `vocal_sfx` cannot tell "nobody has got to
## this one" apart from "a scorpion does not make a noise", and this project has
## paid for that ambiguity before - `DisciplineEffects.DECLARED_ONLY` exists for
## exactly this reason: a thing that cannot be wired yet belongs on a list,
## visibly, rather than missing from both.
const SILENT: Dictionary = {
	"butterfly_azure": "a butterfly is silent",
	"butterfly_monarch": "a butterfly is silent",
	"butterfly_swallowtail": "a butterfly is silent",
	"glass_moth": "a moth is silent",
	"iron_beetle": "a beetle is silent",
	"salt_crab": "a crab is silent",
	"scorpion": "a scorpion is silent",
	"reedback_terrapin": "a terrapin is silent",
	"tortoise": "a tortoise is silent",
}


func _test_every_species_is_voiced_or_declared_silent() -> void:
	var voiced: int = 0
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null:
			continue
		if not kind.vocal_sfx.is_empty():
			voiced += 1
			_check(Sfx.SOUNDS.has(kind.vocal_sfx) or Sfx.GROUPS.has(kind.vocal_sfx),
				("%s speaks with \"%s\", which is neither a sound nor a group"
					% [kind.id, kind.vocal_sfx]))
			continue
		_check(SILENT.has(kind.id),
			("%s has no voice and is not declared silent - a blank vocal_sfx "
				+ "cannot say whether that is a decision") % kind.id)
	_check(voiced >= 40, "only %d species have a voice" % voiced)
	for id: Variant in SILENT:
		var kind := ContentDB.wildlife_kinds.get(String(id)) as WildlifeData
		_check(kind != null, "%s is declared silent and is not a species" % str(id))
		if kind != null:
			_check(kind.vocal_sfx.is_empty(),
				"%s is declared silent and also has a voice" % str(id))


## **A voice is pitched by the body that makes it.**
##
## Twenty-three species share one of the twelve recordings, so without this a
## fennec is a fox and a jackal is a wolf - the sharing that makes a fifty-one
## species roster affordable is also what makes them identical if nothing
## separates them afterwards.
##
## Measured off `Wildlife.voice_pitch` rather than read back off the constants,
## because what must hold is the *ordering*: bigger is lower, smaller is higher,
## a cub is higher than its mother, and nothing ever leaves the clamp.
func _test_a_voice_is_pitched_by_the_body() -> void:
	var small: WildlifeData = null
	var large: WildlifeData = null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null:
			continue
		if small == null or kind.scale < small.scale:
			small = kind
		if large == null or kind.scale > large.scale:
			large = kind
	_check(small != null and large != null, "the roster has a smallest and a largest")
	if small == null or large == null:
		return
	var high: float = Wildlife.voice_pitch(small)
	var low: float = Wildlife.voice_pitch(large)
	_check(high > low,
		("%s (scale %.2f) must speak higher than %s (scale %.2f): %.3f vs %.3f"
			% [small.id, small.scale, large.id, large.scale, high, low]))
	_check(low < 0.0 and high > 0.0,
		"the shift straddles zero, so an average animal is unshifted (%.3f..%.3f)"
			% [low, high])
	# A cub out of the same throat is reedier than its mother.
	_check(Wildlife.voice_pitch(large, 0.5) > Wildlife.voice_pitch(large, 1.0),
		"a young %s must speak higher than a grown one" % large.id)
	# Never outside the clamp, whatever is authored.
	for kind: WildlifeData in ContentDB.wildlife():
		if kind == null:
			continue
		for size: float in [0.4, 0.7, 1.0]:
			var ratio: float = 1.0 + Wildlife.voice_pitch(kind, size)
			_check(ratio >= Balance.WILDLIFE_VOICE_PITCH_MIN - 0.001
				and ratio <= Balance.WILDLIFE_VOICE_PITCH_MAX * 1.2,
				"%s at size %.1f pitches to %.3f, outside the clamp"
					% [kind.id, size, ratio])
	# And nothing may be pitched so far it stops sounding like the recording.
	_check(Balance.WILDLIFE_VOICE_PITCH_MIN > 0.5 and Balance.WILDLIFE_VOICE_PITCH_MAX < 2.0,
		"the clamp allows a ratio that no longer sounds like the animal")


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[wildlife] FAIL: %s" % why)


## **A savage has to be worth having provoked.**
##
## Over-farming a species sends a savage of that kind after the hunter, and the
## constants describe it as "bigger, tougher, harder-hitting and faster". It
## arrived five and a half times as tough, half again as large, tinted, lit,
## rabid and worth six times the bounty - and `HUNT_SAVAGE_DAMAGE` and
## `HUNT_SAVAGE_SPEED` were read by nothing at all, so it bit for exactly what
## an ordinary animal of its kind bites for and walked at exactly its pace.
##
## Nothing caught it because nothing tested the hunt: this gate covered spawn
## clearance, rarity, animation, the ecology and the pre-boss hush, and the
## savage not at all. Found by auditing every constant in Balance.gd for a
## consumer, on 2026-09-13.
##
## Measured through the real functions rather than against the constants, and at
## both places a bite is worked out - the spirit at your shoulder is bitten by
## different code from the hero, and applying a multiplier to one of the two is
## exactly the shape of the fault this is replacing.
func _test_a_savage_is_actually_savage(wildlife: Wildlife) -> void:
	var kind: WildlifeData = null
	for species: WildlifeData in ContentDB.wildlife():
		if species != null and species.damage > 0.0:
			kind = species
			break
	_check(kind != null, "no species in the roster bites at all")
	if kind == null:
		return
	var ordinary: Dictionary = {"size": 1.0}
	var savage: Dictionary = {"size": 1.0, "savage": true}
	var plain_bite: float = float(wildlife.call("_bite_of", ordinary, kind))
	var savage_bite: float = float(wildlife.call("_bite_of", savage, kind))
	_check(plain_bite > 0.0, "an ordinary animal of a biting species must bite")
	_check(savage_bite > plain_bite,
		("a savage %s bites for %.1f against an ordinary %.1f - it is five and a "
			+ "half times as tough and worth six times the bounty, so a bite that "
			+ "lands the same is a chore rather than a consequence")
			% [kind.id, savage_bite, plain_bite])
	var plain_pace: float = float(wildlife.call("_savage_speed", ordinary))
	var savage_pace: float = float(wildlife.call("_savage_speed", savage))
	_check(is_equal_approx(plain_pace, 1.0),
		"an ordinary animal must move at its own pace, got %.2f" % plain_pace)
	_check(savage_pace > plain_pace,
		("a savage moves at %.2f of its kind's pace - it is sent to hunt, and "
			+ "something that cannot close is not hunting") % savage_pace)


## **A beast sent after the players hunts the players** (owner, 2026-09-22: they
## "run off and attack a camp ... or get lost"). A savage is also rabid, which
## lends it the frenzy's reach and its appetite for everything; offered a road
## or camp body and no Warden, it must take neither. A frenzied animal that was
## *not* sent after anybody still attacks whatever is near - that is the
## Wildblight, and it is unchanged.
func _test_a_hunter_keeps_to_the_players(wildlife: Wildlife) -> void:
	var kind: WildlifeData = null
	for species: WildlifeData in ContentDB.wildlife():
		if species != null and species.damage > 0.0 and species.aggro_radius > 0.0:
			kind = species
			break
	_check(kind != null, "no predator to send")
	if kind == null:
		return
	var stub := HuntField.new()
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		breed = value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED:
			break
	var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
	add_child(stub)
	body.setup(breed, 1, stub, 1.0, 1.0, 1.0)
	stub.add_child(body)
	body.global_position = Vector2(40.0, 0.0)
	stub.bodies.append(body)
	var was: Node = wildlife.field
	wildlife.field = stub
	var savage: Dictionary = {"savage": true, "rabid": true}
	var robbed: Dictionary = {"angered": true}
	var frenzied: Dictionary = {"rabid": true}
	_check(wildlife.hunts_the_players(savage) and wildlife.hunts_the_players(robbed),
		"a savage and a robbed parent must both count as hunting the players")
	_check(not wildlife.hunts_the_players(frenzied),
		"a frenzy with nobody to blame must not count as hunting the players")
	var for_savage: Variant = wildlife.call("_quarry_for", Vector2.ZERO, kind, null,
		true, false, false, true)
	_check(for_savage == null,
		"a savage sent after the players took a road body for its quarry - it detours into camps")
	var for_frenzy: Variant = wildlife.call("_quarry_for", Vector2.ZERO, kind, null,
		true, false, false, false)
	_check(for_frenzy == body, "a plain frenzy no longer attacks the body beside it")
	wildlife.field = was
	stub.queue_free()


class HuntField extends EnemyField:
	var bodies: Array[Enemy] = []

	func enemies_near(_at: Vector2, _radius: float) -> Array[Enemy]:
		return bodies
