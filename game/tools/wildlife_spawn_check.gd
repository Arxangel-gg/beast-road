extends Node

## Animals arrive from the wild, not from the town square.
##
## Wildlife inherited the foliage rule for keeping off the city - 340 units,
## which is a reed's distance. Deer and wolves appeared close enough to the base
## to read as attacking it, and a predator that noticed the hero standing there
## was on them before the player saw it coming. Reported twice from play.
##
## The distance is the whole fix, so it is the thing measured: every point the
## spawner offers, over enough draws that a rare bad one would show.

const DRAWS: int = 600

var _failures: int = 0


func _ready() -> void:
	var wildlife := Wildlife.new()
	wildlife.grid = BattleGrid.new()
	add_child(wildlife)

	var closest: float = INF
	var offered: int = 0
	for i: int in DRAWS:
		var at: Vector2 = wildlife.call("_clear_point")
		if at == Vector2.ZERO:
			continue
		offered += 1
		closest = minf(closest, at.length())

	# It must still find somewhere. A clearance that rejects the whole field
	# would read as "the wilderness is empty" rather than as a bug.
	_check(offered > DRAWS / 2,
		"the spawner must still find room, offered %d of %d" % [offered, DRAWS])
	_check(closest >= Balance.WILDLIFE_SPAWN_CLEARANCE,
		"nothing may arrive within %.0f of the city, closest was %.0f"
			% [Balance.WILDLIFE_SPAWN_CLEARANCE, closest])
	print("[wildlife] %d of %d points offered, closest %.0f (floor %.0f)"
		% [offered, DRAWS, closest, Balance.WILDLIFE_SPAWN_CLEARANCE])

	if _failures == 0:
		print("[wildlife] PASS - arrivals keep their distance from the city")
	else:
		printerr("[wildlife] FAIL - %d problem(s)" % _failures)

	# **Torn down before quitting.** Quitting on top of a live system reports
	# "resources still in use at exit", which is an ERROR line, and the release
	# check fails on any of those - a gate that prints one fails the pipeline it
	# belongs to however green its own verdict is.
	wildlife.grid = null
	wildlife.queue_free()
	for _frame: int in 8:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[wildlife] FAIL: %s" % why)
