extends Node

## "Rebuild last board" is a shopping list and never a purse.
##
##   godot --headless --path game res://tools/build_template_check.tscn
##
## `docs/ROAD_TO_1_0.md` §7.2 asked for it: forty emplacements placed one click
## at a time are forty clicks the player has already made, over a campaign that
## is ten evenings long.
##
## **The ways this goes wrong, hardest first:**
##
## - **It lands nowhere.** `BattleGrid._init` rolls `camp_side` from the layout
##   seed and the outskirts it lays differ with it, so an anchor stored as an
##   absolute tile can be open ground on one run and a road on the next - and an
##   unbuilt tower looks exactly like open ground, so the failure is silent.
##   Rows are core-relative, and the gate replays a board on a **different
##   seed** rather than the one it recorded on.
## - **It gives something away.** Every emplacement must be bought through the
##   one door at the price the road charges, so the purse is read before and
##   after and compared against what the same two functions quoted.
## - **It becomes a second expedition.** A template is a *shape*: a place, a
##   kind, a level, a path and a priority. `balance_test` holds the row keys;
##   this holds that replaying one moves no account state at all.
## - **It refuses in silence.** A board that ran out of Gold must say so.

var _failures: int = 0
var _checks: int = 0
var _field: Battlefield = null
var _run: Run = null
## Which tests reached their own last line - a GDScript runtime error stops the
## function it is in and nothing else, so a test that aborts halfway reads
## exactly like one that passed.
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	await _stand_a_field(20260922)
	await _test_a_board_is_recorded_core_relative()
	await _test_it_lands_on_a_different_seed()
	await _test_it_buys_at_the_road_s_prices()
	await _test_it_says_what_it_could_not_place()
	_test_a_malformed_template_is_dropped()
	for stage: String in ["recorded", "lands", "bought", "refused", "malformed"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check "
				+ "it had not made yet is a check nobody made") % stage)
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	MetaState.resume_saves()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 16:
		await get_tree().process_frame
	if _failures == 0:
		print(("[template] PASS - %d checks: recorded core-relative, landing on "
			+ "a seed it never saw, bought at the road's own prices, and saying "
			+ "what it could not place") % _checks)
	else:
		push_error("[template] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[template] " + why)


func _stand_a_field(seed_value: int) -> void:
	if _run != null and is_instance_valid(_run):
		_run.queue_free()
		for _frame: int in 8:
			await get_tree().process_frame
	RunState.reset(false, seed_value)
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.build_grace_until_msec = 0
	RunState.gain_every_currency(999999)


## An ordinary tower this account can build.
func _a_tower() -> TowerData:
	for one: TowerData in ContentDB.unlocked_base_towers():
		if one != null and not one.is_combination and not one.is_well():
			return one
	return null


## Stands a small board up by hand, the way a player does.
func _build_a_board(count: int) -> int:
	var kind: TowerData = _a_tower()
	var made: int = 0
	var lane: int = 0
	while made < count:
		var anchor: Vector2i = _field.free_anchor_near(lane, 8)
		lane = (lane + 1) % maxi(Balance.LANE_COUNT, 1)
		if anchor == Vector2i.ZERO or not _field.placement_problem(anchor).is_empty():
			if lane == 0:
				break
			continue
		if not _field.try_build(anchor, kind).is_empty():
			break
		made += 1
	return made


## **Core-relative.** Read off the composed rows rather than off the constants,
## because the whole point is that the number stored is not the anchor.
func _test_a_board_is_recorded_core_relative() -> void:
	var made: int = _build_a_board(4)
	_check(made >= 2, "the harness could only stand up %d towers" % made)
	var shape: Dictionary = BuildTemplate.compose(_field)
	var rows: Array = BuildTemplate.rows_of(shape)
	_check(rows.size() == made,
		"composed %d rows from a board of %d" % [rows.size(), made])
	for entry: Variant in rows:
		var row: Dictionary = entry as Dictionary
		_check(int(row["cx"]) >= 0 and int(row["cx"]) < BattleGrid.CORE_SIZE
			and int(row["cy"]) >= 0 and int(row["cy"]) < BattleGrid.CORE_SIZE,
			("a row is stored at (%d, %d), which is outside the authored core - "
				+ "an absolute tile means a different place on the next seed")
				% [int(row["cx"]), int(row["cy"])])
		_check(RunState.towers.has(BuildTemplate.anchor_of(row)),
			"a row does not resolve back to the tower it was taken from")
		for key: Variant in row.keys():
			_check(String(key) in BuildTemplate.ROW_KEYS,
				("a row carries \"%s\" - a template is a shape, never a "
					+ "resource") % key)
	MetaState.build_template = shape
	_reached["recorded"] = true


## **On a seed it has never seen**, which is the whole hazard: the outskirts
## differ with `camp_side` and a board replayed at absolute tiles lands on
## ground the run may not have.
func _test_it_lands_on_a_different_seed() -> void:
	var shape: Dictionary = MetaState.build_template
	var wanted: int = BuildTemplate.rows_of(shape).size()
	# A seed whose grid mirrors the recording one, so the outskirts differ.
	var other: int = _a_mirrored_seed(20260922)
	_check(other != 0, "no seed with the opposite camp side was found")
	await _stand_a_field(other if other != 0 else 20260101)
	var landed: Dictionary = BuildTemplate.apply(_field, shape)
	_check(int(landed.get("built", 0)) == wanted,
		("only %d of %d emplacements landed on a seed the board was not "
			+ "recorded on: %s") % [int(landed.get("built", 0)), wanted,
			str(landed.get("refused", []))])
	_check(RunState.towers.size() == wanted,
		"the field holds %d towers against %d rows"
			% [RunState.towers.size(), wanted])
	for entry: Variant in BuildTemplate.rows_of(shape):
		var row: Dictionary = entry as Dictionary
		var anchor: Vector2i = BuildTemplate.anchor_of(row)
		var built: TowerData = RunState.tower_at(anchor)
		_check(built != null and built.id == String(row["kind"]),
			("(%d, %d) holds %s rather than the recorded %s")
				% [int(row["cx"]), int(row["cy"]),
					"nothing" if built == null else built.id, row["kind"]])
	_reached["lands"] = true


## A seed whose grid lays its outskirts the other way round.
func _a_mirrored_seed(from: int) -> int:
	var mine: int = BattleGrid.new(from).camp_side
	for offset: int in range(1, 60):
		var candidate: int = from + offset
		if BattleGrid.new(candidate).camp_side != mine:
			return candidate
	return 0


## **At the road's own prices.** Quoted and charged through the same two
## functions, so a template cannot be a discount.
func _test_it_buys_at_the_road_s_prices() -> void:
	await _stand_a_field(20260923)
	var kind: TowerData = _a_tower()
	var anchor: Vector2i = _field.free_anchor_near(0, 8)
	_check(_field.try_build(anchor, kind).is_empty(), "the harness cannot build")
	for _step: int in 2:
		_field.try_upgrade(anchor)
	var shape: Dictionary = BuildTemplate.compose(_field)
	var quoted: int = BuildTemplate.quote(shape)
	_check(quoted > 0, "a board of one levelled tower quoted %d Gold" % quoted)

	await _stand_a_field(20260924)
	RunState.gain_every_currency(999999)
	var before: int = RunState.currency(RunState.GOLD)
	BuildTemplate.apply(_field, shape)
	var spent: int = before - RunState.currency(RunState.GOLD)
	_check(spent == quoted,
		("the board quoted %d Gold and took %d - the button and the purchase "
			+ "must read the same two functions") % [quoted, spent])
	# And the account is exactly where it was: a template moves a run and never
	# a save.
	var account: String = MetaState.serialized_save()
	BuildTemplate.apply(_field, shape)
	_check(MetaState.serialized_save() == account,
		"replaying a board changed the account")
	_reached["bought"] = true


## **It says what it could not place.** A board that ran out of Gold in silence
## is a button that did half of what it promised and told nobody.
func _test_it_says_what_it_could_not_place() -> void:
	await _stand_a_field(20260925)
	var made: int = _build_a_board(3)
	var shape: Dictionary = BuildTemplate.compose(_field)
	_check(made >= 2 and not shape.is_empty(), "the harness needs a board to copy")
	await _stand_a_field(20260926)
	# An empty purse: every row must be refused, by name, rather than skipped.
	for currency: String in [RunState.GOLD, RunState.WOOD, RunState.FOOD,
			RunState.STONE]:
		RunState.spend_cost({currency: RunState.currency(currency)})
	var landed: Dictionary = BuildTemplate.apply(_field, shape)
	_check(int(landed.get("built", 0)) == 0,
		"a board was stood up with an empty purse (%d towers)"
			% int(landed.get("built", 0)))
	var refused: Array = landed.get("refused", []) as Array
	_check(refused.size() >= 1,
		"nothing could be paid for and the board said nothing at all")
	if refused.size() >= 1:
		_check(String(refused[0]).length() > 4,
			"a refusal must be a sentence, got \"%s\"" % String(refused[0]))
	_reached["refused"] = true


## A row naming a tower this build does not have is dropped, not trusted - the
## rule `Expedition.is_readable` and `_read_pen` already follow.
func _test_a_malformed_template_is_dropped() -> void:
	_check(not BuildTemplate.is_readable({}), "an empty template is not readable")
	_check(not BuildTemplate.is_readable({"rows": []}), "nor is an empty list")
	_check(not BuildTemplate.is_readable({"rows": [
		{"cx": 4, "cy": 4, "kind": "no_such_tower", "level": 1}]}),
		"a template naming a tower this build does not have must be dropped")
	var mixed: Dictionary = {"rows": [
		{"cx": 4, "cy": 4, "kind": "no_such_tower", "level": 1},
		{"cx": 6, "cy": 6, "kind": _a_tower().id, "level": 1},
		{"cx": -99, "cy": 6, "kind": _a_tower().id, "level": 1},
	]}
	_check(BuildTemplate.rows_of(mixed).size() == 1,
		("a template of three rows - one unknown tower, one good, one off the "
			+ "core - read back %d") % BuildTemplate.rows_of(mixed).size())
	_reached["malformed"] = true
