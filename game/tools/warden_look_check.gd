extends Node

## The Warden's look changes nothing but how the Warden looks.
##
##   godot --headless --path game res://tools/warden_look_check.tscn
##
## Owner ruling, 2026-09-21: character customization is approved, with its
## bound written before the code - it may change *nothing but how the Warden
## looks*. This project has refused a third power scale a dozen times, and a
## cosmetic that reached a number would be one arriving through a settings
## screen. So the hardest thing here is the bound: a real hero is dressed and
## every attribute, its speed and its pool are read back unchanged.
##
## The rest is what a look has to survive: a save (JSON, which has no
## integers and may hold anything), a packet (two numbers, possibly short or
## wrong), and the three kinds of sprite it is drawn on - one wearing the
## hero's blood shader, one wearing nothing, and one wearing somebody else's
## material, which it must leave alone.
##
## **The ways this goes wrong:** a dye that moves an attribute, a save that
## comes back plain, a value past the wheel, a packet that errors instead of
## drawing the painted Warden, and a material replaced under a sprite that
## needed it.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_clean_and_pack()
	_test_the_save_round_trip()
	_test_the_three_sprites()
	_test_the_shader_is_wired()
	await _test_the_bound()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[look] PASS - %d checks: a look survives the save and the wire, "
			+ "dresses every sprite it should and none it should not, and moves "
			+ "no number") % _checks)
	else:
		push_error("[look] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _test_clean_and_pack() -> void:
	_check(WardenLook.is_plain(WardenLook.clean("nonsense")),
		"garbage must clean to the painted Warden")
	_check(WardenLook.is_plain(WardenLook.clean({"hat": 3})),
		"an unknown key must be dropped, not kept")
	var wide: Dictionary = WardenLook.clean({"cloak": 9.0, "sash": -4})
	_check(is_equal_approx(float(wide["cloak"]), WardenLook.RANGE)
		and is_equal_approx(float(wide["sash"]), -WardenLook.RANGE),
		"a value past the wheel must be held to it, got %s" % str(wide))
	_check(is_equal_approx(float(WardenLook.clean({"cloak": 1}).get("cloak")), 0.5)
		or is_equal_approx(float(WardenLook.clean({"cloak": 0.2}).get("cloak")), 0.2),
		"an integer is a number too")
	var packed: Array = WardenLook.pack({"cloak": 0.25, "sash": -0.1})
	_check(packed.size() == 2 and is_equal_approx(float(packed[0]), 0.25)
		and is_equal_approx(float(packed[1]), -0.1),
		"pack must give the two numbers in key order, got %s" % str(packed))
	_check(WardenLook.same(WardenLook.unpack(packed), {"cloak": 0.25, "sash": -0.1}),
		"unpack must undo pack")
	_check(WardenLook.is_plain(WardenLook.unpack("x")),
		"a packet that is not an array is the painted Warden, not an error")
	_check(WardenLook.is_plain(WardenLook.unpack([])),
		"an empty packet is the painted Warden")
	var short: Dictionary = WardenLook.unpack([0.3])
	_check(is_equal_approx(float(short["cloak"]), 0.3) and is_equal_approx(float(short["sash"]), 0.0),
		"a short packet dyes what it names and nothing else, got %s" % str(short))
	var long: Dictionary = WardenLook.unpack([0.1, 0.2, 0.3, "extra"])
	_check(is_equal_approx(float(long["sash"]), 0.2),
		"a long packet is read for its first two numbers")


func _test_the_save_round_trip() -> void:
	var kept: Dictionary = MetaState.look.duplicate()
	MetaState.set_look("cloak", 0.25)
	MetaState.set_look("sash", -0.1)
	MetaState.set_look("hat", 0.4)
	_check(WardenLook.same(MetaState.look, {"cloak": 0.25, "sash": -0.1}),
		"set_look must write the two dyes and refuse a third, got %s" % str(MetaState.look))
	MetaState.set_look("cloak", 7.0)
	_check(is_equal_approx(float(MetaState.look["cloak"]), WardenLook.RANGE),
		"set_look must clamp, got %s" % str(MetaState.look))
	MetaState.set_look("cloak", 0.25)
	var text: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary and (parsed as Dictionary).has("look"),
		"the save must carry the look")
	# Through the real loader, on the save's own JSON, which has no integers.
	MetaState.look = {}
	MetaState.adopt_save(parsed as Dictionary)
	_check(WardenLook.same(MetaState.look, {"cloak": 0.25, "sash": -0.1}),
		"the look must come back off the save, got %s" % str(MetaState.look))
	# A save from before the look reads as the painted Warden.
	var older: Dictionary = (parsed as Dictionary).duplicate(true)
	older.erase("look")
	MetaState.adopt_save(older)
	_check(WardenLook.is_plain(MetaState.look),
		"a save without a look must read as the painted Warden, got %s" % str(MetaState.look))
	MetaState.look = kept


func _test_the_three_sprites() -> void:
	# Wearing nothing, and dyed: the standalone shader goes on.
	var bare := Sprite2D.new()
	add_child(bare)
	WardenLook.dress(bare, WardenLook.plain())
	_check(bare.material == null,
		"a plain look on a bare sprite must cost no material at all")
	WardenLook.dress(bare, {"cloak": 0.3, "sash": -0.2})
	var worn := bare.material as ShaderMaterial
	_check(worn != null and worn.shader != null
		and worn.shader.resource_path == WardenLook.SHADER_PATH,
		"a dyed bare sprite must wear the look shader")
	_check(worn != null and is_equal_approx(float(worn.get_shader_parameter("look_cloak")), 0.3)
		and is_equal_approx(float(worn.get_shader_parameter("look_sash")), -0.2),
		"the dye must reach the material's uniforms")
	bare.queue_free()

	# Wearing the hero's blood shader: the dye is set there and the material
	# is kept, because a sprite has one material and the blood is in it.
	var hero_sprite := Sprite2D.new()
	add_child(hero_sprite)
	var blood: ShaderMaterial = BloodStain.attach(hero_sprite, 7)
	_check(blood != null, "the blood shader must attach to a bare sprite")
	WardenLook.dress(hero_sprite, {"cloak": -0.4, "sash": 0.1})
	_check(hero_sprite.material == blood,
		"dressing a sprite that wears the blood shader must keep that material")
	_check(blood != null and is_equal_approx(float(blood.get_shader_parameter("look_cloak")), -0.4),
		"the dye must be set on the blood shader's own uniform")
	hero_sprite.queue_free()

	# Wearing somebody else's material: left exactly alone.
	var other := Sprite2D.new()
	add_child(other)
	var foreign := CanvasItemMaterial.new()
	other.material = foreign
	WardenLook.dress(other, {"cloak": 0.3, "sash": 0.3})
	_check(other.material == foreign,
		"a sprite wearing another material must be left alone")
	other.queue_free()


## Headless cannot compile a shader, so the wiring is read off the source:
## the hero's shader must include the dye and call it.
func _test_the_shader_is_wired() -> void:
	_check(load(WardenLook.SHADER_PATH) is Shader, "the look shader must load")
	var blood_text: String = FileAccess.get_file_as_string(BloodStain.SHADER_PATH)
	_check(blood_text.contains("warden_look.gdshaderinc"),
		"the hero's blood shader must include the dye")
	_check(blood_text.contains("warden_look(COLOR.rgb)"),
		"and call it on the body")
	var include_text: String = FileAccess.get_file_as_string(
		"res://scripts/shaders/warden_look.gdshaderinc")
	_check(include_text.contains("uniform float look_cloak")
		and include_text.contains("uniform float look_sash"),
		"the include must declare both dyes")


## **The bound.** A real hero, dressed, and every number it carries read
## back. Measured through the same functions the fight reads - `attribute`,
## `move_speed`, the pool - rather than by asserting the dye touches nothing.
func _test_the_bound() -> void:
	RunState.reset()
	var hero: Hero = (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	add_child(hero)
	for _frame: int in 3:
		await get_tree().process_frame
	var before: Array = []
	for which: int in RunState.Attribute.size():
		before.append(RunState.attribute(which))
	var speed_before: float = hero.move_speed()
	var pool_before: float = hero.health.max_hp
	var damage_before: float = float(hero.damage_multiplier()) if hero.has_method("damage_multiplier") else 1.0
	hero.wear_look([0.4, -0.3])
	for _frame: int in 3:
		await get_tree().process_frame
	_check(WardenLook.same(hero.look, {"cloak": 0.4, "sash": -0.3}),
		"the hero must wear the look it was told, got %s" % str(hero.look))
	for which: int in RunState.Attribute.size():
		_check(RunState.attribute(which) == int(before[which]),
			"%s moved from %d to %d under a dye - a look may change nothing but the picture"
				% [RunState.ATTRIBUTE_NAMES[which], int(before[which]), RunState.attribute(which)])
	_check(is_equal_approx(hero.move_speed(), speed_before),
		"the hero's speed moved from %.1f to %.1f under a dye" % [speed_before, hero.move_speed()])
	_check(is_equal_approx(hero.health.max_hp, pool_before),
		"the hero's pool moved from %.1f to %.1f under a dye" % [pool_before, hero.health.max_hp])
	if hero.has_method("damage_multiplier"):
		_check(is_equal_approx(float(hero.damage_multiplier()), damage_before),
			"the hero's damage moved under a dye")
	# And the material carries it, so the picture is the one that was told.
	var worn := hero.sprite.material as ShaderMaterial
	_check(worn != null and is_equal_approx(float(worn.get_shader_parameter("look_cloak")), 0.4),
		"the hero's own sprite must carry the dye it was told")
	hero.queue_free()
	await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[look] %s" % why)
