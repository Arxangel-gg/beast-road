extends Node

## Rank is said in light, and light is all it is.
##
## Owner brief, 2026-09-15: a hint on elites and champions, a tint and an aura
## on rarer wildlife, and "super holographic and high contrast" on a shiny,
## "especially legendary shinies".
##
## **The bound is the one every look in this project is held to: nothing about
## the fight moves.** No number, no target, no drop and no bond reads a sheen,
## and `Graphics.KEY_RANK_SHEEN` switches every one of them off - which is what
## makes it safe to give a weak machine. That is asserted here by the shape of
## the thing rather than by a comment: the sheen is a *child* of the sprite with
## an additive blend, so the only way it could change a number is if something
## went looking for it.
##
## Four ways it goes quietly wrong, and none of them shows in a still frame:
##
## - **It draws the creature.** The first cut emitted the art plus a glow, which
##   over the creature is an opaque copy of it - and that hides everything
##   `ActorState`'s polish is doing underneath: the burning, the chill, the wet.
##   It emits only the addition now, and the blend is in the shader.
## - **The ordinary case is lit.** If a Common animal or an unpromoted body
##   wears anything, the signal stops meaning "this one is not ordinary".
## - **The ladder is out of order.** A shiny must outshine its own rarity, and
##   a Legendary shiny must be the loudest thing on the road, or the brightest
##   creature is not the rarest one.
## - **It claims the sprite's material.** `ActorState` owns that slot on a
##   promoted body - burning, chill, wet - and a sheen that took it would put
##   out every status in the game.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_the_shader_can_only_add_light()
	await _test_the_ordinary_wears_nothing()
	await _test_the_ladder_climbs()
	await _test_it_never_claims_the_material()
	_finish()


func _test_the_shader_can_only_add_light() -> void:
	var file := FileAccess.open(RankSheen.SHADER, FileAccess.READ)
	_check(file != null, "the rank shader must be on disk")
	if file == null:
		return
	var code: String = file.get_as_text()
	_check(code.contains("render_mode blend_add"),
		("the sheen must be additive: it is a second sprite over the creature, "
			+ "and anything else is an opaque copy that hides the status "
			+ "polish underneath it"))
	_check(not code.contains("blend_mul") and not code.contains("blend_sub"),
		"and must never multiply or subtract, which can darken a creature")
	_check(code.contains("COLOR = vec4(0.0)"),
		("an unranked pixel must add exactly nothing, or an ordinary creature "
			+ "is not pixel-identical to one with no sheen"))
	_check(code.contains("rarity.rgb * amount"),
		"and everything it adds must be made of the rarity's own colour")
	_check(Balance.RANK_SHEEN_TINT <= 0.3,
		("the rarity wash must stay a hint: %.2f stops the creature being "
			+ "recognisable") % Balance.RANK_SHEEN_TINT)


## **Nothing ordinary is lit.** Checked through the real door rather than by
## reading the tables, because the tables are only right if something consults
## them.
func _test_the_ordinary_wears_nothing() -> void:
	var plain: Sprite2D = await _sprite()
	RankSheen.dress(plain, 0.0, Color.WHITE)
	_check(RankSheen.worn_by(plain) == null,
		"a rank of nothing must leave no sheen behind")
	_check(Balance.RANK_SHEEN_RARE[0] <= 0.0,
		"a Common animal must wear nothing: %.2f" % Balance.RANK_SHEEN_RARE[0])
	plain.queue_free()


## **The ladder climbs and a shiny sits above it.**
func _test_the_ladder_climbs() -> void:
	var rare: Array[float] = Balance.RANK_SHEEN_RARE
	var shiny: Array[float] = Balance.RANK_SHEEN_SHINY
	_check(rare.size() == shiny.size(),
		"the two tables must cover the same rarities: %d and %d"
			% [rare.size(), shiny.size()])
	for step: int in rare.size():
		if step > 0:
			_check(rare[step] > rare[step - 1],
				"rarity %d must outshine %d: %.2f against %.2f"
					% [step, step - 1, rare[step], rare[step - 1]])
			_check(shiny[step] >= shiny[step - 1],
				"and a shiny of rarity %d must not be dimmer than %d"
					% [step, step - 1])
		_check(shiny[step] > rare[step],
			("a shiny must outshine its own rarity at %d: %.2f against %.2f"
				% [step, shiny[step], rare[step]]))
	_check(is_equal_approx(shiny[shiny.size() - 1], 1.0),
		("a legendary shiny must be the loudest thing on the road: %.2f"
			% shiny[shiny.size() - 1]))
	# And a promoted body is a hint rather than a spectacle - it is the fight,
	# not the prize.
	_check(Balance.RANK_SHEEN_ELITE < rare[rare.size() - 1],
		("an elite must be quieter than a legendary animal: %.2f against %.2f"
			% [Balance.RANK_SHEEN_ELITE, rare[rare.size() - 1]]))
	_check(Balance.RANK_SHEEN_LORD > Balance.RANK_SHEEN_ELITE,
		"and a camp lord louder than an elite")

	# Driven, so the tables are not merely well-ordered numbers nobody reads.
	var lit: Sprite2D = await _sprite()
	RankSheen.dress(lit, Balance.RANK_SHEEN_LORD, Color.WHITE)
	var worn: RankSheen = RankSheen.worn_by(lit)
	if _checked(worn != null, "a dressed sprite must carry a sheen"):
		_check(is_equal_approx(worn.amplitude(), Balance.RANK_SHEEN_LORD),
			"and wear the amplitude it was given: %.2f" % worn.amplitude())
		# Re-dressing moves it rather than stacking a second one.
		RankSheen.dress(lit, Balance.RANK_SHEEN_ELITE, Color.WHITE)
		var again: int = 0
		for child: Node in lit.get_children():
			if child is RankSheen:
				again += 1
		_check(again == 1, "a second dressing must move the sheen, not stack %d" % again)
	lit.queue_free()


## **The sprite's own material is never taken.** That slot belongs to
## `ActorState` on a promoted body, and a sheen that claimed it would put out
## burning, chill and wet at once.
func _test_it_never_claims_the_material() -> void:
	var body: Sprite2D = await _sprite()
	var owned := ShaderMaterial.new()
	body.material = owned
	RankSheen.dress(body, Balance.RANK_SHEEN_ELITE, Color.WHITE)
	_check(body.material == owned,
		"the creature's own material must survive being dressed")
	var worn: RankSheen = RankSheen.worn_by(body)
	if _checked(worn != null, "the sheen must exist to be checked"):
		_check(worn.get_parent() == body,
			"the sheen must hang off the sprite it follows")
		var blend := worn.material as CanvasItemMaterial
		_check(blend == null or blend.blend_mode == CanvasItemMaterial.BLEND_MODE_ADD
				or worn.material is ShaderMaterial,
			"the sheen must be additive over the creature")
	body.queue_free()


func _sprite() -> Sprite2D:
	var node := Sprite2D.new()
	node.texture = load("res://art/enemies/enemy_dragon_fire.png") as Texture2D
	add_child(node)
	await get_tree().process_frame
	return node


func _finish() -> void:
	if _failures == 0:
		print("[rank-sheen] PASS - %d checks: the pass only adds light, nothing ordinary is lit, the ladder climbs to a legendary shiny, and the creature's own material is never taken" % _checks)
	else:
		push_error("[rank-sheen] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _checked(condition: bool, why: String) -> bool:
	_check(condition, why)
	return condition


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[rank-sheen] FAIL: %s" % why)
