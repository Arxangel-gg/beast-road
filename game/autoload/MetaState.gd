extends Node

## Everything that survives death — and nothing else (GDD §7, §11 rule 5).
##
## The entire save schema is three things: unlocked ids, run statistics, and
## settings. Death wipes the run; clearing content only widens the pool of
## things that *can* appear next time. You start every run at zero power.
##
## If a field that is not one of those three shows up in a pull request here, a
## design decision has been violated. Flag it instead of implementing it.

const SAVE_PATH: String = "user://beast_road_save.json"

## Where a save of an unrecognised version is preserved before the game starts
## fresh. One per version, so a player who tries several builds keeps a copy of
## each rather than each overwriting the last.
const SAVE_BACKUP_PATH: String = "user://beast_road_save.v%d.bak.json"

## Bumped when the schema changes so an old file can be migrated or discarded.
const SAVE_VERSION: int = 2

## The save file was written or loaded.
signal save_written()
signal save_loaded()

# --- Unlock pool: ids only, never state ---
## Base towers the account may build. Seeded with the eight the game shipped
## with, so **every element and every fusion is reachable on run one** - v4 §3.4
## is explicit that the signature fusion system is not hidden behind progress.
##
## What unlocks is the *roster*: the eight later towers that widen each element
## from two roles to four (GDD §21, §35). Elements are never gated.
const STARTING_TOWERS: Array[String] = [
	"ember_spire", "pyre_cannon",
	"rime_lance", "hoarfrost_bell",
	"bulwark", "shard_thrower",
	"arc_coil", "gale_turret",
]

## The roster order the later towers are earned in. One per act boss felled, so
## the toolkit widens at the same pace the run does and a new player meets one
## new tower at a time rather than sixteen at once.
const ROSTER_UNLOCK_ORDER: Array[String] = [
	"tide_caller", "grit_sling",
	"cinder_lance", "glacial_mortar",
	"stonewatch", "zephyr_needle",
	"ashen_censer", "stormvane",
]

var unlocked_towers: Array[String] = []
var unlocked_relics: Array[String] = []
var unlocked_spells: Array[String] = []
var unlocked_terrains: Array[String] = []

## Milestone-gated construction pool. These are content permissions, not built
## tiers; every building still starts over each run.
var unlocked_buildings: Array[String] = []

## Treasury's one sanctioned carry-over. Capped per currency and consumed when
## the next run begins, so it cannot compound into permanent power.
var resource_cache: Dictionary = {}

## Set once Act 3 has been cleared. Worth exactly one extra starting Town Hall
## relic slot, capped at +1. This is the only sanctioned persistent power.
var act3_cleared: bool = false

# --- Run statistics ---
var runs_started: int = 0
var runs_won: int = 0
var best_distance: float = 0.0
var total_enemies_killed: int = 0

# --- Settings ---
var settings: Dictionary = {
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 1.0,
	"screen_shake": 1.0,
	"beast_gait": 0.65,
	"display_mode": UserSettings.DISPLAY_FULLSCREEN,
	# These keys must exist before load_save() merges persisted settings. The
	# loader deliberately rejects unknown keys, so omitting them made Video and
	# colourblind selections appear to save while silently reverting on launch.
	"graphics": {},
	"colourblind_mode": "off",
	"key_bindings": {},
	# Must exist here or it is silently dropped: the loader rejects keys it does
	# not already know, so a default missing from this dictionary is a setting
	# that appears to save and reverts on the next launch.
	"tutorial_seen": false,
}


## Throws the account away and starts over.
##
## Offered in Settings because a roguelite's unlock pool is most of what a
## returning player is playing against, and somebody who wants the first run
## back has no other way to get it. Deliberately total: progress, statistics and
## the Treasury cache all go.
##
## Player settings are *kept*. Volume, display mode and key bindings are not
## progress, and wiping somebody's key bindings because they wanted a fresh
## unlock pool would be a second, unasked-for destruction.
func erase_progress() -> void:
	unlocked_towers.clear()
	unlocked_relics.clear()
	unlocked_spells.clear()
	unlocked_terrains.clear()
	unlocked_buildings.clear()
	resource_cache.clear()
	act3_cleared = false
	runs_started = 0
	runs_won = 0
	best_distance = 0.0
	total_enemies_killed = 0
	_seed_starting_roster()
	# The tutorial comes back too. It is a preference and the rest of the
	# preferences are kept, but somebody erasing their progress is asking for a
	# first run, and a first run includes being shown how the game works.
	settings["tutorial_seen"] = false
	# Written immediately rather than left in memory: the player asked for the
	# save to be gone, and a crash before the next autosave would hand it back.
	save_game()


## Every account starts able to build the original eight, whatever the save
## says. A save written before the roster existed has none of them listed, and a
## player who could build nothing at all would have no way to earn the rest.
func _seed_starting_roster() -> void:
	for id: String in STARTING_TOWERS:
		if not unlocked_towers.has(id):
			unlocked_towers.append(id)


## Fells an act boss and widens the roster by one, in a fixed order.
##
## Returns the tower id earned, or "" when the roster is already complete.
## Persisted immediately: an unlock that only exists until the process exits is
## not progression.
func earn_next_roster_tower() -> String:
	for id: String in ROSTER_UNLOCK_ORDER:
		if not unlocked_towers.has(id):
			unlocked_towers.append(id)
			save_game()
			return id
	return ""


func _ready() -> void:
	load_save()
	_seed_starting_roster()
	# Applied here rather than left to whoever happens to read a setting first.
	# The buses had exactly that bug once already, and display mode has no other
	# owner at all - without this a windowed player is put back into fullscreen
	# every single launch.
	UserSettings.apply_all()


## Extra Town Hall relic slots granted by meta-progression. Capped by design.
func bonus_relic_slots() -> int:
	return Balance.ACT3_CLEAR_BONUS_RELIC_SLOTS if act3_cleared else 0


func save_game() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("MetaState: could not open save for writing: %s" % SAVE_PATH)
		return
	file.store_string(serialized_save())
	file.close()
	save_written.emit()


## The exact payload written by save_game(). Release gates use this to time an
## isolated checkpoint inside the project instead of ever touching a player's
## real save slot while another development session may be running.
func serialized_save() -> String:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"unlocked": {
			"towers": unlocked_towers,
			"relics": unlocked_relics,
			"spells": unlocked_spells,
			"terrains": unlocked_terrains,
			"buildings": unlocked_buildings,
			"act3_cleared": act3_cleared,
		},
		"resource_cache": resource_cache,
		"stats": {
			"runs_started": runs_started,
			"runs_won": runs_won,
			"best_distance": best_distance,
			"total_enemies_killed": total_enemies_killed,
		},
		"settings": settings,
	}
	return JSON.stringify(data, "\t")


func load_save() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("MetaState: could not open save for reading: %s" % SAVE_PATH)
		return
	var text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		push_warning("MetaState: save file is not a JSON object; ignoring it.")
		return
	var data: Dictionary = parsed

	# An unknown version is discarded rather than half-read - but never before a
	# copy is kept.
	#
	# This is the one thing in the project that git cannot undo. Rolling the game
	# back is a checkout; rolling a player's unlock history back is impossible
	# once the file is gone, and a version mismatch happens in *both* directions:
	# a v4 build reading a v3 save, and a v3 build reading a save that v4 has
	# already migrated. The second is the dangerous one, because it is what
	# happens to anyone who tries a build and then goes back.
	#
	# GDD §52 requires migration to "never destroy the source save". Keeping the
	# original is the whole of that requirement, and it costs one file copy.
	var found_version: int = int(data.get("version", 0))
	if found_version != SAVE_VERSION and found_version != 1:
		_back_up_save(text, found_version)
		push_warning("MetaState: save version %d is not %d; kept a copy at %s and started fresh."
			% [found_version, SAVE_VERSION, SAVE_BACKUP_PATH % found_version])
		return
	if found_version != SAVE_VERSION:
		data = migrate_save(data, text)
		if data.is_empty():
			return

	var unlocked: Dictionary = data.get("unlocked", {}) as Dictionary
	unlocked_towers = _string_array(unlocked.get("towers", []))
	_seed_starting_roster()
	unlocked_relics = _string_array(unlocked.get("relics", []))
	unlocked_spells = _string_array(unlocked.get("spells", []))
	unlocked_terrains = _string_array(unlocked.get("terrains", []))
	unlocked_buildings = _string_array(unlocked.get("buildings", []))
	act3_cleared = bool(unlocked.get("act3_cleared", false))
	resource_cache = data.get("resource_cache", {}) as Dictionary

	var stats: Dictionary = data.get("stats", {}) as Dictionary
	runs_started = int(stats.get("runs_started", 0))
	runs_won = int(stats.get("runs_won", 0))
	best_distance = float(stats.get("best_distance", 0.0))
	total_enemies_killed = int(stats.get("total_enemies_killed", 0))

	var loaded_settings: Dictionary = data.get("settings", {}) as Dictionary
	for key: Variant in loaded_settings:
		if settings.has(key):
			settings[key] = loaded_settings[key]

	save_loaded.emit()


## Migrates a known public schema without ever mutating its source file first.
## The returned dictionary is consumed in memory and only becomes current when
## save_game() later completes successfully.
func migrate_save(data: Dictionary, source_text: String = "",
		backup_path: String = "") -> Dictionary:
	var found_version: int = int(data.get("version", 0))
	if found_version == SAVE_VERSION:
		return data
	if found_version != 1:
		return {}
	var original: String = source_text if not source_text.is_empty() else JSON.stringify(data, "\t")
	if not _back_up_save(original, found_version, backup_path):
		return {}
	var migrated: Dictionary = data.duplicate(true)
	migrated["version"] = SAVE_VERSION
	if not migrated.has("resource_cache"):
		migrated["resource_cache"] = {}
	var unlocked: Dictionary = migrated.get("unlocked", {}) as Dictionary
	if not unlocked.has("buildings"):
		unlocked["buildings"] = []
	migrated["unlocked"] = unlocked
	return migrated


func building_unlocked(id: String) -> bool:
	var data: BuildingData = ContentDB.building(id)
	return data != null and (not data.requires_unlock or unlocked_buildings.has(id))


func unlock_building(id: String) -> bool:
	if unlocked_buildings.has(id) or ContentDB.building(id) == null:
		return false
	unlocked_buildings.append(id)
	EventBus.unlock_earned.emit("building", id)
	return true


## Preserves a save this build cannot read.
##
## Deliberately never overwrites an existing backup: the *first* copy is the
## valuable one. Bouncing between two builds would otherwise have each launch
## re-back-up the file the previous launch already reset, and the original would
## be gone by the third run.
func _back_up_save(text: String, version: int, test_path: String = "") -> bool:
	# The override exists only so the regression gate can prove byte preservation
	# in an isolated fixture. Shipping callers always use the versioned path.
	var path: String = test_path if not test_path.is_empty() else SAVE_BACKUP_PATH % version
	if FileAccess.file_exists(path):
		return true
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("MetaState: could not write save backup to %s" % path)
		return false
	file.store_string(text)
	file.close()
	return true


## JSON gives back an untyped Array; the rest of the codebase wants Array[String].
func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in (value as Array):
			out.append(str(item))
	return out
