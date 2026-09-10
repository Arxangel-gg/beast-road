extends Node

## Healing orbs and supply crates: rare, scaled by what dropped them, and bounded.
##
## Owner brief, 2026-09-10. Two drops, one design: a small helping hand beside
## the Mender's Spark, "while maintaining game's balance... tuned to each
## enemy's rarity and power while still being rare".
##
## Every claim in that sentence is a number somebody will want to move later, so
## every one of them is asserted here rather than left in a comment:
##
## - **Rare.** A breed's chance has to stay a long way under a coin's, or the
##   road becomes a health bar with enemies on it.
## - **Tuned to rarity.** An elite must be worth more than a breed and a boss
##   more than an elite, in both drops.
## - **Tuned to power.** A body worth more must heal for more.
## - **Bounded.** And none of that may add up to a heal that pays for a mistake
##   the difficulty curve exists to punish - which is the one that stops being
##   true quietly, three retunes from now.
##
## The Spark is the control. It is one per act, elite-only and gated on being
## badly hurt; an orb that healed as much as one would have made it pointless.

## A field that records what was spawned into it.
##
## `EnemyField.spawn_loot` is a no-op on the base class - only `Battlefield`
## actually makes a drop - so a probe built on a bare field watches a crate break
## and produce nothing, which is the field being a stub rather than the crate
## being broken. That cost one wrong diagnosis here.
class Recorder extends EnemyField:
	var spawned: Array[Dictionary] = []

	func spawn_loot(currency: String, amount: int, at: Vector2) -> void:
		spawned.append({"currency": currency, "amount": amount, "at": at})


var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_the_art_and_data_exist()
	_test_rarity_is_ordered()
	_test_healing_is_bounded_and_scales()
	_test_a_crate_is_rarer_than_an_orb()
	await _test_an_orb_actually_heals()
	await _test_a_crate_actually_spills()
	_finish()


func _test_the_art_and_data_exist() -> void:
	for id: String in [Balance.HEALING_ORB_ID, Balance.SUPPLY_CRATE_ID]:
		_checked += 1
		_check(ResourceLoader.exists("res://art/loot/loot_%s.png" % id),
			"%s has no world art; a drop nobody can see is a drop nobody takes" % id)
	_checked += 1
	var orb := ContentDB.recovery_drops.get(Balance.HEALING_ORB_ID, null) \
		as RecoveryDropData
	_check(orb != null and not orb.pickup_line.is_empty(),
		"the healing orb has no authored pickup line")


## Rarity is what the brief asked to tune against, so the ordering is the claim.
func _test_rarity_is_ordered() -> void:
	_checked += 1
	_check(Balance.HEALING_ORB_BREED_CHANCE < Balance.HEALING_ORB_ELITE_CHANCE
			and Balance.HEALING_ORB_ELITE_CHANCE <= Balance.HEALING_ORB_BOSS_CHANCE,
		"orb chances are not ordered breed < elite <= boss")
	_checked += 1
	_check(Balance.SUPPLY_CRATE_BREED_CHANCE < Balance.SUPPLY_CRATE_ELITE_CHANCE
			and Balance.SUPPLY_CRATE_ELITE_CHANCE < Balance.SUPPLY_CRATE_BOSS_CHANCE,
		"crate chances are not ordered breed < elite < boss")
	# **Still rare.** An ordinary kill drops a coin far more often than it drops
	# health, and the day that stops being true the road has become a buffet.
	_checked += 1
	_check(Balance.HEALING_ORB_BREED_CHANCE < Balance.LOOT_DROP_CHANCE * 0.5,
		"a breed drops health at %.3f against a coin's %.3f; that is not rare"
			% [Balance.HEALING_ORB_BREED_CHANCE, Balance.LOOT_DROP_CHANCE])


## The cap is the whole balance argument, so it is checked against the hardest
## thing in the game rather than against a constant.
func _test_healing_is_bounded_and_scales() -> void:
	var strongest: EnemyData = null
	var weakest: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		if strongest == null or breed.resource_value > strongest.resource_value:
			strongest = breed
		if weakest == null or breed.resource_value < weakest.resource_value:
			weakest = breed
	_checked += 1
	if not _check(strongest != null and weakest != null, "no enemies to measure"):
		return

	var big: int = _orb_from(strongest)
	var small: int = _orb_from(weakest)
	_checked += 1
	_check(big >= small,
		"the strongest body heals for %d and the weakest for %d; power must scale up"
			% [big, small])
	_checked += 1
	_check(float(big) <= Balance.HERO_MAX_HP * Balance.HEALING_ORB_MAX_FRACTION + 1.0,
		"the strongest body's orb heals %d, past the %.0f cap"
			% [big, Balance.HERO_MAX_HP * Balance.HEALING_ORB_MAX_FRACTION])

	# **Against the Spark**, which is the control. The Spark restores its
	# immediate slice *and then regenerates for six seconds*; an orb that beat
	# that on its own would have replaced a system rather than joined it.
	var spark_total: float = Balance.HERO_MAX_HP \
		* (Balance.MENDER_SPARK_IMMEDIATE_FRACTION
			+ Balance.MENDER_SPARK_REGEN_PER_SECOND * Balance.MENDER_SPARK_DURATION)
	_checked += 1
	_check(float(big) < spark_total,
		"one orb heals %d and a full Mender's Spark heals %.0f; the rare one must win"
			% [big, spark_total])


func _orb_from(breed: EnemyData) -> int:
	var fraction: float = Balance.HEALING_ORB_BASE_FRACTION \
		+ float(breed.resource_value) * Balance.HEALING_ORB_POWER_PER_VALUE
	return maxi(int(round(Balance.HERO_MAX_HP
		* minf(fraction, Balance.HEALING_ORB_MAX_FRACTION))), 1)


func _test_a_crate_is_rarer_than_an_orb() -> void:
	for pair: Array in [
			[Balance.SUPPLY_CRATE_BREED_CHANCE, Balance.HEALING_ORB_BREED_CHANCE, "breed"],
			[Balance.SUPPLY_CRATE_ELITE_CHANCE, Balance.HEALING_ORB_ELITE_CHANCE, "elite"]]:
		_checked += 1
		_check(float(pair[0]) < float(pair[1]),
			"a %s drops crates at %.3f and orbs at %.3f; the event must be rarer than the sip"
				% [String(pair[2]), float(pair[0]), float(pair[1])])


## An orb on the ground actually heals the hero that walks over it.
##
## Driven through the drop rather than by calling the hero's method: the whole
## point of the lesson this project keeps relearning is that the wiring is the
## part that breaks, and `drink_healing_orb` working says nothing about whether
## anything ever calls it.
func _test_an_orb_actually_heals() -> void:
	RunState.reset()
	var field := Recorder.new()
	add_child(field)
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	hero.global_position = Vector2.ZERO
	# **Presence is granted by the scope that owns the body**, and a bare probe is
	# not a scope. Without it the hero is not in `GROUP_ANY`, so the drop's
	# `_nearest_hero` finds nobody and nothing is ever collected - the same trap
	# the raid arena documents having fallen into with its own enemies.
	hero.set_present(true)
	hero.health.take_damage(hero.health.max_hp * 0.5, Vector2.RIGHT)
	var hurt: float = hero.health.current_hp

	# Through `setup`, which is how the field makes one. Assigning the fields by
	# hand skips the scatter velocity and the glow the drop expects to have, and
	# a probe that builds its subject differently from the game is a probe that
	# is testing something else.
	var drop := (load("res://scripts/systems/loot_drop.gd") as GDScript).new() as Node2D
	drop.call("setup", Balance.HEALING_ORB_ID, 40, Vector2(12.0, 0.0))
	field.add_child(drop)
	for _f: int in 90:
		await get_tree().process_frame
		if hero.health.current_hp > hurt:
			break
	_checked += 1
	_check(hero.health.current_hp > hurt,
		"a healing orb the hero stood on top of restored nothing")
	_checked += 1
	_check(hero.health.current_hp <= hero.health.max_hp,
		"an orb healed past maximum health")
	field.queue_free()
	for _f: int in 4:
		await get_tree().process_frame


## A crate breaks and leaves something behind.
func _test_a_crate_actually_spills() -> void:
	RunState.reset()
	var field := Recorder.new()
	add_child(field)
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	hero.global_position = Vector2.ZERO
	# **Presence is granted by the scope that owns the body**, and a bare probe is
	# not a scope. Without it the hero is not in `GROUP_ANY`, so the drop's
	# `_nearest_hero` finds nobody and nothing is ever collected - the same trap
	# the raid arena documents having fallen into with its own enemies.
	hero.set_present(true)

	var crate := (load("res://scripts/systems/loot_drop.gd") as GDScript).new() as Node2D
	crate.call("setup", Balance.SUPPLY_CRATE_ID, 9, Vector2(12.0, 0.0))
	field.add_child(crate)
	for _f: int in 90:
		await get_tree().process_frame
		if not is_instance_valid(crate) or crate.is_queued_for_deletion():
			break
	var spilled: Array[Dictionary] = field.spawned
	_checked += 1
	_check(spilled.size() >= Balance.SUPPLY_CRATE_MIN_SPILLS,
		"a broken crate spilled %d things, wanted at least %d"
			% [spilled.size(), Balance.SUPPLY_CRATE_MIN_SPILLS])
	_checked += 1
	_check(spilled.size() <= Balance.SUPPLY_CRATE_MAX_SPILLS,
		"a broken crate spilled %d things, past the %d cap"
			% [spilled.size(), Balance.SUPPLY_CRATE_MAX_SPILLS])
	# Everything that came out is something the game knows how to hand over.
	for one: Dictionary in spilled:
		var what: String = String(one["currency"])
		_checked += 1
		_check(what == Balance.HEALING_ORB_ID or RunState.CURRENCIES.has(what),
			"a crate spilled '%s', which is neither health nor a run currency" % what)
		_checked += 1
		_check(int(one["amount"]) > 0, "a crate spilled a '%s' worth nothing" % what)
	field.queue_free()
	for _f: int in 4:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> bool:
	if condition:
		return true
	_failures += 1
	push_error("[recovery-drops] %s" % why)
	return false


func _finish() -> void:
	if _failures == 0:
		print("[recovery-drops] PASS - %d checks; orbs and crates are rare, scaled and capped"
			% _checked)
	else:
		push_error("[recovery-drops] FAIL - %d of %d" % [_failures, _checked])
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 12:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)
