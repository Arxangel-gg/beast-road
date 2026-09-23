extends Node

## Taking an animal alive, driven on a real field.
##
## Owner brief, 2026-09-16: capture by wearing an animal down and throwing
## something, not by killing it.
##
## What this holds, and why each one is the thing worth holding:
##
## - **Hurt is what moves the odds.** If it is not, the whole mechanic is a
##   lottery with a rope drawn on it and there is no reason to fight anything
##   first. Measured across the whole health range rather than asserted at two
##   points, because the *shape* is the design.
## - **Nothing is ever certain**, and a whole legendary is nearly impossible.
## - **A capture creates nothing.** The rarity, the shine and the temperament
##   that arrive in the pen are the ones that were on the field. A capture that
##   re-rolled any of them would be a loot box wearing a rope, and it is the one
##   failure here that would be worth exploiting.
## - **It is a capture, not a kill**: no drop, no experience, no wrath. The
##   earth has to stay quiet, or taming an animal alive would cost what killing
##   it costs and nobody would ever do it.
## - **A full pen refuses rather than eating the animal.** Losing a legendary
##   with no explanation is the worst thing this system could do.
## - **And the pen's own bound survives**: an animal caught this minute may go
##   to work, and anything out may be stood down, but a mid-run *swap* is still
##   refused. You can always make things safer, never riskier.

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	RunState.reset(false, 20260916)
	await _test_hurt_is_what_moves_the_odds()
	await _test_a_capture_creates_nothing()
	await _test_it_is_not_a_kill()
	await _test_a_full_pen_refuses()
	_test_the_pen_bound_survives()
	Sfx.stop_immediately()
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[taming] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[taming] PASS - %d checks: hurt moves the odds, nothing is certain,"
		% _checked + " a capture creates nothing, it is not a kill, a full pen refuses,"
		+ " and the pen's own bound survives")
	get_tree().quit(0)


## A field with wildlife on it, and one animal placed by hand so its health can
## be driven. The real `Wildlife`, because the thing under test reads its
## records through the same seams the rope does.
func _field() -> Node:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	return run


## **Placed by hand rather than waited for.** Arrivals are on their own clock and
## headless frames pass no real time, so waiting for one is waiting for ever -
## the same finding the pond fish gate reached. `_spawn` is the system's own
## door, so what stands on the field is a real animal with a real record.
func _an_animal(field: Node, species: String, hp_share: float) -> int:
	var animals: Node = field.call("wildlife")
	if animals == null:
		return 0
	var wanted: WildlifeData = null
	for data: WildlifeData in ContentDB.wildlife():
		if species.is_empty() or data.id == species:
			wanted = data
			break
	if wanted != null:
		var hero: Node2D = field.get("hero") as Node2D
		var here: Vector2 = hero.global_position if hero != null else Vector2.ZERO
		var at: Vector2 = here + Vector2(140.0, 0.0)
		animals.call("_spawn", wanted, at)
	for sprite: Node2D in animals.call("living_sprites") as Array[Node2D]:
		var record: Dictionary = animals.call("record_for_id", sprite.get_instance_id())
		if record.is_empty():
			continue
		var kind: WildlifeData = record.get("data", null) as WildlifeData
		if kind == null or (not species.is_empty() and kind.id != species):
			continue
		record["hp"] = kind.max_hp * hp_share
		return sprite.get_instance_id()
	return 0


## **The shape, not two points.** A whole animal barely gives and a spent one
## mostly does, and the odds must rise the whole way between - a curve that
## flattened early would make the last half of a fight pointless.
func _test_hurt_is_what_moves_the_odds() -> void:
	var run: Node = _field()
	for _f: int in 20:
		await get_tree().process_frame
	var field: Node = run.get("battlefield")
	var id: int = _an_animal(field, "", 1.0)
	_check(id != 0, "there is an animal on the field to rope")
	if id == 0:
		run.queue_free()
		return
	var animals: Node = field.call("wildlife")
	var record: Dictionary = animals.call("record_for_id", id)
	var kind: WildlifeData = record["data"]
	var last: float = -1.0
	var rose_every_step: bool = true
	for step: int in 11:
		var share: float = 1.0 - float(step) / 10.0
		record["hp"] = maxf(kind.max_hp * share, 0.01)
		var chance: float = Taming.chance_for(id, field)
		if last >= 0.0 and chance < last - 0.0001:
			rose_every_step = false
		last = chance
	_check(rose_every_step, "the odds rise the whole way from whole to spent")
	record["hp"] = kind.max_hp
	var whole: float = Taming.chance_for(id, field)
	record["hp"] = kind.max_hp * 0.05
	var spent: float = Taming.chance_for(id, field)
	_check(spent > whole * 3.0,
		"a spent animal is far likelier than a whole one (%.3f against %.3f)" % [spent, whole])
	_check(whole <= 0.15, "a whole animal is nearly impossible to rope (%.3f)" % whole)
	_check(spent <= Balance.TAME_CHANCE_CEILING + 0.0001,
		"and nothing is ever certain (%.3f)" % spent)
	run.queue_free()
	await get_tree().process_frame


## **A capture creates nothing.** The one failure here worth exploiting would be
## a catch that re-rolled what it caught.
func _test_a_capture_creates_nothing() -> void:
	var run: Node = _field()
	for _f: int in 20:
		await get_tree().process_frame
	var field: Node = run.get("battlefield")
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	var id: int = _an_animal(field, "", 0.1)
	if id == 0:
		_check(false, "there is an animal to take")
		run.queue_free()
		return
	var animals: Node = field.call("wildlife")
	var record: Dictionary = animals.call("record_for_id", id)
	var kind: WildlifeData = record["data"]
	# Forced, so the roll is not what is under test - what arrives is.
	record["shiny"] = true
	var rarity_before: int = WildlifeFamilies.rarity_of(record)
	var trait_before: String = str(record.get("trait", ""))
	_check(Taming.take(id, field), "the animal is taken")
	var kept: Dictionary = MetaState.pen[0] if not MetaState.pen.is_empty() else {}
	_check(not kept.is_empty(), "and it is in the pen")
	if kept.is_empty():
		run.queue_free()
		return
	_check(str(kept.get("species", "")) == kind.id,
		"the species in the pen is the species on the field")
	_check(int(kept.get("rarity", -1)) == rarity_before,
		"the rarity is the one it had (%d against %d)"
			% [int(kept.get("rarity", -1)), rarity_before])
	_check(bool(kept.get("shiny", false)), "a shiny animal is shiny in the pen")
	_check(str(kept.get("trait", "")) == trait_before,
		"and it kept its own temperament")
	# Caught hurt, arrives hurt. The pen is what mends it.
	_check(MetaState.pen_health(str(kept["uid"])) < 0.5,
		"it arrives as hurt as it was caught (%.2f)"
			% MetaState.pen_health(str(kept["uid"])))
	# Off the road.
	_check(animals.call("record_for_id", id).is_empty(),
		"and it is no longer on the field")
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	run.queue_free()
	await get_tree().process_frame


## **It is a capture, not a kill.** Taming an animal alive must not cost what
## killing it costs, or nobody would ever do it.
func _test_it_is_not_a_kill() -> void:
	var run: Node = _field()
	for _f: int in 20:
		await get_tree().process_frame
	var field: Node = run.get("battlefield")
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	var sky: WeatherSky = field.call("sky")
	var anger_before: float = sky.wrath() if sky != null else 0.0
	var xp_before: int = RunState.hero_xp
	var food_before: int = RunState.currency(RunState.FOOD)
	var id: int = _an_animal(field, "", 0.1)
	if id == 0:
		_check(false, "there is an animal to take")
		run.queue_free()
		return
	# **Read with nothing between them but the take.** A run pays experience and
	# trickles Food on its own while frames pass, so a reading either side of a
	# wait measures the run rather than the capture.
	var took: bool = Taming.take(id, field)
	var xp_after: int = RunState.hero_xp
	var food_after: int = RunState.currency(RunState.FOOD)
	var anger_after: float = sky.wrath() if sky != null else 0.0
	_check(took, "the animal is taken")
	_check(is_equal_approx(anger_after, anger_before),
		"the earth stayed quiet - a capture is not a kill")
	_check(xp_after == xp_before, "no experience was paid")
	_check(food_after == food_before, "and no Food dropped")
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	run.queue_free()
	await get_tree().process_frame


## A full pen refuses and says so, rather than eating the animal.
func _test_a_full_pen_refuses() -> void:
	var run: Node = _field()
	for _f: int in 20:
		await get_tree().process_frame
	var field: Node = run.get("battlefield")
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	for _one: int in Balance.PEN_CAPACITY:
		MetaState.pen_add("rabbit", 0, false, "", 1.0)
	_check(not MetaState.pen_has_room(), "the pen is full")
	var id: int = _an_animal(field, "", 0.05)
	if id != 0:
		_check(not Taming.take(id, field), "a full pen refuses the catch")
		_check(not field.call("wildlife").call("record_for_id", id).is_empty(),
			"and the animal is still on the field rather than gone")
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	run.queue_free()
	await get_tree().process_frame


## **Safer always, riskier never.** A fresh catch may go to work mid-run; an
## animal already out may be stood down at any time; a mid-run *swap* between two
## penned animals is still refused, which is the bound the pen was built under.
func _test_the_pen_bound_survives() -> void:
	MetaState.pen.clear()
	MetaState.pen_taken = ""
	var first: String = MetaState.pen_add("fox", 0, false, "", 1.0)
	var second: String = MetaState.pen_add("deer", 0, false, "", 1.0)
	# A road is live when the director says so (`RunState.road_is_live`), not
	# when the phase alone reads mid-run - which it does on every fresh launch.
	var was_active: bool = GameDirector.run_active
	GameDirector.run_active = true
	RunState.phase = RunState.Phase.ROAD_BATTLE
	_check(not MetaState.pen_take(first), "a mid-run swap is still refused")
	_check(MetaState.pen_take(first, true), "a fresh catch goes to work mid-run")
	_check(not MetaState.pen_take(second),
		"and it still cannot be swapped for another one")
	_check(MetaState.pen_stand_down(), "it can be stood down at any time")
	_check(MetaState.pen_taken.is_empty(), "and then nothing is out")
	GameDirector.run_active = was_active
	RunState.phase = RunState.Phase.ENDED
	MetaState.pen.clear()
	MetaState.pen_taken = ""


func _check(passed: bool, what: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[taming] %s" % what)
