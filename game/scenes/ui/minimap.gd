class_name Minimap
extends Control

## The minimap (owner brief, 2026-09-12): the field at a glance, with the
## roads, the ponds, the rift gates, the camps and their state, the towers,
## the town, every hero and companion, and - only where the party can see -
## the enemies, the elites, the bosses, the wildlife and the loot. Darkened
## by the fog of war's own texture, so what the map knows is exactly what
## the party has seen. Toggled with `toggle_minimap` (M).
##
## Three layers: the still things drawn once (`_draw`), the fog as a child
## rect sampling `FogOfWar.texture()`, and the moving marks on a child that
## redraws every frame over the fog.

var battlefield: Node = null

var _fog_rect: TextureRect = null
var _marks: Control = null
var _frame: Control = null
var _dirty: bool = true
var _still_clock: float = 0.0


func _ready() -> void:
	name = "Minimap"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_fog_rect = TextureRect.new()
	_fog_rect.name = "Fog"
	_fog_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fog_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_fog_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_fog_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_fog_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/shaders/fog_of_war.gdshader")
	material.set_shader_parameter("unexplored", Balance.MINIMAP_UNEXPLORED_ALPHA)
	material.set_shader_parameter("explored", Balance.MINIMAP_EXPLORED_ALPHA)
	_fog_rect.material = material
	add_child(_fog_rect)
	_marks = Control.new()
	_marks.name = "Marks"
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	_frame = Control.new()
	_frame.name = "Frame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.draw.connect(_draw_frame)
	add_child(_frame)
	EventBus.camp_cleared.connect(func(_lane: int, _tier: int) -> void: _dirty = true)
	EventBus.camp_respawned.connect(func(_lane: int, _tier: int) -> void: _dirty = true)
	EventBus.tower_changed.connect(func(_anchor: Vector2i) -> void: _dirty = true)
	EventBus.fork_opened.connect(func(_lane: int) -> void: _dirty = true)
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void: _dirty = true)
	resized.connect(func() -> void: _dirty = true)


func _process(_delta: float) -> void:
	if not visible or battlefield == null or not is_instance_valid(battlefield):
		return
	var fog: FogOfWar = _fog()
	if fog != null and _fog_rect.texture != fog.texture():
		_fog_rect.texture = fog.texture()
	_fog_rect.visible = fog != null and Graphics.fog_of_war()
	# The still things are also redrawn on a slow clock, because a camp that
	# unlocks on a fork or a tower that levels says nothing the map listens to.
	_still_clock -= _delta
	if _dirty or _still_clock <= 0.0:
		_dirty = false
		_still_clock = 1.5
		queue_redraw()
	_marks.queue_redraw()


func _fog() -> FogOfWar:
	if battlefield != null and battlefield.has_method("fog"):
		return battlefield.call("fog") as FogOfWar
	return null


## World to map: the grid's square onto this control's square.
func _to_map(at: Vector2) -> Vector2:
	var half: float = BattleGrid.HALF_EXTENT
	return (at + Vector2.ONE * half) / (half * 2.0) * size


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Balance.MINIMAP_GROUND)
	if battlefield == null or not is_instance_valid(battlefield):
		return
	var grid: BattleGrid = battlefield.get("grid") as BattleGrid
	if grid != null:
		# The core, a shade lighter than the outskirts, so the map has a middle.
		var core: float = BattleGrid.CORE_HALF_EXTENT
		var a: Vector2 = _to_map(Vector2(-core, -core))
		var b: Vector2 = _to_map(Vector2(core, core))
		draw_rect(Rect2(a, b - a), Balance.MINIMAP_CORE)
		var width: float = maxf(size.x / 90.0, 1.5)
		for route: Variant in grid.lane_paths:
			_draw_road(route as PackedVector2Array, width)
		for route: Variant in grid.far_routes:
			if route is Array:
				for leg: Variant in route:
					_draw_road(leg as PackedVector2Array, width * 0.8)
			else:
				_draw_road(route as PackedVector2Array, width * 0.8)
	# Ponds.
	var ponds: Node = battlefield.call("ponds") if battlefield.has_method("ponds") else null
	if ponds != null and ponds.has_method("pond_positions"):
		for at: Vector2 in ponds.call("pond_positions"):
			draw_circle(_to_map(at), maxf(size.x / 56.0, 2.5), Balance.MINIMAP_WATER)
	# Rift gates.
	var gates: Node = battlefield.call("rift_gates") if battlefield.has_method("rift_gates") else null
	if gates != null and gates.has_method("gate_positions"):
		for at: Vector2 in gates.call("gate_positions"):
			_draw_diamond(_to_map(at), maxf(size.x / 60.0, 2.5), Balance.MINIMAP_RIFT)
	# Trees and seams. A worked-out node is drawn dim rather than removed: the
	# player went out there once and should be able to see it is worth going
	# back, which is the whole reason a node respawns at all.
	var patch: Node = battlefield.call("gathering") if battlefield.has_method("gathering") else null
	if patch != null and patch.has_method("node_positions"):
		var spots: PackedVector2Array = patch.call("node_positions")
		var ids: Array[String] = patch.call("node_ids")
		for index: int in spots.size():
			var kind: GatherNodeData = ContentDB.gather_node(ids[index]) 				if index < ids.size() else null
			var spent: bool = bool(patch.call("node_is_spent", index))
			var tint: Color = Balance.MINIMAP_WOOD if kind != null 				and kind.craft == "woodcutter" else Balance.MINIMAP_ORE
			if spent:
				tint = Color(tint, tint.a * 0.35)
			draw_circle(_to_map(spots[index]), maxf(size.x / 76.0, 2.0), tint)
	# **What something mythical left behind.** Only the signs the party has
	# actually walked up to: a map that marked the next one would turn tracking
	# into following a waypoint, which is the whole of what this feature is not.
	# The freshest is drawn brightest, so the map says which way the trail was
	# going without saying where it ends.
	var trail: Node = battlefield.call("trail") if battlefield.has_method("trail") else null
	if trail != null and trail.has_method("report"):
		var walked: Dictionary = trail.call("report")
		var places: Array = walked.get("signs", [])
		var read: int = int(walked.get("stage", 0))
		for index: int in mini(read, places.size()):
			var fade: float = 0.45 + 0.55 * (float(index + 1) / maxf(float(read), 1.0))
			_draw_diamond(_to_map(places[index] as Vector2),
				maxf(size.x / 70.0, 2.0), Color(Balance.MINIMAP_TRAIL,
					Balance.MINIMAP_TRAIL.a * fade))
	# **A clutch on the ground.** Marked because a nest is a place you go back
	# to - it hatches by road walked, so the thing a player wants to know is
	# where it was when they passed it.
	var clutches: Node = battlefield.call("nests") if battlefield.has_method("nests") else null
	if clutches != null and clutches.has_method("report"):
		for nest: Dictionary in clutches.call("report"):
			draw_circle(_to_map(nest["at"] as Vector2),
				maxf(size.x / 78.0, 2.0), Balance.MINIMAP_NEST)
	# Plots and the crops in them: bare earth, growing, ripe. A wilting crop
	# is drawn dim, which is the same tell the plant itself gives.
	var farm: Node = battlefield.call("farming") if battlefield.has_method("farming") else null
	if farm != null and farm.has_method("plot_state"):
		for index: int in int(farm.call("plot_count")):
			var plot: Dictionary = farm.call("plot_state", index)
			var tint: Color = Balance.MINIMAP_PLOT
			if not String(plot.get("crop_id", "")).is_empty():
				tint = Balance.MINIMAP_CROP_RIPE if float(plot.get("growth", 0.0)) >= 1.0 \
					else Balance.MINIMAP_CROP
				if bool(plot.get("wilting", false)):
					tint = Color(tint, tint.a * 0.45)
			var half: float = maxf(size.x / 96.0, 1.5)
			var spot: Vector2 = _to_map(plot["at"] as Vector2)
			draw_rect(Rect2(spot - Vector2.ONE * half, Vector2.ONE * half * 2.0), tint)
	# Camps, by state.
	var camps: Node = battlefield.call("camps") if battlefield.has_method("camps") else null
	if camps != null and camps.has_method("map_marks"):
		for mark: Dictionary in camps.call("map_marks"):
			var at: Vector2 = _to_map(mark["at"] as Vector2)
			var big: bool = bool(mark.get("baron", false))
			var reach: float = maxf(size.x / (36.0 if big else 52.0), 2.5)
			var colour: Color = Balance.MINIMAP_CAMP_ALIVE
			match int(mark.get("state", 0)):
				Camps.State.LOCKED:
					colour = Balance.MINIMAP_CAMP_LOCKED
				Camps.State.RAZED:
					colour = Balance.MINIMAP_CAMP_RAZED
				Camps.State.RESPAWNING:
					colour = Balance.MINIMAP_CAMP_RESPAWNING
			draw_rect(Rect2(at - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), colour)
			if big:
				draw_rect(Rect2(at - Vector2.ONE * reach, Vector2.ONE * reach * 2.0),
					Balance.MINIMAP_FRAME_LIGHT, false, 1.0)
	# The town.
	var town: Node2D = battlefield.get("town") as Node2D
	if town != null:
		draw_circle(_to_map(town.global_position), maxf(size.x / 30.0, 4.0), Balance.MINIMAP_TOWN)
	# Towers.
	for node: Node in get_tree().get_nodes_in_group(Tower.GROUP):
		var tower: Tower = node as Tower
		if tower == null or not is_instance_valid(tower):
			continue
		var at: Vector2 = _to_map(tower.global_position)
		var reach: float = maxf(size.x / 70.0, 2.0)
		draw_rect(Rect2(at - Vector2.ONE * reach, Vector2.ONE * reach * 2.0), Balance.MINIMAP_TOWER)


func _draw_road(route: PackedVector2Array, width: float) -> void:
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for at: Vector2 in route:
		points.append(_to_map(at))
	draw_polyline(points, Balance.MINIMAP_ROAD, width)


func _draw_diamond(at: Vector2, reach: float, colour: Color) -> void:
	draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -reach),
		at + Vector2(reach, 0.0), at + Vector2(0.0, reach), at + Vector2(-reach, 0.0)]), colour)


## The moving marks, over the fog: only what the party can see.
func _draw_marks() -> void:
	if battlefield == null or not is_instance_valid(battlefield):
		return
	var fog: FogOfWar = _fog()
	var tree: SceneTree = get_tree()
	var dot: float = maxf(size.x / 64.0, 2.0)
	# Enemies: seen ones only. Elites larger and warmer, a boss a diamond.
	for node: Node in tree.get_nodes_in_group(Enemy.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy == null or not is_instance_valid(enemy) or not enemy.visible:
			continue
		if enemy.is_dying():
			continue
		if fog != null and not fog.sees(enemy.global_position):
			continue
		var at: Vector2 = _to_map(enemy.global_position)
		if enemy.data != null and enemy.data.category == EnemyData.Category.BOSS:
			_mark_diamond(at, dot * 2.4, Balance.MINIMAP_BOSS)
		elif enemy.rank != Enemy.Rank.COMMON or (enemy.data != null and enemy.data.category == EnemyData.Category.ELITE):
			_marks.draw_circle(at, dot * 1.5, Balance.MINIMAP_ELITE)
		else:
			_marks.draw_circle(at, dot, Balance.MINIMAP_ENEMY)
	# Wildlife, from the system's own list.
	var wildlife: Node = battlefield.call("wildlife_system") if battlefield.has_method("wildlife_system") else null
	if wildlife != null and wildlife.has_method("map_marks"):
		for mark: Dictionary in wildlife.call("map_marks"):
			var where: Vector2 = mark["at"] as Vector2
			if fog != null and not fog.sees(where):
				continue
			var at: Vector2 = _to_map(where)
			var colour: Color = Balance.MINIMAP_WILDLIFE
			if bool(mark.get("rabid", false)):
				colour = Balance.MINIMAP_RABID
			elif bool(mark.get("hostile", false)):
				colour = Balance.MINIMAP_HOSTILE_WILDLIFE
			elif bool(mark.get("hoards", false)):
				colour = Balance.MINIMAP_LOOT
			_marks.draw_circle(at, dot * (1.3 if bool(mark.get("elite", false)) else 0.8), colour)
	# Loot on the ground.
	for node: Node in tree.get_nodes_in_group(LootDrop.GROUP):
		var drop: Node2D = node as Node2D
		if drop == null or not is_instance_valid(drop) or not drop.visible:
			continue
		if fog != null and not fog.sees(drop.global_position):
			continue
		_mark_diamond(_to_map(drop.global_position), dot * 0.9, Balance.MINIMAP_LOOT)
	# Companions, then heroes on top of everything.
	for node: Node in tree.get_nodes_in_group(Companion.GROUP):
		var companion: Node2D = node as Node2D
		if companion == null or not is_instance_valid(companion) or not companion.visible:
			continue
		_marks.draw_circle(_to_map(companion.global_position), dot * 0.9, Balance.MINIMAP_COMPANION)
	if battlefield.has_method("heroes"):
		var local: Node = battlefield.get("hero") as Node
		for who: Node2D in battlefield.call("heroes"):
			if who == null or not is_instance_valid(who) or not who.visible:
				continue
			var at: Vector2 = _to_map(who.global_position)
			var colour: Color = Balance.MINIMAP_HERO if who == local else Balance.MINIMAP_ALLY
			_marks.draw_circle(at, dot * 1.6, Balance.MINIMAP_FRAME_OUTLINE)
			_marks.draw_circle(at, dot * 1.2, colour)


func _mark_diamond(at: Vector2, reach: float, colour: Color) -> void:
	_marks.draw_colored_polygon(PackedVector2Array([at + Vector2(0.0, -reach),
		at + Vector2(reach, 0.0), at + Vector2(0.0, reach), at + Vector2(-reach, 0.0)]), colour)


## The frame, in the same language as the health bars and the panels: a dark
## outline, a lit bevel inside it, a shadowed inner rule, and a bracket at
## each corner. Thin on purpose - it has to say "this is a window" without
## taking room from the map inside it.
##
## **The same frame every picture in the game wears**, rather than this screen's
## own copy of the idea. The owner asked for a thin aesthetic border here and
## then for frames generally, so the drawing moved to `FrameKit` and this became
## one line. The constants below it kept their names and are now unread by
## anything but the marks, which is where the outline colour still belongs.
func _draw_frame() -> void:
	FrameKit.draw_frame(_frame, Rect2(Vector2.ZERO, size))
