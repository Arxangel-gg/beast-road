extends Node

## Every breed's facing is a decision somebody made by looking at its art.
##
##   godot --headless --path game res://tools/enemy_facing_check.tscn
##
## **The fault this exists to prevent is a silent default.** `art_facing` was
## added on 2026-09-13 so head-on sprites would stop being mirrored, and twelve
## breeds were marked as profile. The other forty-four were never considered:
## the export defaults to FRONT and Godot omits a property left at its default,
## so those `.tres` files carry no `art_facing` line at all and the breed simply
## never turns. Nothing errors, nothing warns, and the body walks backwards up
## the road for the rest of the game.
##
## Reported twice by the owner - the Rootshield, then the Ember Shaman, which
## "regardless of which side of them i go on do not change direction". Both were
## in that silent forty-four, and so were eight more.
##
## So the table below *is* the record. Every breed must appear in it, and the
## data must agree with it. A new breed fails this gate until somebody opens its
## sprite, decides which way it is drawn, and writes that decision down here -
## which is the step that was skipped.
##
## **How each was decided, so the next person can repeat it.** The sprite was
## measured against its own mirror: all twelve breeds already marked as profile
## score 0.40-0.80 silhouette asymmetry, but so do thirty-eight that are drawn
## head-on, because a staff or a lantern in one hand is asymmetric too.
## Asymmetry only says which sprites are worth opening. The facing itself comes
## from where the head, the eyes and the leading prop point - and mirroring a
## head-on sprite is the original fault this whole field exists to prevent, so
## FRONT stays the answer wherever the body is square to the camera.

## breed id -> EnemyData.Facing. 0 FRONT, 1 RIGHT, 2 LEFT.
const ROSTER: Dictionary = {
	"ash_caller": 0, "bell_priest": 0, "bogkin": 0, "brine_drowned": 0,
	"brinefather": 0, "burrower": 1, "chainmaker": 0, "choir_cantor": 0,
	"cinder_hound": 1, "cinder_runner": 1, "cinder_titan": 0,
	"crevasse_stalker": 1, "crown_herald": 0, "drowned_choir": 1,
	"ember_husk": 0, "ember_shaman": 2, "flake_runner": 1, "fog_lantern": 0,
	"frost_herald": 1, "gate_sentinel": 0, "gatekeeper": 0, "glass_chanter": 0,
	"glass_colossus": 0, "glass_singer": 0, "glassborn": 1, "glassguard": 0,
	"horde_drummer": 0, "horde_lancer": 1, "horde_shieldman": 0,
	"horde_warlord": 0, "howler": 1, "ice_hauler": 2, "loam_lurker": 0,
	"mirage_seer": 0, "mire_shambler": 0, "mirrorfang": 1, "mistwarden": 0,
	"prism_warden": 0, "reed_stalker": 2, "rootshield": 2, "rust_crown": 0,
	"rust_hulk": 0, "rustmother": 0, "salt_crawler": 0, "salt_marcher": 1,
	"scale_rider": 1, "shard_wight": 1, "siege_lizard": 1, "snowhide_brute": 0,
	"stair_runner": 1, "steppehorde": 0, "storm_caller": 0, "warden": 0,
	"white_maw_giant": 0, "wolf_rider": 1, "wolf_standard_bearer": 1,
}

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_breed_has_a_recorded_facing()
	_test_the_data_agrees_with_the_record()
	_test_the_roster_names_only_real_breeds()
	_test_something_still_turns()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[enemy-facing] PASS - %d checks over %d breeds, each facing decided and recorded"
			% [_checks, ROSTER.size()])
	else:
		for failure: String in _failures:
			push_error("[enemy-facing] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


func _name_of(facing: int) -> String:
	var names: PackedStringArray = EnemyData.Facing.keys()
	return names[facing] if facing >= 0 and facing < names.size() else "?%d" % facing


## A breed nobody decided about is the whole fault.
func _test_every_breed_has_a_recorded_facing() -> void:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		_check(ROSTER.has(breed.id),
			("%s has no recorded facing - open its sprite, decide which way it is "
				+ "drawn, and add it to ROSTER. Leaving it out means it defaults to "
				+ "FRONT and never turns, which is how ten breeds ended up walking "
				+ "backwards") % breed.id)


func _test_the_data_agrees_with_the_record() -> void:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or not ROSTER.has(breed.id):
			continue
		var wanted: int = int(ROSTER[breed.id])
		_check(int(breed.art_facing) == wanted,
			"%s is authored %s and this gate records %s - one of the two is wrong"
				% [breed.id, _name_of(int(breed.art_facing)), _name_of(wanted)])
		_check(wanted >= 0 and wanted < EnemyData.Facing.size(),
			"%s records facing %d and there are %d"
				% [breed.id, wanted, EnemyData.Facing.size()])


## And the record may not name a breed that no longer exists, or the table
## quietly becomes a list of things somebody once thought about.
func _test_the_roster_names_only_real_breeds() -> void:
	for id: Variant in ROSTER:
		_check(ContentDB.enemies.has(String(id)),
			"ROSTER names \"%s\", which is not a breed" % id)


## The point of all of it: some of the roster actually turns.
##
## A table that recorded FRONT for all fifty-six would pass every check above
## and put the game back exactly where the owner found it.
func _test_something_still_turns() -> void:
	var turning: int = 0
	for id: Variant in ROSTER:
		if int(ROSTER[id]) != EnemyData.Facing.FRONT:
			turning += 1
	_check(turning >= 20,
		("only %d breeds of %d ever turn to face their travel - the roster has "
			+ "drifted back toward the silent default") % [turning, ROSTER.size()])
