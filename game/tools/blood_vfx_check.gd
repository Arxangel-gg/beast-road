extends Node

## The gore toggle is cosmetic and local: off creates no blood nodes; on resolves
## the authored manifest asset while leaving the rest of Vfx untouched.

var _failures: int = 0


func _ready() -> void:
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
	Vfx.blood(Vector2.ZERO, Vector2.RIGHT, Balance.VFX_BLOOD_HIT_SIZE)
	var authored: bool = false
	if layer != null:
		for child: Node in layer.get_children():
			var sprite := child as Sprite2D
			if sprite != null and sprite.texture != null \
					and sprite.texture.resource_path == Vfx.BLOOD_ART_PATH:
				authored = true
	_check(authored, "enabled blood must resolve %s" % Vfx.BLOOD_ART_PATH)

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
			var sprite := child as Sprite2D
			if sprite != null and sprite.texture != null \
					and sprite.texture.resource_path == Vfx.BLOOD_ART_PATH \
					and sprite.global_position.is_equal_approx(harmed_at):
				found_at_target = true
	_check(found_at_target, "hero blood must appear on the Warden named by the damage fact")
	_test_persistent_blood()

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
	await get_tree().process_frame
	await get_tree().process_frame
	# Audio decoding is released on its server thread after the voice is stopped;
	# a short wall-clock turn prevents that in-flight decoder from being mistaken
	# for a leaked resource when this tiny gate exits immediately.
	await get_tree().create_timer(0.25).timeout
	if _failures == 0:
		print("[blood-vfx] PASS — authored blood obeys the local gore toggle")
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


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[blood-vfx] %s" % message)
