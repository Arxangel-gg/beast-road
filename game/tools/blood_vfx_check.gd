extends Node

const BloodBurstScript = preload("res://scripts/systems/blood_burst.gd")

## The gore toggle is cosmetic and local: off creates no blood nodes; on creates
## a procedural ballistic burst while leaving the rest of Vfx untouched.

var _failures: int = 0


func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	await get_tree().process_frame
	var had_value: bool = MetaState.settings.has(UserSettings.BLOOD_VFX_KEY)
	var old_value: Variant = MetaState.settings.get(UserSettings.BLOOD_VFX_KEY, true)
	var stage := Node2D.new()
	add_child(stage)
	Vfx.bind_world(stage)
	var layer: Node2D = stage.get_node_or_null("VfxLayer") as Node2D
	_check(layer != null, "Vfx must create a scoped effect layer")

	UserSettings.set_value(UserSettings.BLOOD_VFX_KEY, false)
	Vfx.blood(Vector2.ZERO, Vector2.RIGHT, Balance.VFX_BLOOD_HIT_SIZE)
	_check(layer == null or layer.get_child_count() == 0,
		"disabled blood must create no cosmetic nodes")

	UserSettings.set_value(UserSettings.BLOOD_VFX_KEY, true)
	Vfx.blood(Vector2.ZERO, Vector2.RIGHT, Balance.VFX_BLOOD_HIT_SIZE,
		Vector2(0.0, 42.0))
	var procedural: bool = false
	if layer != null:
		for child: Node in layer.get_children():
			if child.get_script() == BloodBurstScript:
				procedural = true
	_check(procedural, "enabled blood must create a procedural ballistic burst")

	# The damage fact names the body that was hit. Before `at` existed, Vfx
	# searched the hero group and a remote Warden's impact appeared on the local
	# player instead.
	Vfx.clear()
	await get_tree().process_frame
	var harmed_at := Vector2(123.0, 87.0)
	EventBus.hero_damaged.emit(12.0, Vector2.ZERO, harmed_at)
	var found_at_target: bool = false
	if layer != null:
		for child: Node in layer.get_children():
			if child.get_script() == BloodBurstScript \
					and (child as Node2D).global_position.is_equal_approx(harmed_at):
				found_at_target = true
	_check(found_at_target, "hero blood must appear on the Warden named by the damage fact")
	_test_persistent_blood()
	_test_the_shape_of_a_blob()
	_test_the_vignette_belongs_to_the_run()
	await _test_the_title_screen_opens_clean()

	Vfx.clear()
	Vfx.bind_world(null)
	Sfx.stop_immediately()
	stage.queue_free()
	if had_value:
		MetaState.settings[UserSettings.BLOOD_VFX_KEY] = old_value
	else:
		MetaState.settings.erase(UserSettings.BLOOD_VFX_KEY)
	# Effects own active tweens. Give deferred frees two frames before exit so the
	# gate measures runtime cleanup rather than reporting its own abrupt teardown
	# as leaked game objects.
	for _f: int in 10:
		await get_tree().process_frame
	# Audio decoding is released on its server thread after the voice is
	# stopped; a wall-clock turn prevents that in-flight decoder from being
	# mistaken for a leaked resource when this tiny gate exits immediately.
	# A quarter second lost the race about once in two runs under --verbose
	# and once on CI (2026-09-12); the hurt sound this gate triggers is the
	# last thing decoding when it quits.
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	await get_tree().create_timer(0.75).timeout
	Sfx.stop_immediately()
	if _failures == 0:
		print("[blood-vfx] PASS — procedural blood obeys gore, landing and weather rules")
	else:
		push_error("[blood-vfx] FAIL — %d problem(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## The mark the ground keeps, and the stain a character carries.
##
## The splash above is gone in a third of a second and was already covered. These
## are the two halves that persist, and both have a way of failing silently: a
## ground field parented into the effects layer gets evicted by the effect cap
## the moment a fight gets busy, and a stain driven from health does nothing at
## all if the material never attaches.
## **What blood is shaped like**, which nothing could see before.
##
## Both blood canvases drew with `draw_circle` until 2026-09-16 - a perfectly
## round shape in one flat colour - and every check in this file passed the whole
## time, because they ask whether a burst *exists*, never what it looks like.
## This drives `BloodInk.blob` directly, which is the right seam: it is pure
## arithmetic over arrays, so the shape can be measured without rendering
## anything, and the failure it guards is exactly the one that shipped.
func _test_the_shape_of_a_blob() -> void:
	var points := PackedVector2Array()
	var colours := PackedColorArray()
	var indices := PackedInt32Array()
	var tone := Color(0.48, 0.06, 0.07, 0.5)
	BloodInk.blob(points, colours, indices, Vector2.ZERO, 10.0, tone, 3.5)
	_check(points.size() == 1 + BloodInk.RIM * 2,
		"a blob is a middle and two rings: %d vertices" % points.size())
	_check(indices.size() == BloodInk.RIM * 9,
		"every rim step is three triangles: %d indices" % indices.size())

	# **The edge is soft**, which is the whole of it. One colour for the whole
	# shape *is* a hard edge, so the rim must reach zero while the middle does
	# not - and a build that painted a flat disc reads here as a rim at full
	# alpha.
	var widest: float = 0.0
	var narrowest: float = INF
	for index: int in range(1, points.size()):
		var away: float = points[index].length()
		if index % 2 == 0:
			_check(colours[index].a <= 0.001,
				"the rim is transparent (%.3f)" % colours[index].a)
			widest = maxf(widest, away)
			narrowest = minf(narrowest, away)
		else:
			_check(colours[index].a > tone.a * 0.5,
				"the core ring still carries the colour (%.3f)" % colours[index].a)
	_check(colours[0].a >= tone.a - 0.001,
		"the middle is at full strength (%.3f)" % colours[0].a)

	# **And it is not a circle.** A lobed outline is what separates a pool of
	# blood from a stamp, and a perfectly regular one measures as zero here.
	_check(widest - narrowest > 10.0 * BloodInk.WOBBLE * 0.5,
		"the outline is lobed rather than round (%.2f of %.2f)"
			% [widest - narrowest, 10.0 * BloodInk.WOBBLE])

	# **The same blob is the same shape every frame.** A mark that re-rolled its
	# outline on each repaint shimmers while it dries, and `BloodField` repaints
	# ten times a second for ten minutes.
	var again := PackedVector2Array()
	var again_colours := PackedColorArray()
	var again_indices := PackedInt32Array()
	BloodInk.blob(again, again_colours, again_indices, Vector2.ZERO, 10.0, tone, 3.5)
	var identical: bool = true
	for index: int in points.size():
		if not points[index].is_equal_approx(again[index]):
			identical = false
	_check(identical, "the same seed draws the same outline")

	# **A thrown mote is drawn out along the way it is going.** This is what
	# replaced the bead-plus-trail pair, so a build that ignored the stretch
	# would silently go back to round beads.
	var long := PackedVector2Array()
	var long_colours := PackedColorArray()
	var long_indices := PackedInt32Array()
	BloodInk.blob(long, long_colours, long_indices, Vector2.ZERO, 10.0, tone, 3.5,
		Vector2(30.0, 0.0))
	var reach_x: float = 0.0
	var reach_y: float = 0.0
	for point: Vector2 in long:
		reach_x = maxf(reach_x, absf(point.x))
		reach_y = maxf(reach_y, absf(point.y))
	_check(reach_x > reach_y * 2.0,
		"a streak is longer along its motion than across it (%.1f against %.1f)"
			% [reach_x, reach_y])

	# Nothing at all for a blob with no size or no colour, so a caller need not
	# test before calling and an empty set cannot reach the canvas.
	var empty := PackedVector2Array()
	var empty_colours := PackedColorArray()
	var empty_indices := PackedInt32Array()
	BloodInk.blob(empty, empty_colours, empty_indices, Vector2.ZERO, 0.0, tone, 1.0)
	BloodInk.blob(empty, empty_colours, empty_indices, Vector2.ZERO, 10.0,
		Color(tone, 0.0), 1.0)
	_check(empty.is_empty(), "a blob with no size or no colour draws nothing")


func _test_persistent_blood() -> void:
	var world: Node2D = Vfx.world
	_check(world != null, "the ground field needs a world to live in")
	if world == null:
		return
	var field: BloodField = world.get_node_or_null("BloodField") as BloodField
	_check(field != null, "Vfx must give the world a BloodField")
	if field == null:
		return
	# **Not under the effects layer.** That layer evicts its oldest child once
	# full, which would delete blood to make room for sparks.
	var layer: Node = world.get_node_or_null("VfxLayer")
	_check(field.get_parent() == world,
		"the blood field must sit beside the effect layer, not inside it")
	_check(layer == null or field.get_parent() != layer,
		"blood on the ground must not be subject to the transient effect cap")

	field.wipe()
	var rng := RandomNumberGenerator.new()
	for i: int in 5:
		field.splat(Vector2(i * 40, 0), Vector2.RIGHT, 50.0, rng)
	_check(field.marks() == 5, "five hits must leave five marks, got %d"
		% field.marks())
	# Bounded, so a long act cannot accumulate without limit.
	for i: int in BloodField.MAX_SPLATS + 40:
		field.splat(Vector2(i, 0), Vector2.RIGHT, 30.0, rng)
	_check(field.marks() <= BloodField.MAX_SPLATS,
		"marks must be capped at %d, got %d" % [BloodField.MAX_SPLATS, field.marks()])
	field.wipe()
	_check(field.marks() == 0, "wiping the field must clear it between roads")

	# Rain preserves the ten-minute dry promise while washing existing history at
	# a deliberate faster rate. This exercises the same weather fact the runtime
	# receives rather than reaching into private field state.
	EventBus.weather_changed.emit("downpour")
	_check(is_equal_approx(field.wash_multiplier(), Balance.BLOOD_RAIN_WASH_MULTIPLIER),
		"rain must accelerate blood ageing, got %.2f" % field.wash_multiplier())
	EventBus.weather_changed.emit("clear")
	_check(is_equal_approx(field.wash_multiplier(), 1.0),
		"dry weather must restore ordinary blood ageing")

	# The stain follows health, and washes off when health returns.
	var sprite := Sprite2D.new()
	sprite.texture = PlaceholderTexture2D.new()
	add_child(sprite)
	var material: ShaderMaterial = BloodStain.attach(sprite, 7)
	_check(material != null, "a sprite with no material must accept a stain")
	if material != null:
		for i: int in 60:
			BloodStain.drive(material, 0.1, 0.1)
		var hurt: float = BloodStain.level(material)
		_check(hurt > 0.0, "a badly hurt character must carry a stain, got %.3f" % hurt)
		_check(hurt <= Balance.BLOOD_STAIN_MAX + 0.001,
			"the stain must stay under the readability cap, got %.3f" % hurt)
		for i: int in 200:
			BloodStain.drive(material, 1.0, 0.1)
		_check(BloodStain.level(material) < 0.01,
			"healing must wash the stain off, left %.3f"
				% BloodStain.level(material))
	sprite.queue_free()



## **The red edge is a warning about a hero, and it dies with the run.**
##
## Owner, 2026-09-15: "the red health vignette still appears on title screen in
## some cases but shouldn't." It is a shader parameter on a `CanvasLayer` that
## `Vfx` owns, and `Vfx` is an autoload - so it survives every scene change in
## the game, and the only thing that ever takes it off is somebody choosing to.
## Nothing on the main menu reports health, so whatever it was last told is what
## the title screen wears.
##
## Three ways it outlives a run, and none of them shows in a still frame:
##
## - **A run that is left rather than settled.** Quitting from the pause menu
##   and a co-op host going away both reach the menu without `run_ended`.
## - **A report that lands after the end.** The clear on `run_ended` is only as
##   good as its ordering; anything emitting health afterwards puts it back.
## - **The new run that follows.** A fresh road must open with a clean screen
##   whatever the last one ended as.
func _test_the_vignette_belongs_to_the_run() -> void:
	var phase: RunState.Phase = RunState.phase
	var active: bool = GameDirector.run_active

	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	EventBus.hero_health_changed.emit(1.0, 100.0)
	var hurt: float = Vfx.vignette_strength()
	_check(hurt > 0.0,
		"a nearly dead hero must redden the screen edge, got %.3f" % hurt)
	_check(hurt <= Balance.VFX_VIGNETTE_MAX + 0.001,
		"and never past its own ceiling, got %.3f" % hurt)
	EventBus.hero_health_changed.emit(100.0, 100.0)
	_check(Vfx.vignette_strength() <= 0.001,
		"a whole hero must wear none of it, left %.3f" % Vfx.vignette_strength())

	# **Settled, and then reported at.** The refusal is on the setting rather
	# than only on the clearing, so ordering cannot beat it.
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	EventBus.hero_health_changed.emit(1.0, 100.0)
	RunState.set_phase(RunState.Phase.ENDED)
	Vfx.clear_vignette()
	EventBus.hero_health_changed.emit(1.0, 100.0)
	_check(Vfx.vignette_strength() <= 0.001,
		("a health report after the run ended must not put it back, left %.3f"
			% Vfx.vignette_strength()))

	# Back as it was found: this gate shares its autoloads with the next one.
	RunState.set_phase(phase)
	GameDirector.run_active = active
	Vfx.clear_vignette()


## **And the title screen itself opens clean**, whichever way it was reached.
##
## Driven rather than read, and driven on the real scene: the two paths that
## reach the menu without settling a run - the pause menu's quit and a co-op
## host going away - cannot be taken in a headless gate without the scene
## change freeing the gate, so what is checked is the invariant they broke.
## Standing the menu up while the edge is red is exactly the state the owner
## screenshotted.
func _test_the_title_screen_opens_clean() -> void:
	var phase: RunState.Phase = RunState.phase
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	EventBus.hero_health_changed.emit(1.0, 100.0)
	_check(Vfx.vignette_strength() > 0.0,
		"the gate must start this one with a red screen or it proves nothing")
	var scene := load("res://scenes/ui/main_menu.tscn") as PackedScene
	var menu: Node = scene.instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check(Vfx.vignette_strength() <= 0.001,
		("the main menu must open with no red edge however the player got "
			+ "there, left %.3f") % Vfx.vignette_strength())
	menu.queue_free()
	await get_tree().process_frame
	RunState.set_phase(phase)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[blood-vfx] %s" % message)
