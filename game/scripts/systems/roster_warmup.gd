class_name RosterWarmup
extends RefCounted

## Loads what an act will draw before it draws it.
##
## Measured 2026-09-14 on an RTX 3070 Ti: `perf_check` counted 12.5 hitches a
## minute over 33 ms against a budget of 3, with the average frame sitting
## on vsync. The first spawn of every breed loaded its thirteen frames from
## disk mid-wave, every wildlife kind did the same on arrival, and each
## shader compiled on the first frame that drew it - all of them stalls a
## player feels as stutter in a fight. `ResourceLoader` caches what it has
## loaded, so the fix is to have loaded it already: the region's breeds, its
## elites and its boss, the wildlife, the towers, and every shader, during
## Preparation, where a stall is a loading beat and not a hitch.
##
## Static, and idempotent: a second call for the same act is a dictionary
## of cache hits. Nothing here is kept - the cache is the loader's.

const SHADER_DIR: String = "res://scripts/shaders"

## Every path the warm-up has loaded this process, with the instance it got.
## Kept so a gate can prove a frame was loaded *before* the act and that a
## later load is the same instance - `ResourceLoader.has_cached` answers by
## the remapped import path for a texture, which is not the path anyone
## asks for.
static var warmed: Dictionary = {}


## Every frame the act's roster can draw, loaded. Returns how many textures
## the loader now holds for it, for the gate.
static func warm_act(act: int, terrain_id: String) -> int:
	var loaded: int = 0
	var ids: Array[String] = []
	var terrain: TerrainData = ContentDB.terrain(terrain_id)
	if terrain != null:
		ids.append_array(terrain.enemy_ids)
		ids.append_array(terrain.elite_ids)
		# The invaders from other roads walk this one too (2026-09-24): a wave
		# of veterans on Act X loaded nine megabytes of frames mid-fight.
		for id: String in terrain.veteran_ids:
			if not ids.has(id):
				ids.append(id)
		if not terrain.boss_id.is_empty():
			ids.append(terrain.boss_id)
	# And the camps' own breeds and lords, which no region's roster names.
	for category: int in [EnemyData.Category.CAMP_BREED, EnemyData.Category.CAMP_LORD]:
		for data: EnemyData in ContentDB.enemies_of_category(category):
			if not ids.has(data.id):
				ids.append(data.id)
	# Any elite may be dealt when a region names none of its own.
	for data: EnemyData in ContentDB.enemies_of_category(EnemyData.Category.ELITE):
		if not ids.has(data.id):
			ids.append(data.id)
	for id: String in ids:
		var data: EnemyData = ContentDB.enemy(id)
		if data != null:
			loaded += _warm_body(data.get_sprite_path(), false)
	# The wildlife is a preference by act rather than a gate, so every kind
	# can arrive; small, and loaded once for the run.
	for kind: WildlifeData in ContentDB.wildlife():
		if kind != null and kind.roll_weight(act) > 0.0:
			loaded += _warm_body(kind.get_sprite_path(), true)
	for value: Variant in ContentDB.towers.values():
		var tower := value as TowerData
		if tower != null:
			loaded += _warm_body(tower.get_sprite_path(), false)
	loaded += warm_saddled_mount()
	loaded += Vfx.warm_art()
	# The flames' ring of meshes, so the first flame drawn in an act is not
	# forty-eight meshes built inside a frame.
	loaded += (Flame.shape_ring()["meshes"] as Array).size()
	return loaded


## **The horse the Warden is carrying the key to.**
##
## A mount's three sheets are the largest single thing a player can ask this
## game to draw on a frame's notice - an idle, a walk and a gallop, each eight
## facings - and nothing else reaches for them until the mount key is pressed.
## Left cold, the first press of that key is a disk load in the middle of
## whatever the player pressed it to get away from, which is exactly the
## stutter `perf_check` found in every first wave of every act on 2026-09-14
## and the reason this class exists at all.
##
## **Only the saddled one.** The stable may hold four and the Warden rides one;
## warming the rest is three sheets of somebody else's horse in memory for the
## length of a run. Saddling a different mount happens at the Hold, between
## runs, where a load costs nobody anything.
static func warm_saddled_mount() -> int:
	var kind: MountData = MetaState.saddled_mount()
	if kind == null:
		return 0
	var loaded: int = 0
	loaded += _warm_frame(kind.get_sprite_path())
	for state: String in MountRig.STATES:
		loaded += _warm_frame("res://art/mounts/mount_%s_%s.png"
			% [kind.id, state])
	return loaded


## One texture, if it is there. A missing sheet is a mount that falls back to
## a stiller picture rather than a hole - see `MountRig` - so it is not an
## error here either.
static func _warm_frame(path: String) -> int:
	if path.is_empty() or not ResourceLoader.exists(path):
		return 0
	var texture: Resource = load(path)
	if texture == null:
		return 0
	# **Kept, not merely loaded.** `warmed` is what holds the reference: a
	# texture loaded and dropped on the next line is collected immediately and
	# the load happens again the moment anybody asks - so the warm-up would
	# have cost a disk read and bought nothing. `warmup_check` named it.
	warmed[path] = texture
	return 1


## One body's frames: the base, the idle, the walk, the attack, and for the
## animals the flight and the graze.
static func _warm_body(path: String, animal: bool) -> int:
	if path.is_empty() or not ResourceLoader.exists(path):
		return 0
	var count: int = 0
	var base: Resource = load(path)
	if base != null:
		warmed[path] = base
		count += 1
	for state: String in (["idle", "move", "attack", "fly", "graze"] if animal else ["idle", "move", "attack"]):
		for index: int in range(1, 9):
			var frame: String = "%s_%s_%02d.png" % [path.get_basename(), state, index]
			if not ResourceLoader.exists(frame):
				break
			var texture: Resource = load(frame)
			if texture != null:
				warmed[frame] = texture
				count += 1
	return count


## Every shader on disk, loaded and drawn once on a speck under `host`, so
## the compile happens now and not on the first frame of a flood. Nothing
## to compile headless, where it is a parse and a no-op. Returns the count.
static func warm_shaders(host: Node) -> int:
	var count: int = 0
	var dir: DirAccess = DirAccess.open(SHADER_DIR)
	if dir == null:
		return 0
	var layer := CanvasLayer.new()
	layer.name = "ShaderWarmup"
	layer.layer = -100
	host.add_child(layer)
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.ends_with(".gdshader"):
			var shader := load(SHADER_DIR.path_join(name)) as Shader
			if shader != null:
				var speck := ColorRect.new()
				speck.size = Vector2(2.0, 2.0)
				speck.position = Vector2(-8.0, -8.0)
				speck.modulate = Color(1.0, 1.0, 1.0, 0.02)
				speck.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var material := ShaderMaterial.new()
				material.shader = shader
				speck.material = material
				layer.add_child(speck)
				count += 1
		name = dir.get_next()
	dir.list_dir_end()
	# Two frames drawn, then gone. The compile is what was wanted.
	var tree: SceneTree = host.get_tree()
	if tree != null:
		tree.create_timer(0.1).timeout.connect(layer.queue_free)
	else:
		layer.queue_free()
	return count
