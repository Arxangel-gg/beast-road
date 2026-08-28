extends Node

## An upgraded tower must fire a visibly different shot, not merely a larger one.
##
## Scale alone was already doing the work - a level 5 projectile is 1.64 times a
## level 1 - and it is the kind of difference a player can measure and not see.
## Nothing errors when an upgrade is invisible; the tower simply gets better and
## looks the same, and the money spent stops feeling spent.
##
## So this asserts two things a screenshot could not: that the size really does
## climb across every level, and that somewhere in that climb the shot changes
## *character* rather than only dimensions.

const PROJECTILE_SCENE: String = "res://scenes/battlefield/projectile.tscn"

var _failures: int = 0


func _ready() -> void:
	var scene: PackedScene = load(PROJECTILE_SCENE)
	_check(scene != null, "the projectile scene must exist")
	if scene == null:
		_finish()
		return
	var tower: TowerData = null
	for value: Variant in ContentDB.towers.values():
		tower = value as TowerData
		if tower != null:
			break
	_check(tower != null, "a tower is needed to build a shot")
	if tower == null:
		_finish()
		return

	var looks: Array[Dictionary] = []
	for level: int in range(1, Balance.TOWER_MAX_LEVEL + 1):
		var shot := scene.instantiate() as Projectile
		# Built exactly the way a tower builds one - through the argument, so
		# this measures the path the game actually takes rather than a friendlier
		# one the test arranged for itself.
		shot.setup(null, tower, 10.0, 0.0, level)
		add_child(shot)
		looks.append(shot.look())
		shot.queue_free()

	for level: int in range(1, looks.size()):
		var below: Dictionary = looks[level - 1]
		var here: Dictionary = looks[level]
		_check(float(here["trail"]) > float(below["trail"]),
			"level %d must fire a wider shot than level %d, got %.2f against %.2f"
				% [level + 1, level, float(here["trail"]), float(below["trail"])])
		_check(float(here["glow_alpha"]) >= float(below["glow_alpha"]),
			"and must not glow less, got %.3f against %.3f"
				% [float(here["glow_alpha"]), float(below["glow_alpha"])])

	# The step that makes an upgrade *look* like one.
	_check(not bool(looks[0]["hot"]),
		"a level 1 shot must not carry the white core")
	_check(bool(looks[looks.size() - 1]["hot"]),
		"a max level shot must carry it")
	var first_hot: int = 0
	for level: int in looks.size():
		if bool(looks[level]["hot"]):
			first_hot = level + 1
			break
	_check(first_hot == Balance.PROJECTILE_HOT_TIER,
		"the white core must arrive at level %d, arrived at %d"
			% [Balance.PROJECTILE_HOT_TIER, first_hot])
	print("[projectile] trail %.1f -> %.1f, glow %.2f -> %.2f, white core from level %d"
		% [float(looks[0]["trail"]), float(looks[looks.size() - 1]["trail"]),
			float(looks[0]["glow_alpha"]),
			float(looks[looks.size() - 1]["glow_alpha"]), first_hot])
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("[projectile] PASS - every level fires a bigger shot and the "
			+ "upgrade changes its character")
	else:
		printerr("[projectile] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[projectile] FAIL: %s" % why)
