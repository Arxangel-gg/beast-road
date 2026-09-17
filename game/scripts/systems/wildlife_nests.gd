class_name WildlifeNests
extends Node2D

## What the egg-laying half of the roster does instead of giving birth.
##
## **Owner brief, 2026-09-15** (forwarded essay on egg and nesting ecology). The
## road already raises families - a pair courts, an appraisal decides, and a cub
## is placed beside its mother (2026-09-14). That is right for a wolf and wrong
## for a crane: half this roster is birds, reptiles and insects, and what they
## do is *leave something behind and come back to it*.
##
## So a laying species lays a **nest**. The clutch is rolled exactly as a litter
## is - the same inheritance, the same shiny rules, the same act budget - and
## then it sits on the ground and hatches by **road walked**, never by the
## clock, for the same reason a crop does: a beast standing still hatches
## nothing, and a nest is not a thing to farm by waiting.
##
## **And it can be robbed.** `IDEAS_REVIEW_2026-09-15` triaged the forwarded
## proposal's best beat - steal the egg and be hunted all the way out - and
## concluded that this game's translation of it is the homecoming pass rather
## than an extraction. This is the smaller, honest version of that: take an egg
## and the parents come for you, for the rest of the act, wherever you go.
##
## **Three bounds, and every one of them is the bound something else here is
## already held to.**
##
## - **An egg is never a power scale.** It pays Food, which is a run currency,
##   and it credits the *sighting* of that variant, which is the same credit a
##   birth already pays (collection, never accumulation - the 2026-09-01 rule).
##   It grants no attribute, no bond and no gear.
## - **An angered parent's bite is its own.** A species with no bite is lent one
##   the way the Wildblight lends one, and nothing here multiplies damage: a
##   robbed crane is a crane that has decided to fight you.
## - **Nothing persists.** A nest is the run's, like a plot and a trail.

## One nest: where it is, whose it is, what is in it, and how much road is left
## before it opens.
var _nests: Array[Dictionary] = []

var grid: BattleGrid = null
var animals: Wildlife = null
var families: WildlifeFamilies = null

## Which species has been robbed this act, and is therefore hunting.
var _robbed: Dictionary = {}

var _walked: float = 0.0
var _near: int = -1
var _prompt: String = ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	z_as_relative = false
	_rng.randomize()
	_walked = RunState.distance_travelled
	# **A guest draws; it decides nothing.** Where a clutch is laid is the
	# host's call, because a birth is - so a nest crosses as a fact and what it
	# becomes arrives later as an ordinary birth. Both are already facts the
	# guest knows how to apply, so no second application path exists to drift.
	EventBus.coop_wildlife_nested.connect(_on_told_nested)
	EventBus.coop_wildlife_robbed.connect(_on_told_robbed)
	set_process(true)


## Lay a clutch where a birth would have been placed.
##
## Called by `WildlifeFamilies` in place of `_give_birth` for a laying species,
## with the clutch it had already rolled - so the inheritance, the shine and the
## act's budget are decided in exactly one place and an egg cannot be a second
## route to a rarer animal.
func lay(kind: WildlifeData, at: Vector2, clutch: Array[Dictionary],
		family: int) -> void:
	if kind == null or clutch.is_empty():
		return
	var art: Texture2D = _art("res://art/battlefield/nest.png")
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.global_position = at
	sprite.z_as_relative = false
	sprite.scale = Vector2.ONE * Balance.NEST_SCALE
	add_child(sprite)
	_nests.append({
		"kind": kind,
		"at": at,
		"clutch": clutch,
		"family": family,
		"sprite": sprite,
		# By road, not by clock. A beast that stops walking hatches nothing.
		"left": kind.incubation_distance if kind.incubation_distance > 0.0 \
			else Balance.NEST_INCUBATION_DISTANCE,
	})
	_dress(_nests[_nests.size() - 1])
	# **The sound of a clutch being laid**, which had been recorded, registered
	# and mixed and played by nobody since the ecology was built.
	Sfx.play_group_at("sfx_wildlife_nest_lay", at)
	EventBus.wildlife_nested.emit(kind.id, clutch.size(), at)
	if not Coop.is_guest():
		EventBus.coop_wildlife_nested.emit(kind.id, clutch.size(), at)


func _process(_delta: float) -> void:
	# The road, measured rather than counted: `distance_travelled` only ever
	# rises and stops while the beast does, which is the whole mechanic.
	var now: float = RunState.distance_travelled
	var road: float = maxf(now - _walked, 0.0)
	_walked = now
	if road > 0.0:
		_incubate(road)
	_tick_prompt()


## Every nest ages by the road the party walked, and opens at the end of it.
func _incubate(road: float) -> void:
	for index: int in range(_nests.size() - 1, -1, -1):
		var nest: Dictionary = _nests[index]
		nest["left"] = float(nest["left"]) - road
		if float(nest["left"]) > 0.0:
			continue
		_hatch(index)


## The clutch becomes animals, through the same door a litter does.
func _hatch(index: int) -> void:
	var nest: Dictionary = _nests[index]
	var kind := nest["kind"] as WildlifeData
	var at: Vector2 = nest["at"]
	if families != null and kind != null and not Coop.is_guest():
		families.hatch(kind, at, nest["clutch"] as Array[Dictionary],
			int(nest["family"]))
	# The clutch opening, which is the third of the ecology's own recordings
	# that had never been played.
	Sfx.play_group_at("sfx_wildlife_egg_hatch", at)
	_empty(nest)
	_nests.remove_at(index)


## The eggs themselves, one sprite each, on top of the nest they are in.
##
## **Rebuilt rather than reduced.** A clutch is at most a handful, so freeing
## the lot and laying them again is cheaper to read than tracking which sprite
## belonged to which egg - and it is the only version that cannot drift out of
## step with the clutch after a hatch, a theft and a guest's relayed count.
##
## Owner, 2026-09-17: *"taking an egg from a nest does not update the nest's
## visuals to show until the nest is empty"*. It does now, one egg at a time.
func _dress(nest: Dictionary) -> void:
	var sprite := nest.get("sprite") as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	for old_egg: Node in sprite.get_children():
		old_egg.queue_free()
	var art: Texture2D = _art("res://art/battlefield/nest_egg.png")
	if art == null:
		return
	var clutch: Array = nest.get("clutch", []) as Array
	var kind := nest.get("kind") as WildlifeData
	# The cluster is the nest's own arrangement rather than a roll: the same
	# nest looks the same on both machines and after a reload, and nothing here
	# touches the run's stream (`decoration-needs-its-own-rng-stream`).
	var seed_at: int = absi(hash(str(nest.get("at", Vector2.ZERO))))
	for index: int in clutch.size():
		var egg := Sprite2D.new()
		egg.texture = art
		egg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		egg.scale = Vector2.ONE * Balance.NEST_EGG_SCALE
		var spin: float = float((seed_at >> (index * 3)) % 360) * 0.0174533
		egg.position = Vector2(cos(spin) * Balance.NEST_EGG_SPREAD.x,
			sin(spin) * Balance.NEST_EGG_SPREAD.y - Balance.NEST_EGG_LIFT)
		# Later eggs sit a hair in front, so a cluster reads as a pile rather
		# than as sprites at one depth.
		egg.z_index = index
		egg.rotation = sin(spin * 1.7) * 0.22
		egg.modulate = _egg_tint(clutch[index] as Dictionary, kind)
		sprite.add_child(egg)


## What colour an egg is: its own shell, tinted a little toward the rarity of
## what is inside it and lifted if it is going to hatch a shiny.
func _egg_tint(egg: Dictionary, kind: WildlifeData) -> Color:
	var rank: int = int(egg.get("rarity", kind.rarity if kind != null else 0))
	var colours: Array[Color] = Balance.RANK_SHEEN_RARITY_COLOURS
	if colours.is_empty():
		return Color.WHITE
	var tone: Color = colours[clampi(rank, 0, colours.size() - 1)]
	var ink: Color = Color.WHITE.lerp(tone, Balance.NEST_EGG_RARITY_TINT)
	if bool(egg.get("shiny", false)):
		ink = ink.lightened(0.22)
	return ink


## The nest stays on the ground, emptied. A hatched nest and a robbed one look
## the same afterwards, which is correct: what is gone is gone.
func _empty(nest: Dictionary) -> void:
	var sprite := nest.get("sprite") as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	# The eggs go with the clutch, so the spent painting is not wearing the
	# eggs that are no longer in it while it fades.
	for egg: Node in sprite.get_children():
		egg.queue_free()
	var spent: Texture2D = _art("res://art/battlefield/nest_empty.png")
	if spent != null:
		sprite.texture = spent
	var fade := create_tween()
	fade.tween_property(sprite, "modulate:a", 0.0, Balance.NEST_SPENT_SECONDS)
	fade.tween_callback(sprite.queue_free)


## The prompt, and the theft.
func _tick_prompt() -> void:
	var who: Node2D = _local_hero()
	if who == null:
		_near = -1
		_say("", "")
		return
	_near = _nest_near(who.global_position)
	if _near < 0:
		_say("", "")
		return
	var nest: Dictionary = _nests[_near]
	var kind := nest["kind"] as WildlifeData
	var left: int = (nest["clutch"] as Array).size()
	_say("Take an egg  ·  %s  ·  %d in the nest" % [kind.display_name, left],
		"TAKE")
	var source := who.get("input") as HeroInput
	if source != null and source.pressed(HeroInput.BUTTON_INTERACT):
		_rob(_near, who)


func _nest_near(at: Vector2) -> int:
	for index: int in _nests.size():
		if at.distance_to(_nests[index]["at"] as Vector2) <= Balance.NEST_REACH:
			return index
	return -1


## One egg taken: Food, a sighting, and a species that now has a reason.
func _rob(index: int, who: Node2D) -> void:
	if index < 0 or index >= _nests.size():
		return
	var nest: Dictionary = _nests[index]
	var kind := nest["kind"] as WildlifeData
	var clutch: Array = nest["clutch"]
	if clutch.is_empty() or kind == null:
		return
	var egg: Dictionary = clutch.pop_back()
	# **Food, which is a run currency, and a sighting, which is the credit a
	# birth already pays.** Nothing here grants an attribute or a bond: an egg
	# is worth a meal and the knowledge that the variant exists.
	#
	# **A guest asks rather than pays.** The Food is the run's and the run is
	# the host's; the request names the species so the host reads the amount off
	# its own content, which is the rule the fish and the crop are asked under.
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.TAKE_EGG, [kind.id])
	else:
		RunState.gain_currency(RunState.FOOD,
			_rng.randi_range(kind.food_min, kind.food_max))
	# The same door a sighting goes through, so an egg credits the collection
	# exactly as meeting the animal would and never more.
	MetaState.record_spirit_encounter(kind.id,
		int(egg.get("rarity", kind.rarity)), bool(egg.get("shiny", false)), "")
	Vfx.spark(nest["at"] as Vector2, Color(0.95, 0.92, 0.80), 8, Vector2.UP, 140.0)
	# **The nest shows what is left in it.** One egg leaving a clutch of four
	# used to change nothing on screen until the last one went.
	_dress(nest)
	# Its own recording rather than the interface's confirm chime: taking an
	# egg happens out on the road, at a place, and `sfx_wildlife_egg_take` had
	# been sitting registered and unplayed since it was made.
	Sfx.play_group_at("sfx_wildlife_egg_take", nest["at"] as Vector2)
	RunState.note_kept("eggs", 1.0)
	# **And it goes in the pack.** An egg that reaches home bonds its variant
	# outright; a run that falls loses it. That is the proposal's steal-and-be-
	# hunted beat in this game's grammar - the price is the road home rather
	# than a sprint to an extraction point.
	if not RunState.carry_egg(kind.id, int(egg.get("rarity", kind.rarity)),
			bool(egg.get("shiny", false))):
		EventBus.sky_warned.emit(
			"There is no room left in the pack for another egg.", "Full")
	# **And the parents come for you.** Not a number: the species decides to
	# fight, for the rest of the act, and its own bite is what it fights with.
	_robbed[kind.id] = true
	EventBus.wildlife_robbed.emit(kind.id, nest["at"] as Vector2)
	if animals != null:
		animals.rouse_species(kind.id, who.global_position)
	if not Coop.is_guest():
		EventBus.coop_wildlife_robbed.emit(kind.id, nest["at"] as Vector2,
			clutch.size())
	if clutch.is_empty():
		_empty(nest)
		_nests.remove_at(index)
		_near = -1



## A clutch the host laid, drawn here.
##
## The guest's nest carries a *count* and nothing else: what the eggs become is
## the host's decision and arrives as an ordinary birth, so a guest that rolled
## its own clutch would be a second opinion nobody asked for.
func _on_told_nested(kind_id: String, eggs: int, at: Vector2) -> void:
	if not Coop.is_guest():
		return
	var kind := ContentDB.wildlife_kinds.get(kind_id, null) as WildlifeData
	if kind == null or eggs <= 0:
		return
	var clutch: Array[Dictionary] = []
	for _egg: int in eggs:
		clutch.append({})
	lay(kind, at, clutch, 0)


## An egg was taken somewhere, said by the host. Everyone updates the nest and
## everyone's copy of that species decides to fight.
func _on_told_robbed(kind_id: String, at: Vector2, left: int) -> void:
	if not Coop.is_guest():
		return
	_robbed[kind_id] = true
	if animals != null:
		animals.rouse_species(kind_id, at)
	for index: int in range(_nests.size() - 1, -1, -1):
		var nest: Dictionary = _nests[index]
		if (nest["kind"] as WildlifeData).id != kind_id:
			continue
		if (nest["at"] as Vector2).distance_to(at) > Balance.NEST_REACH:
			continue
		var clutch: Array = nest["clutch"]
		while clutch.size() > left:
			clutch.pop_back()
		if clutch.is_empty():
			_empty(nest)
			_nests.remove_at(index)
		return


## Whether this species is hunting the party because its nest was robbed.
##
## Read by `Wildlife` beside `is_hostile` and the frenzy, which is the same
## door: three reasons an animal comes at you, one place that asks.
func is_angry(species_id: String) -> bool:
	return _robbed.has(species_id)


## A new act forgives. A grudge that outlived the region it was earned in would
## be a difficulty setting the player picked up by accident in Act I.
func forget() -> void:
	_robbed.clear()


## Clear every nest, for a re-lay.
func wipe() -> void:
	for nest: Dictionary in _nests:
		var sprite := nest.get("sprite") as Node
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_nests.clear()
	_near = -1
	_say("", "")


## What is on the ground, for the map and the gate.
func report() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for nest: Dictionary in _nests:
		out.append({
			"at": nest["at"] as Vector2,
			"species": (nest["kind"] as WildlifeData).id,
			"eggs": (nest["clutch"] as Array).size(),
			"left": float(nest["left"]),
		})
	return out


## Walk the road by hand. For the gate, which has no beast.
func walk(distance: float) -> void:
	_incubate(distance)


func _local_hero() -> Node2D:
	var field := get_parent() as Battlefield
	if field == null:
		return null
	return field.hero


## The name this system speaks on the shared prompt line under.
const PROMPT_OWNER: StringName = &"nests"


func _say(text: String, button: String) -> void:
	# Deduped only while this system still holds the shared prompt line - see
	# `EventBus.claim_prompt`.
	if text == _prompt and EventBus.prompt_owner() == PROMPT_OWNER:
		return
	if not EventBus.claim_prompt(PROMPT_OWNER, text):
		return
	_prompt = text
	EventBus.interact_prompt.emit(text, button)


func _art(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null
