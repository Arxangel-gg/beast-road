extends Node

## What a ranged breed knows how to throw, and whether the choice is real.
##
##   godot --headless --path game res://tools/enemy_repertoire_check.tscn
##
## **One shot each was one question each.** Every shooter authored a single
## `shot`, so a breed posed the same problem at every distance for the whole
## campaign. The owner asked for the Ember Shamans to keep their mortar *and*
## carry a fire bolt - "with random uses of both as well as range dependent" -
## and for the rest of the roster to grow the same way, with variety that rises
## with the breed's difficulty.
##
## Four ways that can be a lie, and this gate holds all four:
##
## 1. **A repertoire naming a shot that does not exist.** An id that resolves to
##    nothing is a breed quietly falling back to its old single shot, and
##    nothing anywhere would say so.
## 2. **A choice that is not a choice.** If every shot in a repertoire suits the
##    same distances, the draw is decoration - the breed throws a random thing
##    rather than the right thing.
## 3. **A range gate wearing a repertoire's clothes.** If a shot outside its band
##    can never be drawn, the breed becomes a state machine the player reads off
##    a tape measure. `stray_weight` is what keeps it a tendency.
## 4. **The two enums drifting apart.** `EnemyShotData.Kind` is a second copy of
##    `EnemyData.Shot`, because `EnemyData` refers to this class and naming it
##    back would be a cyclic reference. This project has twice lost content to
##    an enum that grew in the middle - the discipline `Role` and the tutorial
##    `Trigger` - and a silent second copy is that hazard wearing a new coat.

## How many shots a breed of each standing should know. The owner's table.
const EXPECTED: Dictionary = {
	# **Every breed owns its own shots since 2026-09-21** (owner: "each enemy
	# should have its own unique projectiles ... multiple variations"), so the
	# floor is three for a road caster and the elites and champions carry four
	# or five. `enemy_shot_check` holds the ownership; this holds the count.
	"ember_shaman": 3, "thorn_archer": 3, "marsh_piper": 3, "horde_marksman": 3,
	"storm_caller": 4, "fog_lantern": 3, "bell_priest": 3, "choir_cantor": 3,
	"glass_singer": 4, "glass_chanter": 4, "ash_caller": 4, "crown_herald": 4,
	"mirage_seer": 5, "drowned_choir": 5, "anchor_cantor": 3,
	"howler": 3, "wolf_standard_bearer": 3, "horde_drummer": 3,
	"dragon_storm": 4, "camp_shaman": 3,
}

## Distances the draw is measured at, **as a share of the breed's own reach**.
##
## A fixed pair of distances was the first cut and it was wrong: the Fog Lantern
## throws 540 units and the Choir Cantor 560, so a "far" of 900 was past what
## either can throw at all and the gate reported them as having nothing for
## range. A breed is only ever asked about distances it can actually shoot at.
const CLOSE_SHARE: float = 0.22
const FAR_SHARE: float = 0.92
## When a breed authors no reach of its own it throws as far as it can see.
const ASSUMED_REACH: float = 800.0
const DRAWS: int = 400

var _failures: PackedStringArray = []
var _checks: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	MetaState.hold_saves()
	_rng.seed = 20260913
	_test_the_two_enums_agree()
	_test_every_named_shot_exists()
	_test_each_breed_knows_what_it_should()
	_test_a_repertoire_spans_its_ranges()
	_test_the_draw_leans_on_range_without_gating()
	_test_every_shooter_has_a_repertoire()
	_test_every_shot_looks_like_itself()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[repertoire] PASS - %d checks: %d shots, %d breeds, range leans and never gates"
			% [_checks, ContentDB.enemy_shots.size(), EXPECTED.size()])
	else:
		for failure: String in _failures:
			push_error("[repertoire] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## The duplicate enum, held in step name for name.
func _test_the_two_enums_agree() -> void:
	var one: PackedStringArray = EnemyData.Shot.keys()
	var two: PackedStringArray = EnemyShotData.Kind.keys()
	_check(one.size() == two.size(),
		("EnemyData.Shot has %d kinds and EnemyShotData.Kind has %d - a shot "
			+ "authored against one enum would resolve to another kind entirely")
			% [one.size(), two.size()])
	for index: int in mini(one.size(), two.size()):
		_check(one[index] == two[index],
			("kind %d is %s in EnemyData.Shot and %s in EnemyShotData.Kind - "
				+ "the two have drifted and every repertoire is mis-aimed")
				% [index, one[index], two[index]])


func _test_every_named_shot_exists() -> void:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null:
			continue
		for id: String in breed.shot_ids:
			_check(ContentDB.enemy_shot(id) != null,
				("%s names the shot \"%s\", which is not in data/enemy_shots - "
					+ "it would quietly fall back to its single shot")
					% [breed.id, id])
	for value: Variant in ContentDB.enemy_shots.values():
		var shot := value as EnemyShotData
		if shot == null:
			continue
		_check(shot.weight > 0.0,
			"%s is worth nothing inside its own band" % shot.id)
		_check(shot.far <= 0.0 or shot.far > shot.near,
			"%s has a band that ends before it begins (%.0f to %.0f)"
				% [shot.id, shot.near, shot.far])


func _test_each_breed_knows_what_it_should() -> void:
	for id: Variant in EXPECTED:
		var breed: EnemyData = ContentDB.enemy(String(id))
		_check(breed != null, "%s is not a breed" % id)
		if breed == null:
			continue
		_check(breed.repertoire().size() == int(EXPECTED[id]),
			("%s should know %d shots and knows %d - variety is meant to rise "
				+ "with how far down the road a breed lives")
				% [id, int(EXPECTED[id]), breed.repertoire().size()])


## A repertoire has to answer more than one distance, or the draw decides
## nothing that matters.
func _test_a_repertoire_spans_its_ranges() -> void:
	for id: Variant in EXPECTED:
		var breed: EnemyData = ContentDB.enemy(String(id))
		if breed == null:
			continue
		var close_at: float = _close_of(breed)
		var far_at: float = _far_of(breed)
		var near_hand: int = 0
		var far_hand: int = 0
		var kinds: Dictionary = {}
		for shot: EnemyShotData in breed.repertoire():
			if shot.suits(close_at):
				near_hand += 1
			if shot.suits(far_at):
				far_hand += 1
			kinds[int(shot.kind)] = true
		_check(near_hand >= 1,
			"%s has nothing it prefers up close, so closing the gap costs the player nothing"
				% id)
		_check(far_hand >= 1,
			"%s has nothing it prefers at range, so backing off costs the player nothing"
				% id)
		_check(kinds.size() >= 2,
			("%s knows %d shots but only %d kind of shot - the verb that answers "
				+ "them never changes") % [id, breed.repertoire().size(), kinds.size()])


## **The measurement.** Range must lean the draw and must never decide it.
##
## Driven rather than read back: the real weights are drawn hundreds of times at
## two distances, because the property is statistical and an assertion about the
## constants would pass with the picker wired to anything at all.
func _test_the_draw_leans_on_range_without_gating() -> void:
	for id: Variant in EXPECTED:
		var breed: EnemyData = ContentDB.enemy(String(id))
		if breed == null or breed.repertoire().is_empty():
			continue
		var known: Array[EnemyShotData] = breed.repertoire()
		var close_counts: Dictionary = _draw(known, _close_of(breed))
		var far_counts: Dictionary = _draw(known, _far_of(breed))
		# Everything it knows must still be reachable at both distances, or the
		# band is a gate and the repertoire is one shot per range.
		for shot: EnemyShotData in known:
			_check(int(close_counts.get(shot.id, 0)) > 0,
				("%s can never throw %s up close - a band that refuses outright "
					+ "is a gate, not a preference") % [id, shot.id])
			_check(int(far_counts.get(shot.id, 0)) > 0,
				"%s can never throw %s at range" % [id, shot.id])
		# And the mix has to actually change with the distance.
		var moved: bool = false
		for shot: EnemyShotData in known:
			var near_share: float = float(close_counts.get(shot.id, 0)) / float(DRAWS)
			var far_share: float = float(far_counts.get(shot.id, 0)) / float(DRAWS)
			if absf(near_share - far_share) >= 0.12:
				moved = true
		_check(moved,
			("%s throws the same mix up close as at range - the choice is random "
				+ "rather than range-dependent") % id)


## The two distances this breed is actually asked about.
func _reach_of(breed: EnemyData) -> float:
	return breed.shot_range if breed.shot_range > 0.0 else ASSUMED_REACH


func _close_of(breed: EnemyData) -> float:
	return _reach_of(breed) * CLOSE_SHARE


func _far_of(breed: EnemyData) -> float:
	return _reach_of(breed) * FAR_SHARE


func _draw(known: Array[EnemyShotData], gap: float) -> Dictionary:
	var counts: Dictionary = {}
	for _pull: int in DRAWS:
		var total: float = 0.0
		for shot: EnemyShotData in known:
			total += maxf(shot.draw_weight(gap), 0.0)
		if total <= 0.0:
			continue
		var roll: float = _rng.randf() * total
		for shot: EnemyShotData in known:
			roll -= maxf(shot.draw_weight(gap), 0.0)
			if roll <= 0.0:
				counts[shot.id] = int(counts.get(shot.id, 0)) + 1
				break
	return counts


## **Every breed that shoots has something to shoot with.**
##
## `EXPECTED` only names breeds somebody thought to list, so a shooter left out
## of it was never checked at all - which is how `howler`, `horde_drummer` and
## `wolf_standard_bearer` kept firing the single pre-2026-09-13 bolt for a day
## after the rest of the roster stopped. The roster asks this question of
## itself now rather than of a hand-kept table.
func _test_every_shooter_has_a_repertoire() -> void:
	var shooters: int = 0
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed == null or breed.role != EnemyData.Role.HOWLER:
			continue
		shooters += 1
		_check(breed.repertoire().size() >= 2,
			("%s shoots for a living and knows %d shots - a breed with one is "
				+ "the single bolt this whole system replaced")
				% [breed.id, breed.repertoire().size()])
		_check(EXPECTED.has(breed.id),
			("%s shoots and EXPECTED does not name it, so nothing above checked "
				+ "how many shots it has") % breed.id)
	_check(shooters >= 12,
		"only %d shooters found; the roster should be full of them" % shooters)


## **A look is a breed's own, and a breed's shots look unlike each other.**
##
## This held every shot in the pool a colour apart from every other while the
## pool was twelve shared files. Since 2026-09-21 every breed owns its shots -
## eighty-odd files - and two breeds a region apart may fairly fly the same
## ember; what has to stay true is *within* a breed, where two shots of one
## kind with one head and one colour are a single shot drawn twice. Amended
## deliberately, and the ownership itself is held by `enemy_shot_check`.
func _test_every_shot_looks_like_itself() -> void:
	for value: Variant in ContentDB.enemy_shots.values():
		var shot := value as EnemyShotData
		if shot == null:
			continue
		_check(shot.tint.a > 0.0,
			("%s leaves its tint transparent, so it flies in whatever colour "
				+ "every other shot flies in") % shot.id)
	for id: Variant in EXPECTED:
		var breed: EnemyData = ContentDB.enemy(String(id))
		if breed == null:
			continue
		var seen: Array[EnemyShotData] = []
		for shot: EnemyShotData in breed.repertoire():
			for other: EnemyShotData in seen:
				var apart: float = absf(shot.tint.r - other.tint.r) + absf(shot.tint.g - other.tint.g) \
					+ absf(shot.tint.b - other.tint.b)
				_check(int(shot.kind) != int(other.kind) or int(shot.head) != int(other.head)
						or apart > 0.18,
					("%s throws %s and %s, which are the same kind, the same head and "
						+ "the same colour - one shot drawn twice") % [id, other.id, shot.id])
			seen.append(shot)

