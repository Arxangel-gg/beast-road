extends Node

## Every tuning constant is read by something, or is written down as not being.
##
##   godot --headless --path game res://tools/balance_reach_check.tscn
##
## **A number in this project's Balance file looks authoritative whether or not
## anything reads it**, and several have not been. Each was found by hand, long
## after it shipped, and each had been describing a promise to the player that
## no code kept:
##
## - `HERO_FOCUS_SPELL_PER_POINT` - the Mansion had advertised spell power for
##   Focus since the attribute was authored, and nothing applied it.
## - `CROSSROADS_PER_ACT` came off this list on 2026-09-15, which is the gate
##   working: the road-card gate started reading it the day the acts stopped
##   being the same length, and this refused to let it stay listed as unread.
## - `CROSSROADS_PER_ACT` and `CROSSROADS_PER_RUN` - both quietly wrong in both
##   directions, and consulted by nothing.
## - Six discipline `effect_id`s - described on cards, priced at a skill point
##   and a lot of Food, read by nothing at all.
## - `TOWER_CAPSTONE_FOCUS_PIERCE` - half of what the Focus path promised at the
##   tenth level, which a player paid for and never received.
## - `HUNT_SAVAGE_DAMAGE` and `HUNT_SAVAGE_SPEED` - the savage sent to hunt an
##   over-farming player bit for exactly what an ordinary animal bites for, at
##   exactly its walking pace.
##
## So this counts them. Every constant must be named by some script outside
## Balance.gd, or appear in `UNREAD` below. **The list may shrink and may never
## grow**: adding a constant that nothing reads fails this gate, which is the
## moment to either wire it or admit in writing that it is not wired yet.
##
## Two decoys were deleted rather than listed when this was written -
## `SAME_ELEMENT_DAMAGE_BONUS` and `GRANARY_TIER_BONUS`, each a stale twin
## holding the same value as a live constant under a nearly identical name. They
## broke nothing and would have wasted somebody's afternoon: tuning either did
## exactly nothing, because the live number was somewhere else.

## Constants nothing reads today.
##
## Most are honest leftovers - a system re-tuned through data, a value moved to
## a resource, a knob kept for a screen that was rebuilt. They are listed rather
## than deleted because deleting a constant is a decision about content and this
## gate is about drift. **Shrink it whenever one is wired or removed.**
const UNREAD: PackedStringArray = [
	"BOSS_VOLLEY_SPEED", "CAMERA_ZOOM_RAID", "CITY_BUILD_SLOTS",
	"COLOURBLIND_MODES", "COMMAND_ORDER_COUNT",
	"ENEMY_LIGHT_ENERGY", "ENEMY_LIGHT_RADIUS", "ENEMY_SEPARATION_SPEED",
	"ENEMY_SHOT_HEX_TINT", "FISHING_SLACK_GRACE", "FISHING_SPENT_TINT",
	"FOLIAGE_GROUND_SWAY", "FOLIAGE_LANE_CLEARANCE", "FOLIAGE_SLOT_MARGIN",
	"FOLIAGE_UPDATE_INTERVAL", "GRID_TILES", "HERO_ACTIVE_SLOTS",
	"HERO_DRAUGHT_REVIVE_HP", "LANE_RING_CALM", "LANE_RING_HOT",
	"MARKET_MAX_EXCHANGE", "MINIMAP_CORNER", "MINIMAP_CORNER_SIZE",
	"MINIMAP_FRAME_INNER", "MINIMAP_FRAME_THICK", "PATH_CORE_RADIUS",
	"PATH_EDGE_FADE", "PATH_EDGE_NOISE", "PATH_END_FADE", "PATH_NOISE_SCALE",
	"PREPARATION_MIN_SECONDS", "PREPARATION_PANEL_LIFT_TOUCH",
	"PROJECTILE_LENGTH", "RAID_ARENA_RADIUS", "RAID_DURATION",
	"RAID_FIRE_GLOW", "RAID_FIRE_GLOW_RADIUS", "RAID_TELEPORT_COOLDOWN",
	"ROAD_BEND_COUNT", "SCOPE_FADE_TIME",
	"SPAWN_BURST_END", "SPAWN_BURST_START", "SPAWN_INTERVAL_END",
	"SPAWN_INTERVAL_START", "SPAWN_MAX_ALIVE", "SPAWN_MIN_DISTANCE_FROM_HERO",
	"SPAWN_RAMP_SECONDS", "SPELLS_OFFERED_ON_LEVEL_UP", "STARTING_RESOURCES",
	"TORCH_CORNER_CLEARANCE", "TORCH_CORNER_OFFSET_SCALE", "TORCH_SPACING",
	"TOWER_CLICK_BLOCK_RADIUS", "TOWER_FOOTPRINT_TILES", "TOWER_SLOT_COUNT",
	"TOWER_SPRITE_SIZE", "TREASURY_CACHE_MAX", "WARD_ABSORB",
]

const BALANCE_PATH: String = "res://scripts/Balance.gd"
const SELF_PATH: String = "res://tools/balance_reach_check.gd"
const ROOTS: PackedStringArray = ["res://scripts", "res://scenes",
	"res://autoload", "res://tools"]

var _failures: PackedStringArray = []
var _checks: int = 0
var _code: String = ""


func _ready() -> void:
	MetaState.hold_saves()
	_code = _every_script_but_balance() + "\n" + _balance_without_its_declarations()
	var declared: PackedStringArray = _declared()
	_test_every_constant_is_read_or_listed(declared)
	_test_the_list_names_only_real_constants(declared)
	_test_the_list_has_not_grown()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[balance-reach] PASS - %d checks: %d constants, %d listed as unread"
			% [_checks, declared.size(), UNREAD.size()])
	else:
		for failure: String in _failures:
			push_error("[balance-reach] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## Every `const NAME:` in the Balance file.
func _declared() -> PackedStringArray:
	var out: PackedStringArray = []
	var file := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		return out
	var finder := RegEx.create_from_string("(?m)^const ([A-Z][A-Z0-9_]*)\\s*:")
	for found: RegExMatch in finder.search_all(file.get_as_text()):
		out.append(found.get_string(1))
	return out


## Balance.gd itself, with only the `const NAME: Type =` headers cut away.
##
## A constant read by one of this file's own helpers - or by the *value* of
## another constant, as `ACT_DISTANCE` reads `SEGMENT_DISTANCE` - is read. Only
## the declaration itself is not a use of the thing being declared, so that is
## the only part removed. Cutting the whole line would have hidden every
## derivation in the file and called a dozen live constants dead.
func _balance_without_its_declarations() -> String:
	var file := FileAccess.open(BALANCE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var header := RegEx.create_from_string("(?m)^const [A-Z][A-Z0-9_]*\\s*:[^=\\n]*=")
	return header.sub(file.get_as_text(), "", true)


## Everything that could read one, as one string.
func _every_script_but_balance() -> String:
	var parts: PackedStringArray = []
	for root: String in ROOTS:
		_gather(root, parts)
	return "\n".join(parts)


func _gather(path: String, into: PackedStringArray) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.list_dir_begin()
	var name: String = directory.get_next()
	while not name.is_empty():
		var full: String = path.path_join(name)
		if directory.current_is_dir():
			_gather(full, into)
		# **And never this file.** It lives under `tools`, so scanning itself
		# would find every name in `UNREAD` as a string literal and declare the
		# whole roster read - a ledger that satisfies itself. `discipline_check`
		# carries the same exclusion for the same reason.
		elif name.ends_with(".gd") and full != BALANCE_PATH and full != SELF_PATH:
			var file := FileAccess.open(full, FileAccess.READ)
			if file != null:
				into.append(file.get_as_text())
		name = directory.get_next()
	directory.list_dir_end()


func _test_every_constant_is_read_or_listed(declared: PackedStringArray) -> void:
	_check(declared.size() > 100,
		"only %d constants found - the Balance file was not read properly"
			% declared.size())
	for name: String in declared:
		if _code.contains(name) or UNREAD.has(name):
			continue
		_check(false,
			("%s is authored and nothing outside Balance.gd reads it. Wire it, "
				+ "delete it, or add it to UNREAD with a reason - a tuning "
				+ "constant nobody reads is a promise nobody keeps") % name)


## And the list may not name something that no longer exists, or it becomes a
## list of things somebody once worried about.
func _test_the_list_names_only_real_constants(declared: PackedStringArray) -> void:
	for name: String in UNREAD:
		_check(declared.has(name),
			("UNREAD names %s, which is not a constant in Balance.gd - it was "
				+ "wired or deleted and the list did not follow") % name)
		_check(not _code.contains(name),
			("UNREAD names %s and something reads it now - take it off the list")
				% name)


## The count is a ratchet.
func _test_the_list_has_not_grown() -> void:
	# The figure this gate was written at. Lowering it is the point; raising it
	# is the thing it exists to make somebody argue for out loud.
	_check(UNREAD.size() <= 60,
		("%d constants are listed as read by nothing, against the 60 this gate "
			+ "was written at. The list is a ratchet: it may shrink and may not "
			+ "grow") % UNREAD.size())
