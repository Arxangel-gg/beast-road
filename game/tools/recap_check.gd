extends Node

## The build recap and its title (owner request, 2026-09-02).
##
## "That screenshot is inherently shareable" - so the thing it names has to be
## the thing that happened. Five promises:
##
## 1. **Titles are content.** Adding one is adding a `.tres`.
## 2. **No run ends unnamed.** Every element-and-axis a run can finish in
##    resolves to a title, including the ones nobody authored an element for.
## 3. **The element is the dominant one, and a tie is not one.** A player with
##    two Fire towers and two Water towers did not build a Fire run; calling it
##    one is the recap flattering them instead of describing them.
## 4. **The axis is ordered, not scored**, and the threshold means "enough of
##    them to be the plan" rather than "any at all".
## 5. **It reads, never records.** The recap is derived from `RunState` and
##    `MetaState` at the moment it is asked, so it cannot drift from the run it
##    describes - which is what a second set of counters would eventually do.

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	RunState.reset(false, 20260902)
	_test_titles_are_content()
	_test_no_run_ends_unnamed()
	_test_the_element_is_the_dominant_one()
	_test_the_axis_is_ordered()
	_test_the_recap_reads_the_run()
	_finish()


## 1.
func _test_titles_are_content() -> void:
	var titles: Dictionary = ContentDB.run_titles
	_check(titles.size() >= 6,
		"there must be titles to give, found %d" % titles.size())
	for value: Variant in titles.values():
		var title := value as RunTitleData
		_check(title != null, "every run title must load as RunTitleData")
		if title == null:
			continue
		_check(not title.display_name.is_empty(),
			"%s needs a name a player can read" % title.id)
		_check(not title.description.is_empty(),
			"%s needs a line under it" % title.id)
	_ran += 1


## 2. Every corner a real run can end in.
func _test_no_run_ends_unnamed() -> void:
	for axis: int in RunTitleData.Axis.size():
		for element: int in range(-1, TowerData.Element.size()):
			var title: RunTitleData = RunRecap.title_for(element, axis)
			_check(title != null,
				"a run that ended element %d on axis %d has no name"
					% [element, axis])
			if title != null:
				_check(title.axis == axis,
					"and the name it got describes the wrong axis: %s" % title.id)
	_ran += 1


## 3. Dominance, and honesty about ties.
func _test_the_element_is_the_dominant_one() -> void:
	var fire: TowerData = _tower_of(TowerData.Element.FIRE)
	var water: TowerData = _tower_of(TowerData.Element.WATER)
	if fire == null or water == null:
		_check(false, "two elements of tower are needed to compare")
		_ran += 1
		return

	_check(RunRecap.dominant_element({}) == -1,
		"a run with no towers settled on no element")

	var leaning: Dictionary = {
		Vector2i(0, 0): {"tower_id": fire.id, "level": 1},
		Vector2i(1, 0): {"tower_id": fire.id, "level": 1},
		Vector2i(2, 0): {"tower_id": water.id, "level": 1},
	}
	_check(RunRecap.dominant_element(leaning) == TowerData.Element.FIRE,
		"two Fire against one Water is a Fire run")

	var tied: Dictionary = {
		Vector2i(0, 0): {"tower_id": fire.id, "level": 1},
		Vector2i(1, 0): {"tower_id": water.id, "level": 1},
	}
	_check(RunRecap.dominant_element(tied) == -1,
		"an even split settled on nothing, and saying otherwise is the recap "
			+ "flattering the player rather than describing them")

	# An entry naming a tower that no longer exists must not be counted as an
	# element - a save or a content rename should leave a run unnamed, not
	# mislabelled.
	_check(RunRecap.dominant_element({Vector2i(0, 0): {"tower_id": "nope"}}) == -1,
		"an unknown tower must not vote for an element")
	_ran += 1


## 4. Ordered, with a threshold that means something.
func _test_the_axis_is_ordered() -> void:
	var floor_count: int = Balance.RECAP_TOWER_AXIS_MINIMUM
	_check(RunRecap.axis_of(floor_count, false) == RunTitleData.Axis.TOWERS,
		"enough towers is a tower run")
	_check(RunRecap.axis_of(floor_count, true) == RunTitleData.Axis.TOWERS,
		"and stays one with a companion beside it - the towers were the plan")
	_check(RunRecap.axis_of(floor_count - 1, true) == RunTitleData.Axis.COMPANION,
		"below the threshold, a companion is what the run was about")
	_check(RunRecap.axis_of(0, false) == RunTitleData.Axis.BLADE,
		"and neither is the hero alone")
	_check(floor_count >= 2,
		"a threshold of one would make every run that placed a tower a tower run")
	_ran += 1


## 5. Read from the run, so it cannot drift from it.
func _test_the_recap_reads_the_run() -> void:
	RunState.towers.clear()
	MetaState.equipped_spirit = ""
	var bare: Dictionary = RunRecap.build()
	_check(int(bare.get("towers", -1)) == 0, "no towers standing, none reported")
	_check(int(bare.get("axis", -1)) == RunTitleData.Axis.BLADE,
		"and no companion makes it the hero's own run")
	_check(not String(bare.get("title", "")).is_empty(),
		"which still has a name")

	# Change the run; the recap must change with it, having been told nothing.
	var fire: TowerData = _tower_of(TowerData.Element.FIRE)
	if fire != null:
		for index: int in Balance.RECAP_TOWER_AXIS_MINIMUM:
			RunState.towers[Vector2i(index, 0)] = {
				"tower_id": fire.id, "level": 1, "target_priority": 0,
			}
		var built: Dictionary = RunRecap.build()
		_check(int(built.get("towers", 0)) == Balance.RECAP_TOWER_AXIS_MINIMUM,
			"the recap must count what is actually standing, got %d"
				% int(built.get("towers", 0)))
		_check(int(built.get("axis", -1)) == RunTitleData.Axis.TOWERS,
			"and read it as a tower run")
		_check(built.get("title", "") != bare.get("title", ""),
			"and give it a different name than the run that built nothing")
		# Twice from the same state is the same answer. A recap that rolled or
		# accumulated would not be.
		_check(RunRecap.build() == built,
			"the same run must recap the same way twice")
	RunState.towers.clear()
	_ran += 1


# --- harness -----------------------------------------------------------------

func _tower_of(element: int) -> TowerData:
	for value: Variant in ContentDB.towers.values():
		var kind := value as TowerData
		if kind != null and not kind.is_combination and kind.element == element:
			return kind
	return null


func _finish() -> void:
	if _failures == 0 and _ran == 5:
		print("[recap] PASS - titles are content, no run ends unnamed, a tie "
			+ "settles on no element, the axis is ordered, and the recap is "
			+ "read off the run rather than recorded during it")
	elif _failures == 0:
		push_error("[recap] FAIL - only %d of 5 tests ran" % _ran)
		get_tree().quit(1)
		return
	else:
		push_error("[recap] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[recap] FAIL: %s" % why)
