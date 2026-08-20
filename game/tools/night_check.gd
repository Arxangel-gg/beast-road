extends Node

## Is the game playable at night with brightness at its minimum?
##
## GDD §52 locks "night playable at minimum brightness" and the audit has always
## reported it as a human-judgement row, because nothing could answer it. It is
## answerable: the question is whether enough *contrast* survives at the darkest
## legal grade to tell the things you must react to from the ground they stand
## on.
##
## Run at the authored grade with no lift, which is what minimum brightness means
## now that the setting exists. A player who turns the slider up only ever gets
## more than this.
##
##   godot --path game res://tools/night_check.tscn
##
## Not headless: this measures pixels, and the dummy renderer draws none.
##
## **Staged, not played.** An earlier version rode on and waited for a wave, and
## the same check then swung between 0.011 and 0.090 separation across runs
## depending on where the hero had wandered and what was going off next to them.
## A flaky gate is worse than no gate, so the camera is unhooked from the hero
## and the enemy is planted at a known point. What varies between runs is the
## lighting and nothing else.

## Luminance separations, 0..1 on a mean-of-channels scale.
##
## Deliberately modest. This does not ask the night to look like day, it asks
## that the two things a player must resolve are resolvable: where the road runs,
## and where an enemy is standing.
##
## Set *below* the corrected measured band rather than inside it. At 1440p the
## road sits around 0.078 above ground and the enemy mean lands at 0.007-0.021
## across repeated scatters. The enemy number is deliberately conservative: a
## disc includes transparent pixels around the silhouette, even though its edge
## and colour remain plainly visible in the saved frame. The low floor still
## catches what it is for - an unlit road or a sprite truly identical to its
## background collapses to zero. Foliage scatter must not make a good build red.
const ROAD_OVER_GROUND: float = 0.025
const ENEMY_OVER_LOCAL: float = 0.005
const FLOOR_LUMINANCE: float = 0.020

## Deep night, the darkest stop on the day/night ramp.
const NIGHT_PHASE: float = 0.85

## Frames averaged per measurement, to see past the torch flicker.
const SETTLE_FRAMES: int = 24

var _failures: int = 0


func _ready() -> void:
	RunState.reset()
	# Minimum brightness is the case under test, so pin it rather than trusting
	# whatever the developer's own save happens to hold.
	Graphics.set_display(Graphics.KEY_BRIGHTNESS, 0.0)

	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame

	DayNight._apply(NIGHT_PHASE)
	if run.hud != null:
		run.hud.visible = false

	var camera := run.battlefield.camera as Camera2D
	if camera != null:
		camera.target = null
		camera.global_position = Vector2.ZERO
		camera.zoom = Vector2(0.5, 0.5)
	# Cloud shadows drift across the field and torches flicker, and both move the
	# numbers between runs without being what is under test. Clouds off; the
	# flicker is small enough to live with once the rest is pinned.
	Graphics.set_switch(Graphics.KEY_CLOUDS, false)
	var enemy: Enemy = _plant_enemy(run.battlefield)

	# Long enough for the tint, the torch flames and the planted enemy's own
	# spawn-in to settle. Measuring earlier reads a field mid-fade.
	for _f: int in 20:
		await get_tree().process_frame

	# Averaged over several frames rather than judged from one. Torches flicker,
	# and a sprite standing between two of them lands anywhere in a wide band
	# depending on which frame is caught - single frames disagreed by more than
	# the threshold being tested. Flicker is part of the look and should not be
	# switched off to make a number sit still; averaging over it measures the
	# light the player actually reads by.
	# Stopped only now, after its spawn-in has finished. Freezing it at spawn
	# froze that animation part way; leaving it running meant it walked while the
	# frames were being captured, so every frame sampled a different part of the
	# road and the average came out as road-versus-road - twice reported as a
	# separation of 0.000, which is the signature of sampling nothing at all.
	if enemy != null and is_instance_valid(enemy):
		enemy.set_process(false)
		await get_tree().process_frame

	var frames: Array[Image] = []
	for _f: int in SETTLE_FRAMES:
		frames.append(get_viewport().get_texture().get_image())
		await get_tree().process_frame
	_measure(frames, run.battlefield, enemy)

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	if _failures == 0:
		print("[night] PASS")
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(_failures)


func _measure(frames: Array[Image], field: Battlefield, enemy: Enemy) -> void:
	var image_size: Vector2i = frames[0].get_size() if not frames.is_empty() else Vector2i.ZERO
	if not frames.is_empty():
		frames[frames.size() - 1].save_png("user://night_check.png")
	print("[night] frame=%s visible=%s canvas=%s screen=%s" % [
		str(image_size), str(get_viewport().get_visible_rect().size),
		str(get_viewport().get_canvas_transform()),
		str(get_viewport().get_screen_transform())])
	# The road is what a player reads the battlefield from, and it is what the
	# torches are for. If it does not separate from the ground at night, the
	# lighting is decoration rather than information.
	var road: float = _mean(frames, _road_samples(field))
	var ground: float = _mean(frames, _ground_samples())
	print("[night] lit road %.3f vs unlit ground %.3f  (separation %.3f, need %.3f)"
		% [road, ground, road - ground, ROAD_OVER_GROUND])
	if road - ground < ROAD_OVER_GROUND:
		push_error("the lit road does not separate from unlit ground at minimum brightness")
		_failures += 1
	if road < FLOOR_LUMINANCE:
		push_error("the lit road is below the readable floor at minimum brightness")
		_failures += 1

	# An enemy has to be findable against whatever it is standing on. Measured
	# against its own surroundings rather than the frame average: a dark enemy on
	# dark ground is the failure, and a frame-wide average hides exactly that.
	if enemy == null or not is_instance_valid(enemy):
		push_error("no enemy stood on the road, so enemy contrast went unmeasured")
		_failures += 1
		return
	# Sampled on the *sprite*, not on the node: an enemy's origin sits at its
	# feet, so sampling there measures the road under it and compares road
	# against road.
	var body: Vector2 = enemy.global_position
	if enemy.sprite != null:
		body = enemy.sprite.global_position
	var radius: int = 10
	if enemy.sprite != null and enemy.sprite.texture != null:
		var drawn: Vector2 = enemy.sprite.texture.get_size() * enemy.sprite.global_scale.abs()
		radius = clampi(int(minf(drawn.x, drawn.y) * _world_to_image_scale() * 0.22), 5, 20)

	# Compared against the ring immediately around the sprite rather than a point
	# some fixed distance to one side. A fixed offset lands on road, on unlit
	# ground, or inside a torch pool depending on where the enemy stopped, and
	# the check swung from 0.005 to 0.070 on that alone. The ring asks the
	# question a player actually asks - does this shape stand out from what is
	# directly behind it - and it asks it the same way wherever the enemy is.
	var here: float = _disc(frames, body, 0, radius)
	var around: float = _disc(frames, body, radius * 2, radius * 3)
	print("[night] enemy %.3f vs the ring around it %.3f  (separation %.3f, need %.3f)"
		% [here, around, absf(here - around), ENEMY_OVER_LOCAL])
	if absf(here - around) < ENEMY_OVER_LOCAL:
		push_error("an enemy cannot be told from the ground it stands on at minimum brightness")
		_failures += 1


## Mean luminance of an annulus around a world point, averaged over the frames.
##
## `inner` of 0 makes it a disc. Sampling a ring rather than a single opposing
## point is what makes the enemy comparison independent of where the enemy is
## standing.
func _disc(frames: Array[Image], world: Vector2, inner: int, outer: int) -> float:
	var total: float = 0.0
	var count: int = 0
	for image: Image in frames:
		var centre: Vector2 = _world_to_image(world)
		for dx: int in range(-outer, outer + 1):
			for dy: int in range(-outer, outer + 1):
				var distance: float = Vector2(float(dx), float(dy)).length()
				if distance > float(outer) or distance < float(inner):
					continue
				var x: int = int(centre.x) + dx
				var y: int = int(centre.y) + dy
				if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
					continue
				var colour: Color = image.get_pixel(x, y)
				total += (colour.r + colour.g + colour.b) / 3.0
				count += 1
	return total / float(maxi(count, 1))


## Points along each road's final approach to the town.
##
## Several per road rather than one. A single point sits at the mercy of the two
## torches nearest it and their flicker, and the road figure moved by more than
## the threshold between runs on that alone - once to 0.033 against a 0.035 gate,
## which is a gate that fails on a good build roughly one time in six.
func _road_samples(field: Battlefield) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for lane: int in Balance.LANE_COUNT:
		var path: PackedVector2Array = field.lane_path(lane)
		if path.size() < 2:
			continue
		var gate: Vector2 = path[path.size() - 1]
		var out: Vector2 = path[path.size() - 2]
		for step: int in 4:
			points.append(gate.lerp(out, 0.2 + 0.2 * float(step)))
	return points


## Ground away from any road, on the diagonals between the four lanes.
func _ground_samples() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for lane: int in Balance.LANE_COUNT:
		points.append(BattleGrid.lane_vector(lane).rotated(PI * 0.25) * 620.0)
	return points


## One enemy, on a road, at a fixed distance out.
##
## Placed rather than spawned by a wave so its position is known: the contrast
## being measured is a sprite against the ground under it, which is only
## meaningful if the sample actually lands on the sprite.
func _plant_enemy(field: Battlefield) -> Enemy:
	var roster: Array[EnemyData] = ContentDB.enemies_of_category(EnemyData.Category.BREED)
	if roster.is_empty() or field == null:
		return null
	var enemy: Enemy = field.spawn_enemy(roster[0], 0, 1.0)
	if enemy == null:
		return null
	enemy.global_position = BattleGrid.lane_vector(0) * 520.0
	# Held still, but by pinning its speed rather than by switching its process
	# off: freezing it the frame it spawns also freezes its spawn-in part way,
	# and how far through that got depended on frame timing.
	enemy.set_physics_process(false)
	return enemy


func _mean(frames: Array[Image], points: Array[Vector2], radius: int = 8) -> float:
	if points.is_empty() or frames.is_empty():
		return 0.0
	var total: float = 0.0
	for image: Image in frames:
		for at: Vector2 in points:
			total += _sample(image, at, radius)
	return total / float(points.size() * frames.size())


## Mean luminance of a small patch of the rendered frame around a world point.
##
## Mapped through the viewport's own canvas transform rather than by hand from
## the camera's position and zoom. The hand-rolled version went wrong the moment
## the camera moved, and went wrong quietly — it kept returning plausible numbers
## for the wrong pixels, which reads as the night having changed rather than as
## the tool having drifted.
func _sample(image: Image, world: Vector2, radius: int) -> float:
	var centre: Vector2 = _world_to_image(world)
	var total: float = 0.0
	var count: int = 0
	for dx: int in range(-radius, radius + 1):
		for dy: int in range(-radius, radius + 1):
			var x: int = int(centre.x) + dx
			var y: int = int(centre.y) + dy
			if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
				continue
			var colour: Color = image.get_pixel(x, y)
			total += (colour.r + colour.g + colour.b) / 3.0
			count += 1
	return total / float(maxi(count, 1))


## The viewport texture is captured after stretch has mapped the authored
## 1920x1080 canvas to the actual window. `get_canvas_transform()` alone lands
## in authored pixels, so it samples the wrong quarter of a 1440p/4K frame.
func _world_to_image(world: Vector2) -> Vector2:
	var viewport: Viewport = get_viewport()
	return (viewport.get_screen_transform() * viewport.get_canvas_transform()) * world


func _world_to_image_scale() -> float:
	var viewport: Viewport = get_viewport()
	var transform: Transform2D = viewport.get_screen_transform() * viewport.get_canvas_transform()
	return (transform.x.length() + transform.y.length()) * 0.5
