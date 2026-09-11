extends Node

## A ranged spell must land where it was aimed, and not before it is due.
##
## Owner request for more ranged spells, 2026-09-11. Every kind the game had
## resolved at the hero or in a line out of their hands; METEOR and VOLLEY are
## the first that strike a place the player merely pointed at, and that is
## exactly what makes them able to fail quietly:
##
## - **It lands on the hero instead.** The aim is a direction and `cast_range`
##   is a distance; multiply them in the wrong order, or forget the feet, and a
##   meteor is a nova with a longer animation. Nothing errors, the damage is
##   real, and the spell is simply a different spell.
## - **It lands immediately.** The delay is the whole design - bodies get a
##   moment to walk out of the circle - so a strike that resolves on the frame
##   it was cast has the description of a ranged spell and the behaviour of a
##   nova.
## - **It never lands.** A timer that is decremented but never fires costs mana,
##   draws the ring, and deals nothing at all.
## - **A volley is one hit.** Six small strikes and one big one are different
##   spells; the scatter is what makes aiming it a spread rather than a point.
## - **It survives the fight.** A strike still in the air when Preparation opens
##   would land on the construction screen, which is the one phase that is
##   supposed to be safe.
##
## Driven through the real `SpellCaster` against stand-in bodies, because the
## claim is about what the game does rather than what the resource says.
##
## **The loadout is re-equipped before every cast.** `RunState.reset` clears it
## and `_equip_starting_spells` refills it from the unlock pool, so a slot set
## once at the top of the file is the wrong spell by the third test - which is
## how the first run of this gate reported four failures that were all its own.

## **Real enemies, not stand-ins.** `EnemyField.enemies_near` casts every node
## in the group with `as Enemy`, so a scripted Node2D in that group is skipped
## in silence - a strike lands, damages nothing, and the gate reads it as a
## spell that never fired. The first run of this file said exactly that about
## three spells that were working.
const ENEMY_SCENE: String = "res://scenes/battlefield/enemy.tscn"

var _failures: int = 0
var _checked: int = 0
var _field: EnemyField = null
var _caster: SpellCaster = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260911)
	RunState.phase = RunState.Phase.ROAD_BATTLE
	await get_tree().process_frame

	_field = EnemyField.new()
	add_child(_field)
	_caster = SpellCaster.new()
	_caster.field = _field
	add_child(_caster)
	await get_tree().process_frame

	var meteor: SpellData = _spell_of_kind(SpellData.Kind.METEOR)
	var volley: SpellData = _spell_of_kind(SpellData.Kind.VOLLEY)
	_checked += 1
	_check(meteor != null and volley != null,
		"the ranged kinds must have content, or they are enum entries")
	if meteor == null or volley == null:
		await _finish()
		return

	await _test_it_lands_where_it_was_aimed(meteor)
	await _test_it_waits(meteor)
	await _test_a_volley_is_many(volley)
	await _test_preparation_clears_the_air(meteor)
	_test_the_same_seed_scatters_the_same_way(volley)
	await _finish()


## Aimed at a point, it hits the body standing there and not the one at the feet.
func _test_it_lands_where_it_was_aimed(spell: SpellData) -> void:
	var at_hero: Enemy = _dummy(Vector2.ZERO)
	var far: Enemy = _dummy(Vector2.RIGHT * spell.cast_range)
	_equip(spell)
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_caster.tick(Balance.SPELL_METEOR_DELAY + 0.2, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(_was_hit(far),
		"%s did not land on the point it was aimed at" % spell.id)
	_checked += 1
	_check(not _was_hit(at_hero),
		("%s landed on the caster as well, which makes it a nova with a longer "
			+ "animation") % spell.id)
	await _clear([at_hero, far])


## And it waits. A strike that resolves on the frame it was cast has the words
## of a ranged spell and the behaviour of a nova.
func _test_it_waits(spell: SpellData) -> void:
	var body: Enemy = _dummy(Vector2.RIGHT * spell.cast_range)
	_equip(spell)
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_caster.tick(0.01, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(not _was_hit(body),
		"%s landed instantly; the delay is what the bodies walk out of" % spell.id)
	_caster.tick(Balance.SPELL_METEOR_DELAY + 0.1, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(_was_hit(body),
		"%s never landed at all, so it cost mana and dealt nothing" % spell.id)
	await _clear([body])


## Six strikes rather than one, and they do not all fall on the same spot.
##
## Counted off the strikes in the air rather than off hits on a body, because a
## scattered volley is *supposed* to miss a point target with most of its hits -
## measuring it by one dummy's hit count tests the dummy's radius instead.
func _test_a_volley_is_many(spell: SpellData) -> void:
	_equip(spell)
	_caster.cancel_channel()
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var places: Array[Vector2] = _falling_places()
	_checked += 1
	_check(places.size() == Balance.SPELL_VOLLEY_STRIKES,
		"%s put %d strikes in the air, not %d"
			% [spell.id, places.size(), Balance.SPELL_VOLLEY_STRIKES])
	var distinct: Dictionary = {}
	for place: Vector2 in places:
		distinct[place] = true
	_checked += 1
	_check(distinct.size() > 1,
		("%s dropped every strike on one spot, which is a meteor with extra "
			+ "words") % spell.id)

	# **And they land where they scattered to.** A body standing at the aim
	# point is hit by a spread volley only about four times in five, which is a
	# coin toss wearing a gate's clothes; standing it under the first strike
	# tests the claim - that the places in the list are the places that are
	# struck - and is the same answer every run.
	var body: Enemy = _dummy(places[0])
	# The strikes were queued before the body existed; the scatter is seeded, so
	# re-casting from the same seeded stream puts them in the same places.
	for _step: int in 12:
		_caster.tick(0.5, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(_was_hit(body),
		"%s scattered its strikes and then landed none of them" % spell.id)
	await _clear([body])


## Preparation is the one phase that is supposed to be safe.
func _test_preparation_clears_the_air(spell: SpellData) -> void:
	var body: Enemy = _dummy(Vector2.RIGHT * spell.cast_range)
	_equip(spell)
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_caster.cancel_channel()
	_caster.tick(Balance.SPELL_METEOR_DELAY + 1.0, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(not _was_hit(body),
		("%s landed after the fight ended, on the one screen that is supposed "
			+ "to be safe") % spell.id)
	await _clear([body])


## The scatter comes out of the run's own stream, so a seed reproduces it.
func _test_the_same_seed_scatters_the_same_way(spell: SpellData) -> void:
	var first: Array[Vector2] = _scatter_of(spell, 20260911)
	var second: Array[Vector2] = _scatter_of(spell, 20260911)
	var other: Array[Vector2] = _scatter_of(spell, 111)
	_checked += 1
	_check(not first.is_empty() and first == second,
		"the same seed scattered a volley differently twice")
	_checked += 1
	_check(first != other,
		"two different seeds scattered a volley identically, so it is not rolled")


func _scatter_of(spell: SpellData, seed_value: int) -> Array[Vector2]:
	RunState.reset(false, seed_value)
	RunState.phase = RunState.Phase.ROAD_BATTLE
	_caster.cancel_channel()
	_caster.clear_cooldowns()
	_equip(spell)
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var out: Array[Vector2] = _falling_places()
	_caster.cancel_channel()
	return out


func _falling_places() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for entry: Variant in _caster.get("_falling"):
		out.append((entry as Dictionary)["at"])
	return out


## `RunState.reset` refills the loadout from the unlock pool, so every cast
## names its own spell rather than trusting the slot to have survived.
func _equip(spell: SpellData) -> void:
	if RunState.equipped_spells.is_empty():
		RunState.equipped_spells.append(spell.id)
	else:
		RunState.equipped_spells[0] = spell.id


func _spell_of_kind(kind: int) -> SpellData:
	var found: Array[String] = []
	for id: Variant in ContentDB.spells:
		var spell: SpellData = ContentDB.spells[id] as SpellData
		if spell != null and spell.kind == kind:
			found.append(spell.id)
	found.sort()
	if found.is_empty():
		return null
	return ContentDB.spells[found[0]] as SpellData


## One body, standing where it is put, with enough health to survive a meteor
## so that whether it was struck is what is measured rather than its death.
func _dummy(at: Vector2) -> Enemy:
	var ids: Array[String] = []
	for id: Variant in ContentDB.enemies:
		var data: EnemyData = ContentDB.enemies[id] as EnemyData
		if data != null and data.category == EnemyData.Category.BREED:
			ids.append(data.id)
	ids.sort()
	var breed: EnemyData = ContentDB.enemies[ids[0]] as EnemyData
	var foe := (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	foe.setup(breed, 0, _field, 40.0)
	_field.add_child(foe)
	foe.global_position = at
	return foe


## Frees the bodies and lets the tree actually drop them, so the run does not
## end with "resources still in use" - which this project treats as a red gate.
## Freed on the spot rather than queued.
##
## `queue_free` near the end of a headless run is a race: a node freed on the
## last frame before `quit` is still alive at exit, and Godot reports that as
## leaked objects, which the sweep reads as a red gate. Measured over three runs
## the queued version was dirty once and clean twice - a gate that fails one run
## in three trains everyone to re-run it, which is the same as not having one.
func _clear(bodies: Array) -> void:
	for body: Variant in bodies:
		var node := body as Node
		if node == null or not is_instance_valid(node):
			continue
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.free()
	await get_tree().process_frame


## Health taken is the evidence a blow landed: the body is real, so the damage
## goes through its own `take_damage` rather than a counter the gate invented.
func _was_hit(foe: Enemy) -> bool:
	if foe == null or not is_instance_valid(foe):
		return false
	return foe.health.current_hp < foe.health.max_hp


func _check(passed: bool, message: String) -> void:
	if passed:
		return
	_failures += 1
	print("[spell-strike] %s" % message)


func _finish() -> void:
	if _caster != null:
		_caster.cancel_channel()
		remove_child(_caster)
		_caster.free()
		_caster = null
	if _field != null:
		remove_child(_field)
		_field.free()
		_field = null
	# **Silence first, then ten frames, then quit** - the order `mana_check`
	# arrived at and the one this gate needed too. Every cast above played a
	# sound and drew a telegraph; a playback still running at exit is reported
	# as a resource still in use, and a ring still on screen as a leaked object,
	# and the sweep reads either as a red gate with every assertion green. This
	# file was dirty on three runs in five before the wait was long enough, and
	# a gate that fails one run in three teaches everyone to re-run it.
	Sfx.stop_immediately()
	Vfx.clear()
	for _frame: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MetaState.resume_saves()
	if _failures == 0:
		print("[spell-strike] PASS - %d checks; a ranged spell lands where it "
			% _checked + "was aimed, when it was due, and not after the fight")
	else:
		push_error("[spell-strike] FAIL - %d of %d" % [_failures, _checked])
	get_tree().quit(1 if _failures > 0 else 0)
