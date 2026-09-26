extends Node

## A light has one writer (2026-09-26).
##
##   godot --headless --path game res://tools/light_writer_check.tscn
##
## Every light `LightKit.add_light` makes gets a `LightDriver`, which writes its
## energy - the day's dimming and a wobble - and since 2026-09-24 does so thirty
## times a second rather than every frame. A campfire also wrote its light's
## energy every frame from its own flicker, so on a fast screen the light was
## the fire's value for five frames and the driver's day-dimmed one for the
## sixth: the menu's fires strobing, which the owner reported as "a glitchy
## jitter that's an eye sore". A tower's upgrade glow was written once and
## erased by the driver's next tick.
##
## - **The fire's light follows the fire, every frame.** A campfire ticked on a
##   fast screen's clock: its light's energy over its own flicker is one number
##   on every frame, never a second one on the frames the driver writes.
## - **An owner's factor survives the driver's tick.** A light scaled through
##   `LightKit.scale_light` keeps that factor after the driver has written.
## - **Nobody else writes it.** A source walk: outside the driver, the kit that
##   makes a light and the impact flash that makes its own, no script assigns a
##   light's energy.

## Where assigning `.energy` is the job rather than a second writer.
const WRITERS: Array[String] = [
	"res://scripts/systems/light_driver.gd",
	"res://scripts/systems/light_kit.gd",
	"res://autoload/Vfx.gd",
]
const ROOTS: Array[String] = ["res://scripts", "res://scenes", "res://autoload"]

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	await _test_the_fire_is_one_light()
	await _test_a_factor_survives_the_tick()
	_test_nobody_else_writes()
	for stage: String in ["fire", "factor", "writers"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[light-writer] PASS - %d checks: a campfire's light follows its flicker on every frame, an owner's factor survives the driver, and nothing else writes a light's energy" % _checks)
	else:
		push_error("[light-writer] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[light-writer] FAIL: %s" % why)


## A campfire and its driver ticked by hand at a 180 Hz screen's clock for two
## seconds - the fire, then the driver, which is the tree's own order. The light
## is read after both, which is what the frame draws.
func _test_the_fire_is_one_light() -> void:
	var fire := CampFire.new()
	add_child(fire)
	await get_tree().process_frame
	fire.set_process(false)
	var driver: LightDriver = null
	var light: PointLight2D = null
	for child: Node in fire.get_children():
		if child is LightDriver:
			driver = child as LightDriver
			driver.set_process(false)
		elif child is PointLight2D:
			light = child as PointLight2D
	_check(driver != null and light != null, "a campfire's light must come with its driver")
	if driver == null or light == null:
		fire.queue_free()
		_reached.append("fire")
		return
	var ratios: Array[float] = []
	var step: float = 1.0 / 180.0
	for _frame: int in 360:
		fire._process_measured(step)
		driver._process_measured(step)
		if fire.flicker() > 0.01:
			ratios.append(light.energy / fire.flicker())
	var low: float = ratios.min()
	var high: float = ratios.max()
	_check(high - low < 0.002,
		"the light over the fire's flicker ran %.3f to %.3f across two seconds - two writers taking turns" % [low, high])
	fire.queue_free()
	await get_tree().process_frame
	_reached.append("fire")


## A light that wobbles, scaled to double by its owner, keeps the double after
## the driver's own tick has written.
func _test_a_factor_survives_the_tick() -> void:
	var holder := Node2D.new()
	add_child(holder)
	var light: PointLight2D = LightKit.add_light(holder, Color.WHITE, 100.0, 1.0, 0.3)
	var driver: LightDriver = null
	for child: Node in holder.get_children():
		if child is LightDriver:
			driver = child as LightDriver
			driver.set_process(false)
	_check(driver != null, "a light made by the kit must come with its driver")
	if driver != null:
		driver._process_measured(0.0)
		var plain: float = light.energy
		LightKit.scale_light(light, 2.0)
		# Past the driver's own clock, so it writes.
		driver._process_measured(1.0 / Balance.FLAME_REDRAW_HZ + 0.001)
		var day: float = lerpf(Balance.LIGHT_DAY_ENERGY, 1.0, DayNight.darkness)
		_check(light.energy >= 2.0 * day * (1.0 - 0.3 * 0.5) - 0.001,
			"after the driver's tick the light is %.3f - the owner's factor of 2 was dropped (unscaled %.3f)"
			% [light.energy, plain])
	holder.queue_free()
	await get_tree().process_frame
	_reached.append("factor")


func _test_nobody_else_writes() -> void:
	var assign := RegEx.create_from_string("[A-Za-z_][A-Za-z_0-9]*\\.energy\\s*[-+*/]?=[^=]")
	var found: int = 0
	for path: String in _scripts():
		if WRITERS.has(path):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		for number: int in lines.size():
			var line: String = lines[number].strip_edges()
			if line.begins_with("#"):
				continue
			if assign.search(line) != null:
				found += 1
				_check(false, "%s:%d writes a light's energy beside its driver: %s" % [path, number + 1, line])
	_check(_scripts().size() > 100, "the walk must read the project's scripts")
	print("[light-writer] %d scripts walked, %d second writers" % [_scripts().size(), found])
	_reached.append("writers")


var _script_list: Array[String] = []


func _scripts() -> Array[String]:
	if _script_list.is_empty():
		for root: String in ROOTS:
			_collect(root)
	return _script_list


func _collect(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			_script_list.append(folder.path_join(file_name))
	for sub: String in dir.get_directories():
		_collect(folder.path_join(sub))
