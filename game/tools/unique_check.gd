extends Node

## **The uniques** (docs/UNIQUES_DESIGN_2026-10-07.md).
##
##   godot --headless --path game res://tools/unique_check.tscn
##
## Holds that every act boss pays a unique of its own, each a trophy trinket
## carrying a rule the table resolves and its own words; that a unique is never
## rolled; that worn it puts its flag in the table and broken it does not, and a
## partner's worn kinds carry it; that a boss's first fall on a road lays it at
## the Warden's feet for this account and a second first fall does not; and that
## each of the eleven rules happens through its real door when worn and does
## not when it is not.

const TAG: String = "[unique]"
const TRINKETS: Array[int] = [GearData.Slot.CHARM, GearData.Slot.GLOVES, GearData.Slot.BOOTS,
	GearData.Slot.RING, GearData.Slot.AMULET]

var _run: Run = null
var _field: Battlefield = null
var _hero: Hero = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	var held_stash: Array = MetaState.stash.duplicate(true)
	var held_equipped: Dictionary = MetaState.equipped.duplicate(true)
	var held_clears: Dictionary = MetaState.first_clears.duplicate(true)
	RunState.reset(false, 20261011)
	GameDirector.run_active = true
	_test_the_eleven()
	_test_never_rolled()
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 20:
		await get_tree().process_frame
	_field = _run.battlefield
	_hero = _field.hero
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	_field.town.health.floor_hp = _field.town.health.max_hp * 0.5
	_hero.global_position = _field.town_position() + Vector2(0.0, 900.0)
	_hero.health.floor_hp = _hero.health.max_hp * 0.5
	_test_the_table()
	await _test_the_drop()
	await _test_the_rules()
	for stage: String in ["eleven", "rolled", "table", "drop", "rules"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	MetaState.stash = held_stash
	MetaState.equipped = held_equipped
	MetaState.first_clears = held_clears
	Modifiers.rebuild()
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: eleven trophies, never rolled, a flag worn and none broken, paid once a road at the Warden's feet, and every rule through its own door" % [TAG, _checks])
	else:
		push_error("%s FAIL - %d of %d" % [TAG, _failures, _checks])
	get_tree().quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("%s %s" % [TAG, message])
	return ok


func _test_the_eleven() -> void:
	var acts: Dictionary = {}
	var rules: Dictionary = {}
	for kind: GearData in Uniques.all():
		_check(kind.trophy, "%s is a unique and not a trophy" % kind.id)
		_check(Modifiers.UNIQUE_KEYS.has(kind.unique_rule), "%s's rule %s is not a key the table resolves" % [kind.id, kind.unique_rule])
		_check(Modifiers.WARDEN_KEYS.has(kind.unique_rule), "%s's rule is not a Warden key, so a partner cannot carry it" % kind.id)
		_check(not kind.unique_text.is_empty(), "%s does not say its rule" % kind.id)
		_check(TRINKETS.has(kind.slot), "%s is not a trinket, so it would need drawn art on the body" % kind.id)
		_check(ResourceLoader.exists(kind.get_sprite_path()), "%s has no icon" % kind.id)
		_check(not acts.has(kind.unique_act), "two uniques for act %d" % kind.unique_act)
		_check(not rules.has(kind.unique_rule), "two uniques carry %s" % kind.unique_rule)
		acts[kind.unique_act] = kind.id
		rules[kind.unique_rule] = kind.id
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		_check(Uniques.kind_for_act(act) != null, "act %d's boss pays no unique" % act)
	_check(rules.size() == Modifiers.UNIQUE_KEYS.size(), "%d rules worn by %d keys" % [rules.size(), Modifiers.UNIQUE_KEYS.size()])
	_reached.append("eleven")


func _test_never_rolled() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 20261011
	var rolled: int = 0
	for _index: int in 3000:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), 2, dice)
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind != null and kind.is_unique():
			rolled += 1
	_check(rolled == 0, "%d uniques rolled in three thousand drops" % rolled)
	_reached.append("rolled")


func _wear(id: String, on: bool) -> void:
	var kind: GearData = ContentDB.gear(id)
	if kind == null:
		return
	if not on:
		MetaState.equipped.erase(kind.slot)
		Modifiers.rebuild()
		return
	var piece: Dictionary = Stash.make(id, 4)
	MetaState.stash.append(piece)
	MetaState.equipped[kind.slot] = Stash.uid(piece)
	Modifiers.rebuild()


func _test_the_table() -> void:
	MetaState.stash.clear()
	MetaState.equipped.clear()
	_wear("hoarfrost_signet", true)
	_check(Modifiers.value(Modifiers.UNIQUE_HOARFROST) > 0.0, "a worn unique puts no flag in the table")
	var worn: Dictionary = MetaState.stash[MetaState.stash.size() - 1]
	worn["dur"] = 0
	Modifiers.rebuild()
	_check(Modifiers.value(Modifiers.UNIQUE_HOARFROST) <= 0.0, "a broken unique still keeps its rule")
	_wear("hoarfrost_signet", false)
	_check(Modifiers.value(Modifiers.UNIQUE_HOARFROST) <= 0.0, "an unworn unique keeps its rule")
	var partner: Dictionary = Modifiers.gear_totals([Stash.make("prismheart", 4)] as Array[Dictionary])
	_check(float(partner.get(Modifiers.UNIQUE_PRISMHEART, 0.0)) > 0.0, "a partner's worn unique carries no rule")
	_reached.append("table")


func _test_the_drop() -> void:
	MetaState.first_clears = {}
	var before: int = _uniques_on_the_ground()
	MetaState.note_first_clear(RunState.tier_id, 2)
	await get_tree().process_frame
	_check(_uniques_on_the_ground() == before + 1, "a boss's first fall laid no unique")
	var drop: LootDrop = _last_unique_drop()
	if _check(drop != null, "the unique is not on the ground"):
		_check(String(drop.gear.get("kind", "")) == "sandglass_sabatons", "act II's boss paid %s" % String(drop.gear.get("kind", "")))
		_check(drop.net_id == 0, "a unique was laid as a shared drop")
		_check(drop.global_position.distance_to(_hero.global_position) < 200.0, "the unique was laid away from the Warden")
		_check(_run.get("_unique_paid_act") == 2, "the first fall's payment is not remembered against the repeat")
	MetaState.note_first_clear(RunState.tier_id, 2)
	await get_tree().process_frame
	_check(_uniques_on_the_ground() == before + 1, "a second first fall of the same boss paid again")
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var piece := node as LootDrop
		if piece != null and not piece.gear.is_empty():
			piece.queue_free()
	_reached.append("drop")


func _uniques_on_the_ground() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and not drop.gear.is_empty():
			var kind: GearData = ContentDB.gear(String(drop.gear.get("kind", "")))
			if kind != null and kind.is_unique() and not drop.is_queued_for_deletion():
				count += 1
	return count


func _last_unique_drop() -> LootDrop:
	var found: LootDrop = null
	for node: Node in get_tree().get_nodes_in_group(LootDrop.GROUP):
		var drop := node as LootDrop
		if drop != null and not drop.gear.is_empty():
			var kind: GearData = ContentDB.gear(String(drop.gear.get("kind", "")))
			if kind != null and kind.is_unique():
				found = drop
	return found


func _breed() -> EnemyData:
	for value: Variant in ContentDB.enemies.values():
		var breed := value as EnemyData
		if breed != null and breed.category == EnemyData.Category.BREED and not breed.targets_towers \
				and breed.knockback_resistance < 0.5:
			return breed
	return null


func _body(at: Vector2, pool: float = 60.0) -> Enemy:
	var body: Enemy = _field.spawn_enemy(_breed(), 0, pool, -1.0, 0.001)
	if body != null:
		body.global_position = at
	return body


func _chill(body: Enemy) -> float:
	return float(body.get("_chill")) if body != null and is_instance_valid(body) else 0.0


func _clear_bodies() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		node.queue_free()


## Every rule worn and not worn, through the door the game goes through.
func _test_the_rules() -> void:
	MetaState.stash.clear()
	MetaState.equipped.clear()
	Modifiers.rebuild()
	var here: Vector2 = _hero.global_position
	for worn: bool in [false, true]:
		var said: String = "worn" if worn else "not worn"
		# I - Rootbinder's Grip: a finisher kill roots the bodies round it.
		_wear("rootbinders_grip", worn)
		var victim: Enemy = _body(here + Vector2(60.0, 0.0), 0.01)
		var near: Enemy = _body(here + Vector2(120.0, 30.0))
		await get_tree().process_frame
		_hero.attack._land_on(victim, 99999.0, 100.0, true, null, here)
		_check((_chill(near) > 0.0) == worn, "Rootbinder %s: the body beside a finisher kill has %.2f chill" % [said, _chill(near)])
		_wear("rootbinders_grip", false)
		_clear_bodies()
		await get_tree().process_frame
		# X - Anchorchain Gauntlets: the finisher pulls rather than throws.
		_wear("anchorchain_gauntlets", worn)
		var struck: Enemy = _body(here + Vector2(80.0, 0.0), 500.0)
		await get_tree().process_frame
		_hero.attack.set("_hit_ids", {})
		_hero.attack._land_on(struck, 1.0, 300.0, true, null, here)
		var thrown: Vector2 = struck.get("_knockback") as Vector2
		_check((thrown.dot(here - struck.global_position) > 0.0) == worn,
			"Anchorchain %s: the finisher moved the body %s" % [said, str(thrown)])
		_wear("anchorchain_gauntlets", false)
		_clear_bodies()
		await get_tree().process_frame
		# II - Sandglass Sabatons: a dash slows what it crosses.
		_wear("sandglass_sabatons", worn)
		_hero.set("_dash_direction", Vector2.RIGHT)
		var crossed: Enemy = _body(here + Vector2(Balance.HERO_DASH_DISTANCE * 0.5, 0.0))
		var aside: Enemy = _body(here + Vector2(Balance.HERO_DASH_DISTANCE * 0.5, 400.0))
		await get_tree().process_frame
		_hero._sand_trail()
		_check((_chill(crossed) > 0.0) == worn, "Sandglass %s: a body on the dash's line has %.2f chill" % [said, _chill(crossed)])
		_check(_chill(aside) <= 0.0, "Sandglass slowed a body off the dash's line")
		_wear("sandglass_sabatons", false)
		_clear_bodies()
		await get_tree().process_frame
		# III - Hoarfrost Signet: a chilled body the Warden kills passes it on.
		_wear("hoarfrost_signet", worn)
		var cold: Enemy = _body(here + Vector2(0.0, 200.0), 0.01)
		var beside: Enemy = _body(here + Vector2(60.0, 220.0))
		await get_tree().process_frame
		cold._add_chill(0.6)
		DamageLedger.credit_as(DamageLedger.WARDEN)
		cold.take_damage(99999.0, here, 0.0, true, null)
		_check((_chill(beside) > 0.0) == worn, "Hoarfrost %s: the body beside a chilled kill has %.2f chill" % [said, _chill(beside)])
		_wear("hoarfrost_signet", false)
		_clear_bodies()
		await get_tree().process_frame
		# IV - Bogwater Amulet, VIII - Prismheart: a spell's landing.
		_wear("bogwater_amulet", worn)
		var soaked: Enemy = _body(here + Vector2(-200.0, 0.0), 500.0)
		await get_tree().process_frame
		_hero.spells._land(soaked, 1.0, here, 0.0, TowerData.Element.WATER, null, true)
		_check((_chill(soaked) > 0.0) == worn, "Bogwater %s: a body a water spell soaked has %.2f chill" % [said, _chill(soaked)])
		_wear("bogwater_amulet", false)
		_wear("prismheart", worn)
		var lit: Enemy = _body(here + Vector2(-260.0, 60.0), 500.0)
		await get_tree().process_frame
		_hero.spells._land(lit, 1.0, here, 0.0, -1, null, true)
		_check((lit.brand_multiplier() > 1.0) == worn, "Prismheart %s: a body a spell struck is branded %.2f" % [said, lit.brand_multiplier()])
		_wear("prismheart", false)
		_clear_bodies()
		await get_tree().process_frame
		# V - Gearwright's Charm: a tower falling near empowers the next finisher.
		_wear("gearwrights_charm", worn)
		_hero.spend_guard()
		EventBus.tower_destroyed.emit(Vector2i(0, 0), here + Vector2(200.0, 0.0))
		_check((float(_hero.get("_guard_left")) > 0.0) == worn, "Gearwright %s: a tower falling near left the guard at %.2f" % [said, float(_hero.get("_guard_left"))])
		_hero.spend_guard()
		EventBus.tower_destroyed.emit(Vector2i(0, 0), here + Vector2(Balance.UNIQUE_GEAR_REACH + 300.0, 0.0))
		_check(float(_hero.get("_guard_left")) <= 0.0, "Gearwright answered a tower falling across the field")
		_wear("gearwrights_charm", false)
		_hero.spend_guard()
		# VI - Saltbound Band, XI - Kharok's Sigil: a blow on the ward.
		_wear("kharoks_sigil", worn)
		var striker: Enemy = _body(here + Vector2(0.0, -120.0))
		await get_tree().process_frame
		_hero.health.add_shield(400.0)
		_hero.health.take_damage(10.0, striker.global_position)
		_check(striker.is_hunted() == worn, "Kharok's Sigil %s: the striker of a warded blow is hunted %s" % [said, str(striker.is_hunted())])
		_wear("kharoks_sigil", false)
		_wear("saltbound_band", worn)
		var breaker: Enemy = _body(here + Vector2(30.0, -140.0))
		await get_tree().process_frame
		_hero.health.add_shield(5.0)
		_hero.health.take_damage(200.0, breaker.global_position)
		_check((_chill(breaker) > 0.0) == worn, "Saltbound %s: what broke the ward has %.2f chill" % [said, _chill(breaker)])
		_wear("saltbound_band", false)
		_hero.health.current_hp = _hero.health.max_hp
		_clear_bodies()
		await get_tree().process_frame
		# VII - Horselord's Treads: sprinting through a body shoves it.
		_wear("horselords_treads", worn)
		var trodden: Enemy = _body(here + Vector2(20.0, 0.0), 500.0)
		await get_tree().process_frame
		_hero.set("_trodden", {})
		_hero._horselord(0.016)
		var shoved: Vector2 = trodden.get("_knockback") as Vector2
		_check((shoved.length() > 1.0) == worn, "Horselord %s: a body sprinted through moved %s" % [said, str(shoved)])
		_wear("horselords_treads", false)
		_clear_bodies()
		await get_tree().process_frame
		# IX - Emberwreath: a burning body the Warden kills lights the brush.
		_wear("emberwreath", worn)
		var plants: Array[Dictionary] = _field.foliage_node().plants_near(here, 3000.0) \
			if _field.foliage_node() != null else []
		var fire: Wildfire = _field.wildfire()
		_check(not plants.is_empty() and fire != null, "no brush stands for Emberwreath to light - the test would hold nothing")
		if not plants.is_empty() and fire != null:
			var burning: Enemy = _body(plants[0]["at"] as Vector2, 0.01)
			await get_tree().process_frame
			burning.apply_burn(5.0, 4.0)
			var lit_before: int = fire.fire_count()
			DamageLedger.credit_as(DamageLedger.WARDEN)
			burning.take_damage(99999.0, here, 0.0, true, null)
			_check((fire.fire_count() > lit_before) == worn,
				"Emberwreath %s: a burning kill lit %d fires" % [said, fire.fire_count() - lit_before])
		_wear("emberwreath", false)
		_clear_bodies()
		await get_tree().process_frame
	_reached.append("rules")
