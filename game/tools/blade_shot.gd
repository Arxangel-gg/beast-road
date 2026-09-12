extends Node2D

## Photographs the blade sweep mid-swing so its trail can be looked at.
## Diagnostic only, never a gate.
##
##   godot --path game --fixed-fps 60 res://tools/blade_shot.tscn
##
## `weapon_vfx_check` proves the ribbon exists and cleans up; nothing automatic
## can say whether the steel reaches the end of its own smear or whether the
## strip ends in a hard edge. The owner reported both (2026-09-11), so the
## sweep is fired at three points of its life and each is written out.
##
## `--fixed-fps 60` matters: the sweep is a tween on real time, and a frame
## count is only a time if the frames are the same length.

const FRAMES: Array[int] = [2, 5, 9, 14]


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	var world := Node2D.new()
	add_child(world)
	Vfx.bind_world(world)
	RenderingServer.set_default_clear_color(Color(0.10, 0.12, 0.11))
	# The starting weapon, worn, so the sweep draws the sword the player sees.
	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.settings[MetaState.STARTING_GEAR_KEY] = false
	MetaState._seed_starting_gear()
	var at := Vector2(480.0, 400.0)
	var finisher := Vector2(1280.0, 400.0)
	var reach: float = Balance.HERO_ATTACK_RANGE[0]
	var arc: float = Balance.HERO_ATTACK_ARC_DEGREES[0]
	var last: float = Balance.HERO_ATTACK_RANGE[Balance.HERO_CHAIN_LENGTH - 1]
	var last_arc: float = Balance.HERO_ATTACK_ARC_DEGREES[Balance.HERO_CHAIN_LENGTH - 1]
	EventBus.hero_swing_resolved.emit(at, Vector2.RIGHT, reach, 0)
	EventBus.hero_swing_resolved.emit(finisher, Vector2.RIGHT.rotated(-0.6), last, 2)
	var frame: int = 0
	var out_dir: String = OS.get_environment("SHOT_DIR")
	if out_dir.is_empty():
		out_dir = "user://"
	for target: int in FRAMES:
		while frame < target:
			await get_tree().process_frame
			frame += 1
		await RenderingServer.frame_post_draw
		var path: String = out_dir.path_join("blade_shot_%02d.png" % target)
		get_viewport().get_texture().get_image().save_png(path)
		print("[blade-shot] frame %d (%.0f%% of the sweep, arc %.0f/%.0f) -> %s"
			% [target, 100.0 * float(target) / (60.0 * Balance.VFX_SLASH_LIFE
				* Balance.VFX_BLADE_LIFE_SCALE), arc, last_arc,
				ProjectSettings.globalize_path(path)])
	Vfx.clear()
	Vfx.bind_world(null)
	Sfx.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)
