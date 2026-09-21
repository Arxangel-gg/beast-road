extends Node
## Every act fields the roster the table says it does.
##
## The owner's ruling of 2026-09-21: eleven acts, "8 unique enemies" in the
## first and "19" in the last, one more each act between. `Balance.ACT_UNIQUE_ENEMIES`
## is that table and this gate holds every act to it - **exactly**, because a
## pool larger than the table is a pool nobody re-read and one smaller is a
## promise nobody kept. A breed counts once for the road it walks: native
## (`enemy_ids`), elite (`elite_ids`) or veteran (`veteran_ids`).
##
## Four ways the count can be a lie, each held here:
##
## - **A body with no art.** A breed listed on a road whose frames are not on
##   disk is a breed the road can never draw, and `Enemy` falls back to nothing
##   in silence. Every id in every pool has to resolve to a base painting and
##   the idle, walk and attack frames the loaders read.
## - **A veteran from nowhere.** A veteran is a breed native to *another* road,
##   walking this one at the invader chance. One native to no road is a native
##   the count is inventing; one native to this same road is counted twice.
## - **A roster the dice never reach.** Listing a breed is not fielding it. The
##   real `WaveDirector._pick_enemy` is driven three thousand times per act and
##   what comes out is read back: natives dominate by the invader chance, every
##   veteran listed is drawn, and nothing off the list ever is.
## - **An ascent that is not an act.** The Final Ascent has ground of its own
##   since the same day; entering it has to change the region, end where the
##   summit is, and be long enough to be an act rather than a corridor.

const TAG: String = "[roster]"
const DRAWS: int = 3000
const IDLE_FRAMES: int = 3
const MOVE_FRAMES: int = 8
const ATTACK_FRAMES: int = 4

var _checks: int = 0
var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	_test_every_act_names_its_count()
	_test_every_body_has_its_art()
	_test_a_veteran_belongs_elsewhere()
	_test_the_dice_reach_the_roster()
	_test_the_ascent_is_an_act()
	_finish()


func _terrains_by_act() -> Array[TerrainData]:
	var out: Array[TerrainData] = []
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		out.append(ContentDB.terrain_for_act(act))
	return out


static func _unique_ids(terrain: TerrainData) -> Array[String]:
	var out: Array[String] = []
	for id: String in terrain.enemy_ids + terrain.elite_ids + terrain.veteran_ids:
		if not out.has(id):
			out.append(id)
	return out


func _test_every_act_names_its_count() -> void:
	var table: Array[int] = Balance.ACT_UNIQUE_ENEMIES
	_check(table.size() == Balance.FINAL_ASCENT_ACT,
		"the table names one count per act including the ascent (%d for %d acts)"
			% [table.size(), Balance.FINAL_ASCENT_ACT])
	_check(table[0] == 8, "Act I fields eight breeds (%d)" % table[0])
	_check(table[table.size() - 1] == 19, "the summit fields nineteen (%d)" % table[table.size() - 1])
	for index: int in range(1, Balance.ACT_COUNT):
		_check(table[index] == table[index - 1] + 1,
			"act %d fields one more breed than act %d (%d after %d)"
				% [index + 1, index, table[index], table[index - 1]])
	var acts: Array[TerrainData] = _terrains_by_act()
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		var terrain: TerrainData = acts[act - 1]
		if not _check(terrain != null, "act %d has a terrain" % act):
			continue
		var unique: Array[String] = _unique_ids(terrain)
		_check(unique.size() == table[act - 1],
			"act %d (%s) fields %d breeds, the table says %d: %s"
				% [act, terrain.id, unique.size(), table[act - 1], unique])
		for id: String in terrain.veteran_ids:
			_check(not terrain.enemy_ids.has(id),
				"%s is both a native and a veteran of %s" % [id, terrain.id])
		for id: String in terrain.enemy_ids + terrain.veteran_ids:
			var data: EnemyData = ContentDB.enemy(id)
			_check(data != null and data.category == EnemyData.Category.BREED,
				"%s on %s's road is a road breed" % [id, terrain.id])
		for id: String in terrain.elite_ids:
			var data: EnemyData = ContentDB.enemy(id)
			_check(data != null and data.category == EnemyData.Category.ELITE,
				"%s among %s's elites is an elite" % [id, terrain.id])
		_check(not terrain.boss_id.is_empty() and ContentDB.enemy(terrain.boss_id) != null,
			"%s names a boss that exists" % terrain.id)


func _test_every_body_has_its_art() -> void:
	var seen: Dictionary = {}
	for terrain: TerrainData in _terrains_by_act():
		if terrain == null:
			continue
		for id: String in _unique_ids(terrain):
			if seen.has(id):
				continue
			seen[id] = true
			var data: EnemyData = ContentDB.enemy(id)
			if not _check(data != null, "%s resolves to a breed" % id):
				continue
			var base: String = data.get_sprite_path()
			if not _check(ResourceLoader.exists(base), "%s has a base painting at %s" % [id, base]):
				continue
			var stem: String = base.get_basename()
			for sequence: Array in [["idle", IDLE_FRAMES], ["move", MOVE_FRAMES], ["attack", ATTACK_FRAMES]]:
				var missing: int = 0
				for index: int in range(1, int(sequence[1]) + 1):
					if not ResourceLoader.exists("%s_%s_%02d.png" % [stem, sequence[0], index]):
						missing += 1
				_check(missing == 0, "%s is missing %d of its %d %s frames"
					% [id, missing, int(sequence[1]), sequence[0]])
	print("%s %d distinct bodies walk the eleven roads" % [TAG, seen.size()])


func _test_a_veteran_belongs_elsewhere() -> void:
	var acts: Array[TerrainData] = _terrains_by_act()
	for terrain: TerrainData in acts:
		if terrain == null:
			continue
		for id: String in terrain.veteran_ids:
			var home: String = ""
			for other: TerrainData in acts:
				if other != null and other != terrain and other.enemy_ids.has(id):
					home = other.id
					break
			_check(not home.is_empty(),
				"%s, a veteran on %s, is native to no other road" % [id, terrain.id])


## The real director's draw, per act, read back against the list.
func _test_the_dice_reach_the_roster() -> void:
	var act_before: int = RunState.act
	var terrain_before: String = RunState.terrain_id
	var director := WaveDirector.new()
	var dice := RandomNumberGenerator.new()
	dice.seed = 20260921
	director._rng = dice
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		var terrain: TerrainData = ContentDB.terrain_for_act(act)
		if terrain == null:
			continue
		RunState.act = act
		RunState.terrain_id = terrain.id
		var natives: int = 0
		var veterans: int = 0
		var strangers: Array[String] = []
		var drawn: Dictionary = {}
		for _draw: int in DRAWS:
			var body: EnemyData = director._pick_enemy(false)
			if body == null:
				strangers.append("<null>")
				continue
			drawn[body.id] = true
			if terrain.enemy_ids.has(body.id):
				natives += 1
			elif terrain.veteran_ids.has(body.id):
				veterans += 1
			elif not strangers.has(body.id):
				strangers.append(body.id)
		var chance: float = Balance.WAVE_INVADER_CHANCE[clampi(act - 1, 0,
			Balance.WAVE_INVADER_CHANCE.size() - 1)]
		var native_share: float = float(natives) / float(DRAWS)
		_check(strangers.is_empty(),
			"act %d drew bodies off its own list: %s" % [act, strangers])
		_check(native_share >= 1.0 - chance - 0.05,
			"act %d natives are %.0f%% of the draw against an invader chance of %.0f%%"
				% [act, native_share * 100.0, chance * 100.0])
		if terrain.veteran_ids.is_empty() or chance <= 0.0 or act == 1:
			_check(veterans == 0, "act %d drew a veteran it does not list" % act)
		else:
			_check(float(veterans) / float(DRAWS) <= chance + 0.05,
				"act %d veterans are %.0f%% of the draw against a chance of %.0f%%"
					% [act, float(veterans) / float(DRAWS) * 100.0, chance * 100.0])
			for id: String in terrain.veteran_ids:
				_check(drawn.has(id), "act %d lists %s as a veteran and never drew it" % [act, id])
		for id: String in terrain.enemy_ids:
			_check(drawn.has(id), "act %d lists %s as a native and never drew it" % [act, id])
		var wrong_elites: Array[String] = []
		for _draw: int in 300:
			var elite: EnemyData = director._pick_enemy(true)
			if elite == null or not terrain.elite_ids.has(elite.id):
				if not wrong_elites.has(elite.id if elite != null else "<null>"):
					wrong_elites.append(elite.id if elite != null else "<null>")
		_check(wrong_elites.is_empty(), "act %d drew elites off its list: %s" % [act, wrong_elites])
	director.free()
	RunState.act = act_before
	RunState.terrain_id = terrain_before


func _test_the_ascent_is_an_act() -> void:
	RunState.reset()
	var road: String = RunState.terrain_id
	RunState.begin_final_ascent()
	var summit: TerrainData = ContentDB.terrain_for_act(Balance.FINAL_ASCENT_ACT)
	if _check(summit != null, "the ascent has a terrain of its own"):
		_check(RunState.terrain_id == summit.id,
			"entering the ascent changes the region to %s (it is %s)" % [summit.id, RunState.terrain_id])
		_check(RunState.terrain_id != road, "the summit is not the road that led to it")
		_check(summit.boss_id == "chainmaker", "the summit's boss is the Chainmaker (%s)" % summit.boss_id)
	_check(is_equal_approx(Balance.act_end_distance(Balance.FINAL_ASCENT_ACT),
			RunState.final_ascent_target()),
		"the ascent ends where the summit is (%.0f vs %.0f)"
			% [Balance.act_end_distance(Balance.FINAL_ASCENT_ACT), RunState.final_ascent_target()])
	_check(Balance.waves_in_act(Balance.FINAL_ASCENT_ACT) >= 30.0,
		"the ascent is an act, not a corridor (%.0f waves)" % Balance.waves_in_act(Balance.FINAL_ASCENT_ACT))
	_check(Balance.waves_in_act(Balance.FINAL_ASCENT_ACT) < Balance.waves_in_act(Balance.ACT_COUNT),
		"a climax is a peak and not a plateau: the ascent is shorter than the Terrace")
	RunState.reset()


func _check(condition: bool, why: String) -> bool:
	_checks += 1
	if condition:
		return true
	_failures += 1
	push_error("%s %s" % [TAG, why])
	return false


func _finish() -> void:
	for _frame: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("%s PASS - %d checks, 0 failures" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)
