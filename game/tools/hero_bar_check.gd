extends Node

## The Warden's overhead bars stand above the head actually drawn (owner,
## 2026-09-26: "Player HP bar overlaps the player's head and should be above
## it", with thin MP and SP bars under it).
##
##   godot --headless --path game res://tools/hero_bar_check.tscn
##
## - **Clear of every head.** Both bodies, bald and in every hairstyle and every
##   beard, in all eight facings: the bottom of the lowest bar sits above the
##   highest pixel drawn - the body's own frame and the dressing on its head,
##   each read off its PNG on disk rather than off the numbers the hero used.
## - **Not floating.** The same bars sit within a hand's breadth of that head,
##   so "clear" cannot be bought by hanging them in the sky.
## - **Three bars for the player.** Health on top, then mana, then stamina,
##   each the share of its pool; a bar given -1 is not drawn and not counted.
## - **It follows the rider.** The seat lifts the sprite's offset; the bars
##   rise with it.
## - **It is wired.** The hero's tick stands the bars, read off its source,
##   because a function no tick calls is a bar left where the scene put it.
## - **A ward is League's** (2026-09-30). A ward is a segment after the health
##   on the bar over the head and on the HUD's, the whole bar rescaled when
##   the two pass the pool; the notches land on real hundreds; and only this
##   machine's own Warden speaks to the HUD, read off the source.
## - **A falling structure calls.** A tower's frame is silent above the alarm
##   share and loudest at its floor, and a wounded tower's bar keeps ticking
##   the pulse while a whole one rests.

var _failures: int = 0
var _checks: int = 0
var _reached: Array[String] = []
var _images: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	var hero := (load("res://scenes/hero/hero.tscn") as PackedScene).instantiate() as Hero
	add_child(hero)
	for _frame: int in 4:
		await get_tree().process_frame
	_test_clear_of_every_head(hero)
	_test_three_bars(hero)
	_test_follows_the_rider(hero)
	_test_wired()
	_test_ward_and_notches(hero)
	await _test_structure_alarm()
	for stage: String in ["heads", "pools", "rider", "wired", "ward", "alarm"]:
		_check(_reached.has(stage), "'%s' never reached its end - a runtime error stopped it" % stage)
	hero.queue_free()
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures == 0:
		print("[hero-bar] PASS - %d checks: every head clears the bars and none floats, health, mana and stamina stack, the bars follow the rider, the tick stands them, a ward and its notches read League's way, and a falling tower calls" % _checks)
	else:
		push_error("[hero-bar] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	printerr("[hero-bar] FAIL: %s" % why)


func _dress(hero: Hero, body: int, hair: int, beard: int) -> void:
	var look: Dictionary = WardenLook.plain()
	look[WardenLook.KEY_BODY] = body
	look[WardenLook.KEY_HAIR] = hair
	look[WardenLook.KEY_BEARD] = beard
	hero.look = look
	hero._dress_warden()


## Stands the Warden in one facing on the first idle frame, then lets the hero
## place its bars from scratch.
func _stand(hero: Hero, facing: int) -> void:
	hero.frames.set_facing(Vector2.from_angle(float(facing) * TAU / float(HeroAnimator.DIRECTION_COUNT)))
	hero.frames.play("idle", true)
	hero.frames._process(0.0)
	hero._bars_placed = false
	hero._place_bars(1.0 / 60.0)


func _image(path: String) -> Image:
	if not _images.has(path):
		_images[path] = Image.load_from_file(ProjectSettings.globalize_path(path))
	return _images[path]


## The top of what a region of a picture draws, or a large number for nothing.
func _top_of(path: String, region: Rect2) -> float:
	var image: Image = _image(path)
	if image == null:
		return 1.0e9
	var used: Rect2i = image.get_region(Rect2i(region)).get_used_rect()
	return float(used.position.y) if used.size.y > 0 else 1.0e9


## The highest pixel the Warden draws, in the hero's own space.
func _figure_top(hero: Hero) -> float:
	var sprite: Sprite2D = hero.sprite
	var body_path: String = WardenDress.art_root + String(hero.outfit["body_layer"]) + "/idle.png"
	var top: float = sprite.position.y + sprite.offset.y + _top_of(body_path, sprite.region_rect)
	var layers := sprite.get_node_or_null("Dress") as DressLayers
	if layers == null:
		return top
	for pair: Array in [[layers.hair(), "hair"], [layers.beard(), "beard"]]:
		var part: Sprite2D = pair[0]
		var option: Dictionary = hero.outfit.get(pair[1], {})
		if part == null or not part.visible or option.is_empty():
			continue
		top = minf(top, sprite.position.y + part.position.y + part.offset.y
			+ _top_of(String(option["path"]), part.region_rect))
	return top


func _test_clear_of_every_head(hero: Hero) -> void:
	var worst_gap: float = 1.0e9
	var widest_gap: float = 0.0
	var measured: int = 0
	for body: int in WardenDress.BODIES.size():
		if not WardenDress.available(WardenDress.BODIES[body]):
			continue
		var looks: Array = [[0, 0]]
		for hair: int in range(1, 25):
			if not WardenDress.head_option(WardenDress.BODIES[body], "hair", hair).is_empty():
				looks.append([hair, 0])
		for beard: int in range(1, 10):
			if not WardenDress.head_option(WardenDress.BODIES[body], "beard", beard).is_empty():
				looks.append([0, beard])
		for chosen: Array in looks:
			_dress(hero, body, int(chosen[0]), int(chosen[1]))
			for facing: int in HeroAnimator.DIRECTION_COUNT:
				_stand(hero, facing)
				var top: float = _figure_top(hero)
				var bottom: float = hero.health_bar.position.y + hero.health_bar.stack_height()
				var gap: float = top - bottom
				measured += 1
				worst_gap = minf(worst_gap, gap)
				widest_gap = maxf(widest_gap, gap)
				var what: String = "%s hair %d beard %d facing %s" % [WardenDress.BODIES[body], chosen[0], chosen[1],
					HeroAnimator.FACING_NAMES[facing]]
				_check(gap >= Balance.HERO_BAR_HEAD_GAP - 0.5,
					"%s: the bars end at %.1f and the head reaches %.1f - %.1f of air where %.1f was meant"
					% [what, bottom, top, gap, Balance.HERO_BAR_HEAD_GAP])
				_check(gap <= Balance.HERO_BAR_HEAD_GAP + 30.0,
					"%s: the bars float %.1f above the head" % [what, gap])
	_check(measured >= 16, "the walk must stand real heads (stood %d)" % measured)
	print("[hero-bar] %d heads stood: nearest %.1f, furthest %.1f above the drawn head" % [measured, worst_gap, widest_gap])
	_reached.append("heads")


func _test_three_bars(hero: Hero) -> void:
	_dress(hero, 0, 0, 0)
	hero.mana = hero.mana_max() * 0.5
	hero.stamina = hero.max_stamina() * 0.25
	_stand(hero, 2)
	var bar: HealthBar = hero.health_bar
	_check(absf(bar._pools[0] - 0.5) < 0.01, "the mana bar reads %.2f of a half-full pool" % bar._pools[0])
	_check(absf(bar._pools[1] - 0.25) < 0.01, "the stamina bar reads %.2f of a quarter-full pool" % bar._pools[1])
	var three: float = bar.stack_height()
	_check(is_equal_approx(three, Balance.HEALTH_BAR_HEIGHT + 2.0 * (Balance.HERO_POOL_BAR_GAP + Balance.HERO_POOL_BAR_HEIGHT)),
		"three bars stand %.1f tall" % three)
	bar.set_pools(0.5, -1.0)
	_check(is_equal_approx(bar.stack_height(), Balance.HEALTH_BAR_HEIGHT + Balance.HERO_POOL_BAR_GAP + Balance.HERO_POOL_BAR_HEIGHT),
		"a stamina bar given -1 is still counted")
	bar.set_pools(-1.0, -1.0)
	_check(is_equal_approx(bar.stack_height(), Balance.HEALTH_BAR_HEIGHT), "an enemy's bar grew pools")
	_reached.append("pools")


func _test_follows_the_rider(hero: Hero) -> void:
	_dress(hero, 0, 0, 0)
	_stand(hero, 2)
	var before: float = hero.health_bar.position.y
	hero.sprite.offset.y -= 40.0
	hero._place_bars(10.0)
	_check(absf((before - hero.health_bar.position.y) - 40.0) < 0.5,
		"a seat 40 higher moved the bars %.1f" % (before - hero.health_bar.position.y))
	_reached.append("rider")


func _test_ward_and_notches(hero: Hero) -> void:
	var bar: HealthBar = hero.health_bar
	hero.health.revive(1.0)
	hero.health.max_hp = 400.0
	hero.health.current_hp = 400.0
	hero.health.changed.emit(400.0, 400.0)
	_check(is_zero_approx(bar.shield_share()) and is_equal_approx(bar.scale_total(), 1.0),
		"an unwarded Warden's bar reads a ward of %.2f on a scale of %.2f" % [bar.shield_share(), bar.scale_total()])
	var heard: Array = []
	var listen := func(remaining: float, maximum: float) -> void: heard.append([remaining, maximum])
	EventBus.hero_shield_changed.connect(listen)
	hero.health.add_shield(100.0 / hero.health.shield_scale)
	EventBus.hero_shield_changed.disconnect(listen)
	_check(absf(bar.shield_share() - 0.25) < 0.01,
		"a ward of a quarter of the pool reads %.2f over the head" % bar.shield_share())
	_check(absf(bar.scale_total() - 1.25) < 0.01,
		"a whole Warden with a quarter ward should stand on a bar of 1.25 pools, it is %.2f" % bar.scale_total())
	_check(heard.size() == 1 and absf(float(heard[0][0]) - 100.0) < 0.5 and is_equal_approx(float(heard[0][1]), 400.0),
		"this machine's own Warden should tell the HUD its ward once, it said %s" % [heard])
	hero.health.take_damage(60.0, Vector2.ZERO)
	_check(bar.shield_share() < 0.25 and is_equal_approx(hero.health.current_hp, 400.0),
		"a blow under the ward should spend the ward and not the health")
	hero.health.revive(1.0)
	_check(is_zero_approx(bar.shield_share()), "a revive clears the ward and the bar did not")
	# Notches: a hundred a notch while that fits, wider steps when it would not.
	_check(is_equal_approx(HealthBar.segment_step(400.0, 10), 100.0), "400 health notches every 100")
	_check(is_equal_approx(HealthBar.segment_step(2000.0, 10), 250.0), "2000 health over ten notches steps to 250")
	_check(is_equal_approx(HealthBar.segment_step(2000.0, 24), 100.0), "the HUD's wider bar keeps 100 at 2000")
	_check(bar._segmented, "the Warden's bar over the head is not notched")
	# The HUD's marks, driven as the HUD drives them.
	var marks := PoolMarks.new()
	add_child(marks)
	marks.size = Vector2(300.0, 16.0)
	marks.show_pool(0.8, 0.4, 500.0)
	_check(is_equal_approx(marks.ward, 0.2), "a ward past the bar's end is cut at its end, it reads %.2f" % marks.ward)
	marks.queue_free()
	var hud: String = FileAccess.get_file_as_string("res://scenes/ui/hud.gd")
	_check(hud.contains("EventBus.hero_shield_changed.connect(_on_hero_shield)") and hud.contains("_hero_marks.show_pool("),
		"the HUD's bar never hears the ward")
	var source: String = FileAccess.get_file_as_string("res://scenes/hero/hero.gd")
	for fn: String in ["func _on_health_changed(", "func _on_shield_changed("]:
		var at: int = source.find(fn)
		var body: String = source.substr(at, 700) if at >= 0 else ""
		_check(body.contains("is_local_player()"),
			"%s speaks for every body in the party - a partner's blow reaches this machine's HUD" % fn)
	_reached.append("ward")


func _test_structure_alarm() -> void:
	_check(is_zero_approx(HealthBar.alarm_for(1.0)) and is_zero_approx(HealthBar.alarm_for(Balance.HEALTH_BAR_ALARM_FROM)),
		"a structure above the alarm share should be silent")
	_check(is_equal_approx(HealthBar.alarm_for(Balance.HEALTH_BAR_ALARM_FULL), 1.0), "a structure at the floor should call at full")
	var last: float = -1.0
	var climbs: bool = true
	for step: int in range(20, 0, -1):
		var now: float = HealthBar.alarm_for(float(step) / 20.0)
		climbs = climbs and now >= last
		last = now
	_check(climbs, "the alarm must only grow as a structure falls")
	var health := Health.new()
	health.max_hp = 100.0
	health.current_hp = 100.0
	add_child(health)
	var bar: HealthBar = (load("res://scenes/ui/health_bar.tscn") as PackedScene).instantiate() as HealthBar
	add_child(bar)
	bar.set_structure(true)
	bar.bind(health)
	await get_tree().process_frame
	_check(is_zero_approx(bar.alarm()) and not bar.is_processing(), "a whole tower's bar should rest")
	health.take_damage(80.0, Vector2.ZERO)
	for _frame: int in 30:
		await get_tree().process_frame
	_check(bar.alarm() > 0.5 and bar.is_processing(),
		"a tower at a fifth should call and keep its pulse ticking (alarm %.2f)" % bar.alarm())
	var plain: HealthBar = (load("res://scenes/ui/health_bar.tscn") as PackedScene).instantiate() as HealthBar
	add_child(plain)
	plain.bind(health)
	_check(is_zero_approx(plain.alarm()), "a body's bar is not a structure's and must not call")
	for path: String in ["res://scenes/battlefield/tower.gd", "res://scenes/battlefield/barricade.gd"]:
		_check(FileAccess.get_file_as_string(path).contains(".set_structure(true)"),
			"%s never marks its bar as a structure's" % path.get_file())
	bar.queue_free()
	plain.queue_free()
	health.queue_free()
	_reached.append("alarm")


func _test_wired() -> void:
	var source: String = FileAccess.get_file_as_string("res://scenes/hero/hero.gd")
	# **Every rendered frame, not every physics step** (amended 2026-09-30): the
	# bars are a picture, and the step runs three times a frame on a 180 Hz
	# screen. The invariant is unchanged - something stands them every frame.
	var start: int = source.find("\nfunc _process(")
	var body: String = source.substr(start, 600) if start >= 0 else ""
	_check(body.contains("_place_bars(delta)"), "the hero's frame never stands the bars")
	var step: int = source.find("func _physics_process_measured(")
	var step_end: int = source.find("\nfunc ", step + 5)
	_check(step >= 0 and not source.substr(step, step_end - step).contains("_place_bars("),
		"the bars are stood inside the physics step again, three times a frame on a fast screen")
	_reached.append("wired")
