extends Node

## Photographs the families: a courting pair with their hearts, a mother with
## a cub beside her, a shiny cub, and an animal the Wildblight is taking -
## first its warning, then the frenzy. Diagnostic only, never a gate.
##
##   godot --path game res://tools/wildlife_family_shot.tscn
##
## Each frame lands in `user://` as `family_<what>.png`, with a crop around
## the animals as `family_<what>_close.png`, because the brief asks for these
## looked at "at normal gameplay zoom" and a 64px animal on a 2560px frame is
## not something a person can judge.

var _field: Battlefield = null
var _animals: Wildlife = null
var _families: WildlifeFamilies = null
var _at: Vector2 = Vector2.ZERO
## What the next photograph is of, so the crop frames it.
var _aim: Vector2 = Vector2.ZERO


func _aim_at(animal: Dictionary) -> void:
	var body := animal.get("sprite", null) as Sprite2D
	_aim = body.global_position if body != null and is_instance_valid(body) else _at


func _ready() -> void:
	RunState.reset(false, 20260914)
	GameDirector.run_active = true
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 12:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	run.call("switch_scope", GameDirector.Scope.BATTLEFIELD)
	if run.hud != null:
		run.hud.visible = false
	for _f: int in 12:
		await get_tree().process_frame
	_field = run.get("battlefield") as Battlefield
	_animals = _field.wildlife() if _field != null else null
	_families = _animals.families() if _animals != null else null
	if _field == null or _animals == null or _families == null:
		push_error("[family] no field, wildlife or families")
		get_tree().quit(1)
		return
	_field.sky().events_enabled = false
	if _field.wave_director != null:
		_field.wave_director.stop()
	if _field.fog() != null:
		_field.fog().reveal_all()
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_camp_mob():
			enemy.queue_free()
	var rig: CameraRig = _field.camera as CameraRig
	if rig != null:
		rig.zoom_by(3)
	await get_tree().process_frame

	var deer: WildlifeData = _kind("deer")
	var rabbit: WildlifeData = _kind("rabbit")

	# A pair courting, hearts up.
	_at = _quiet_ground(deer)
	# **Beside them, not above them.** The camera follows the hero, and at this
	# zoom nine hundred units up put the animals off the bottom of the frame -
	# the first cut photographed four pictures of foliage. Four hundred and
	# thirty is outside a deer's skittish radius and inside the view.
	_field.hero.global_position = _at + Vector2(430.0, 0.0)
	var pair: Array[Dictionary] = []
	for sex: int in 2:
		var one: Dictionary = _animals.spawn_born(deer, _at + Vector2(float(sex) * 150.0, 0.0),
			{"sex": sex, "stage": WildlifeFamilies.Stage.ADULT, "rarity": int(deer.rarity)})
		one["patience"] = 9999.0
		one["court_cooldown"] = 0.0
		one["born_act"] = -1
		pair.append(one)
	var mother: Dictionary = pair[0]
	# The hearts go up at the appraisal, so that is what is waited for.
	for _f: int in 2400:
		await get_tree().process_frame
		var stage: int = int(mother.get("court", 0))
		if stage == WildlifeFamilies.Court.ASSESSING or stage == WildlifeFamilies.Court.MATING:
			break
	_aim_at(mother)
	await _shoot("courting")

	# A mother with a cub, and a shiny one beside it.
	_animals.clear()
	await get_tree().process_frame
	var hind: Dictionary = _animals.spawn_born(deer, _at,
		{"sex": 0, "stage": WildlifeFamilies.Stage.ADULT, "rarity": int(deer.rarity)})
	hind["patience"] = 9999.0
	var cub: Dictionary = _animals.spawn_born(deer, _at + Vector2(90.0, 30.0),
		{"sex": 1, "stage": WildlifeFamilies.Stage.BABY, "rarity": int(deer.rarity),
		"parents": [int(hind["net_id"]), 0], "born_act": RunState.act})
	cub["patience"] = 9999.0
	var shiny: Dictionary = _animals.spawn_born(deer, _at + Vector2(-110.0, 40.0),
		{"sex": 0, "stage": WildlifeFamilies.Stage.BABY, "shiny": true,
		"rarity": WildlifeData.Rarity.RARE,
		"parents": [int(hind["net_id"]), 0], "born_act": RunState.act})
	shiny["patience"] = 9999.0
	for _f: int in 40:
		await get_tree().process_frame
	_aim_at(hind)
	await _shoot("family")

	# The Wildblight: the warning, and then the frenzy.
	_animals.clear()
	await get_tree().process_frame
	RunState.wave_number = Balance.WILDBLIGHT_OPENING_WAVES + 1
	var sick: Dictionary = _animals.spawn_born(rabbit, _at,
		{"stage": WildlifeFamilies.Stage.ADULT})
	sick["patience"] = 9999.0
	_families.call("_try_sicken", sick, sick["sprite"], rabbit, true)
	for _f: int in 20:
		await get_tree().process_frame
	_aim_at(sick)
	await _shoot("warning")
	sick["blight_left"] = 0.01
	for _f: int in 30:
		await get_tree().process_frame
	_aim_at(sick)
	await _shoot("frenzy")

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


func _kind(id: String) -> WildlifeData:
	for kind: WildlifeData in ContentDB.wildlife():
		if kind.id == id:
			return kind
	return null


func _quiet_ground(kind: WildlifeData) -> Vector2:
	var margin: float = maxf(kind.skittish_radius, 400.0) + 260.0
	var best: Vector2 = Vector2.ZERO
	var best_gap: float = -1.0
	for _try: int in 60:
		var spot: Vector2 = _animals.call("_clear_point")
		if spot == Vector2.ZERO:
			continue
		var gap: float = INF
		for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
			var body := node as Node2D
			if body != null and is_instance_valid(body):
				gap = minf(gap, spot.distance_to(body.global_position))
		if gap > best_gap:
			best_gap = gap
			best = spot
		if gap >= margin:
			return spot
	return best


func _shoot(what: String) -> void:
	for _f: int in 6:
		await get_tree().process_frame
	var frame: Image = get_viewport().get_texture().get_image()
	frame.save_png("user://family_%s.png" % what)
	# Aimed at what the shot is of rather than at the spot it was asked for, and
	# **clamped into the frame rather than intersected with it**: a box wholly
	# outside intersects to nothing, and the first cut of this silently wrote
	# no close-ups at all.
	var on_screen: Vector2 = get_viewport().get_canvas_transform() * _aim
	on_screen *= Vector2(frame.get_size()) / get_viewport().get_visible_rect().size
	var size := Vector2i(620, 460)
	var origin := Vector2i(on_screen) - size / 2
	origin.x = clampi(origin.x, 0, maxi(frame.get_width() - size.x, 0))
	origin.y = clampi(origin.y, 0, maxi(frame.get_height() - size.y, 0))
	var box := Rect2i(origin, size).intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	if box.size.x > 0 and box.size.y > 0:
		frame.get_region(box).save_png("user://family_%s_close.png" % what)
	print("[family] %s -> %s" % [what,
		ProjectSettings.globalize_path("user://family_%s.png" % what)])
