extends Node

## **The Arcane's form throws the chain** (owner, 2026-10-06: "Players still
## cannot equip and set and use the arcane primary skill to magic projectile
## basic attack enemies at range for MP").
##
##   godot --headless --path game res://tools/chain_bolt_check.tscn
##
## A form authored `form_thrown` looses the chain's own blow as a bolt along
## the aim for `CHAIN_BOLT_MANA_COST` of the pool, and swings steel when the
## pool cannot pay. What this holds, driven through the press a player makes:
##
## - the Arcane's form can be taken up on an account that has reached Act II,
##   through the door the Primary picker uses;
## - a press with the form throws: a body well beyond the arm's reach takes
##   exactly the chain's first blow, the pool pays the bolt, the breath pays
##   nothing;
## - with the pool short, the same press is steel - nothing at range, a body
##   at the arm struck, the breath paid;
## - a melee form throws nothing and spends no mana;
## - the finisher's bolt passes through more than one body;
## - a partner body throws by its own sheet and never by this machine's form.

const SEED: int = 20261006
const FAR: float = 300.0
const NEAR: float = 60.0

class Aimed extends HeroInput:
	var press: int = 0
	var hold: int = 0
	var toward: Vector2 = Vector2.RIGHT

	func _read_press(button: int) -> bool:
		return press & button != 0

	func _read_hold(mask: int) -> bool:
		return hold & mask != 0

	func aim(_previous: Vector2) -> Vector2:
		return toward

	func is_local() -> bool:
		return true

var _failures: int = 0
var _checks: int = 0
var _finished: int = 0
var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null
var _hands: Aimed = null
var _landed: Array[int] = []


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, SEED)
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
	RunState.gain_every_currency(99999)
	# The road is an act in, so the Arcane is open; a fight, so the swing is.
	RunState.act = 2
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_hero = _field.hero
	_hands = Aimed.new(_hero)
	_hero.input = _hands
	_hero.attack.landed.connect(func(step: int, _targets: int, _at: Vector2) -> void:
		_landed.append(step))
	# Away from the town's sanctuary, on open ground.
	_hero.global_position = Vector2(2000.0, 1700.0)
	await _frames(3)

	_test_the_form_can_be_taken_up()
	await _test_a_bolt_at_range()
	await _test_steel_when_the_pool_is_short()
	await _test_a_melee_form_throws_nothing()
	await _test_the_finisher_pierces()
	await _test_a_partner_throws_by_its_sheet()

	_check(_finished == 6, "%d of 6 tests reached their end" % _finished)
	MetaState.discipline_form = "hemorrhage_edge"
	_run.queue_free()
	for _f: int in 6:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures == 0:
		print(("[chain-bolt] PASS - %d checks: the Arcane's form throws the chain"
			+ " for mana, swings steel without it, and a partner throws by its sheet") % _checks)
	else:
		push_error("[chain-bolt] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("[chain-bolt] FAIL: " + what)


func _frames(count: int) -> void:
	for _f: int in count:
		await get_tree().process_frame


func _seconds(span: float) -> void:
	await get_tree().create_timer(span).timeout


## A body stood at `offset` from the hero, immortal and still, so a blow is
## measured on a standing target and never on a corpse (`stagger_check`'s lesson).
func _stand(offset: Vector2) -> Enemy:
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var candidate := value as EnemyData
		if candidate != null and candidate.category == EnemyData.Category.BREED \
				and candidate.role == EnemyData.Role.MARCHER:
			breed = candidate
			break
	var body: Enemy = _field.spawn_enemy(breed, 0, 60.0, -1.0, 0.001)
	if body == null:
		return null
	await get_tree().process_frame
	body.global_position = _hero.global_position + offset
	body.health.max_hp = 100000.0
	body.health.current_hp = 100000.0
	body.set_process(false)
	body.set_physics_process(false)
	await get_tree().process_frame
	return body


func _clear(bodies: Array) -> void:
	for body: Variant in bodies:
		if body != null and is_instance_valid(body):
			(body as Node).queue_free()
	await _frames(2)


## **Held until the swing begins**, never one frame: the hero reads its input
## on the physics tick, and a headless process frame routinely falls between
## two of them - a press on one frame is dropped as often as not (the mount
## gate's lesson, 2026-09-22). Released the frame the swing is under way.
func _press() -> void:
	_hands.press = HeroInput.BUTTON_ATTACK
	for _f: int in 90:
		await get_tree().process_frame
		if _hero.attack.is_swinging():
			break
	_hands.press = 0
	await get_tree().process_frame


## Waits for the swing under way to end, so the next press chains onto it.
func _swing_done() -> void:
	for _f: int in 240:
		await get_tree().process_frame
		if not _hero.attack.is_swinging():
			return


func _arm(form: String) -> void:
	MetaState.discipline_form = form
	_hero.sheet = null
	_hero.attack.sheet = null
	_hero.refill_mana()
	_hero.stamina = _hero.max_stamina()
	_hero.attack.cancel()
	_landed.clear()
	await _frames(2)


func _test_the_form_can_be_taken_up() -> void:
	var forms: Array[DisciplineNodeData] = MetaState.chain_forms()
	var listed: bool = false
	for form: DisciplineNodeData in forms:
		if form.id == "spellblade":
			listed = true
	_check(listed, "the Primary picker lists the Arcane's form")
	_check(MetaState.form_problem("spellblade", 2).is_empty(),
		"the Arcane's form is open an act in: '%s'" % MetaState.form_problem("spellblade", 2))
	_check(MetaState.set_discipline_form("spellblade", 2).is_empty()
		and MetaState.discipline_form == "spellblade",
		"and can be taken up through the picker's own door")
	var node: DisciplineNodeData = ContentDB.discipline_node("spellblade")
	_check(node != null and node.form_thrown, "the Arcane's form is authored thrown")
	_check(Balance.CHAIN_BOLT_TRAVEL > Balance.HERO_ATTACK_RANGE[2] * 2.0,
		"a bolt reaches well past the arm")
	_finished += 1


func _test_a_bolt_at_range() -> void:
	await _arm("spellblade")
	var far: Enemy = await _stand(Vector2(FAR, 0.0))
	_check(far != null, "the harness needs a body")
	var mana_before: float = _hero.mana
	var breath_before: float = _hero.stamina
	var hp_before: float = far.health.current_hp
	await _press()
	# The pool refills while the bolt flies, so what it paid is its low point.
	var lowest: float = await _lowest_mana(0.9)
	var took: float = hp_before - far.health.current_hp
	var blow: float = Balance.HERO_ATTACK_DAMAGE[0] * _hero.damage_multiplier()
	_check(took > 0.0, "a press with the Arcane's form hurts a body %d units off (took %.1f)" % [int(FAR), took])
	_check(absf(took - blow) < blow * 0.25 + 0.5,
		"and the bolt is the chain's own first blow (%.1f against %.1f)" % [took, blow])
	_check(absf((mana_before - lowest) - Balance.CHAIN_BOLT_MANA_COST) < 0.6,
		"the pool paid the bolt (%.1f -> %.1f at its lowest)" % [mana_before, lowest])
	_check(_hero.stamina >= breath_before - 0.6, "and the breath paid nothing (%.1f -> %.1f)" % [breath_before, _hero.stamina])
	_check(_landed.size() == 1 and _landed[0] == 0, "the blow is announced as the chain's first (%s)" % str(_landed))
	await _clear([far])
	_finished += 1


func _test_steel_when_the_pool_is_short() -> void:
	await _arm("spellblade")
	var far: Enemy = await _stand(Vector2(FAR, 0.0))
	# Inside the arm and the arc, and off the bolt's own line - a body on the
	# line would stop a bolt and read as steel.
	#
	# **Amended 2026-10-07**, a harness change: the swing steps the Warden
	# forward before it lands, and at (50, -60) that step put the body's
	# middle 80 degrees off the aim. It passed only because the old stroke's
	# nearest point was level with the Warden's chest; the arc judges the
	# body's middle as well now (`HeroAttack.in_arc`), so the body stands
	# where the arc is after the step.
	var near: Enemy = await _stand(Vector2(70.0, -20.0))
	var far_before: float = far.health.current_hp
	var near_before: float = near.health.current_hp
	var breath_before: float = _hero.stamina
	# Emptied on the frame of the press: the pool refills at a few points a
	# second and a bolt costs four.
	_hero.burn_mana(_hero.mana)
	await _press()
	var lowest_breath: float = await _lowest_breath(0.9)
	_check(is_equal_approx(far.health.current_hp, far_before),
		"with the pool empty nothing flies: the far body is untouched")
	_check(near.health.current_hp < near_before,
		"and the chain is steel: the body at the arm is struck")
	_check(lowest_breath < breath_before - 0.5,
		"the breath paid the steel swing (%.1f -> %.1f at its lowest)" % [breath_before, lowest_breath])
	_check(_hero.mana < Balance.CHAIN_BOLT_MANA_COST,
		"and the pool, refilling, never paid a bolt (%.1f)" % _hero.mana)
	await _clear([far, near])
	_finished += 1


## The lowest the breath reads over the next `span` seconds; it refills too.
func _lowest_breath(span: float) -> float:
	var lowest: float = _hero.stamina
	var deadline: float = Time.get_ticks_msec() / 1000.0 + span
	while Time.get_ticks_msec() / 1000.0 < deadline:
		await get_tree().process_frame
		lowest = minf(lowest, _hero.stamina)
	return lowest


## The lowest the pool reads over the next `span` seconds.
func _lowest_mana(span: float) -> float:
	var lowest: float = _hero.mana
	var deadline: float = Time.get_ticks_msec() / 1000.0 + span
	while Time.get_ticks_msec() / 1000.0 < deadline:
		await get_tree().process_frame
		lowest = minf(lowest, _hero.mana)
	return lowest


func _test_a_melee_form_throws_nothing() -> void:
	await _arm("hemorrhage_edge")
	var far: Enemy = await _stand(Vector2(FAR, 0.0))
	var mana_before: float = _hero.mana
	var hp_before: float = far.health.current_hp
	await _press()
	await _seconds(0.9)
	_check(is_equal_approx(far.health.current_hp, hp_before),
		"a melee form reaches nothing %d units off" % int(FAR))
	_check(is_equal_approx(_hero.mana, mana_before), "and spends no mana")
	_check(not _hero.attack.thrown, "the attack is not thrown under a melee form")
	await _clear([far])
	_finished += 1


func _test_the_finisher_pierces() -> void:
	await _arm("spellblade")
	var first: Enemy = await _stand(Vector2(220.0, 0.0))
	var second: Enemy = await _stand(Vector2(330.0, 0.0))
	# Three presses inside the chain's window: the third is the finisher.
	for _blow: int in 3:
		await _press()
		await _swing_done()
	await _seconds(0.6)
	var finishers: int = 0
	for step: int in _landed:
		if step == Balance.HERO_CHAIN_LENGTH - 1:
			finishers += 1
	_check(_landed.has(Balance.HERO_CHAIN_LENGTH - 1), "the third press is the finisher (%s)" % str(_landed))
	_check(finishers >= 2, "and the finisher's bolt passes through both bodies (%d landed)" % finishers)
	_check(second.health.current_hp < 100000.0, "the far body behind the near one was struck")
	await _clear([first, second])
	_finished += 1


func _test_a_partner_throws_by_its_sheet() -> void:
	await _arm("hemorrhage_edge")
	var partner := WardenSheet.new()
	partner.form = "spellblade"
	partner.level = 5
	_hero.sheet = partner
	_hero.attack.sheet = partner
	await _seconds(0.15)
	_check(_hero.attack.thrown, "a body whose sheet carries the Arcane's form throws, whatever this account swings")
	partner.form = "hemorrhage_edge"
	await _seconds(0.15)
	_check(not _hero.attack.thrown, "and one whose sheet carries a melee form does not")
	_hero.sheet = null
	_hero.attack.sheet = null
	_finished += 1
