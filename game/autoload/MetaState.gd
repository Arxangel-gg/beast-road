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

## Bumped when the schema changes so an old file can be migrated or discarded.
const SAVE_VERSION: int = 1

## The save file was written or loaded.
signal save_written()
signal save_loaded()

# --- Unlock pool: ids only, never state ---
var unlocked_towers: Array[String] = []
var unlocked_relics: Array[String] = []
var unlocked_spells: Array[String] = []
var unlocked_terrains: Array[String] = []

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
}


func _ready() -> void:
	load_save()


## Extra Town Hall relic slots granted by meta-progression. Capped by design.
func bonus_relic_slots() -> int:
	return Balance.ACT3_CLEAR_BONUS_RELIC_SLOTS if act3_cleared else 0


func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"unlocked": {
			"towers": unlocked_towers,
			"relics": unlocked_relics,
			"spells": unlocked_spells,
			"terrains": unlocked_terrains,
			"act3_cleared": act3_cleared,
		},
		"stats": {
			"runs_started": runs_started,
			"runs_won": runs_won,
			"best_distance": best_distance,
			"total_enemies_killed": total_enemies_killed,
		},
		"settings": settings,
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("MetaState: could not open save for writing: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	save_written.emit()


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

	# An unknown version is discarded rather than half-read. The save holds no
	# power, so losing it costs the player unlock progress and nothing else.
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("MetaState: unrecognised save version; starting fresh.")
		return

	var unlocked: Dictionary = data.get("unlocked", {}) as Dictionary
	unlocked_towers = _string_array(unlocked.get("towers", []))
	unlocked_relics = _string_array(unlocked.get("relics", []))
	unlocked_spells = _string_array(unlocked.get("spells", []))
	unlocked_terrains = _string_array(unlocked.get("terrains", []))
	act3_cleared = bool(unlocked.get("act3_cleared", false))

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


## JSON gives back an untyped Array; the rest of the codebase wants Array[String].
func _string_array(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if value is Array:
		for item: Variant in (value as Array):
			out.append(str(item))
	return out
