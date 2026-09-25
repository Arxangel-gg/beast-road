extends Node

## Champions and elites (owner decision, 2026-08-31).
##
## Five promises, each of which fails quietly:
##
## 1. **Promotion multiplies the numbers**, and it has to happen before `setup`
##    fills the health node - afterwards leaves a champion with a common's hit
##    points and nothing reports it.
## 2. **Affixes combine by multiplying**, which is what makes a pair free. If
##    they ever stop stacking, every combination silently becomes one affix.
## 3. **Resistance takes the best, not the product**, or two sources approach
##    immunity and the enemy stops being an affix and becomes a wall.
## 4. **A promoted body is visibly promoted.** A promotion nobody can see is a
##    promotion that does not exist.
## 5. **No body wears the same affix twice**, which reads as a bug because it is.

var _failures: int = 0


func _ready() -> void:
	RunState.reset()
	RunState.act = 3
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED:
			breed = one
			break
	_check(breed != null, "a breed is needed")
	_check(ContentDB.affixes.size() >= 4, "there must be affixes to wear")
	_test_every_act_has_marks_of_its_own()
	_test_every_mark_field_is_read()
	if breed == null or ContentDB.affixes.is_empty():
		_finish()
		return

	var field := EnemyField.new()
	add_child(field)

	# 1. The rank reaches the health node.
	var common: Enemy = _make(field, breed, Enemy.Rank.COMMON, [])
	var champion: Enemy = _make(field, breed, Enemy.Rank.CHAMPION,
		[ContentDB.affixes["ironhide"] as EnemyAffixData])
	_check(champion.health.max_hp > common.health.max_hp * 2.0,
		"a champion must be substantially tougher, %.0f against %.0f"
			% [champion.health.max_hp, common.health.max_hp])

	# 2. Two affixes multiply rather than replace.
	var one_affix: Enemy = _make(field, breed, Enemy.Rank.ELITE,
		[ContentDB.affixes["ironhide"] as EnemyAffixData])
	var two_affix: Enemy = _make(field, breed, Enemy.Rank.ELITE,
		[ContentDB.affixes["ironhide"] as EnemyAffixData,
			ContentDB.affixes["dreadful"] as EnemyAffixData])
	_check(two_affix.health.max_hp > one_affix.health.max_hp * 1.5,
		"affixes must stack: two gave %.0f against one at %.0f"
			% [two_affix.health.max_hp, one_affix.health.max_hp])

	# 3. Resistance is the best of them, never the product.
	var resist: float = two_affix.call("_affix_best", &"damage_resistance")
	_check(resist < 0.7, "resistance must stay short of immunity, got %.2f" % resist)
	_check(is_equal_approx(resist,
		maxf((ContentDB.affixes["ironhide"] as EnemyAffixData).damage_resistance,
			(ContentDB.affixes["dreadful"] as EnemyAffixData).damage_resistance)),
		"and must be the largest single source rather than their sum")

	# 4. It looks promoted: bigger, ringed, and named for what it wears.
	_check(champion.sprite.scale.x > common.sprite.scale.x,
		"a promoted body must be visibly larger")
	var ringed: bool = false
	for child: Node in champion.get_children():
		var line := child as Line2D
		if line != null and line.points.size() > 8:
			ringed = true
	_check(ringed, "and must stand in a ring")
	_check(champion.promoted_name().contains("Ironhide")
		and champion.promoted_name().contains(breed.display_name),
		"and must be named for what it wears, got '%s'" % champion.promoted_name())
	_check(common.promoted_name() == breed.display_name,
		"while a common one keeps its plain name")

	# 5. Never the same affix twice.
	var director := WaveDirector.new()
	add_child(director)
	for attempt: int in 40:
		var worn: Array = director.call("_roll_affixes", 3)
		var seen: Dictionary = {}
		for affix: EnemyAffixData in worn:
			_check(not seen.has(affix.id),
				"a body must not wear %s twice" % affix.id)
			seen[affix.id] = true

	print("[elite] %d affixes, champion %.0f hp against common %.0f, elite pair %.0f"
		% [ContentDB.affixes.size(), champion.health.max_hp, common.health.max_hp,
			two_affix.health.max_hp])

	for node: Node in [common, champion, one_affix, two_affix, director, field]:
		node.queue_free()
	for _frame: int in 8:
		await get_tree().process_frame
	_finish()


func _make(field: EnemyField, breed: EnemyData, rank: Enemy.Rank,
		worn: Array[EnemyAffixData]) -> Enemy:
	var scene: PackedScene = load("res://scenes/battlefield/enemy.tscn")
	var foe := scene.instantiate() as Enemy
	if rank != Enemy.Rank.COMMON:
		foe.promote(rank, worn)
	foe.setup(breed, 0, field, 1.0)
	field.add_child(foe)
	return foe


func _finish() -> void:
	if _failures == 0:
		print("[elite] PASS - promotion reaches the numbers, affixes stack, "
			+ "resistance stays short of immunity, and it shows")
	else:
		printerr("[elite] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Every act meets marks of its own, and every field a mark can carry is read
## by something.**
##
## Both halves are faults this project has already shipped. `from_act` was capped
## at 3 on a ten-act road, so acts IV to X wore exactly the pool Act I did - the
## fifth hardcoded three-act range found here, after the relic counter, the
## Chronicle's `minimum_act`, the campaign tiers' boss table and
## `wildlife_spawn_check`. And a field authored on a resource and read by nothing
## is the `DisciplineEffects` lie in a second place: the mark draws, the codex
## describes it, and it does nothing at all.
func _test_every_act_has_marks_of_its_own() -> void:
	var pool_at: Dictionary = {}
	for act: int in range(1, Balance.ACT_COUNT + 1):
		var count: int = 0
		for value: Variant in ContentDB.affixes.values():
			var affix := value as EnemyAffixData
			if affix != null and affix.from_act <= act:
				count += 1
		pool_at[act] = count
		_check(count >= 4,
			"act %d has %d marks to draw from, which is not a promotion system"
				% [act, count])
	# **And the pool grows.** A campaign where the last act draws from exactly
	# what the first did is a campaign whose promotions stopped meaning anything
	# two thirds of the way along - which is what the three-act cap did.
	_check(int(pool_at[Balance.ACT_COUNT]) > int(pool_at[1]),
		("act %d draws from the same %d marks as act 1, so the back of the "
			+ "campaign wears nothing it has not already seen")
			% [Balance.ACT_COUNT, int(pool_at[1])])
	var newest: int = 0
	for value: Variant in ContentDB.affixes.values():
		var affix := value as EnemyAffixData
		if affix != null:
			newest = maxi(newest, affix.from_act)
	_check(newest >= Balance.ACT_COUNT - 2,
		("the latest mark in the game arrives in act %d of %d - the last acts "
			+ "have nothing of their own") % [newest, Balance.ACT_COUNT])


## Every field a mark may carry has to be read by some script other than the
## resource that declares it. A grep is a weak proof of behaviour and a strong
## proof of *wiring*, which is the half that goes silently false.
func _test_every_mark_field_is_read() -> void:
	var declared: PackedStringArray = []
	var script := load("res://scripts/resources/enemy_affix_data.gd") as Script
	for entry: Dictionary in script.get_script_property_list():
		var name: String = String(entry.get("name", ""))
		if name.is_empty() or name.begins_with("_") or name == "id" \
				or name == "display_name" or name == "description" \
				or name == "mark_colour" or name == "from_act" \
				or name.ends_with(".gd"):
			continue
		if int(entry.get("usage", 0)) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		declared.append(name)
	_check(declared.size() >= 10,
		"only %d mark fields found, so this check is reading the wrong thing"
			% declared.size())
	var readers: PackedStringArray = [
		"res://scenes/battlefield/enemy.gd",
		"res://scenes/battlefield/companion.gd",
		"res://scripts/systems/wave_director.gd",
		"res://scripts/systems/camps.gd",
		"res://scripts/systems/enemy_marks.gd",
	]
	var body: String = ""
	for path: String in readers:
		if not FileAccess.file_exists(path):
			continue
		body += FileAccess.get_file_as_string(path)
	# **A read of the mark, not of the word** (2026-09-25). This checked
	# `body.contains(name)`, and the enemy script contains "speed_scale" three
	# times over - its own `_speed_scale`, its `speed_scale()` and a parameter -
	# so the mark's `speed_scale`, authored on twelve marks and shown in the
	# codex, passed while nothing applied it. A mark's field is read as
	# `affix.<name>` or handed by name to the product and best helpers.
	for name: String in declared:
		var read: bool = body.contains("affix." + name) or body.contains("&\"%s\"" % name)
		_check(read,
			("a mark may carry '%s' and nothing outside the resource reads it - "
				+ "the mark draws, the codex describes it, and it does nothing")
					% name)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[elite] FAIL: %s" % why)
