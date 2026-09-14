extends Node

## The raccoon is a thief with an AI, and each part of it is measured on the
## real field: born with its sack less than always; takes the richest drop on
## the ground and not the nearest; never a piece a player put down; runs it to
## cover away from the hero and lies low half-seen; breaks cover and bolts
## when the hero comes close; forages the foliage when it has nothing and
## sometimes comes up with Gold; and when it dies everything it took comes
## back onto the ground.
##
##   godot --headless --path game res://tools/raccoon_check.tscn
##
## Driven through `Wildlife._tick_one` with the animal's own record, because
## the failure this guards is a thief that never notices, never hides, or
## keeps what it stole when it falls.

var _failures: PackedStringArray = []
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _animals: Wildlife = null
var _kind: WildlifeData = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	_animals = _field.wildlife() if _field != null else null
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.id == "raccoon":
			_kind = kind
	_check(_field != null and _animals != null and _kind != null, "the field, its wildlife and the raccoon")
	if _field != null and _animals != null and _kind != null:
		_check(_kind.hoards and _kind.steals and _kind.hoard_chance < 1.0,
			"the raccoon must hoard, steal, and not always be born with a sack")
		_field.sky().events_enabled = false
		if _field.wave_director != null:
			_field.wave_director.stop()
		# The road's bodies, not the camps': a camp whose bodies vanish is a
		# camp razed, and eight razed camps shower the field with loot.
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var enemy := node as Enemy
			if enemy != null and not enemy.is_camp_mob():
				enemy.queue_free()
		await get_tree().process_frame
		_test_not_every_raccoon_has_loot()
		await _test_it_takes_the_richest_and_hides()
		await _test_a_hero_breaks_cover()
		await _test_it_never_takes_what_a_player_put_down()
		await _test_it_forages()
		await _test_it_drops_everything_it_took()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[thieves] PASS - %d checks: the sack is a chance, the richest is taken, cover is "
			% _checks + "kept and broken, the player's is left, foraging pays, and death pays back")
	else:
		for failure: String in _failures:
			push_error("[thieves] " + failure)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _living() -> Array:
	return _animals.get("_living") as Array


## Spawns a raccoon settled at a point, with no sack, and returns its record.
## The hero stands a way off: near enough that the road does not forget the
## animal (`WILDLIFE_FORGET_DISTANCE`), far enough not to frighten it.
func _raccoon_at(at: Vector2) -> Dictionary:
	_field.hero.global_position = at + Vector2(0.0, 760.0)
	_animals.call("_spawn", _kind, at)
	var animal: Dictionary = _living().back()
	animal["state"] = Wildlife.State.SETTLED
	animal["goal"] = at
	animal["home"] = at
	animal["pause"] = 5.0
	animal["patience"] = 600.0
	(animal["sprite"] as Node2D).global_position = at
	if bool(animal.get("sack", false)):
		_animals.call("_set_sack", animal, animal["sprite"], _kind, false)
		animal["innate"] = false
	return animal


func _clear_animals() -> void:
	for animal: Dictionary in _living():
		var sprite := animal["sprite"] as Node2D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_living().clear()


func _clear_loot() -> void:
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		node.queue_free()


func _drops() -> Array[LootDrop]:
	var out: Array[LootDrop] = []
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and is_instance_valid(drop) and not drop.is_taken():
			out.append(drop)
	return out


## Ticks until the animal is lying low, or gives up after `seconds`. Cover is
## held for a while and then left, so a gate that waited a fixed sixty seconds
## and looked afterwards found it up and wandering again.
func _tick_until_hiding(animal: Dictionary, seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		_animals.call("_tick_one", animal, 0.1)
		left -= 0.1
		if bool(animal.get("hiding", false)):
			return true
	return false


## A clear spot a short walk from the animal, away from the hero, so the walk
## to cover cannot be cut short by ground it may not stand on. The choice of
## cover is measured separately; this is for what happens at it.
func _known_cover(animal: Dictionary) -> Vector2:
	var at: Vector2 = (animal["sprite"] as Node2D).global_position
	var away: Vector2 = (at - _field.hero.global_position).normalized()
	for turn: float in [0.0, 0.5, -0.5, 1.0, -1.0, 1.5, -1.5, 2.0, -2.0]:
		var spot: Vector2 = at + away.rotated(turn) * 220.0
		if bool(_animals.call("_is_clear", spot)):
			return spot
	return at


func _tick(animal: Dictionary, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		_animals.call("_tick_one", animal, 0.1)
		left -= 0.1


func _test_not_every_raccoon_has_loot() -> void:
	var with_sack: int = 0
	var count: int = 60
	_field.hero.global_position = Vector2(900.0, 1600.0)
	for index: int in count:
		_animals.call("_spawn", _kind, Vector2(800.0 + float(index) * 3.0, 900.0))
		if bool(_living().back().get("sack", false)):
			with_sack += 1
	var share: float = float(with_sack) / float(count)
	_check(share > 0.15 and share < 0.8,
		"%d of %d raccoons were born with a sack; the chance is %.2f" % [with_sack, count, _kind.hoard_chance])
	_clear_animals()


## Gold near, gear further: it takes the gear, then runs it to cover, lies
## low half-seen, and the drop is gone from the ground.
func _test_it_takes_the_richest_and_hides() -> void:
	_clear_loot()
	var at: Vector2 = Vector2(1000.0, 1000.0)
	var animal: Dictionary = _raccoon_at(at)
	_field.spawn_loot(RunState.GOLD, 20, at + Vector2(90.0, 0.0))
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 0, RunState.rng("gear"))
	_field.spawn_gear(piece, at + Vector2(-260.0, 0.0))
	await get_tree().process_frame
	await get_tree().process_frame
	var kinds: Dictionary = {}
	for drop: LootDrop in _drops():
		var key: String = "gear" if not drop.gear.is_empty() else ("plan" if not drop.blueprint.is_empty() else drop.currency)
		kinds[key] = int(kinds.get(key, 0)) + 1
	_check(_drops().size() == 2, "two drops on the ground to choose from (%d: %s)" % [_drops().size(), kinds])
	_tick(animal, 1.0)
	_check(int(animal["state"]) == Wildlife.State.SCAVENGING, "the raccoon did not notice the loot")
	var target := instance_from_id(int(animal.get("target_loot", 0))) as LootDrop
	_check(target != null and not target.gear.is_empty(), "the raccoon went for the coin over the gear")
	_tick(animal, 12.0)
	await get_tree().process_frame
	var loot: Array = animal.get("loot", [])
	_check(loot.size() == 1 and not (loot[0] as Dictionary).get("gear", {}).is_empty(), "the raccoon did not take the gear")
	_check(bool(animal.get("sack", false)) and (animal["sprite"] as Node).get_node_or_null("Sack") != null,
		"a raccoon carrying gear shows no sack")
	_check(_drops().size() == 1 and _drops()[0].currency == RunState.GOLD, "the gear is still on the ground, or the coin went too")
	_check(int(animal["state"]) == Wildlife.State.HIDING, "with the gear it did not run for cover")
	var cover: Vector2 = animal["goal"]
	_check(cover.distance_to(_field.hero.global_position) >= Balance.THIEF_HIDE_DISTANCE * 0.9,
		"its cover is %.0f from the hero" % cover.distance_to(_field.hero.global_position))
	animal["goal"] = _known_cover(animal)
	_check(_tick_until_hiding(animal, 40.0), "at its cover it is not lying low")
	_check((animal["sprite"] as CanvasItem).modulate.a < 0.9, "lying low it is fully seen")
	_clear_loot()
	_clear_animals()
	await get_tree().process_frame


func _test_a_hero_breaks_cover() -> void:
	var at: Vector2 = Vector2(1000.0, -1000.0)
	var animal: Dictionary = _raccoon_at(at)
	(animal["loot"] as Array).append({"currency": RunState.GOLD, "amount": 30, "gear": {}})
	_animals.call("_set_sack", animal, animal["sprite"], _kind, true)
	_animals.call("_run_for_cover", animal, animal["sprite"], at)
	animal["goal"] = _known_cover(animal)
	_check(_tick_until_hiding(animal, 40.0), "it never reached cover")
	var sprite := animal["sprite"] as Node2D
	_field.hero.global_position = sprite.global_position + Vector2(Balance.THIEF_HIDE_BREAK * 0.5, 0.0)
	_tick(animal, 0.5)
	_check(not bool(animal.get("hiding", false)) and int(animal["state"]) == Wildlife.State.FLEEING,
		"a hero at its side did not break its cover")
	_check(is_equal_approx((sprite as CanvasItem).modulate.a, 1.0), "bolting, it is still half seen")
	_check((animal["loot"] as Array).size() == 1, "bolting, it dropped what it held")
	_clear_animals()
	await get_tree().process_frame


func _test_it_never_takes_what_a_player_put_down() -> void:
	_clear_loot()
	var at: Vector2 = Vector2(-1000.0, 1000.0)
	var animal: Dictionary = _raccoon_at(at)
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 0, RunState.rng("gear"))
	_field.spawn_gear(piece, at + Vector2(80.0, 0.0))
	await get_tree().process_frame
	for drop: LootDrop in _drops():
		drop.player_dropped = true
	_tick(animal, 3.0)
	_check(int(animal["state"]) != Wildlife.State.SCAVENGING and (animal["loot"] as Array).is_empty(),
		"the raccoon went for a piece a player put down")
	_check(_drops().size() == 1, "the player's piece is gone")
	_clear_loot()
	_clear_animals()
	await get_tree().process_frame


## Set digging at a plant with nothing in its sack; enough digs come up with
## Gold, and the sack goes on when one does.
func _test_it_forages() -> void:
	var foliage: Foliage = _field.foliage_node()
	_check(foliage != null, "foliage to forage")
	if foliage == null:
		return
	var plants: Array[Dictionary] = foliage.plants_near(Vector2(1200.0, 1200.0), 1400.0)
	_check(not plants.is_empty(), "a plant to dig at")
	if plants.is_empty():
		return
	var plant: Vector2 = plants[0]["at"]
	var animal: Dictionary = _raccoon_at(plant)
	var found: bool = false
	for _dig: int in 40:
		animal["state"] = Wildlife.State.FORAGING
		animal["goal"] = plant
		animal["forage_left"] = 0.2
		(animal["sprite"] as Node2D).global_position = plant
		_tick(animal, 0.5)
		if not (animal["loot"] as Array).is_empty():
			found = true
			break
	_check(found, "forty digs came up with nothing")
	_check(bool(animal.get("sack", false)), "it found Gold and shows no sack")
	_clear_animals()
	await get_tree().process_frame


func _test_it_drops_everything_it_took() -> void:
	_clear_loot()
	var at: Vector2 = Vector2(1100.0, 300.0)
	var animal: Dictionary = _raccoon_at(at)
	var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 0, RunState.rng("gear"))
	(animal["loot"] as Array).append({"currency": RunState.GOLD, "amount": 33, "gear": {}})
	(animal["loot"] as Array).append({"currency": "", "amount": 0, "gear": piece})
	_animals.call("_set_sack", animal, animal["sprite"], _kind, true)
	var index: int = _living().find(animal)
	_animals.call("_wound", index, animal, 100000.0, true)
	await get_tree().process_frame
	await get_tree().process_frame
	var gold_back: int = 0
	var gear_back: int = 0
	for drop: LootDrop in _drops():
		if drop.currency == RunState.GOLD and drop.amount == 33:
			gold_back += 1
		if not drop.gear.is_empty():
			gear_back += 1
	_check(gold_back == 1, "the stolen Gold did not come back (%d)" % gold_back)
	_check(gear_back == 1, "the stolen piece did not come back (%d)" % gear_back)
	_clear_loot()
	_clear_animals()
	await get_tree().process_frame
