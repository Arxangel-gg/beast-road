extends Node

var _failures: PackedStringArray = []


func _ready() -> void:
	# **Held for the whole run.** This gate edits MetaState in place - a wiped
	# stash, a drained Tools purse, a reset flag - and any save reached while
	# that scratch state is live overwrites a real player's file. One did, on
	# 2026-08-31, and a stash is the one thing here that cannot be restored.
	MetaState.hold_saves()
	RunState.reset()
	# 24 authored nodes, plus one summon per discipline from 2026-08-25 and a
	# second from 2026-09-01: 30.
	#
	# **A tripwire against loss, not a ceiling.** The count is asserted rather
	# than derived on purpose - a node that vanishes from the data is a hero
	# power silently disappearing, and nothing else in the project would notice.
	# Raising it when nodes are deliberately added is the intended maintenance;
	# what must never happen is it being *lowered* to match a roster that got
	# smaller by accident.
	_check(ContentDB.discipline_nodes.size() == 30,
		"expected 30 authored discipline nodes, got %d" % ContentDB.discipline_nodes.size())
	_check(RunState.trained_discipline_nodes.size() == 2,
		"a run must begin with the curated Attack and Defense pair")
	_check(RunState.discipline_node_in_slot(0) != null \
			and RunState.discipline_node_in_slot(1) != null,
		"starter Attack and Defense must occupy their role slots")
	_check(RunState.discipline_node_in_slot(2) == null \
			and RunState.discipline_node_in_slot(3) == null,
		"Power and Ultimate must begin empty")

	RunState.building_tiers["sanctum"] = 3
	RunState.refresh_discipline_offers()
	_check(RunState.discipline_offers.size() == 3,
		"a built Mansion must offer exactly three unique nodes")
	var seen: Dictionary = {}
	for id: String in RunState.discipline_offers:
		seen[id] = true
	_check(seen.size() == RunState.discipline_offers.size(),
		"Mansion offers must not contain duplicates")

	_test_every_effect_is_accounted_for()
	_test_every_node_can_be_offered()

	var power: DisciplineNodeData = ContentDB.discipline_node("marrow_drain")
	RunState.trained_discipline_nodes.append(power.id)
	_check(not RunState.try_equip_discipline(power.id).is_empty(),
		"Power must remain locked during Act I")
	RunState.act = 2
	_check(RunState.try_equip_discipline(power.id).is_empty() \
			and RunState.discipline_node_in_slot(2) == power,
		"Power must equip after the Act I gate")

	RunState.gain_currency(RunState.FOOD, 999)
	var first_cost: int = RunState.discipline_respec_cost()
	_check(RunState.try_respec_disciplines().is_empty(),
		"Preparation respec must succeed when Food is available")
	_check(RunState.discipline_respec_cost() > first_cost,
		"respec Food cost must rise per use")
	_check(RunState.trained_discipline_nodes.size() == 2,
		"respec must return to the curated starter pair")

	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		_check(ResourceLoader.exists(node.get_sprite_path()),
			"missing discipline icon: %s" % node.get_sprite_path())

	await _test_mercy_under_fire()

	if _failures.is_empty():
		print("[discipline] PASS — %d nodes, role gates, offers, respec and icons"
			% ContentDB.discipline_nodes.size())
	else:
		for failure: String in _failures:
			push_error("[discipline] " + failure)
	# The Mercy Under Fire test hurts a hero, and a hero being hurt plays a
	# sound. A voice still playing at exit leaks its Ogg stream, and a *warning*
	# fails this gate on the runner exactly as an assertion does - which is why
	# every gate that touches the battlefield ends this way.
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if not _failures.is_empty() else 0)


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
	RunState.trained_discipline_nodes.append(node.id)

	var field := EnemyField.new()
	add_child(field)
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	field.add_child(hero)
	await get_tree().process_frame
	hero.global_position = Vector2.ZERO

	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED 				and one.knockback_resistance < 0.5:
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


func _check(condition: bool, failure: String) -> void:
	if not condition:
		_failures.append(failure)


## Every authored node has to be reachable through the offer rotation.
##
## The tree is a *choice*: 27 nodes and a maxed hero trains eleven, drawn three
## at a time from a deterministic per-road shuffle. That is a good shape, and it
## has one silent failure - a node that the rotation never surfaces is content
## nobody can take, and it looks exactly like a node nobody happened to pick.
## Nothing else in the project would notice: the count assertion above sees it in
## the data, the icon assertion below sees its art, and the offer assertion sees
## three ids without caring which.
##
## Swept over roads rather than reasoned about, because the ordering is a hash
## and hashes do not answer arguments.
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


func _test_every_node_can_be_offered() -> void:
	var before_seed: int = RunState.run_seed
	var before_segment: int = RunState.segment
	var before_wave: int = RunState.wave_number
	var before_act: int = RunState.act
	var before_trained: Array[String] = RunState.trained_discipline_nodes.duplicate()

	# The Mansion at its ceiling, so tier is not what is excluding anything -
	# that is the assertion below, and mixing the two would hide it.
	RunState.building_tiers["sanctum"] = 3
	RunState.trained_discipline_nodes = []

	# **Walked, not sampled from a standing start.**
	#
	# This used to clear the trained list once and read the offers, which was the
	# right test while the trees were flat: every node was available to everybody
	# from the first road. Since 2026-09-09 a node also wants depth in its own
	# discipline, so a tier-3 Blood node is *supposed* to be unreachable to a
	# player who has trained nothing - asserting otherwise would assert the tree
	# away.
	#
	# So each seed now plays a run instead: take an offer, which deepens that
	# discipline, and see what the next road opens. A node counts as reachable if
	# some path of choices reaches it. Every discipline is walked as the
	# preferred one in turn, because a Blood specialist must not be what proves
	# the Holy ultimate reachable.
	var offered: Dictionary = {}
	for seed_index: int in 40:
		for favour: int in 3:
			RunState.run_seed = 1000 + seed_index * 7919
			RunState.trained_discipline_nodes = []
			for segment: int in 12:
				RunState.segment = segment
				RunState.wave_number = segment * 3
				RunState.act = 1 + (segment % 3)
				RunState.refresh_discipline_offers()
				var take: String = ""
				for id: String in RunState.discipline_offers:
					offered[id] = true
					var node: DisciplineNodeData = ContentDB.discipline_node(id)
					# Prefer the favoured discipline, so depth actually accrues
					# somewhere rather than spreading one node per tree.
					if node != null and node.discipline == favour:
						take = id
					elif take.is_empty():
						take = id
				if not take.is_empty():
					RunState.trained_discipline_nodes.append(take)

	var missing: PackedStringArray = []
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if not offered.has(node.id):
			missing.append(node.id)
	_check(missing.is_empty(),
		"never offered across 480 roads, so nobody can train them: %s"
			% ", ".join(missing))
	print("[discipline] %d of %d nodes reachable through the rotation"
		% [offered.size(), ContentDB.discipline_nodes.size()])

	# A tree the player can finish is a checklist, not a build.
	RunState.hero_level = Balance.HERO_MAX_LEVEL
	_check(RunState.discipline_cap() < ContentDB.discipline_nodes.size(),
		"a maxed hero may train %d of %d nodes - at parity the tree stops being a choice"
			% [RunState.discipline_cap(), ContentDB.discipline_nodes.size()])

	RunState.run_seed = before_seed
	RunState.segment = before_segment
	RunState.wave_number = before_wave
	RunState.act = before_act
	RunState.trained_discipline_nodes = before_trained
	RunState.refresh_discipline_offers()
