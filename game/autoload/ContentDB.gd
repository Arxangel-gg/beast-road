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
var items: Dictionary = {}
var spells: Dictionary = {}
var terrains: Dictionary = {}
var buildings: Dictionary = {}
var captives: Dictionary = {}
var wave_archetypes: Dictionary = {}
var weathers: Dictionary = {}
var wildlife_kinds: Dictionary = {}
var companions: Dictionary = {}
var traps: Dictionary = {}
var barricades: Dictionary = {}
var tiers: Dictionary = {}
var gear_kinds: Dictionary = {}

## First-run coach prompts. Content because the strings are player-facing and
## CLAUDE.md keeps those out of scripts.
var tutorial_steps: Dictionary = {}
var discipline_nodes: Dictionary = {}
var factions: Dictionary = {}
var roads: Dictionary = {}
var road_difficulties: Dictionary = {}
var milestone_cinematics: Dictionary = {}
var chronicle_objectives: Dictionary = {}
var run_challenges: Dictionary = {}
var recovery_drops: Dictionary = {}

## Ranged combat and what feeds it (owner decision, 2026-08-31). Blueprints are
## the knowledge; ammo and ranged weapons are what the knowledge makes.
var ranged_weapons: Dictionary = {}
var ammo_kinds: Dictionary = {}
var blueprints: Dictionary = {}

## Combination towers, kept separately because they are looked up by element
## pair rather than by id.
var combinations: Array[TowerData] = []


func _ready() -> void:
	towers = _load_dir("res://data/towers")
	enemies = _load_dir("res://data/enemies")
	relics = _load_dir("res://data/relics")
	spells = _load_dir("res://data/spells")
	terrains = _load_dir("res://data/terrains")
	weathers = _load_dir("res://data/weather")
	wildlife_kinds = _load_dir("res://data/wildlife")
	companions = _load_dir("res://data/companions")
	traps = _load_dir("res://data/traps")
	barricades = _load_dir("res://data/barricades")
	tiers = _load_dir("res://data/tiers")
	gear_kinds = _load_dir("res://data/gear")
	buildings = _load_dir("res://data/buildings")
	captives = _load_dir("res://data/captives")
	wave_archetypes = _load_dir("res://data/waves")
	discipline_nodes = _load_dir("res://data/disciplines")
	factions = _load_dir("res://data/factions")
	roads = _load_dir("res://data/roads")
	road_difficulties = _load_dir("res://data/road_difficulties")
	items = _load_dir("res://data/items")
	tutorial_steps = _load_dir("res://data/tutorial")
	milestone_cinematics = _load_dir("res://data/cinematics")
	chronicle_objectives = _load_dir("res://data/objectives")
	run_challenges = _load_dir("res://data/challenges")
	recovery_drops = _load_dir("res://data/recovery_drops")
	ranged_weapons = _load_dir("res://data/ranged")
	ammo_kinds = _load_dir("res://data/ammo")
	blueprints = _load_dir("res://data/blueprints")

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


func item(id: String) -> ItemData:
	return items.get(id, null) as ItemData


## One kind of gear by id.
func gear(id: String) -> GearData:
	return gear_kinds.get(id, null) as GearData


## Every kind of gear, for rolling a drop.
func gear_sorted() -> Array[GearData]:
	var out: Array[GearData] = []
	for value: Variant in gear_kinds.values():
		var kind := value as GearData
		if kind != null:
			out.append(kind)
	out.sort_custom(func(a: GearData, b: GearData) -> bool: return a.id < b.id)
	return out


## Campaign tiers, easiest first.
func tiers_sorted() -> Array[CampaignTierData]:
	var out: Array[CampaignTierData] = []
	for value: Variant in tiers.values():
		var tier := value as CampaignTierData
		if tier != null:
			out.append(tier)
	out.sort_custom(func(a: CampaignTierData, b: CampaignTierData) -> bool:
		return a.order < b.order)
	return out


func tier(id: String) -> CampaignTierData:
	return tiers.get(id, null) as CampaignTierData


## Every weather eligible for an act, for the roll.
func weathers_for_act(act: int) -> Array[WeatherData]:
	var out: Array[WeatherData] = []
	for value: Variant in weathers.values():
		var weather := value as WeatherData
		if weather != null and weather.allows_act(act):
			out.append(weather)
	out.sort_custom(func(a: WeatherData, b: WeatherData) -> bool: return a.id < b.id)
	return out


func weather(id: String) -> WeatherData:
	return weathers.get(id, null) as WeatherData


## Every animal that can turn up on the field, in a stable order.
##
## Sorted by id rather than left in directory order, because the spawner rolls
## against this list and a seeded run must pick the same animal on two machines.
func barricade(id: String) -> BarricadeData:
	return barricades.get(id, null) as BarricadeData


func trap(id: String) -> TrapData:
	return traps.get(id, null) as TrapData


## Every trap that can be laid, in a stable order for the build panel.
func trap_kinds() -> Array[TrapData]:
	var out: Array[TrapData] = []
	for value: Variant in traps.values():
		var kind := value as TrapData
		if kind != null:
			out.append(kind)
	out.sort_custom(func(a: TrapData, b: TrapData) -> bool: return a.id < b.id)
	return out


func companion(id: String) -> CompanionData:
	return companions.get(id, null) as CompanionData


func wildlife() -> Array[WildlifeData]:
	var out: Array[WildlifeData] = []
	for value: Variant in wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind != null:
			out.append(kind)
	out.sort_custom(func(a: WildlifeData, b: WildlifeData) -> bool: return a.id < b.id)
	return out


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


func milestone_cinematics_sorted() -> Array[MilestoneCinematicData]:
	var out: Array[MilestoneCinematicData] = []
	for value: Variant in milestone_cinematics.values():
		var data := value as MilestoneCinematicData
		if data != null:
			out.append(data)
	out.sort_custom(func(a: MilestoneCinematicData, b: MilestoneCinematicData) -> bool:
		return a.id < b.id)
	return out


func chronicle_objective(id: String) -> ChronicleObjectiveData:
	return chronicle_objectives.get(id, null) as ChronicleObjectiveData


func run_challenge(id: String) -> Resource:
	return run_challenges.get(id, null) as Resource


func recovery_drop(id: String) -> Resource:
	return recovery_drops.get(id, null) as Resource


func chronicle_objectives_sorted() -> Array[ChronicleObjectiveData]:
	var out: Array[ChronicleObjectiveData] = []
	for value: Variant in chronicle_objectives.values():
		var objective := value as ChronicleObjectiveData
		if objective != null:
			out.append(objective)
	out.sort_custom(func(a: ChronicleObjectiveData, b: ChronicleObjectiveData) -> bool:
		if a.order != b.order:
			return a.order < b.order
		return a.id < b.id)
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


## Base towers this account may actually build. The build panel uses this;
## `base_towers` stays unfiltered for balance tools and the curve report, which
## are asking about the design rather than about one save file.
func unlocked_base_towers() -> Array[TowerData]:
	var out: Array[TowerData] = []
	for tower: TowerData in base_towers():
		if MetaState.unlocked_towers.has(tower.id):
			out.append(tower)
	return out


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
