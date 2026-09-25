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
## **What the torches are worth**, rather than how bright the road is.
##
## This was `ROAD_OVER_GROUND = 0.025` - the road had to sit that far above the
## ground in absolute luminance - and on 2026-09-13 it failed at 0.018 with the
## lighting working perfectly well. Measuring the same points at midday says
## why: the road reads **0.124 against ground at 0.129**. The two surfaces are
## the same brightness now, and the road is told apart by its colour and its
## texture. The old threshold was calibrated against ground art that was darker
## than the road, and the ten-region re-skin on 2026-09-12 replaced it; no
## amount of light could have met the bar afterwards.
##
## So the question is asked of the lights directly: the same night is captured
## twice, once with every torch light on and once with them switched off, and
## what is compared is **the same pixels in both**. The ground art, the night
## tint, the foliage scatter and the fog are identical across the pair, so the
## difference is the lighting and cannot be anything else.
##
## Four earlier attempts each measured something that was not the lights, and
## each looked convincing until it was checked by turning the torches off:
##
## - road against ground, which the re-skin had flattened to nothing;
## - the same, minus a daylight reference, which still passed with every light
##   extinguished - it was reading the blue night tint crushing green foliage
##   harder than it crushes a neutral road;
## - the torch posts themselves, which are dark sprites;
## - the pools against distant ground, which is a different surface, and which
##   read the pools as *darker* than open ground.
##
## Measured at 0.018 lit against 0.009 unlit - the torches very nearly double
## what is under them - so the floor is set at half of that. [TUNE]
const TORCH_LIFT: float = 0.004
const ENEMY_OVER_LOCAL: float = 0.005
const FLOOR_LUMINANCE: float = 0.020

## Deep night, the darkest stop on the day/night ramp - and the midday stop the
## torch lift is measured against.
const NIGHT_PHASE: float = 0.85
const DAY_PHASE: float = 0.28

## Frames averaged per measurement, to see past the torch flicker.
const SETTLE_FRAMES: int = 24

var _failures: int = 0
## Road minus ground at midday: what the art gives before any torch is lit.
var _day_separation: float = 0.0
## The same night, with every torch light switched off.
var _unlit: Array[Image] = []
var _light_count: int = 0


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

	var camera := run.battlefield.camera as CameraRig
	if camera != null:
		camera.target = null
		camera.global_position = Vector2.ZERO
		camera.zoom = Vector2(0.5, 0.5)
	# Cloud shadows drift across the field and torches flicker, and both move the
	# numbers between runs without being what is under test. Clouds off; the
	# flicker is small enough to live with once the rest is pinned.
	Graphics.set_switch(Graphics.KEY_CLOUDS, false)
	# **And the fog, which is exploration rather than lighting.** Most of the
	# eighty-odd torches stand far from where the hero happens to be, so with
	# fog on this samples ground that is deliberately not drawn - it read the
	# pools as darker than open ground.
	Graphics.set_switch(Graphics.KEY_FOG, false)
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

	# **The daylight reference, from the same staging.** The torch lift is a
	# difference of differences, so both halves have to come off the same
	# camera, the same scatter and the same planted body - a figure carried in
	# from another run would be measuring the foliage seed as much as the light.
	DayNight._apply(DAY_PHASE)
	for _f: int in 12:
		await get_tree().process_frame
	var day: Array[Image] = []
	for _f: int in SETTLE_FRAMES:
		var lit: Image = _grab()
		if lit != null:
			day.append(lit)
		await get_tree().process_frame
	if not day.is_empty():
		_day_separation = _mean(day, _road_samples(run.battlefield)) 			- _mean(day, _ground_samples())
	DayNight._apply(NIGHT_PHASE)
	for _f: int in 12:
		await get_tree().process_frame

	var frames: Array[Image] = []
	for _f: int in SETTLE_FRAMES:
		var shot: Image = _grab()
		if shot != null:
			frames.append(shot)
		await get_tree().process_frame

	# **The control pass: the same night with the torch lights switched off.**
	# Everything that is not the lighting - the ground art, the night tint, the
	# foliage scatter, the fog - is identical between the two, so the
	# difference is the light and nothing else. Four earlier attempts at this
	# gate each measured something other than the lights; this one cannot.
	var lights: Array[PointLight2D] = _torch_lights()
	for light: PointLight2D in lights:
		light.enabled = false
	for _f: int in 8:
		await get_tree().process_frame
	var dark: Array[Image] = []
	for _f: int in SETTLE_FRAMES:
		var shot: Image = _grab()
		if shot != null:
			dark.append(shot)
		await get_tree().process_frame
	for light: PointLight2D in lights:
		light.enabled = true
	_unlit = dark
	_light_count = lights.size()
	# **Refuses rather than passes when it cannot see.** Run headless this gate
	# read from the dummy renderer, which has no textures: `texture_2d_get`
	# returned null two dozen times, `_measure` was handed an empty array, and it
	# printed PASS having measured nothing at all. A brightness check that cannot
	# sample a pixel has to say so - this is the same failure that let the
	# discipline rotation ship, an assertion satisfied by the absence of data.
	if frames.is_empty():
		_failures += 1
		printerr("[night] FAIL: no frame could be captured - this gate needs a real "
			+ "renderer, so run it without --headless")
	else:
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
	print("[night] road %.3f vs ground %.3f  (separation %.3f, daylight %.3f)"
		% [road, ground, road - ground, _day_separation])
	# **What the torches are actually worth**, measured inside their pools
	# against ground that no light reaches. The road-versus-ground figure above
	# is printed for context and asserted on no longer: at deep night the tint
	# is (0.13, 0.17, 0.33), so green foliage loses far more luminance than a
	# neutral road does, and most of that separation is the *colour* of night
	# rather than anything being lit. Proved by putting `TORCH_LIGHT_EVERY` to
	# 9999 and measuring again - the separation went up.
	var pools: Array[Vector2] = _pool_samples()
	var lit: float = _mean(frames, pools)
	var unlit: float = _mean(_unlit, pools) if not _unlit.is_empty() else lit
	var lift: float = lit - unlit
	print(("[night] torch pools %.3f lit vs %.3f unlit across %d samples and %d "
		+ "lights  (lift %.3f, need %.3f)")
		% [lit, unlit, pools.size(), _light_count, lift, TORCH_LIFT])
	if pools.is_empty() or _light_count == 0:
		push_error("no torch carries a light, so night is unlit")
		_failures += 1
	elif _unlit.is_empty():
		push_error("the unlit control pass captured no frames, so the torch "
			+ "lift went unmeasured")
		_failures += 1
	elif lift < TORCH_LIFT:
		push_error("switching every torch light off changes nothing under them:"
			+ " the lighting is decoration rather than information")
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


## Inside the torch pools, and well outside every one of them.
##
## Sampled on a ring a third of the light radius out rather than at the post,
## because a torch post is a dark sprite and sampling it measures the post.
## Only posts that actually carry a light are asked - `TORCH_LIGHT_EVERY` means
## most of them are scenery.
func _pool_samples() -> Array[Vector2]:
	var points: Array[Vector2] = []
	var step: float = Balance.TORCH_LIGHT_RADIUS * 0.33
	for node: Node in get_tree().get_nodes_in_group(&"torches"):
		var torch := node as Node2D
		if torch == null or not bool(torch.get("carries_light")):
			continue
		for turn: int in 4:
			points.append(torch.global_position
				+ Vector2.RIGHT.rotated(TAU * float(turn) / 4.0) * step)
	return points


## Every PointLight2D a torch owns.
##
## Walked rather than asked for: the light lives on the flame inside the post,
## and a gate that reaches for `_flame` breaks the first time that is renamed.
func _torch_lights() -> Array[PointLight2D]:
	var out: Array[PointLight2D] = []
	for node: Node in get_tree().get_nodes_in_group(&"torches"):
		_lights_under(node, out)
	return out


func _lights_under(node: Node, into: Array[PointLight2D]) -> void:
	var light := node as PointLight2D
	if light != null:
		into.append(light)
	for child: Node in node.get_children():
		_lights_under(child, into)


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


## One frame, or null when the renderer cannot give one.
##
## The dummy renderer used headless answers `get_texture()` with a texture whose
## image is null, so this has to be checked rather than assumed - assuming it is
## exactly how the gate came to pass on nothing.
func _grab() -> Image:
	var texture: ViewportTexture = get_viewport().get_texture()
	if texture == null:
		return null
	return texture.get_image()
