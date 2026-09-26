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
	_test_the_split_moved_no_coat()
	_test_a_cub_resembles_its_parents()
	await _test_two_of_a_kind_wear_different_coats()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[phenotype] PASS - %d checks: every uniform is read, a coat is "
			+ "stable, varies, stays inside its ceilings, a cub wears its parents' "
			+ "and switching it off leaves the roster exactly as it was") % _checks)
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
		# Before the arrivals, which fill the field to its cap - a litter rolled
		# on a full field is an empty litter, and would test nothing.
		_test_a_litter_is_born_wearing_it(animals, field.hero.global_position)
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


## **Nothing that was not born changed its coat** (2026-09-25). `dress` was
## split into `genes` and `apply` so a newborn could be handed its parents'
## coat; the draws are held here against the arithmetic `dress` always did,
## written out, for every species - because a reordered draw would re-coat every
## animal in the game and nothing would error.
func _test_the_split_moved_no_coat() -> void:
	for kind_value: Variant in ContentDB.wildlife_kinds.values():
		var kind := kind_value as WildlifeData
		if kind == null:
			continue
		for serial: int in [1, 2, 7, 40, 999]:
			var rng := RandomNumberGenerator.new()
			rng.seed = Phenotype.seed_for(kind.id, serial)
			var hue: float = rng.randf_range(-1.0, 1.0) * minf(kind.coat_hue_spread,
				Balance.PHENOTYPE_HUE_CEILING)
			var light: float = rng.randf_range(-1.0, 1.0) * minf(kind.coat_light_spread,
				Balance.PHENOTYPE_LIGHT_CEILING)
			var saturation: float = rng.randf_range(-1.0, 1.0) * minf(
				kind.coat_saturation_spread, Balance.PHENOTYPE_SATURATION_CEILING)
			var strength: float = 0.0
			if kind.coat_pattern != WildlifeData.Coat.NONE:
				strength = kind.coat_pattern_strength * rng.randf_range(0.55, 1.0)
			var offset := Vector2(rng.randf() * 64.0, rng.randf() * 64.0)
			var coat: Dictionary = Phenotype.genes(kind, serial)
			var same: bool = is_equal_approx(float(coat["hue"]), hue) \
				and is_equal_approx(float(coat["light"]), light) \
				and is_equal_approx(float(coat["saturation"]), saturation) \
				and is_equal_approx(float(coat["strength"]), strength) \
				and (coat["offset"] as Vector2).is_equal_approx(offset)
			_check(same, "%s #%d wears a different coat since dress was split" % [kind.id, serial])


## **A cub looks like its parents, and no two cubs are one cub** (2026-09-25).
## Every gene inside the range its parents span, widened by the mutation and
## never past the species' own ceiling; a cub nearer its parents than a
## stranger of its kind nearly always; a litter of four never one coat; and the
## same litter rolled twice the same litter.
func _test_a_cub_resembles_its_parents() -> void:
	var nearer: int = 0
	var trials: int = 0
	for kind_value: Variant in ContentDB.wildlife_kinds.values():
		var kind := kind_value as WildlifeData
		if kind == null:
			continue
		var room: float = Phenotype.spread(kind, "hue") + Phenotype.spread(kind, "light") \
			+ Phenotype.spread(kind, "saturation")
		if room <= 0.0:
			continue
		for pair: int in 30:
			var mother: Dictionary = {"data": kind, "net_id": 100 + pair * 2}
			var father: Dictionary = {"data": kind, "net_id": 101 + pair * 2}
			var from_mother: Dictionary = Phenotype.coat_of(mother)
			var from_father: Dictionary = Phenotype.coat_of(father)
			var litter: Array[Dictionary] = []
			for index: int in 4:
				var cub: Dictionary = WildlifeFamilies.cub_coat(mother, father, kind, 7, index)
				litter.append(cub)
				for gene: String in ["hue", "light", "saturation"]:
					var limit: float = Phenotype.spread(kind, gene)
					var drift: float = limit * Balance.PHENOTYPE_MUTATION + 0.0001
					var low: float = minf(float(from_mother[gene]), float(from_father[gene])) - drift
					var high: float = maxf(float(from_mother[gene]), float(from_father[gene])) + drift
					_check(float(cub[gene]) >= low and float(cub[gene]) <= high,
						"%s: a cub's %s %.4f is outside its parents' %.4f and %.4f"
							% [kind.id, gene, float(cub[gene]), float(from_mother[gene]),
								float(from_father[gene])])
					_check(absf(float(cub[gene])) <= limit + 0.0001,
						"%s: a cub's %s walked past the species' ceiling" % [kind.id, gene])
				_check(float(cub["strength"]) >= 0.0
					and float(cub["strength"]) <= kind.coat_pattern_strength + 0.0001,
					"%s: a cub's markings are stronger than its species allows" % kind.id)
				var stranger: Dictionary = Phenotype.genes(kind, 50000 + pair * 13 + index)
				trials += 1
				if minf(_gap(kind, cub, from_mother), _gap(kind, cub, from_father)) \
						< _gap(kind, cub, stranger):
					nearer += 1
			var distinct: Dictionary = {}
			for cub: Dictionary in litter:
				distinct["%.5f|%.5f|%.5f" % [float(cub["hue"]), float(cub["light"]),
					float(cub["saturation"])]] = true
			_check(distinct.size() > 1, "%s: a litter of four came out as one coat" % kind.id)
			var again: Dictionary = WildlifeFamilies.cub_coat(mother, father, kind, 7, 0)
			_check(is_equal_approx(float(again["hue"]), float(litter[0]["hue"]))
				and is_equal_approx(float(again["light"]), float(litter[0]["light"])),
				"%s: the same litter rolled twice is a different litter" % kind.id)
	var share: float = float(nearer) / float(maxi(trials, 1))
	_check(share >= 0.8,
		"a cub is nearer a parent than a stranger only %.0f%% of the time - that is not resemblance"
			% (share * 100.0))


## How far apart two coats of one kind are, each gene as a share of the room
## the species has on it.
func _gap(kind: WildlifeData, one: Dictionary, two: Dictionary) -> float:
	var total: float = 0.0
	for gene: String in ["hue", "light", "saturation"]:
		var limit: float = Phenotype.spread(kind, gene)
		if limit > 0.0:
			total += absf(float(one[gene]) - float(two[gene])) / limit
	return total


## **Driven, not assumed.** A litter rolled by the real families and placed by
## the real `spawn_born` wears the coat it was rolled with - on its record, and
## on the material the shader reads.
func _test_a_litter_is_born_wearing_it(animals: Wildlife, near: Vector2) -> void:
	var families := animals.get("_families") as WildlifeFamilies
	var kind: WildlifeData = ContentDB.wildlife_kinds.get("deer", null) as WildlifeData
	_check(families != null and kind != null, "the harness needs the families and a deer")
	if families == null or kind == null:
		return
	var mother: Dictionary = animals.spawn_born(kind, near + Vector2(320.0, 0.0),
		{"sex": WildlifeFamilies.Sex.FEMALE, "stage": WildlifeFamilies.Stage.ADULT})
	var father: Dictionary = animals.spawn_born(kind, near + Vector2(360.0, 0.0),
		{"sex": WildlifeFamilies.Sex.MALE, "stage": WildlifeFamilies.Stage.ADULT})
	_check(not mother.is_empty() and not father.is_empty(), "the harness could not stand a pair")
	if mother.is_empty() or father.is_empty():
		return
	mother["litter_by"] = int(father["net_id"])
	families.births_this_act = 0
	var clutch: Array[Dictionary] = families.call("_roll_clutch", mother, kind, 2, 99, 0, false)
	_check(not clutch.is_empty() and clutch[0].has("coat"),
		"a rolled litter carries no coat")
	if clutch.is_empty():
		return
	var cub: Dictionary = animals.spawn_born(kind,
		(mother["sprite"] as Sprite2D).global_position + Vector2(30.0, 0.0), clutch[0])
	_check(not cub.is_empty(), "the harness could not place the cub")
	if cub.is_empty():
		return
	var rolled: Dictionary = clutch[0]["coat"] as Dictionary
	var inherited: Dictionary = WildlifeFamilies.cub_coat(mother, father, kind, 99, 0)
	_check(is_equal_approx(float(rolled["hue"]), float(inherited["hue"])),
		"the litter's coat is not the one its parents hand down")
	_check(is_equal_approx(float((cub["coat"] as Dictionary)["hue"]), float(rolled["hue"])),
		"the cub's record wears a different coat than it was born with")
	var material := cub.get("impact") as ShaderMaterial
	if material != null and Graphics.phenotypes():
		_check(is_equal_approx(float(material.get_shader_parameter("coat_hue")), float(rolled["hue"]))
			and is_equal_approx(float(material.get_shader_parameter("coat_light")), float(rolled["light"])),
			"the cub's material wears its serial's coat rather than the one it was born with")


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
