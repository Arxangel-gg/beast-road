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
	_check(arrow.contains("wound_near"),
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
