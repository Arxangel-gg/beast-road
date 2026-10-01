extends Node

## **Cooking** (2026-09-30, `RunState.cook`): a fish from the pantry and a crop
## pulled this run, eaten as one meal.
##
##   godot --headless --path game res://tools/cooking_check.tscn
##
## Driven on the real field, through the real doors:
##
## - **The basket**: a real harvest lays its crop in it as well as paying its
##   Food, up to `COOK_BASKET_CAP` of a kind, and a new run empties it.
## - **The dish**, on the real hero: the fish's own restores exactly as eating it
##   plain, plus what the crop lends - stamina, a ward, the buff's length - and
##   **not one point of health more**, whatever the crop.
## - **The cap**: a dish is one meal; the fourth is refused, and a refusal spends
##   neither the fish nor the crop. No crop, no fish, or between runs: refused.
## - **The ceiling**: a crop authored past `COOK_DISH_CEILING` lends the ceiling.
## - **No stat**: a crop carries no field that reads like health or an attribute.
## - **Banked**: the basket rides a front through `Expedition.compose` and
##   `apply`.
## - **The pantry**: with a crop in the basket the pot offers it, and choosing
##   it turns Eat into Cook, which cooks.

const TAG: String = "[cooking]"
const SEED: int = 20260914

var _run: Run = null
var _field: Battlefield = null
var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	RunState.terrain_id = "jungle"
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 16:
		await get_tree().process_frame
	_field = _run.battlefield
	_field.wave_director.stop()
	_field.sky().events_enabled = false
	_field.climate().reset()
	var animals: Node = _field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	_field.hero.global_position = _field.town_position()

	_test_the_crops()
	_test_the_basket()
	_test_the_dish()
	_test_the_cap()
	_test_the_ceiling()
	_test_banked()
	await _test_the_pantry()
	for stage: String in ["crops", "basket", "dish", "cap", "ceiling", "banked", "pantry"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	MetaState.fish.clear()
	_run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	GameDirector.run_active = false
	MetaState.resume_saves()
	if _failures == 0:
		print("%s PASS - %d checks: a harvest fills the basket, a dish is one meal that heals what its fish heals and lends what its crop lends, and the cap holds" % [TAG, _checks])
		get_tree().quit(0)
	else:
		print("%s FAIL - %d of %d checks" % [TAG, _failures, _checks])
		get_tree().quit(1)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("%s FAIL: %s" % [TAG, what])


## Every crop lends the pot something, and nothing a crop carries reads like
## health or a stat.
func _test_the_crops() -> void:
	var crops: Array = ContentDB.crops.values()
	_check(crops.size() >= 6, "the harness found %d crops" % crops.size())
	for value: Variant in crops:
		var crop := value as CropData
		if crop == null:
			continue
		_check(not crop.dish_text().is_empty(), "%s lends a dish nothing - a crop the pot cannot use" % crop.id)
		for field: String in ["dish_stamina", "dish_ward", "dish_mana", "dish_lingers"]:
			_check(float(crop.get(field)) <= Balance.COOK_DISH_CEILING,
				"%s authors %s %.2f past the ceiling %.2f" % [crop.id, field, float(crop.get(field)), Balance.COOK_DISH_CEILING])
		for property: Dictionary in crop.get_property_list():
			var name: String = String(property.get("name", ""))
			if not name.begins_with("dish_"):
				continue
			for forbidden: String in ["heal", "health", "hp", "might", "vigour", "swiftness", "focus",
					"resolve", "attribute", "damage", "armour", "armor"]:
				_check(not name.contains(forbidden),
					"CropData.%s reads like %s - a dish lends a share of what the Warden has, never health and never a stat" % [name, forbidden])
	_reached.append("crops")


## A real harvest lays its crop in the basket; the cap; a new run empties it.
func _test_the_basket() -> void:
	var farm: Farming = _field.farming()
	_check(farm != null, "the field has a farm")
	if farm == null:
		_reached.append("basket")
		return
	var bare: int = -1
	for index: int in farm.plot_count():
		var state: Dictionary = farm.plot_state(index)
		if not bool(state["wild"]) and String(state["crop_id"]).is_empty():
			bare = index
			break
	_check(bare >= 0, "the harness needs a bare plot")
	if bare < 0:
		_reached.append("basket")
		return
	RunState.basket.clear()
	RunState.seeds.clear()
	RunState.add_seeds("barley", 1)
	_check(farm.plant(bare), "barley is planted")
	farm.grow_by(Balance.ACT_DISTANCE * 2.0)
	var food_before: int = RunState.currency(RunState.FOOD)
	_check(farm.harvest(bare), "and harvested")
	_check(RunState.currency(RunState.FOOD) > food_before, "the harvest still pays its Food")
	_check(RunState.basket_count("barley") == 1, "and lays the barley in the basket (%d)" % RunState.basket_count("barley"))
	for _more: int in Balance.COOK_BASKET_CAP + 4:
		RunState.add_to_basket("barley")
	_check(RunState.basket_count("barley") == Balance.COOK_BASKET_CAP,
		"the basket holds %d barley against a cap of %d" % [RunState.basket_count("barley"), Balance.COOK_BASKET_CAP])
	RunState.add_to_basket("not_a_crop")
	_check(not RunState.basket.has("not_a_crop"), "a crop that does not exist is not laid in the basket")
	var kept: Dictionary = RunState.basket.duplicate()
	RunState.reset(false, SEED)
	_check(RunState.basket.is_empty(), "a new run empties the basket")
	RunState.basket = kept
	RunState.terrain_id = "jungle"
	_reached.append("basket")


func _hero() -> Hero:
	return _field.hero


## A meal's worth: health, ward, mana, stamina and the buff's seconds, measured
## from an emptied Warden.
func _empty_the_warden() -> void:
	var hero: Hero = _hero()
	hero.health.current_hp = hero.health.max_hp * 0.2
	hero.health._shield = 0.0
	hero.mana = 0.0
	hero.stamina = 0.0
	hero._meal_left = 0.0
	hero._meal_damage = 0.0
	hero._meal_speed = 0.0


func _measure() -> Dictionary:
	var hero: Hero = _hero()
	return {"hp": hero.health.current_hp, "ward": hero.health.shield(), "mana": hero.mana,
		"sp": hero.stamina, "buff": hero._meal_left}


## The dish carries the fish's restores exactly and what the crop lends, and
## never one point of health more than the fish.
func _test_the_dish() -> void:
	var hero: Hero = _hero()
	var fish: FishData = ContentDB.fish("deepwinter_pike")
	var crop: CropData = ContentDB.crop("stone_melon")
	_check(fish != null and crop != null, "the harness needs the pike and the melon")
	if fish == null or crop == null:
		_reached.append("dish")
		return
	MetaState.fish.clear()
	for _keep: int in 4:
		MetaState.take_fish(fish.id)
	RunState.meals_eaten = 0
	RunState.basket = {crop.id: 2}

	_empty_the_warden()
	_check(RunState.eat_fish(fish.id).is_empty(), "the plain pike is eaten")
	var plain: Dictionary = _measure()

	_empty_the_warden()
	var why: String = RunState.cook(fish.id, crop.id)
	_check(why.is_empty(), "the pike is cooked with the melon (%s)" % why)
	var dish: Dictionary = _measure()

	_check(is_equal_approx(float(dish["hp"]), float(plain["hp"])),
		"a dish healed %.1f where its fish alone heals %.1f - a crop never heals" % [float(dish["hp"]), float(plain["hp"])])
	var ward_want: float = hero.health.max_hp * (fish.shield_fraction + crop.dish_ward) * hero.health.shield_scale
	_check(absf(float(dish["ward"]) - ward_want) < 0.5,
		"the dish's ward is %.1f, wanting the pike's and the melon's %.1f" % [float(dish["ward"]), ward_want])
	_check(float(dish["ward"]) > float(plain["ward"]), "and more than the pike alone (%.1f)" % float(plain["ward"]))
	_check(is_equal_approx(float(dish["mana"]), float(plain["mana"])),
		"the melon lends no mana and the dish's mana moved (%.1f against %.1f)" % [float(dish["mana"]), float(plain["mana"])])
	var sp_want: float = hero.max_stamina() * crop.dish_stamina
	_check(absf(float(dish["sp"]) - sp_want) < 0.5,
		"the dish restored %.1f stamina, wanting %.1f" % [float(dish["sp"]), sp_want])
	_check(is_zero_approx(float(plain["sp"])), "and the pike alone restores none (%.1f)" % float(plain["sp"]))
	var buff_want: float = float(plain["buff"]) * (1.0 + crop.dish_lingers)
	_check(absf(float(dish["buff"]) - buff_want) < 0.01,
		"the dish's meal lasts %.1fs, wanting %.1fs" % [float(dish["buff"]), buff_want])
	_check(RunState.basket_count(crop.id) == 1, "the dish took one melon from the basket (%d left)" % RunState.basket_count(crop.id))
	_check(MetaState.fish_count(fish.id) == 2, "and one pike each meal (%d left)" % MetaState.fish_count(fish.id))
	_check(RunState.meals_eaten == 2, "a dish is one meal (%d eaten)" % RunState.meals_eaten)
	_reached.append("dish")


## The cap counts a dish; a refusal spends nothing.
func _test_the_cap() -> void:
	var fish: FishData = ContentDB.fish("silt_minnow")
	MetaState.fish.clear()
	for _keep: int in 6:
		MetaState.take_fish(fish.id)
	RunState.meals_eaten = 0
	RunState.basket = {"barley": 3}
	GameDirector.run_active = true

	_check(not RunState.cook(fish.id, "glowcap").is_empty(), "a crop not in the basket is refused")
	_check(MetaState.fish_count(fish.id) == 6 and RunState.meals_eaten == 0,
		"and the refusal spent nothing (%d fish, %d meals)" % [MetaState.fish_count(fish.id), RunState.meals_eaten])
	_check(not RunState.cook("greenback_perch", "barley").is_empty(), "a fish not in the pantry is refused")
	_check(RunState.basket_count("barley") == 3, "and the refusal kept the barley (%d)" % RunState.basket_count("barley"))

	_check(RunState.eat_fish(fish.id).is_empty(), "a plain meal")
	_check(RunState.cook(fish.id, "barley").is_empty(), "a dish")
	_check(RunState.cook(fish.id, "barley").is_empty(), "another dish")
	_check(not RunState.cook(fish.id, "barley").is_empty(),
		"a fourth meal, cooked, is refused - a dish counts against FISH_MEALS_PER_RUN like any fish")
	_check(MetaState.fish_count(fish.id) == 3 and RunState.basket_count("barley") == 1,
		"and the refused dish spent nothing (%d fish, %d barley)" % [MetaState.fish_count(fish.id), RunState.basket_count("barley")])

	RunState.meals_eaten = 0
	GameDirector.run_active = false
	_check(not RunState.cook(fish.id, "barley").is_empty(), "cooking between runs is refused")
	_check(MetaState.fish_count(fish.id) == 3 and RunState.basket_count("barley") == 1, "and spends nothing")
	GameDirector.run_active = true
	_reached.append("cap")


## A crop authored past the ceiling lends the ceiling.
func _test_the_ceiling() -> void:
	var hero: Hero = _hero()
	var fish: FishData = ContentDB.fish("silt_minnow")
	var crop: CropData = ContentDB.crop("barley")
	var kept_sp: float = crop.dish_stamina
	var kept_lingers: float = crop.dish_lingers
	crop.dish_stamina = 5.0
	crop.dish_lingers = 5.0
	MetaState.fish.clear()
	MetaState.take_fish(fish.id)
	RunState.meals_eaten = 0
	RunState.basket = {"barley": 1}
	_empty_the_warden()
	_check(RunState.cook(fish.id, "barley").is_empty(), "the overgrown barley is cooked")
	var sp_cap: float = hero.max_stamina() * Balance.COOK_DISH_CEILING
	_check(hero.stamina <= sp_cap + 0.5,
		"a crop authored at 500%% stamina restored %.1f against a ceiling of %.1f" % [hero.stamina, sp_cap])
	var tier: int = clampi(int(fish.rarity), 0, Balance.FISH_BUFF_SECONDS.size() - 1)
	var buff_cap: float = Balance.FISH_BUFF_SECONDS[tier] * (1.0 + Balance.COOK_DISH_CEILING)
	_check(hero._meal_left <= buff_cap + 0.01,
		"a crop authored to linger 500%% kept the meal %.1fs against a ceiling of %.1fs" % [hero._meal_left, buff_cap])
	crop.dish_stamina = kept_sp
	crop.dish_lingers = kept_lingers
	_reached.append("ceiling")


## The basket rides a banked front.
func _test_banked() -> void:
	RunState.basket = {"glowcap": 2, "barley": 1}
	# A front is banked at a crossroad, never before the first wave.
	RunState.wave_number = maxi(RunState.wave_number, 3)
	var stored: Dictionary = Expedition.compose(_field)
	var round_trip: Variant = JSON.parse_string(JSON.stringify(stored))
	RunState.basket.clear()
	_check(round_trip is Dictionary and Expedition.apply(round_trip as Dictionary), "the front is banked and restored")
	_check(RunState.basket_count("glowcap") == 2 and RunState.basket_count("barley") == 1,
		"the basket came back as %s" % str(RunState.basket))
	_reached.append("banked")


## The pantry offers the pot, and Cook cooks.
func _test_the_pantry() -> void:
	var fish: FishData = ContentDB.fish("greenback_perch")
	MetaState.fish.clear()
	MetaState.take_fish(fish.id)
	RunState.meals_eaten = 0
	RunState.basket = {"frost_root": 1}
	GameDirector.run_active = true
	var screen := StashScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	screen._filter = StashScreen.FILTER_PANTRY
	screen._refresh()
	await get_tree().process_frame
	var pick: Button = _button(screen, "Frost Root")
	_check(pick != null, "the pot offers the frost root in the basket")
	if pick != null:
		pick.pressed.emit()
		await get_tree().process_frame
	var cook: Button = _button(screen, "Cook")
	_check(cook != null, "choosing it turns Eat into Cook")
	if cook != null:
		_empty_the_warden()
		var ward_before: float = _hero().health.shield()
		cook.pressed.emit()
		await get_tree().process_frame
		_check(MetaState.fish_count(fish.id) == 0 and RunState.basket_count("frost_root") == 0,
			"and Cook cooked (%d perch, %d frost root)" % [MetaState.fish_count(fish.id), RunState.basket_count("frost_root")])
		_check(_hero().health.shield() > ward_before, "the frost root's ward landed on the Warden")
	_check(_button(screen, "Frost Root") == null, "an emptied basket offers nothing")
	screen.queue_free()
	await get_tree().process_frame
	_reached.append("pantry")


func _button(root: Node, starts: String) -> Button:
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button != null and button.is_visible_in_tree() and button.text.begins_with(starts):
			return button
	return null
