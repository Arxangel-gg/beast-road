extends Node

## Pieces, the toss, the pouch, the quiver and the mana orb (owner,
## 2026-09-21: "pickups should fall and bounce on the ground and scatter in
## high quantities instead of as stacks ... more pickups should drop more often
## but maybe in less total quantity").
##
## Eight things, each the bound that keeps the juice from becoming an economy:
##
## - **The pieces sum exactly to the amount**, for every currency and hundreds
##   of totals, and no piece is worth nothing. `LootDrop.split` is the one
##   place that divides and this is the one place that checks it.
## - **A piece is thrown, lands, bounces and settles**, driven by hand through
##   the real `_process`, and a hero standing under it cannot take it out of
##   the air. The toss is a picture; the node never leaves the ground.
## - **One lamp per batch.** Nine coins are not nine lights.
## - **A mirror flies the same arc.** Two pieces with one net id land in one
##   place; two with none do not share a toss.
## - **A pouch spills exactly what it carried**, across the four currencies,
##   and the purse gains it once.
## - **A quiver pays a bow and nothing else**, and is never dropped for a
##   Warden without one.
## - **A mana orb is a share of the pool and never past it.**
## - **The field never holds more than `LOOT_FIELD_MAX` drops**, and making
##   room pays rather than deletes.

const FRAME: float = 1.0 / 60.0
const RECOVERIES: Array[String] = ["healing_orb", "mender_spark", "supply_crate",
	"coin_pouch", "quiver", "mana_orb"]

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260921)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		_check(false, "the harness needs a battlefield")
		_finish()
		return
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.resume()
	for _frame: int in 4:
		await get_tree().process_frame
	_field.hero.global_position = Vector2(4000.0, 4000.0)

	_test_split_sums_exactly()
	await _test_a_piece_is_thrown_lands_and_settles()
	await _test_one_lamp_per_batch()
	await _test_a_mirror_flies_the_same_arc()
	await _test_a_pouch_spills_what_it_carried()
	await _test_a_quiver_pays_a_bow_and_nothing_else()
	_test_a_mana_orb_is_a_share_of_the_pool()
	await _test_the_field_never_overfills()
	_test_the_retune_kept_the_bonus_a_bonus()
	_finish()


## Every drop of a currency at a point, from the group.
func _pieces_at(at: Vector2, currency: String = "") -> Array[LootDrop]:
	var out: Array[LootDrop] = []
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop == null or not is_instance_valid(drop) or drop.is_taken():
			continue
		if drop.global_position.distance_to(at) > 60.0:
			continue
		if not currency.is_empty() and drop.currency != currency:
			continue
		out.append(drop)
	return out


func _clear_field_loot() -> void:
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		node.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _test_split_sums_exactly() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 2026_09_21
	var probed: int = 0
	for currency: String in RunState.CURRENCIES:
		for _roll: int in 400:
			var total: int = dice.randi_range(1, 260)
			var pieces: PackedInt32Array = LootDrop.split(currency, total)
			probed += 1
			var sum: int = 0
			var smallest: int = total
			for piece: int in pieces:
				sum += piece
				smallest = mini(smallest, piece)
			if sum != total or smallest < 1 or pieces.size() > Balance.LOOT_PIECES_MAX \
					or pieces.is_empty():
				_check(false, "%s x%d split into %s (sum %d, smallest %d)"
					% [currency, total, pieces, sum, smallest])
				return
	_check(probed == 1600, "the split was walked (%d)" % probed)
	# A bonus worth one coin is still one piece worth one coin.
	_check(LootDrop.split(RunState.GOLD, 1).size() == 1, "a single coin is one piece")
	_check(LootDrop.split(RunState.GOLD, 0).is_empty(), "nothing splits into nothing")
	# A recovery, a crate and a pouch land as one thing.
	for id: String in RECOVERIES:
		var pieces: PackedInt32Array = LootDrop.split(id, 40)
		_check(pieces.size() == 1 and pieces[0] == 40,
			"%s was cut into pieces: %s" % [id, pieces])


## Driven by hand through the real `_process` with the run frozen, so the only
## thing moving the piece is its own toss.
func _test_a_piece_is_thrown_lands_and_settles() -> void:
	await _clear_field_loot()
	var at := Vector2(600.0, 520.0)
	var hero: Hero = _field.hero
	hero.global_position = at
	var before: int = RunState.currency(RunState.GOLD)
	_run.process_mode = Node.PROCESS_MODE_DISABLED
	_field.spawn_loot(RunState.GOLD, 3, at)
	var pieces: Array[LootDrop] = _pieces_at(at, RunState.GOLD)
	_check(pieces.size() == 1, "three gold is one piece (%d)" % pieces.size())
	if pieces.is_empty():
		_run.process_mode = Node.PROCESS_MODE_INHERIT
		return
	var piece: LootDrop = pieces[0]
	var peak: float = 0.0
	var caught_in_the_air: bool = false
	var airborne_frames: int = 0
	var frames: int = 0
	while frames < 900 and is_instance_valid(piece) and not piece.is_taken():
		piece.call("_process", FRAME)
		frames += 1
		if not is_instance_valid(piece):
			break
		var height: float = piece.toss_height()
		peak = maxf(peak, height)
		if height > Balance.LOOT_CATCH_HEIGHT:
			airborne_frames += 1
			# The hero is standing exactly where it will land, and may not
			# have it while it is above the catch height.
			if piece.is_taken() or RunState.currency(RunState.GOLD) != before:
				caught_in_the_air = true
	# Held against the *weakest* toss the constants allow rather than a literal,
	# because the toss is drawn from the piece's own dice: a literal above the
	# weakest peak is a coin toss wearing a gate's clothes, and the first cut
	# was one (a 40 against a minimum of 25).
	var weakest_peak: float = Balance.LOOT_TOSS_LIFT_MIN * Balance.LOOT_TOSS_LIFT_MIN \
		/ (2.0 * Balance.LOOT_GRAVITY)
	_check(weakest_peak > Balance.LOOT_CATCH_HEIGHT + 4.0,
		"the weakest toss (peak %.1f) must clear the catch height (%.1f), or a hero "
			% [weakest_peak, Balance.LOOT_CATCH_HEIGHT]
			+ "standing under a kill takes a piece before it visibly leaves the corpse")
	# **Less the integrator's own shortfall** (2026-09-25). The piece steps its
	# toss a frame at a time, and a discrete step undershoots the analytic peak
	# by about the launch speed times half a frame - 2.6 units at the weakest
	# toss. The first cut allowed one, so a toss drawn near the minimum failed
	# Guard: the ninth coin toss in a gate's clothes.
	var shortfall: float = Balance.LOOT_TOSS_LIFT_MIN * FRAME * 0.5 + 0.5
	_check(peak >= weakest_peak - shortfall,
		"the piece never left the ground (peak %.1f, weakest toss %.1f less %.1f for the step)"
			% [peak, weakest_peak, shortfall])
	_check(airborne_frames > 6, "the piece was in the air for %d frames" % airborne_frames)
	_check(not caught_in_the_air, "a hero took a piece out of the air")
	_check(RunState.currency(RunState.GOLD) == before + 3,
		"the piece landed and was not taken by the hero under it (purse %+d)"
			% (RunState.currency(RunState.GOLD) - before))
	# And a piece with nobody under it comes to rest, after at least one bounce.
	var far := Vector2(-700.0, 640.0)
	hero.global_position = Vector2(4000.0, 4000.0)
	_field.spawn_loot(RunState.GOLD, 3, far)
	var resting: Array[LootDrop] = _pieces_at(far, RunState.GOLD)
	if not resting.is_empty():
		var lone: LootDrop = resting[0]
		for _frame: int in 900:
			if lone.has_settled():
				break
			lone.call("_process", FRAME)
		_check(lone.has_settled(), "the piece never settled")
		_check(lone.bounces() >= 2, "the piece settled without bouncing (%d landings)"
			% lone.bounces())
		_check(is_zero_approx(lone.toss_height()), "a settled piece is off the ground")
		# The node never leaves the plane - the picture does - so what is held
		# is that it came to rest within the furthest the constants can throw
		# it: the hardest scatter carried through every bounce's airtime (a
		# geometric series in `LOOT_BOUNCE`, the speed shedding `LOOT_BOUNCE_DRAG`
		# each landing) plus the slide the ground drag then allows. A literal
		# here was a coin toss: 160 against a hardest throw of about 200.
		var airtime: float = 2.0 * Balance.LOOT_TOSS_LIFT_MAX / Balance.LOOT_GRAVITY
		var per_bounce: float = Balance.LOOT_BOUNCE * Balance.LOOT_BOUNCE_DRAG
		var thrown: float = Balance.LOOT_SCATTER_SPEED * airtime / (1.0 - per_bounce)
		var slid: float = Balance.LOOT_SCATTER_SPEED * Balance.LOOT_SCATTER_SPEED \
			/ (2.0 * Balance.LOOT_DRAG)
		var furthest: float = thrown + slid + 1.0
		_check(lone.global_position.distance_to(far) <= furthest,
			"the node slid %.0f from where it fell, past the %.0f the constants allow"
				% [lone.global_position.distance_to(far), furthest])
	_run.process_mode = Node.PROCESS_MODE_INHERIT
	await _clear_field_loot()


func _lamps_under(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is PointLight2D:
			count += 1
		count += _lamps_under(child)
	return count


func _test_one_lamp_per_batch() -> void:
	var at := Vector2(300.0, -600.0)
	_field.spawn_loot(RunState.GOLD, 24, at)
	await get_tree().process_frame
	var pieces: Array[LootDrop] = _pieces_at(at, RunState.GOLD)
	_check(pieces.size() == 8, "twenty-four gold fell as %d pieces, not 8" % pieces.size())
	var lamps: int = 0
	var leads: int = 0
	var carried: int = 0
	for piece: LootDrop in pieces:
		lamps += _lamps_under(piece)
		leads += 1 if piece.lead else 0
		carried += piece.amount
	_check(lamps == 1, "a batch of %d pieces carries %d lights, not one" % [pieces.size(), lamps])
	_check(leads == 1, "a batch has %d leads" % leads)
	_check(carried == 24, "the batch carries %d, not 24" % carried)
	# A single small piece still has its light - it is its own batch.
	var lone_at := Vector2(-300.0, -600.0)
	_field.spawn_loot(RunState.WOOD, 2, lone_at)
	await get_tree().process_frame
	var lone: Array[LootDrop] = _pieces_at(lone_at, RunState.WOOD)
	_check(lone.size() == 1 and _lamps_under(lone[0]) == 1, "a lone piece lost its light")
	await _clear_field_loot()


func _test_a_mirror_flies_the_same_arc() -> void:
	var at := Vector2(0.0, 900.0)
	var twins: Array[LootDrop] = []
	for _twin: int in 2:
		var drop := LootDrop.new()
		drop.setup(RunState.GOLD, 1, at)
		drop.net_id = 777
		_field.add_child(drop)
		twins.append(drop)
	await get_tree().process_frame
	_check((twins[0].get("_velocity") as Vector2).is_equal_approx(twins[1].get("_velocity") as Vector2)
			and is_equal_approx(float(twins[0].get("_lift")), float(twins[1].get("_lift"))),
		"two pieces with one net id were thrown differently")
	var loose: Array[Vector2] = []
	for _piece: int in 6:
		var drop := LootDrop.new()
		drop.setup(RunState.GOLD, 1, at)
		_field.add_child(drop)
		loose.append(drop.get("_velocity") as Vector2)
	var differ: bool = false
	for index: int in range(1, loose.size()):
		if not loose[index].is_equal_approx(loose[0]):
			differ = true
	_check(differ, "six pieces with no net id all flew the same way")
	await _clear_field_loot()


func _test_a_pouch_spills_what_it_carried() -> void:
	var at := Vector2(-900.0, -200.0)
	var hero: Hero = _field.hero
	var before: Dictionary = {}
	for id: String in RunState.CURRENCIES:
		before[id] = RunState.currency(id)
	_field.spawn_loot(Balance.COIN_POUCH_ID, 40, at)
	await get_tree().process_frame
	var pouches: Array[LootDrop] = _pieces_at(at, Balance.COIN_POUCH_ID)
	_check(pouches.size() == 1, "a pouch is one thing (%d)" % pouches.size())
	if pouches.is_empty():
		return
	_check(pouches[0].steal_worth() > 0.0, "a thief would walk past a pouch")
	pouches[0].call("_collect", hero)
	await get_tree().process_frame
	var spilled: Array[LootDrop] = _pieces_at(at)
	_check(spilled.size() >= 4, "a pouch of forty spilled only %d pieces" % spilled.size())
	var carried: int = 0
	var kinds: Dictionary = {}
	for piece: LootDrop in spilled:
		carried += piece.amount
		kinds[piece.currency] = true
	_check(carried == 40, "the pouch spilled %d, not the 40 it carried" % carried)
	_check(kinds.has(RunState.GOLD) and kinds.size() >= 2,
		"a pouch spilled one currency only: %s" % [kinds.keys()])
	for piece: LootDrop in spilled:
		piece.call("_collect", hero)
		piece.call("_collect", hero)
	# Gold is paid exactly; the other three are trimmed at the purse's door by
	# `CURRENCY_YIELD_SCALE`, which is the purse's rule and not the pouch's, so
	# they are held to "paid something, and never more than was carried".
	var gold_part: int = int(round(40.0 * Balance.COIN_POUCH_GOLD_SHARE))
	var gold_gained: int = RunState.currency(RunState.GOLD) - int(before[RunState.GOLD])
	_check(gold_gained == gold_part, "the spill paid %d gold, not %d" % [gold_gained, gold_part])
	var others_gained: int = 0
	for id: String in RunState.CURRENCIES:
		if id != RunState.GOLD:
			others_gained += RunState.currency(id) - int(before[id])
	_check(others_gained > 0 and others_gained <= 40 - gold_part,
		"the spill's other currencies paid %d against %d carried" % [others_gained, 40 - gold_part])
	await _clear_field_loot()


func _test_a_quiver_pays_a_bow_and_nothing_else() -> void:
	var hero: Hero = _field.hero
	var kept_ranged: String = RunState.ranged_id
	var kept_ammo: String = RunState.ammo_id
	RunState.ranged_id = ""
	RunState.ammo_id = ""
	var stock_before: int = RunState.ammo_bulk_used()
	hero.take_quiver(5)
	_check(RunState.ammo_bulk_used() == stock_before,
		"a quiver paid a Warden with no bow")
	# And it is not even dropped for one.
	var shooter: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.role == EnemyData.Role.HOWLER \
				and breed.category == EnemyData.Category.BREED:
			shooter = breed
			break
	_check(shooter != null, "the roster has a shooter to drop a quiver")
	if shooter != null:
		var at := Vector2(900.0, 900.0)
		var body: Enemy = _field.spawn_enemy(shooter, 0, 1.0)
		body.global_position = at
		for _roll: int in 60:
			body.call("_drop_quiver")
		await get_tree().process_frame
		_check(_pieces_at(at, Balance.QUIVER_ID).is_empty(),
			"a quiver was dropped for a Warden without a bow")
		# With a bow, sixty rolls at the drop chance land some.
		var ammo_ids: Array = ContentDB.ammo_kinds.keys()
		ammo_ids.sort()
		if not ammo_ids.is_empty():
			RunState.ranged_id = "bow"
			RunState.ammo_id = String(ammo_ids[0])
			for _roll: int in 60:
				body.call("_drop_quiver")
			await get_tree().process_frame
			var quivers: Array[LootDrop] = _pieces_at(at, Balance.QUIVER_ID)
			_check(not quivers.is_empty(), "sixty shooters with a bow in play dropped no quiver")
			RunState.ammo.clear()
			var paid: int = 0
			if not quivers.is_empty():
				var shots: int = quivers[0].amount
				quivers[0].call("_collect", hero)
				paid = RunState.ammo_count(RunState.ammo_id)
				_check(paid > 0 and paid <= shots,
					"a quiver of %d arrows paid %d" % [shots, paid])
			_check(quivers.is_empty() or quivers[0].steal_worth() == 0.0,
				"a thief can steal a quiver")
		body.queue_free()
	RunState.ranged_id = kept_ranged
	RunState.ammo_id = kept_ammo
	await _clear_field_loot()


func _test_a_mana_orb_is_a_share_of_the_pool() -> void:
	var hero: Hero = _field.hero
	var pool: float = hero.mana_max()
	_check(pool > 0.0, "the Warden has a mana pool to fill")
	hero.mana = 0.0
	hero.drink_mana_orb(float(Balance.MANA_ORB_PERCENT) / 100.0)
	_check(is_equal_approx(hero.mana, pool * float(Balance.MANA_ORB_PERCENT) / 100.0),
		"an orb of %d%% filled %.1f of a %.1f pool" % [Balance.MANA_ORB_PERCENT, hero.mana, pool])
	hero.mana = pool
	hero.drink_mana_orb(0.5)
	_check(is_equal_approx(hero.mana, pool), "a mana orb overfilled the pool to %.1f of %.1f"
		% [hero.mana, pool])
	# It expires rather than paying, like the healing orb.
	var drop := LootDrop.new()
	drop.setup(Balance.MANA_ORB_ID, Balance.MANA_ORB_PERCENT, Vector2(0.0, -900.0))
	_check(drop.steal_worth() == 0.0, "a thief can steal a mana orb")
	drop.free()
	_check(Balance.MANA_ORB_BREED_CHANCE < Balance.MANA_ORB_ELITE_CHANCE
			and Balance.MANA_ORB_ELITE_CHANCE <= Balance.MANA_ORB_BOSS_CHANCE,
		"mana orb chances are not ordered breed < elite <= boss")


func _test_the_field_never_overfills() -> void:
	var hero: Hero = _field.hero
	hero.global_position = Vector2(4000.0, 4000.0)
	# Gold, because Gold is the one currency the purse does not trim at the
	# door, so paid + carried can be held to spawned exactly.
	var before: int = RunState.currency(RunState.GOLD)
	var spawned: int = 0
	var spawns: int = Balance.LOOT_FIELD_MAX + 40
	for index: int in spawns:
		var at := Vector2(-1500.0 + float(index % 50) * 20.0, -1500.0 + float(index / 50) * 20.0)
		_field.spawn_loot(RunState.GOLD, 2, at)
		spawned += 2
	await get_tree().process_frame
	var on_field: int = 0
	var carried: int = 0
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and is_instance_valid(drop) and not drop.is_taken():
			on_field += 1
			carried += drop.amount
	_check(on_field <= Balance.LOOT_FIELD_MAX,
		"the field holds %d drops against a cap of %d" % [on_field, Balance.LOOT_FIELD_MAX])
	var paid: int = RunState.currency(RunState.GOLD) - before
	_check(paid + carried == spawned,
		"making room lost something: %d paid + %d on the field != %d spawned" % [paid, carried, spawned])
	_check(paid > 0, "making room paid nothing out")
	await _clear_field_loot()


## The bonus is still a bonus: what a kill's coins are expected to add did not
## grow with the retune - more often, smaller - and an orb is still rarer than
## a coin.
func _test_the_retune_kept_the_bonus_a_bonus() -> void:
	var expected: float = Balance.LOOT_DROP_CHANCE * Balance.LOOT_BONUS_SHARE
	_check(expected <= 0.13, "a kill's expected bonus share is %.3f; the retune was meant to keep it near 0.12" % expected)
	_check(Balance.LOOT_DROP_CHANCE >= 0.5, "drops are meant to be common now (%.2f)" % Balance.LOOT_DROP_CHANCE)
	_check(Balance.HEALING_ORB_BREED_CHANCE < Balance.LOOT_DROP_CHANCE * 0.5, "an orb is rarer than a coin")


func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	if _run != null:
		_run.process_mode = Node.PROCESS_MODE_INHERIT
		_run.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	print("[loot-juice] %s - %d checks, %d failures" % [
		"PASS" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("[loot-juice] " + message)
