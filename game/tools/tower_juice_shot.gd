extends Node

## Photographs the five shot styles in the air: a bolt, a lob, a lance, a
## spray and a chain, one tower each in a row, firing at bodies stood in
## front of them, with the towers' own airs playing. Diagnostic only, never a
## gate - the gate is `tower_juice_check`, which reads the damage; this is
## what a person looks at to say whether a lob reads as a lob.
##
##   godot --path game res://tools/tower_juice_shot.tscn
##
## Four frames land in `user://` as `tower_juice_<n>.png`, a third of a second
## apart, so a shot is caught leaving, flying and landing.

const TOWERS: PackedStringArray = ["ember_spire", "pyre_cannon", "rime_lance", "hailcaster", "arc_coil",
	"barrow_stake", "quake", "scree_gun"]

var _field: Battlefield = null


func _ready() -> void:
	RunState.reset(false, 20260914)
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
		push_error("[tower-juice] no battlefield or hero")
		get_tree().quit(1)
		return
	if _field.wave_director != null:
		_field.wave_director.stop()
	_field.sky().events_enabled = false
	if _field.fog() != null:
		_field.fog().reveal_all()
	RunState.gain_every_currency(50000)
	# A cluster of towers in lane 0's pocket - the field's own free-anchor
	# search hands out adjacent plots - and a body in front of each.
	var centre: Vector2 = _field.grid.lane_pocket_centre(0)
	var built: Array[Tower] = []
	for id: String in TOWERS:
		var data: TowerData = ContentDB.tower(id)
		if data == null:
			continue
		var anchor: Vector2i = _field.free_anchor_near(0, 10)
		if not _field.try_build(anchor, data).is_empty():
			continue
		await get_tree().process_frame
		for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
			var tower := node as Tower
			if tower != null and tower.anchor == anchor:
				built.append(tower)
	var breed: EnemyData = ContentDB.enemy("bogkin")
	for tower: Tower in built:
		var body: Enemy = _field.spawn_enemy(breed, 0, 80.0, -1.0, 0.001)
		if body != null:
			body.global_position = tower.origin() + Vector2(0.0, 260.0)
	_field.hero.global_position = centre + Vector2(0.0, 120.0)
	for _f: int in 30:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.effect_root.process_mode = Node.PROCESS_MODE_INHERIT
	for n: int in 4:
		for _f: int in 20:
			await get_tree().process_frame
		var path: String = "user://tower_juice_%d.png" % n
		get_viewport().get_texture().get_image().save_png(path)
		print("[tower-juice] %d -> %s" % [n, ProjectSettings.globalize_path(path)])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
