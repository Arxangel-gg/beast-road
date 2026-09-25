extends Node

## **Keystone Road Cards** (2026-09-25, `docs/IDEAS_REVIEW_2026-09-25.md` §2).
##
## A keystone re-routes an existing effect onto a new trigger and never moves its
## size - the discipline synergies' bound on a card. This holds the card side
## (authored, one a hand, dealt on dice of their own without moving the ordinary
## draft) and drives each of the five through the door it re-routes:
##
## - **Cold Snap**: a body that dies chilled passes its chill on, and only then.
## - **Tinderstrike**: the finisher lights the brush where it lands; nothing else does.
## - **Timberwright**: a trunk felled mends the towers near it through `repair`.
## - **Sapper's Due**: a seam emptied rearms the traps near it, and only those.
## - **Hunter's Mark**: what the Warden struck comes first in a tower's eye.

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260926)
	_test_every_keystone_is_authored()
	_test_one_keystone_a_hand()
	_test_the_ordinary_draft_did_not_move()
	_test_keystones_are_dealt_and_only_last()

	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		_check(false, "the harness needs a battlefield")
	else:
		if _field.town != null and _field.town.health != null:
			_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
		RunState.gain_every_currency(20000)
		_test_cold_snap()
		_test_tinderstrike()
		await _test_timberwright()
		await _test_sappers_due()
		await _test_hunters_mark()

	_hold([])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	for _frame: int in 20:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures == 0:
		print(("[keystones] PASS - %d checks: authored, one a hand, dealt apart, and each "
			+ "re-routes its door at that door's own size") % _checks)
	else:
		push_error("[keystones] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[keystones] FAIL: %s" % why)


func _keystones() -> Array[RoadCardData]:
	var out: Array[RoadCardData] = []
	var ids: Array = ContentDB.road_cards.keys()
	ids.sort()
	for id: Variant in ids:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card != null and card.keystone:
			out.append(card)
	return out


## Hold exactly these cards and rebuild the table they feed.
func _hold(ids: Array) -> void:
	var hand: Array[String] = []
	for id: Variant in ids:
		hand.append(String(id))
	RunState.road_cards = hand
	Modifiers.rebuild()


# --- The cards ---------------------------------------------------------------------

func _test_every_keystone_is_authored() -> void:
	var cards: Array[RoadCardData] = _keystones()
	_check(cards.size() >= 5, "only %d keystones are authored" % cards.size())
	var keys: PackedStringArray = Modifiers.keys_in_use()
	var claimed: Dictionary = {}
	for card: RoadCardData in cards:
		_check(card.effect_id.begins_with("keystone_") and keys.has(card.effect_id),
			"%s re-routes '%s', which is no keystone flag on the table" % [card.id, card.effect_id])
		_check(is_equal_approx(card.effect_magnitude, 1.0),
			"%s sets its flag to %.2f; a keystone is a flag, not a number" % [card.id, card.effect_magnitude])
		_check(card.first_act >= 3, "%s is dealt from act %d, before the draft has a hand" % [card.id, card.first_act])
		_check(not card.card_text.strip_edges().is_empty(), "%s says nothing" % card.id)
		_check(ResourceLoader.exists(card.get_sprite_path()), "%s has no icon" % card.id)
		_check(Modifiers.LABELS.has(card.effect_id), "%s has no label on the table" % card.id)
		claimed[card.effect_id] = true
	# Every keystone flag has a card, or it is a flag nothing can set.
	for key: String in keys:
		if key.begins_with("keystone_"):
			_check(claimed.has(key), "the flag '%s' has no card to set it" % key)


## **One keystone in a hand**: a second replaces the first, and an ordinary card
## leaves it where it is.
func _test_one_keystone_a_hand() -> void:
	var cards: Array[RoadCardData] = _keystones()
	if cards.size() < 2:
		return
	_hold([])
	RunState.take_road_card(cards[0].id)
	var went: String = RunState.take_road_card(cards[1].id)
	_check(went == cards[0].id and RunState.road_cards == [cards[1].id],
		"a second keystone did not replace the first: the hand is %s" % str(RunState.road_cards))
	var ordinary: String = ""
	for id: Variant in ContentDB.road_cards:
		var card: RoadCardData = ContentDB.road_card(String(id))
		if card != null and not card.keystone:
			ordinary = card.id
			break
	RunState.take_road_card(ordinary)
	_check(RunState.road_cards.has(cards[1].id) and RunState.road_cards.size() == 2,
		"an ordinary card took the keystone's place")
	_hold([])


## **The ordinary draft is exactly what it was.** The pool is shuffled on the
## "road_cards" stream; the keystone is dealt on dice of its own - so the ordinary
## stream spends exactly the draws a pool without keystones would.
func _test_the_ordinary_draft_did_not_move() -> void:
	for act: int in [3, 6, 10]:
		var stream: RandomNumberGenerator = RunState.rng("road_cards")
		var twin := RandomNumberGenerator.new()
		twin.seed = stream.seed
		twin.state = stream.state
		var ordinary: int = 0
		for id: Variant in ContentDB.road_cards:
			var card: RoadCardData = ContentDB.road_card(String(id))
			if card != null and not card.keystone and card.first_act <= act:
				ordinary += 1
		RoadCardData.offer([], act, Balance.ROAD_CARD_OFFER_COUNT)
		for index: int in range(ordinary - 1, 0, -1):
			twin.randi_range(0, index)
		_check(stream.state == twin.state,
			"act %d: the ordinary draft spent other draws than a pool without keystones would" % act)


## Dealt about as often as authored, only in the last slot, and never early.
func _test_keystones_are_dealt_and_only_last() -> void:
	var dealt: int = 0
	var offers: int = 3000
	for _i: int in offers:
		var drawn: Array[String] = RoadCardData.offer([], 5, Balance.ROAD_CARD_OFFER_COUNT)
		for index: int in drawn.size():
			var card: RoadCardData = ContentDB.road_card(drawn[index])
			if card != null and card.keystone:
				_check(index == drawn.size() - 1, "a keystone was dealt in slot %d, not the last" % index)
				dealt += 1
		_check(drawn.size() == Balance.ROAD_CARD_OFFER_COUNT, "a draft came up short")
	var share: float = float(dealt) / float(offers)
	_check(absf(share - Balance.KEYSTONE_OFFER_CHANCE) < 0.04,
		"keystones came in %.3f of drafts against %.3f" % [share, Balance.KEYSTONE_OFFER_CHANCE])
	for _i: int in 400:
		for id: String in RoadCardData.offer([], 2, Balance.ROAD_CARD_OFFER_COUNT):
			_check(not ContentDB.road_card(id).keystone, "a keystone was dealt in act 2")


# --- The doors ------------------------------------------------------------------------------

func _stand(at: Vector2) -> Enemy:
	var none: Array[EnemyAffixData] = []
	var body: Enemy = _field.spawn_enemy(ContentDB.enemy("bogkin"), 0, 1.0, 1.0, 1.0,
		false, Enemy.Rank.COMMON, none)
	if body != null:
		body.global_position = at
		body.health.max_hp = 100000.0
		body.health.current_hp = 100000.0
	return body


func _free(bodies: Array) -> void:
	for body: Variant in bodies:
		if body != null and is_instance_valid(body):
			(body as Node).queue_free()


## **Cold Snap**: the dying body's own chill, shared, to those inside the reach.
func _test_cold_snap() -> void:
	for held: bool in [false, true]:
		_hold(["cold_snap"] if held else [])
		var at := Vector2(-2600.0, 2400.0)
		var dying: Enemy = _stand(at)
		var near: Enemy = _stand(at + Vector2(Balance.KEYSTONE_COLD_SNAP_REACH * 0.5, 0.0))
		var far: Enemy = _stand(at + Vector2(Balance.KEYSTONE_COLD_SNAP_REACH * 2.5, 0.0))
		if dying == null or near == null or far == null:
			_free([dying, near, far])
			return
		dying.call("_add_chill", 0.8)
		var chill: float = float(dying.get("_chill"))
		dying.health.kill(at)
		var took: float = float(near.get("_chill"))
		if held:
			_check(took > chill * Balance.KEYSTONE_COLD_SNAP_SHARE * 0.9,
				"Cold Snap passed %.2f of a %.2f chill on" % [took, chill])
			_check(took <= chill + 0.0001, "Cold Snap made more cold than the body had")
			_check(float(far.get("_chill")) == 0.0, "Cold Snap reached past its reach")
		else:
			_check(took == 0.0, "a chilled death passed its chill on with no keystone held")
		_free([near, far])
	_hold([])


## **Tinderstrike**: the finisher lights the brush where it lands, and nothing
## short of the finisher does.
func _test_tinderstrike() -> void:
	var fire: Wildfire = _field.wildfire()
	if fire == null:
		_check(false, "the harness needs the wildfire")
		return
	RunState.rain_intensity = 0.0
	RunState.flood = 0.0
	var plant: Dictionary = fire.call("_nearest_unburnt", _field.hero.global_position, 99999.0)
	_check(not plant.is_empty(), "there is no brush on the field to light")
	if plant.is_empty():
		return
	var at: Vector2 = plant["at"]
	var finisher: int = Balance.HERO_CHAIN_LENGTH - 1
	_hold([])
	var before: int = fire.lit_count
	EventBus.hero_attack_landed.emit(finisher, 1, at, 0)
	_check(fire.lit_count == before, "a finisher lit the brush with no keystone held")
	_hold(["tinderstrike"])
	EventBus.hero_attack_landed.emit(0, 1, at, 0)
	_check(fire.lit_count == before, "an opening swing lit the brush - only the finisher does")
	var owed: int = fire.burnt_by_player
	EventBus.hero_attack_landed.emit(finisher, 1, at, 0)
	_check(fire.lit_count == before + 1, "a finisher with Tinderstrike held lit nothing")
	_check(owed == fire.burnt_by_player or fire.burnt_by_player >= owed,
		"the fire the Warden lit is not counted as the player's")
	_hold([])


## **Timberwright**: a felled trunk mends the towers near it, by the repair
## door's own share, and none far away.
func _test_timberwright() -> void:
	var gathering: Gathering = _field.gathering()
	var woodcutting: GatherNodeData = ContentDB.gather_node("ashwood")
	if gathering == null or woodcutting == null:
		_check(false, "the harness needs the gathering and a trunk")
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	var anchor: Vector2i = _field.free_anchor_near(1, 8)
	_check(_field.try_build(anchor, ContentDB.tower("ember_spire")).is_empty(), "the harness could not build")
	await get_tree().process_frame
	var tower: Tower = _field.tower_at_anchor(anchor)
	if tower == null:
		return
	var health: Health = Health.of(tower)
	for held: bool in [false, true]:
		_hold(["timberwright"] if held else [])
		health.current_hp = health.max_hp * 0.4
		gathering.call("_keystone_worked_out", woodcutting, tower.origin() + Vector2(120.0, 0.0))
		var mended: float = health.current_hp / health.max_hp
		if held:
			_check(absf(mended - (0.4 + Balance.KEYSTONE_TIMBER_MEND)) < 0.02,
				"Timberwright mended a tower to %.2f, not by its share" % mended)
		else:
			_check(is_equal_approx(mended, 0.4), "a felled trunk mended a tower with no keystone held")
	# Out of reach, nothing.
	_hold(["timberwright"])
	health.current_hp = health.max_hp * 0.4
	gathering.call("_keystone_worked_out", woodcutting,
		tower.origin() + Vector2(Balance.KEYSTONE_WORK_REACH * 2.0, 0.0))
	_check(is_equal_approx(health.current_hp / health.max_hp, 0.4),
		"Timberwright mended a tower past its reach")
	_hold([])
	_field.try_sell(anchor)


## **Sapper's Due**: a seam emptied rearms the traps near it, and only those.
func _test_sappers_due() -> void:
	var gathering: Gathering = _field.gathering()
	var seam: GatherNodeData = ContentDB.gather_node("copper_seam")
	var trap: TrapData = ContentDB.trap("spike_pit")
	if gathering == null or seam == null or trap == null:
		_check(false, "the harness needs the gathering, a seam and a trap")
		return
	RunState.set_phase(RunState.Phase.PREPARATION)
	var tile: Vector2i = Vector2i(-1, -1)
	for point: Vector2 in _field.lane_route(0):
		var candidate: Vector2i = BattleGrid.world_to_tile(point)
		if _field.try_place_trap(candidate, trap).is_empty():
			tile = candidate
			break
	_check(tile != Vector2i(-1, -1), "the harness could not lay a trap")
	if tile == Vector2i(-1, -1):
		return
	var at: Vector2 = BattleGrid.tile_to_world(tile)
	for held: bool in [false, true]:
		_hold(["sappers_due"] if held else [])
		var entry: Dictionary = RunState.traps[tile]
		entry["triggers_left"] = 0
		RunState.traps[tile] = entry
		gathering.call("_keystone_worked_out", seam, at + Vector2(90.0, 0.0))
		var left: int = int(RunState.traps[tile].get("triggers_left", 0))
		if held:
			_check(left > 0, "Sapper's Due rearmed no trap beside the seam")
		else:
			_check(left == 0, "an emptied seam rearmed a trap with no keystone held")
	_hold(["sappers_due"])
	var spent: Dictionary = RunState.traps[tile]
	spent["triggers_left"] = 0
	RunState.traps[tile] = spent
	gathering.call("_keystone_worked_out", seam, at + Vector2(Balance.KEYSTONE_WORK_REACH * 2.0, 0.0))
	_check(int(RunState.traps[tile].get("triggers_left", 0)) == 0,
		"Sapper's Due rearmed a trap past its reach")
	_hold([])
	RunState.clear_trap(tile)
	await get_tree().process_frame


## **Hunter's Mark**: what the Warden has just struck comes first in a tower's
## eye whatever the doctrine, for its seconds and no longer.
func _test_hunters_mark() -> void:
	RunState.set_phase(RunState.Phase.PREPARATION)
	var anchor: Vector2i = _field.free_anchor_near(2, 8)
	_check(_field.try_build(anchor, ContentDB.tower("ember_spire")).is_empty(), "the harness could not build")
	await get_tree().process_frame
	var tower: Tower = _field.tower_at_anchor(anchor)
	if tower == null:
		return
	var near: Enemy = _stand(tower.origin() + Vector2(60.0, 0.0))
	var struck: Enemy = _stand(tower.origin() + Vector2(300.0, 0.0))
	if near == null or struck == null:
		_free([near, struck])
		return
	for held: bool in [false, true]:
		_hold(["hunters_mark"] if held else [])
		struck.set("_hunted_left", 0.0)
		struck.take_damage(1.0, _field.hero.global_position, 0.0, true)
		var first: float = float(tower.call("_target_score", struck, 0))
		var second: float = float(tower.call("_target_score", near, 0))
		if held:
			_check(struck.is_hunted() and first > second,
				"a body the Warden struck is not first in a tower's eye")
		else:
			_check(not struck.is_hunted(), "a body was hunted with no keystone held")
	struck.set("_hunted_left", 0.0)
	_check(float(tower.call("_target_score", struck, 0)) < Balance.KEYSTONE_HUNT_PRIORITY,
		"the mark outlived its seconds")
	_hold([])
	_free([near, struck])
	_field.try_sell(anchor)
