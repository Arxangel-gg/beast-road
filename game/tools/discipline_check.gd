extends Node

var _failures: PackedStringArray = []

## How many of the awaited tests reached their last line.
var _finished: int = 0

## What the riders under test moved. Members rather than locals because the
## handlers that fill them are lambdas, and those capture by value.
var _healed: float = 0.0
var _armor_asked: Vector2 = Vector2.ZERO
var _wound_asked: Vector3 = Vector3.ZERO
var _refund_asked: float = 0.0

## A stand-in hero for the cleanse test: it only has to say it was cleansed.
const RECORDER_SOURCE: String = "extends Node2D\nvar cleansed: bool = false\nfunc cleanse_disables() -> void:\n\tcleansed = true\n"
var _blinked_to: Vector2 = Vector2.INF
const EXPECTED_TESTS: int = 5


func _ready() -> void:
	# **Held for the whole run.** This gate edits MetaState in place - a wiped
	# stash, a drained Tools purse, a reset flag - and any save reached while
	# that scratch state is live overwrites a real player's file. One did, on
	# 2026-08-31, and a stash is the one thing here that cannot be restored.
	MetaState.hold_saves()
	RunState.reset()
	# 24 authored nodes, plus one summon per discipline from 2026-08-25 and a
	# second from 2026-09-01: 30.
	#
	# **A tripwire against loss, not a ceiling.** The count is asserted rather
	# than derived on purpose - a node that vanishes from the data is a hero
	# power silently disappearing, and nothing else in the project would notice.
	# Raising it when nodes are deliberately added is the intended maintenance;
	# what must never happen is it being *lowered* to match a roster that got
	# smaller by accident.
	_check(ContentDB.discipline_nodes.size() == 30,
		"expected 30 authored discipline nodes, got %d" % ContentDB.discipline_nodes.size())
	_check(RunState.trained_discipline_nodes.size() == 2,
		"a run must begin with the curated Attack and Defense pair")
	_check(RunState.discipline_node_in_slot(0) != null \
			and RunState.discipline_node_in_slot(1) != null,
		"starter Attack and Defense must occupy their role slots")
	_check(RunState.discipline_node_in_slot(2) == null \
			and RunState.discipline_node_in_slot(3) == null,
		"Power and Ultimate must begin empty")

	RunState.building_tiers["sanctum"] = 3
	RunState.refresh_discipline_offers()
	_check(RunState.discipline_offers.size() == 3,
		"a built Mansion must offer exactly three unique nodes")
	var seen: Dictionary = {}
	for id: String in RunState.discipline_offers:
		seen[id] = true
	_check(seen.size() == RunState.discipline_offers.size(),
		"Mansion offers must not contain duplicates")

	_test_every_effect_is_accounted_for()
	_test_every_node_can_be_offered()

	var power: DisciplineNodeData = ContentDB.discipline_node("marrow_drain")
	RunState.trained_discipline_nodes.append(power.id)
	_check(not RunState.try_equip_discipline(power.id).is_empty(),
		"Power must remain locked during Act I")
	RunState.act = 2
	_check(RunState.try_equip_discipline(power.id).is_empty() \
			and RunState.discipline_node_in_slot(2) == power,
		"Power must equip after the Act I gate")

	RunState.gain_currency(RunState.FOOD, 999)
	var first_cost: int = RunState.discipline_respec_cost()
	_check(RunState.try_respec_disciplines().is_empty(),
		"Preparation respec must succeed when Food is available")
	_check(RunState.discipline_respec_cost() > first_cost,
		"respec Food cost must rise per use")
	_check(RunState.trained_discipline_nodes.size() == 2,
		"respec must return to the curated starter pair")

	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		_check(ResourceLoader.exists(node.get_sprite_path()),
			"missing discipline icon: %s" % node.get_sprite_path())

	await _test_mercy_under_fire()
	_test_synergies_are_real()
	await _test_second_wind_fires()
	await _test_the_brand_reaches_the_towers()
	await _test_the_riders_fire()
	_test_the_wound_pool_recovers()

	# **A script error aborts its own function and nothing else.**
	# This gate printed PASS with three SCRIPT ERRORs above it, because the two
	# tests that died had simply stopped running and left no failures behind.
	# `ranged_check` and `trade_check` both grew this counter after exactly the
	# same thing; it is the cheapest assertion in the file and the only one that
	# can notice a test that never happened.
	if _finished != EXPECTED_TESTS:
		_check(false, ("only %d of %d awaited tests ran to completion - look for "
			+ "a SCRIPT ERROR above") % [_finished, EXPECTED_TESTS])

	if _failures.is_empty():
		print("[discipline] PASS — %d nodes, role gates, offers, respec and icons"
			% ContentDB.discipline_nodes.size())
	else:
		for failure: String in _failures:
			push_error("[discipline] " + failure)
	# The Mercy Under Fire test hurts a hero, and a hero being hurt plays a
	# sound. A voice still playing at exit leaks its Ogg stream, and a *warning*
	# fails this gate on the runner exactly as an assertion does - which is why
	# every gate that touches the battlefield ends this way.
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


## Mercy Under Fire actually pushes, on a revive a player can actually reach.
##
## Driven through `apply_hearthmend` - the Resurrection Draught spending itself -
## rather than by calling the respawn's completion function. That distinction is
## the point of this test rather than a nicety: the effect was first wired into
## `_finish_respawn` alone and the Draught path stood the hero up in silence, so
## a test that called `_finish_respawn` would have passed on a half-inert
## feature. Both revives now go through one function and this drives the other
## one.
##
## Non-damaging is asserted too. A revive that killed things would make dying a
## play, and zero-damage-through-`take_damage` would have been the obvious
## shortcut to writing it.
func _test_mercy_under_fire() -> void:
	RunState.reset()
	RunState.act = 3
	var node: DisciplineNodeData = null
	for one: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if one.effect_id == "revive_knockback":
			node = one
	_check(node != null, "no authored node carries revive_knockback")
	if node == null:
		return
	RunState.trained_discipline_nodes.append(node.id)

	var field := EnemyField.new()
	add_child(field)
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	hero.global_position = Vector2.ZERO

	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED 				and one.knockback_resistance < 0.5:
			breed = one
			break
	_check(breed != null, "a breed with ordinary footing is needed to be pushed")
	if breed == null:
		field.queue_free()
		return

	var foe := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
	foe.setup(breed, 0, field, 1.0)
	field.add_child(foe)
	foe.global_position = Vector2(60.0, 0.0)
	await get_tree().process_frame
	var before: Vector2 = foe.global_position
	var hp_before: float = foe.health.current_hp

	# The reachable revive: hold a Draught, go down, get up.
	RunState.take_item("resurrection_draught")
	hero.health.take_damage(hero.health.max_hp * 2.0, Vector2.LEFT)
	for _f: int in 12:
		await get_tree().process_frame

	_check(hero.is_alive(), "the Draught did not stand the hero back up")
	_check(foe.global_position.distance_to(before) > 8.0,
		"Mercy Under Fire moved a body %.1f pixels"
			% foe.global_position.distance_to(before))
	_check(is_equal_approx(foe.health.current_hp, hp_before),
		"Mercy Under Fire dealt damage; it is meant to be a shove, not a blow")
	# Torn down deliberately and waited out. `queue_free` on the field alone,
	# followed by a single frame, left eight ObjectDB instances alive at exit and
	# turned the whole gate DIRTY on a warning - which fails CI exactly as a
	# failed assertion does. A hero and an enemy each own tweens and timers that
	# need their own frames to unwind.
	foe.queue_free()
	hero.queue_free()
	await get_tree().process_frame
	field.queue_free()
	for _f: int in 12:
		await get_tree().process_frame
	_finished += 1


## Every authored synergy is accounted for, buildable, and points at real
## effects.
##
## Four separate ways a synergy can be a lie, and all four have precedent in
## this codebase:
##
## 1. **Authored and read by nothing.** Twenty-one discipline effects shipped
##    like that. `Synergies.IMPLEMENTED` is the same registry answer, and this
##    fails the build when a synergy is in neither list or in both.
## 2. **Requiring an effect that does not exist.** A typo in a `.tres` array is
##    silent - `trained()` simply always answers false and the synergy can never
##    fire, which is indistinguishable from a player who has not built for it.
## 3. **Requiring an effect nothing implements.** Seventeen are still owed. A
##    synergy resting on one of those is buildable and inert.
## 4. **Requiring effects a hero cannot hold at once.** The three finisher
##    effects are all Attack-slot, and only one node sits in a slot - so a
##    synergy between two of them could never fire, by construction. This is the
##    one that would have been hardest to notice by playing.
func _test_synergies_are_real() -> void:
	var listed: Dictionary = {}
	for id: String in Synergies.IMPLEMENTED:
		listed[id] = "implemented"
	for id: String in Synergies.DECLARED_ONLY:
		_check(not listed.has(id), "%s is in both synergy registries" % id)
		listed[id] = "declared"

	var authored: Dictionary = {}
	for data: SynergyData in Synergies.all_sorted():
		authored[data.id] = true
		_check(listed.has(data.id),
			"synergy %s is authored and in neither registry, so nothing says "
				% data.id + "whether anything reads it")
		_check(data.requires.size() >= 2,
			"synergy %s requires %d effect(s); a synergy of one is a node"
				% [data.id, data.requires.size()])
		for effect_id: String in data.requires:
			_check(_effect_is_authored(effect_id),
				"synergy %s requires effect '%s', which no node carries"
					% [data.id, effect_id])
			_check(DisciplineEffects.IMPLEMENTED.has(effect_id),
				"synergy %s rests on '%s', which is authored and still owed"
					% [data.id, effect_id])
		_check(_can_hold_together(data),
			"synergy %s needs two effects that cannot both be live at once"
				% data.id)
	for id: Variant in listed:
		_check(authored.has(String(id)),
			"%s is registered as a synergy and no .tres authors it" % String(id))
	print("[discipline] %d synergies, %d implemented"
		% [Synergies.all_sorted().size(), Synergies.IMPLEMENTED.size()])


func _effect_is_authored(effect_id: String) -> bool:
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.effect_id == effect_id:
			return true
	return false


## Whether one hero could have every effect this synergy wants working at once.
##
## `DisciplineEffects.trained` reads the trained list, not the slots, so any
## number of PASSIVE effects coexist freely. The trap is the effects that are
## only ever read off an equipped node: two of those in the same slot can never
## both be live. Slot is a property of the node, so this asks the nodes.
func _can_hold_together(data: SynergyData) -> bool:
	var slot_used: Dictionary = {}
	for effect_id: String in data.requires:
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.effect_id != effect_id:
				continue
			# Read from the trained list, so the slot does not constrain it.
			if not _effect_is_slot_bound(effect_id):
				continue
			var slot: int = int(node.slot)
			if slot_used.has(slot) and slot_used[slot] != effect_id:
				return false
			slot_used[slot] = effect_id
	return true


## The effects the game reads off `discipline_node_in_slot` rather than off the
## trained list. Listed rather than derived, because "how is this effect read"
## is a fact about the consuming code and nothing in the data knows it.
func _effect_is_slot_bound(effect_id: String) -> bool:
	return effect_id in ["bleed_finisher", "defense_radiant_finisher",
		"crowd_finisher_force"]


## Second Wind actually refills Rising Fury on a Howler kill.
##
## Driven through the real signal rather than by calling `fill_fury`, for the
## reason the whole session keeps running into: the wiring is the part that
## breaks, and a test that calls the effect directly passes on a synergy nothing
## triggers. Both halves are trained, a Howler dies on the bus, and the hero's
## attack interval is measured before and after.
func _test_second_wind_fires() -> void:
	RunState.reset()
	RunState.act = 3
	for effect_id: String in ["active_attack_speed", "support_kill_speed"]:
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.effect_id == effect_id:
				RunState.trained_discipline_nodes.append(node.id)
	_check(Synergies.active("second_wind"),
		"training both halves did not make Second Wind active")

	var howler: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.role == EnemyData.Role.HOWLER:
			howler = breed
			break
	_check(howler != null, "no authored breed is a Howler, so nothing can trigger it")
	if howler == null:
		return

	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	add_child(hero)
	await get_tree().process_frame
	var cold: float = hero.attack.fury_ramp()
	_check(is_zero_approx(cold),
		"a hero who has not swung is already at %.2f fury" % cold)
	EventBus.enemy_died.emit(howler.id, Vector2.ZERO)
	await get_tree().process_frame
	var hot: float = hero.attack.fury_ramp()
	_check(hot >= 0.99,
		"a Howler kill left Rising Fury at %.2f rather than its cap" % hot)
	hero.queue_free()
	for _f: int in 6:
		await get_tree().process_frame
	_finished += 1


## Judgment Brand paints priority prey, and the towers spend it.
##
## **Two halves that can each be true alone and useless.** A brand nothing reads
## is the whole failure `DisciplineEffects` exists for; a tower multiplier with
## nothing applying it is the same failure facing the other way. So this drives
## the real hero attack path into a real body and then asks a real tower what it
## would do to it.
##
## The ordinary-breed case is the one worth having. Without it the node is a flat
## damage multiplier on everything the hero touches, which is not what it says
## and not what it was priced at.
func _test_the_brand_reaches_the_towers() -> void:
	RunState.reset()
	var brand_node: DisciplineNodeData = null
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.effect_id == "tower_damage_brand":
			brand_node = node
	if not _checked(brand_node != null, "no node authors tower_damage_brand"):
		return
	RunState.trained_discipline_nodes.append(brand_node.id)
	RunState.equipped_discipline_slots[0] = brand_node.id

	var field := EnemyField.new()
	add_child(field)
	var elite: Enemy = await _body(field, func(breed: EnemyData) -> bool:
		return breed.category != EnemyData.Category.BREED)
	var common: Enemy = await _body(field, func(breed: EnemyData) -> bool:
		return breed.category == EnemyData.Category.BREED \
			and breed.role != EnemyData.Role.HOWLER \
			and breed.role != EnemyData.Role.BURROWER)
	if elite == null or common == null:
		_check(false, "no authored pair of an elite and an ordinary breed to test with")
		field.queue_free()
		return

	_check(is_equal_approx(elite.brand_multiplier(), 1.0),
		"a body was branded before anything hit it")
	elite.take_damage(1.0, Vector2.ZERO, 0.0, true)
	common.take_damage(1.0, Vector2.ZERO, 0.0, true)
	await get_tree().process_frame

	_check(elite.is_branded(),
		"the hero's attack slot did not brand priority prey, so the towers get nothing")
	_check(elite.brand_multiplier() > 1.0 + brand_node.effect_value - 0.001,
		"the brand is worth %.3f rather than the authored %.3f"
			% [elite.brand_multiplier() - 1.0, brand_node.effect_value])
	_check(not common.is_branded(),
		("an ordinary breed was branded too, so the node is a flat damage "
			+ "multiplier on everything rather than a choice of target"))

	# And it lets go. A brand that never expires is a permanent multiplier bought
	# with one swing.
	elite.call("_tick_brand", Balance.DISCIPLINE_BRAND_SECONDS + 0.1)
	_check(not elite.is_branded(), "the brand never expires")
	_check(is_equal_approx(elite.brand_multiplier(), 1.0),
		"an expired brand still multiplies tower damage")
	# **And something actually spends it.**
	#
	# Everything above proves the mark goes on and comes off. None of it proves a
	# tower ever multiplies by it - and a brand nothing reads is precisely the
	# failure `DisciplineEffects` exists to catch, arriving one layer further in.
	#
	# Checked by reading the two damage call sites rather than by building a
	# tower and a projectile, which is blunt but catches the regression that
	# matters: somebody simplifying the multiplication away. Both paths are
	# named, because the direct hit and the projectile are separate code and
	# fixing one has already meant forgetting the other elsewhere in this file.
	for spender: String in ["res://scenes/battlefield/tower.gd",
			"res://scenes/battlefield/projectile.gd"]:
		var source: String = FileAccess.get_file_as_string(spender)
		_check(source.contains("brand_multiplier()"),
			("%s no longer multiplies by the brand, so Judgment Brand marks a "
				+ "body that nothing treats differently") % spender.get_file())

	elite.queue_free()
	common.queue_free()
	await get_tree().process_frame
	field.queue_free()
	for _f: int in 12:
		await get_tree().process_frame
	_finished += 1


## The three riders that ride an existing spell actually fire.
##
## Each of these nodes casts a spell that was already implemented, so the node
## *looked* like it worked: the effect went off, the numbers appeared, and the
## sentence on the card describing the extra was simply not true. That is the
## hardest version of this failure to notice by playing, which is why it is here.
##
## **Cast for real, and watch the thing the rider is supposed to move.** An
## earlier draft of this test asserted that the node existed, named a real spell
## and carried a magnitude - all of which were true the entire time the riders
## did nothing. A test that passes against the bug it was written for is worse
## than no test, and this project has shipped one before.
func _test_the_riders_fire() -> void:
	for effect_id: String in ["drain_command", "tempest_heal_cap", "heavy_reverse_pull",
			"armor_stagger", "dash_shield_field", "lane_cleanse", "recoverable_wound",
			"road_line_disrupt", "selected_road_shockwave", "marked_dash_refund"]:
		await _drive_rider(effect_id)
	_finished += 1


## Sanguine Guard's pool, on its own: harm is banked, a swing wins some back,
## and the window closing takes the rest. The rider test above proves the node
## asks for it; this proves the thing it asks for does what the card says.
func _test_the_wound_pool_recovers() -> void:
	var pool: Health = Health.new()
	pool.max_hp = 100.0
	add_child(pool)
	pool.deferred_fraction = 0.28
	pool.take_damage(50.0, Vector2.ZERO)
	_check(is_equal_approx(pool.current_hp, 64.0),
		"a 28%% guard should take 36 of a 50 blow, took %.1f" % (100.0 - pool.current_hp))
	_check(is_equal_approx(pool.deferred(), 14.0),
		"and bank the other 14, banked %.1f" % pool.deferred())
	var won: float = pool.recover_deferred(0.5)
	_check(is_equal_approx(won, 7.0) and is_equal_approx(pool.deferred(), 7.0),
		"a landed blow should win back half the bank")
	var owed: float = pool.settle_deferred()
	_check(is_equal_approx(owed, 7.0) and is_equal_approx(pool.current_hp, 57.0),
		"closing the window should take the rest, %.1f left" % pool.current_hp)
	_check(pool.deferred_fraction == 0.0 and pool.deferred() == 0.0,
		"and leave nothing banked and nothing guarded")
	# Armour: a share turned away before the shield, so a ward pays only for
	# what armour let by.
	pool.damage_scale = 0.7
	pool.add_shield(10.0)
	pool.take_damage(50.0, Vector2.ZERO)
	_check(is_equal_approx(pool.current_hp, 57.0 - 25.0),
		"30%% armour under a 10 shield should let 25 of 50 through, hp %.1f" % pool.current_hp)
	pool.queue_free()
	_finished += 1


func _drive_rider(effect_id: String) -> void:
	RunState.reset()
	RunState.act = 3
	# Command is only earned in a fight, so a rider that pays it cannot be tested
	# outside one. This is the phase, not a flag: `gain_command` asks
	# `is_command_combat()` and silently returns otherwise.
	RunState.phase = RunState.Phase.ROAD_BATTLE
	var node: DisciplineNodeData = null
	for one: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if one.effect_id == effect_id:
			node = one
	if not _checked(node != null, "no node authors %s" % effect_id):
		return
	var spell := ContentDB.spells.get(node.spell_id, null) as SpellData
	if not _checked(spell != null,
			"%s names spell '%s', which does not exist" % [effect_id, node.spell_id]):
		return

	var field := EnemyField.new()
	add_child(field)
	var caster: SpellCaster = SpellCaster.new()
	caster.field = field
	add_child(caster)
	await get_tree().process_frame

	# Equipped, not merely trained: these riders belong to the node in the slot.
	RunState.equipped_spells[0] = spell.id
	RunState.trained_discipline_nodes.append(node.id)
	RunState.equipped_discipline_slots[0] = node.id

	# **Members, not locals.** A GDScript lambda captures by value, so a local
	# `healed` incremented inside the handler stays zero outside it - and the
	# test reads exactly as though the rider never fired. `merchant_check` lost
	# an afternoon to this same line.
	_healed = 0.0
	_blinked_to = Vector2.INF
	_armor_asked = Vector2.ZERO
	_wound_asked = Vector3.ZERO
	_refund_asked = 0.0
	caster.heal_requested.connect(func(amount: float) -> void: _healed += amount)
	caster.blink_requested.connect(func(to: Vector2) -> void: _blinked_to = to)
	caster.armor_requested.connect(func(fraction: float, seconds: float) -> void:
		_armor_asked = Vector2(fraction, seconds))
	caster.wound_guard_requested.connect(func(fraction: float, delay: float, seconds: float) -> void:
		_wound_asked = Vector3(fraction, delay, seconds))
	caster.dash_refund_requested.connect(func(fraction: float) -> void: _refund_asked = fraction)

	var body: Enemy = await _rider_body(field, effect_id)
	if not _checked(body != null,
			"%s: no authored breed can stand in front of it" % effect_id):
		caster.queue_free()
		field.queue_free()
		return
	# Most riders want a body beside the cast. The two that run down the road
	# want one *past* the spell's own reach, along the lane - which in a bare
	# field is straight up - so the assertion cannot be satisfied by the spell
	# the rider rides.
	var offset: Vector2 = Vector2(60.0, 0.0)
	if effect_id == "road_line_disrupt":
		offset = Vector2(0.0, -400.0)
	elif effect_id == "selected_road_shockwave":
		offset = Vector2(0.0, -600.0)
	body.global_position = offset
	await get_tree().process_frame
	# **Cast from where the game casts from.** `hero.gd` passes
	# `combat_origin()`, which on a large body sits hundreds of pixels above its
	# feet - and `enemies_near` measures to that same point. An origin taken from
	# the feet frame put every target out of range and read exactly like three
	# riders that never fired.
	var from: Vector2 = body.combat_origin() - offset

	# The two riders that act on heroes rather than bodies need a hero to act
	# on. A bare node in the heroes group is enough: one with a health pool for
	# the shield field, one that records being cleansed.
	var stand_in: Node2D = null
	var stand_in_pool: Health = null
	if effect_id == "dash_shield_field" or effect_id == "lane_cleanse":
		stand_in = Node2D.new()
		if effect_id == "lane_cleanse":
			var recorder := GDScript.new()
			recorder.source_code = RECORDER_SOURCE
			recorder.reload()
			stand_in.set_script(recorder)
		else:
			stand_in_pool = Health.new()
			stand_in_pool.max_hp = 100.0
			stand_in.add_child(stand_in_pool)
		stand_in.add_to_group(Hero.GROUP_ANY)
		add_child(stand_in)
		stand_in.global_position = from
		await get_tree().process_frame

	var command_before: float = RunState.command
	var body_hp_before: float = body.health.current_hp
	caster.clear_cooldowns()
	var went_off: bool = caster.try_cast(0, Vector2.RIGHT, from)
	_check(went_off, "%s: the spell it rides would not cast at all" % effect_id)
	await get_tree().process_frame
	caster.tick(0.1, Vector2.RIGHT, from)

	match effect_id:
		"drain_command":
			_check(RunState.command > command_before,
				("drain_command: channelling on priority prey paid no Command, "
					+ "which is the whole sentence on the card"))
		"tempest_heal_cap":
			_check(_healed > 0.0,
				"tempest_heal_cap: a tempest into a body returned no health")
			_check(_healed <= node.effect_value + 0.001,
				("tempest_heal_cap: returned %.1f health against an authored cap "
					+ "of %.1f, so the cap is not being applied")
					% [_healed, node.effect_value])
		"heavy_reverse_pull":
			_check(_blinked_to != Vector2.INF,
				("heavy_reverse_pull: a target too heavy to drag did not reel the "
					+ "hero in either, so the cast is still wasted on it"))
			if _blinked_to != Vector2.INF:
				# Landed on the ground, beside the body rather than inside it.
				var gap: float = _blinked_to.distance_to(body.global_position)
				_check(gap > 1.0 and gap < Balance.HERO_ATTACK_RANGE[0],
					("heavy_reverse_pull: the hook left the hero %.0f from the "
						+ "body, which is either inside it or nowhere near it")
						% gap)
				# Loose on purpose: the body is walking, so it drifts a few
				# pixels between the cast being aimed and resolved. What this
				# catches is a frame mix, which is a body-height out - hundreds
				# of pixels on a large elite, never single digits.
				_check(absf(_blinked_to.y - body.global_position.y) < 40.0,
					("heavy_reverse_pull: the hook landed the hero at y=%.0f "
						+ "against a body at y=%.0f - the body frame and the foot "
						+ "frame have been mixed")
						% [_blinked_to.y, body.global_position.y])
		"armor_stagger":
			_check(is_equal_approx(_armor_asked.x, node.effect_value),
				"armor_stagger: asked for %.2f armour, the card says %.2f"
					% [_armor_asked.x, node.effect_value])
			_check(_armor_asked.y > spell.duration,
				"armor_stagger: the armour must outlast the veil it rides, or it is nothing")
			_check(body._hitstun_left > 0.0,
				"armor_stagger: the body beside the roar was not staggered")
		"dash_shield_field":
			_check(caster.aegis_field_count() == 1,
				"dash_shield_field: the step left no field behind it")
			_check(stand_in_pool != null and stand_in_pool.shield() > 0.0,
				"dash_shield_field: a hero standing in the field was not warded")
			if stand_in_pool != null:
				_check(is_equal_approx(stand_in_pool.shield(),
						100.0 * Balance.DISCIPLINE_AEGIS_SHIELD_FRACTION),
					"dash_shield_field: the ward is %.1f, not the authored share" % stand_in_pool.shield())
		"lane_cleanse":
			_check(stand_in != null and bool(stand_in.get("cleansed")),
				"lane_cleanse: a hero on the warded ground was not cleansed")
		"recoverable_wound":
			_check(is_equal_approx(_wound_asked.x, node.effect_value),
				"recoverable_wound: asked to bank %.2f, the card says %.2f"
					% [_wound_asked.x, node.effect_value])
			_check(is_equal_approx(_wound_asked.y, spell.duration) and _wound_asked.z > 0.0,
				"recoverable_wound: the window must open when the veil ends and last a while")
		"road_line_disrupt":
			_check(body._hitstun_left > 0.0,
				("road_line_disrupt: a body on the road past the tremor's own reach "
					+ "was not disrupted, so the line is only the nova"))
		"selected_road_shockwave":
			_check(body.health.current_hp < body_hp_before,
				("selected_road_shockwave: a body down the road past the nova's reach "
					+ "took nothing, so the shockwave stops where the spell did"))
		"marked_dash_refund":
			_check(is_equal_approx(_refund_asked, node.effect_value),
				"marked_dash_refund: stepping through priority prey refunded %.2f, the card says %.2f"
					% [_refund_asked, node.effect_value])
			_check(_blinked_to != Vector2.INF and is_equal_approx(_blinked_to.y, from.y),
				"marked_dash_refund: the step itself must land level with where it left")

	if stand_in != null:
		stand_in.queue_free()
	caster.queue_free()
	body.queue_free()
	await get_tree().process_frame
	field.queue_free()
	for _f: int in 12:
		await get_tree().process_frame


## The body each rider needs in front of it.
##
## `heavy_reverse_pull` needs something immovable and the other two need priority
## prey; a breed that is neither proves nothing.
func _rider_body(into: EnemyField, effect_id: String) -> Enemy:
	if effect_id == "heavy_reverse_pull":
		return await _body(into, func(breed: EnemyData) -> bool:
			return breed.knockback_resistance >= Balance.DISCIPLINE_HEAVY_RESISTANCE)
	return await _body(into, func(breed: EnemyData) -> bool:
		return breed.category != EnemyData.Category.BREED)


## A spawned body of the first breed matching `wanted`, or null.
##
## **Set up into a field, not merely added to the tree.** A bare `add_child`
## leaves `_field` null and the body throws on its first physics frame - which is
## exactly what the first version of this did, printing a wall of SCRIPT ERRORs
## while the gate went on to say PASS.
func _body(into: EnemyField, wanted: Callable) -> Enemy:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or not wanted.call(breed):
			continue
		var body := (load("res://scenes/battlefield/enemy.tscn") as PackedScene) \
			.instantiate() as Enemy
		body.setup(breed, 0, into, 1.0)
		into.add_child(body)
		await get_tree().process_frame
		return body
	return null


## `_check` that also answers, so a guard clause can read as one line.
func _checked(condition: bool, failure: String) -> bool:
	_check(condition, failure)
	return condition


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


## Every authored node has to be reachable through the offer rotation.
##
## The tree is a *choice*: 27 nodes and a maxed hero trains eleven, drawn three
## at a time from a deterministic per-road shuffle. That is a good shape, and it
## has one silent failure - a node that the rotation never surfaces is content
## nobody can take, and it looks exactly like a node nobody happened to pick.
## Nothing else in the project would notice: the count assertion above sees it in
## the data, the icon assertion below sees its art, and the offer assertion sees
## three ids without caring which.
##
## Swept over roads rather than reasoned about, because the ordering is a hash
## and hashes do not answer arguments.
## **Every authored effect is either implemented or listed as not implemented.**
##
## A sweep on 2026-09-09 found `.effect_id` read in exactly three places in the
## whole codebase: twenty-one of the twenty-four authored discipline effects had
## no consumer, and ten nodes had no `spell_id` either - so a third of the skill
## tree cost a skill point and its Food, drew an icon, printed a sentence saying
## what it did, and did nothing.
##
## Nothing could have caught it, because "no consumer" is invisible to a gate
## that only reads data. `DisciplineEffects` makes it declarative instead: this
## asserts the two lists cover every authored key exactly once, so a new inert
## node cannot be added without someone writing its key into `DECLARED_ONLY` on
## purpose, in a diff a reviewer sees.
##
## It deliberately does *not* fail on the outstanding nineteen. A gate that is
## red for a week is a gate people stop reading, and those cannot be written in
## one change - the count is printed instead so the debt is visible and its
## direction is obvious.
func _test_every_effect_is_accounted_for() -> void:
	var implemented: Array[String] = DisciplineEffects.IMPLEMENTED
	var declared: Array[String] = DisciplineEffects.DECLARED_ONLY
	var missing: PackedStringArray = []
	var doubled: PackedStringArray = []
	var authored: Dictionary = {}
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.effect_id.is_empty():
			continue
		authored[node.effect_id] = true
		var known: bool = implemented.has(node.effect_id)
		var owed: bool = declared.has(node.effect_id)
		if not known and not owed:
			missing.append("%s (%s)" % [node.effect_id, node.id])
		if known and owed:
			doubled.append(node.effect_id)
	_check(missing.is_empty(),
		"authored effects in neither DisciplineEffects list, so nobody can tell "
			+ "whether they do anything: %s" % ", ".join(missing))
	_check(doubled.is_empty(),
		"effects claimed as both implemented and outstanding: %s" % ", ".join(doubled))
	# A key listed but no longer authored is dead weight that makes the debt
	# look larger than it is.
	var stale: PackedStringArray = []
	for key: String in implemented + declared:
		if not authored.has(key):
			stale.append(key)
	_check(stale.is_empty(),
		"listed in DisciplineEffects but no node authors them: %s" % ", ".join(stale))
	print("[discipline] %d effects implemented, %d authored and still owed"
		% [implemented.size(), declared.size()])


func _test_every_node_can_be_offered() -> void:
	var before_seed: int = RunState.run_seed
	var before_segment: int = RunState.segment
	var before_wave: int = RunState.wave_number
	var before_act: int = RunState.act
	var before_trained: Array[String] = RunState.trained_discipline_nodes.duplicate()

	# The Mansion at its ceiling, so tier is not what is excluding anything -
	# that is the assertion below, and mixing the two would hide it.
	RunState.building_tiers["sanctum"] = 3
	RunState.trained_discipline_nodes = []

	# **Walked, not sampled from a standing start.**
	#
	# This used to clear the trained list once and read the offers, which was the
	# right test while the trees were flat: every node was available to everybody
	# from the first road. Since 2026-09-09 a node also wants depth in its own
	# discipline, so a tier-3 Blood node is *supposed* to be unreachable to a
	# player who has trained nothing - asserting otherwise would assert the tree
	# away.
	#
	# So each seed now plays a run instead: take an offer, which deepens that
	# discipline, and see what the next road opens. A node counts as reachable if
	# some path of choices reaches it. Every discipline is walked as the
	# preferred one in turn, because a Blood specialist must not be what proves
	# the Holy ultimate reachable.
	var offered: Dictionary = {}
	for seed_index: int in 40:
		for favour: int in 3:
			RunState.run_seed = 1000 + seed_index * 7919
			RunState.trained_discipline_nodes = []
			for segment: int in 12:
				RunState.segment = segment
				RunState.wave_number = segment * 3
				RunState.act = 1 + (segment % 3)
				RunState.refresh_discipline_offers()
				var take: String = ""
				for id: String in RunState.discipline_offers:
					offered[id] = true
					var node: DisciplineNodeData = ContentDB.discipline_node(id)
					# Prefer the favoured discipline, so depth actually accrues
					# somewhere rather than spreading one node per tree.
					if node != null and node.discipline == favour:
						take = id
					elif take.is_empty():
						take = id
				if not take.is_empty():
					RunState.trained_discipline_nodes.append(take)

	var missing: PackedStringArray = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if not offered.has(node.id):
			missing.append(node.id)
	_check(missing.is_empty(),
		"never offered across 480 roads, so nobody can train them: %s"
			% ", ".join(missing))
	print("[discipline] %d of %d nodes reachable through the rotation"
		% [offered.size(), ContentDB.discipline_nodes.size()])

	# A tree the player can finish is a checklist, not a build.
	RunState.hero_level = Balance.HERO_MAX_LEVEL
	_check(RunState.discipline_cap() < ContentDB.discipline_nodes.size(),
		"a maxed hero may train %d of %d nodes - at parity the tree stops being a choice"
			% [RunState.discipline_cap(), ContentDB.discipline_nodes.size()])

	RunState.run_seed = before_seed
	RunState.segment = before_segment
	RunState.wave_number = before_wave
	RunState.act = before_act
	RunState.trained_discipline_nodes = before_trained
	RunState.refresh_discipline_offers()
