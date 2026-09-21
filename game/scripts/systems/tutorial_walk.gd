class_name TutorialWalk
extends Node

## **The Walk: the guided valley, driven.**
##
## Owner brief, 2026-09-17: a tutorial "with a narrow walk through map to guide
## the player through all of the essentials of the game ... using a narration
## dialogue that helps the player understand and identify everything easily at
## the right time in the right way like the runescape tutorial world", ending
## with the Warden taking Yuri from his rest and cutting the chain. The beat
## sheet is `docs/TUTORIAL_DESIGN.md`.
##
## **It is the battlefield with a scripted director, not a second game.** Every
## system it teaches is the shipped one: the ponds are `Fishing`, the trunks are
## `Gathering`, the swing is `HeroAttack`, the build panel is the build panel.
## A bespoke tutorial scene would be a second copy of each of those to keep in
## step, and this project has paid for that four times over.
##
## **Stops are placed against the field's own landmarks rather than at authored
## cells**, and that is the decision in this file worth defending. A hand-typed
## grid coordinate is a number nobody can check without looking at the screen,
## and this project's own record is full of placement faults that every number
## agreed about and a photograph refused - a pond dug where nobody could reach
## it, a newborn fifteen hundred units off the edge, a camp on a tile with no
## route to it. So a stop names *a kind of place* - the road at a share of its
## length, a pond, a trunk, a seam, a build anchor, the town - and the Walk asks
## the live field where that is. It cannot resolve to unreachable ground,
## because the ground it resolves to is ground the field already built.
##
## **Nothing here grants anything.** The whole ledger is `TutorialGrants.award`,
## paid once, at the chain or at the skip - never per stop, because a per-stop
## reward is a partial Walk that can be farmed by quitting at the good ones.

signal finished()

## How near counts as arrived when a stop does not say.
const DEFAULT_RADIUS: float = 110.0

var field: Node = null
var card: WalkCard = null

var _stops: Array[TutorialStopData] = []
var _index: int = -1
var _at: Vector2 = Vector2.ZERO
var _done: bool = false
## What the current stop is counting, for the objectives that count.
var _tally: int = 0
## Instructions only, on a second walk.
var _replay: bool = false
var _clock: float = 0.0
## The last level seen at each anchor, so a build and an upgrade can be told
## apart on the one signal both arrive on.
var _levels: Dictionary = {}
var _chain: WalkChain = null


func _ready() -> void:
	name = "TutorialWalk"
	_replay = MetaState.tutorial_walk_done
	_load_stops()
	if card != null:
		card.skip_asked.connect(skip)
	_listen()
	set_process(true)
	_advance()


func _load_stops() -> void:
	_stops.clear()
	for value: Variant in ContentDB.tutorial_stops.values():
		var stop := value as TutorialStopData
		if stop != null:
			_stops.append(stop)
	_stops.sort_custom(func(a: TutorialStopData, b: TutorialStopData) -> bool:
		return a.order < b.order)


## Everything a stop can be finished by, wired once.
##
## Listening rather than polling, and to the signals the game already emits
## rather than to anything the Walk asks for: a stop that is finished by a
## kill is finished by the same `enemy_died` every other system reads, so a
## Walk that thinks a boar is dead and a field that does not is not a state
## this can reach.
func _listen() -> void:
	EventBus.enemy_died.connect(func(_id: String, _where: Vector2) -> void:
		_tick_objective(TutorialStopData.Done.KILLED))
	EventBus.wildlife_killed.connect(func(_id: String, _food: int, _where: Vector2,
			_rarity: int, _shiny: bool, _grave: bool) -> void:
		_tick_objective(TutorialStopData.Done.KILLED))
	EventBus.gathered.connect(func(_id: String, _amount: int) -> void:
		_tick_objective(TutorialStopData.Done.GATHERED))
	EventBus.fish_caught.connect(func(_id: String, _food: int) -> void:
		_tick_objective(TutorialStopData.Done.CAUGHT))
	EventBus.tower_changed.connect(_on_tower_changed)
	EventBus.wave_cleared.connect(func(_wave: int) -> void:
		_tick_objective(TutorialStopData.Done.WAVE_HELD))
	# The verbs (2026-09-21): a stop that tells the player to loose, cast or
	# upgrade used to finish when they arrived, which taught the words and not
	# the thing. Each is the signal the game already emits for it.
	EventBus.hero_loosed.connect(func(_from: Vector2, _direction: Vector2, _ammo: String) -> void:
		_tick_objective(TutorialStopData.Done.LOOSED))
	EventBus.spell_cast.connect(func(_spell: String, _slot: int, _at: Vector2) -> void:
		_tick_objective(TutorialStopData.Done.CAST))
	EventBus.spirit_bonded.connect(func(_key: String) -> void:
		_tick_objective(TutorialStopData.Done.BONDED))


## Built and upgraded are one signal, told apart by the level: a tower the
## Walk has not seen at this anchor is a build, one it has seen at a lower
## level is an upgrade, and a sale is neither.
func _on_tower_changed(anchor: Vector2i) -> void:
	var level: int = RunState.level_at(anchor)
	var before: int = int(_levels.get(anchor, 0))
	_levels[anchor] = level
	if level > 0 and before == 0:
		_tick_objective(TutorialStopData.Done.BUILT)
	elif level > before and before > 0:
		_tick_objective(TutorialStopData.Done.UPGRADED)

# ---------------------------------------------------------------- the stops


func current() -> TutorialStopData:
	if _index < 0 or _index >= _stops.size():
		return null
	return _stops[_index]


## Where the Warden is being sent. `Vector2.INF` when there is no stop.
func target() -> Vector2:
	return _at if current() != null else Vector2.INF


func stops() -> int:
	return _stops.size()


func index() -> int:
	return _index


## Moves to the next stop, places it, and says it.
func _advance() -> void:
	_tally = 0
	_index += 1
	var stop: TutorialStopData = current()
	if stop == null:
		_finish()
		return
	_at = _place(stop)
	_open(stop)
	EventBus.walk_stop_reached.emit(stop.id)
	if card != null:
		card.say(stop.instruction, "" if _replay else stop.aside, stop.seconds)


## What a stop needs standing or in hand before it can be finished the way it
## says (2026-09-21): a bow at the butts, a purse where a purchase is asked,
## the chain at the anchor. Run-scoped every one - the Walk's run is never
## settled - so "nothing here grants anything" still means the account.
func _open(stop: TutorialStopData) -> void:
	match stop.done:
		TutorialStopData.Done.LOOSED:
			_lend_bow()
		TutorialStopData.Done.BUILT:
			RunState.gain_every_currency(Balance.WALK_BUILD_PURSE)
		TutorialStopData.Done.UPGRADED:
			RunState.gain_every_currency(Balance.WALK_UPGRADE_PURSE)
		TutorialStopData.Done.CHAIN_CUT:
			_stand_chain()


## The starting-kit bow and a quiver of what fits it, exactly as the armoury
## hands them over - so the thing the butts teach is the thing the road sells.
func _lend_bow() -> void:
	if RunState.ranged_id.is_empty():
		var ids: Array = ContentDB.ranged_weapons.keys()
		ids.sort()
		for id: Variant in ids:
			var weapon := ContentDB.ranged_weapons[id] as RangedWeaponData
			if weapon != null and weapon.starting_kit:
				RunState.ranged_id = weapon.id
				break
	if RunState.ranged_id.is_empty():
		return
	var fits: Array[AmmoData] = RunState.ammo_for_weapon(RunState.ranged_id)
	if fits.is_empty():
		return
	var still_good: bool = false
	for kind: AmmoData in fits:
		if kind.id == RunState.ammo_id:
			still_good = true
	if not still_good:
		RunState.ammo_id = fits[0].id
	RunState.gain_ammo(RunState.ammo_id, Balance.RANGED_STARTING_SHOTS)
	EventBus.ammo_changed.emit(RunState.ammo_id, RunState.ammo_count(RunState.ammo_id))


## The chain stands a little below the town so it is not drawn under the
## town's own art, and its parting is what finishes the stop. Stood under the
## field when there is one and under the Walk when there is not, so the wiring
## exists either way and a gate can work it by hand.
func _stand_chain() -> void:
	_at += Vector2(0.0, Balance.WALK_CHAIN_STANDOFF)
	_chain = WalkChain.new()
	_chain.field = field
	var battlefield := field as Battlefield
	if battlefield != null and battlefield.entity_root != null:
		battlefield.entity_root.add_child(_chain)
	else:
		add_child(_chain)
	_chain.global_position = _at
	_chain.cut.connect(func() -> void:
		_tick_objective(TutorialStopData.Done.CHAIN_CUT))


func chain() -> WalkChain:
	return _chain


## **Where a stop is, asked of the field rather than typed into a file.**
##
## An anchor that cannot be resolved falls back to the road, which is the one
## landmark every layout has: a stop that resolved to nowhere would be a stop
## the Walk waits at for ever, and a tutorial that cannot be finished is worse
## than one that is imprecise.
func _place(stop: TutorialStopData) -> Vector2:
	var battlefield := field as Battlefield
	if battlefield == null:
		return Vector2.ZERO
	match stop.anchor:
		"pond":
			var water: PackedVector2Array = _pond_places(battlefield)
			if not water.is_empty():
				return water[0]
		"trunk", "seam":
			var nodes: PackedVector2Array = _node_places(battlefield)
			if not nodes.is_empty():
				# The seam is the furthest node from the trunk, so the two are
				# never the same place and the walk between them is a walk.
				return nodes[0] if stop.anchor == "trunk" else nodes[nodes.size() - 1]
		"build":
			var anchor: Vector2i = battlefield.free_anchor_near(Balance.WALK_LANE, 4)
			if anchor != Vector2i(-1, -1) and battlefield.grid != null:
				return battlefield.grid.tile_to_world(anchor)
		"town":
			return battlefield.town_position()
	return _on_the_road(battlefield, stop.along)


## A share of the way along the valley's road: 0 is the far end the Warden
## starts from, 1 is the town.
func _on_the_road(battlefield: Battlefield, along: float) -> Vector2:
	var grid: BattleGrid = battlefield.grid
	if grid == null or grid.lane_paths.size() <= Balance.WALK_LANE:
		return battlefield.town_position()
	var path: PackedVector2Array = grid.lane_paths[Balance.WALK_LANE]
	if path.is_empty():
		return battlefield.town_position()
	# The path runs from the spawn to the town, so a share of it is a share of
	# the road - and the last point is the gate rather than the middle of the
	# town, which is what makes the final stops read as arriving.
	var step: int = clampi(int(round(clampf(along, 0.0, 1.0)
		* float(path.size() - 1))), 0, path.size() - 1)
	return path[step]


func _pond_places(battlefield: Battlefield) -> PackedVector2Array:
	var water: Fishing = battlefield.ponds()
	return water.pond_positions() if water != null else PackedVector2Array()


func _node_places(battlefield: Battlefield) -> PackedVector2Array:
	var seams: Gathering = battlefield.gathering()
	return seams.node_positions() if seams != null else PackedVector2Array()


# ---------------------------------------------------------- finishing a stop


func _process(delta: float) -> void:
	_clock += delta
	var stop: TutorialStopData = current()
	if stop == null or _done:
		return
	if stop.done != TutorialStopData.Done.ENTERED:
		return
	if _warden_is_here(stop):
		_stop_done()


func _warden_is_here(stop: TutorialStopData) -> bool:
	var battlefield := field as Battlefield
	if battlefield == null:
		return false
	for who: Hero in battlefield.heroes():
		if who != null and is_instance_valid(who):
			var reach: float = stop.radius if stop.radius > 0.0 else DEFAULT_RADIUS
			if who.global_position.distance_to(_at) <= reach:
				return true
	return false


## One of the things a stop can be finished by happened. Counted rather than
## taken, because a stop may want three arrows rather than one.
func _tick_objective(kind: int) -> void:
	var stop: TutorialStopData = current()
	if stop == null or _done or stop.done != kind:
		return
	_tally += 1
	if _tally >= maxi(stop.count, 1):
		_stop_done()


func _stop_done() -> void:
	var stop: TutorialStopData = current()
	if stop == null:
		return
	EventBus.walk_stop_done.emit(stop.id)
	if card != null and not stop.instruction_two.strip_edges().is_empty():
		card.say(stop.instruction_two, "", stop.seconds)
	_advance()


## For the gate, and for the chain: finishes whatever stop is open.
func force_current_done() -> void:
	if current() != null:
		_stop_done()


# ------------------------------------------------------------------ the end


## The chain. The last stop, and the one beat that is not a lesson.
func _finish() -> void:
	if _done:
		return
	_done = true
	EventBus.walk_chain_cut.emit()
	var given: Dictionary = TutorialGrants.award()
	# The premise is not told twice in five minutes: a walker has seen it, so
	# the four-panel intro is marked seen rather than shown before Act I.
	MetaState.story_intro_seen = true
	MetaState.save_game()
	finished.emit()
	if card != null:
		card.say(_parting_words(given), "", 12.0)


## **Leaves the valley without finishing it, and is paid exactly the same.**
##
## Any other split makes skipping a mechanical penalty, which makes the
## tutorial a tax rather than a gift - and this codebase holds one bound over
## every optional system: opting out must not cost power. A walker and a
## skipper stand on the first frame of Act I identical.
func skip() -> void:
	if _done:
		return
	_done = true
	TutorialGrants.award()
	MetaState.story_intro_seen = true
	MetaState.save_game()
	finished.emit()
	GameDirector.end_walk(false)


func _parting_words(given: Dictionary) -> String:
	var said: PackedStringArray = []
	if not String(given.get("blueprint", "")).is_empty():
		said.append("the smith's plan")
	if not String(given.get("bond", "")).is_empty():
		said.append("the rabbit")
	if not String(given.get("fish", "")).is_empty():
		said.append("one fish")
	if not (given.get("materials", {}) as Dictionary).is_empty():
		said.append("what you cut and broke")
	if said.is_empty():
		return "The chain is off. He is walking. Go with him."
	return ("The chain is off. He is walking, and you are taking %s with you."
		% " and ".join(said))
