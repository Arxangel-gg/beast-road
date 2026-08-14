extends Node

## Loads every `.tres` in /data once, at boot, and hands them out by id.
##
## This is what makes "adding content means adding a file" true in practice: no
## script anywhere names a piece of content, they ask this for one. If you find
## yourself writing `if tower_id == "bulwark"`, the answer is a field on
## TowerData instead.

var towers: Dictionary = {}
var enemies: Dictionary = {}
var relics: Dictionary = {}
var spells: Dictionary = {}
var terrains: Dictionary = {}
var buildings: Dictionary = {}
var captives: Dictionary = {}
var wave_archetypes: Dictionary = {}
var discipline_nodes: Dictionary = {}
var factions: Dictionary = {}
var roads: Dictionary = {}
var road_difficulties: Dictionary = {}

## Combination towers, kept separately because they are looked up by element
## pair rather than by id.
var combinations: Array[TowerData] = []


func _ready() -> void:
	towers = _load_dir("res://data/towers")
	enemies = _load_dir("res://data/enemies")
	relics = _load_dir("res://data/relics")
	spells = _load_dir("res://data/spells")
	terrains = _load_dir("res://data/terrains")
	buildings = _load_dir("res://data/buildings")
	captives = _load_dir("res://data/captives")
	wave_archetypes = _load_dir("res://data/waves")
	discipline_nodes = _load_dir("res://data/disciplines")
	factions = _load_dir("res://data/factions")
	roads = _load_dir("res://data/roads")
	road_difficulties = _load_dir("res://data/road_difficulties")

	for value: Variant in towers.values():
		var tower := value as TowerData
		if tower != null and tower.is_combination:
			combinations.append(tower)


func tower(id: String) -> TowerData:
	return towers.get(id, null) as TowerData


func enemy(id: String) -> EnemyData:
	return enemies.get(id, null) as EnemyData


func relic(id: String) -> RelicData:
	return relics.get(id, null) as RelicData


func terrain(id: String) -> TerrainData:
	return terrains.get(id, null) as TerrainData


func building(id: String) -> BuildingData:
	return buildings.get(id, null) as BuildingData


func captive(id: String) -> CaptiveData:
	return captives.get(id, null) as CaptiveData


func wave_archetype(id: String) -> WaveArchetypeData:
	return wave_archetypes.get(id, null) as WaveArchetypeData


func discipline_node(id: String) -> DisciplineNodeData:
	return discipline_nodes.get(id, null) as DisciplineNodeData


func faction(id: String) -> FactionData:
	return factions.get(id, null) as FactionData


func road(id: String) -> RoadData:
	return roads.get(id, null) as RoadData


func road_difficulty(id: String) -> RoadDifficultyData:
	return road_difficulties.get(id, null) as RoadDifficultyData


func roads_sorted() -> Array[RoadData]:
	var out: Array[RoadData] = []
	for value: Variant in roads.values():
		var road_data := value as RoadData
		if road_data != null:
			out.append(road_data)
	out.sort_custom(func(a: RoadData, b: RoadData) -> bool: return a.id < b.id)
	return out


func road_difficulties_sorted() -> Array[RoadDifficultyData]:
	var out: Array[RoadDifficultyData] = []
	for value: Variant in road_difficulties.values():
		var difficulty := value as RoadDifficultyData
		if difficulty != null:
			out.append(difficulty)
	out.sort_custom(func(a: RoadDifficultyData, b: RoadDifficultyData) -> bool:
		return a.rank < b.rank)
	return out


func discipline_nodes_sorted() -> Array[DisciplineNodeData]:
	var out: Array[DisciplineNodeData] = []
	for value: Variant in discipline_nodes.values():
		var node := value as DisciplineNodeData
		if node != null:
			out.append(node)
	out.sort_custom(func(a: DisciplineNodeData, b: DisciplineNodeData) -> bool:
		if a.mansion_tier != b.mansion_tier:
			return a.mansion_tier < b.mansion_tier
		if a.discipline != b.discipline:
			return a.discipline < b.discipline
		return a.id < b.id)
	return out


func available_wave_archetypes(act: int, act_wave: int) -> Array[WaveArchetypeData]:
	var out: Array[WaveArchetypeData] = []
	for value: Variant in wave_archetypes.values():
		var archetype := value as WaveArchetypeData
		if archetype != null and archetype.is_available(act, act_wave):
			out.append(archetype)
	out.sort_custom(func(a: WaveArchetypeData, b: WaveArchetypeData) -> bool:
		return a.id < b.id)
	return out


## Base towers only — the eight the player can put in an outer or inner slot.
func base_towers() -> Array[TowerData]:
	var out: Array[TowerData] = []
	for value: Variant in towers.values():
		var t := value as TowerData
		if t != null and not t.is_combination:
			out.append(t)
	out.sort_custom(func(a: TowerData, b: TowerData) -> bool: return a.id < b.id)
	return out


## The combination produced by a pair of elements, or null if there is none.
func combination_for(a: TowerData.Element, b: TowerData.Element) -> TowerData:
	for t: TowerData in combinations:
		if t.matches_parents(a, b):
			return t
	return null


func terrain_for_act(act: int) -> TerrainData:
	for value: Variant in terrains.values():
		var t := value as TerrainData
		if t != null and t.act == act:
			return t
	return null


func buildings_sorted() -> Array[BuildingData]:
	var out: Array[BuildingData] = []
	for value: Variant in buildings.values():
		var b := value as BuildingData
		if b != null:
			out.append(b)
	# Town Hall first, then by plot angle, so the town lays out deterministically.
	out.sort_custom(func(a: BuildingData, b: BuildingData) -> bool:
		if a.is_town_hall != b.is_town_hall:
			return a.is_town_hall
		return a.plot_angle_degrees < b.plot_angle_degrees)
	return out


func enemies_of_category(category: EnemyData.Category) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for value: Variant in enemies.values():
		var e := value as EnemyData
		if e != null and e.category == category:
			out.append(e)
	out.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.id < b.id)
	return out


func _load_dir(path: String) -> Dictionary:
	var out: Dictionary = {}
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		# Exported builds rename .tres to .remap; ResourceLoader wants the
		# original path either way.
		if not dir.current_is_dir() and (name.ends_with(".tres") or name.ends_with(".tres.remap")):
			var file: String = path.path_join(name.trim_suffix(".remap"))
			var res: Resource = load(file)
			var data := res as GameData
			if data == null:
				push_warning("ContentDB: %s is not a GameData resource" % file)
			elif data.id.is_empty():
				push_warning("ContentDB: %s has an empty id" % file)
			elif out.has(data.id):
				push_warning("ContentDB: duplicate id '%s' in %s" % [data.id, path])
			else:
				out[data.id] = data
		name = dir.get_next()
	dir.list_dir_end()
	return out
