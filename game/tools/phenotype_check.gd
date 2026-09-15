extends Node

## No two animals of a kind are the same animal, and none of it is a number.
##
##   godot --headless --path game res://tools/phenotype_check.tscn
##
## Owner, 2026-09-15: "Wildlife should also all generate with some random
## variations using shaders appropriately for all wildlife with seeds so that
## they all end up looking unique and different in some ways."
##
## **A coat cannot be seen by a gate** - headless compiles no shader, and even
## with one nothing here could judge whether a deer looks like a deer. So what
## is held is everything about a coat that is *not* the picture, and every one
## of these is a way the feature quietly stops working:
##
## - **It never varies.** A seed that is the same for every animal - which is
##   exactly what happened to spirit personalities when every animal in a solo
##   run had serial zero - gives thirty-nine species one coat each, and the
##   whole system is a shader nobody can see doing nothing.
## - **It varies too much.** A hue wide enough to turn a fox blue makes the rank
##   sheen unreadable: the player can no longer tell "rarer" from "different".
##   The ceilings are the bound and they are checked per species.
## - **It rerolls.** A coat that changes when the animal is looked at twice is
##   not an animal, and this project has paid for that once already with shiny.
## - **A uniform is renamed.** The shader is the consumer and GDScript will
##   happily set a parameter that does not exist, in silence, for ever.
## - **Something reads it.** The bound is that a phenotype is a look. If the
##   switch that turns coats off changed a number, it would be a difficulty
##   setting nobody chose - the fog's bound, in a second place.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_shader_answers_to_every_uniform()
	_test_a_coat_is_stable_and_varies()
	_test_no_species_wanders_past_the_ceilings()
	_test_a_pattern_that_marks_nothing_is_refused()
	_test_switching_it_off_leaves_nothing_behind()
	await _test_two_of_a_kind_wear_different_coats()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[phenotype] PASS - %d checks: every uniform is read, a coat is "
			+ "stable, varies, stays inside its ceilings, and switching it off "
			+ "leaves the roster exactly as it was") % _checks)
	else:
		push_error("[phenotype] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **The shader is the consumer, and a misspelt uniform is silent.**
##
## `ShaderMaterial.set_shader_parameter` accepts any name at all. A coat wired
## to `coat_hue_shift` while the shader reads `coat_hue` would set a value
## nothing looks at, for ever, with nothing to see - the same class of failure
## as an effect key nothing reads, which this project has now paid for three
## times.
func _test_the_shader_answers_to_every_uniform() -> void:
	var file := FileAccess.open(ActorPolish.SHADER_PATH, FileAccess.READ)
	_check(file != null, "the actor shader must be on disk")
	if file == null:
		return
	var code: String = file.get_as_text()
	for name: String in Phenotype.UNIFORMS:
		_check(code.contains("uniform") and code.contains(name),
			("the shader declares no `%s`, so the coat sets a parameter nothing "
				+ "reads") % name)
	# And the coat is applied to the body rather than declared and ignored.
	_check(code.contains("coat_apply(source.rgb"),
		("the shader declares the coat uniforms and never applies them, which "
			+ "is the same silence one layer further in"))


## **Stable across reads, different across animals.**
func _test_a_coat_is_stable_and_varies() -> void:
	var kinds: Array = ContentDB.wildlife_kinds.values()
	_check(not kinds.is_empty(), "there must be wildlife to wear a coat")
	var differing: int = 0
	var counted: int = 0
	for value: Variant in kinds:
		var kind := value as WildlifeData
		if kind == null:
			continue
		counted += 1
		var once: Dictionary = Phenotype.describe(kind, 7)
		var again: Dictionary = Phenotype.describe(kind, 7)
		_check(_same(once, again),
			("%s wears a different coat on the second read - a coat that "
				+ "rerolls is not an animal") % kind.id)
		if not _same(once, Phenotype.describe(kind, 8)):
			differing += 1
		# And two species with the same serial are not the same coat, or the
		# seed is the serial alone and a herd of everything matches.
		_check(Phenotype.seed_for(kind.id, 7) != Phenotype.seed_for("", 7),
			"%s derives its seed from its serial alone" % kind.id)
	_check(counted > 0 and differing >= int(float(counted) * 0.9),
		("only %d of %d species look different between two serials - the seed "
			+ "is not reaching the coat") % [differing, counted])


## **Inside the ceilings, per species, over many animals.**
##
## Read off the values a coat actually takes rather than off the authored
## spread, because the spread is only half of it: `Phenotype` clamps to the
## ceiling, and a gate that checked the authored number would pass a species
## that authored ten and be measuring the clamp rather than the design.
func _test_no_species_wanders_past_the_ceilings() -> void:
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind == null:
			continue
		var widest: float = 0.0
		var lightest: float = 0.0
		var richest: float = 0.0
		for serial: int in range(1, 60):
			var coat: Dictionary = Phenotype.describe(kind, serial)
			widest = maxf(widest, absf(float(coat["coat_hue"])))
			lightest = maxf(lightest, absf(float(coat["coat_light"])))
			richest = maxf(richest, absf(float(coat["coat_saturation"])))
		_check(widest <= Balance.PHENOTYPE_HUE_CEILING + 0.0001,
			("%s shifts hue by %.3f, past the %.3f that keeps a coat from "
				+ "reading as a rarity") % [kind.id, widest,
					Balance.PHENOTYPE_HUE_CEILING])
		_check(lightest <= Balance.PHENOTYPE_LIGHT_CEILING + 0.0001,
			"%s shifts light by %.3f, past %.3f"
				% [kind.id, lightest, Balance.PHENOTYPE_LIGHT_CEILING])
		_check(richest <= Balance.PHENOTYPE_SATURATION_CEILING + 0.0001,
			"%s shifts saturation by %.3f, past %.3f"
				% [kind.id, richest, Balance.PHENOTYPE_SATURATION_CEILING])


## **A pattern with nothing to draw with is a pattern nobody sees.**
func _test_a_pattern_that_marks_nothing_is_refused() -> void:
	var marked: int = 0
	for value: Variant in ContentDB.wildlife_kinds.values():
		var kind := value as WildlifeData
		if kind == null or kind.coat_pattern == WildlifeData.Coat.NONE:
			continue
		marked += 1
		_check(kind.coat_pattern_strength > 0.0,
			"%s authors markings at zero strength" % kind.id)
		_check(kind.coat_pattern_tint.a > 0.0,
			("%s authors markings in a transparent colour, so it has a pattern "
				+ "that marks nothing") % kind.id)
		_check(kind.coat_pattern_scale >= 1.0,
			"%s authors markings smaller than a pixel" % kind.id)
		_check(int(kind.coat_pattern) < WildlifeData.Coat.size(),
			"%s names a pattern the shader has no branch for" % kind.id)
	_check(marked >= 8,
		("only %d species have markings - colour alone is not what the owner "
			+ "asked for") % marked)


## **Off means off, and off changes nothing but the picture.**
func _test_switching_it_off_leaves_nothing_behind() -> void:
	var kind: WildlifeData = null
	for value: Variant in ContentDB.wildlife_kinds.values():
		var candidate := value as WildlifeData
		if candidate != null and candidate.coat_pattern != WildlifeData.Coat.NONE:
			kind = candidate
			break
	if kind == null:
		_check(false, "the gate needs a species with markings")
		return
	var lit: Dictionary = Phenotype.describe(kind, 11)
	var was: bool = Graphics.phenotypes()
	Graphics.set_switch(Graphics.KEY_PHENOTYPE, false)
	var plain: Dictionary = Phenotype.describe(kind, 11)
	_check(is_zero_approx(float(plain["coat_hue"]))
			and is_zero_approx(float(plain["coat_pattern_strength"]))
			and int(plain["coat_pattern"]) == 0,
		"turning coats off must leave the animal exactly as it was painted")
	_check(not _same(lit, plain),
		"the switch changed nothing, so it is not the switch for this")
	Graphics.set_switch(Graphics.KEY_PHENOTYPE, was)


## **Driven on the real field**, because everything above reads a static
## function and none of it proves an animal on the road ever wears one.
func _test_two_of_a_kind_wear_different_coats() -> void:
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	var animals: Wildlife = field.get_node_or_null("Wildlife") as Wildlife
	_check(animals != null, "the battlefield must have a wildlife system")
	if animals != null:
		# **Driven rather than waited for.** Arrivals are a coin flip on a clock,
		# so twenty frames of a fresh road is reliably an empty one - and an
		# empty road reads exactly like a coat that is never put on.
		for _try: int in 40:
			animals.call("_consider_arrival")
		await get_tree().process_frame
		var coats: Dictionary = {}
		var seen: int = 0
		for record: Dictionary in animals.living():
			var material := record.get("impact") as ShaderMaterial
			if material == null:
				continue
			seen += 1
			var key: String = "%s|%.4f|%.4f|%.4f" % [
				String((record["data"] as WildlifeData).id),
				float(material.get_shader_parameter("coat_hue")),
				float(material.get_shader_parameter("coat_light")),
				float(material.get_shader_parameter("coat_saturation"))]
			coats[key] = true
		_check(seen > 0, "the road must have animals on it to look at")
		# Every animal placed must be its own: a duplicate key means two of them
		# rolled the same coat, which with a live serial cannot happen unless
		# the serial is not reaching the seed.
		_check(seen == 0 or coats.size() == seen,
			("%d animals wear %d different coats - the serial is not reaching "
				+ "the seed") % [seen, coats.size()])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame


func _same(one: Dictionary, two: Dictionary) -> bool:
	for name: String in Phenotype.UNIFORMS:
		if str(one.get(name)) != str(two.get(name)):
			return false
	return true


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[phenotype] " + why)
