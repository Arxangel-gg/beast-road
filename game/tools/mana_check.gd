extends Node

## Mana, and the Focus attribute that had promised "spell power" and paid none.
##
## Four things a mana system can quietly fail at, each with precedent here:
## a spell that costs nothing because nobody authored a cost; a cast that goes
## off unpaid; a refusal that spends anyway; and an attribute the Mansion
## describes that no code reads - which is what Focus was for spells until
## 2026-09-11, `HERO_FOCUS_SPELL_PER_POINT` having been defined and never
## consulted. This drives a real caster against a stand-in hero that keeps a
## pool, and reads the numbers back.

## A hero that only has a pool. The caster asks it to pay, and it says.
const POOL_SOURCE: String = "extends Node2D\nvar mana: float = 100.0\nvar refused: int = 0\nfunc spend_mana(cost: float) -> bool:\n\tif mana < cost:\n\t\trefused += 1\n\t\treturn false\n\tmana -= cost\n\treturn true\n"

var _failures: int = 0
var _starved: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset()
	RunState.phase = RunState.Phase.ROAD_BATTLE

	# 1. Every spell costs something, authored or by default.
	for value: Variant in ContentDB.spells.values():
		var spell := value as SpellData
		if spell == null:
			continue
		_check(spell.cost() > 0.0, "%s costs nothing" % spell.id)
		_check(spell.mana_cost > 0.0,
			"%s has no authored mana cost and is paying the default" % spell.id)

	# 2. A bare caster - the gates' shape - casts for free.
	var field := EnemyField.new()
	add_child(field)
	var free := SpellCaster.new()
	free.field = field
	add_child(free)
	await get_tree().process_frame
	RunState.equipped_spells[0] = "rift_step"
	free.clear_cooldowns()
	_check(free.try_cast(0, Vector2.RIGHT, Vector2.ZERO),
		"a caster with no hero must still cast; the gates depend on it")

	# 3. A caster with a hero pays, and is refused - unpaid - when it cannot.
	var pool_script := GDScript.new()
	pool_script.source_code = POOL_SOURCE
	pool_script.reload()
	var stand_in := Node2D.new()
	stand_in.set_script(pool_script)
	add_child(stand_in)
	var paid := SpellCaster.new()
	paid.field = field
	paid.hero = stand_in
	paid.cast_starved.connect(func(_slot: int) -> void: _starved += 1)
	add_child(paid)
	await get_tree().process_frame
	var rift := ContentDB.spells.get("rift_step", null) as SpellData
	var before: float = float(stand_in.get("mana"))
	paid.clear_cooldowns()
	_check(paid.try_cast(0, Vector2.RIGHT, Vector2.ZERO), "a paid cast must go off")
	_check(is_equal_approx(float(stand_in.get("mana")), before - rift.cost()),
		"a cast must draw exactly its cost: %.1f -> %.1f for a %.1f spell"
			% [before, float(stand_in.get("mana")), rift.cost()])
	stand_in.set("mana", rift.cost() * 0.5)
	paid.clear_cooldowns()
	_check(not paid.try_cast(0, Vector2.RIGHT, Vector2.ZERO),
		"a cast the pool cannot cover must be refused")
	_check(is_equal_approx(float(stand_in.get("mana")), rift.cost() * 0.5),
		"and a refused cast must spend nothing")
	_check(_starved == 1, "and say so once, so the HUD can flash the bar")
	_check(paid.is_ready(0), "a refused cast must not start the cooldown")

	# 4. Focus does what the Mansion says: harder spells, shorter cooldowns.
	RunState.hero_attributes[RunState.Attribute.FOCUS] = 0
	var plain_power: float = SpellCaster.focus_power()
	var plain_cooldown: float = paid._effective_cooldown(rift)
	RunState.hero_attributes[RunState.Attribute.FOCUS] = 20
	_check(SpellCaster.focus_power() > plain_power,
		"twenty Focus must raise spell power above %.2f" % plain_power)
	_check(paid._effective_cooldown(rift) < plain_cooldown,
		"twenty Focus must shorten a cooldown below %.2fs" % plain_cooldown)
	RunState.hero_attributes[RunState.Attribute.FOCUS] = 1000
	_check(paid._effective_cooldown(rift) >= plain_cooldown * (1.0 - Balance.HERO_FOCUS_COOLDOWN_CAP) - 0.01,
		"Focus must not cut a cooldown past its cap")
	RunState.hero_attributes[RunState.Attribute.FOCUS] = 0

	free.queue_free()
	paid.queue_free()
	stand_in.queue_free()
	field.queue_free()
	# Dropped by hand: `_ready` is a coroutine, so its locals outlive the quit
	# below and the engine reports the runtime script as a leaked resource.
	pool_script = null
	rift = null
	# The casts above played their sounds, and a playback still running at
	# quit is reported as a leaked resource. momentum_check learned the same.
	Sfx.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures > 0:
		push_error("[mana] FAIL - %d problem(s)" % _failures)
		get_tree().quit(1)
		return
	print("[mana] PASS - every spell costs, a cast pays or is refused unpaid, and Focus sharpens and shortens")
	get_tree().quit(0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)
