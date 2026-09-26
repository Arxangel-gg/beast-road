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
const EXPECTED_TESTS: int = 10


func _ready() -> void:
	# **Held for the whole run.** This gate edits MetaState in place - a wiped
	# tree, a raised level, a reset flag - and any save reached while that
	# scratch state is live overwrites a real player's file. One did, on
	# 2026-08-31, and a stash is the one thing here that cannot be restored.
	# Since 2026-09-26 the Disciplines are the account's too.
	MetaState.hold_saves()
	_fresh_tree()
	RunState.reset()
	# **A tripwire against loss, not a ceiling.** The count is asserted rather
	# than derived on purpose - a node that vanishes from the data is a hero
	# power silently disappearing, and nothing else in the project would notice.
	_check(ContentDB.discipline_nodes.size() == 40,
		"expected 40 authored discipline nodes, got %d" % ContentDB.discipline_nodes.size())
	# **A new Warden holds the free pair and nothing else**: the chain's first
	# form and a Defense skill in its slot.
	_check(RunState.learned_disciplines() == Balance.DISCIPLINE_STARTERS,
		"a new Warden must hold the free starters and nothing else, held %s"
			% str(RunState.learned_disciplines()))
	var form: DisciplineNodeData = RunState.chain_form()
	_check(form != null and form.id == Balance.DISCIPLINE_STARTING_FORM and form.is_form(),
		"a new Warden's chain must take the starting form")
	var defense: DisciplineNodeData = RunState.discipline_node_in_slot(1)
	_check(defense != null and Balance.DISCIPLINE_STARTERS.has(defense.id),
		"the starting Defense skill must sit in its slot")
	_check(RunState.discipline_node_in_slot(2) == null \
			and RunState.discipline_node_in_slot(3) == null,
		"Power and Ultimate must begin empty")
	for id: String in Balance.DISCIPLINE_STARTERS:
		_check(ContentDB.discipline_node(id) != null, "starter %s is not authored" % id)
	_check(ContentDB.discipline_node(Balance.DISCIPLINE_STARTING_FORM) != null
			and ContentDB.discipline_node(Balance.DISCIPLINE_STARTING_FORM).is_form()
			and Balance.DISCIPLINE_STARTERS.has(Balance.DISCIPLINE_STARTING_FORM),
		"the starting form must be a form, and free")

	_test_a_spell_can_always_be_cast()
	_test_the_tree_is_well_formed()
	_test_every_effect_is_accounted_for()
	_test_every_node_can_be_learned()
	_test_the_arcane_waits_for_the_second_act()

	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		_check(ResourceLoader.exists(node.get_sprite_path()),
			"missing discipline icon: %s" % node.get_sprite_path())

	await _test_mercy_under_fire()
	_test_synergies_are_real()
	await _test_second_wind_fires()
	await _test_the_brand_reaches_the_towers()
	await _test_the_riders_fire()
	_test_the_wound_pool_recovers()
	_test_points_never_leak()
	_test_the_rings_and_the_loadout_hold()
	_test_the_slots_open_on_the_road()
	await _test_the_forms_do_what_they_say()
	await _test_the_hold_screen_shapes_the_tree()

	# **A script error aborts its own function and nothing else.**
	# This gate printed PASS with three SCRIPT ERRORs above it, because the two
	# tests that died had simply stopped running and left no failures behind.
	if _finished != EXPECTED_TESTS:
		_check(false, ("only %d of %d awaited tests ran to completion - look for "
			+ "a SCRIPT ERROR above") % [_finished, EXPECTED_TESTS])

	if _failures.is_empty():
		print("[discipline] PASS — %d nodes, rings, points, loadout, forms and icons"
			% ContentDB.discipline_nodes.size())
	else:
		for failure: String in _failures:
			push_error("[discipline] " + failure)
	# The Mercy Under Fire test hurts a hero, and a hero being hurt plays a
	# sound. A voice still playing at exit leaks its Ogg stream, and a *warning*
	# fails this gate on the runner exactly as an assertion does.
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


## A new Warden's tree: the free pair, the first form, the Defense skill in
## its slot - exactly what a save with no hero block reads as.
func _fresh_tree() -> void:
	MetaState.call("_read_disciplines", {})


## A node learned for a test, past every rule: the harness setting up a state,
## never the door being tested. The doors are driven in the tests that own them.
func _learn(id: String) -> void:
	MetaState.discipline_tree[id] = 1


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
	_fresh_tree()
	_learn(node.id)

	var field := EnemyField.new()
	add_child(field)
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	hero.global_position = Vector2.ZERO

	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED \
				and one.knockback_resistance < 0.5:
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


## Whether one Warden could have every effect this synergy wants working at once.
##
## `DisciplineEffects.trained` reads the learned tree, not the slots, so any
## number of passive effects coexist freely. The trap is the effects read off
## one chosen thing: a chain form (one at a time) or a skill's slot (one skill a
## slot). Two effects needing the same one of those can never both be live.
func _can_hold_together(data: SynergyData) -> bool:
	var used: Dictionary = {}
	for effect_id: String in data.requires:
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.effect_id != effect_id:
				continue
			var place: String = ""
			if node.is_form():
				place = "form"
			elif node.is_active_slot():
				place = "slot %d" % node.slot_index()
			if place.is_empty():
				continue
			if used.has(place) and used[place] != effect_id:
				return false
			used[place] = effect_id
	return true


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
	_fresh_tree()
	for effect_id: String in ["active_attack_speed", "support_kill_speed"]:
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.effect_id == effect_id:
				_learn(node.id)
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
	# A form since 2026-09-26: chosen beside the slots, read off `chain_form`.
	_fresh_tree()
	_learn(brand_node.id)
	MetaState.discipline_form = brand_node.id

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
		"the chain's form did not brand priority prey, so the towers get nothing")
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

	# Slotted, not merely learned: these riders belong to the node in the slot.
	_fresh_tree()
	_learn(node.id)
	MetaState.discipline_loadout[0] = node.id
	RunState.equipped_spells[0] = spell.id

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
## **The Arcane opens with the second act, and the three melee trees do not
## wait** (owner, 2026-09-21: "unlock the magic discipline in the hero mansion
## after beating the Act 1 boss and unlocking act 2"). Driven through the one
## door - `eligible_discipline_nodes` - on a fresh account standing in Act I,
## then in the run that reaches Act II, then on an account that has reached it
## before; the table read back would pass with the door ignoring it.
func _test_the_arcane_waits_for_the_second_act() -> void:
	var before_act: int = RunState.act
	var before_best: float = MetaState.best_distance
	_fresh_tree()
	MetaState.best_distance = 0.0
	RunState.act = 1
	var arcane: int = DisciplineNodeData.Discipline.ARCANE
	_check(not RunState.discipline_is_open(arcane),
		"on a new account in Act I the Arcane is closed")
	_check(RunState.discipline_is_open(DisciplineNodeData.Discipline.BLOOD)
			and RunState.discipline_is_open(DisciplineNodeData.Discipline.HOLY)
			and RunState.discipline_is_open(DisciplineNodeData.Discipline.BERSERK),
		"and the three melee trees are open at once")
	_check(_arcane_nodes_open() == 0,
		"so no Arcane node is offered in Act I (%d were)" % _arcane_nodes_open())
	_check(_melee_nodes_open() == _ring_one_melee(),
		"while the melee trees open their whole first ring (%d of %d nodes)"
			% [_melee_nodes_open(), _ring_one_melee()])
	RunState.act = 2
	_check(_arcane_nodes_open() >= 3,
		"the run that reaches Act II opens the Arcane on the spot (%d nodes)"
			% _arcane_nodes_open())
	RunState.act = 1
	MetaState.best_distance = Balance.act_start_distance(2)
	_check(_arcane_nodes_open() >= 3,
		"and an account that has reached Act II keeps it open on a new road (%d nodes)"
			% _arcane_nodes_open())
	_check(RunState.discipline_opens_at(arcane) == 2,
		"the Mansion's copy names Act II (%d)" % RunState.discipline_opens_at(arcane))
	MetaState.best_distance = before_best
	RunState.act = before_act
	_fresh_tree()


## The first ring of the three melee arms, less the free pair.
func _ring_one_melee() -> int:
	var count: int = 0
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.ring == 1 and node.discipline != DisciplineNodeData.Discipline.ARCANE \
				and not Balance.DISCIPLINE_STARTERS.has(node.id):
			count += 1
	return count


func _arcane_nodes_open() -> int:
	var count: int = 0
	for node: DisciplineNodeData in RunState.eligible_discipline_nodes():
		if node.discipline == DisciplineNodeData.Discipline.ARCANE:
			count += 1
	return count


func _melee_nodes_open() -> int:
	var count: int = 0
	for node: DisciplineNodeData in RunState.eligible_discipline_nodes():
		if node.discipline != DisciplineNodeData.Discipline.ARCANE:
			count += 1
	return count


func _checked(condition: bool, failure: String) -> bool:
	_check(condition, failure)
	return condition


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


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

	# **And "implemented" is checked rather than trusted.**
	#
	# `DisciplineEffects` says in as many words that adding a key to
	# `IMPLEMENTED` without a consumer "is the exact lie this file exists to
	# prevent, and `discipline_check` cannot detect it". It can now: every key
	# on that list must be named by some script other than the ledger itself.
	# A grep is a weak proof of behaviour and a strong proof of *wiring*, which
	# is the half that was silently false for twenty-one effects.
	var unread: PackedStringArray = []
	for key: String in implemented:
		if not _named_in_code(key):
			unread.append(key)
	_check(unread.is_empty(),
		("listed as implemented and named by no script but the ledger, which is "
			+ "the placebo this file exists to prevent: %s") % ", ".join(unread))


## Whether any script outside the ledger mentions this key.
func _named_in_code(key: String) -> bool:
	const ROOTS: Array[String] = ["res://scenes", "res://scripts", "res://autoload"]
	var wanted: String = "\"%s\"" % key
	for root: String in ROOTS:
		if _mentions(root, wanted):
			return true
	return false


func _mentions(path: String, wanted: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return false
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		if directory.current_is_dir():
			if _mentions(full, wanted):
				directory.list_dir_end()
				return true
		elif name.ends_with(".gd") and name != "discipline_effects.gd":
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null and file.get_as_text().contains(wanted):
				directory.list_dir_end()
				return true
		name = directory.get_next()
	directory.list_dir_end()
	return false


## **A spell on a node nobody can equip is a spell nobody can cast.**
##
## `is_active_slot` is Attack, Defense, Power and Ultimate; a Passive or an
## Augment is trained and never slotted, so a `spell_id` on one is content that
## can never reach the combat bar. Two Arcane nodes were authored that way on
## 2026-09-13 - the Role enum is `ATTACK, DEFENSE, POWER, PASSIVE, ULTIMATE,
## AUGMENT` and they were written against the order `slot_index` returns, which
## puts Ultimate at 3 rather than 4.
##
## The same failure as a misspelt effect key, one layer up: the node trains, the
## card draws, and the thing it promised is unreachable.
func _test_a_spell_can_always_be_cast() -> void:
	var stranded: PackedStringArray = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.spell_id.is_empty():
			continue
		if not node.is_active_slot():
			stranded.append("%s (%s)" % [node.id, node.slot_name()])
		_check(ContentDB.spells.has(node.spell_id),
			"%s hands over \"%s\", which no spell names" % [node.id, node.spell_id])
	_check(stranded.is_empty(),
		("these carry a spell and sit in no slot, so the spell can never be cast: %s")
			% ", ".join(stranded))


## **The tree is a tree** (2026-09-26): every node in a ring its own arm can
## reach, every upgrade on a skill of its own arm, every form a form, and the
## tables the rings and slots are read from shaped for what they index.
##
## A ring nobody can open is `call_wolf` again - content that trains in the
## data and never on the road - and a count is only safe from that if the arm
## below the ring holds enough nodes to reach it.
func _test_the_tree_is_well_formed() -> void:
	var depth_table: Array[int] = Balance.DISCIPLINE_RING_DEPTH
	var arms: int = DisciplineNodeData.DISCIPLINE_NAMES.size()
	for arm: int in arms:
		var per_ring: Array[int] = [0, 0, 0, 0]
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.discipline == arm:
				per_ring[clampi(node.ring - 1, 0, 3)] += 1
		_check(per_ring[0] > 0, "%s has nothing in its first ring"
			% DisciplineNodeData.DISCIPLINE_NAMES[arm])
		var below: int = 0
		for ring: int in 4:
			if per_ring[ring] > 0:
				_check(below >= depth_table[ring],
					"%s ring %d wants %d learned below it and the arm holds %d"
						% [DisciplineNodeData.DISCIPLINE_NAMES[arm], ring + 1,
							depth_table[ring], below])
			below += per_ring[ring]
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		_check(node.ring >= 1 and node.ring <= 4, "%s sits in ring %d" % [node.id, node.ring])
		_check(int(node.kind) >= 0 and int(node.kind) < DisciplineNodeData.Kind.size(),
			"%s names kind %d, which the enum does not have" % [node.id, int(node.kind)])
		if node.is_form():
			_check(node.spell_id.is_empty(), "%s is a form and carries a spell" % node.id)
			_check(node.form_damage >= 0.0 and node.form_damage < 0.25,
				"%s adds %.2f to every swing" % [node.id, node.form_damage])
		else:
			_check(is_zero_approx(node.form_damage),
				"%s is not a form and authors form_damage" % node.id)
		if node.kind == DisciplineNodeData.Kind.UPGRADE:
			var parent: DisciplineNodeData = ContentDB.discipline_node(node.parent_id)
			if _checked(parent != null, "%s upgrades '%s', which is not a node" % [node.id, node.parent_id]):
				_check(parent.kind == DisciplineNodeData.Kind.SKILL
						and parent.discipline == node.discipline and parent.ring <= node.ring,
					"%s must upgrade a skill of its own arm no deeper than itself" % node.id)
	_check(Balance.DISCIPLINE_EARLY_SLOT_TIER.size() == Balance.HERO_MAX_SPELL_SLOTS,
		"the early-slot table must have one entry a slot")
	var mansion: BuildingData = ContentDB.building("sanctum")
	var top: int = mansion.effect_per_tier.size() if mansion != null else 0
	for slot: int in Balance.DISCIPLINE_EARLY_SLOT_TIER.size():
		_check(Balance.DISCIPLINE_EARLY_SLOT_TIER[slot] <= top,
			"slot %d opens early at Mansion tier %d, which cannot be built (top %d)"
				% [slot, Balance.DISCIPLINE_EARLY_SLOT_TIER[slot], top])


## **Every node can be learned, by some order of choices**, through the real
## door. Walked once favouring each arm, because a Blood specialist must not be
## what proves the Holy ultimate reachable.
func _test_every_node_can_be_learned() -> void:
	var saved_level: int = MetaState.hero_level
	var saved_clears: Dictionary = MetaState.first_clears.duplicate()
	var reached: Dictionary = {}
	var summit: int = Balance.ACT_COUNT + 1
	MetaState.hero_level = Balance.HERO_MAX_LEVEL
	MetaState.first_clears = {}
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		MetaState.first_clears[tier.id] = (1 << (summit)) - 1
	for favour: int in DisciplineNodeData.DISCIPLINE_NAMES.size():
		_fresh_tree()
		for id: String in RunState.learned_disciplines():
			reached[id] = true
		while true:
			var take: String = ""
			for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
				if not MetaState.learn_problem(node.id, summit).is_empty():
					continue
				if node.discipline == favour:
					take = node.id
					break
				if take.is_empty():
					take = node.id
			if take.is_empty():
				break
			var answer: String = MetaState.learn_discipline(take, summit)
			if not _checked(answer.is_empty(), "learning %s refused: %s" % [take, answer]):
				break
			reached[take] = true
	var missing: PackedStringArray = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if not reached.has(node.id):
			missing.append(node.id)
	_check(missing.is_empty(), "no order of choices learns: %s" % ", ".join(missing))

	# **One Normal clear is not the whole tree.** A Warden of the level a Normal
	# campaign ends near, holding every Normal first clear, must still be
	# choosing: the points buy part of the tree, never all of it.
	var normal: CampaignTierData = ContentDB.tiers_sorted()[0]
	MetaState.hero_level = normal.expected_level(Balance.ACT_COUNT)
	MetaState.first_clears = {normal.id: (1 << summit) - 1}
	var learnable: int = ContentDB.discipline_nodes.size() - Balance.DISCIPLINE_STARTERS.size()
	_check(MetaState.skill_points_earned() < learnable,
		"a Warden of level %d with every Normal clear earns %d points against %d nodes - the tree stops being a choice"
			% [MetaState.hero_level, MetaState.skill_points_earned(), learnable])
	MetaState.hero_level = Balance.HERO_MAX_LEVEL
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		MetaState.first_clears[tier.id] = (1 << summit) - 1
	print("[discipline] every node learnable; a full account earns %d points against %d nodes"
		% [MetaState.skill_points_earned(), learnable])
	MetaState.hero_level = saved_level
	MetaState.first_clears = saved_clears
	_fresh_tree()


## **Skill points cannot leak, and the tree is kept** (owner rulings R1, R2,
## 2026-09-26). Driven through the doors a player uses: learning in the Hold, a
## level earned after it, the next road, the save and its read, a first clear,
## and a front coming back.
func _test_points_never_leak() -> void:
	var original: Variant = JSON.parse_string(MetaState.serialized_save())
	var saved_run_active: bool = GameDirector.run_active
	GameDirector.run_active = false
	_fresh_tree()
	MetaState.first_clears = {}
	MetaState.hero_level = 10
	MetaState.hero_xp = 0.0
	RunState.reset()
	_check(RunState.skill_points() == 9,
		"a level-10 Warden with no clears holds 9 points, held %d" % RunState.skill_points())
	var ring_one: DisciplineNodeData = null
	for node: DisciplineNodeData in RunState.eligible_discipline_nodes():
		if node.ring == 1:
			ring_one = node
			break
	if _checked(ring_one != null, "a new Warden must have a first-ring node open"):
		_check(MetaState.learn_discipline(ring_one.id).is_empty(), "learning in the Hold must succeed")
		_check(RunState.skill_points() == 8, "and cost the point: %d of 9" % RunState.skill_points())
		RunState.gain_hero_xp(RunState.hero_xp_for_level(RunState.hero_level) + 1.0)
		RunState.gain_hero_xp(RunState.hero_xp_for_level(RunState.hero_level) + 1.0)
		_check(MetaState.hero_level == 12, "the harness must level the Warden twice")
		_check(RunState.skill_points() == 9,
			"levels 11 and 12 earn one more between them: %d of 9" % RunState.skill_points())
		RunState.reset()
		_check(MetaState.owns_discipline(ring_one.id) and RunState.skill_points() == 9,
			"the next road keeps the node and the points it left: %d" % RunState.skill_points())
		var saved: Variant = JSON.parse_string(MetaState.serialized_save())
		var hero: Dictionary = (saved as Dictionary).get("hero", {}) as Dictionary
		_check((hero.get("tree", {}) as Dictionary).has(ring_one.id),
			"the save must carry the learned tree")
		_check(int(hero.get("skill_points", -1)) == MetaState.skill_points_earned(),
			"the save must write the points earned, never the points left")
		MetaState.adopt_save(saved as Dictionary)
		_check(MetaState.owns_discipline(ring_one.id) and RunState.skill_points() == 9,
			"and read it back: the node held, %d points" % RunState.skill_points())

	# **A save that claims more than its points is trimmed**, and so is one that
	# holds a node no order of learning could have reached.
	var greedy: Dictionary = (JSON.parse_string(MetaState.serialized_save()) as Dictionary)
	var greedy_hero: Dictionary = greedy.get("hero", {}) as Dictionary
	var every: Dictionary = {}
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		every[node.id] = 1
	greedy_hero["tree"] = every
	greedy_hero["level"] = 3
	greedy["hero"] = greedy_hero
	MetaState.adopt_save(greedy)
	_check(MetaState.skill_points_spent() <= MetaState.skill_points_earned(),
		"a save claiming %d nodes on %d points must be trimmed to its points"
			% [every.size(), MetaState.skill_points_earned()])
	_check(MetaState.call("_stranded", MetaState.owned_disciplines()) == "",
		"and must hold nothing no order of learning could reach")
	var deep: DisciplineNodeData = null
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.ring == 3:
			deep = node
			break
	var stranded_save: Dictionary = (JSON.parse_string(MetaState.serialized_save()) as Dictionary)
	var stranded_hero: Dictionary = stranded_save.get("hero", {}) as Dictionary
	stranded_hero["tree"] = {deep.id: 1}
	stranded_hero["level"] = Balance.HERO_MAX_LEVEL
	stranded_save["hero"] = stranded_hero
	MetaState.adopt_save(stranded_save)
	_check(not MetaState.owns_discipline(deep.id),
		"a save holding %s with nothing beneath it must let it go" % deep.id)

	# **A first clear is a point, once a difficulty and act.**
	_fresh_tree()
	MetaState.first_clears = {}
	var before: int = MetaState.skill_points_earned()
	var tier_id: String = ContentDB.tiers_sorted()[0].id
	MetaState.note_first_clear(tier_id, 1)
	_check(MetaState.skill_points_earned() == before + Balance.SKILL_POINTS_PER_FIRST_CLEAR,
		"the first fall of an act's boss must earn a point")
	MetaState.note_first_clear(tier_id, 1)
	_check(MetaState.skill_points_earned() == before + Balance.SKILL_POINTS_PER_FIRST_CLEAR,
		"and the second fall of the same boss must not")

	var source: String = FileAccess.get_file_as_string("res://scripts/systems/expedition.gd")
	var at: int = source.find("static func apply(")
	var body: String = source.substr(at) if at >= 0 else ""
	var end: int = body.find("\nstatic func ", 1)
	body = body.substr(0, end) if end > 0 else body
	_check(body.contains("_sync_discipline_spells("),
		"Expedition.apply must restate the combat bar from the loadout the Warden holds now")
	_check(not source.contains("\"trained_discipline_nodes\""),
		"a banked front must not carry a tree: the tree is the account's")

	GameDirector.run_active = saved_run_active
	if original is Dictionary:
		MetaState.adopt_save(original as Dictionary)
	_fresh_tree()
	RunState.reset()
	_finished += 1


## **The rings, the reshaping and the loadout, through their doors.**
func _test_the_rings_and_the_loadout_hold() -> void:
	var saved_level: int = MetaState.hero_level
	var saved_run_active: bool = GameDirector.run_active
	var saved_phase: int = RunState.phase
	GameDirector.run_active = false
	MetaState.hero_level = Balance.HERO_MAX_LEVEL
	_fresh_tree()
	var blood: int = DisciplineNodeData.Discipline.BLOOD
	var ring_two: DisciplineNodeData = _first(blood, 2, DisciplineNodeData.Kind.SKILL)
	var ring_one: DisciplineNodeData = null
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.discipline == blood and node.ring == 1 and not MetaState.owns_discipline(node.id):
			ring_one = node
			break
	if _checked(ring_two != null and ring_one != null, "Blood needs a first- and second-ring node"):
		_check(not MetaState.learn_problem(ring_two.id).is_empty(),
			"%s must wait for its ring: Blood holds %d"
				% [ring_two.id, int(MetaState.discipline_depth().get(blood, 0))])
		_check(MetaState.learn_discipline(ring_one.id).is_empty(), "a first-ring node must be learnable")
		_check(MetaState.learn_discipline(ring_two.id).is_empty(),
			"%s must open once Blood holds %d" % [ring_two.id, Balance.DISCIPLINE_RING_DEPTH[1]])
		# Letting go of what a deeper node stands on is refused; the deeper first.
		_check(not MetaState.unlearn_problem(ring_one.id).is_empty(),
			"%s stands on %s and must keep it" % [ring_two.id, ring_one.id])
		_check(MetaState.unlearn_discipline(ring_two.id).is_empty()
				and MetaState.unlearn_discipline(ring_one.id).is_empty(),
			"letting go deepest first must succeed")
	for id: String in Balance.DISCIPLINE_STARTERS:
		_check(not MetaState.unlearn_problem(id).is_empty(), "the free pair cannot be let go: %s" % id)

	# An upgrade waits for its skill.
	var upgrade: DisciplineNodeData = null
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.kind == DisciplineNodeData.Kind.UPGRADE:
			upgrade = node
			break
	if _checked(upgrade != null, "the tree must hold an upgrade"):
		_fresh_tree()
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.discipline == upgrade.discipline and node.id != upgrade.parent_id \
					and node.id != upgrade.id and node.ring < upgrade.ring:
				_learn(node.id)
		_check(MetaState.learn_problem(upgrade.id).contains("first"),
			"%s must wait for %s, said: %s" % [upgrade.id, upgrade.parent_id,
				MetaState.learn_problem(upgrade.id)])
		_learn(upgrade.parent_id)
		_check(MetaState.learn_problem(upgrade.id).is_empty(),
			"and open once %s is learned" % upgrade.parent_id)

	# No points, no node.
	_fresh_tree()
	MetaState.hero_level = 1
	var first_free: DisciplineNodeData = RunState.eligible_discipline_nodes()[0] \
		if not RunState.eligible_discipline_nodes().is_empty() else null
	if _checked(first_free != null, "a new Warden must see something open"):
		_check(MetaState.learn_problem(first_free.id).contains("skill points"),
			"a level-1 Warden has no point to spend")
	MetaState.hero_level = Balance.HERO_MAX_LEVEL

	# **Reshaping is the Hold's.** On a live road the tree only grows.
	_fresh_tree()
	if ring_one != null:
		_learn(ring_one.id)
		GameDirector.run_active = true
		RunState.phase = RunState.Phase.PREPARATION
		_check(not MetaState.unlearn_problem(ring_one.id).is_empty(),
			"a node must not be let go on a live road")
		_check(not MetaState.reset_disciplines().is_empty() and MetaState.owns_discipline(ring_one.id),
			"and the tree must not be reset on one")
		GameDirector.run_active = false
		_check(MetaState.reset_disciplines().is_empty() and MetaState.discipline_tree.is_empty()
				and MetaState.discipline_form == Balance.DISCIPLINE_STARTING_FORM,
			"the Hold's reset must let the whole tree go and take up the first form")

	# **The road's doors**: Preparation, and a Mansion to learn in.
	_fresh_tree()
	GameDirector.run_active = true
	RunState.building_tiers["sanctum"] = 0
	var road_pick: DisciplineNodeData = RunState.eligible_discipline_nodes()[0]
	RunState.phase = RunState.Phase.ROAD_BATTLE
	_check(not RunState.try_learn_discipline(road_pick.id).is_empty(),
		"nothing is learned mid-fight")
	RunState.phase = RunState.Phase.PREPARATION
	_check(not RunState.try_learn_discipline(road_pick.id).is_empty(),
		"nothing is learned on the road without a Mansion")
	RunState.building_tiers["sanctum"] = 1
	_check(RunState.try_learn_discipline(road_pick.id).is_empty()
			and MetaState.owns_discipline(road_pick.id),
		"a Mansion in Preparation learns, and the account keeps it")

	# **The loadout**: a skill goes to its own slot; a form is chosen beside.
	_fresh_tree()
	var power: DisciplineNodeData = _first(blood, 2, DisciplineNodeData.Kind.SKILL, 2)
	if _checked(power != null, "Blood needs a Power skill"):
		_learn(power.id)
		_check(RunState.try_equip_discipline(power.id).is_empty()
				and MetaState.discipline_loadout[2] == power.id,
			"a learned Power skill goes into the Power slot")
		_check(not MetaState.set_discipline_slot(0, power.id).is_empty(),
			"and into no other")
	var passive: DisciplineNodeData = _first(-1, 0, DisciplineNodeData.Kind.PASSIVE)
	if passive != null:
		_learn(passive.id)
		_check(not RunState.try_equip_discipline(passive.id).is_empty(), "a passive is not slotted")
	var other_form: DisciplineNodeData = null
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.is_form() and node.id != Balance.DISCIPLINE_STARTING_FORM:
			other_form = node
			break
	if _checked(other_form != null, "the tree must hold a second form"):
		_check(not RunState.try_choose_form(other_form.id).is_empty(), "an unlearned form cannot be taken up")
		_learn(other_form.id)
		_check(RunState.try_choose_form(other_form.id).is_empty()
				and RunState.chain_form() == other_form,
			"a learned form is taken up")
		if power != null:
			_check(not RunState.try_choose_form(power.id).is_empty(), "a skill is not a form")

	RunState.phase = saved_phase
	GameDirector.run_active = saved_run_active
	MetaState.hero_level = saved_level
	_fresh_tree()
	_finished += 1


## The first node of an arm (-1: any) in a ring (0: any) of a kind, optionally
## in one slot.
func _first(arm: int, ring: int, kind: int, slot: int = -1) -> DisciplineNodeData:
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if (arm < 0 or node.discipline == arm) and (ring == 0 or node.ring == ring) \
				and node.kind == kind and (slot < 0 or node.slot_index() == slot):
			return node
	return null


## **The slots open on the road by the boss, or a boss sooner by the Mansion**
## (owner ruling R6, 2026-09-26), and the combat bar follows - through the
## signal a finished Mansion sends, never by being told.
func _test_the_slots_open_on_the_road() -> void:
	var saved_act: int = RunState.act
	_fresh_tree()
	var power: DisciplineNodeData = _first(-1, 0, DisciplineNodeData.Kind.SKILL, 2)
	var ultimate: DisciplineNodeData = _first(-1, 0, DisciplineNodeData.Kind.SKILL, 3)
	if not _checked(power != null and ultimate != null, "the tree needs a Power and an Ultimate skill"):
		_finished += 1
		return
	_learn(power.id)
	_learn(ultimate.id)
	MetaState.discipline_loadout[2] = power.id
	MetaState.discipline_loadout[3] = ultimate.id
	var cases: Array = [
		# act, Mansion tier, Power open, Ultimate open
		[1, 0, false, false], [1, 1, false, false], [1, 2, true, false], [1, 3, true, false],
		[2, 0, true, false], [2, 2, true, false], [2, 3, true, true],
		[3, 0, true, true]]
	for case: Array in cases:
		RunState.act = int(case[0])
		RunState.building_tiers["sanctum"] = int(case[1])
		EventBus.construction_completed.emit("sanctum", int(case[1]))
		var where: String = "Act %d, Mansion %d" % [case[0], case[1]]
		_check(RunState.slot_is_open(2) == bool(case[2]),
			"%s: Power should be %s" % [where, "open" if case[2] else "closed"])
		_check(RunState.slot_is_open(3) == bool(case[3]),
			"%s: Ultimate should be %s" % [where, "open" if case[3] else "closed"])
		_check((RunState.equipped_spells[2] == power.spell_id) == bool(case[2]),
			"%s: the bar casts '%s' from the Power slot" % [where, RunState.equipped_spells[2]])
		_check((RunState.equipped_spells[3] == ultimate.spell_id) == bool(case[3]),
			"%s: the bar casts '%s' from the Ultimate slot" % [where, RunState.equipped_spells[3]])
	_check(RunState.slot_opens_note(3).contains("Mansion"),
		"a closed Ultimate slot must say the Mansion can open it sooner")
	var boss: String = FileAccess.get_file_as_string("res://scripts/systems/boss_director.gd")
	_check(boss.contains("RunState._sync_discipline_spells()"),
		"a boss falling must restate the combat bar, which is when a slot opens")
	RunState.act = saved_act
	_fresh_tree()
	RunState.reset()
	_finished += 1


## **Every form does what its card says** (2026-09-26). Two of the four were a
## flat multiplier behind a sentence about something else: Cleaving Road said
## the finisher "gains force for each enemy struck" and Consecrated Chain that
## it "splashes radiant damage near defenses". Driven through a real finisher
## into real bodies.
func _test_the_forms_do_what_they_say() -> void:
	var field := EnemyField.new()
	add_child(field)
	var owner := Node2D.new()
	add_child(owner)
	var attack := HeroAttack.new()
	owner.add_child(attack)
	await get_tree().process_frame
	var aim: Vector2 = Vector2.RIGHT
	var origin: Vector2 = Vector2(2000.0, 2000.0)
	var reach: float = Balance.HERO_ATTACK_RANGE[Balance.HERO_CHAIN_LENGTH - 1] * attack.reach_scale()

	# Cleaving Road: the same body, alone and in a crowd of four.
	_fresh_tree()
	var cleave: DisciplineNodeData = ContentDB.discipline_node("cleaving_road")
	if _checked(cleave != null and cleave.effect_id == "crowd_finisher_force",
			"Cleaving Road must carry crowd_finisher_force"):
		_learn(cleave.id)
		MetaState.discipline_form = cleave.id
		var alone: float = await _shove(field, attack, origin, aim, 1)
		var crowded: float = await _shove(field, attack, origin, aim, 4)
		var wanted: float = 1.0 + cleave.effect_value * 3.0
		_check(alone > 0.0 and absf(crowded / alone - wanted) < 0.05,
			"Cleaving Road's finisher shoves %.2f times as hard into four as into one, the card says %.2f"
				% [crowded / maxf(alone, 0.001), wanted])

	# Consecrated Chain: a body past the swing's reach, near a tower and not.
	var radiant: DisciplineNodeData = ContentDB.discipline_node("consecrated_chain")
	if _checked(radiant != null and radiant.effect_id == "defense_radiant_finisher",
			"Consecrated Chain must carry defense_radiant_finisher"):
		_learn(radiant.id)
		MetaState.discipline_form = radiant.id
		var tower := Node2D.new()
		add_child(tower)
		tower.global_position = origin + Vector2(0.0, 80.0)
		tower.add_to_group(Tower.GROUP)
		var near_loss: float = await _splash(field, attack, origin, aim, reach)
		tower.remove_from_group(Tower.GROUP)
		var far_loss: float = await _splash(field, attack, origin, aim, reach)
		_check(near_loss > 0.0,
			"Consecrated Chain's finisher beside a tower did not splash a body past its reach")
		_check(is_zero_approx(far_loss),
			"and away from every tower it must not splash (%.1f)" % far_loss)
		tower.queue_free()
		MetaState.discipline_form = Balance.DISCIPLINE_STARTING_FORM
		var plain_loss: float = await _splash(field, attack, origin, aim, reach)
		_check(is_zero_approx(plain_loss), "another form must not splash (%.1f)" % plain_loss)

	# And a form's own share reaches every swing, through the hero.
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	MetaState.discipline_form = "hemorrhage_edge"
	var bleed: float = hero.damage_multiplier()
	MetaState.discipline_form = "judgment_brand"
	var brand: float = hero.damage_multiplier()
	var bleed_node: DisciplineNodeData = ContentDB.discipline_node("hemorrhage_edge")
	var brand_node: DisciplineNodeData = ContentDB.discipline_node("judgment_brand")
	_check(bleed_node != null and brand_node != null and is_equal_approx(bleed / brand,
			(1.0 + bleed_node.form_damage) / (1.0 + brand_node.form_damage)),
		"a form's authored share must reach every swing: %.3f against %.3f" % [bleed, brand])

	hero.queue_free()
	attack.queue_free()
	owner.queue_free()
	await get_tree().process_frame
	field.queue_free()
	for _f: int in 12:
		await get_tree().process_frame
	_fresh_tree()
	_finished += 1


## The finisher into `count` bodies in the arc, and the first one's shove.
func _shove(field: EnemyField, attack: HeroAttack, origin: Vector2, aim: Vector2, count: int) -> float:
	var bodies: Array[Enemy] = []
	for index: int in count:
		var body: Enemy = await _body(field, func(breed: EnemyData) -> bool:
			return breed.category == EnemyData.Category.BREED and breed.knockback_resistance < 0.3)
		if body == null:
			return 0.0
		var lift: Vector2 = body.combat_origin() - body.global_position
		body.global_position = origin + aim * 50.0 + Vector2(0.0, -30.0 + 20.0 * index) - lift
		bodies.append(body)
	_finisher(attack, origin, aim)
	var shove: float = (bodies[0].get("_knockback") as Vector2).length()
	for body: Enemy in bodies:
		body.queue_free()
	await get_tree().process_frame
	return shove


## The finisher into one body in front, with a second standing just past its
## reach; returns what the second lost.
func _splash(field: EnemyField, attack: HeroAttack, origin: Vector2, aim: Vector2, reach: float) -> float:
	var struck: Enemy = await _body(field, func(breed: EnemyData) -> bool:
		return breed.category == EnemyData.Category.BREED)
	var beyond: Enemy = await _body(field, func(breed: EnemyData) -> bool:
		return breed.category == EnemyData.Category.BREED)
	if struck == null or beyond == null:
		return -1.0
	var lift: Vector2 = struck.combat_origin() - struck.global_position
	struck.global_position = origin + aim * 50.0 - lift
	beyond.global_position = origin + aim * (reach + beyond.contact_radius() + 12.0) - lift
	var before: float = beyond.health.current_hp
	_finisher(attack, origin, aim)
	var lost: float = before - beyond.health.current_hp
	struck.queue_free()
	beyond.queue_free()
	await get_tree().process_frame
	return lost


## One finisher's strike, set up as `_begin_swing` would leave it.
func _finisher(attack: HeroAttack, origin: Vector2, aim: Vector2) -> void:
	attack.set("_step", Balance.HERO_CHAIN_LENGTH - 1)
	attack.set("_swing_origin", origin)
	attack.set("_swing_aim", aim)
	(attack.get("_hit_ids") as Dictionary).clear()
	attack.set("_announced", false)
	attack.set("_radiant_done", false)
	attack.call("_strike")


## **The Hold's screen shapes the tree through its own buttons** (2026-09-26),
## and writes nothing when it is only looked at - the rule the Glass and the
## comfort card were built under.
func _test_the_hold_screen_shapes_the_tree() -> void:
	var saved_level: int = MetaState.hero_level
	var saved_run_active: bool = GameDirector.run_active
	GameDirector.run_active = false
	MetaState.hero_level = 20
	_fresh_tree()
	var screen := DisciplinesScreen.new()
	add_child(screen)
	await get_tree().process_frame
	var before: String = MetaState.serialized_save()
	screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	screen.close()
	_check(MetaState.serialized_save() == before, "opening and closing the screen must write nothing")
	screen.open()
	await get_tree().process_frame
	var buttons: Dictionary = screen.get("_nodes")
	_check(buttons.size() == ContentDB.discipline_nodes.size(),
		"the map must draw every node: %d of %d" % [buttons.size(), ContentDB.discipline_nodes.size()])
	# No two nodes stand on each other, at the size the screen chose for them.
	var overlaps: PackedStringArray = []
	var ids: Array = buttons.keys()
	for a: int in ids.size():
		for b: int in range(a + 1, ids.size()):
			var one: TextureButton = buttons[ids[a]]
			var other: TextureButton = buttons[ids[b]]
			if one.get_rect().grow(-2.0).intersects(other.get_rect().grow(-2.0)):
				overlaps.append("%s/%s" % [ids[a], ids[b]])
	_check(overlaps.is_empty(), "nodes drawn on top of each other: %s" % ", ".join(overlaps))

	# Learn, through the node and the button.
	var pick: DisciplineNodeData = null
	for node: DisciplineNodeData in RunState.eligible_discipline_nodes():
		if node.is_active_slot():
			pick = node
			break
	if _checked(pick != null, "a new Warden must see a skill open on the map"):
		(buttons[pick.id] as TextureButton).pressed.emit()
		var learn: Button = screen.get("_learn_button")
		_check(learn.visible and not learn.disabled, "an open node must offer Learn")
		learn.pressed.emit()
		_check(MetaState.owns_discipline(pick.id), "Learn must learn it")
		var use: Button = screen.get("_use_button")
		_check(use.visible and not use.disabled, "a learned skill must offer its slot")
		use.pressed.emit()
		_check(MetaState.discipline_loadout[pick.slot_index()] == pick.id, "and the slot must take it")
		var forget: Button = screen.get("_forget_button")
		_check(forget.visible and not forget.disabled, "a learned node must offer Let go in the Hold")
		forget.pressed.emit()
		_check(not MetaState.owns_discipline(pick.id)
				and MetaState.discipline_loadout[pick.slot_index()] != pick.id,
			"Let go must forget it and empty its slot")
		MetaState.learn_discipline(pick.id)
		var reset: Button = screen.get("_reset_button")
		reset.pressed.emit()
		_check(MetaState.owns_discipline(pick.id), "one press of the reset must only arm it")
		reset.pressed.emit()
		_check(MetaState.discipline_tree.is_empty(), "the second press must let the tree go")
	screen.close()
	screen.queue_free()
	await get_tree().process_frame
	GameDirector.run_active = saved_run_active
	MetaState.hero_level = saved_level
	_fresh_tree()
	_finished += 1
