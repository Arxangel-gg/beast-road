extends Node

## The summon spells: Wolf, Crow and Bear.
##
##   godot --headless --path game res://tools/companion_check.tscn
##
## What this really defends is the line between a *spell* and a *party member*.
## GDD §54 cuts "multiple heroes, party roster" for 1.0, and a permanent second
## body on the field is near enough that line to be the same thing wearing a
## different word. A summon stays inside the cut because it **expires** and
## because there is only ever **one**.
##
## Both of those are properties that would rot silently. A duration that stopped
## being applied, or a second cast that stacked instead of replacing, would not
## error, would not look wrong in a screenshot, and would quietly turn a spell
## into the system §54 says not to build.

const SEED: int = 314159265

var _failures: int = 0
var _run: Node = null


func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame

	_test_the_data_is_whole()
	await _test_a_summon_arrives_and_fights()
	await _test_only_one_at_a_time()
	await _test_it_expires()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[companion] PASS - every summon named in the data, one at a time, and all of them leave")
	get_tree().quit(_failures)


## Every summon spell names a companion that exists.
##
## **Derived from the data, not from a list written here.** This used to iterate
## `["call_wolf", "call_crow", "call_bear"]`, so it checked exactly the three
## summons that existed when it was written and silently ignored every one added
## afterwards - three new companions shipped past it with no sprite check, no
## duration check and no complaint. A gate that only examines what somebody
## remembered to name is a gate that gets weaker every time the game grows.
func _test_the_data_is_whole() -> void:
	var found: int = 0
	var ids: Array = ContentDB.spells.keys()
	ids.sort()
	for key: Variant in ids:
		var id: String = String(key)
		var spell: SpellData = ContentDB.spells.get(id, null) as SpellData
		if spell == null or spell.kind != SpellData.Kind.COMPANION:
			continue
		found += 1
		var data: CompanionData = ContentDB.companion(spell.companion_id)
		_check(data != null, "%s names companion '%s', which does not exist"
			% [id, spell.companion_id])
		if data == null:
			continue
		_check(ResourceLoader.exists(data.get_sprite_path()),
			"%s has no sprite at %s" % [data.id, data.get_sprite_path()])
		# The bound that keeps a summon a spell.
		_check(data.duration > 0.0,
			"%s must expire: a companion that does not is a party member" % data.id)
	# A tripwire against loss, like the discipline node count: raise it when
	# summons are deliberately added, never lower it to match a roster that
	# shrank by accident.
	_check(found == 6, "expected 6 companion summons, found %d" % found)


## It turns up, and it hurts something.
func _test_a_summon_arrives_and_fights() -> void:
	var field: Battlefield = _run.get("battlefield") as Battlefield
	if field == null or field.hero == null:
		_check(false, "the harness needs a hero on a battlefield")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var enemy: Enemy = _spawn_enemy(field)
	if enemy == null:
		return
	enemy.global_position = field.hero.global_position + Vector2(90.0, 0.0)
	var before: float = enemy.health.current_hp

	_summon(field, "call_wolf")
	await get_tree().process_frame
	_check(_living() == 1, "casting a summon must put one on the field")

	for _f: int in 90:
		await get_tree().process_frame
	# The Wolf may simply have killed it, which is the strongest possible pass
	# and also frees the node - reading its health afterwards is how the first
	# version of this check reported an error on its own success.
	if not is_instance_valid(enemy):
		return
	_check(enemy.health.current_hp < before,
		"a summoned companion must actually fight, %.0f -> %.0f"
			% [before, enemy.health.current_hp])
	enemy.queue_free()
	await get_tree().process_frame


## A second cast replaces the first rather than stacking.
func _test_only_one_at_a_time() -> void:
	var field: Battlefield = _run.get("battlefield") as Battlefield
	if field == null:
		return
	_summon(field, "call_bear")
	_summon(field, "call_crow")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_living() == 1,
		"two summons must not stack: %d on the field, and two is a party" % _living())


## And it goes away on its own.
func _test_it_expires() -> void:
	var field: Battlefield = _run.get("battlefield") as Battlefield
	if field == null:
		return
	var crow: CompanionData = ContentDB.companion("crow")
	if crow == null:
		return
	# Driven rather than waited out: a Crow lasts sixteen seconds and a gate must
	# not. Ticked directly, which is the same thing the run would do to it.
	for node: Node in get_tree().get_nodes_in_group(Companion.GROUP):
		var companion := node as Companion
		if companion != null:
			for _step: int in int(crow.duration / 0.1) + 4:
				if not is_instance_valid(companion):
					break
				companion._physics_process(0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_living() == 0,
		"a summon must leave when its time is up, %d still standing" % _living())


func _summon(field: Battlefield, spell_id: String) -> void:
	var spell: SpellData = ContentDB.spells.get(spell_id, null) as SpellData
	if spell == null or field.hero == null:
		return
	field.hero.spells._resolve(spell, Vector2.RIGHT, field.hero.global_position)


func _living() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(Companion.GROUP):
		if is_instance_valid(node) and not node.is_queued_for_deletion():
			count += 1
	return count


func _spawn_enemy(field: Battlefield) -> Enemy:
	var enemy: Enemy = field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0)
	if enemy == null:
		_check(false, "the harness needs an enemy")
	return enemy


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[companion] %s" % why)
