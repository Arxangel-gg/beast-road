extends Node

## The frame's budgets (2026-09-24), held to what they promise.
##
##   godot --headless --path game res://tools/frame_budget_check.tscn
##
## Act X measured 97 ms a frame on an RTX 3070 Ti, and the census said why: a
## node allocated and freed for every hit, every number and every muzzle; cast
## shadows on every torch on the field at once; and every ember of every
## torch, tower and camp simulated whether or not the camera could see it.
## Each of those is a budget now, and each budget is *driven* here rather than
## read back off a constant: a hit allocates no node, the shadows are the
## nearest few to what the camera watches, an emitter the camera cannot see
## rests, the foliage's idle step reaches only the view, and the physics tick
## follows the display so a 144 Hz screen is not watching a 60 Hz Warden.

var _failures: Array[String] = []
var _checks: int = 0
var _world: Node2D = null


func _ready() -> void:
	MetaState.hold_saves()
	var held: Dictionary = Graphics.to_dictionary()
	_world = Node2D.new()
	_world.name = "World"
	add_child(_world)
	await _test_a_hit_allocates_no_node()
	_test_shadows_are_the_nearest_few()
	_test_an_unseen_emitter_rests()
	_test_the_idle_step_reaches_only_the_view()
	_test_physics_follows_the_display()
	await _test_the_lamps_on_loot_are_budgeted()
	_test_the_roster_is_gathered_once_a_frame()
	await _test_a_bar_is_one_item()
	_test_the_ink_ages_on_its_clock()
	Graphics.from_dictionary(held)
	Vfx.bind_world(null)
	await get_tree().process_frame
	for problem: String in _failures:
		push_error("[frame_budget] " + problem)
	print("[frame_budget] %d checks, %d failed" % [_checks, _failures.size()])
	print("[frame_budget] %s" % ("PASS - a hit allocates nothing, the shadows are the nearest few, the unseen rests"
		if _failures.is_empty() else "FAIL"))
	Sfx.stop_immediately()
	await get_tree().process_frame
	get_tree().quit(0 if _failures.is_empty() else 1)


# --- A hit allocates no node --------------------------------------------------

## Forty of everything a blow throws, then the effects layer must hold nothing:
## every one of them is a record on one of the two ink canvases. The caps drop
## the oldest rather than grow, and every record burns out.
func _test_a_hit_allocates_no_node() -> void:
	Vfx.bind_world(_world)
	var layer: Node = Vfx.get("_container") as Node
	_check(layer != null, "binding a world stands the effects layer up")
	for i: int in 40:
		var at := Vector2(200.0 + float(i) * 7.0, 300.0)
		Vfx.number(at, 12.0 + float(i), Color.WHITE, i % 5 == 0)
		Vfx.muzzle(at, Vector2.RIGHT, Color(1.0, 0.6, 0.2), TowerData.Element.FIRE)
		Vfx.impact(at, TowerData.Element.FIRE, Color(1.0, 0.6, 0.2), 48.0)
		Vfx.forge_burst(at, 80.0)
		Vfx.spark(at, Color.WHITE, 1, Vector2.UP, 120.0)
		Vfx.blood(at, Vector2.RIGHT, Balance.VFX_BLOOD_HIT_SIZE)
		Vfx.dust(at, Color(0.4, 0.3, 0.2), 3, 30.0)
	await get_tree().process_frame
	var stood: int = layer.get_child_count() if layer != null else -1
	_check(stood == 0,
		"forty hits stood %d nodes up on the effects layer; a hit must allocate none" % stood)
	var flat: VfxInk = Vfx.ink_flat()
	var light: VfxInk = Vfx.ink()
	_check(flat != null and light != null, "both ink canvases stand under the world")
	if flat == null or light == null:
		return
	_check(not flat.additive and light.additive,
		"the numbers' canvas lays paint and the sparks' canvas adds light")
	_check(flat.live_dust() == 120,
		"forty landings' dust should be a hundred and twenty records on the flat canvas, got %d" % flat.live_dust())
	_check(flat.live_numbers() == 40,
		"forty numbers should be forty records, got %d" % flat.live_numbers())
	_check(light.live_art() >= 40,
		"forty forged bursts should be at least forty records, got %d" % light.live_art())
	_check(light.live_sparks() == 40,
		"forty sparks should be forty records, got %d" % light.live_sparks())
	var motes: BloodMotes = Vfx.blood_motes()
	_check(motes != null and motes.live() >= 40 * Balance.VFX_BLOOD_DROPS_MIN
		and motes.live() <= Balance.VFX_BLOOD_MOTES_MAX,
		"forty blows' blood should be records in the air, got %d" % (motes.live() if motes != null else -1))
	_check(light.live_rings() == 0 and light.live() > 80,
		"the muzzle's tongue and flash land on the light canvas (%d live)" % light.live())
	if ResourceLoader.exists(Vfx.IMPACT_ART_FORMAT % "fire"):
		_check(flat.live_art() >= 40,
			"the painted impacts should be records on the flat canvas, got %d" % flat.live_art())
	# Capped by dropping the oldest, never by growing.
	for _i: int in Balance.VFX_INK_NUMBERS_MAX + 20:
		Vfx.number(Vector2.ZERO, 5.0, Color.WHITE)
	_check(flat.live_numbers() == Balance.VFX_INK_NUMBERS_MAX,
		"the numbers cap at %d, held %d" % [Balance.VFX_INK_NUMBERS_MAX, flat.live_numbers()])
	await get_tree().create_timer(Balance.VFX_NUMBER_LIFE * 1.25 + 1.0).timeout
	await get_tree().process_frame
	_check(flat.live() == 0 and light.live() == 0,
		"every record should have burnt out (%d paint, %d light still live)"
			% [flat.live(), light.live()])
	_check(layer.get_child_count() == 0, "the effects layer stayed empty through it")


# --- The shadows are the nearest few ----------------------------------------

## Twenty shadow lights in a row; the budget keeps the nearest few to the
## watched point, follows the point when it moves, gives an unlit light no
## slot, keeps more on Ultra than on High, and none on Low.
func _test_shadows_are_the_nearest_few() -> void:
	var root := Node2D.new()
	root.name = "Torches"
	_world.add_child(root)
	var lights: Array[PointLight2D] = []
	for i: int in 20:
		var light := PointLight2D.new()
		light.position = Vector2(100.0 * float(i), 0.0)
		light.add_to_group(LightKit.SHADOW_GROUP)
		light.shadow_enabled = true
		root.add_child(light)
		lights.append(light)

	Graphics.apply_preset(Graphics.PRESET_HIGH)
	var high: int = Balance.SHADOW_LIGHT_BUDGET_HIGH
	var kept: int = LightKit.budget_shadows(get_tree(), Vector2.ZERO)
	_check(kept == high, "High should keep %d shadows, kept %d" % [high, kept])
	var wrong: int = 0
	for i: int in 20:
		if lights[i].shadow_enabled != (i < high):
			wrong += 1
	_check(wrong == 0, "%d lights were cast or rested against their distance" % wrong)

	LightKit.budget_shadows(get_tree(), Vector2(1900.0, 0.0))
	_check(lights[19].shadow_enabled and not lights[0].shadow_enabled,
		"the budget follows what the camera watches")

	lights[19].visible = false
	LightKit.budget_shadows(get_tree(), Vector2(1900.0, 0.0))
	_check(not lights[19].shadow_enabled and lights[19 - high].shadow_enabled,
		"an unlit light took a slot")
	lights[19].visible = true

	Graphics.apply_preset(Graphics.PRESET_ULTRA)
	kept = LightKit.budget_shadows(get_tree(), Vector2.ZERO)
	_check(kept == Balance.SHADOW_LIGHT_BUDGET_ULTRA and kept > high,
		"Ultra should keep more than High (%d against %d)" % [kept, high])

	Graphics.apply_preset(Graphics.PRESET_LOW)
	kept = LightKit.budget_shadows(get_tree(), Vector2.ZERO)
	var casting: int = 0
	for light: PointLight2D in lights:
		if light.shadow_enabled:
			casting += 1
	_check(kept == 0 and casting == 0, "Low should cast nothing (%d kept, %d casting)" % [kept, casting])

	Graphics.apply_preset(Graphics.PRESET_HIGH)
	root.free()


# --- An unseen emitter rests --------------------------------------------------

## A flame, a tower's air and a camp fire far off the screen hide their
## emitters; brought back into view, they wake.
func _test_an_unseen_emitter_rests() -> void:
	var far := Vector2(-9000.0, -9000.0)
	var near := Vector2(200.0, 200.0)
	# The flame staggers its clock up to 1.3x the interval, so one tick this
	# long is past every emitter's next look.
	var step: float = Balance.PARTICLE_CULL_INTERVAL * 1.3 + 0.01

	var flame := Flame.new()
	_world.add_child(flame)
	flame.configure(16.0)
	flame.position = far
	flame._process(step)
	var embers: CPUParticles2D = flame.get("_embers") as CPUParticles2D
	var smoke: CPUParticles2D = flame.get("_smoke") as CPUParticles2D
	_check(embers != null and smoke != null, "a configured flame has embers and smoke")
	_check(embers != null and not embers.visible and smoke != null and not smoke.visible,
		"a flame far off the screen still simulated its embers")
	flame.position = near
	flame._process(step)
	_check(embers != null and embers.visible and smoke != null and smoke.visible,
		"a flame back in view did not wake its embers")
	flame.free()

	var aura := TowerAura.new()
	aura.element = TowerData.Element.FIRE
	_world.add_child(aura)
	aura.position = far
	aura._process(step)
	_check(not aura.visible, "a tower's air far off the screen was still simulated")
	aura.position = near
	aura._process(step)
	_check(aura.visible, "a tower's air back in view did not wake")
	aura.free()

	var fire := CampFire.new()
	_world.add_child(fire)
	fire.make_showpiece()
	var sparks: CPUParticles2D = fire.get("_embers") as CPUParticles2D
	_check(sparks != null, "a showpiece camp fire has embers")
	fire.position = far
	fire._process(step)
	_check(sparks != null and not sparks.visible, "a camp fire far off the screen still simulated its embers")
	fire.position = near
	fire._process(step)
	_check(sparks != null and sparks.visible, "a camp fire back in view did not wake its embers")
	fire.free()


# --- The idle step reaches only the view ------------------------------------

## Two breathing plants, one inside the window and one outside: a step turns
## the first to its next frame and leaves the second alone.
func _test_the_idle_step_reaches_only_the_view() -> void:
	var a := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var b := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var inside := Sprite2D.new()
	inside.texture = a
	inside.position = Vector2(100.0, 100.0)
	_world.add_child(inside)
	var outside := Sprite2D.new()
	outside.texture = a
	outside.position = Vector2(5000.0, 5000.0)
	_world.add_child(outside)
	var foliage := Foliage.new()
	var frames_a: Array[Texture2D] = [a, b]
	foliage._animated.append({"sprite": inside, "frames": frames_a, "phase": 0})
	foliage._animated.append({"sprite": outside, "frames": frames_a, "phase": 0})
	foliage._step_idle(1, Rect2(0.0, 0.0, 800.0, 800.0))
	_check(inside.texture == b, "a plant inside the view did not take its next frame")
	_check(outside.texture == a, "a plant outside the view was re-textured")
	foliage._step_idle(2, Rect2(0.0, 0.0, 8000.0, 8000.0))
	_check(outside.texture == a and inside.texture == a,
		"a plant that comes into the window steps from then on")
	foliage.free()
	inside.free()
	outside.free()
	# And the field's own tick asks the view, which is the wiring a driven
	# step cannot see.
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/foliage.gd")
	var at: int = source.find("_idle_frame = step")
	var slice: String = source.substr(at, 200) if at >= 0 else ""
	_check(slice.contains("_step_idle(step, ScreenCull.world_window("),
		"the foliage's tick does not hand the view's window to the step")


# --- The physics tick follows the display ------------------------------------

func _test_physics_follows_the_display() -> void:
	var floor_rate: int = Balance.PHYSICS_RATE_MIN
	_check(Graphics.physics_rate_for(144.0, 0) == 144, "a 144 Hz display uncapped ticks at 144")
	_check(Graphics.physics_rate_for(60.0, 0) == 60, "a 60 Hz display ticks at 60")
	_check(Graphics.physics_rate_for(-1.0, 0) == floor_rate, "an unknown display ticks at the floor")
	_check(Graphics.physics_rate_for(144.0, 60) == 60, "a frame cap below the display caps the tick")
	_check(Graphics.physics_rate_for(240.0, 0) == Balance.PHYSICS_RATE_MAX,
		"a 240 Hz display is held to the ceiling")
	_check(Graphics.physics_rate_for(144.0, 240) == 144, "a cap above the display changes nothing")
	_check(Graphics.physics_rate_for(-1.0, 144) == 144, "an unknown display with a cap ticks at the cap")
	_check(Graphics.physics_rate_for(-1.0, 30) == floor_rate, "a cap under the floor still ticks at the floor")
	Graphics.apply_runtime()
	_check(Engine.physics_ticks_per_second == floor_rate,
		"headless there is no display, so the tick is the floor (%d)" % Engine.physics_ticks_per_second)
	_check(Engine.max_physics_steps_per_frame == Balance.PHYSICS_STEPS_PER_FRAME_MAX,
		"a slow frame may catch up on the physics clock")
	_check(Graphics.FPS_CHOICES.has(144) and Graphics.FPS_CHOICES.has(240),
		"the frame cap offers the high refresh rates")
	var sorted: bool = true
	for i: int in range(1, Graphics.FPS_CHOICES.size()):
		if Graphics.FPS_CHOICES[i] <= Graphics.FPS_CHOICES[i - 1]:
			sorted = false
	_check(sorted, "the frame cap choices climb")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


# --- The lamps on loot are budgeted --------------------------------------------

## Thirty pieces that each want a lamp: no more than `LOOT_LIGHT_MAX` carry
## one, the first to land keep theirs, and a piece leaving the field hands
## its lamp back for the next.
func _test_the_lamps_on_loot_are_budgeted() -> void:
	Graphics.apply_preset(Graphics.PRESET_HIGH)
	var before: int = LightKit.drop_lights()
	var pieces: Array[LootDrop] = []
	for i: int in 30:
		var piece := LootDrop.new()
		piece.currency = RunState.GOLD
		piece.amount = 5
		piece.lead = true
		piece.position = Vector2(float(i) * 30.0, 0.0)
		_world.add_child(piece)
		pieces.append(piece)
	var lamps: int = 0
	var first_lit: bool = true
	for i: int in pieces.size():
		var lamp: Variant = pieces[i].get("_lamp")
		if lamp != null:
			lamps += 1
		elif i < Balance.LOOT_LIGHT_MAX - before:
			first_lit = false
	_check(lamps <= Balance.LOOT_LIGHT_MAX,
		"thirty lit pieces carry %d lamps against a budget of %d" % [lamps, Balance.LOOT_LIGHT_MAX])
	_check(lamps == Balance.LOOT_LIGHT_MAX - before and first_lit,
		"the first to land should keep their lamps (%d lit, %d already out)" % [lamps, before])
	pieces[0].free()
	pieces.remove_at(0)
	var late := LootDrop.new()
	late.currency = RunState.GOLD
	late.amount = 5
	late.lead = true
	_world.add_child(late)
	_check(late.get("_lamp") != null, "a piece leaving the field should hand its lamp to the next")
	late.free()
	for piece: LootDrop in pieces:
		piece.free()
	_check(LightKit.drop_lights() == before,
		"every lamp should be given back (%d still out)" % (LightKit.drop_lights() - before))
	Graphics.apply_preset(Graphics.PRESET_LOW)
	var dark := LootDrop.new()
	dark.currency = RunState.GOLD
	dark.amount = 5
	dark.lead = true
	_world.add_child(dark)
	_check(dark.get("_lamp") == null, "Low should light no drop")
	dark.free()
	Graphics.apply_preset(Graphics.PRESET_HIGH)
	await get_tree().process_frame


# --- The roster is gathered once a frame ---------------------------------------

## Two calls in one frame walk the group once; a body that starts dying between
## them is still refused; the next frame gathers again.
## **A health bar is one canvas item** (2026-09-24): the scene's rects are
## read and freed in `_ready`, and the frame is filled rects rather than
## polylines. Held by counting the bar's children after a frame and by a
## source walk, because the polyline is the half a count cannot see.
func _test_a_bar_is_one_item() -> void:
	var bar: HealthBar = (load("res://scenes/ui/health_bar.tscn") as PackedScene).instantiate() as HealthBar
	_world.add_child(bar)
	await get_tree().process_frame
	_check(bar.get_child_count() == 0,
		"a health bar should own no child items, it owns %d" % bar.get_child_count())
	var source: String = FileAccess.get_file_as_string("res://scenes/ui/health_bar.gd")
	_check(source.find("draw_line(") < 0 and source.find(", false, 1.0)") < 0,
		"a health bar's frame must be filled rects, never a polyline")
	bar.queue_free()


## **The ink ages on its redraw clock** (2026-09-24): five short frames bank
## their delta and step nothing, and the next tick steps by all of it.
func _test_the_ink_ages_on_its_clock() -> void:
	var ink := VfxInk.new(false)
	_world.add_child(ink)
	ink.dust(Vector2.ZERO, Vector2.RIGHT * 10.0, Color.WHITE, 5.0, 2.0, 1.0, false)
	var records: Array = ink.get("_dust")
	_check(records.size() == 1, "one dust record was written")
	if records.size() == 1:
		var tick: float = 1.0 / Balance.VFX_INK_HZ
		var small: float = tick * 0.12
		for _frame: int in 5:
			ink._process(small)
		var banked: float = float((records[0] as Dictionary)["age"])
		_check(banked <= small + 0.0001,
			"five short frames should bank their delta, not spend it (aged %.4f)" % banked)
		ink._process(tick)
		var stepped: float = float((records[0] as Dictionary)["age"])
		_check(is_equal_approx(stepped, small * 5.0 + tick),
			"the tick should step by everything banked (aged %.4f, wanted %.4f)"
				% [stepped, small * 5.0 + tick])
	ink.queue_free()


func _test_the_roster_is_gathered_once_a_frame() -> void:
	var field := EnemyField.new()
	_world.add_child(field)
	var first: Array[Enemy] = field.living_bodies()
	var again: Array[Enemy] = field.living_bodies()
	_check(first == again and field.get("_roster_frame") == Engine.get_process_frames(),
		"two asks in one frame should read one roster")
	var near: Array[Enemy] = field.enemies_near(Vector2.ZERO, 1.0e6)
	_check(near.size() == first.size(), "enemies_near reads the roster (%d against %d)"
		% [near.size(), first.size()])
	field.free()
