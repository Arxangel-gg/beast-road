extends Node

## Ranged combat, ammunition and blueprints (owner decision, 2026-08-31).
##
## Four promises, and every one of them fails silently if it breaks:
##
## 1. **A recipe you have not learned cannot be made.** That is the entire point
##    of blueprints; without it they are decoration on a crafting menu.
## 2. **Ammunition costs run currency and resets with the run.** It is a run
##    resource. A quiver that survived a run would make every later opening
##    trivial for anyone who stockpiled.
## 3. **The quiver is bounded by bulk**, which is the whole scarcity model - no
##    rarity tiers, no encumbrance, no second currency.
## 4. **Firing spends, and an empty quiver falls back rather than jamming.**

var _failures: int = 0

## A member, not a local. GDScript lambdas capture locals by *value*, so a
## counter incremented inside a signal handler writes to the closure's own copy
## and the outer one never moves - the same trap `room_check` documents, and it
## reported a bow that fires perfectly well as a bow that never fired.
var _shots: int = 0


class ArrowWildlife extends Wildlife:
	var bodies: Array[Node2D] = []
	var hits: Dictionary = {}
	func _ready() -> void:
		set_process(false)
	func projectile_bodies(_at: Vector2, _radius: float) -> Array[Dictionary]:
		var found: Array[Dictionary] = []
		for body: Node2D in bodies:
			found.append({"body": body, "at": body.global_position})
		return found
	func wound_sprite(body: Node2D, _damage: float) -> bool:
		hits[body.get_instance_id()] = int(hits.get(body.get_instance_id(), 0)) + 1
		return true


func _ready() -> void:
	RunState.reset()
	RunState.gain_every_currency(400)

	# --- 1. blueprints gate crafting -----------------------------------------
	var locked: String = "ember_arrow"
	MetaState.unlocked_blueprints.clear()
	_check(not MetaState.knows_recipe("ammo", locked),
		"an unlearned recipe must not be known")
	var refusal: String = RunState.craft_ammo(locked, 1)
	_check(not refusal.is_empty(),
		"crafting an unlearned recipe must refuse, said %s" % ["nothing" if refusal.is_empty() else refusal])
	_check(RunState.ammo_count(locked) == 0,
		"and must not have made any")

	_check(MetaState.learn_blueprint("plan_ember_arrow"), "learning must take")
	_check(not MetaState.learn_blueprint("plan_ember_arrow"),
		"learning the same plan twice must report nothing new")
	_check(MetaState.knows_recipe("ammo", locked),
		"the recipe must be known once its plan is learned")

	# --- 2. crafting costs, and yields a batch --------------------------------
	var kind := ContentDB.ammo_kinds[locked] as AmmoData
	var gold_before: int = RunState.currency(RunState.GOLD)
	var made: String = RunState.craft_ammo(locked, 1)
	_check(made.is_empty(), "crafting a known recipe must succeed, said %s" % made)
	_check(RunState.ammo_count(locked) == kind.craft_batch,
		"a batch is %d, got %d" % [kind.craft_batch, RunState.ammo_count(locked)])
	_check(RunState.currency(RunState.GOLD) < gold_before,
		"crafting must cost the currencies it names")

	# --- 3. the quiver is bounded --------------------------------------------
	var plain: String = "plain_arrow"
	_check(RunState.gain_ammo(plain, 9999) < 9999,
		"the quiver must refuse what will not fit")
	_check(RunState.ammo_bulk_used() <= Balance.AMMO_CAPACITY,
		"and must never exceed its capacity, used %d of %d"
			% [RunState.ammo_bulk_used(), Balance.AMMO_CAPACITY])

	# --- 4. firing spends, and empty falls back ------------------------------
	var bow := HeroRanged.new()
	add_child(bow)
	RunState.ranged_id = "shortbow"
	RunState.ammo_id = locked
	_check(bow.armed(), "a bow in hand must report armed")
	var held: int = RunState.ammo_count(locked)
	bow.loosed.connect(func(_f: Vector2, _d: Vector2, _a: AmmoData) -> void: _shots += 1)
	bow.request(Vector2.RIGHT, Vector2.ZERO)
	_check(_shots == 1, "requesting a shot must loose one")
	_check(RunState.ammo_count(locked) == held - 1,
		"and must spend exactly one arrow")

	# Empty the special type; the bow must move to what is left rather than jam.
	RunState.ammo[locked] = 1
	bow.tick(99.0)
	bow.request(Vector2.RIGHT, Vector2.ZERO)
	bow.tick(99.0)
	bow.request(Vector2.RIGHT, Vector2.ZERO)
	_check(RunState.ammo_id != locked or RunState.ammo_count(locked) > 0,
		"an emptied ammunition must not stay nocked")
	_check(_shots >= 2, "and the bow must keep firing what it still has")

	# --- 5. ammunition is a run resource, knowledge is not --------------------
	RunState.reset()
	_check(RunState.ammo.is_empty(), "a new run must start with an empty quiver")
	_check(RunState.ranged_id.is_empty(), "and melee-only")
	_check(MetaState.knows_recipe("ammo", locked),
		"but the recipe must survive the run")

	# --- 6. the player can actually reach it -----------------------------------
	#
	# **Shipped without this once.** The bow arrived only by learning its plan,
	# and only if the hero held none already - so a player who learned a second
	# plan could never switch to it, and a player who found no plan at all never
	# met the system. A weapon you cannot equip from a menu is not finished.
	MetaState.unlocked_blueprints.clear()
	var reachable: int = 0
	for value: Variant in ContentDB.ranged_weapons.values():
		var weapon := value as RangedWeaponData
		if weapon != null and weapon.starting_kit:
			reachable += 1
	_check(reachable == 1,
		"exactly one weapon must be reachable without a discovery, got %d" % reachable)

	# And switching must leave the quiver holding something the new weapon fires.
	RunState.ranged_id = "shortbow"
	RunState.ammo_id = "plain_arrow"
	var crossbow_ammo: Array[AmmoData] = RunState.ammo_for_weapon("heavy_crossbow")
	_check(not crossbow_ammo.is_empty(), "a crossbow must have ammunition it fits")
	for fits: AmmoData in crossbow_ammo:
		_check(fits.family == "bolt",
			"and must never be offered %s, which is an arrow" % fits.id)

	print("[ranged] capacity %d, batch %d, %d weapons, %d ammunitions, %d plans"
		% [Balance.AMMO_CAPACITY, kind.craft_batch, ContentDB.ranged_weapons.size(),
			ContentDB.ammo_kinds.size(), ContentDB.blueprints.size()])

	bow.queue_free()
	for _frame: int in 6:
		await get_tree().process_frame
	_test_arrows_reach_wildlife()
	_test_the_shot_goes_where_it_is_aimed()
	await _test_swept_flight()
	_test_a_bow_is_carried_by_its_archer()
	_test_melee_is_still_the_default()
	# **A script error aborts the function it happens in and nothing else.**
	# This gate printed PASS while a bad constant name silently killed the melee
	# comparison mid-way, which is the exact failure `crossroad_vote_check`
	# grew its own counter for. Two of these tests are new; both count
	# themselves, and the pair has already caught one of its own bugs.
	if _finished_tests != 2:
		_check(false, "only %d of 2 counted tests ran to completion" % _finished_tests)

	if _failures == 0:
		print("[ranged] PASS - blueprints gate the recipe, ammunition costs and "
			+ "resets, the quiver is bounded, and the bow never jams")
	else:
		printerr("[ranged] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[ranged] FAIL: %s" % why)


## An arrow has to be able to kill an animal, because a sword can.
##
## Wildlife is not the enemy field - it is its own system with its own bodies -
## so a shot only reaches it if something deliberately asks. Melee does, through
## the swing announcement; the arrow asked nobody, and passed straight through a
## wolf standing in the open while a sword killed it. Reported from play.
##
## Driven through `wound_near`, the same door the arrow uses, because the arrow
## itself needs a live battlefield and a flight to test end to end - and the
## thing that was missing was the call, not the flying.
func _test_arrows_reach_wildlife() -> void:
	# The live half of this - that `wound_near` actually kills - lives in
	# `regression_check`, which already stands up a real population and tears it
	# down cleanly. What is checked here is the half that was missing and that a
	# fixture cannot show: that the arrow asks at all.
	# Read, not instantiated: `Wildlife.new()` is a Node, and one created here
	# and never freed is a leaked object - an ERROR line that fails the pipeline
	# however green this gate's verdict is.
	_check(_source("res://scripts/systems/wildlife.gd").contains("func wound_near"),
		"wildlife must expose a way for a projectile to hit it")
	var arrow: String = _source("res://scenes/battlefield/hero_arrow.gd")
	_check(not arrow.is_empty(), "the arrow script must exist")
	_check(arrow.contains("projectile_bodies") and arrow.contains("wound_sprite"),
		"the arrow must ask wildlife for a hit, or shots pass through animals")


func _source(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var body: String = file.get_as_text()
	file.close()
	return body


## An arrow must pass through the cursor, not near it.
##
## Reported as "the ranged weapons do not shoot exactly where the mouse cursor
## was aiming", and it was geometry rather than accuracy: the aim direction was
## measured from the hero's *feet* and the arrow left from the hero's *chest*.
## Two parallel lines a little over fifty units apart, which is nothing when the
## target is far away and most of the screen when it is close.
##
## Checked as arithmetic and as a call site, and it needs both. The arithmetic
## says the rule is right; the call site is where the wrong point was passed in,
## and a correct rule fed the wrong origin is exactly the bug that shipped.
func _test_the_shot_goes_where_it_is_aimed() -> void:
	var feet := Vector2(400.0, 800.0)
	var lift := Vector2(0.0, -52.0)
	var body: Vector2 = feet + lift
	var cursor := Vector2(700.0, 790.0)

	var heading: Vector2 = HeroInput.aim_at(body, cursor, Vector2.RIGHT)
	# The shot leaves from `body` and flies along `heading`. Projecting the cursor
	# onto that ray must land on the cursor itself.
	var along: float = (cursor - body).dot(heading)
	var closest: Vector2 = body + heading * along
	_check(closest.distance_to(cursor) < 0.01,
		"a shot aimed from the body must pass through the cursor, missed by %.2f"
			% closest.distance_to(cursor))

	# And the bug it replaces, stated as a number so nobody reintroduces it by
	# reasoning that fifty units cannot matter.
	var from_feet: Vector2 = HeroInput.aim_at(feet, cursor, Vector2.RIGHT)
	var error: float = absf(rad_to_deg(from_feet.angle_to(heading)))
	_check(error > 5.0,
		"aiming from the feet must measurably miss, or this test proves nothing "
			+ "(%.1f degrees)" % error)

	# Zero-length is a real state - the cursor sits on the hero every time they
	# walk under it - and must hold the previous direction rather than snap east.
	_check(HeroInput.aim_at(body, body, Vector2.UP) == Vector2.UP,
		"a cursor on top of the hero must keep the previous aim")

	var source: String = _source("res://scripts/components/local_hero_input.gd")
	_check(source.contains("combat_origin"),
		"the local aim must be measured from combat_origin, or the rule above is "
			+ "correct and unused")
	var hero_source: String = _source("res://scenes/hero/hero.gd")
	_check(hero_source.contains("ranged.request(_aim, combat_origin())"),
		"the shot must leave from combat_origin, the same point the aim is "
			+ "measured from")


## An arrow carries the archer's strength, the same way a sword swing does.
##
## **It did not, and nothing noticed.** `Hero.damage_multiplier` folds in Might,
## worn gear, relics and the Command bonus, and every melee swing goes through
## it; a bow dealt `weapon.damage * ammo.damage_scale` and nothing else. By Act
## III a hero has all of that behind a sword blow and had none of it behind an
## arrow, so the bow quietly stopped being a weapon while still reading as one.
## Reported from play as arrows that "hit enemies but do not seem to hurt them".
##
## This gate had six tests over crafting, capacity, aim and flight and not one
## over what an arrow is worth when it lands.
## How many of the counted tests below reached their end.
var _finished_tests: int = 0


func _test_a_bow_is_carried_by_its_archer() -> void:
	var weapon: RangedWeaponData = null
	for value: Variant in ContentDB.ranged_weapons.values():
		weapon = value as RangedWeaponData
		break
	var kind := ContentDB.ammo_kinds.get("plain_arrow", null) as AmmoData
	if weapon == null or kind == null:
		_check(false, "no weapon or ammunition to measure")
		return
	var plain := HeroArrow.new()
	plain.launch(null, Vector2.ZERO, Vector2.RIGHT, weapon, kind, 1.0)
	var strong := HeroArrow.new()
	strong.launch(null, Vector2.ZERO, Vector2.RIGHT, weapon, kind, 2.0)
	_check(strong.damage > plain.damage * 1.9,
		("an archer twice as strong looses an arrow worth %.1f against %.1f; "
			+ "the bow is ignoring Might, gear and relics")
			% [strong.damage, plain.damage])
	plain.free()
	strong.free()
	_finished_tests += 1


## And melee stays the reliable default, which CLAUDE.md makes the bound of the
## whole ranged decision: "if a run can be completed at range without ever
## closing, the trade this system exists to create has collapsed".
##
## That bound was written down and never gated - this is the gate. Compared as
## sustained damage per second at equal archer strength, because a bow that beat
## a sword *per shot* is fine and one that beats it per second is not.
func _test_melee_is_still_the_default() -> void:
	var melee: float = 0.0
	for step: float in Balance.HERO_ATTACK_DAMAGE:
		melee += step
	# The whole chain's own timing, summed from the three phases each step
	# actually spends. There is no single interval constant for melee - the
	# swing is a state machine - and inventing one here would be a second
	# statement of the same fact for the balance to drift away from.
	var chain_seconds: float = 0.0
	for step: int in Balance.HERO_CHAIN_LENGTH:
		chain_seconds += Balance.HERO_ATTACK_WINDUP[step] 			+ Balance.HERO_ATTACK_ACTIVE[step] + Balance.HERO_ATTACK_RECOVERY[step]
	var melee_dps: float = melee / maxf(chain_seconds, 0.001)

	var best: float = 0.0
	var best_id: String = ""
	for value: Variant in ContentDB.ranged_weapons.values():
		var bow := value as RangedWeaponData
		if bow == null or bow.draw_time <= 0.0:
			continue
		# The strongest ammunition a bow can hold, which is the fairest case to
		# put against a sword that has no ammunition to choose.
		var scale: float = 1.0
		for other: Variant in ContentDB.ammo_kinds.values():
			var ammo := other as AmmoData
			if ammo != null and ammo.family == bow.family:
				scale = maxf(scale, ammo.damage_scale)
		# **Single target on both sides, and pierce is deliberately not counted.**
		# The first version multiplied a bow's damage by its pierce and reported
		# the heavy crossbow at 70 against melee's 38 - a violation that was
		# entirely the model's. Pierce pays on a line of bodies; melee's arc
		# catches everything in front of it and pays on exactly the same shape of
		# situation. Crediting one and not the other measures the comparison
		# rather than the weapons.
		var dps: float = bow.damage * scale / bow.draw_time
		if dps > best:
			best = dps
			best_id = bow.id
	_check(best <= melee_dps,
		("%s sustains %.1f damage a second against melee's %.1f; a run that can "
			+ "be finished at range without ever closing has lost the trade the "
			+ "bow exists to create") % [best_id, best, melee_dps])
	print("[ranged] melee %.1f dps single target, best bow %s at %.1f"
		% [melee_dps, best_id, best])
	_finished_tests += 1


func _test_swept_flight() -> void:
	_check(is_equal_approx(HeroArrow.contact_distance(Vector2.ZERO, Vector2.RIGHT,
		180.0, Vector2(90.0, 0.0), 12.0), 78.0), "sweep must detect a skipped body at entry")
	_check(HeroArrow.contact_distance(Vector2.ZERO, Vector2.RIGHT,
		50.0, Vector2(90.0, 0.0), 12.0) < 0.0, "sweep must respect the range endpoint")
	_check(HeroArrow.contact_distance(Vector2.ZERO, Vector2.RIGHT,
		180.0, Vector2(90.0, 13.0), 12.0) < 0.0, "sweep must not widen the hit radius")
	var field := EnemyField.new()
	add_child(field)
	var wildlife := ArrowWildlife.new()
	wildlife.name = "Wildlife"
	field.add_child(wildlife)
	for x: float in [70.0, 140.0]:
		var body := Node2D.new()
		body.position = Vector2(x, 0.0)
		wildlife.add_child(body)
		wildlife.bodies.append(body)
	var weapon := RangedWeaponData.new()
	weapon.pierce = 2
	weapon.projectile_speed = 900.0
	var ammo := AmmoData.new()
	var shot := HeroArrow.new()
	shot.launch(field, Vector2.ZERO, Vector2.RIGHT, weapon, ammo)
	field.add_child(shot)
	shot.set_process(false)
	shot._process(0.2)
	_check(wildlife.hits.size() == 2 and shot.is_queued_for_deletion(),
		"a hitch must hit both animals crossed and exhaust two-body pierce")
	wildlife.hits.clear()
	wildlife.bodies[0].position = Vector2(5.0, 0.0)
	weapon.pierce = 3
	weapon.projectile_speed = 20.0
	shot = HeroArrow.new()
	shot.launch(field, Vector2.ZERO, Vector2.RIGHT, weapon, ammo)
	field.add_child(shot)
	shot.set_process(false)
	for _frame: int in 5:
		shot._process(0.05)
	_check(int(wildlife.hits.get(wildlife.bodies[0].get_instance_id(), 0)) == 1,
		"one piercing arrow must not hurt the same animal on five successive frames")
	shot.queue_free()
	wildlife.hits.clear()
	wildlife.bodies[0].position = Vector2(140.0, 0.0)
	wildlife.bodies[1].position = Vector2(240.0, 0.0)
	var enemy := load("res://scenes/battlefield/enemy.tscn").instantiate() as Enemy
	enemy.setup(ContentDB.enemy("bogkin"), 0, field, 1.0)
	field.add_child(enemy)
	enemy.set_process(false)
	enemy.global_position += Vector2(70.0, 0.0) - enemy.combat_origin()
	var health: Health = Health.of(enemy)
	var before: float = health.current_hp
	weapon.pierce = 1
	weapon.projectile_speed = 900.0
	weapon.damage = 1.0
	shot = HeroArrow.new()
	shot.launch(field, Vector2.ZERO, Vector2.RIGHT, weapon, ammo)
	field.add_child(shot)
	shot.set_process(false)
	shot._process(0.2)
	_check(health.current_hp < before and wildlife.hits.is_empty(),
		"the nearer enemy must intercept before a farther animal")
	_check(shot.global_position.x < 70.0,
		"impact VFX must originate at first contact, not the frame endpoint")
	before = health.current_hp
	weapon.effective_range = 30.0
	shot = HeroArrow.new()
	shot.launch(field, Vector2.ZERO, Vector2.RIGHT, weapon, ammo)
	field.add_child(shot)
	shot.set_process(false)
	shot._process(1.0)
	_check(is_equal_approx(shot.global_position.x, 30.0) and health.current_hp == before,
		"a long frame must stop at weapon range, not hit a target beyond it")
	field.queue_free()
	for _frame: int in 30:
		await get_tree().process_frame
