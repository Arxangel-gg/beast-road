extends Node

## The Wildlife Spirit Companion collection: its rules, and its save.
##
## Owner decision, 2026-09-01. The loop is meant to be understood from playing —
## see an animal, meet that exact variant enough times, its spirit is yours — so
## the properties worth gating are the ones a player would notice being wrong:
##
## 1. **Rarer needs fewer.** If a Legendary took more encounters than a Common,
##    the tier that is hardest to find would also be the longest to finish, and
##    a Legendary sighting would read as a chore rather than an event.
## 2. **The power ladder is strictly ordered.** Shiny Common above Common and
##    below Uncommon, all the way up. Any inversion makes a variant that is
##    rarer and *worse*, which is the single most disappointing thing a
##    collection system can do.
## 3. **A shiny is never worth less than a plain one.** A shiny encounter feeds
##    the ordinary variant of the same rarity too, so a player hunting a normal
##    Rare Wolf never groans at finding a shiny.
## 4. **Higher rarity recovers faster.** Punishing the best companion with the
##    longest absence would make owning it worse.
## 5. **The save round-trips, and an old save is not corrupted by it.**

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	_test_rarer_needs_fewer()
	_test_the_power_ladder_is_ordered()
	_test_a_shiny_also_feeds_the_plain_variant()
	_test_recovery_favours_rarity()
	_test_the_collection_survives_a_save()
	_test_keys_round_trip()
	_finish()


func _test_rarer_needs_fewer() -> void:
	_ran += 1
	for tier: int in 3:
		_check(SpiritBond.needed(tier + 1, false) <= SpiritBond.needed(tier, false),
			"rarity %d needs %d encounters and %d needs %d - rarer must never need more"
				% [tier, SpiritBond.needed(tier, false),
					tier + 1, SpiritBond.needed(tier + 1, false)])
		_check(SpiritBond.needed(tier + 1, true) <= SpiritBond.needed(tier, true),
			"the same must hold for shinies at rarity %d" % tier)
	for tier: int in 4:
		_check(SpiritBond.needed(tier, true) <= SpiritBond.needed(tier, false),
			"a shiny at rarity %d needs %d against the plain %d - finding the shiny "
				% [tier, SpiritBond.needed(tier, true), SpiritBond.needed(tier, false)]
				+ "is already the grind")
		_check(SpiritBond.needed(tier, false) >= 1,
			"every variant must need at least one encounter")
	_check(SpiritBond.needed(3, false) == 1,
		"a Legendary sighting should complete its bond outright")


## The one property the whole system's appeal rests on.
func _test_the_power_ladder_is_ordered() -> void:
	_ran += 1
	var ladder: Array[float] = []
	var names: PackedStringArray = []
	for rarity: int in 4:
		for shiny: bool in [false, true]:
			ladder.append(SpiritBond.power_scale(rarity, shiny))
			names.append("%s%s" % ["shiny " if shiny else "",
				Balance.SPIRIT_RARITY_NAMES[rarity]])
			_check(SpiritBond.power_step(rarity, shiny) == rarity * 2 + (1 if shiny else 0),
				"the ladder step for %s is not where it belongs" % names[names.size() - 1])
	for index: int in ladder.size() - 1:
		_check(ladder[index + 1] > ladder[index],
			"%s (%.3f) must be stronger than %s (%.3f), or a rarer variant is worse"
				% [names[index + 1], ladder[index + 1], names[index], ladder[index]])
	_check(is_equal_approx(ladder[0], 1.0),
		"the base variant must be the baseline, got %.3f" % ladder[0])
	# Bounded, or everything below the apex becomes worthless.
	_check(ladder[ladder.size() - 1] <= 3.0,
		"an apex %.2fx the base makes every lower tier pointless"
			% ladder[ladder.size() - 1])


func _test_a_shiny_also_feeds_the_plain_variant() -> void:
	_ran += 1
	MetaState.hold_saves()
	var before_counts: Dictionary = MetaState.spirit_encounters.duplicate(true)
	var before_bonded: Dictionary = MetaState.spirit_bonded.duplicate(true)
	MetaState.spirit_encounters = {}
	MetaState.spirit_bonded = {}

	var plain: String = SpiritBond.key("wolf", 2, false)
	var shiny: String = SpiritBond.key("wolf", 2, true)
	var result: Dictionary = MetaState.record_spirit_encounter("wolf", 2, true)
	_check(MetaState.spirit_encounter_count(shiny) == 1,
		"a shiny encounter must progress the shiny variant")
	_check(MetaState.spirit_encounter_count(plain) == 1,
		"and the plain variant of the same rarity, or finding something rarer "
			+ "would be worth less than finding something ordinary")
	_check((result["discovered"] as Array).size() == 2,
		"both variants were new, so both are discoveries")

	# And a plain encounter must not feed the shiny, which would make shinies
	# obtainable without ever seeing one.
	MetaState.record_spirit_encounter("wolf", 2, false)
	_check(MetaState.spirit_encounter_count(plain) == 2,
		"a plain encounter progresses the plain variant")
	_check(MetaState.spirit_encounter_count(shiny) == 1,
		"a plain encounter must never progress the shiny")

	# Bonding fires once, on the encounter that completes it.
	MetaState.spirit_encounters = {}
	MetaState.spirit_bonded = {}
	var needed: int = SpiritBond.needed(0, false)
	var bonds: int = 0
	for _meeting: int in needed + 3:
		bonds += (MetaState.record_spirit_encounter("rabbit", 0, false)["bonded"] as Array).size()
	_check(bonds == 1,
		"a bond must complete exactly once across %d encounters, got %d"
			% [needed + 3, bonds])
	_check(MetaState.spirit_encounter_count(SpiritBond.key("rabbit", 0, false)) == needed + 3,
		"encounters past the threshold are still counted - the journal shows "
			+ "them rather than pretending they did not happen")

	MetaState.spirit_encounters = before_counts
	MetaState.spirit_bonded = before_bonded
	MetaState.resume_saves()


func _test_recovery_favours_rarity() -> void:
	_ran += 1
	for tier: int in 3:
		_check(SpiritBond.recovery_seconds(tier + 1, false)
				< SpiritBond.recovery_seconds(tier, false),
			"rarity %d recovers in %.0fs and %d in %.0fs - the better companion "
				% [tier, SpiritBond.recovery_seconds(tier, false), tier + 1,
					SpiritBond.recovery_seconds(tier + 1, false)]
				+ "must not be the one that is missing longer")
	for tier: int in 4:
		_check(SpiritBond.recovery_seconds(tier, true)
				<= SpiritBond.recovery_seconds(tier, false),
			"a shiny must not recover slower than its plain variant")
	# No spirit may be gone so long that equipping it feels like a punishment.
	_check(SpiritBond.recovery_seconds(0, false) <= 60.0,
		"a recovery of %.0fs is long enough to feel like a death penalty"
			% SpiritBond.recovery_seconds(0, false))


func _test_the_collection_survives_a_save() -> void:
	_ran += 1
	MetaState.hold_saves()
	var before_counts: Dictionary = MetaState.spirit_encounters.duplicate(true)
	var before_bonded: Dictionary = MetaState.spirit_bonded.duplicate(true)
	var before_equipped: String = MetaState.equipped_spirit

	MetaState.spirit_encounters = {}
	MetaState.spirit_bonded = {}
	MetaState.record_spirit_encounter("fox", 3, true)
	var apex: String = SpiritBond.key("fox", 3, true)
	_check(MetaState.spirit_is_bonded(apex),
		"a Legendary needs one encounter, so that one must have bonded it")
	_check(MetaState.equip_spirit(apex), "a bonded spirit must be equippable")

	var written: String = MetaState.serialized_save()
	MetaState.spirit_encounters = {}
	MetaState.spirit_bonded = {}
	MetaState.equipped_spirit = ""
	var parsed: Variant = JSON.parse_string(written)
	_check(parsed is Dictionary, "the save must be readable JSON")
	if parsed is Dictionary:
		MetaState._read_spirits((parsed as Dictionary).get("spirits", {}) as Dictionary)
	_check(MetaState.spirit_is_bonded(apex), "a bond must survive the round trip")
	_check(MetaState.equipped_spirit == apex, "and so must the equipped slot")

	# **An old save is the case that must not break.** One written before spirits
	# existed has no "spirits" key at all, and must read as an empty collection
	# rather than as an error or a half-populated one.
	MetaState._read_spirits({})
	_check(MetaState.spirit_encounters.is_empty() and MetaState.spirit_bonded.is_empty(),
		"a save with no spirits block must load as an empty collection")
	_check(MetaState.equipped_spirit.is_empty(),
		"and must equip nothing rather than something it does not have")

	# A slot pointing at an unbonded spirit is an edited or older save, and is
	# safer cleared than summoned.
	MetaState._read_spirits({"equipped": SpiritBond.key("bear", 3, true)})
	_check(MetaState.equipped_spirit.is_empty(),
		"an equipped spirit that is not bonded must be dropped, not summoned")

	MetaState.spirit_encounters = before_counts
	MetaState.spirit_bonded = before_bonded
	MetaState.equipped_spirit = before_equipped
	MetaState.resume_saves()


func _test_keys_round_trip() -> void:
	_ran += 1
	for species: String in ["wolf", "snow_lynx", "frost_elk"]:
		for rarity: int in 4:
			for shiny: bool in [false, true]:
				var key: String = SpiritBond.key(species, rarity, shiny)
				_check(SpiritBond.species_of(key) == species,
					"%s lost its species" % key)
				_check(SpiritBond.rarity_of(key) == rarity, "%s lost its rarity" % key)
				_check(SpiritBond.shiny_of(key) == shiny, "%s lost its shine" % key)
	# Eight rows per species, which is what the journal draws.
	_check(SpiritBond.variants_of("wolf").size() == 8,
		"a species offers four rarities in plain and shiny")
	# Every species in the game can be collected: the roster is the content.
	var species_count: int = ContentDB.wildlife().size()
	_check(species_count >= 20,
		"only %d species can be bonded; the roster should be far larger" % species_count)


func _finish() -> void:
	if _ran != 6:
		_failures += 1
		print("[spirit] only %d of 6 tests ran" % _ran)
	if _failures == 0:
		print("[spirit] PASS - rarer needs fewer, the ladder never inverts, a shiny "
			+ "is never worth less, and the collection survives a save")
	else:
		push_error("[spirit] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[spirit] %s" % why)
