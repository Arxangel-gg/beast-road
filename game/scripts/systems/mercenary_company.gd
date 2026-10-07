class_name MercenaryCompany
extends Node

## **The company on the road** (owner, 2026-10-07; `docs/MERCENARIES_2026-10-07.md`).
## Stands each mercenary `GameDirector._muster` paid for on its seat, as a
## partner's body with `MercenaryInput` for hands, lets it think every physics
## frame, and carries it off the road after its last wound to a bed at the Hold.
##
## A child of the battlefield, so a raid's freeze holds the company with the
## field (working rule 8) and a field torn down takes it with it.

var field: Battlefield = null
var _bodies: Dictionary = {}
var _minds: Dictionary = {}


func _ready() -> void:
	name = "MercenaryCompany"
	EventBus.mercenary_fell.connect(_on_fell)
	EventBus.phase_changed.connect(_on_phase_changed)
	_muster.call_deferred()


## The body of one mercenary on this road, or null.
func body(uid: String) -> Hero:
	var found: Variant = _bodies.get(uid, null)
	return found as Hero if found != null and is_instance_valid(found) else null


## Its mind.
func mind(uid: String) -> MercenaryInput:
	return _minds.get(uid, null) as MercenaryInput


## Every mercenary body standing on this road.
func bodies() -> Array[Hero]:
	var out: Array[Hero] = []
	for uid: Variant in _bodies:
		var found: Hero = body(String(uid))
		if found != null:
			out.append(found)
	return out


func _muster() -> void:
	if field == null:
		return
	for row: Dictionary in RunState.company:
		if not bool(row.get("out", false)):
			_stand(row)
	if not RunState.company_stayed_home.is_empty():
		EventBus.company_news.emit("%s stayed home: the contract could not be paid."
			% ", ".join(RunState.company_stayed_home))


## One mercenary on its seat.
func _stand(row: Dictionary) -> Hero:
	var uid: String = String(row.get("uid", ""))
	var hired: Dictionary = MetaState.mercenary(uid)
	if hired.is_empty() or field == null or field.entity_root == null:
		return null
	var scene: PackedScene = load("res://scenes/hero/hero.tscn") as PackedScene
	var hero := scene.instantiate() as Hero if scene != null else null
	if hero == null:
		return null
	var hands := MercenaryInput.new(hero, uid)
	hands.master = field.hero
	hands.field = field
	# Before the tree, so `Hero._ready` never builds a keyboard for it.
	hero.input = hands
	hero.mercenary_uid = uid
	hero.name = "Mercenary%d" % int(row.get("slot", 2))
	hero.field = field
	hero.party_slot = int(row.get("slot", 2))
	hero.bounds_extent = Vector2.ONE * BattleGrid.play_extent()
	hero.spawn_point = CoopHeroes.spawn_for_slot(hero.party_slot, field.town_position())
	hero.position = hero.spawn_point
	field.entity_root.add_child(hero)
	hero.wear_sheet(Mercenaries.sheet_row(hired))
	hero.wear_look(hired.get("look", []))
	hero.wear_gear(Mercenaries.worn_kinds(hired))
	hero.set_present(true)
	# Never the hero group: that group is "whose health the HUD shows".
	hero.set_active(false)
	hero.set_nameplate(String(hired.get("name", "")))
	hands.command(MercenaryInput.Order.FOLLOW)
	_bodies[uid] = hero
	_minds[uid] = hands
	return hero


func _physics_process(delta: float) -> void:
	for uid: Variant in _minds:
		var found: Hero = body(String(uid))
		var hands := _minds[uid] as MercenaryInput
		if found != null and hands != null:
			hands.think(delta)


## **It builds in the breather** (owner, 2026-10-07: mercenaries *"place their own
## towers and traps"*). A moment into Preparation, so the player sees it happen,
## each mercenary on its feet makes a few purchases from its own purse through
## the battlefield's payer doors - every rule a purchase obeys is the Warden's
## rule, only the purse differs.
func _on_phase_changed(phase: int, _previous: int) -> void:
	if phase != RunState.Phase.PREPARATION or field == null or not is_inside_tree():
		return
	await get_tree().create_timer(Balance.MERC_BUILD_DELAY, false).timeout
	if field == null or RunState.phase != RunState.Phase.PREPARATION:
		return
	for row: Dictionary in RunState.live_mercenaries():
		spend(String(row.get("uid", "")))


## One mercenary's shopping: raise its weakest tower, else build a new one on
## its own road, else lay a trap there. Returns what it bought, as words.
func spend(uid: String) -> Array[String]:
	var bought: Array[String] = []
	var me: Hero = body(uid)
	if me == null or field == null or not RunState.can_build_now():
		return bought
	var lane: int = _lane_of(me)
	for _purchase: int in Balance.MERC_BUILDS_PER_BREATHER:
		var raised: Vector2i = _weakest_owned(uid)
		if raised != Vector2i(-1, -1) and field.upgrade_for(uid, raised).is_empty():
			bought.append("raise")
			continue
		var tower: TowerData = _dearest_affordable(uid)
		if tower != null:
			var anchor: Vector2i = field.free_anchor_near(lane, 4)
			if field.placement_problem(anchor).is_empty() and field.build_for(uid, anchor, tower).is_empty():
				bought.append(tower.id)
				EventBus.company_news.emit("%s raises a %s on its road." % [
					String(RunState.company_row(uid).get("name", "")), tower.display_name])
				continue
		var trap: TrapData = _affordable_trap(uid)
		if trap != null and _lay_a_trap(uid, me.global_position, trap):
			bought.append(trap.id)
			continue
		break
	return bought


## The road it stands nearest.
func _lane_of(me: Hero) -> int:
	var best: int = 0
	var best_dot: float = -INF
	var from_town: Vector2 = (me.global_position - field.town_position()).normalized()
	for lane: int in Balance.LANE_COUNT:
		var along: float = from_town.dot(Battlefield.lane_vector(lane).normalized())
		if along > best_dot:
			best_dot = along
			best = lane
	return best


## Its tower at the lowest level that can still rise, or (-1, -1).
func _weakest_owned(uid: String) -> Vector2i:
	var best := Vector2i(-1, -1)
	var lowest: int = 1 << 30
	for key: Variant in RunState.tower_owners:
		if String(RunState.tower_owners[key]) != uid:
			continue
		var anchor: Vector2i = key
		var level: int = RunState.level_at(anchor)
		if level < mini(Balance.TOWER_MAX_LEVEL, RunState.tower_level_cap()) and level < lowest:
			if RunState.mercenary_can_afford(uid, {RunState.GOLD: Battlefield.upgrade_cost_of(level)}):
				lowest = level
				best = anchor
	return best


## The dearest tower the Warden has unlocked that its purse pays for at par -
## the strongest answer it can afford, which is how a player with money spends it.
func _dearest_affordable(uid: String) -> TowerData:
	var best: TowerData = null
	var best_price: int = -1
	for tower: TowerData in ContentDB.unlocked_base_towers():
		if tower == null or tower.is_well() or tower.is_support():
			continue
		var cost: Dictionary = Battlefield.cost_of(tower)
		var price: int = RunState.par_total(cost)
		if RunState.mercenary_can_afford(uid, cost) and price > best_price:
			best = tower
			best_price = price
	return best


func _affordable_trap(uid: String) -> TrapData:
	for value: Variant in ContentDB.traps.values():
		var trap := value as TrapData
		if trap != null and RunState.mercenary_can_afford(uid, trap.cost):
			return trap
	return null


## A trap on the road nearest it, tried outward ring by ring.
func _lay_a_trap(uid: String, near: Vector2, trap: TrapData) -> bool:
	var origin: Vector2i = BattleGrid.world_to_tile(near)
	for ring: int in Balance.MERC_TRAP_SEARCH:
		for dx: int in range(-ring, ring + 1):
			for dy: int in range(-ring, ring + 1):
				if absi(dx) != ring and absi(dy) != ring:
					continue
				if field.trap_for(uid, origin + Vector2i(dx, dy), trap).is_empty():
					return true
	return false


## Its last wound: it lies where it fell for a moment, then is carried off the
## road and put to bed at the inn - now, not when the run settles, because it
## has left the road whatever the run does next.
func _on_fell(uid: String, _at: Vector2, wounds_left: int) -> void:
	if wounds_left > 0:
		var name_now: String = String(RunState.company_row(uid).get("name", ""))
		EventBus.company_news.emit("%s is down  ·  %d %s left" % [name_now, wounds_left,
			"wound" if wounds_left == 1 else "wounds"])
		return
	carry_off(uid, Balance.MERC_CARRY_SECONDS)


## Takes a mercenary off the road and to a bed. `after` lets it lie a moment.
func carry_off(uid: String, after: float = 0.0) -> void:
	var gone: Hero = body(uid)
	var name_now: String = String(RunState.company_row(uid).get("name", "A mercenary"))
	if after > 0.0 and is_inside_tree():
		await get_tree().create_timer(after, false).timeout
	gone = body(uid)
	if gone != null:
		gone.set_present(false)
		gone.queue_free()
	_bodies.erase(uid)
	_minds.erase(uid)
	var row: Dictionary = RunState.company_row(uid)
	if not row.is_empty():
		row["out"] = true
	MetaState.send_mercenary_to_bed(uid)
	EventBus.company_news.emit("%s is carried back to the Hold, to a bed at the inn." % name_now)
	EventBus.mercenary_carried_off.emit(uid)
