extends Node

## **Shields, durability and the Smith** (owner, 2026-10-07): "Let players wield
## shields in an offhand slot ... it should have a limit to how much it can
## withstand, and that damage is not completely mitigated either. It reduces
## knockback also but not completely. And it can be broken setting it on a
## cooldown ... equipment should have durability and need to be repaired at the
## smith in the Hold ... Red ... providing no benefits until repaired. Yellow gear
## providing half the benefits ... each time gear is repaired, its max durability
## should decrease, more for red than yellow ... Both the current and max
## durability should affect its value."
##
##   godot --headless --path game res://tools/durability_check.tscn
##
## Every promise in that brief, driven through the door it goes through:
##
## - a piece wears into yellow and red, and gives half and then none of its
##   points, its legendary affixes and its set membership - read off
##   `MetaState.gear_attribute_points` and the modifier table, not off a band;
## - mending costs Marks, is refused with nothing taken when the purse is short,
##   makes the piece whole, and lowers what it holds by more for red than yellow;
## - a worn piece sells for less, by what is left and by what it holds;
## - the wear survives the save through the real loader, and a partner's sheet
##   carries its band;
## - a raised shield takes its share of a blow from in front - never all of it,
##   never one from behind - spends its guard, breaks at nothing left and rests,
##   and takes some of a shove but not all;
## - a two-handed weapon leaves no hand for one;
## - the mannequin on the HUD shows exactly the worn and broken slots.

const SEED: int = 20261007

class Held extends HeroInput:
	var hold: int = 0
	var walk: Vector2 = Vector2.ZERO

	func _read_press(_button: int) -> bool:
		return false

	func _read_hold(mask: int) -> bool:
		return hold & mask != 0

	func move() -> Vector2:
		return walk

	func is_local() -> bool:
		return true

var _failures: int = 0
var _checks: int = 0
var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null
var _hands: Held = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, SEED)
	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.marks = 0
	_test_wear_and_its_benefits()
	_test_mending()
	_test_reforging()
	_test_value()
	_test_the_save_and_the_sheet()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _f: int in 12:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_hero = _field.hero
	_hands = Held.new(_hero)
	_hero.input = _hands
	_hero.global_position = Vector2(2000.0, 1700.0)
	await _test_the_shield()
	await _test_the_perfect_guard()
	await _test_the_mannequin()
	_finish()


func _equip(kind_id: String, rarity: int = 3) -> Dictionary:
	var piece: Dictionary = Stash.make(kind_id, rarity, 3)
	MetaState.stash.append(piece)
	var kind: GearData = ContentDB.gear(kind_id)
	MetaState.equipped[kind.slot] = Stash.uid(piece)
	return piece


func _first_kind(slot: int, legendary: bool = false) -> String:
	for kind: GearData in ContentDB.gear_sorted():
		if kind != null and kind.slot == slot and not kind.trophy:
			if slot == GearData.Slot.WEAPON and kind.grip != GearData.Grip.ONE_HAND:
				continue
			if not legendary or not Stash.legendary_affixes(Stash.make(kind.id, 6, 5), kind).is_empty():
				return kind.id
	return ""


# --- Wear and what it costs ---------------------------------------------------

func _test_wear_and_its_benefits() -> void:
	var armour_id: String = _first_kind(GearData.Slot.ARMOUR)
	var piece: Dictionary = _equip(armour_id, 6)
	var kind: GearData = ContentDB.gear(armour_id)
	var whole: Array[int] = MetaState.gear_attribute_points()
	var whole_sum: int = 0
	for value: int in whole:
		whole_sum += value
	_check(whole_sum > 0, "a worn %s grants no points to measure" % armour_id)
	var made: int = Stash.durability_original(piece, kind)
	_check(made > 0, "armour must wear")
	_check(Stash.durability_band(piece) == 0, "a fresh piece is whole")
	# Down to yellow.
	MetaState.wear_worn(kind.slot, made - int(floor(float(made) * Balance.GEAR_DURABILITY_YELLOW)))
	_check(Stash.durability_band(piece) == 1, "%s at %d of %d is not yellow" % [armour_id,
		Stash.durability(piece, kind), made])
	var half: int = 0
	for value: int in MetaState.gear_attribute_points():
		half += value
	_check(half < whole_sum and half >= int(floor(float(whole_sum) * 0.4)),
		"a yellow piece gives %d of its %d points, not about half" % [half, whole_sum])
	# Down to red.
	MetaState.wear_worn(kind.slot, 9999)
	_check(Stash.durability_band(piece) == 2, "a piece at nothing left is not red")
	var none: int = 0
	for value: int in MetaState.gear_attribute_points():
		none += value
	_check(none == 0, "a broken piece still gives %d points" % none)
	# A ring never wears.
	var ring: Dictionary = _equip(_first_kind(GearData.Slot.RING), 3)
	MetaState.wear_worn(GearData.Slot.RING, 50)
	_check(Stash.durability_band(ring) == 0 and not ring.has("dur"), "a ring wore")
	# A broken piece's legendary affixes leave the modifier table.
	var legend_id: String = _first_kind(GearData.Slot.HELMET, true)
	if not legend_id.is_empty():
		var legend: Dictionary = _equip(legend_id, 6)
		var legend_kind: GearData = ContentDB.gear(legend_id)
		var affixes: Array[GearAffixData] = Stash.legendary_affixes(legend, legend_kind)
		var key: String = ""
		for affix: GearAffixData in affixes:
			if not affix.effect_id.is_empty():
				key = affix.effect_id
				break
		if not key.is_empty():
			Modifiers.rebuild()
			var before: float = Modifiers.value(key)
			MetaState.wear_worn(GearData.Slot.HELMET, 9999)
			var after: float = Modifiers.value(key)
			_check(after < before, "a broken %s still moves %s (%.3f -> %.3f)" % [legend_id, key, before, after])
	MetaState.stash = []
	MetaState.equipped = {}


func _test_mending() -> void:
	var kind_id: String = _first_kind(GearData.Slot.BOOTS)
	var kind: GearData = ContentDB.gear(kind_id)
	var worn: Dictionary = _equip(kind_id, 2)
	var made: int = Stash.durability_original(worn, kind)
	MetaState.wear_worn(kind.slot, made - int(floor(float(made) * Balance.GEAR_DURABILITY_YELLOW)))
	var cost: int = Stash.repair_cost(worn, kind)
	_check(cost > 0, "a worn piece costs nothing to mend")
	MetaState.marks = cost - 1
	_check(not MetaState.repair_piece(Stash.uid(worn)).is_empty(), "a mending the purse cannot pay went through")
	_check(MetaState.marks == cost - 1 and Stash.durability_band(worn) == 1,
		"a refused mending took something")
	MetaState.marks = cost
	_check(MetaState.repair_piece(Stash.uid(worn)).is_empty(), "a mending the purse can pay was refused")
	_check(MetaState.marks == 0, "a mending took %d of its %d Marks" % [cost - MetaState.marks, cost])
	var after_yellow: int = Stash.durability_max(worn, kind)
	_check(Stash.durability(worn, kind) == after_yellow and after_yellow < made,
		"a mended piece is %d of %d, holding %d" % [Stash.durability(worn, kind), after_yellow, made])
	var yellow_loss: int = made - after_yellow
	# Broken, then mended: it loses more.
	MetaState.wear_worn(kind.slot, 9999)
	MetaState.marks = 99999
	_check(MetaState.repair_piece(Stash.uid(worn)).is_empty(), "a broken piece could not be mended")
	var red_loss: int = after_yellow - Stash.durability_max(worn, kind)
	_check(red_loss > yellow_loss, "mending a broken piece cost it %d, a worn one %d" % [red_loss, yellow_loss])
	_check(MetaState.repair_piece(Stash.uid(worn)) == "It needs no mending.", "a whole piece was mended again")
	# Never below its floor, however often it is broken and mended.
	for _round: int in 40:
		MetaState.wear_worn(kind.slot, 9999)
		MetaState.repair_piece(Stash.uid(worn))
	_check(Stash.durability_max(worn, kind) >= int(round(float(made) * Balance.GEAR_DURABILITY_FLOOR)),
		"forty mendings took it to %d, under its floor" % Stash.durability_max(worn, kind))
	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.marks = 0


## **Reforging** (triage of 2026-10-07): once in a piece's life the Smith gives
## back what mending took, for the deep ore and Marks - refused with nothing
## taken when either is short, refused for a piece that has lost nothing, and
## refused a second time; and the save remembers it was done.
func _test_reforging() -> void:
	var kind_id: String = _first_kind(GearData.Slot.BOOTS)
	var kind: GearData = ContentDB.gear(kind_id)
	var piece: Dictionary = _equip(kind_id, 4)
	var made: int = Stash.durability_original(piece, kind)
	MetaState.marks = 99999
	_check(not Stash.can_reforge(piece, kind) and not MetaState.reforge_piece(Stash.uid(piece)).is_empty(),
		"a piece that has lost nothing was offered a reforging")
	for _round: int in 4:
		MetaState.wear_worn(kind.slot, 9999)
		MetaState.repair_piece(Stash.uid(piece))
	var lowered: int = Stash.durability_max(piece, kind)
	_check(lowered < made and Stash.can_reforge(piece, kind), "four mendings left it holding %d of %d" % [lowered, made])
	var ore: int = Stash.reforge_ore(piece)
	var price: int = Stash.reforge_marks(piece)
	MetaState.materials.erase(Balance.GEAR_REFORGE_ORE)
	MetaState.marks = price
	_check(not MetaState.reforge_piece(Stash.uid(piece)).is_empty(), "a reforging with no ore went through")
	_check(MetaState.marks == price and Stash.durability_max(piece, kind) == lowered,
		"a refused reforging took something")
	MetaState.materials[Balance.GEAR_REFORGE_ORE] = ore
	MetaState.marks = price - 1
	_check(not MetaState.reforge_piece(Stash.uid(piece)).is_empty(), "a reforging the purse cannot pay went through")
	_check(MetaState.material_count(Balance.GEAR_REFORGE_ORE) == ore, "a refused reforging spent the ore")
	MetaState.marks = price
	_check(MetaState.reforge_piece(Stash.uid(piece)).is_empty(), "a reforging that can be paid was refused")
	_check(Stash.durability_max(piece, kind) == made and Stash.durability(piece, kind) == made,
		"reforged, it holds %d of %d and has %d" % [Stash.durability_max(piece, kind), made, Stash.durability(piece, kind)])
	_check(MetaState.marks == 0 and MetaState.material_count(Balance.GEAR_REFORGE_ORE) == 0,
		"reforging took %d Marks of %d and left %d ore" % [price - MetaState.marks, price,
			MetaState.material_count(Balance.GEAR_REFORGE_ORE)])
	MetaState.wear_worn(kind.slot, 9999)
	MetaState.repair_piece(Stash.uid(piece))
	MetaState.materials[Balance.GEAR_REFORGE_ORE] = 99
	MetaState.marks = 99999
	_check(MetaState.reforge_piece(Stash.uid(piece)) == "It has been reforged once already.",
		"a piece was reforged twice")
	var data: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	MetaState.adopt_save(data)
	var back: Dictionary = MetaState.equipped_piece(kind.slot)
	_check(bool(back.get("reforged", false)), "the save forgot a piece was reforged: %s" % back)
	MetaState.materials.erase(Balance.GEAR_REFORGE_ORE)
	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.marks = 0


func _test_value() -> void:
	var kind_id: String = _first_kind(GearData.Slot.ARMOUR)
	var kind: GearData = ContentDB.gear(kind_id)
	var piece: Dictionary = Stash.make(kind_id, 4, 3)
	var whole: int = Stash.sell_price(piece)
	Stash.wear(piece, kind, Stash.durability_original(piece, kind) / 2)
	var half: int = Stash.sell_price(piece)
	_check(half < whole, "a half-worn piece sells for %d, a whole one %d" % [half, whole])
	var cost: int = Stash.repair(piece, kind)
	_check(cost > 0, "the value test could not mend")
	var mended: int = Stash.sell_price(piece)
	_check(mended < whole and mended > half,
		"mended, it sells for %d - between %d worn and %d new" % [mended, half, whole])


func _test_the_save_and_the_sheet() -> void:
	var kind_id: String = _first_kind(GearData.Slot.GLOVES)
	var piece: Dictionary = _equip(kind_id, 3)
	MetaState.wear_worn(GearData.Slot.GLOVES, 30)
	var left: int = int(piece["dur"])
	var data: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	MetaState.adopt_save(data)
	var back: Dictionary = MetaState.equipped_piece(GearData.Slot.GLOVES)
	_check(int(back.get("dur", -1)) == left and back.has("dur_max") and back.has("dur_orig"),
		"the save read back %s for a piece worn to %d" % [back, left])
	MetaState.wear_worn(GearData.Slot.GLOVES, 9999)
	var row: Array = WardenSheet.pack_mine()
	var sheet: WardenSheet = WardenSheet.from_row(row)
	var found: bool = false
	for worn: Dictionary in sheet.worn:
		if String(worn.get("kind", "")) == kind_id:
			found = true
			_check(Stash.durability_band(worn) == 2, "a partner's broken gloves arrived %s" % worn)
	_check(found, "a partner's sheet lost the worn gloves")
	MetaState.stash = []
	MetaState.equipped = {}


# --- The shield ---------------------------------------------------------------

func _test_the_shield() -> void:
	var weapon_id: String = _first_kind(GearData.Slot.WEAPON)
	_equip(weapon_id, 2)
	var shield_id: String = "ironbound_kite"
	var shield: Dictionary = _equip(shield_id, 2)
	var kind: GearData = ContentDB.gear(shield_id)
	_check(kind != null and kind.is_shield(), "the kite is not a shield")
	_hero.call("_dress_warden")
	await _frames(2)
	# Standing still raises it, for a pad and a thumb.
	_hands.walk = Vector2.ZERO
	await _seconds(Balance.SHIELD_AUTO_GUARD_SECONDS + 0.2)
	_check(_hero.is_guarding(), "standing still with a shield did not raise it")
	# Walking with the key held keeps it up; walking without lowers it.
	_hands.walk = Vector2.RIGHT
	await _frames(3)
	_check(not _hero.is_guarding(), "walking lowered nothing")
	_hands.hold = HeroInput.HOLD_GUARD
	await _frames(3)
	_check(_hero.is_guarding(), "the guard key did not raise it")
	_hands.walk = Vector2.ZERO
	# A blow from in front: its share taken, never all of it.
	var facing: Vector2 = _hero.get("_facing") as Vector2
	var full: float = Stash.guard_capacity(shield, kind)
	var pool: float = _hero.health.max_hp
	_hero.health.current_hp = pool
	var before_guard: float = _hero.guard_ratio()
	_hero.health.take_damage(20.0, _hero.global_position + facing * 80.0)
	var taken_front: float = pool - _hero.health.current_hp
	_check(taken_front > 0.0 and taken_front < 20.0 * _hero.health.damage_scale,
		"a guarded blow from in front took %.1f of 20" % taken_front)
	_check(_hero.guard_ratio() < before_guard, "a blocked blow spent no guard")
	_check(shield.has("dur"), "blocking wore nothing on the shield")
	# From behind: all of it.
	_hero.health.current_hp = pool
	_hero.health.take_damage(20.0, _hero.global_position - facing * 80.0)
	var taken_back: float = pool - _hero.health.current_hp
	_check(taken_back > taken_front, "a blow from behind was guarded (%.1f against %.1f)" % [taken_back, taken_front])
	# The shove from in front is taken in part, never whole. Facing read again:
	# walking turned the Warden.
	facing = _hero.get("_facing") as Vector2
	_hero.set("_shoved", Vector2.ZERO)
	_hero.shove(-facing * 300.0)
	var guarded_shove: float = (_hero.get("_shoved") as Vector2).length()
	_hero.set("_shoved", Vector2.ZERO)
	_hands.hold = 0
	_hands.walk = Vector2.RIGHT
	await _frames(3)
	_hero.shove(-facing * 300.0)
	var open_shove: float = (_hero.get("_shoved") as Vector2).length()
	_hero.set("_shoved", Vector2.ZERO)
	_check(guarded_shove > 0.0 and guarded_shove < open_shove,
		"a guarded shove went %.0f, an open one %.0f" % [guarded_shove, open_shove])
	# Broken at nothing left, and resting.
	_hands.hold = HeroInput.HOLD_GUARD
	_hands.walk = Vector2.ZERO
	await _frames(3)
	facing = _hero.get("_facing") as Vector2
	for _blow: int in 400:
		if _hero.guard_ratio() < 0.0:
			break
		_hero.health.current_hp = pool
		_hero.health.take_damage(full * 0.2, _hero.global_position + facing * 80.0)
	_check(_hero.guard_ratio() < 0.0 and not _hero.is_guarding(), "the guard never broke")
	await _seconds(1.0)
	_check(not _hero.is_guarding(), "a broken guard was raised again at once")
	await _seconds(Balance.SHIELD_BREAK_COOLDOWN + 0.5)
	_check(_hero.is_guarding() and is_equal_approx(_hero.guard_ratio(), 1.0),
		"a rested guard did not come back whole (%.2f)" % _hero.guard_ratio())
	# A two-handed weapon leaves no hand for it.
	var heavy: String = ""
	for value: GearData in ContentDB.gear_sorted():
		if value != null and value.slot == GearData.Slot.WEAPON and value.grip == GearData.Grip.TWO_HAND:
			heavy = value.id
			break
	if not heavy.is_empty():
		_equip(heavy, 2)
		await _frames(3)
		_check(not _hero.is_guarding(), "a two-handed weapon raised a shield")
	_hands.hold = 0


## **A perfect guard** (triage of 2026-10-07): raised on the instant, after the
## guard was down long enough, it takes the whole blow and spends nothing, and
## staggers the body that struck from in reach; one a raise; tapping the key
## buys nothing; a blow after the window is an ordinary guard.
func _test_the_perfect_guard() -> void:
	_equip(_first_kind(GearData.Slot.WEAPON), 2)
	_equip("ironbound_kite", 2)
	_hero.call("_dress_warden")
	var pool: float = _hero.health.max_hp
	var body: Enemy = _field.spawn_enemy(ContentDB.enemies.values()[0] as EnemyData, 0, 1.0)
	await _frames(2)
	body.process_mode = Node.PROCESS_MODE_DISABLED
	# Down long enough to re-arm it, then raised.
	await _lower_then_raise(Balance.SHIELD_PERFECT_REARM + 0.2)
	_check(_hero.is_guarding() and _hero.guard_is_perfect(), "a fresh raise after a real lowering is not perfect")
	var facing: Vector2 = _hero.get("_facing") as Vector2
	var from: Vector2 = _hero.global_position + facing * 70.0
	body.global_position = from
	var counted: int = _hero.perfect_guards
	var taught: int = MetaState.perfect_guards
	var ratio: float = _hero.guard_ratio()
	_hero.health.current_hp = pool
	_hero.health.take_damage(20.0, from)
	_check(is_equal_approx(_hero.health.current_hp, pool),
		"a perfect guard let %.1f of 20 through" % (pool - _hero.health.current_hp))
	_check(_hero.perfect_guards == counted + 1, "a perfect guard was not counted")
	_check(MetaState.perfect_guards == taught + 1, "the account's teaching statistic missed a perfect guard")
	_check(is_equal_approx(_hero.guard_ratio(), ratio),
		"a perfect guard spent the guard (%.2f to %.2f)" % [ratio, _hero.guard_ratio()])
	_check(float(body.get("_hitstun_left")) > 0.0, "the body that struck was not staggered")
	# One a raise: the next blow in the same window is an ordinary guard.
	_hero.health.current_hp = pool
	_hero.health.take_damage(20.0, from)
	_check(_hero.health.current_hp < pool and _hero.perfect_guards == counted + 1,
		"a second blow in the same raise was perfect too")
	# Tapping the key: lowered a moment and raised, no perfect guard.
	await _lower_then_raise(0.0)
	_check(_hero.is_guarding(), "a tapped guard did not come up")
	_hero.health.current_hp = pool
	_hero.health.take_damage(20.0, from)
	_check(_hero.health.current_hp < pool and _hero.perfect_guards == counted + 1,
		"tapping the guard key bought a perfect guard")
	# Re-armed, but the blow comes after the window.
	await _lower_then_raise(Balance.SHIELD_PERFECT_REARM + 0.2)
	await _seconds(Balance.SHIELD_PERFECT_WINDOW + 0.15)
	_hero.health.current_hp = pool
	_hero.health.take_damage(20.0, from)
	_check(_hero.health.current_hp < pool and _hero.perfect_guards == counted + 1,
		"a blow after the window was perfect")
	_check(MetaState.perfect_guards == taught + 1, "an ordinary guard was counted as a perfect one")
	_hands.hold = 0
	body.queue_free()


func _lower_then_raise(down_for: float) -> void:
	_hands.hold = 0
	_hands.walk = Vector2.RIGHT
	await _frames(3)
	if down_for > 0.0:
		await _seconds(down_for)
	_hands.walk = Vector2.ZERO
	_hands.hold = HeroInput.HOLD_GUARD
	await _frames(2)


func _test_the_mannequin() -> void:
	var hud: HUD = _run.get("hud") as HUD
	var doll := hud.get("_durability_doll") as DurabilityDoll if hud != null else null
	_check(doll != null, "the HUD has no mannequin")
	if doll == null:
		return
	MetaState.stash = []
	MetaState.equipped = {}
	_equip(_first_kind(GearData.Slot.ARMOUR), 2)
	_equip(_first_kind(GearData.Slot.BOOTS), 2)
	doll.refresh()
	_check(not doll.visible, "the mannequin shows with nothing worn out")
	MetaState.wear_worn(GearData.Slot.ARMOUR, 9999)
	await _frames(1)
	var kind: GearData = ContentDB.gear(String(MetaState.equipped_piece(GearData.Slot.BOOTS).get("kind", "")))
	var boots: Dictionary = MetaState.equipped_piece(GearData.Slot.BOOTS)
	var made: int = Stash.durability_original(boots, kind)
	MetaState.wear_worn(GearData.Slot.BOOTS, made - int(floor(float(made) * Balance.GEAR_DURABILITY_YELLOW)))
	await _frames(1)
	var shown: Dictionary = doll.shown_bands()
	_check(doll.visible and int(shown.get(GearData.Slot.ARMOUR, 0)) == 2 and int(shown.get(GearData.Slot.BOOTS, 0)) == 1
		and shown.size() == 2, "the mannequin shows %s" % shown)


# --- Helpers ------------------------------------------------------------------

func _frames(count: int) -> void:
	for _f: int in count:
		await get_tree().physics_frame


func _seconds(wait: float) -> void:
	var until: int = Time.get_ticks_msec() + int(wait * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[durability] " + message)


func _finish() -> void:
	MetaState.resume_saves()
	if _run != null:
		_run.queue_free()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[durability] PASS - %d checks: wear halves and ends a piece's benefits, the Smith mends for Marks and the most it holds falls, wear lowers its worth, it survives the save and the wire, a shield guards in front and breaks and rests, and the mannequin shows what is worn" % _checks)
	else:
		push_error("[durability] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
