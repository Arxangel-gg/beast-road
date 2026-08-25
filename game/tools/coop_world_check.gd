extends Node

## Mirrored enemies and host-validated building.
##
##   godot --headless --path game res://tools/coop_world_check.tscn
##
## Step 4 of `docs/COOP_DESIGN.md`, the half that needs a real battlefield.
## `coop_check.tscn` covers the wire; this covers what the messages *mean*.
##
## **What this deliberately does not attempt.** The build order asks for "a wave
## runs identically on both sides", and a harness in one process cannot honestly
## claim that: there is one `RunState` autoload per process, so a simulated guest
## shares the host's run state and the two cannot meaningfully disagree. Pretending
## otherwise would be a green check that proves nothing.
##
## What it can prove is every piece that identity rests on: that a puppet decides
## nothing, that it takes its position and health from what it is told, that it
## leaves without paying out, and that a guest's build request is answered by the
## same function a local click goes through rather than by a copy of its rules.
## Two machines agreeing is then a property of those pieces plus the wire, and the
## wire is gated next door. The rest is a two-machine play test, which is on the
## road list and cannot be automated here.

const SEED: int = 223606797

var _failures: int = 0
var _run: Node = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield

	_test_the_systems_exist_and_are_inert_alone()
	await _test_a_puppet_decides_nothing()
	await _test_a_puppet_takes_what_it_is_told()
	await _test_a_puppet_leaves_without_paying()
	await _test_towers_rebuild_from_run_state()
	await _test_building_is_refused_for_the_right_reason()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop-world] PASS - puppets decide nothing, towers rebuild, builds are host-judged")
	get_tree().quit(_failures)


## A single-player run carries the machinery and pays almost nothing for it.
func _test_the_systems_exist_and_are_inert_alone() -> void:
	_check(_field != null, "the harness needs a battlefield")
	if _field == null:
		return
	_check(_field.get_node_or_null("CoopWorld") != null,
		"the battlefield must build its CoopWorld system")
	_check(not Coop.is_networked(), "this harness plays alone")
	var enemy: Enemy = _spawn()
	await_nothing()
	_check(enemy != null and enemy.net_id == 0,
		"nothing should be handed a network identity when nobody is listening")
	if enemy != null:
		enemy.queue_free()


## The whole of what "puppet" means: it does not walk, and it cannot be hurt.
func _test_a_puppet_decides_nothing() -> void:
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var enemy: Enemy = _spawn()
	if enemy == null:
		_check(false, "the harness needs an enemy")
		return
	enemy.puppet = true
	await get_tree().process_frame
	var from: Vector2 = enemy.global_position
	for _f: int in 20:
		await get_tree().process_frame
	_check(enemy.global_position.distance_to(from) < 0.5,
		"a puppet must not walk itself, moved %.2f"
			% enemy.global_position.distance_to(from))

	var hp_before: float = enemy.health.current_hp
	_check(not enemy.take_damage(999.0, Vector2.ZERO, 0.0),
		"a puppet must refuse damage: the host decides what hurt it")
	_check(is_equal_approx(enemy.health.current_hp, hp_before),
		"and must not lose health locally")
	enemy.queue_free()
	await get_tree().process_frame


## Position and health arrive as facts, and both land.
func _test_a_puppet_takes_what_it_is_told() -> void:
	var enemy: Enemy = _spawn()
	if enemy == null:
		return
	enemy.puppet = true
	await get_tree().process_frame

	var told: Vector2 = Vector2(-420.0, 260.0)
	enemy.mirror(told, 0.25)
	_check(enemy.global_position == told, "a puppet must go where it is told")
	_check(is_equal_approx(enemy.health_ratio(), 0.25),
		"and show the health it is told, got %.2f" % enemy.health_ratio())

	# Facing is derived from the movement the mirrored positions imply, rather
	# than sent. Two packets apart on the x axis must turn it.
	enemy.mirror(told + Vector2(-400.0, 0.0), 0.25)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(enemy.sprite.flip_h,
		"a puppet walking left must face left, from motion the host never sent")
	enemy.queue_free()
	await get_tree().process_frame


## A mirrored enemy leaving must not pay the guest a second time.
func _test_a_puppet_leaves_without_paying() -> void:
	var enemy: Enemy = _spawn()
	if enemy == null:
		return
	enemy.puppet = true
	await get_tree().process_frame
	var gold_before: int = RunState.currency(RunState.GOLD)
	var kills_before: int = RunState.enemies_killed

	enemy.dismiss()
	await get_tree().process_frame
	_check(enemy.is_dying(), "a retired puppet must leave the field")
	_check(RunState.currency(RunState.GOLD) == gold_before,
		"and pay nothing: the host already paid, and a shared purse would double")
	_check(RunState.enemies_killed == kills_before,
		"and count as nobody's kill")


## The reason towers cost almost no network code.
##
## `battlefield.gd` rebuilds every tower node from `RunState` whenever
## `tower_changed` fires, so a guest told "a level 2 Ember Spire stands at (3,4)"
## writes that and the tower appears. This asserts the property that makes the
## mirror free — if it ever stops being true, towers need real replication and
## `CoopWorld` needs rewriting rather than patching.
func _test_towers_rebuild_from_run_state() -> void:
	var anchor: Vector2i = _free_anchor()
	RunState.set_tower(anchor, "ember_spire", 2)
	await get_tree().process_frame
	var built: Tower = _field.tower_at_anchor(anchor)
	_check(built != null, "writing a tower into RunState must raise the node")
	if built != null:
		_check(built.data != null and built.data.id == "ember_spire",
			"of the kind it was told")

	RunState.clear_tower(anchor)
	await get_tree().process_frame
	_check(_field.tower_at_anchor(anchor) == null,
		"and clearing it must take the node away again")


## A guest's build request is judged by the host's own rules.
##
## `try_build` is the same function a local click goes through — not a copy of
## its rules. A second implementation of "may this be built here" would be a
## second answer, and the two would diverge the first time either changed. The
## refusal it returns is already a sentence written for a player, which is why it
## travels back unedited.
func _test_building_is_refused_for_the_right_reason() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var spire: TowerData = ContentDB.tower("ember_spire")
	var anchor: Vector2i = _free_anchor()

	# The run starts with no Gold since 2026-08-24, so this needs no arranging.
	_check(RunState.currency(RunState.GOLD) == 0, "the harness expects an empty purse")
	var refusal: String = _field.try_build(anchor, spire)
	_check(not refusal.is_empty(), "an unaffordable tower must be refused")
	_check(refusal.contains("Needs"),
		"and refused for the reason that is true - the cost - got: %s" % refusal)
	_check(_field.tower_at_anchor(anchor) == null,
		"and nothing may be built by a refused request")

	RunState.gain_every_currency(9999)
	_check(_field.try_build(anchor, spire).is_empty(),
		"a funded request must be granted")
	await get_tree().process_frame
	_check(_field.tower_at_anchor(anchor) != null, "and raise the tower")

	# The phase rule is the host's too. A guest asking mid-combat is refused for
	# a different and equally real reason.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var later: String = _field.try_build(_free_anchor(), spire)
	_check(not later.is_empty() and later.contains("Preparation"),
		"building outside Preparation must be refused as a phase problem, got: %s" % later)


func _spawn() -> Enemy:
	return _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0)


func _free_anchor() -> Vector2i:
	return _field.free_anchor_near(0)


## Readability helper: this test needs no frame, and says so.
func await_nothing() -> void:
	pass


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[coop-world] %s" % why)
