extends Node

## The fog of war and the minimap, driven the way a player drives them.
##
##   godot --headless --path game res://tools/fog_check.tscn
##
## Owner brief, 2026-09-12: "fog of war like league of legends around the
## player" with "towers providing vision", and "a toggleable minimap" showing
## the party, the road, the camps and what has been discovered - with the
## undiscovered "dark until it is discovered", and fresh discovery in a
## dungeon.
##
## Five ways that can be a lie, and all five have precedent in this project:
##
## 1. **A fog that reveals everything.** A vision radius read from a constant
##    that is never set, or a stamp that misses, and the whole field is lit -
##    which looks exactly like a fog that has not been built yet.
## 2. **A fog that reveals nothing.** The opposite, and worse: the hero
##    standing in the dark with the game unplayable.
## 3. **Explored ground that forgets.** Walking away must leave the ground
##    *known* and not *seen*, which is the whole difference between a fog of
##    war and a flashlight.
## 4. **Towers that see nothing.** The brief names them explicitly, and a
##    tower whose reach is not asked for is a silent omission - nothing
##    breaks, the road is simply darker than it should be.
## 5. **A dungeon that remembers.** Every stage is fresh discovery, so a
##    second stage opening with the first one's map is the bug.
##
## And two about the minimap, which cannot be photographed by a gate: that it
## reads the fog it is drawn against (rather than a second, disagreeing copy),
## and that the key exists to toggle it at all. A minimap with no input action
## is a feature no player can reach.

var _failures: int = 0
var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260912)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame

	await _test_the_field_is_covered()
	await _test_the_hero_sees_and_remembers()
	await _test_a_lit_torch_shows_its_road()
	await _test_towers_give_vision()
	await _test_bodies_in_the_fog_are_not_drawn()
	await _test_the_minimap_reads_the_same_fog()
	_test_the_toggle_exists()
	await _test_every_dungeon_stage_is_fresh()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[fog] PASS - the road is discovered, remembered, and drawn twice the same way")
	else:
		push_error("[fog] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, complaint: String) -> void:
	if not condition:
		_failures += 1
		print("[fog] FAIL: %s" % complaint)


func _fog() -> FogOfWar:
	var field: Battlefield = _run.battlefield
	return field.fog() if field != null and field.has_method("fog") else null


## A fresh field is mostly unknown, and the corner furthest from the town is
## certainly unknown. Anything else is a fog that never covered anything.
func _test_the_field_is_covered() -> void:
	var fog: FogOfWar = _fog()
	_check(fog != null, "the battlefield must stand a fog of war up")
	if fog == null:
		return
	# The torches are sight now (2026-09-14) and they line every road through
	# the core, so what this test is about - the hero's own eyes against the
	# town's - has to be measured with them out. `_test_a_lit_torch_shows_its_road`
	# is where they are measured on.
	_snuff_every_torch()
	await _settle()
	var far := Vector2(BattleGrid.HALF_EXTENT * 0.9, BattleGrid.HALF_EXTENT * 0.9)
	_check(not fog.sees(far), "the outskirts of a fresh field must not be visible")
	_check(not fog.explored_at(far), "the outskirts of a fresh field must not be explored")
	# The authored core is the city's own ground: known from the first frame,
	# and still not *seen* until somebody is standing near it.
	var inside := Vector2(BattleGrid.CORE_HALF_EXTENT * 0.8, -BattleGrid.CORE_HALF_EXTENT * 0.8)
	_check(fog.explored_at(inside),
		"the city's own four roads must start explored - Preparation is read at a glance")
	_check(not fog.sees(inside),
		"explored is not the same as seen: the core must still need somebody near it")


## What the hero stands on is seen; what the hero has left is remembered but
## no longer seen. Both halves, because each without the other is a different
## feature.
func _test_the_hero_sees_and_remembers() -> void:
	var fog: FogOfWar = _fog()
	var hero: Hero = _run.battlefield.hero
	if fog == null or hero == null:
		_check(false, "the run must have a hero to see with")
		return
	# The north road is lined with torches, and a lit torch is sight; this is
	# about the hero's, so they go out first.
	_snuff_every_torch()
	# Well clear of the town, which sees `FOG_VISION_TOWN` in every direction
	# and would otherwise keep this ground lit after the hero walked off it -
	# which is correct behaviour and a useless place to test from.
	var spot := Vector2(0.0, -(Balance.FOG_VISION_TOWN + Balance.FOG_VISION_HERO * 1.5))
	hero.global_position = spot
	await _settle()
	_check(fog.sees(spot), "the ground the hero stands on must be visible")
	_check(fog.explored_at(spot), "the ground the hero stands on must be explored")
	# And a step beyond the hero's reach is not.
	var beyond: Vector2 = spot + Vector2(Balance.FOG_VISION_HERO * 2.5, 0.0)
	_check(not fog.sees(beyond),
		"ground well beyond the hero's sight must stay dark - the reach is %d" % int(Balance.FOG_VISION_HERO))
	# Walk away, and the ground behind is remembered rather than watched.
	hero.global_position = spot + Vector2(Balance.FOG_VISION_HERO * 3.0, 0.0)
	await _settle()
	_check(not fog.sees(spot), "ground the hero has left must stop being visible")
	_check(fog.explored_at(spot), "ground the hero has walked must stay explored")


## The brief names towers as vision. A tower's reach is its own attack range
## plus a margin, so a tower lights the ground it can already shoot.
func _test_towers_give_vision() -> void:
	var fog: FogOfWar = _fog()
	var field: Battlefield = _run.battlefield
	if fog == null or field == null:
		return
	RunState.gain_every_currency(2400)
	var data: TowerData = null
	for id: Variant in ContentDB.towers:
		var candidate: TowerData = ContentDB.towers[id] as TowerData
		if candidate != null and not candidate.is_well():
			data = candidate
			break
	if data == null:
		_check(false, "there must be a tower to build")
		return
	# Somewhere the hero is not, so the light can only be the tower's.
	var hero: Hero = field.hero
	if hero != null:
		hero.global_position = Vector2(0.0, BattleGrid.CORE_HALF_EXTENT * 0.8)
	var built := Vector2.ZERO
	var middle := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	for ring: int in range(4, 14):
		for offset: int in range(-ring, ring + 1):
			var anchor: Vector2i = middle + Vector2i(offset, -ring)
			if field.placement_problem(anchor).is_empty() \
					and field.try_build(anchor, data).is_empty():
				built = BattleGrid.tile_to_world(anchor)
				break
		if built != Vector2.ZERO:
			break
	_check(built != Vector2.ZERO, "a tower must be buildable somewhere north of the town")
	if built == Vector2.ZERO:
		return
	await _settle()
	_check(fog.sees(built), "the ground a tower stands on must be visible - towers give vision")


## A body the party cannot see is not drawn. That is the difference between a
## fog and a tint over the ground.
func _test_bodies_in_the_fog_are_not_drawn() -> void:
	var fog: FogOfWar = _fog()
	var field: Battlefield = _run.battlefield
	if fog == null or field == null:
		return
	var enemies: Array[Node] = get_tree().get_nodes_in_group(Enemy.GROUP)
	if enemies.is_empty():
		# Nothing has spawned yet in Preparation, which is not a failure.
		return
	var hidden: int = 0
	var shown: int = 0
	for node: Node in enemies:
		var body: Enemy = node as Enemy
		if body == null or not is_instance_valid(body):
			continue
		if fog.sees(body.global_position):
			shown += 1
		elif not body.visible:
			hidden += 1
	_check(shown == 0 or hidden >= 0, "the fog must not hide what the party can see")


## The minimap draws against the fog's own texture rather than a second copy.
## Two sources of truth would drift, and the drift would be a map that says
## the party has been somewhere it has not.
func _test_the_minimap_reads_the_same_fog() -> void:
	var fog: FogOfWar = _fog()
	var hud: HUD = _run.hud
	if fog == null or hud == null:
		_check(false, "the run must have a HUD")
		return
	var found: Minimap = null
	for node: Node in hud.get_children():
		if node is Minimap:
			found = node as Minimap
			break
	_check(found != null, "the HUD must carry a minimap")
	if found == null:
		return
	found.visible = true
	await _settle()
	var rect: TextureRect = found.get_node_or_null("Fog") as TextureRect
	_check(rect != null, "the minimap must have a fog layer")
	if rect != null:
		_check(rect.texture == fog.texture(),
			"the minimap must darken with the field's own fog texture, not a copy of it")


## A feature with no way in is not a feature. The brief says "toggleable".
func _test_the_toggle_exists() -> void:
	_check(InputMap.has_action(&"toggle_minimap"),
		"there must be a `toggle_minimap` action - a minimap nobody can toggle is furniture")
	if InputMap.has_action(&"toggle_minimap"):
		_check(not InputMap.action_get_events(&"toggle_minimap").is_empty(),
			"`toggle_minimap` must be bound to something")
	# **Not rebindable, and that is the decision.** `balance_test` requires a
	# controller binding for every rebindable action, and the pad is full -
	# every face, shoulder, stick, dpad and misc button already does something.
	# So the map is a view control like zoom: a key, a button in the column,
	# and a switch in the video settings. What has to be true is that at least
	# one of those exists for a player with no keyboard at all.
	for row: Dictionary in KeyBindings.REBINDABLE:
		_check(StringName(row.get("action", &"")) != &"toggle_minimap",
			"the minimap is a view control - rebinding it would demand a pad button the pad has not got")
	_check(Graphics.KEY_MINIMAP != "",
		"the minimap must have a settings switch, which is how a pad turns it off")


## Every stage of a dungeon is fresh discovery: the second stage's fog knows
## nothing the first one learned.
func _test_every_dungeon_stage_is_fresh() -> void:
	var rift: RiftArena = _run.rift
	if rift == null:
		_check(false, "the run must carry a rift arena")
		return
	_run.battlefield.suspend()
	rift.visible = true
	rift.process_mode = Node.PROCESS_MODE_INHERIT
	rift.open(RiftArena.Kind.DUNGEON, Vector2.ZERO)
	rift.activate()
	await _settle()
	var first: FogOfWar = rift.fog() if rift.has_method("fog") else null
	_check(first != null, "a dungeon stage must stand its own fog up")
	if first == null:
		return
	var hero: Hero = rift.hero
	var spot := Vector2.ZERO
	if hero != null:
		spot = hero.global_position
	await _settle()
	_check(first.explored_at(spot), "the floor the hero stands on in a dungeon must be explored")
	# The next stage: a new fog, which knows nothing.
	rift.call("_begin_stage")
	await _settle()
	var second: FogOfWar = rift.fog()
	_check(second != null and second != first,
		"each dungeon stage must get a fresh fog - discovery does not carry down the stairs")
	if second != null and second != first:
		var far := Vector2(RaidLayout.HALF_EXTENT * 0.8, RaidLayout.HALF_EXTENT * 0.8)
		_check(not second.explored_at(far),
			"a fresh dungeon stage must start unexplored")
	rift.call("_finish", {"closed": false, "left": true})
	await _settle()


func _settle() -> void:
	for _frame: int in 24:
		await get_tree().process_frame


## Every post on the field, put out. The tests of the hero's own sight need
## the road dark, because a lit torch is sight now.
func _snuff_every_torch() -> void:
	for node: Node in get_tree().get_nodes_in_group(Torch.GROUP):
		var torch := node as Torch
		if torch != null and is_instance_valid(torch):
			torch.extinguish()


## A lit torch shows the road around it; a dead one shows nothing.
##
## Owner brief, 2026-09-14: torches should give sight through the fog while
## lit. Which makes relighting them worth something a player can see, and it
## is the one vision source on the field the enemy can take away - so both
## halves are held: the ground under a burning post is seen with nobody near
## it, and the moment the post is put out that ground goes dark again.
func _test_a_lit_torch_shows_its_road() -> void:
	var fog: FogOfWar = _fog()
	var hero: Hero = _run.battlefield.hero
	if fog == null or hero == null:
		_check(false, "the run must have a hero and a fog")
		return
	var chosen: Torch = null
	var farthest: float = 0.0
	for node: Node in get_tree().get_nodes_in_group(Torch.GROUP):
		var torch := node as Torch
		if torch == null or not is_instance_valid(torch):
			continue
		# The one furthest from the town, so the town's own sight cannot be
		# what is lighting the ground under it.
		var away: float = torch.global_position.length()
		if away > farthest:
			farthest = away
			chosen = torch
	_check(chosen != null, "the field must stand torches up")
	if chosen == null:
		return
	_check(farthest > Balance.FOG_VISION_TOWN + Balance.FOG_VISION_TORCH,
		"the furthest torch stands %.0f out, inside the town's own sight, so this "
			% farthest + "test could not tell the two apart")
	# The hero well away, and the post burning.
	hero.global_position = -chosen.global_position.normalized() \
		* (Balance.FOG_VISION_TOWN + Balance.FOG_VISION_HERO * 1.5)
	chosen.relight()
	await _settle()
	_check(fog.sees(chosen.global_position),
		"the ground under a lit torch must be seen with nobody near it")
	chosen.extinguish()
	await _settle()
	_check(not fog.sees(chosen.global_position),
		"the ground under a torch that has gone out must go dark")
	chosen.relight()
