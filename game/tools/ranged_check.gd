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

	print("[ranged] capacity %d, batch %d, %d weapons, %d ammunitions, %d plans"
		% [Balance.AMMO_CAPACITY, kind.craft_batch, ContentDB.ranged_weapons.size(),
			ContentDB.ammo_kinds.size(), ContentDB.blueprints.size()])

	bow.queue_free()
	for _frame: int in 6:
		await get_tree().process_frame
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
