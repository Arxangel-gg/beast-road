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
	_test_one_animal_is_one_encounter()
	_test_shiny_odds_are_reachable()
	await _test_a_spirit_fights_falls_and_returns()
	_finish()


func _test_rarer_needs_fewer() -> void:
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
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


## The one property the whole system's appeal rests on.
func _test_the_power_ladder_is_ordered() -> void:
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
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


func _test_a_shiny_also_feeds_the_plain_variant() -> void:
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
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


func _test_recovery_favours_rarity() -> void:
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
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


func _test_the_collection_survives_a_save() -> void:
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
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


func _test_keys_round_trip() -> void:
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
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


func _finish() -> void:
	if _ran != 9:
		_failures += 1
		print("[spirit] only %d of 9 tests ran" % _ran)
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


## **The anti-farm rule.** One animal is one encounter, however many times it is
## hit or approached.
##
## Without it a player bonds a Legendary by hitting the same deer repeatedly, or
## by stepping in and out of a tortoise's bond radius - and the whole collection
## collapses into standing next to one animal. This drives the real crediting
## path rather than calling `record_spirit_encounter` directly, because the flag
## that prevents it lives on the animal rather than in the rules.
func _test_one_animal_is_one_encounter() -> void:
	var wildlife := Wildlife.new()
	add_child(wildlife)
	MetaState.hold_saves()
	var before_counts: Dictionary = MetaState.spirit_encounters.duplicate(true)
	var before_bonded: Dictionary = MetaState.spirit_bonded.duplicate(true)
	MetaState.spirit_encounters = {}
	MetaState.spirit_bonded = {}

	var deer := ContentDB.wildlife_kinds.get("deer", null) as WildlifeData
	_check(deer != null, "the deer is needed to test crediting")
	if deer != null:
		var animal: Dictionary = {"data": deer, "shiny": false, "credited": false}
		for _attempt: int in 12:
			wildlife._credit_encounter(animal, SpiritBond.Kind.BONDED)
		var key: String = SpiritBond.key(deer.id, deer.rarity, false)
		_check(MetaState.spirit_encounter_count(key) == 1,
			"twelve attempts on one animal banked %d encounters - one animal is "
				% MetaState.spirit_encounter_count(key) + "one encounter")

		# A second animal of the same variant is a second encounter, or the
		# collection could never be finished at all.
		var another: Dictionary = {"data": deer, "shiny": false, "credited": false}
		wildlife._credit_encounter(another, SpiritBond.Kind.BONDED)
		_check(MetaState.spirit_encounter_count(key) == 2,
			"a different animal of the same variant must count again")

	MetaState.spirit_encounters = before_counts
	MetaState.spirit_bonded = before_bonded
	MetaState.resume_saves()
	wildlife.queue_free()
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


## The odds have to make every row of the journal reachable in a lifetime.
func _test_shiny_odds_are_reachable() -> void:
	for tier: int in 4:
		var chance: float = Balance.SPIRIT_SHINY_CHANCE[tier]
		_check(chance > 0.0, "rarity %d can never shine, so its shiny rows are dead" % tier)
		_check(chance <= 0.25,
			"a %.0f%% shiny chance at rarity %d stops being a surprise"
				% [chance * 100.0, tier])
	# **Legendary is the most generous on purpose.** A Legendary sighting is
	# already rare; stacking a 2% roll on top would make Shiny Legendary a row
	# nobody ever fills. If that inverts, the apex of the whole system becomes
	# unreachable and nothing else in this gate would notice.
	_check(Balance.SPIRIT_SHINY_CHANCE[3] >= Balance.SPIRIT_SHINY_CHANCE[0],
		"a Legendary must not be less likely to shine than a Common, or the "
			+ "apex variant is unreachable")
	# And the bond radius has to be inside every skittish radius, or approaching
	# a nervous animal is not the skill check it is meant to be.
	for value: Variant in ContentDB.wildlife():
		var kind := value as WildlifeData
		if kind == null or kind.is_hostile() or kind.skittish_radius <= 0.0:
			continue
		_check(Balance.SPIRIT_BOND_RADIUS < kind.skittish_radius,
			"%s bolts at %.0f and bonds at %.0f - a bond must be closer than the "
				% [kind.id, kind.skittish_radius, Balance.SPIRIT_BOND_RADIUS]
				+ "flee, or there is nothing to approach")
	# Counted here rather than on entry. A runtime error aborts the
	# function it happens in, so a counter incremented at the top marks a
	# test that never ran as having run - which is exactly how this gate
	# printed PASS while an Invalid call skipped every assertion below it.
	_ran += 1


## A spirit is summoned, can be hurt, falls, and comes back beside the hero.
##
## The whole point of a spirit rather than a summon is what happens at the end,
## so that is what this drives: it is put on a field with something that hurts,
## beaten down, and watched until it re-forms.
##
## **`companion_form` is exercised rather than asserted about.** Every one of the
## 184 variants is built by that function at runtime, so a mistake in it is a
## mistake in every spirit in the game at once.
func _test_a_spirit_fights_falls_and_returns() -> void:
	var wolf := ContentDB.wildlife_kinds.get("wolf", null) as WildlifeData
	_check(wolf != null, "the wolf is needed to test a spirit")
	if wolf == null:
		_ran += 1
		return

	var apex: String = SpiritBond.key("wolf", 3, true)
	var base: String = SpiritBond.key("wolf", 0, false)
	var strong: CompanionData = SpiritBond.companion_form(wolf, apex)
	var weak: CompanionData = SpiritBond.companion_form(wolf, base)
	_check(strong != null and weak != null, "every variant must produce a form")
	if strong == null or weak == null:
		_ran += 1
		return
	_check(strong.damage > weak.damage,
		"the apex variant must hit harder than the base: %.1f against %.1f"
			% [strong.damage, weak.damage])
	_check(strong.duration == INF,
		"a spirit must not expire - that is the whole difference from a summon")
	_check(not strong.display_name.is_empty()
			and strong.display_name.contains("Shiny"),
		"a shiny variant must say so in its name, got '%s'" % strong.display_name)

	var field := EnemyField.new()
	add_child(field)
	var spirit := Companion.new()
	spirit.spirit_key = base
	spirit.setup(weak, null, field)
	field.add_child(spirit)
	await get_tree().process_frame
	_check(spirit.spirit_health_ratio() > 0.99, "a fresh spirit starts whole")
	_check(is_zero_approx(spirit.recovery_left()),
		"and is present rather than recovering")

	# Beaten down, then watched until it re-forms. The recovery is driven rather
	# than waited out: this is a forty-five second clock and a gate must not take
	# forty-five seconds to check it.
	spirit._hp = 0.0
	spirit._go_down()
	_check(spirit.recovery_left() > 0.0,
		"a defeated spirit must begin re-forming rather than being freed")
	_check(is_equal_approx(spirit.recovery_left(),
			SpiritBond.recovery_seconds(0, false)),
		"and must take its variant's own recovery, %.0fs"
			% SpiritBond.recovery_seconds(0, false))
	spirit._tick_recovery(SpiritBond.recovery_seconds(0, false) + 1.0)
	_check(is_zero_approx(spirit.recovery_left()), "the clock must run out")
	_check(spirit.spirit_health_ratio() > 0.99,
		"and it must come back whole rather than at the health it fell on")

	field.queue_free()
	await get_tree().process_frame
	_check(not is_instance_valid(spirit),
		"the spirit must be freed with its field, or this gate leaks")
	_ran += 1
