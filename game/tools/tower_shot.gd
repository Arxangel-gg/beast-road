extends Node

## Photographs a row of towers on the real field, so a regenerated tower
## can be looked at where it stands rather than on a contact sheet: the
## perspective against the roads, the scale against the hero, the idle
## frames playing. Diagnostic only, never a gate.
##
##   godot --path game res://tools/tower_shot.tscn -- --towers=id,id,...
##
## With no list, the seven regenerated on 2026-09-14. Each frame lands in
## `user://` as `tower_shot_<n>.png`, up to four towers a frame.

const DEFAULT: PackedStringArray = ["ash_thrower", "barrow_stake", "glacier", "hailcaster",
	"rime_ward", "rootcrusher", "scree_gun"]

var _field: Battlefield = null


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	_field = run.get("battlefield") as Battlefield
	if _field == null or _field.hero == null:
		push_error("[tower] no battlefield or hero")
		get_tree().quit(1)
		return
	var ids: PackedStringArray = DEFAULT
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--towers="):
			ids = arg.trim_prefix("--towers=").split(",", false)
	RunState.gain_every_currency(50000)
	var shot: int = 0
	var index: int = 0
	while index < ids.size():
		# Four to a frame, in a row across the lane's pocket, the hero beside them.
		var lane: int = shot % 4
		var centre: Vector2 = _field.grid.lane_pocket_centre(lane)
		var placed: int = 0
		var tries: int = 0
		var cursor: Vector2i = BattleGrid.world_to_tile(centre) - Vector2i(4, 0)
		while placed < 4 and index < ids.size() and tries < 40:
			tries += 1
			var anchor: Vector2i = cursor + Vector2i(tries % 10 * 2 - 8, int(tries / 10) * 3)
			if not _field.placement_problem(anchor).is_empty():
				continue
			var data: TowerData = ContentDB.tower(ids[index])
			if data == null:
				index += 1
				continue
			if _field.try_build(anchor, data).is_empty():
				placed += 1
				index += 1
		_field.hero.global_position = centre + Vector2(0.0, 180.0)
		await _shoot("%d" % shot, 40)
		shot += 1
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _shoot(what: String, settle_frames: int) -> void:
	for _f: int in settle_frames:
		await get_tree().process_frame
	var path: String = "user://tower_shot_%s.png" % what
	get_viewport().get_texture().get_image().save_png(path)
	print("[tower] %s -> %s" % [what, ProjectSettings.globalize_path(path)])
