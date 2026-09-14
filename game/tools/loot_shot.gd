extends Node

## Photographs a row of drops on the ground, which needs a real renderer.
## Diagnostic only, never a gate.
##
##   godot --path game res://tools/loot_shot.tscn
##
## The spire is a shader and the plate is a frame of text, and neither can be
## looked at headless: `loot_beacon.gdshader` is skipped entirely under the dummy
## renderer, exactly as the city's health ring was - and that one shipped broken.
## See `shader_lint_check` for what a headless gate can and cannot say about a
## shader.
##
## One drop per rarity, plus a coin and a stack of Wood, laid across the field so
## the ladder is readable in one picture: the colour, the height of the column,
## how special the effect gets, and the slot name on the plate.


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	var run: Node = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	for _f: int in 12:
		await get_tree().process_frame
	var field: Node = run.get("battlefield")
	if field == null:
		push_error("[loot] no battlefield")
		get_tree().quit(1)
		return

	var kinds: Array[GearData] = ContentDB.gear_sorted()
	var spread: float = 190.0
	var left: float = -spread * float(Stash.RARITY_NAMES.size() - 1) * 0.5
	for rarity: int in Stash.RARITY_NAMES.size():
		var kind: GearData = kinds[rarity % kinds.size()] as GearData
		if kind == null:
			continue
		var piece: Dictionary = Stash.make(kind.id, rarity, 20)
		field.call("spawn_gear", piece,
			Vector2(left + spread * float(rarity), -60.0), false)
	field.call("spawn_loot", "gold", 40, Vector2(left - spread, 120.0))
	field.call("spawn_loot", "wood", 25, Vector2(left, 120.0))
	for _f: int in 120:
		await get_tree().process_frame
	var path: String = "user://loot_row.png"
	get_viewport().get_texture().get_image().save_png(path)
	print("[loot] %d rarities -> %s"
		% [Stash.RARITY_NAMES.size(), ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	get_tree().quit(0)
