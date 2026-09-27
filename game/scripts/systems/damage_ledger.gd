class_name DamageLedger
extends RefCounted

## **Where the damage came from** (2026-09-26; `docs/SKILL_TREE_REWORK_2026-09-26.md`
## section 8.6: *"the ledger comes with it"*).
##
## Every blow on a body goes through `Enemy.take_damage`, and that funnel never
## knew who threw it - thirty places deal a blow and most of them have nothing
## to say about themselves. So the door that throws names itself just before it
## lands (`credit_as`), the funnel takes the name (`take_source`), and what the
## blow actually took off the body is written against it. A blow nobody named is
## "other", never lost.
##
## **And what each augment was worth.** A card on a damage key raises every blow
## that key multiplies, so its share of a blow is its magnitude over the whole
## bonus the key carries: `taken * c / (1 + total)`. Exact for the Warden, whose
## blows multiply that key by everything else; an estimate for a tower, whose
## bonus also holds its own path and the war horn - which only ever makes the
## estimate generous, never invented.
##
## **A look and never a fact.** Nothing reads the ledger but the debrief and the
## pause screen; turning it off moves no number in a fight.

## Who is throwing the blow about to land, or "" once the funnel has taken it.
static var _source: String = ""

const OTHER: String = "other"
const WARDEN: String = "warden"
const ARROW: String = "arrow"
const COMPANION: String = "companion"
const MOUNT: String = "mount"
const EARTH: String = "earth"
const WILDLIFE: String = "wildlife"
const BURN: String = "burn"
const SPELL: String = "spell"
const TOWER_PREFIX: String = "tower:"
const TRAP_PREFIX: String = "trap:"
const AUGMENT_PREFIX: String = "augment:"


## Names the next blow.
static func credit_as(source: String) -> void:
	_source = source


## The name of the blow landing now, taken so it cannot name the next one too.
static func take_source() -> String:
	var source: String = _source
	_source = ""
	return source if not source.is_empty() else OTHER


## **A blow took `taken` off a body.** Written against its source, and each held
## augment on the key that multiplied it is credited its share.
static func note(source: String, taken: float) -> void:
	if taken <= 0.0:
		return
	var book: Dictionary = RunState.damage_ledger
	book[source] = float(book.get(source, 0.0)) + taken
	for key: String in _keys_of(source):
		var total: float = 1.0 + maxf(Modifiers.value(key), 0.0)
		# The party's board and, in a split hand, this Warden's own cards.
		for held: String in RunState.hand_of():
			var card: RoadCardData = ContentDB.road_card(held)
			if card == null or card.effect_id != key:
				continue
			var share: float = card.magnitude_at(RunState.card_level(held)) / total
			if share <= 0.0:
				continue
			var credit: String = AUGMENT_PREFIX + held
			book[credit] = float(book.get(credit, 0.0)) + taken * share


## Every key a source's blows are multiplied by, or none for one no augment
## touches. A tower's rate is here as well as its damage: more shots is more of
## the same blow, and the share of it a faster clock bought is the rate's.
static func _keys_of(source: String) -> Array[String]:
	if source.begins_with(TOWER_PREFIX):
		return [Modifiers.TOWER_DAMAGE, Modifiers.TOWER_RATE]
	if source.begins_with(TRAP_PREFIX):
		return [Modifiers.TRAP_DAMAGE]
	if source == BURN:
		return [Modifiers.BURN_DAMAGE]
	if source == SPELL:
		return [Modifiers.HERO_DAMAGE, Modifiers.SPELL_POWER]
	if source == COMPANION:
		return [Modifiers.HERO_DAMAGE, Modifiers.COMPANION_DAMAGE]
	if source == WARDEN or source == ARROW or source == MOUNT:
		return [Modifiers.HERO_DAMAGE]
	# A weapon of the Arsenal: its hit rides the Warden's damage and the
	# Arsenal's own power (`Arsenal.hit_for`), so those cards share its blows.
	if source.begins_with(AUGMENT_PREFIX):
		return [Modifiers.HERO_DAMAGE, Modifiers.ARSENAL_POWER]
	return []


## What a source is called on a screen.
static func name_of(source: String) -> String:
	if source.begins_with(TOWER_PREFIX):
		var tower: TowerData = ContentDB.tower(source.trim_prefix(TOWER_PREFIX))
		return tower.display_name if tower != null else "A tower"
	if source.begins_with(TRAP_PREFIX):
		var trap: TrapData = ContentDB.trap(source.trim_prefix(TRAP_PREFIX))
		return trap.display_name if trap != null else "A trap"
	if source.begins_with(AUGMENT_PREFIX):
		var card: RoadCardData = ContentDB.road_card(source.trim_prefix(AUGMENT_PREFIX))
		return card.display_name if card != null else "An augment"
	match source:
		WARDEN:
			return "The Warden's blade"
		SPELL:
			return "Spells"
		ARROW:
			return "The bow"
		COMPANION:
			return "Companions"
		MOUNT:
			return "The charge"
		EARTH:
			return "The earth"
		WILDLIFE:
			return "The wild"
		BURN:
			return "Burning"
	return "Everything else"


## The ledger's lines, biggest first: the sources, then what each augment added.
## `levels` is the hand the road ended with, by card id, so the debrief names
## the level each card had grown to after the run itself is gone.
static func lines(book: Dictionary, levels: Dictionary, most: int = 8) -> PackedStringArray:
	var out: PackedStringArray = []
	var sources: Array = []
	var augments: Array = []
	var total: float = 0.0
	for key: Variant in book:
		var amount: float = float(book[key])
		if String(key).begins_with(AUGMENT_PREFIX):
			augments.append([String(key), amount])
		else:
			sources.append([String(key), amount])
			total += amount
	if total <= 0.0:
		return out
	var biggest: Callable = func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1])
	sources.sort_custom(biggest)
	augments.sort_custom(biggest)
	out.append("DAMAGE  ·  %s dealt" % _count(total))
	for index: int in mini(sources.size(), most):
		var entry: Array = sources[index]
		out.append("   %s   %s   ·   %d%%" % [name_of(String(entry[0])), _count(float(entry[1])),
			int(round(float(entry[1]) / total * 100.0))])
	for entry: Array in augments:
		var card_id: String = String(entry[0]).trim_prefix(AUGMENT_PREFIX)
		var level: int = maxi(int(levels.get(card_id, 1)), 1)
		out.append("   + %s %s   %s of it" % [name_of(String(entry[0])),
			RunState.act_numeral(level), _count(float(entry[1]))])
	return out


## One line for the pause screen: the biggest few sources and their shares.
static func brief(book: Dictionary, most: int = 3) -> String:
	var sources: Array = []
	var total: float = 0.0
	for key: Variant in book:
		if String(key).begins_with(AUGMENT_PREFIX):
			continue
		sources.append([String(key), float(book[key])])
		total += float(book[key])
	if total <= 0.0:
		return ""
	sources.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
	var parts: PackedStringArray = []
	for index: int in mini(sources.size(), most):
		var entry: Array = sources[index]
		parts.append("%s %d%%" % [name_of(String(entry[0])),
			int(round(float(entry[1]) / total * 100.0))])
	return "Damage so far: " + "  ·  ".join(parts)


static func _count(amount: float) -> String:
	if amount >= 1000000.0:
		return "%.1fM" % (amount / 1000000.0)
	if amount >= 10000.0:
		return "%dk" % int(round(amount / 1000.0))
	return "%d" % int(round(amount))
