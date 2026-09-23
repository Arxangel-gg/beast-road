extends Node

## Nothing walks off the map, and the edge is one number.
##
##   godot --headless --path game res://tools/map_bounds_check.tscn
##
## Owner, 2026-09-22: the beasts *"sometimes will run off and attack a camp or
## try to leave the map or get lost ... ensure that they are not able to leave
## the map's bounds etc. And for any other enemies that might experience similar
## issues as well."*
##
## **The hero had been clamped since it was written and nothing else ever was.**
## `Battlefield.step_is_legal` refuses only the city and the base
## `EnemyField.step_is_legal` returns `true` outright, so a hard enough shove
## walked a body off the field and it kept going - where it can never arrive,
## never be killed, and never stop holding its wave open. Measured on the same
## day: a pounce left up to 821 units a second of drift on a body that walks at
## 96, which is off the map in a few seconds.
##
## **The four ways a body moves, and every one is held.** `Enemy._step` (the
## walk, the slide off a cliff and a commitment's shove), `Enemy._walk_camp`
## (a camp lord's patrol - the largest thing on the outskirts and the one that
## never walks a road), `Enemy._bounced` (knockback) and `Wildlife._walk_step`
## (every animal). A mover added later that writes `global_position` itself is
## the thing this gate cannot see, which is why the last test refuses a second
## hand-written copy of the edge.
##
## **Clamped, never refused.** A body that is already outside - thrown there by
## a funnel, spawned there by a harness, standing there when the ground was
## re-laid - has to be able to come back. A rule that refused an out-of-bounds
## destination would pin it there for the rest of the run, which is
## `step_is_legal`'s own reasoning about the city applied at the other edge.

const FRAME: float = 1.0 / 60.0
## Slack for one frame of travel past the line before the next step pulls it in.
const SLACK: float = 2.0

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
## Which tests reached their own last line. A GDScript runtime error stops the
## function it is in and nothing else, so a test that aborts halfway reads
## exactly like one that passed.
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260922)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 24:
		await get_tree().process_frame
	_field = _run.battlefield
	_check(_field != null, "the harness needs a battlefield")
	if _field == null:
		_finish()
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	for _frame: int in 4:
		await get_tree().process_frame

	await _test_no_body_can_be_thrown_off_the_field()
	await _test_a_body_outside_is_walked_back()
	await _test_a_camp_lord_patrols_inside()
	await _test_an_animal_keeps_to_the_map()
	_test_the_hero_and_the_bodies_share_an_edge()
	_test_the_edge_has_one_definition()
	for stage: String in ["thrown", "outside", "camp", "animal", "hero", "one"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check "
				+ "it had not made yet is a check nobody made") % stage)
	_finish()


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[bounds] " + why)


func _finish() -> void:
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 16:
		await get_tree().process_frame
	if _failures == 0:
		print(("[bounds] PASS - %d checks: no body or animal can be thrown off "
			+ "the field, one that is outside is walked back, and the edge is "
			+ "stated once") % _checks)
	else:
		push_error("[bounds] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _outside(at: Vector2) -> float:
	var edge: float = BattleGrid.play_extent()
	return maxf(absf(at.x) - edge, absf(at.y) - edge)


func _clear_bodies() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var body := node as Enemy
		if body != null and is_instance_valid(body):
			body.queue_free()


## **Every breed, thrown as hard as anything in the game throws.** A guarantee
## is a property of the whole roster or it is not a guarantee - the same lesson
## as the one breed `release_repair_check` used to ask about the wall.
func _test_no_body_can_be_thrown_off_the_field() -> void:
	var edge: float = BattleGrid.play_extent()
	var roster: Array[EnemyData] = []
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null:
			roster.append(breed)
	_check(roster.size() > 20, "the roster is %d breeds, which is not it" % roster.size())
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	var worst: float = -INF
	var worst_breed: String = ""
	for breed: EnemyData in roster:
		var body: Enemy = _field.spawn_enemy(breed, 0, 1.0)
		if body == null:
			continue
		# A corner, so both axes are tested at once, and hard enough that no
		# authored knockback resistance can make the shove trivial.
		body.global_position = Vector2(edge - 40.0, edge - 40.0)
		body.shove(Vector2.ZERO, 12000.0)
		for _frame: int in 90:
			body.call("_process", FRAME)
			var over: float = _outside(body.global_position)
			if over > worst:
				worst = over
				worst_breed = breed.id
		body.queue_free()
	_run.process_mode = Node.PROCESS_MODE_INHERIT
	_check(worst <= SLACK,
		("%s was thrown %.0f units past the field's edge. Nothing bounds a body "
			+ "but its own step, so one pushed out keeps going - it can never "
			+ "arrive, never be killed, and never stops holding its wave open")
			% [worst_breed, worst])
	_clear_bodies()
	await get_tree().process_frame
	_reached["thrown"] = true


## **Clamped, not refused.** A body that starts outside must be able to come in.
func _test_a_body_outside_is_walked_back() -> void:
	var edge: float = BattleGrid.play_extent()
	var breed: EnemyData = _a_breed()
	_check(breed != null, "the harness needs a breed")
	if breed == null:
		return
	var body: Enemy = _field.spawn_enemy(breed, 0, 1.0)
	_check(body != null, "the harness could not spawn a body")
	if body == null:
		return
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	body.global_position = Vector2(edge * 2.5, edge * 2.5)
	var started: float = _outside(body.global_position)
	for _frame: int in 240:
		body.call("_process", FRAME)
	var ended: float = _outside(body.global_position)
	_run.process_mode = Node.PROCESS_MODE_INHERIT
	_check(started > 0.0, "the harness did not place the body outside")
	_check(ended <= SLACK,
		("a body placed %.0f units outside the field was still %.0f units out "
			+ "after four seconds - the bound must clamp a stray back in, never "
			+ "refuse its step, or it is pinned out there for the run")
			% [started, ended])
	body.queue_free()
	await get_tree().process_frame
	_reached["outside"] = true


## A camp lord patrols the outskirts rather than walking a road, which makes it
## the body nearest the edge for the whole run - and the "beast" a player is
## most likely to go looking for.
func _test_a_camp_lord_patrols_inside() -> void:
	var edge: float = BattleGrid.play_extent()
	var breed: EnemyData = _a_breed()
	if breed == null:
		return
	var body: Enemy = _field.spawn_enemy(breed, 0, 1.0)
	if body == null:
		return
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	# Its home put outside on purpose: a patrol circles home, so a home off the
	# map is a body that presses on the border for the rest of the act.
	body.make_camp_mob(Vector2(edge * 1.4, 0.0), 600.0)
	body.global_position = Vector2(edge - 20.0, 0.0)
	var worst: float = -INF
	for _frame: int in 600:
		body.call("_process", FRAME)
		worst = maxf(worst, _outside(body.global_position))
	_run.process_mode = Node.PROCESS_MODE_INHERIT
	_check(worst <= SLACK,
		"a camp body patrolled %.0f units past the edge of the field" % worst)
	body.queue_free()
	await get_tree().process_frame
	_reached["camp"] = true


## Every animal, and a mythic in particular: one that wandered off the map is a
## legend nobody ever meets.
##
## **The Warden stands out by the corner with them.** An animal further than
## `WILDLIFE_FORGET_DISTANCE` from every hero is removed as out of sight, and the
## town is 3,800 units from a corner - so a harness that leaves the hero at home
## measures an empty field and passes whatever the animals do.
func _test_an_animal_keeps_to_the_map() -> void:
	var edge: float = BattleGrid.play_extent()
	var wildlife: Wildlife = _field.wildlife_system()
	_check(wildlife != null, "the battlefield has no wildlife system to ask")
	if wildlife == null:
		return
	var corner := Vector2(edge - 160.0, edge - 160.0)
	var hero: Hero = _field.hero
	_check(hero != null, "the harness needs the Warden standing near the animals")
	if hero == null:
		return
	hero.global_position = corner - Vector2(900.0, 900.0)
	var legend: WildlifeData = null
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind != null and kind.mythic:
			legend = kind
			break
	_check(legend != null, "no mythic species is authored")
	if legend != null:
		wildlife.place_mythic(legend, corner)
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	var living: Array = wildlife.get("_living") as Array
	_check(living.size() >= 2, "the field carries %d animals - too few to measure" % living.size())
	# Every animal settled at the corner with its haunt and its goal dragged
	# outside, which is what a species frightened often enough does to itself:
	# `home` moves a relocate-distance each time, so it random-walks its own
	# haunt off the edge. Everything but one, which is sent *away* over the edge.
	var leaver: Dictionary = {}
	for entry: Variant in living:
		var animal: Dictionary = entry as Dictionary
		var sprite: Node2D = animal.get("sprite") as Node2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		sprite.global_position = corner + Vector2(randf_range(-60.0, 60.0),
			randf_range(-60.0, 60.0))
		if leaver.is_empty() and (animal["data"] as WildlifeData) != legend:
			leaver = animal
			animal["state"] = Wildlife.State.LEAVING
			animal["goal"] = Vector2(edge * 1.25, edge * 1.25)
			continue
		animal["state"] = Wildlife.State.SETTLED
		animal["pause"] = 0.0
		animal["home"] = Vector2(edge * 1.8, edge * 1.8)
		animal["goal"] = Vector2(edge * 2.4, edge * 2.4)
	_check(not leaver.is_empty(), "no ordinary animal to send away over the edge")
	# Measured on **every frame**, and only of animals meant to stay: one that
	# walks far enough out is forgotten, so reading the survivors at the end
	# passes a stray precisely because it got away.
	var crossing: Array[int] = [Wildlife.State.ARRIVING, Wildlife.State.LEAVING]
	var worst: float = -INF
	var strays: Dictionary = {}
	var samples: int = 0
	var left_the_map: bool = false
	for _frame: int in 900:
		wildlife.call("_process", FRAME)
		if not leaver.is_empty() and not left_the_map:
			var gone: Variant = leaver.get("sprite")
			var freed: bool = not living.has(leaver) or not is_instance_valid(gone)
			left_the_map = freed or _outside((gone as Node2D).global_position) > SLACK
		for entry: Variant in living:
			var animal: Dictionary = entry as Dictionary
			if crossing.has(int(animal.get("state", -1))):
				continue
			var sprite: Variant = animal.get("sprite")
			if not is_instance_valid(sprite):
				continue
			samples += 1
			var over: float = _outside((sprite as Node2D).global_position)
			worst = maxf(worst, over)
			if over > SLACK:
				strays[animal.get("net_id", 0)] = true
	_run.process_mode = Node.PROCESS_MODE_INHERIT
	_check(samples > 0, "no staying animal was ever measured - the check read nothing")
	_check(worst <= SLACK,
		("%d animal(s) stood outside the field, the furthest by %.0f units - an "
			+ "animal off the map is an encounter the player can never reach")
			% [strays.size(), worst])
	# Arriving and leaving are the one time an animal is meant to cross the
	# edge. Held there too, a leaver walks at a way out it can never reach and
	# stands against the border for the rest of the run - the same "stuck at the
	# edge of the world" this gate exists to refuse, from the other side.
	_check(left_the_map,
		("an animal sent away over the edge was still inside after fifteen "
			+ "seconds - leaving has to be allowed to cross, or it is pinned at "
			+ "the border for ever"))
	hero.global_position = Vector2.ZERO
	_reached["animal"] = true


## The Warden and the things hunting them must agree about where the world ends.
func _test_the_hero_and_the_bodies_share_an_edge() -> void:
	var hero: Hero = _field.hero
	_check(hero != null, "the harness needs a hero")
	if hero == null:
		return
	_check(is_equal_approx(hero.bounds_extent.x, BattleGrid.play_extent())
		and is_equal_approx(hero.bounds_extent.y, BattleGrid.play_extent()),
		("the hero is clamped to %s and every body to %.0f - a body standing "
			+ "where the Warden cannot follow is a fight that cannot be had")
			% [hero.bounds_extent, BattleGrid.play_extent()])
	_reached["hero"] = true


## **One definition.** The edge was written out by hand in three places - the
## hero's clamp on the battlefield, the same clamp in co-op, and the knockback
## bounce - and the bounce's copy named the *battlefield's* extent even inside a
## raid arena, where the floor is several times smaller.
##
## A source walk, because the failure is a *second copy*: a fourth one added
## tomorrow would agree with the others until somebody tuned one of them.
func _test_the_edge_has_one_definition() -> void:
	var owners: Array[String] = ["res://scripts/systems/battle_grid.gd",
		"res://scripts/systems/raid_layout.gd"]
	# The edge is a whole tile in from the rim. A different inset - half a tile
	# to lay a tilemap, two tiles for a spawn ring - is a different number that
	# happens to share a spelling, so only a tile *not* multiplied is the edge.
	var edge := RegEx.new()
	edge.compile("HALF_EXTENT\\s*-\\s*(BattleGrid\\.|RaidLayout\\.)?TILE(?!\\s*\\*)")
	for path: String in _gameplay_scripts():
		if owners.has(path):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if text.is_empty():
			continue
		var number: int = 0
		for line: String in text.split("\n"):
			number += 1
			# Code only: a comment naming the old spelling is history, not a copy.
			var code: String = line.get_slice("#", 0)
			var found: RegExMatch = edge.search(code)
			if found == null:
				continue
			_check(false,
				("%s:%d writes the field's edge out by hand as \"%s\". It is "
					+ "stated once, in `play_extent()`, and asked through "
					+ "`EnemyField.hold_inside` - a second copy is one that "
					+ "disagrees the first time either is tuned")
					% [path, number, found.get_string()])
	_reached["one"] = true


func _gameplay_scripts() -> PackedStringArray:
	var found: PackedStringArray = []
	for folder: String in ["res://scripts/systems", "res://scenes/battlefield",
			"res://scenes/raid", "res://scenes/hero", "res://scenes/run"]:
		for name: String in DirAccess.get_files_at(folder):
			if name.ends_with(".gd"):
				found.append(folder + "/" + name)
	return found


func _a_breed() -> EnemyData:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED:
			return breed
	return null
