extends Node

## Renders the build panel so the element rail can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that
	# edits the account must never be able to write it to the player's disk.
	# See `save_guard_check`, which finds these by reading them.
	MetaState.hold_saves()
	# Force a first-time account, so the shot shows the coach card as a new
	# player meets it rather than as a returning one never does.
	MetaState.settings["tutorial_seen"] = false
	RunState.reset()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.gain_every_currency(9999)
	var field: Battlefield = run.battlefield
	var anchor: Vector2i = Vector2i.ZERO
	for y: int in BattleGrid.SIZE:
		for x: int in BattleGrid.SIZE:
			if field.grid.footprint_is_open(Vector2i(x, y)):
				anchor = Vector2i(x, y)
				break
		if anchor != Vector2i.ZERO:
			break
	# **A board behind the player**, so the "Rebuild last board" row is in the
	# picture. It is only offered to somebody who has finished a run, which a
	# shot tool on a fresh account is not - and a row that only ever appears on
	# a veteran's screen is a row nobody photographs.
	var kind: TowerData = ContentDB.unlocked_base_towers().front() as TowerData
	if kind != null:
		var lane: int = 0
		for _made: int in 6:
			var spot: Vector2i = field.free_anchor_near(lane, 8)
			lane = (lane + 1) % maxi(Balance.LANE_COUNT, 1)
			field.try_build(spot, kind)
		MetaState.build_template = BuildTemplate.compose(field)
		for key: Variant in RunState.towers.keys():
			field.try_sell(key as Vector2i)
		RunState.gain_every_currency(9999)
	run.hud.call("_open_build_panel", anchor)
	run.hud.set("_build_element", TowerData.Element.WATER)
	run.hud.call("_refresh_build_panel")
	for _f: int in 8:
		await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png("user://build_panel_shot.png")
	print("[build] shot -> %s" % ProjectSettings.globalize_path("user://build_panel_shot.png"))
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20: await get_tree().process_frame
	get_tree().quit(0)
