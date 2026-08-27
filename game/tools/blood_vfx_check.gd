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


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[blood-vfx] %s" % message)
