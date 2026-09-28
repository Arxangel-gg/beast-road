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
	_test_only_a_true_channel_roots_the_caster()
	_test_the_strike_is_seen_falling(meteor, volley)
	_test_the_beam_is_drawn()
	await _finish()


## **The thing that lands is seen falling** (owner, 2026-09-28: a spell showed
## *"a vfx forge animated sprite at a set distance away from the player without
## showing any projectiles"*). A meteor's streak is drawn from the same two
## numbers as its ring - the mark and the delay - so this reads both back off
## the record: it ends exactly where the strike will land, it starts above, and
## it lives exactly as long as the wait. A volley's thorns leave the hand on an
## arc. The ink is a canvas under a world, so the gate binds one for it.
func _test_the_strike_is_seen_falling(meteor: SpellData, volley: SpellData) -> void:
	var world := Node2D.new()
	world.name = "InkWorld"
	add_child(world)
	Vfx.bind_world(world)
	var ink: VfxInk = Vfx.ink()
	_checked += 1
	_check(ink != null, "no ink canvas came up under a bound world, so nothing below measures anything")
	if ink == null:
		return
	_equip(meteor)
	_caster.cancel_channel()
	_caster.clear_cooldowns()
	ink.clear()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var places: Array[Vector2] = _falling_places()
	var records: Array[Dictionary] = ink.streak_records()
	_checked += 1
	_check(places.size() == 1 and records.size() == 1,
		"%s put %d strikes in the air and %d streaks - the meteor is not seen falling"
			% [meteor.id, places.size(), records.size()])
	if places.size() == 1 and records.size() == 1:
		var record: Dictionary = records[0]
		_checked += 1
		_check((record["to"] as Vector2).is_equal_approx(places[0]),
			"%s's streak ends at %s and the strike lands at %s - the picture and the blow disagree"
				% [meteor.id, record["to"], places[0]])
		_checked += 1
		_check((record["from"] as Vector2).y < (record["to"] as Vector2).y - 100.0,
			"%s's streak does not come from above (%s to %s)" % [meteor.id, record["from"], record["to"]])
		_checked += 1
		_check(absf(float(record["life"]) - Balance.SPELL_METEOR_DELAY) < 0.02,
			"%s's streak lives %.2fs against a %.2fs wait - it would land before or after the blow"
				% [meteor.id, float(record["life"]), Balance.SPELL_METEOR_DELAY])
		_checked += 1
		_check(not (record["frames"] as Array).is_empty(),
			"%s's streak wears no painted head, so it is a line rather than a thing" % meteor.id)
	_equip(volley)
	_caster.cancel_channel()
	_caster.clear_cooldowns()
	ink.clear()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	places = _falling_places()
	records = ink.streak_records()
	_checked += 1
	_check(places.size() == records.size() and records.size() == Balance.SPELL_VOLLEY_STRIKES,
		"%s put %d strikes in the air and %d streaks" % [volley.id, places.size(), records.size()])
	var lobbed: int = 0
	var from_hand: int = 0
	var landing_on_a_mark: int = 0
	for record: Dictionary in records:
		if float(record["arc"]) > 0.0 and String(record["path"]) == "lob":
			lobbed += 1
		if (record["from"] as Vector2).is_equal_approx(Vector2.ZERO):
			from_hand += 1
		for place: Vector2 in places:
			if (record["to"] as Vector2).is_equal_approx(place):
				landing_on_a_mark += 1
				break
	_checked += 1
	_check(lobbed == records.size(), "%d of %s's %d thorns are not lobbed" % [records.size() - lobbed, volley.id, records.size()])
	_checked += 1
	_check(from_hand == records.size(), "%d of %s's thorns do not leave the hand" % [records.size() - from_hand, volley.id])
	_checked += 1
	_check(landing_on_a_mark == records.size(),
		"%d of %s's thorns land somewhere no strike is due" % [records.size() - landing_on_a_mark, volley.id])
	_caster.clear_cooldowns()
	ink.clear()


## **The beam is drawn as a beam** - a band from the hand to its end on every
## frame it is held, and on no frame after the channel ends. It used to be only
## the sheet at the far end, which is exactly the report above.
func _test_the_beam_is_drawn() -> void:
	var ink: VfxInk = Vfx.ink()
	if ink == null:
		Vfx.bind_world(null)
		return
	var beam: SpellData = null
	for id: Variant in ContentDB.spells:
		var spell: SpellData = ContentDB.spells[id] as SpellData
		if spell != null and spell.kind == SpellData.Kind.BEAM and spell.is_channelled:
			beam = spell
			break
	_checked += 1
	_check(beam != null, "no channelled BEAM to measure")
	if beam == null:
		Vfx.bind_world(null)
		return
	_equip(beam)
	_caster.cancel_channel()
	_caster.clear_cooldowns()
	ink.clear()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var ticks: int = 3
	for _i: int in ticks:
		_caster.tick(0.03, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(ink.live_beams() == ticks,
		"%s was held for %d frames and drew %d beams - the beam is not drawn every frame"
			% [beam.id, ticks, ink.live_beams()])
	if ink.live_beams() > 0:
		var record: Dictionary = ink.streak_records().duplicate() if false else {}
		# The last beam pushed is the one to read; the canvas keeps them in order.
		record = (ink.get("_beams") as Array)[ink.live_beams() - 1]
		var from: Vector2 = record["from"]
		var to: Vector2 = record["to"]
		_checked += 1
		_check(from.is_equal_approx(Vector2.ZERO) and to.x > 100.0 and absf(to.y) < 1.0,
			"%s's beam runs %s to %s, not from the hand along the aim" % [beam.id, from, to])
		_checked += 1
		_check(absf(float(record["width"]) - from.distance_to(to) * Balance.SPELL_BEAM_WIDTH_SHARE) < 0.5,
			"%s's beam is %.1f wide against a reach of %.0f" % [beam.id, float(record["width"]), from.distance_to(to)])
	var held: int = ink.live_beams()
	_caster.cancel_channel()
	for _i: int in ticks:
		_caster.tick(0.03, Vector2.RIGHT, Vector2.ZERO)
	_checked += 1
	_check(ink.live_beams() == held,
		"%s drew %d more beams after the channel ended" % [beam.id, ink.live_beams() - held])
	ink.clear()
	Vfx.bind_world(null)


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


## A BEAM is not automatically a channel, and reading it as one rooted the
## caster on every lance.
##
## `is_channelling` returned `_beam_left > 0.0`, so Frost Lance (0.5s) and Sky
## Lance (0.4s) pinned the hero in place and locked the whole spell bar for
## their duration - while `SpellData.is_channelled`, authored for exactly this
## distinction, was read by nothing in the project. The Arcane tree sells
## *where you are standing*; rooting it on every cast sold the opposite.
##
## Measured off the caster rather than off the flag, and both halves are
## required: a BEAM that is not channelled must still **be** a beam, or this
## would pass just as well on a spell that failed to cast at all.
func _test_only_a_true_channel_roots_the_caster() -> void:
	var channelled: int = 0
	var flashes: int = 0
	for id: Variant in ContentDB.spells:
		var spell: SpellData = ContentDB.spells[id] as SpellData
		if spell == null or spell.kind != SpellData.Kind.BEAM:
			continue
		_equip(spell)
		_caster.cancel_channel()
		_caster.clear_cooldowns()
		_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
		var beaming: bool = float(_caster.get("_beam_left")) > 0.0
		_checked += 1
		_check(beaming,
			"%s is a BEAM and casting it started no beam, so this gate is"
				% spell.id + " measuring a cast that never happened")
		_checked += 1
		_check(_caster.is_channelling() == spell.is_channelled,
			("%s authors is_channelled=%s and the caster says %s - a lance that"
				% [spell.id, spell.is_channelled, _caster.is_channelling()])
				+ " roots the hero takes away the one thing the Arcane sells")
		if spell.is_channelled:
			channelled += 1
		else:
			flashes += 1
		_caster.cancel_channel()
	# Both kinds have to exist or the distinction is untested and this gate
	# would go green on a roster where every BEAM is the same thing.
	_checked += 1
	_check(channelled > 0 and flashes > 0,
		("%d channelled BEAMs and %d flashes - the distinction needs both"
			% [channelled, flashes]))
