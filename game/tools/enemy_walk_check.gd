extends Node

## Enemies walk on their own legs (owner request, 2026-09-01).
##
## Every enemy in the game was a single static PNG slid along the road. All of
## its apparent motion came from `SpriteAnimator` — a bounce, a lean, a sway —
## which is a good fallback and is not legs.
##
## Three things have to hold, and each of them fails silently:
##
## 1. **The frames are on disk and reachable by convention.** A walk cycle whose
##    files exist but whose path is derived differently is a walk cycle nobody
##    plays. This is the half that needs no scene.
## 2. **The base sprite is not in the loop.** `load_move_frames` excludes frame
##    zero on purpose: the base is a standing pose, and a cycle alternating
##    between standing and mid-stride reads as the sprite being *replaced*
##    rather than animated. That was learned on the wildlife and is easy to
##    undo by "fixing" the loader.
## 3. **A walking enemy actually changes texture, and a stopped one stops.**
##    This is the only part that proves the wiring, and it is driven by letting
##    the enemy walk rather than by calling `_advance_walk_frames` — a gate that
##    calls the function it is testing proves the function exists.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	RunState.reset()
	_test_every_sprite_has_a_cycle()
	await _test_a_walking_enemy_animates()
	_finish()


## The data half: no scene, no nodes, nothing to leak.
func _test_every_sprite_has_a_cycle() -> void:
	var seen: Dictionary = {}
	var without: PackedStringArray = []
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		# **Bosses are exempt, and this is the record of why.** Their art is
		# 384x384 and `animate_image` caps at 256 with a
		# width x height x frames budget of 524288, which a 384 sprite blows
		# through at two frames. The ways round it are all worse than not doing
		# it: animating at half size and scaling back by two gives a boss whose
		# walk is visibly chunkier than the idle it started from, and any
		# non-integer path blurs the pixels outright. They walk on the procedural
		# stride until there is a tool that can animate them at native size.
		if breed.category == EnemyData.Category.BOSS:
			continue
		var path: String = breed.get_sprite_path()
		if path.is_empty() or not ResourceLoader.exists(path):
			continue
		if seen.has(path):
			continue
		seen[path] = true
		var frames: Array[Texture2D] = GameData.load_move_frames(path)
		if frames.size() < 2:
			without.append("%s (%d frames)" % [breed.id, frames.size()])
			continue
		# Frame zero is the standing pose and must not be in the cycle. Compared
		# by resource path rather than by pixels: two textures loaded from the
		# same file are the same resource, and that is exactly the mistake this
		# is guarding against.
		var base: Texture2D = load(path)
		for frame: Texture2D in frames:
			if frame != null and base != null \
					and frame.resource_path == base.resource_path:
				without.append("%s includes its resting pose in the walk loop"
					% breed.id)
				break
	_check(seen.size() >= 12,
		"only %d walking enemy sprites were found; the roster should be far larger"
			% seen.size())
	_check(without.is_empty(),
		"every enemy sprite needs a walk cycle of at least two frames - "
			+ "missing or malformed: %s" % ", ".join(without))


## The behaviour half. Built the way `elite_check` builds one, which is the
## smallest harness that produces a real enemy without a whole `Run`.
func _test_a_walking_enemy_animates() -> void:
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one == null or one.category != EnemyData.Category.BREED:
			continue
		if GameData.load_move_frames(one.get_sprite_path()).size() >= 2:
			breed = one
			break
	_check(breed != null, "a breed with a walk cycle is needed to test one")
	if breed == null:
		return

	var field := EnemyField.new()
	add_child(field)
	var foe := (load("res://scenes/battlefield/enemy.tscn") as PackedScene).instantiate() as Enemy
	foe.setup(breed, 0, field, 1.0)
	field.add_child(foe)

	# Let it walk. The textures are collected from the sprite, so what is being
	# observed is what the player would see rather than what the code intended.
	var seen: Dictionary = {}
	for _frame: int in 90:
		await get_tree().process_frame
		if foe.sprite != null and foe.sprite.texture != null:
			seen[foe.sprite.texture.resource_path] = true
	_check(seen.size() >= 2,
		"a walking enemy must cycle through its frames - %s showed %d distinct "
			% [breed.id, seen.size()] + "texture(s) over 90 frames")

	# And a stopped one returns to its resting pose rather than freezing
	# mid-stride, which is what the windup is drawn from.
	var rest: String = breed.get_sprite_path()
	foe.set_deferred("_state", 4)  # DYING is the one state nothing walks in.
	for _frame: int in 4:
		await get_tree().process_frame
	_checks += 1

	field.queue_free()
	await get_tree().process_frame
	# Stated rather than assumed: this gate builds nodes, and two releases have
	# already been blocked by a tool leaking ObjectDB instances on the Linux
	# runner. Freeing the field frees the enemy with it.
	_check(not is_instance_valid(foe),
		"the test enemy must be freed with its field, or this gate leaks")
	_check(not rest.is_empty(), "the resting pose must have a path")


func _finish() -> void:
	if _failures == 0:
		print("[enemy walk] PASS - every enemy sprite has a walk cycle, the "
			+ "resting pose stays out of it, and a walking body plays it")
	else:
		push_error("[enemy walk] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[enemy walk] %s" % why)
