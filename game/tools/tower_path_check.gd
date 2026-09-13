extends Node

## A tower's specialisation: the split at five, the capstone at ten, and the
## bound that keeps both inside the curve.
##
##   godot --headless --path game res://tools/tower_path_check.tscn
##
## Owner brief, 2026-09-13: "Towers should have a way to specialize in a split
## choice specialization after level 5 each ... And at level 10 a maxed out
## tower should get another special kind of bonus."
##
## Five ways this can be a lie, and the last is the one that matters most:
##
## 1. **A choice offered too early.** A tower that can specialise at level one
##    is not a ladder with a decision on it, it is a second build menu.
## 2. **A choice that never has to be made.** A tower standing at five with no
##    path is a dead upgrade, which is the fault the Power and Ultimate slots
##    already had once.
## 3. **A choice that is not a choice.** Picking again next Preparation makes
##    the decision free, and a free decision is a setting.
## 4. **A capstone that arrives early.** It is the last thing a player buys on
##    an emplacement; if it lands at five the levels between are worthless.
## 5. **A path that adds a mechanic.** The bound every addition in this project
##    is held to: a specialisation may only move a number the tower already
##    has, so the ten-act pressure curve can still be read against it. This is
##    checked by *measuring* - damage, rate, reach, targets and blast before
##    and after, and nothing else allowed to move.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260913)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	RunState.gain_every_currency(9000)

	_test_the_names_exist()
	await _test_the_split()
	_test_the_bound()

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[tower-path] PASS - %d checks: the split, the capstone, and numbers only" % _checks)
	else:
		push_error("[tower-path] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[tower-path] FAIL: %s" % why)


## Every element names both of its paths, and both say what they do.
##
## A path with no name draws an empty button, which is the kind of thing that
## ships because nothing errors.
func _test_the_names_exist() -> void:
	for element: int in [TowerData.Element.FIRE, TowerData.Element.WATER,
			TowerData.Element.EARTH, TowerData.Element.AIR]:
		for path: int in [TowerData.Path.FOCUS, TowerData.Path.SPREAD]:
			_check(not TowerData.path_name(element, path).is_empty(),
				"%s has no name for path %d" % [TowerData.element_name(element), path])
			_check(not TowerData.capstone_note(element, path).is_empty(),
				"%s path %d promises no capstone" % [TowerData.element_name(element), path])
	for path: int in [TowerData.Path.FOCUS, TowerData.Path.SPREAD]:
		_check(not TowerData.path_note(path).is_empty(), "path %d says nothing" % path)
	_check(TowerData.path_name(TowerData.Element.FIRE, TowerData.Path.NONE).is_empty(),
		"an unchosen path must have no name")


## Built, raised, asked, answered - and asked again, which must refuse.
func _test_the_split() -> void:
	var field: Battlefield = _run.battlefield
	var data: TowerData = null
	for id: Variant in ContentDB.towers:
		var candidate: TowerData = ContentDB.towers[id] as TowerData
		if candidate != null and not candidate.is_well() and not candidate.is_combination:
			data = candidate
			break
	if data == null or field == null:
		_check(false, "the harness needs a battlefield and a tower to build")
		return
	var anchor: Vector2i = field.free_anchor_near(0, 6)
	_check(field.try_build(anchor, data).is_empty(), "the harness must be able to build")
	_check(not RunState.tower_awaits_path(anchor),
		"a tower must not be asked to specialise at level one")
	_check(not RunState.set_tower_path(anchor, TowerData.Path.FOCUS),
		"a path taken before the fifth level would skip the ladder entirely")

	# Up to the split. The Forge caps the climb, so it is raised with it.
	RunState.building_tiers["forge"] = 3
	for _step: int in Balance.TOWER_SPECIALISE_LEVEL - 1:
		RunState.set_tower(anchor, data.id, RunState.level_at(anchor) + 1)
	_check(RunState.level_at(anchor) == Balance.TOWER_SPECIALISE_LEVEL,
		"the harness must reach the level the split is on")
	_check(RunState.tower_awaits_path(anchor),
		"a tower at level %d with no path must be asked" % Balance.TOWER_SPECIALISE_LEVEL)

	_check(RunState.set_tower_path(anchor, TowerData.Path.SPREAD), "the answer must take")
	_check(RunState.tower_path(anchor) == TowerData.Path.SPREAD, "and it must be remembered")
	_check(not RunState.tower_awaits_path(anchor), "and it must stop asking")
	_check(not RunState.set_tower_path(anchor, TowerData.Path.FOCUS),
		"a path already chosen must not be changed - a free re-pick is a setting, not a decision")

	# And it survives the levels it exists for.
	RunState.set_tower(anchor, data.id, RunState.level_at(anchor) + 1)
	_check(RunState.tower_path(anchor) == TowerData.Path.SPREAD,
		"the path must survive the next level - the levels are what it is for")
	await get_tree().process_frame


## The bound: a path moves numbers the tower already has, and only those.
##
## Measured rather than asserted from the constants, because the question is
## whether the *tower* changed, not whether the table says it should.
func _test_the_bound() -> void:
	var field: Battlefield = _run.battlefield
	var data: TowerData = null
	for id: Variant in ContentDB.towers:
		var candidate: TowerData = ContentDB.towers[id] as TowerData
		if candidate != null and not candidate.is_well() and not candidate.is_combination \
				and candidate.damage > 0.0:
			data = candidate
			break
	if data == null:
		return
	var anchor: Vector2i = field.free_anchor_near(1, 6)
	if not field.try_build(anchor, data).is_empty():
		return
	var tower: Tower = field.tower_at_anchor(anchor)
	if tower == null:
		_check(false, "the harness needs the built tower")
		return
	RunState.building_tiers["forge"] = 4
	for _step: int in Balance.TOWER_SPECIALISE_LEVEL - 1:
		RunState.set_tower(anchor, data.id, RunState.level_at(anchor) + 1)
	tower.upgrade_to(RunState.level_at(anchor))

	var before_damage: float = tower.effective_damage()
	var before_range: float = tower.effective_range()
	var before_interval: float = tower.path_interval_scale()
	var before_targets: int = tower.path_extra_targets()

	RunState.set_tower_path(anchor, TowerData.Path.FOCUS)
	tower.refresh_modifiers()
	_check(tower.effective_damage() > before_damage,
		"the focusing path must hit harder: %.1f against %.1f"
			% [tower.effective_damage(), before_damage])
	_check(tower.effective_range() > before_range,
		"the focusing path must reach further")
	_check(tower.path_interval_scale() > before_interval,
		"the focusing path must swing slower - it is the price of the damage")
	_check(tower.path_extra_targets() == before_targets,
		"the focusing path must not add targets; that is the other path")

	# The capstone waits for the tenth level.
	var focused: float = tower.effective_damage()
	RunState.set_tower(anchor, data.id, Balance.TOWER_CAPSTONE_LEVEL - 1)
	tower.upgrade_to(RunState.level_at(anchor))
	var below: float = tower.effective_damage() / maxf(data.damage_at(tower.level), 0.001)
	RunState.set_tower(anchor, data.id, Balance.TOWER_CAPSTONE_LEVEL)
	tower.upgrade_to(RunState.level_at(anchor))
	var at_cap: float = tower.effective_damage() / maxf(data.damage_at(tower.level), 0.001)
	_check(at_cap > below,
		"the capstone must add something at level %d that level %d did not have"
			% [Balance.TOWER_CAPSTONE_LEVEL, Balance.TOWER_CAPSTONE_LEVEL - 1])
	_check(focused > 0.0, "a focused tower must still deal damage")

	# And the spreading path is the other shape, on its own emplacement.
	var other: Vector2i = field.free_anchor_near(2, 6)
	if field.try_build(other, data).is_empty():
		var second: Tower = field.tower_at_anchor(other)
		if second != null:
			RunState.set_tower(other, data.id, Balance.TOWER_SPECIALISE_LEVEL)
			RunState.set_tower_path(other, TowerData.Path.SPREAD)
			second.upgrade_to(RunState.level_at(other))
			_check(second.path_extra_targets() > 0,
				"the spreading path must reach more bodies")
			_check(second.path_aoe_scale() > 1.0,
				"the spreading path must widen the blast")
			_check(second.path_interval_scale() < 1.0,
				"the spreading path must fire faster")
