extends Node

## Evidence, tracking, encounter — and the ways a trail quietly leads nowhere.
##
##   godot --headless --path game res://tools/mythic_trail_check.tscn
##
## The owner forwarded a proposal for 112 mythical creatures on 2026-09-15;
## `docs/IDEAS_REVIEW_2026-09-15.md` triaged it and concluded that the best idea
## in it is not a creature but the **trail**, and that the trail has to be built
## before any of them.
##
## **Everything about a trail fails silently.** A sign nobody can find, a stage
## with no sign authored, a species that is also in the random scatter, an
## animal that never arrives at the end: not one of them errors, and the player
## has no way to tell a trail that is subtle from one that is broken. So:
##
## - **A mythic is never scattered.** That is the whole of what the
##   classification means. If `_pick_kind` could offer one, the trail is
##   decoration and the rarest thing in the game turns up like a rabbit.
## - **Every stage has a sign.** The trail deals one sign per stage in order; a
##   hole at stage 3 is a trail that ends three steps early, and the animal
##   arrives with no warning at all.
## - **Every sign has a picture and a sentence.** A sign with neither is an
##   invisible thing that says nothing, which is indistinguishable from a bug.
## - **It gets somewhere.** Every sign is laid out in the wilds, on open ground,
##   and each is further along than the last - a trail that scatters is five
##   unrelated curiosities.
## - **And the animal is at the end of it.** Walked to the last stage, the
##   quarry must actually be on the field.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_content_is_whole()
	_test_a_mythic_is_never_scattered()
	await _test_the_trail_leads_somewhere_and_ends_in_the_animal()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[mythic-trail] PASS - %d checks: every stage has a sign, no "
			+ "mythic is ever scattered, the trail leads outward and the animal "
			+ "is at the end of it") % _checks)
	else:
		push_error("[mythic-trail] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **A trail with a hole in it ends early, in silence.**
func _test_the_content_is_whole() -> void:
	var mythics: Array[WildlifeData] = []
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind != null and kind.mythic:
			mythics.append(kind)
	_check(not mythics.is_empty(),
		"nothing is mythic, so the whole trail is unreachable content")
	for kind: WildlifeData in mythics:
		_check(not kind.trail_signs.is_empty(),
			"%s is mythic and leaves nothing behind, so it can never be found"
				% kind.id)
		for stage: int in Balance.TRAIL_LENGTH:
			var found: bool = false
			for id: String in kind.trail_signs:
				var sign := ContentDB.trail_signs.get(id, null) as TrailSignData
				if sign != null and sign.suits(kind.id, stage):
					found = true
			_check(found,
				("%s has no sign for stage %d of %d - its trail ends there and "
					+ "the animal arrives unannounced")
					% [kind.id, stage, Balance.TRAIL_LENGTH])
		# And it must be reachable: an act past the last one is content nobody
		# meets, which is this project's oldest recurring failure.
		_check(kind.trail_first_act >= 1 and kind.trail_first_act <= Balance.ACT_COUNT,
			"%s begins in act %d of %d" % [kind.id, kind.trail_first_act,
				Balance.ACT_COUNT])

	for value: Variant in ContentDB.trail_signs.values():
		var sign := value as TrailSignData
		if sign == null:
			continue
		_check(not sign.reading.strip_edges().is_empty(),
			"%s says nothing when it is read" % sign.id)
		_check(ResourceLoader.exists(sign.get_sprite_path()),
			"%s has no picture at %s" % [sign.id, sign.get_sprite_path()])
		_check(sign.stage >= 0 and sign.stage < Balance.TRAIL_LENGTH,
			("%s sits at stage %d, which a trail of %d never deals")
				% [sign.id, sign.stage, Balance.TRAIL_LENGTH])
		# A sign for a species that does not exist is a sign nothing deals.
		_check(sign.species.is_empty()
				or ContentDB.wildlife_kinds.has(sign.species),
			"%s belongs to \"%s\", which is not an animal" % [sign.id, sign.species])


## **The classification, driven rather than read.**
##
## `_tilted_weight` is what both the total and the draw in `_pick_kind` go
## through, so a mythic weighing zero there is the whole guarantee. Checked by
## asking the real function rather than by reading the flag, because the flag
## being set and the roll ignoring it are two different things.
func _test_a_mythic_is_never_scattered() -> void:
	var animals := Wildlife.new()
	animals.grid = BattleGrid.new()
	add_child(animals)
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind == null or not kind.mythic:
			continue
		for wildness: float in [0.0, 0.5, 1.0]:
			var weight: float = float(animals.call("_tilted_weight", kind, wildness))
			_check(is_zero_approx(weight),
				("%s weighs %.3f in the scatter at wildness %.1f - a mythic that "
					+ "can simply turn up is not a mythic")
					% [kind.id, weight, wildness])
	animals.queue_free()


## **Walked, on the real field.**
func _test_the_trail_leads_somewhere_and_ends_in_the_animal() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	# The trail begins at `trail_first_act`, and the Moonstag's is act 2 - a
	# gate that stood in act 1 would be testing a road with no trail on it.
	RunState.act = maxi(RunState.act, 2)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var trail: MythicTrail = field.trail() if field != null else null
	_check(trail != null, "the battlefield must lay a trail")
	if trail == null:
		run.queue_free()
		return
	trail.scatter()
	var first: Dictionary = trail.report()
	_check(not String(first["quarry"]).is_empty(),
		"the trail chose nothing to be about")
	_check((first["signs"] as Array).size() == 1,
		"a fresh trail must have laid exactly its first sign, laid %d"
			% (first["signs"] as Array).size())

	# **Every sign is out in the wilds and further along than the last.**
	var last_out: float = 0.0
	for step: int in Balance.TRAIL_LENGTH + 1:
		var now: Dictionary = trail.report()
		var places: Array = now["signs"]
		if not places.is_empty():
			var at: Vector2 = places[places.size() - 1]
			_check(BattleGrid.beyond_core(at),
				("sign %d is inside the city's own square, where a thing that "
					+ "hides does not leave anything") % places.size())
			_check(at.length() >= Balance.TRAIL_FIRST_DISTANCE * 0.5,
				"sign %d is %.0f from the square, which is not the wilds"
					% [places.size(), at.length()])
			last_out = at.length()
		if not trail.read_the_next_sign():
			break
	var ended: Dictionary = trail.report()
	_check(bool(ended["found"]),
		"walking the whole trail must end in the animal being placed")
	_check((ended["signs"] as Array).size() >= Balance.TRAIL_LENGTH,
		"the trail laid %d signs of %d"
			% [(ended["signs"] as Array).size(), Balance.TRAIL_LENGTH])
	_check(last_out > 0.0, "no sign was ever laid")

	# And the quarry is on the field, once, wearing everything an animal wears.
	var animals: Wildlife = field.wildlife()
	var standing: int = 0
	if animals != null:
		for record: Dictionary in animals.living():
			if String((record["data"] as WildlifeData).id) == String(ended["quarry"]):
				standing += 1
	_check(standing == 1,
		"%s should be standing at the end of its trail, found %d"
			% [String(ended["quarry"]), standing])

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[mythic-trail] " + why)
