class_name ActStart

## Starting a fresh road at an act you have already reached.
##
## **Owner ruling, 2026-09-15.** Reaching an act unlocks it permanently, and a
## fresh road there opens on an authored baseline whose *shape* the player
## chooses - four doctrines - and whose *size* they do not.
##
## **This is not the expedition, and the difference is the whole point.** An
## expedition is *your* road, banked at a crossroad and picked up where you left
## it, damage and all. An act start is a *new* road that happens to begin
## further along: a different seed, a different world, an untouched wall. The two
## are separate doors in the Hold and neither consumes the other.
##
## **Why it exists.** With a campaign of 622 waves, a wiped expedition otherwise
## costs five hours of walking to stand where you were standing, and gear is what
## the player comes back for (2026-09-01) - so being unable to go to the act that
## drops what you are hunting makes the hunt a formality.
##
## **Nothing here is a new power scale, and nothing here persists.** The budget
## buys towers at the prices the road charges, through the same `try_build` a
## player's own build goes through; what it does not spend is handed over as
## Gold. `MetaState` gains nothing: which acts are open is *derived* from
## `best_distance`, a run statistic working rule 7 already sanctions, so there is
## no new save key and no migration.

## How many tower spots the outfit will try before it gives up on a lane. A
## board is four lanes wide and the pockets hold about a dozen apiece.
const SEARCH_RINGS: int = 9

## The most emplacements an outfit will ever stand up, whatever the budget says.
## The board itself is the real ceiling - `try_build` refuses a spot that is not
## free - and this only stops a runaway loop on a malformed doctrine.
const MAX_PLACEMENTS: int = 80


## **The furthest act this account has ever stood in.**
##
## Derived from `best_distance` rather than stored, which is what keeps this out
## of working rule 7: the furthest distance walked is a run statistic the save
## already keeps, and the act it falls in is arithmetic. A new key would have
## been a second answer to a question the save can already answer.
static func furthest_act() -> int:
	var reached: int = 1
	for act: int in range(1, Balance.ACT_COUNT + 1):
		# Standing anywhere inside an act counts as having reached it: the act
		# opened, its region was drawn and its boss was walked toward.
		if MetaState.best_distance >= Balance.act_start_distance(act):
			reached = act
	return clampi(reached, 1, Balance.ACT_COUNT)


## Whether a road may be started at this act.
static func may_start(act: int) -> bool:
	return act >= 1 and act <= furthest_act()


## What a Warden who walked to this act would be holding, in Gold.
static func budget_for(act: int) -> int:
	var index: int = clampi(act - 1, 0, Balance.ACT_START_BUDGET.size() - 1)
	return maxi(Balance.ACT_START_BUDGET[index], 0)


## **Put the road down at the act's door.**
##
## Called after `RunState.reset()` and before the field is built, exactly where
## `Expedition.apply` is called, because both answer the same question: what was
## already true when this battlefield came up. The outfit itself happens later -
## a tower needs a field to stand on.
static func begin(act: int, doctrine_id: String) -> bool:
	if not may_start(act):
		return false
	var doctrine: DoctrineData = ContentDB.doctrine(doctrine_id)
	if doctrine == null:
		return false
	RunState.act = clampi(act, 1, Balance.ACT_COUNT)
	RunState.distance_travelled = Balance.act_start_distance(RunState.act)
	# The wave number a walked campaign would be on. Read off the road rather
	# than stored, so it moves with `ACT_ROAD_DISTANCE` instead of going stale.
	RunState.wave_number = maxi(int(round(
		RunState.distance_travelled / Balance.WAVE_ROAD_DISTANCE)), 0)
	var terrain: TerrainData = ContentDB.terrain_for_act(RunState.act)
	if terrain != null:
		RunState.terrain_id = terrain.id
	var budget: int = budget_for(RunState.act)
	# **The whole budget is granted, then spent.** Handing the purse over first
	# and letting the doctrine buy from it is what makes the board a board the
	# road could have produced - every tower is paid for at the price a player
	# would have paid, by the function a player's own build calls.
	RunState.currencies[RunState.GOLD] = budget
	# **The other three come off the road, because that is where they come
	# from.** Wood, Food and Stone trickle in with distance rather than with
	# kills, so a share of the Gold budget would have been a share of a number
	# they have nothing to do with. This is what the road to that act would have
	# paid, kept in part - a walked Warden spent most of theirs on repairs and
	# tending on the way.
	var trickled: float = RunState.distance_travelled * Balance.RESOURCE_PER_DISTANCE
	RunState.currencies[RunState.WOOD] = int(round(
		trickled * Balance.ACT_START_WOOD_SHARE))
	RunState.currencies[RunState.FOOD] = int(round(
		trickled * Balance.ACT_START_FOOD_SHARE))
	RunState.currencies[RunState.STONE] = int(round(
		trickled * Balance.ACT_START_STONE_SHARE))
	# **The wall arrives whole**, unlike an expedition's. Nobody fought for this
	# board, so there is no attrition to preserve and a hurt wall would be a
	# worse opening bought with no decision.
	RunState.town_hp = RunState.town_max_hp * Balance.ACT_START_WALL
	# Read once and erased by the battlefield, the way `tower_health_restore` is.
	RunState.pending_outfit = {"doctrine": doctrine.id, "budget": budget}
	return true


## **Spend the budget on a board, through the doors a player uses.**
##
## Driven by the battlefield once it is standing and the phase is Preparation.
## Returns what it did, for the gate and for the screen.
static func outfit(field: Battlefield) -> Dictionary:
	var pending: Dictionary = RunState.pending_outfit
	if pending.is_empty() or field == null:
		return {}
	# Erased first. A second call must be a no-op however this is reached - a
	# re-sync, a rebuilt field, a guest's welcome - because a board built twice
	# is a doctrine worth twice as much.
	RunState.pending_outfit = {}
	var doctrine: DoctrineData = ContentDB.doctrine(String(pending.get("doctrine", "")))
	if doctrine == null:
		return {}
	var budget: int = int(pending.get("budget", 0))
	if budget <= 0:
		return {}

	var choices: Array[TowerData] = _preferred_towers(doctrine, doctrine.breadth)
	if choices.is_empty():
		return {}
	var board: float = float(budget) * clampf(doctrine.board_share, 0.0, 1.0)
	# **How many emplacements, not how much Gold.** See `ACT_START_BOARD_MIN`:
	# a share of the purse buys a different board depending on what the doctrine
	# favours, and the card promises a number of walls rather than a sum.
	var span: int = maxi(Balance.ACT_START_BOARD_MAX - Balance.ACT_START_BOARD_MIN, 0)
	var wanted: int = Balance.ACT_START_BOARD_MIN + int(round(
		float(span) * clampf(doctrine.breadth, 0.0, 1.0)))

	var built: Array[Vector2i] = []
	var spent: int = 0
	# --- Breadth: stand up that many, while the board's share lasts -----------
	var lane: int = 0
	while built.size() < mini(wanted, MAX_PLACEMENTS) and spent < int(board):
		var pick: TowerData = choices[built.size() % choices.size()]
		var anchor: Vector2i = field.free_anchor_near(lane, SEARCH_RINGS)
		lane = (lane + 1) % maxi(Balance.LANE_COUNT, 1)
		if not field.placement_problem(anchor).is_empty():
			# Every lane refused in one pass round the board means the board is
			# full, which is a legitimate end rather than a fault.
			if lane == 0:
				break
			continue
		var before: int = RunState.currency(RunState.GOLD)
		if not field.try_build(anchor, pick).is_empty():
			if lane == 0:
				break
			continue
		spent += maxi(before - RunState.currency(RunState.GOLD), 0)
		built.append(anchor)

	# --- Depth: take what is standing up the ladder with the rest -------------
	var levels: int = 0
	var guard: int = 0
	while spent < int(board) and not built.is_empty() and guard < MAX_PLACEMENTS * 12:
		guard += 1
		var anchor: Vector2i = built[guard % built.size()]
		var before: int = RunState.currency(RunState.GOLD)
		if not field.try_upgrade(anchor).is_empty():
			# Every emplacement refusing means they are all at the cap the Forge
			# allows, and the remainder stays in the purse.
			if guard % built.size() == built.size() - 1 and levels == 0:
				break
			levels = 0
			continue
		spent += maxi(before - RunState.currency(RunState.GOLD), 0)
		levels += 1

	return {
		"doctrine": doctrine.id,
		"budget": budget,
		"spent": spent,
		"towers": built.size(),
		"spare": RunState.currency(RunState.GOLD),
	}


## The towers this doctrine reaches for, best match first.
##
## Drawn from what the account has actually unlocked, so an outfit can never
## stand up a tower the player has not bought - the board it leaves has to be a
## board they could have built themselves.
static func _preferred_towers(doctrine: DoctrineData,
		breadth: float) -> Array[TowerData]:
	var element: int = doctrine.element_index()
	var role: int = doctrine.role_index()
	var scored: Array[TowerData] = []
	for tower: TowerData in ContentDB.unlocked_base_towers():
		if tower == null or tower.is_combination:
			continue
		scored.append(tower)
	# **Cost breaks the tie, and which way depends on what the doctrine wants.**
	#
	# Sorting on the preference alone let the *element* decide how many
	# emplacements a budget bought: Bulwark favours the Earth wardens, which are
	# dear, so the widest doctrine in the game stood up a narrower board than the
	# balanced one. The number was obeyed and the card was a lie. A doctrine that
	# wants breadth reaches for the cheapest of what it favours; one that wants
	# depth reaches for the dearest, and spends the rest taking it up the ladder.
	var wide: bool = breadth >= 0.5
	scored.sort_custom(func(a: TowerData, b: TowerData) -> bool:
		var left: int = _score(a, element, role)
		var right: int = _score(b, element, role)
		if left != right:
			return left > right
		return a.build_cost() < b.build_cost() if wide \
			else a.build_cost() > b.build_cost())
	return scored


static func _score(tower: TowerData, element: int, role: int) -> int:
	var points: int = 0
	if element >= 0 and int(tower.element) == element:
		points += 2
	if role >= 0 and int(tower.role) == role:
		points += 1
	return points
