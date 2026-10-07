class_name WildlifeCarrion
extends RefCounted

## **A heap of the dead calls for what eats it** (owner, 2026-10-07: *"if there
## are plenty of corpses then vultures may come to eat it, as well as even larger
## more dangerous beasts"*).
##
## Every `CARRION_CHECK_SECONDS` the host finds the biggest pile of corpses with
## meat on them (`CorpseField.pile_at`). A pile of `CARRION_VULTURE_PILE` calls a
## couple of vultures down onto it, never more than `CARRION_VULTURES_MAX` at
## once; a pile of `CARRION_LORD_PILE` may, on `CARRION_LORD_CHANCE`, call **a
## carrion lord** - the region's heaviest hunting scavenger, grown to an elite -
## that comes to the heap and holds it. Both arrive through the ordinary door
## (`Wildlife._spawn`), flying or walking in from off the field to the pile, so
## everything else about an animal is true of them, and what they do there is
## `WildlifeFeeding`'s: smell, eat, quarrel.
##
## The bound is the population's: nothing here arrives past the field's cap or
## the hunters' cap, while the road is hushed, or on a guest - a guest's animals
## are the host's. A carrion lord is one at a time, from Act II.

const VULTURE_ID: String = "vulture"

var wild: Wildlife = null
var _clock: float = 0.0
## Dice of its own, so a heap calling a vulture moves no roll the arrivals or
## the families are drawn on.
var _dice := RandomNumberGenerator.new()
var _vulture_rest: float = 0.0
## The chance a big enough heap calls its lord, per look: `CARRION_LORD_CHANCE`,
## and a documented seam a gate sets to one so the lord is a certainty to test.
var lord_chance: float = Balance.CARRION_LORD_CHANCE
## How many vultures and lords this called. For the gate.
var vultures_called: int = 0
var lords_called: int = 0


func _init(owner: Wildlife) -> void:
	wild = owner
	_clock = Balance.CARRION_CHECK_SECONDS
	_dice.seed = absi(hash("carrion:%d" % RunState.run_seed))


func tick(delta: float) -> void:
	_vulture_rest = maxf(_vulture_rest - delta, 0.0)
	_clock -= delta
	if _clock > 0.0:
		return
	_clock = Balance.CARRION_CHECK_SECONDS
	consider()


## One look at the field's dead. Returns what it called: "vultures", "lord" or "".
func consider() -> String:
	if wild == null or Coop.is_guest() or wild.is_hushed():
		return ""
	var corpses: CorpseField = _corpses()
	if corpses == null or corpses.count() == 0:
		return ""
	var pile: Dictionary = biggest_pile(corpses)
	if pile.is_empty():
		return ""
	var at: Vector2 = pile["at"]
	var size: int = int(pile["count"])
	var called: String = ""
	if size >= Balance.CARRION_LORD_PILE and RunState.act >= 2 and lord_count() == 0 \
			and _dice.randf() < lord_chance:
		if _call_lord(at):
			called = "lord"
	if called.is_empty() and size >= Balance.CARRION_VULTURE_PILE and _vulture_rest <= 0.0:
		if _call_vultures(at, size):
			called = "vultures"
	return called


## The corpse with the most meat-bearing corpses within `CARRION_PILE_REACH` of
## it: `{at, count}`, or empty.
static func biggest_pile(corpses: CorpseField) -> Dictionary:
	var best: Dictionary = {}
	var best_count: int = 0
	for corpse: Dictionary in corpses.corpses():
		if float(corpse["meat"]) <= Balance.CORPSE_EATEN_FROM:
			continue
		var found: int = corpses.pile_at(corpse["at"] as Vector2, Balance.CARRION_PILE_REACH)
		if found > best_count:
			best_count = found
			best = {"at": corpse["at"], "count": found}
	return best


func vulture_count() -> int:
	var found: int = 0
	for animal: Dictionary in wild.living():
		var kind := animal.get("data", null) as WildlifeData
		if kind != null and kind.id == VULTURE_ID and float(animal.get("dying", 0.0)) <= 0.0:
			found += 1
	return found


func lord_count() -> int:
	var found: int = 0
	for animal: Dictionary in wild.living():
		if bool(animal.get("carrion_lord", false)) and float(animal.get("dying", 0.0)) <= 0.0:
			found += 1
	return found


func _call_vultures(at: Vector2, pile: int) -> bool:
	var kind: WildlifeData = ContentDB.wildlife_kinds.get(VULTURE_ID, null) as WildlifeData
	if kind == null:
		return false
	var room: int = mini(Balance.CARRION_VULTURES_MAX - vulture_count(), wild.population_cap() - wild.living().size())
	# A bigger heap draws more of them, one more a step past the threshold.
	var wanted: int = mini(room, 1 + (pile - Balance.CARRION_VULTURE_PILE) / 2)
	if wanted <= 0:
		return false
	var before: int = wild.living().size()
	for index: int in wanted:
		var near: Vector2 = at + Vector2.from_angle(_dice.randf() * TAU) * _dice.randf_range(30.0, 90.0)
		wild.call("_spawn", kind, near)
	var arrived: int = wild.living().size() - before
	if arrived > 0:
		vultures_called += arrived
		_vulture_rest = Balance.CARRION_VULTURE_REST
		for index: int in range(wild.living().size() - arrived, wild.living().size()):
			var animal: Dictionary = wild.living()[index]
			animal["goal"] = at
			animal["home"] = at
			animal["patience"] = maxf(float(animal.get("patience", 0.0)), Balance.CARRION_STAY_SECONDS)
	return arrived > 0


func _call_lord(at: Vector2) -> bool:
	var kind: WildlifeData = lord_kind()
	if kind == null:
		return false
	if wild.living().size() >= wild.population_cap() or wild.call("_hostile_count") >= Balance.WILDLIFE_HOSTILE_MAX:
		return false
	var before: int = wild.living().size()
	wild.call("_spawn", kind, at)
	if wild.living().size() <= before:
		return false
	var animal: Dictionary = wild.living()[wild.living().size() - 1]
	make_lord(animal, kind, at)
	lords_called += 1
	EventBus.preparation_warning.emit("Something large has come for the dead.")
	return true


## The heaviest hunting scavenger the act's region favours, or any act's if the
## region has none.
func lord_kind() -> WildlifeData:
	var best: WildlifeData = null
	var best_weight: float = -1.0
	for pass_index: int in 2:
		for value: Variant in ContentDB.wildlife_kinds.values():
			var kind := value as WildlifeData
			if kind == null or not kind.scavenges or not kind.is_hostile() or kind.mythic:
				continue
			if pass_index == 0 and not kind.acts.has(RunState.act):
				continue
			var heft: float = kind.max_hp * kind.scale
			if heft > best_weight:
				best_weight = heft
				best = kind
		if best != null:
			return best
	return best


## Grows a freshly arrived animal into the heap's lord: an elite's size, tint and
## pool, and the heap as its home.
static func make_lord(animal: Dictionary, kind: WildlifeData, at: Vector2) -> void:
	var sprite := animal.get("sprite", null) as Sprite2D
	animal["carrion_lord"] = true
	animal["elite"] = true
	animal["size"] = Balance.WILDLIFE_ELITE_SCALE
	animal["hp"] = kind.max_hp * Balance.WILDLIFE_ELITE_HEALTH * Balance.CARRION_LORD_HEALTH
	animal["home"] = at
	animal["goal"] = at
	animal["patience"] = maxf(float(animal.get("patience", 0.0)), Balance.CARRION_STAY_SECONDS)
	if sprite != null and is_instance_valid(sprite):
		sprite.scale = Vector2.ONE * kind.scale * Balance.WILDLIFE_ELITE_SCALE
		sprite.modulate = Balance.WILDLIFE_ELITE_TINT
	var bar := animal.get("bar", null) as ProgressBar
	if bar != null and is_instance_valid(bar):
		bar.visible = true
		bar.modulate = Balance.WILDLIFE_ELITE_TINT


func _corpses() -> CorpseField:
	var field: Node = wild.field if wild != null else null
	if field == null or not ("corpses" in field):
		return null
	return field.get("corpses") as CorpseField
