extends Node

## Photographs of the 2026-09-12 polish for the eye, not for the guide: the
## field with its fog and minimap, the build panel with its tooltips, a pond
## with its plants and a swimmer, a camp, the town's beds, the beast, a
## battle, the night, and the front door. Written to the scratch directory,
## never to the repository. Run windowed:
##
##   Godot --path game res://tools/phase_shots.tscn

const OUT: String = "C:/Users/Hamed/AppData/Local/Temp/claude/E--Arxangel-GameDev-BeastRoad/32e9c9cb-1491-428b-b139-1034ae2fac29/scratchpad/shots/"
const SIZE := Vector2i(1600, 900)

var run: Run = null
var _written: PackedStringArray = []


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = SIZE
	DirAccess.make_dir_recursive_absolute(OUT)
	RunState.reset(false, 20260912)
	GameDirector.run_active = true
	run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 16:
		await get_tree().process_frame
	RunState.gain_every_currency(2400)
	await _shot("field", func() -> void: pass)
	await _shot("build", func() -> void:
		GameDirector.set_build_mode(true); _build_some(false); _place_trap())
	GameDirector.set_build_mode(false)
	var pond: Vector2 = _pond_centre()
	await _shot("pond", func() -> void: _stand_at(pond + Vector2(0.0, 150.0)); _zoom(1.5))
	await _shot("swim", func() -> void: _stand_at(pond))
	_zoom(0.0)
	await _shot("camp", func() -> void: _stand_at(_camp_centre() + Vector2(0.0, 170.0)))
	_stand_at(Vector2.ZERO)
	await _shot("town", func() -> void: run.switch_scope(GameDirector.Scope.TOWN))
	await _shot("beast", func() -> void: run.switch_scope(GameDirector.Scope.BEAST))
	run.switch_scope(GameDirector.Scope.BATTLEFIELD)
	run.call("_on_ride_on_requested")
	for _f: int in 420:
		await get_tree().process_frame
	await _shot("battle", func() -> void: pass)
	await _shot("night", func() -> void: DayNight.call("_apply", 0.78))
	DayNight.call("_apply", 0.18)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	GameDirector.run_active = false
	var menu: Node = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate()
	add_child(menu)
	await _shot("menu", func() -> void: pass)
	menu.queue_free()
	for _f: int in 10:
		await get_tree().process_frame
	print("[phase-shots] wrote %d pictures to %s" % [_written.size(), OUT])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0)


# --- Set-ups -----------------------------------------------------------------------------

## A couple of towers on legal ground near the town, so the picture shows a
## defence rather than a field.
func _build_some(well: bool) -> void:
	var field: Battlefield = run.battlefield
	var data: TowerData = null
	if well:
		data = ContentDB.tower("healing_well")
	else:
		for id: Variant in ContentDB.towers:
			var candidate: TowerData = ContentDB.towers[id] as TowerData
			if candidate != null and not candidate.is_well():
				data = candidate
				break
	if data == null:
		return
	var built: int = 0
	var middle := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	for ring: int in range(3, 12):
		for dx: int in range(-ring, ring + 1):
			for dy: int in [-ring, ring]:
				for anchor: Vector2i in [middle + Vector2i(dx, dy), middle + Vector2i(dy, dx)]:
					if built >= (1 if well else 3):
						return
					if field.placement_problem(anchor).is_empty():
						if field.try_build(anchor, data).is_empty():
							built += 1
							if built == 1:
								_stand_at(BattleGrid.tile_to_world(anchor) + Vector2(60.0, 40.0))


func _place_trap() -> void:
	var field: Battlefield = run.battlefield
	var data: TrapData = null
	for id: Variant in ContentDB.traps:
		data = ContentDB.traps[id] as TrapData
		if data != null:
			break
	if data == null:
		return
	var middle := Vector2i(BattleGrid.SIZE / 2, BattleGrid.SIZE / 2)
	for ring: int in range(3, 12):
		for dx: int in range(-ring, ring + 1):
			for tile: Vector2i in [middle + Vector2i(dx, -ring), middle + Vector2i(dx, ring)]:
				if field.try_place_trap(tile, data).is_empty():
					_stand_at(BattleGrid.tile_to_world(tile) + Vector2(50.0, 30.0))
					return


func _stand_at(at: Vector2) -> void:
	var hero: Hero = run.battlefield.hero
	if hero != null:
		hero.global_position = at


func _zoom(level: float) -> void:
	var cam: Node = run.battlefield.camera
	if cam != null:
		cam.set("zoom_level", level)


func _pond_centre() -> Vector2:
	var ponds: Variant = run.battlefield.get("_ponds")
	if ponds != null and ponds.has_method("pond_positions"):
		var spots: PackedVector2Array = ponds.pond_positions()
		if not spots.is_empty():
			return spots[0]
	return Vector2(900.0, 900.0)


func _camp_centre() -> Vector2:
	var camps: Camps = run.battlefield.camps()
	if camps != null:
		var sites: Variant = camps.get("_sites")
		if sites is Array and not (sites as Array).is_empty():
			return (sites as Array)[0].get("centre", Vector2.ZERO)
	return Vector2(0.0, -1600.0)


func _barrier_at() -> Vector2:
	var grid: BattleGrid = run.battlefield.grid
	if grid != null and not grid.barriers.is_empty():
		var pair: Array = grid.barriers[0]
		if not pair.is_empty():
			return (pair[0] as Dictionary).get("at", Vector2.ZERO) + Vector2(0.0, 80.0)
	return Vector2(0.0, -1900.0)


func _bond_a_spirit() -> void:
	var key: String = SpiritBond.key("fox", 0, false)
	if not ContentDB.wildlife_kinds.has("fox"):
		for id: Variant in ContentDB.wildlife_kinds:
			key = SpiritBond.key(String(id), 0, false)
			break
	MetaState.spirit_bonded[key] = true
	MetaState.equip_spirit(key)


func _stock_the_stash() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _piece: int in 12:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 1, rng)
		if not piece.is_empty():
			MetaState.receive_gear(piece)
	for id: Variant in ContentDB.fish_kinds:
		MetaState.fish[String(id)] = 2


func _pick_tab(screen: Node, title: String) -> void:
	for node: Node in _walk(screen):
		if node is TabContainer:
			var tabs := node as TabContainer
			for index: int in tabs.get_tab_count():
				if tabs.get_tab_title(index).begins_with(title):
					tabs.current_tab = index
					return
		elif node is Button and (node as Button).text.begins_with(title):
			(node as Button).pressed.emit()
			return


func _open_settings(tab: String) -> void:
	var layer := CanvasLayer.new()
	layer.name = "SettingsShot"
	add_child(layer)
	var panel := SettingsPanel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	layer.add_child(panel)
	panel.position = (Vector2(get_window().size) - panel.size) * 0.5
	_pick_tab(panel, tab)
	panel.position = (Vector2(get_window().size) - panel.size) * 0.5


func _open_coop() -> void:
	for node: Node in get_children():
		if node.name == "SettingsShot":
			node.queue_free()
	var scene: Resource = load("res://scenes/ui/coop_screen.gd")
	if scene == null:
		return
	var screen: Node = (scene as GDScript).new()
	screen.name = "CoopShot"
	add_child(screen)
	if screen.has_method("open"):
		screen.call("open")


func _open_hub() -> void:
	for node: Node in get_children():
		if node.name == "CoopShot":
			node.queue_free()
	var hub: HubScreen = HubScreen.new()
	hub.name = "HubShot"
	add_child(hub)
	if hub.has_method("open"):
		hub.open()


func _walk(node: Node) -> Array[Node]:
	var out: Array[Node] = [node]
	for child: Node in node.get_children():
		out.append_array(_walk(child))
	return out


# --- The camera ---------------------------------------------------------------------------

func _shot(id: String, setup: Callable) -> void:
	setup.call()
	get_tree().paused = false
	for _f: int in 70:
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(OUT + id + ".png")
	_written.append(id)
	print("[guide-shots] %s" % id)


func _copy(from: String, to: String) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(OUT + from + ".png"))
	if image == null:
		return
	image.save_png(OUT + to + ".png")
	_written.append(to)


## A region of a picture, as fractions, blown back up to the picture's size.
func _crop(from: String, to: String, part: Rect2) -> void:
	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(OUT + from + ".png"))
	if image == null:
		return
	var rect := Rect2i(int(part.position.x * image.get_width()), int(part.position.y * image.get_height()),
		int(part.size.x * image.get_width()), int(part.size.y * image.get_height()))
	var piece: Image = image.get_region(rect)
	piece.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
	piece.save_png(OUT + to + ".png")
	_written.append(to)
