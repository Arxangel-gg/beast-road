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
const SAVE_VERSION: int = 5

## Terrain ids as they were before v4's regions were adopted. A save records
## which terrains a player has unlocked *by id*, so renaming the content renames
## the save keys with it - and a v2 save would otherwise arrive holding three ids
## that no longer name anything, silently losing the unlocks.
## Save versions this build can carry forward. Anything else is backed up and
## the account starts fresh.
const MIGRATABLE_VERSIONS: Array[int] = [1, 2, 3, 4]

const TERRAIN_RENAMES_V3: Dictionary = {
	"ashfen": "jungle",
	"saltglass": "desert",
	"steppe": "snow",
}

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

## The roster order the later towers are earned in, bought with Tools at the end
## of a run (v4 §35). It was one per act boss felled, which paid a run that died
## in Act III the same as one that cleared it; Tools price depth instead. Still
## an authored order, so a new player meets one
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

## Tools: the account currency that widens what a run can contain (v4 §35).
## Earned by getting deep, spent on the roster. Never on power.
var tools: int = 0

# --- Hero progression (owner amendment, 2026-08-20) ---------------------------
#
# GDD §974 read "no hero level persists" through v4.0. The owner re-cut it: the
# game is now a multi-run climb through Normal, Nightmare and Hell, and a hero
# who resets every run cannot climb it. CLAUDE.md §7 carries the same amendment.
#
# What §974 was protecting is still protected. Growth is *capped* at
# HERO_MAX_LEVEL, so nothing unbounded persists, and the rest of the run - towers,
# relics, currencies, building tiers, Oathbound leaders - resets exactly as
# before. A player carries their hero forward, not their defence.

## The hero's level, experience and placed attributes, carried between runs.
var hero_level: int = 1
var hero_xp: float = 0.0
var hero_attributes: Array[int] = [0, 0, 0, 0]
var hero_attribute_points: int = 0
var hero_skill_points: int = 0

## Highest campaign tier order fully cleared. -1 means none, so only the first
## tier is open.
var tier_cleared: int = -1

## The tier the player last chose, so the picker reopens where they left off.
var last_tier_id: String = "normal"

# --- The stash (owner ruling, 2026-08-20) -------------------------------------
#
# Gear persists with the hero. Marks are the account's currency and shards are
# what broken gear becomes; neither is a run currency, and gold cannot be turned
# into either. That separation is the point: a stash purchase must never compete
# with the wall that is about to be overrun.

## Owned gear, each a plain dictionary of kind, rarity and level.
var stash: Array = []

## Equipped pieces, keyed by GearData.Slot. Values are indices into `stash`.
var equipped: Dictionary = {}

## The account's currency, and what salvage yields.
var marks: int = 0
var shards: int = 0


## Whether the opening cinematic has been shown. A setting rather than a
## statistic: it exists so the intro plays once, and it is cleared when a player
## wipes their save because a fresh account should see the opening again.
var story_intro_seen: bool = false


## Legacy rank, one per full clear, capped at Balance.SIGIL_MAX_RANK (v4 §36).
var sigils: int = 0

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


## Banks Tools for a finished run and spends them on the roster.
##
## Earning is by depth, not by kills: a per-kill trickle pays for farming one
## wave, which is the opposite of what the run is for. Spending is automatic and
## in the authored order, because a shop for one currency with one thing to buy
## is a menu standing in front of a decision nobody makes.
##
## Returns the tower ids unlocked, so the debrief can name them.
func award_tools(act_reached: int, victory: bool) -> Array[String]:
	var earned: int = Balance.TOOLS_PER_ACT * maxi(act_reached, 1)
	if victory:
		earned += Balance.TOOLS_VICTORY_BONUS
	tools = mini(tools + earned, Balance.TOOLS_MAX)

	var bought: Array[String] = []
	while tools >= Balance.TOOLS_PER_ROSTER_TOWER:
		var id: String = earn_next_roster_tower()
		if id.is_empty():
			break                                   # roster complete
		tools -= Balance.TOOLS_PER_ROSTER_TOWER
		bought.append(id)
	return bought


## One Sigil per full clear, until the legacy is complete.
##
## v4 §36 wants this on the true final boss. The Chainmaker does not exist yet,
## so it is awarded on the summit clear that currently ends the campaign - the
## same moment, one boss early. Move the call, not the rule, when the summit is
## built.
func award_sigil() -> bool:
	if sigils >= Balance.SIGIL_MAX_RANK:
		return false
	sigils += 1
	save_game()
	return true


## What the Treasury may carry between runs. Rank 3 raises it (v4 §36).
func treasury_cap(tier_cap: int) -> int:
	if sigils >= 3:
		return maxi(tier_cap, Balance.SIGIL_RANK3_TREASURY_CAP)
	return tier_cap


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
	tools = 0
	sigils = 0
	runs_started = 0
	runs_won = 0
	best_distance = 0.0
	total_enemies_killed = 0
	_seed_starting_roster()
	# The tutorial comes back too. It is a preference and the rest of the
	# preferences are kept, but somebody erasing their progress is asking for a
	# first run, and a first run includes being shown how the game works.
	settings["tutorial_seen"] = false
	# And the opening cinematic, for the same reason: somebody erasing their
	# progress is asking for a first run, and a first run starts with the story.
	story_intro_seen = false
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
## Rank 4's legacy effect in v4 §36 is "one additional Town Hall relic socket",
## which is exactly what the shipped `act3_cleared` bonus already grants - and
## CLAUDE.md §7 names that bonus as the *only* sanctioned persistent power. So
## the socket stays on the first clear rather than the fourth: strictly more
## generous than v4, takes nothing away from an account that has it, and avoids
## two systems paying twice for the same achievement.
func bonus_relic_slots() -> int:
	return Balance.ACT3_CLEAR_BONUS_RELIC_SLOTS if act3_cleared else 0


## The starting bundle rank 1 grants, per currency (v4 §36).
func sigil_starting_supply() -> int:
	return Balance.SIGIL_RANK1_SUPPLY if sigils >= 1 else 0


## Crossroad redraws this account has earned (rank 2).
func sigil_crossroad_rerolls() -> int:
	return Balance.SIGIL_RANK2_REROLLS if sigils >= 2 else 0


## Reads the hero block, clamping everything.
##
## A save is a file on someone's disk and may have been edited, truncated or
## written by a build that is not this one. Every field is bounded here rather
## than trusted, because an out-of-range level does not fail loudly - it produces
## a hero with 4,000 attribute points and a game that is no longer a game.
func _read_hero(hero: Dictionary) -> void:
	hero_level = clampi(int(hero.get("level", 1)), 1, Balance.HERO_MAX_LEVEL)
	hero_xp = maxf(float(hero.get("xp", 0.0)), 0.0)
	hero_attribute_points = maxi(int(hero.get("attribute_points", 0)), 0)
	hero_skill_points = maxi(int(hero.get("skill_points", 0)), 0)
	tier_cleared = clampi(int(hero.get("tier_cleared", -1)), -1, 8)
	last_tier_id = String(hero.get("last_tier", "normal"))
	story_intro_seen = bool(hero.get("story_seen", false))

	hero_attributes = [0, 0, 0, 0]
	var stored: Array = hero.get("attributes", []) as Array
	for i: int in mini(stored.size(), hero_attributes.size()):
		hero_attributes[i] = maxi(int(stored[i]), 0)

	# Placed points plus unspent may not exceed what the level could ever have
	# granted. This is the one line that stops a hand-edited save from arriving
	# with a maxed hero on a fresh account.
	var granted: int = hero_level - 1
	var placed: int = 0
	for value: int in hero_attributes:
		placed += value
	if placed + hero_attribute_points > granted:
		var over: int = placed + hero_attribute_points - granted
		hero_attribute_points = maxi(hero_attribute_points - over, 0)
		over = placed + hero_attribute_points - granted
		for i: int in hero_attributes.size():
			if over <= 0:
				break
			var taken: int = mini(hero_attributes[i], over)
			hero_attributes[i] -= taken
			over -= taken


## Reads the stash, discarding anything that is not a real piece of gear.
##
## A save is a file on someone's disk. Every entry is validated against the
## content that actually exists rather than trusted, because a piece naming a
## kind this build no longer ships is not an error anywhere — it is a silent hole
## that surfaces later as a null in the equip screen.
func _read_stash(data: Dictionary) -> void:
	marks = maxi(int(data.get("marks", 0)), 0)
	shards = maxi(int(data.get("shards", 0)), 0)
	stash = []
	for entry: Variant in data.get("gear", []) as Array:
		if not (entry is Dictionary):
			continue
		var piece: Dictionary = entry
		var kind: String = String(piece.get("kind", ""))
		if ContentDB.gear(kind) == null:
			continue
		stash.append(Stash.make(kind, int(piece.get("rarity", 0)),
			int(piece.get("level", 1))))
		if stash.size() >= Balance.STASH_CAPACITY:
			break

	equipped = {}
	for key: Variant in (data.get("equipped", {}) as Dictionary):
		var index: int = int((data["equipped"] as Dictionary)[key])
		if index >= 0 and index < stash.size():
			equipped[int(key)] = index


## The piece worn in a slot, or an empty dictionary.
func equipped_piece(slot: int) -> Dictionary:
	var index: int = int(equipped.get(slot, -1))
	if index < 0 or index >= stash.size():
		return {}
	return stash[index]


## Attribute points every equipped piece grants, as a four-entry array.
func gear_attribute_points() -> Array[int]:
	var out: Array[int] = [0, 0, 0, 0]
	for slot: Variant in equipped:
		var piece: Dictionary = equipped_piece(int(slot))
		if piece.is_empty():
			continue
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind == null or kind.attribute < 0 or kind.attribute >= out.size():
			continue
		out[kind.attribute] += Stash.points(piece, kind)
	return out


## Takes a piece into the stash. Returns false when there is no room.
func take_gear(piece: Dictionary) -> bool:
	if piece.is_empty() or stash.size() >= Balance.STASH_CAPACITY:
		return false
	stash.append(piece)
	save_game()
	EventBus.stash_changed.emit()
	return true


## Removes a piece, keeping the equipped indices pointing at the same gear.
##
## Indices shift when an element is removed from the middle of an array, so
## anything equipped after the removed slot has to move down with it. Getting
## this wrong does not fail loudly - it silently re-equips a different sword.
func drop_gear(index: int) -> Dictionary:
	if index < 0 or index >= stash.size():
		return {}
	var piece: Dictionary = stash[index]
	stash.remove_at(index)
	var moved: Dictionary = {}
	for slot: Variant in equipped:
		var at: int = int(equipped[slot])
		if at == index:
			continue
		moved[int(slot)] = at - 1 if at > index else at
	equipped = moved
	save_game()
	EventBus.stash_changed.emit()
	return piece


## Which campaign tiers this account may choose.
func tier_is_unlocked(tier: CampaignTierData) -> bool:
	return tier != null and tier.order <= tier_cleared + 1


## Records a full clear, which is what opens the next tier.
func record_tier_cleared(order: int) -> void:
	if order > tier_cleared:
		tier_cleared = order
		save_game()


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
			"tools": tools,
			"sigils": sigils,
			"act3_cleared": act3_cleared,
		},
		"hero": {
			"level": hero_level,
			"xp": hero_xp,
			"attributes": hero_attributes,
			"attribute_points": hero_attribute_points,
			"skill_points": hero_skill_points,
			"tier_cleared": tier_cleared,
			"last_tier": last_tier_id,
			"story_seen": story_intro_seen,
		},
		"stash": {
			"gear": stash,
			"equipped": equipped,
			"marks": marks,
			"shards": shards,
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
	if found_version != SAVE_VERSION and not MIGRATABLE_VERSIONS.has(found_version):
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
	tools = clampi(int(unlocked.get("tools", 0)), 0, Balance.TOOLS_MAX)
	sigils = clampi(int(unlocked.get("sigils", 0)), 0, Balance.SIGIL_MAX_RANK)
	_read_hero(data.get("hero", {}) as Dictionary)
	_read_stash(data.get("stash", {}) as Dictionary)
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
	if not MIGRATABLE_VERSIONS.has(found_version):
		return {}
	var original: String = source_text if not source_text.is_empty() else JSON.stringify(data, "\t")
	if not _back_up_save(original, found_version, backup_path):
		return {}
	var migrated: Dictionary = data.duplicate(true)
	var unlocked: Dictionary = migrated.get("unlocked", {}) as Dictionary

	# Applied in order, so a v1 save walks every step rather than jumping to the
	# current shape and skipping the ones in between.
	if found_version <= 1:
		if not migrated.has("resource_cache"):
			migrated["resource_cache"] = {}
		if not unlocked.has("buildings"):
			unlocked["buildings"] = []
	if found_version <= 2:
		unlocked["terrains"] = _renamed_terrains(unlocked.get("terrains", []))

	migrated["unlocked"] = unlocked
	migrated["version"] = SAVE_VERSION
	return migrated


## Rewrites unlocked terrain ids to their v4 region names, dropping nothing: an
## id that is already current, or that names no terrain at all, is passed through
## rather than discarded. A migration that quietly forgets an unlock is worse
## than one that carries a stale string.
func _renamed_terrains(ids: Array) -> Array:
	var out: Array = []
	for value: Variant in ids:
		var id: String = String(value)
		out.append(TERRAIN_RENAMES_V3.get(id, id))
	return out


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
