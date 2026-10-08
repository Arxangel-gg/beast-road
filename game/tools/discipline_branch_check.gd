extends Node
## discipline_branch_check: the tree's phase 2 (docs/SKILL_TREE_D4_2026-09-28.md)
## does what it says, through the real doors.
##
## A branch that is authored, drawn and priced and read by nothing is the
## placebo `DisciplineEffects` exists to prevent, and a grep proves wiring and
## not behaviour. So every kind of thing here is *driven*: a rank through
## `learn_discipline` three times and read back off `learned_effect_value`; a
## fork's twin refused at the door; a second Oath refused; a spell branch
## through a real `SpellCaster` cast with the number read off the strike it
## put in the air or the body it hit; a form branch through a real
## `HeroAttack` finisher on a real body; an Oath on a real `Hero`. And the
## sheet a partner would send carries the ranks back.
##
## Stamped: a GDScript runtime error aborts the function it happens in and
## nothing else, so every test marks its own last line and `_ready` counts
## the stamps.

const ENEMY_SCENE: String = "res://scenes/battlefield/enemy.tscn"
const HERO_SCENE: String = "res://scenes/hero/hero.tscn"
const STAGES: Array[String] = ["ranks", "sheet", "oath_and_forks", "gatebroken", "spell_branches",
	"form_branches", "oaths_on_the_hero", "ceiling"]

var _failures: PackedStringArray = []
var _checks: int = 0
var _reached: Dictionary = {}
var _field: EnemyField = null
var _caster: SpellCaster = null
var _healed: float = 0.0


## What the swing calls on its owner, recorded.
class OwnerProbe extends Node2D:
	var healed: float = 0.0
	var refunded: float = 0.0
	var dash_refund: float = 0.0
	var finishers: int = 0
	func heal_unscaled(amount: float) -> void:
		healed += amount
	func refund_mana_share(share: float) -> void:
		refunded += share
	func refund_dash(fraction: float) -> void:
		dash_refund += fraction
	func note_finisher_landed() -> void:
		finishers += 1


## A tower as the Kept Gate and the Bastion Hymn see one: a place, and a ward.
class TowerProbe extends Node2D:
	var warded: float = 0.0
	func ward(share: float) -> void:
		warded += share


func _ready() -> void:
	MetaState.hold_saves()
	# Blows are compared by ratio here; a zone's critical is a coin no test asked about.
	Hitbox.zone_crits = false
	GameDirector.run_active = false
	_fresh()
	RunState.reset(false, 20260928)
	RunState.phase = RunState.Phase.ROAD_BATTLE
	_field = EnemyField.new()
	add_child(_field)
	_caster = SpellCaster.new()
	_caster.field = _field
	_caster.heal_requested.connect(func(amount: float) -> void: _healed += amount)
	add_child(_caster)
	await get_tree().process_frame
	_test_ranks()
	_test_the_sheet_carries_ranks()
	_test_one_oath_and_one_fork()
	_test_gatebroken()
	await _test_spell_branches()
	await _test_form_branches()
	await _test_oaths_on_the_hero()
	_test_the_ceiling()
	for stage: String in STAGES:
		_check(_reached.has(stage), "'%s' never reached its end - a SCRIPT ERROR above aborted it" % stage)
	_fresh()
	Hitbox.zone_crits = true
	MetaState.resume_saves()
	Sfx.stop_immediately()
	Vfx.clear()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures.is_empty():
		print("[discipline-branch] PASS - %d checks: ranks, forks, one Oath, and every kind of branch moves the number it names" % _checks)
	else:
		for failure: String in _failures:
			push_error("[discipline-branch] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


# --- Ranks ---------------------------------------------------------------------

## A passive is learned again for a rank, each a point, worth its value a
## rank, refused past its top, and let go a rank at a time.
func _test_ranks() -> void:
	_fresh()
	var passive: DisciplineNodeData = ContentDB.discipline_node("hunters_pulse")
	if not _checked(passive != null and passive.ranks == 3, "Hunter's Pulse must carry three ranks"):
		return
	var key: String = passive.effect_id
	for rank: int in 3:
		_check(MetaState.learn_discipline(passive.id).is_empty(), "rank %d must be learnable" % (rank + 1))
	_check(MetaState.discipline_rank(passive.id) == 3, "three learns are rank three, held %d"
		% MetaState.discipline_rank(passive.id))
	_check(MetaState.skill_points_spent() == 3, "three ranks are three points, spent %d"
		% MetaState.skill_points_spent())
	_check(is_equal_approx(MetaState.learned_effect_value(key), passive.effect_value * 3.0),
		"rank three is worth three times the per-rank value: %.3f against %.3f"
			% [MetaState.learned_effect_value(key), passive.effect_value * 3.0])
	_check(MetaState.learn_problem(passive.id) == "Already learned.",
		"a fourth rank must be refused, said: %s" % MetaState.learn_problem(passive.id))
	_check(int(MetaState.discipline_depth().get(passive.discipline, 0)) == 4,
		"depth counts points: the free form and three ranks are 4, counted %d"
			% int(MetaState.discipline_depth().get(passive.discipline, 0)))
	_check(MetaState.unlearn_discipline(passive.id).is_empty() and MetaState.discipline_rank(passive.id) == 2,
		"letting go takes one rank")
	# A save that claims four ranks reads three.
	var saved: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	var hero: Dictionary = saved.get("hero", {}) as Dictionary
	hero["tree"] = {passive.id: 4}
	saved["hero"] = hero
	MetaState.adopt_save(saved)
	_check(MetaState.discipline_rank(passive.id) == 3,
		"a save holding rank four of a three-rank passive must read as three, read %d"
			% MetaState.discipline_rank(passive.id))
	_fresh()
	_reached["ranks"] = true


## The row a partner sends carries the rank, and an older build's bare id is
## rank one.
func _test_the_sheet_carries_ranks() -> void:
	_fresh()
	var passive: DisciplineNodeData = ContentDB.discipline_node("hunters_pulse")
	MetaState.learn_discipline(passive.id)
	MetaState.learn_discipline(passive.id)
	var row: Array = WardenSheet.pack_mine()
	var learned: Array = row[WardenSheet.AT_LEARNED] as Array
	_check(learned.has("hunters_pulse:2"), "the packed row must carry the rank: %s" % str(learned))
	var sheet: WardenSheet = WardenSheet.from_row(row)
	_check(int(sheet.learned.get(passive.id, 0)) == 2, "the sheet read back must hold rank two, held %s"
		% str(sheet.learned.get(passive.id, 0)))
	_check(is_equal_approx(WardenSheet.trained_value_of(sheet, passive.effect_id), passive.effect_value * 2.0),
		"a partner's rank two is worth two ranks")
	row[WardenSheet.AT_LEARNED] = ["hunters_pulse"]
	var bare: WardenSheet = WardenSheet.from_row(row)
	_check(int(bare.learned.get(passive.id, 0)) == 1, "a bare id from an older build reads as rank one")
	_fresh()
	_reached["sheet"] = true


# --- One Oath, one fork -----------------------------------------------------------

func _test_one_oath_and_one_fork() -> void:
	_fresh()
	_fill_arm(DisciplineNodeData.Discipline.BLOOD)
	_fill_arm(DisciplineNodeData.Discipline.HOLY)
	_check(MetaState.learn_discipline("oath_red_road").is_empty(), "an Oath is sworn at the tip: %s"
		% MetaState.learn_problem("oath_red_road"))
	var second: String = MetaState.learn_problem("oath_kept_gate")
	_check(second.contains("sworn"), "a second Oath must be refused as one at a time, said: %s" % second)
	var sworn: DisciplineNodeData = MetaState.sworn_oath()
	_check(sworn != null and sworn.id == "oath_red_road", "the sworn Oath is the one learned")
	_check(MetaState.unlearn_discipline("oath_red_road").is_empty()
			and MetaState.learn_discipline("oath_kept_gate").is_empty(),
		"let go, the other Oath may be sworn")
	# A fork waits for its enhancement and closes its twin.
	_fresh()
	_fill_arm(DisciplineNodeData.Discipline.BLOOD, 2)
	MetaState.discipline_tree.erase("red_pursuit_long")
	MetaState.discipline_tree.erase("red_pursuit_hound")
	MetaState.discipline_tree.erase("red_pursuit_sever")
	_check(MetaState.learn_problem("red_pursuit_hound").contains("first"),
		"a fork must wait for its enhancement, said: %s" % MetaState.learn_problem("red_pursuit_hound"))
	_check(MetaState.learn_discipline("red_pursuit_long").is_empty()
			and MetaState.learn_discipline("red_pursuit_hound").is_empty(),
		"the enhancement and then a fork are learned")
	_check(MetaState.learn_problem("red_pursuit_sever").contains("exclude"),
		"the twin fork must be closed, said: %s" % MetaState.learn_problem("red_pursuit_sever"))
	# A save holding both forks keeps one.
	var saved: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	var hero: Dictionary = saved.get("hero", {}) as Dictionary
	var tree: Dictionary = (hero.get("tree", {}) as Dictionary).duplicate()
	tree["red_pursuit_sever"] = 1
	hero["tree"] = tree
	saved["hero"] = hero
	MetaState.adopt_save(saved)
	_check(MetaState.owns_discipline("red_pursuit_hound") != MetaState.owns_discipline("red_pursuit_sever"),
		"a save holding both forks of a pair must keep exactly one")
	_fresh()
	_reached["oath_and_forks"] = true


# --- Gatebroken ---------------------------------------------------------------------------

## **A Warden who beat the Gatekeeper swears two Oaths** (docs/GATEBROKEN_2026-09-28.md),
## from two arms; a third is refused; a partner's row says so; and the Mantle
## he pays is never rolled, stocked or forged.
func _test_gatebroken() -> void:
	_fresh()
	_fill_arm(DisciplineNodeData.Discipline.BLOOD)
	_fill_arm(DisciplineNodeData.Discipline.HOLY)
	_fill_arm(DisciplineNodeData.Discipline.BERSERK)
	var tier: CampaignTierData = ContentDB.tiers_sorted()[0]
	_check(MetaState.oaths_allowed() == 1, "before the Gatekeeper falls one Oath is allowed")
	MetaState.gatekeeper[tier.id] = GatekeeperTrials.STAGES
	_check(GatekeeperTrials.is_gatebroken(tier.id) and MetaState.oaths_allowed() == Balance.OATHS_GATEBROKEN,
		"rung four is Gatebroken, and two Oaths are allowed")
	_check(MetaState.learn_discipline("oath_red_road").is_empty()
			and MetaState.learn_discipline("oath_kept_gate").is_empty(),
		"a Gatebroken Warden swears a second Oath: %s" % MetaState.learn_problem("oath_kept_gate"))
	var third: String = MetaState.learn_problem("oath_no_retreat")
	_check(third.contains("two Oaths"), "a third Oath is refused, said: %s" % third)
	_check(MetaState.sworn_oaths().size() == 2, "both Oaths are sworn")
	_check(is_equal_approx(DisciplineUpgrades.boon(MetaState.discipline_tree, "oath_lifesteal"),
			ContentDB.discipline_node("oath_red_road").effect_value)
			and is_equal_approx(DisciplineUpgrades.bane(MetaState.discipline_tree, "oath_no_tower_penalty"),
			ContentDB.discipline_node("oath_kept_gate").bane_value),
		"both Oaths' boons and banes are read")
	_check(MetaState.warden_title().contains("Gatebroken"), "the title says Gatebroken: %s" % MetaState.warden_title())
	# The row a partner sends carries the allowance, and a host keeps both.
	var row: Array = WardenSheet.pack_mine()
	var sheet: WardenSheet = WardenSheet.from_row(row)
	_check(sheet.oaths_allowed == 2 and DisciplineUpgrades.oaths_of(sheet.learned).size() == 2,
		"a Gatebroken partner's sheet keeps both Oaths (allowed %d, kept %d)"
			% [sheet.oaths_allowed, DisciplineUpgrades.oaths_of(sheet.learned).size()])
	row.resize(WardenSheet.AT_OATHS)
	var older: WardenSheet = WardenSheet.from_row(row)
	_check(DisciplineUpgrades.oaths_of(older.learned).size() == 1,
		"a row from an older build reads as one Oath, and keeps the first")
	# Losing the rungs takes the second Oath back on the next read.
	MetaState.gatekeeper = {}
	var saved: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	MetaState.adopt_save(saved)
	_check(MetaState.sworn_oaths().size() == 1, "not Gatebroken, a save holding two Oaths keeps one")
	# The Mantle.
	var mantle: Dictionary = GatekeeperTrials.mantle_for(tier.id)
	var kind: GearData = ContentDB.gear(String(mantle.get("kind", "")))
	_check(kind != null and kind.trophy and kind.slot == GearData.Slot.CAPE,
		"the Gatekeeper pays a trophy cape on %s" % tier.id)
	_check(int(mantle.get("rarity", -1)) == Stash.RARITY_NAMES.find("Oathbound"),
		"the Long Road's Mantle is Oathbound, was %d" % int(mantle.get("rarity", -1)))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260928
	var rolled: int = 0
	for _roll: int in 600:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 2, rng)
		var rolled_kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if rolled_kind != null and rolled_kind.trophy:
			rolled += 1
	_check(rolled == 0, "a trophy must never be rolled, rolled %d in 600" % rolled)
	_fresh()
	_reached["gatebroken"] = true


# --- Spell branches ---------------------------------------------------------------------

func _test_spell_branches() -> void:
	_fresh()
	# Wide Fall: the strike's radius, read off the strike in the air.
	_learn("ember_fall_rite")
	var ember: SpellData = ContentDB.spells.get("ember_fall")
	_equip(ember)
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var plain: float = _strike_radius()
	_learn("ember_fall_rite_wide")
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var wide: float = _strike_radius()
	var wide_node: DisciplineNodeData = ContentDB.discipline_node("ember_fall_rite_wide")
	_check(plain > 0.0 and is_equal_approx(wide / plain, 1.0 + wide_node.effect_value),
		"Wide Fall must widen the strike by %.2f: %.1f to %.1f" % [wide_node.effect_value, plain, wide])
	# Cinder Rain: a second stone.
	_learn("ember_fall_rite_cinder_rain")
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var places: Array = _falling()
	_check(places.size() == 2 and not (places[0]["at"] as Vector2).is_equal_approx(places[1]["at"]),
		"Cinder Rain must put a second stone in the air beside the first, put %d" % places.size())
	_caster.clear_cooldowns()
	# Thicker Volley: two more thorns.
	_fresh()
	_learn("thorn_volley_rite")
	var volley: SpellData = ContentDB.spells.get("thorn_volley")
	_equip(volley)
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var thorns: int = _falling().size()
	_learn("thorn_volley_rite_more")
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_check(_falling().size() == thorns + 2, "Thicker Volley must throw two more thorns: %d to %d"
		% [thorns, _falling().size()])
	_caster.clear_cooldowns()
	# Deep Marrow: the cooldown laid down.
	_fresh()
	_learn("marrow_drain")
	var drain: SpellData = ContentDB.spells.get("marrow_drain")
	var cool_plain: float = float(_caster.call("_effective_cooldown", drain))
	_learn("marrow_drain_wide")
	_learn("marrow_drain_deep")
	var cool_deep: float = float(_caster.call("_effective_cooldown", drain))
	var deep_node: DisciplineNodeData = ContentDB.discipline_node("marrow_drain_deep")
	_check(is_equal_approx(cool_deep / cool_plain, 1.0 - deep_node.effect_value),
		"Deep Marrow must cool %.0f%% faster: %.2fs to %.2fs" % [deep_node.effect_value * 100.0, cool_plain, cool_deep])
	# Hollowing: a share of what it takes heals - **on top of** the drain's own
	# draught, which `SpellData.lifesteal` has paid since the spell was written.
	# The first cut asked for the fork's share alone and read the whole heal
	# (50% and 20% together), so the plain cast is measured first and the fork
	# is held to what it adds.
	_fresh()
	_learn("marrow_drain")
	_learn("marrow_drain_wide")
	_equip(drain)
	var plain_body: Enemy = _dummy(Vector2.RIGHT * 60.0)
	var plain_before: float = plain_body.health.current_hp
	_healed = 0.0
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var plain_taken: float = plain_before - plain_body.health.current_hp
	var plain_share: float = _healed / maxf(plain_taken, 0.001)
	await _clear([plain_body])
	_learn("marrow_drain_hollowing")
	var body: Enemy = _dummy(Vector2.RIGHT * 60.0)
	var before: float = body.health.current_hp
	_healed = 0.0
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	var taken: float = before - body.health.current_hp
	var hollow: DisciplineNodeData = ContentDB.discipline_node("marrow_drain_hollowing")
	_check(plain_taken > 0.0 and taken > 0.0 and _healed > 0.0
			and absf(_healed - taken * (plain_share + hollow.effect_value)) < 0.5,
		"Hollowing must heal %.0f%% more of what it took than the drain alone (%.0f%%): took %.1f, healed %.1f"
			% [hollow.effect_value * 100.0, plain_share * 100.0, taken, _healed])
	await _clear([body])
	# Barbed Hook: what it pulls bleeds.
	_fresh()
	_learn("chain_hook")
	_learn("chain_hook_long")
	_learn("chain_hook_barbed")
	var hook: SpellData = ContentDB.spells.get("chain_hook")
	_equip(hook)
	body = _dummy(Vector2.RIGHT * 90.0)
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_check(body.is_burning(), "Barbed Hook must leave the body bleeding")
	await _clear([body])
	# Keen Lance: the beam's tick, read off a body with a pool it cannot empty.
	_fresh()
	_learn("frost_lance_rite")
	var lance: SpellData = ContentDB.spells.get("frost_lance")
	_equip(lance)
	body = _dummy(Vector2.RIGHT * 80.0)
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	_caster.cancel_channel()
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_caster.tick(0.05, Vector2.RIGHT, Vector2.ZERO)
	var plain_tick: float = 100000.0 - body.health.current_hp
	body.health.current_hp = 100000.0
	_caster.cancel_channel()
	_learn("frost_lance_rite_keen")
	_caster.clear_cooldowns()
	_caster.try_cast(0, Vector2.RIGHT, Vector2.ZERO)
	_caster.tick(0.05, Vector2.RIGHT, Vector2.ZERO)
	var keen_tick: float = 100000.0 - body.health.current_hp
	var keen: DisciplineNodeData = ContentDB.discipline_node("frost_lance_rite_keen")
	_check(plain_tick > 0.0 and absf(keen_tick / plain_tick - (1.0 + keen.effect_value)) < 0.03,
		"Keen Lance must strike %.0f%% harder: %.2f to %.2f a tick" % [keen.effect_value * 100.0, plain_tick, keen_tick])
	_caster.cancel_channel()
	await _clear([body])
	_fresh()
	_reached["spell_branches"] = true


# --- Form branches ------------------------------------------------------------------------

func _test_form_branches() -> void:
	_fresh()
	var owner := OwnerProbe.new()
	add_child(owner)
	var attack := HeroAttack.new()
	owner.add_child(attack)
	await get_tree().process_frame
	var origin: Vector2 = Vector2(3000.0, 3000.0)
	var aim: Vector2 = Vector2.RIGHT
	var reach: float = Balance.HERO_ATTACK_RANGE[Balance.HERO_CHAIN_LENGTH - 1] * attack.reach_scale()
	# Deeper Cut reaches every swing, through the hero's multiplier.
	var hero := (load(HERO_SCENE) as PackedScene).instantiate() as Hero
	_field.add_child(hero)
	await get_tree().process_frame
	MetaState.discipline_form = "hemorrhage_edge"
	var plain: float = hero.damage_multiplier()
	_learn("hemorrhage_edge_deeper")
	var deeper: float = hero.damage_multiplier()
	var edge: DisciplineNodeData = ContentDB.discipline_node("hemorrhage_edge")
	var cut: DisciplineNodeData = ContentDB.discipline_node("hemorrhage_edge_deeper")
	_check(is_equal_approx(deeper / plain, (1.0 + edge.form_damage + cut.effect_value) / (1.0 + edge.form_damage)),
		"Deeper Cut must add %.2f to every swing: %.3f to %.3f" % [cut.effect_value, plain, deeper])
	hero.queue_free()
	await get_tree().process_frame
	# Red Draught: the finisher heals a share of what it dealt.
	_learn("hemorrhage_edge_draught")
	var body: Enemy = _dummy(origin + aim * 50.0)
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	owner.healed = 0.0
	_finisher(attack, origin, aim)
	var dealt: float = 100000.0 - body.health.current_hp
	var draught: DisciplineNodeData = ContentDB.discipline_node("hemorrhage_edge_draught")
	_check(dealt > 0.0 and absf(owner.healed - dealt * draught.effect_value) < 0.5,
		"Red Draught must heal %.0f%% of the finisher: dealt %.1f, healed %.1f" % [draught.effect_value * 100.0, dealt, owner.healed])
	await _clear([body])
	# Wide Cleave: a body outside the finisher's arc and inside the widened one.
	_fresh()
	MetaState.discipline_form = "cleaving_road"
	_learn("cleaving_road")
	var half: float = deg_to_rad(Balance.HERO_ATTACK_ARC_DEGREES[Balance.HERO_CHAIN_LENGTH - 1] * 0.5)
	var wide_node: DisciplineNodeData = ContentDB.discipline_node("cleaving_road_wide")
	var angle: float = half * (1.0 + wide_node.effect_value * 0.5)
	body = _dummy(origin + aim.rotated(angle) * 60.0)
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	_finisher(attack, origin, aim)
	var narrow_hit: bool = body.health.current_hp < 100000.0
	_learn("cleaving_road_heavier")
	_learn("cleaving_road_wide")
	body.health.current_hp = 100000.0
	_finisher(attack, origin, aim)
	var wide_hit: bool = body.health.current_hp < 100000.0
	_check(not narrow_hit and wide_hit, "Wide Cleave must reach a body the plain finisher misses (plain %s, wide %s)"
		% [narrow_hit, wide_hit])
	await _clear([body])
	# Spellblade: the finisher refunds, and Arc Bolt reaches a body beyond the swing.
	_fresh()
	_learn("spellblade")
	MetaState.discipline_form = "spellblade"
	body = _dummy(origin + aim * 50.0)
	var beyond: Enemy = _dummy(origin + aim * (reach * 1.6))
	beyond.health.max_hp = 100000.0
	beyond.health.current_hp = 100000.0
	owner.refunded = 0.0
	_finisher(attack, origin, aim)
	var blade: DisciplineNodeData = ContentDB.discipline_node("spellblade")
	_check(is_equal_approx(owner.refunded, blade.effect_value), "Spellblade's finisher must refund %.2f of the pool, refunded %.3f"
		% [blade.effect_value, owner.refunded])
	_check(beyond.health.current_hp == 100000.0, "without Arc Bolt a body beyond the swing is untouched")
	_learn("spellblade_keener")
	_learn("spellblade_arc_bolt")
	_finisher(attack, origin, aim)
	_check(beyond.health.current_hp < 100000.0, "Arc Bolt must strike the body beyond the swing")
	await _clear([body, beyond])
	# Brand of Ruin: the finisher on a branded body.
	_fresh()
	_learn("judgment_brand")
	_learn("judgment_brand_bright")
	_learn("judgment_brand_ruin")
	MetaState.discipline_form = "judgment_brand"
	body = _dummy(origin + aim * 50.0)
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	_finisher(attack, origin, aim)
	var unbranded: float = 100000.0 - body.health.current_hp
	body.health.current_hp = 100000.0
	body.brand(5.0, 0.1)
	_finisher(attack, origin, aim)
	var branded: float = 100000.0 - body.health.current_hp
	var ruin: DisciplineNodeData = ContentDB.discipline_node("judgment_brand_ruin")
	_check(unbranded > 0.0 and absf(branded / unbranded - (1.0 + ruin.effect_value)) < 0.03,
		"Brand of Ruin must strike a branded body %.0f%% harder: %.1f to %.1f" % [ruin.effect_value * 100.0, unbranded, branded])
	await _clear([body])
	attack.queue_free()
	owner.queue_free()
	await get_tree().process_frame
	_fresh()
	_reached["form_branches"] = true


# --- The Oaths on a real hero ----------------------------------------------------------------

func _test_oaths_on_the_hero() -> void:
	_fresh()
	var hero := (load(HERO_SCENE) as PackedScene).instantiate() as Hero
	_field.add_child(hero)
	hero.field = _field
	hero.global_position = Vector2(5000.0, 5000.0)
	await get_tree().process_frame
	# The Deep Well: a deeper pool that does not refill.
	var pool: float = hero.mana_max()
	var regen: float = hero.mana_regen()
	_learn("oath_deep_well")
	var well: DisciplineNodeData = ContentDB.discipline_node("oath_deep_well")
	_check(is_equal_approx(hero.mana_max() / pool, 1.0 + well.effect_value),
		"The Deep Well must deepen the pool by %.0f%%: %.0f to %.0f" % [well.effect_value * 100.0, pool, hero.mana_max()])
	_check(regen > 0.0 and is_zero_approx(hero.mana_regen()), "and stop it refilling: %.2f a second" % hero.mana_regen())
	MetaState.discipline_tree.erase("oath_deep_well")
	# The Red Road: draughts heal half, its own lifesteal does not.
	_learn("oath_red_road")
	hero.call("_apply_permanent_bonuses")
	_check(is_equal_approx(hero.health.heal_scale, 0.5 * Balance.HERO_HEAL_SCALE), "The Red Road must halve heals: scale %.2f" % hero.health.heal_scale)
	hero.health.current_hp = hero.health.max_hp * 0.2
	var low: float = hero.health.current_hp
	hero.health.heal(20.0)
	_check(is_equal_approx(hero.health.current_hp - low, 10.0), "a draught of 20 heals 10 under the Red Road")
	low = hero.health.current_hp
	hero.heal_unscaled(20.0)
	_check(is_equal_approx(hero.health.current_hp - low, 20.0), "and the Road's own lifesteal heals whole")
	MetaState.discipline_tree.erase("oath_red_road")
	hero.call("_apply_permanent_bonuses")
	_check(is_equal_approx(hero.health.heal_scale, Balance.HERO_HEAL_SCALE), "let go, heals are whole again")
	# No Retreat: no perfect evade; the dash strikes what it crosses.
	var evades: Array[int] = [0]
	var counter: Callable = func(_at: Vector2) -> void: evades[0] += 1
	EventBus.hero_perfect_evade.connect(counter)
	var taught: int = MetaState.perfect_evades
	hero.call("_on_evaded", 0.01, Vector2.ZERO)
	_check(evades[0] == 1, "without the Oath a perfect evade is announced")
	_check(MetaState.perfect_evades == taught + 1, "the account's teaching statistic missed a perfect evade")
	_learn("oath_no_retreat")
	hero.call("_on_evaded", 0.01, Vector2.ZERO)
	_check(evades[0] == 1, "under No Retreat there is no perfect evade")
	EventBus.hero_perfect_evade.disconnect(counter)
	var body: Enemy = _dummy(hero.global_position + Vector2.RIGHT * 100.0)
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	hero.set("_aim", Vector2.RIGHT)
	hero.set("_dash_cooldown_left", 0.0)
	hero.set("_dash_left", 0.0)
	hero.call("_try_dash")
	_check(body.health.current_hp < 100000.0, "No Retreat's dash must strike the body it crosses")
	await _clear([body])
	MetaState.discipline_tree.erase("oath_no_retreat")
	# The Kept Gate: a ward reaches the nearest tower; no tower in reach, softer.
	_learn("oath_kept_gate")
	var tower := TowerProbe.new()
	tower.add_to_group(Tower.GROUP)
	_field.add_child(tower)
	tower.global_position = hero.global_position + Vector2(120.0, 0.0)
	hero.health.current_hp = hero.health.max_hp
	hero.grant_ward(0.1)
	var gate: DisciplineNodeData = ContentDB.discipline_node("oath_kept_gate")
	_check(hero.health.shield() > 0.0, "a ward must ward the Warden")
	_check(is_equal_approx(tower.warded, 0.1 * gate.effect_value),
		"The Kept Gate must ward the nearest tower for %.0f%% of it: warded %.3f" % [gate.effect_value * 100.0, tower.warded])
	await get_tree().create_timer(0.25).timeout
	var near: float = hero.damage_multiplier()
	tower.global_position = hero.global_position + Vector2(Balance.DISCIPLINE_RADIANT_TOWER_REACH * 3.0, 0.0)
	await get_tree().create_timer(0.25).timeout
	var far: float = hero.damage_multiplier()
	_check(is_equal_approx(far / near, 1.0 - gate.bane_value),
		"with no tower in reach the Warden must hit %.0f%% softer: %.3f to %.3f" % [gate.bane_value * 100.0, near, far])
	tower.queue_free()
	hero.queue_free()
	await get_tree().process_frame
	_fresh()
	_reached["oaths_on_the_hero"] = true


# --- The ceiling ----------------------------------------------------------------------------

## No share a branch authors is past the ceiling, and the reader bounds one
## that would be.
func _test_the_ceiling() -> void:
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.kind != DisciplineNodeData.Kind.UPGRADE or DisciplineUpgrades.COUNTED.has(node.effect_id):
			continue
		_check(node.effect_value > 0.0 and node.effect_value <= Balance.DISCIPLINE_UPGRADE_CEILING,
			"%s moves %s by %.2f, past the ceiling of %.2f" % [node.id, node.effect_id, node.effect_value,
				Balance.DISCIPLINE_UPGRADE_CEILING])
	var learned: Dictionary = {"marrow_drain": 1, "marrow_drain_wide": 1, "marrow_drain_deep": 3}
	_check(DisciplineUpgrades.value(learned, "marrow_drain", "up_cooldown") <= Balance.DISCIPLINE_UPGRADE_CEILING,
		"the reader must bound a share to the ceiling whatever the ranks claim")
	_reached["ceiling"] = true


# --- Helpers ------------------------------------------------------------------------------------

func _fresh() -> void:
	MetaState.call("_read_disciplines", {})
	MetaState.hero_level = Balance.HERO_MAX_LEVEL
	MetaState.first_clears = {}
	for tier: CampaignTierData in ContentDB.tiers_sorted():
		MetaState.first_clears[tier.id] = (1 << (Balance.ACT_COUNT + 1)) - 1
	MetaState.discipline_form = Balance.DISCIPLINE_STARTING_FORM
	MetaState.gatekeeper = {}
	_healed = 0.0


## A node learned past every rule: the harness setting a state up.
func _learn(id: String) -> void:
	MetaState.discipline_tree[id] = 1


## Every node of an arm up to a ring, past every rule but the forks: the twin
## of each pair is left out, so what is set up is a tree a player could hold.
func _fill_arm(arm: int, up_to_ring: int = 4) -> void:
	var taken: Dictionary = {}
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if node.discipline != arm or node.ring > up_to_ring or node.is_oath():
			continue
		if not node.exclusive.is_empty():
			if taken.has(node.exclusive):
				continue
			taken[node.exclusive] = true
		MetaState.discipline_tree[node.id] = maxi(node.ranks, 1)


func _equip(spell: SpellData) -> void:
	if RunState.equipped_spells.is_empty():
		RunState.equipped_spells.append(spell.id)
	else:
		RunState.equipped_spells[0] = spell.id


func _falling() -> Array:
	return _caster.get("_falling") as Array


func _strike_radius() -> float:
	var strikes: Array = _falling()
	var radius: float = float(strikes[0]["radius"]) if not strikes.is_empty() else 0.0
	_caster.clear_cooldowns()
	return radius


func _dummy(at: Vector2) -> Enemy:
	var ids: Array[String] = []
	for id: Variant in ContentDB.enemies:
		var data: EnemyData = ContentDB.enemies[id] as EnemyData
		if data != null and data.category == EnemyData.Category.BREED:
			ids.append(data.id)
	ids.sort()
	var breed: EnemyData = ContentDB.enemies[ids[0]] as EnemyData
	var foe := (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	foe.setup(breed, 0, _field, 40.0)
	_field.add_child(foe)
	var lift: Vector2 = foe.combat_origin() - foe.global_position
	foe.global_position = at - lift
	return foe


func _clear(bodies: Array) -> void:
	for body: Variant in bodies:
		var node := body as Node
		if node == null or not is_instance_valid(node):
			continue
		var parent: Node = node.get_parent()
		if parent != null:
			parent.remove_child(node)
		node.free()
	await get_tree().process_frame


## One finisher's strike, set up as `_begin_swing` would leave it.
func _finisher(attack: HeroAttack, origin: Vector2, aim: Vector2) -> void:
	attack.set("_step", Balance.HERO_CHAIN_LENGTH - 1)
	attack.set("_swing_origin", origin)
	attack.set("_swing_aim", aim)
	(attack.get("_hit_ids") as Dictionary).clear()
	attack.set("_announced", false)
	attack.set("_radiant_done", false)
	attack.call("_strike")


func _checked(condition: bool, failure: String) -> bool:
	_check(condition, failure)
	return condition


func _check(condition: bool, failure: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(failure)
