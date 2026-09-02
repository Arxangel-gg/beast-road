extends Node

## Combat state on a body, as material rather than as tint (owner brief,
## 2026-09-01: "Every shader must either improve atmosphere, communicate
## gameplay, or make progression feel more powerful").
##
## Six promises. Every one of them fails silently, which is why this exists at
## all — a shader that stops being driven still draws, it just draws nothing, and
## the game plays exactly as it did with the numbers invisible.
##
## 1. **Both shaders answer to the same uniforms.** Every enemy wears
##    `blood_stain`; a promoted one wears `actor_polish`, because whichever
##    material is claimed first wins. State that only reached one of them would
##    vanish the moment an enemy was promoted.
## 2. **A burning body carries burn**, and stops when the fire does.
## 3. **A chilled body carries frost, and a frozen one carries all of it.**
## 4. **A winding-up body carries a rim that grows.** The tell is the one thing
##    here a player has to read *in time* rather than merely notice, and a rim
##    that thickens says how long is left without a bar.
## 5. **A promoted body still receives all of it.** The elite path discarded its
##    material reference before this change, so a champion was unreachable.
## 6. **Nothing wrong with it costs nothing.** Ordinary walkers are the common
##    case by a wide margin and the min-spec frame budget is still open.
##
## And the fallback, which is not cosmetic: a player who cannot see a wind-up is
## playing a harder game rather than a plainer-looking one, so the tell has to
## arrive on every configuration. Low keeps the stain material and the shader
## carries it there; only a build whose shader failed to load falls back to the
## tint. The last test insists on the right one of those in each case rather than
## accepting either, because the first version of it assumed Low meant no
## material and was wrong about the build it was testing.

const REQUIRED: PackedStringArray = ["burn", "burn_colour", "frost",
	"frost_colour", "telegraph", "telegraph_colour", "telegraph_width",
	"state_seed", "shine", "shine_colour", "dissolve",
	"dissolve_colour"]

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	RunState.reset()
	RunState.act = 1
	await _test_both_shaders_declare_it()
	await _test_burning_body()
	await _test_frozen_body()
	await _test_windup_rim_grows()
	await _test_promoted_body_is_reachable()
	await _test_quiet_body_is_free()
	await _test_tint_survives_without_shaders()
	await _test_shiny_animal_shines()
	await _test_death_comes_apart()
	_finish()


## 1. Neither shader may drift from the other.
func _test_both_shaders_declare_it() -> void:
	for path: String in [BloodStain.SHADER_PATH, ActorPolish.SHADER_PATH]:
		var shader: Shader = load(path) as Shader
		_check(shader != null, "%s must load" % path.get_file())
		if shader == null:
			continue
		var names: Dictionary = {}
		for entry: Dictionary in shader.get_shader_uniform_list():
			names[String(entry.get("name", ""))] = true
		for wanted: String in REQUIRED:
			_check(names.has(wanted),
				"%s is missing the '%s' uniform, so state stops at whichever "
					% [path.get_file(), wanted]
					+ "material a body happens to be wearing")
	_ran += 1


## 2. Fire reaches the material, and leaves with the fire.
func _test_burning_body() -> void:
	var field := EnemyField.new()
	add_child(field)
	var foe: Enemy = _make(field)
	if foe == null:
		field.queue_free()
		return
	foe.apply_burn(40.0, 6.0)
	await _settle()
	_check(_uniform(foe, "burn") > 0.5,
		"a body burning for six seconds must be lit, reads %.2f"
			% _uniform(foe, "burn"))

	# And it goes out. Asked by draining the meter directly rather than by
	# waiting six seconds, because a gate that sleeps is a gate nobody runs.
	foe.set("_burn_left", 0.0)
	await _settle()
	_check(_uniform(foe, "burn") <= 0.001,
		"a fire that has burned out must stop drawing, reads %.2f"
			% _uniform(foe, "burn"))
	field.queue_free()
	await _settle()
	_ran += 1


## 3. Chill is a meter; frozen is that meter arrived.
func _test_frozen_body() -> void:
	var field := EnemyField.new()
	add_child(field)
	var chilled: Enemy = _make(field)
	var frozen: Enemy = _make(field)
	if chilled == null or frozen == null:
		field.queue_free()
		return
	chilled.set("_chill", 0.5)
	frozen.set("_freeze_left", 3.0)
	await _settle()
	_check(_uniform(chilled, "frost") > 0.2 and _uniform(chilled, "frost") < 0.9,
		"a half-chilled body must be part-rimed, reads %.2f"
			% _uniform(chilled, "frost"))
	_check(_uniform(frozen, "frost") > _uniform(chilled, "frost"),
		"and a frozen one must be more so, %.2f against %.2f"
			% [_uniform(frozen, "frost"), _uniform(chilled, "frost")])
	field.queue_free()
	await _settle()
	_ran += 1


## 4. The tell appears at once and thickens toward the blow.
##
## Both halves matter. A rim that fades in is read late, and late is the whole
## failure a telegraph exists to prevent; a rim that does not grow is a light
## that is merely on, and says nothing about how long is left.
func _test_windup_rim_grows() -> void:
	var early: float = ActorState.telegraph_level(
		Balance.ENEMY_ATTACK_WINDUP, Balance.ENEMY_ATTACK_WINDUP)
	var late: float = ActorState.telegraph_level(
		Balance.ENEMY_ATTACK_WINDUP * 0.05, Balance.ENEMY_ATTACK_WINDUP)
	_check(early >= Balance.STATE_TELEGRAPH_FLOOR - 0.001,
		"the tell must be visible on its first frame, starts at %.2f" % early)
	_check(late > early + 0.2,
		"and must thicken toward the strike, %.2f then %.2f" % [early, late])
	_check(ActorState.telegraph_level(0.0, Balance.ENEMY_ATTACK_WINDUP) == 0.0,
		"a body that is not winding up must carry no rim")

	# And on a real body, driven by the state machine rather than by arithmetic.
	var field := EnemyField.new()
	add_child(field)
	var foe: Enemy = _make(field)
	if foe == null:
		field.queue_free()
		return
	foe.set("_state", 1)
	foe.set("_state_left", Balance.ENEMY_ATTACK_WINDUP * 0.2)
	await _settle()
	var lit: float = _uniform(foe, "telegraph")
	_check(lit > Balance.STATE_TELEGRAPH_FLOOR,
		"a body most of the way through its wind-up must carry a thick rim, "
			+ "reads %.2f" % lit)
	field.queue_free()
	await _settle()
	_ran += 1


## 5. A champion is reachable.
##
## The regression this holds: promotion claims the sprite's material slot, and
## the reference to what it claimed used to be created, configured and dropped.
## Every enemy in the game could show state except the ones worth watching.
func _test_promoted_body_is_reachable() -> void:
	var affix: EnemyAffixData = null
	for value: Variant in ContentDB.affixes.values():
		affix = value as EnemyAffixData
		break
	var field := EnemyField.new()
	add_child(field)
	var worn: Array[EnemyAffixData] = []
	if affix != null:
		worn.append(affix)
	var champion: Enemy = _make(field, Enemy.Rank.CHAMPION, worn)
	if champion == null:
		field.queue_free()
		return
	champion.apply_burn(40.0, 6.0)
	await _settle()
	_check(ActorState.carried(champion.call("_state_material")),
		"a promoted body must keep a material that understands state")
	_check(_uniform(champion, "burn") > 0.5,
		"and must burn like any other, reads %.2f" % _uniform(champion, "burn"))
	field.queue_free()
	await _settle()
	_ran += 1


## 6. An ordinary walker pays nothing.
func _test_quiet_body_is_free() -> void:
	var field := EnemyField.new()
	add_child(field)
	var foe: Enemy = _make(field)
	if foe == null:
		field.queue_free()
		return
	await _settle()
	for name: String in ["burn", "frost", "telegraph"]:
		_check(_uniform(foe, name) <= 0.001,
			"a body with nothing wrong with it must carry no %s, reads %.2f"
				% [name, _uniform(foe, name)])
	field.queue_free()
	await _settle()
	_ran += 1


## The tell survives the cheapest machine and the shaderless build.
##
## **This is a gameplay promise, not a visual one.** A player who cannot see a
## wind-up is playing a harder game rather than a plainer-looking one, so it has
## to arrive by *some* route on every configuration.
##
## Two routes, and the gate insists on the right one in each case rather than on
## a disjunction. On Low the stain material still attaches - only its outline is
## zeroed - so the shader carries it, and that was worth discovering: the first
## version of this test assumed Low meant no material and was simply wrong about
## the build it was testing. When there is genuinely no material at all, which is
## a build whose shader failed to load, the tint has to carry all three states on
## its own.
func _test_tint_survives_without_shaders() -> void:
	var restore: Dictionary = Graphics.to_dictionary()
	Graphics.from_dictionary({Graphics.KEY_PRESET: Graphics.PRESET_LOW})
	_check(not Graphics.polish_shaders(),
		"the Low preset must be the one that sheds polish shaders")

	var field := EnemyField.new()
	add_child(field)
	var low: Enemy = _make(field)
	if low == null:
		field.queue_free()
		Graphics.from_dictionary(restore)
		return
	low.set("_state", 1)
	low.set("_state_left", Balance.ENEMY_ATTACK_WINDUP * 0.5)
	await _settle()
	_check(_uniform(low, "telegraph") > 0.0,
		"Low keeps the stain material, so the tell must still be drawn by it")
	Graphics.from_dictionary(restore)

	# And with no material whatsoever - the shaderless build. Taking both
	# references away drives the same `_update_sprite` a player runs, with the
	# one thing missing that the fallback exists for.
	var bare: Enemy = _make(field)
	if bare == null:
		field.queue_free()
		return
	await _settle()
	bare.set("_blood", null)
	bare.set("_polish", null)
	bare.set("_blood_tried", true)
	var plain: Color = bare.sprite.modulate
	bare.set("_state", 1)
	bare.set("_state_left", Balance.ENEMY_ATTACK_WINDUP * 0.5)
	await _settle()
	_check(bare.sprite.modulate != plain,
		"with no material at all the tint must carry the wind-up")

	bare.set("_state", 0)
	bare.set("_state_left", 0.0)
	bare.set("_freeze_left", 4.0)
	await _settle()
	_check(bare.sprite.modulate != plain,
		"and must carry a freeze")

	field.queue_free()
	await _settle()
	_ran += 1


## 8. A killed body comes apart, and says what killed it.
##
## Three promises. The dissolve has to *run* - a uniform nobody drives leaves the
## body whole until the node is freed, which is a corpse blinking out. It has to
## carry the condition the body died in, which is the part that teaches the
## player what their fire tower did. And the wind-up rim has to stop, because a
## dying body still showing a tell is a tell that lies, and `_update_state_shader`
## does not run during death - so whatever the rim was at the moment of the kill
## would sit there for the whole dissolve unless something clears it.
func _test_death_comes_apart() -> void:
	var field := EnemyField.new()
	add_child(field)
	var foe: Enemy = _make(field)
	if foe == null:
		field.queue_free()
		return
	await _settle()
	_check(_uniform(foe, "dissolve") <= 0.001,
		"a living body must be whole, reads %.2f" % _uniform(foe, "dissolve"))

	# Burning, mid-wind-up, then killed: every condition this has to resolve, at
	# once, which is also the frame that used to leave a rim on a corpse.
	foe.apply_burn(40.0, 6.0)
	foe.set("_state", 1)
	foe.set("_state_left", Balance.ENEMY_ATTACK_WINDUP * 0.3)
	await _settle()
	_check(_uniform(foe, "telegraph") > 0.0, "the rim must be up before the kill")

	foe.set("_state", int(4))
	foe.set("_death_left", Balance.ENEMY_DEATH_FADE * 0.5)
	await _settle()
	var through: float = _uniform(foe, "dissolve")
	_check(through > 0.2 and through < 0.95,
		"a body half through its death must be half apart, reads %.2f" % through)
	_check(_uniform(foe, "telegraph") <= 0.001,
		"and must not still be telegraphing a blow it will never land")

	var hue: Variant = foe.call("_state_material").get_shader_parameter(
		"dissolve_colour")
	_check(hue != null and Color(hue).is_equal_approx(Balance.STATE_BURN_COLOUR),
		"a body that died burning must come apart in embers, got %s" % str(hue))

	field.queue_free()
	await _settle()
	_ran += 1


## 7. A shiny animal is drawn as one, and an ordinary one is not.
##
## Driven through the spawner with the host's answer forced, rather than by
## calling the dressing function - the roll, the material and the dressing are
## three separate things and the bug worth catching is any one of them not
## reaching the next. `told_shiny` is the co-op path a guest uses, which makes it
## the honest way to ask for a known shiny without reaching inside.
func _test_shiny_animal_shines() -> void:
	var kind: WildlifeData = null
	for value: Variant in ContentDB.wildlife_kinds.values():
		var one := value as WildlifeData
		if one != null and ResourceLoader.exists(one.get_sprite_path()):
			kind = one
			break
	_check(kind != null, "a wildlife kind with art is needed to shine")
	if kind == null:
		return

	var wildlife := Wildlife.new()
	wildlife.grid = BattleGrid.new()
	add_child(wildlife)
	wildlife.call("_spawn", kind, Vector2(600.0, 0.0), 0, 0, 1)
	wildlife.call("_spawn", kind, Vector2(900.0, 0.0), 0, 0, 0)
	await _settle()

	# Read out as numbers before anything is freed, and hold nothing else.
	#
	# A local `Array` taken from `_living` is the *same* array, so keeping one
	# across the teardown keeps every sprite, bar and texture in it alive past
	# the frame the node is freed on - four objects and two resources still in
	# use at exit, which the release gate reads as a failure rather than as
	# untidiness. Two floats cannot do that.
	var placed: int = (wildlife.get("_living") as Array).size()
	var lit: float = _spawned_uniform(wildlife, 0, "shine")
	var plain: float = _spawned_uniform(wildlife, 1, "shine")
	_check(placed >= 2, "both animals must have been placed, got %d" % placed)
	if placed >= 2:
		_check(lit > 0.5, "a shiny must carry the shimmer, reads %.2f" % lit)
		_check(plain <= 0.001,
			"and an ordinary animal must not, reads %.2f" % plain)

	# **Silence, then wait.** Placing an animal plays its call, and a voice still
	# sounding at exit is an `AudioStreamPlayer` still alive - which the release
	# gate reports as leaked instances and a failure. `momentum_check` learned
	# the same thing off fifty death sounds; stopping alone is not enough,
	# because the players are freed a few frames later.
	wildlife.queue_free()
	Sfx.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	_ran += 1


## The uniform on one spawned animal's own sprite material.
##
## Reaches into the live list and comes back with a float, deliberately: nothing
## it touches outlives the call. See the note where it is used.
func _spawned_uniform(wildlife: Node, index: int, name: String) -> float:
	var living: Array = wildlife.get("_living") as Array
	if index >= living.size():
		return 0.0
	var animal: Dictionary = living[index] as Dictionary
	var sprite := animal.get("sprite", null) as Sprite2D
	if sprite == null:
		return 0.0
	var material := sprite.material as ShaderMaterial
	if not ActorState.carried(material):
		return 0.0
	var value: Variant = material.get_shader_parameter(name)
	return 0.0 if value == null else float(value)


# --- harness -----------------------------------------------------------------

func _make(field: EnemyField, rank: Enemy.Rank = Enemy.Rank.COMMON,
		worn: Array[EnemyAffixData] = []) -> Enemy:
	var breed: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var one := value as EnemyData
		if one != null and one.category == EnemyData.Category.BREED:
			breed = one
			break
	if breed == null:
		_check(false, "a breed is needed to put state on")
		return null
	var scene: PackedScene = load("res://scenes/battlefield/enemy.tscn")
	var foe := scene.instantiate() as Enemy
	if rank != Enemy.Rank.COMMON:
		foe.promote(rank, worn)
	foe.setup(breed, 0, field, 1.0)
	field.add_child(foe)
	return foe


## The value a body's material actually carries, or zero when it has none.
##
## Read back off the material rather than off the enemy's own fields, because
## what this gate is for is the gap between the two: the fields were always
## right, and for three states nothing was pointing them at anything.
func _uniform(foe: Enemy, name: String) -> float:
	var material: ShaderMaterial = foe.call("_state_material")
	if material == null:
		return 0.0
	var value: Variant = material.get_shader_parameter(name)
	return 0.0 if value == null else float(value)


func _settle() -> void:
	for _frame: int in 4:
		await get_tree().process_frame
		await get_tree().physics_frame


func _finish() -> void:
	# Counted at the end of each test rather than the start. A runtime error
	# aborts the function it is in without failing anything, so a test that
	# counted itself first would report having run while having done nothing.
	if _failures == 0 and _ran == 9:
		print("[state-shader] PASS - fire, ice, the wind-up, a shiny and coming "
			+ "apart are material on every body including promoted ones, cost "
			+ "nothing on a quiet one, and still read on Low")
	elif _failures == 0:
		printerr("[state-shader] FAIL - only %d of 9 tests ran" % _ran)
		get_tree().quit(1)
		return
	else:
		printerr("[state-shader] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[state-shader] FAIL: %s" % why)
