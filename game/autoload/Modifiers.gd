extends Node

## Resolves every relic and boss core into a flat table of modifiers (GDD §5).
##
## Relics only act while socketed in the Town Hall; boss cores are permanent and
## unsocketed. Both end up here, so nothing downstream has to know the
## difference — a tower asks for `TOWER_DAMAGE` and gets a number.
##
## Rebuilt on socket changes rather than recomputed per call: this is read
## inside tower fire loops, and walking the relic list per shot would be the
## most-executed code in the game for no reason.

# Effect keys. These are the strings relic `.tres` files use in `effect_id`.
const TOWER_DAMAGE: String = "tower_damage"
const TOWER_RANGE: String = "tower_range"
const TOWER_ARMOUR: String = "tower_armour"
const CHAIN_TARGETS: String = "chain_targets"
const BURN_DAMAGE: String = "burn_damage"
const SLOW_STRENGTH: String = "slow_strength"
const KNOCKBACK: String = "knockback"

const HERO_DAMAGE: String = "hero_damage"
const HERO_SPEED: String = "hero_speed"
const HERO_MAX_HP: String = "hero_max_hp"
const DASH_COOLDOWN: String = "dash_cooldown"

const TOWN_MAX_HP: String = "town_max_hp"
const RESOURCE_RATE: String = "resource_rate"
const KILL_RESOURCES: String = "kill_resources"
const CAPTIVE_OUTPUT: String = "captive_output"
const BUILD_COST: String = "build_cost"
const BEAST_SPEED: String = "beast_speed"
const RAID_CHARGE: String = "raid_charge"
const ENEMY_DAMAGE: String = "enemy_damage"
const WAVE_FORESIGHT: String = "wave_foresight"

var _totals: Dictionary = {}
var _base_totals: Dictionary = {}


func _ready() -> void:
	EventBus.stash_changed.connect(rebuild)
	EventBus.relic_socketed.connect(_on_relics_changed)
	EventBus.relic_unsocketed.connect(_on_relics_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.run_started.connect(rebuild)
	rebuild()


## Summed magnitude for an effect. 0.0 when nothing grants it.
## Every key this table has a constant for.
##
## Derived from the constants rather than kept as a second list, because a
## hand-kept mirror of a set of constants is a mirror that drifts - which is
## exactly how a misspelt effect key reaches disk and pays nothing. Used by the
## gates that refuse an omen, a card, an affix or a set tier naming a key
## nothing reads.
func keys_in_use() -> PackedStringArray:
	var out: PackedStringArray = []
	for name: Variant in (get_script() as Script).get_script_constant_map():
		var value: Variant = (get_script() as Script).get_script_constant_map()[name]
		if value is String and not String(value).is_empty():
			out.append(String(value))
	return out


func value(effect_id: String) -> float:
	return float(_totals.get(effect_id, 0.0))


func base_value(effect_id: String) -> float:
	return float(_base_totals.get(effect_id, 0.0))


## Convenience for the common "1.0 + bonus" multiplier shape.
func multiplier(effect_id: String) -> float:
	return 1.0 + value(effect_id)


func has(effect_id: String) -> bool:
	return _totals.has(effect_id)


func rebuild() -> void:
	_totals.clear()
	_base_totals.clear()
	# Socketed relics act; held ones do not. That is the entire point of the
	# Town Hall (GDD §5).
	for relic_id: String in RunState.socketed_relics:
		_add(ContentDB.relics.get(relic_id, null) as RelicData)
	for core_id: String in RunState.boss_cores:
		_add(ContentDB.relics.get(core_id, null) as RelicData)
	# Omens land in the same table as relics and for the same reason: a tower
	# asks for `TOWER_DAMAGE` and gets a number, and nothing downstream has to
	# learn that a third source of modifiers now exists.
	for omen_id: String in RunState.taken_omens:
		_add_omen(ContentDB.omens.get(omen_id, null) as OmenData)
	# And the hand, into the same table for the same reason.
	for card_id: String in RunState.road_cards:
		_add_card(ContentDB.road_cards.get(card_id, null) as RoadCardData)
	# And what the Warden wears. A legendary affix is a relic the player found
	# on a sword rather than in a boss's chest, and it lands where a relic
	# lands - so a tower asking for `tower_damage` gets one number.
	for slot: Variant in MetaState.equipped:
		var piece: Dictionary = MetaState.equipped_piece(int(slot))
		if piece.is_empty():
			continue
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		for affix: GearAffixData in Stash.legendary_affixes(piece, kind):
			if affix.effect_id.is_empty():
				continue
			_totals[affix.effect_id] = float(_totals.get(affix.effect_id, 0.0)) + affix.magnitude
	# And what matches. A set tier is a relic the player assembled rather than
	# found, and it lands where a relic lands - so nothing downstream learns that
	# sets exist either.
	_add_matched_sets()
	# **And how far the party has pushed without banking.** Discovery only: see
	# `Balance.MOMENTUM_PER_CROSSROAD` for why momentum may never reach a damage
	# number. It is the one modifier here bought by refusing to save.
	_add_momentum()
	_base_totals = _totals.duplicate()
	_apply_regional_adapters()


## **What the Warden is wearing enough of.**
##
## Counted by *kind* across the worn slots, so a piece of any rarity or level
## counts toward its set - the thing to hunt is the match, which the road can
## actually give you, rather than a second lottery on top of the drop tables.
func _add_matched_sets() -> void:
	var worn: Dictionary = {}
	for slot: Variant in MetaState.equipped:
		var piece: Dictionary = MetaState.equipped_piece(int(slot))
		if piece.is_empty():
			continue
		var kind_id: String = String(piece.get("kind", ""))
		var set_data: GearSetData = ContentDB.gear_set_of(kind_id)
		if set_data == null:
			continue
		# By kind rather than by count of pieces: two of the same ring is one
		# member of the set, not two, and slots make that impossible anyway -
		# but a set that counted pieces would be wrong the day they do not.
		var seen: Dictionary = worn.get(set_data.id, {}) as Dictionary
		seen[kind_id] = true
		worn[set_data.id] = seen
	for set_id: Variant in worn:
		var set_data: GearSetData = ContentDB.gear_sets.get(String(set_id), null) as GearSetData
		if set_data == null:
			continue
		var count: int = (worn[set_id] as Dictionary).size()
		for tier: int in set_data.tiers_at(count):
			var key: String = set_data.tier_effects[tier]
			if key.is_empty():
				continue
			_totals[key] = float(_totals.get(key, 0.0)) \
				+ set_data.tier_magnitudes[tier]


## How many pieces of this set are worn right now. For the screens and the gate.
func set_pieces_worn(set_id: String) -> int:
	var set_data: GearSetData = ContentDB.gear_sets.get(set_id, null) as GearSetData
	if set_data == null:
		return 0
	var kinds: Dictionary = {}
	for slot: Variant in MetaState.equipped:
		var piece: Dictionary = MetaState.equipped_piece(int(slot))
		if piece.is_empty():
			continue
		var kind_id: String = String(piece.get("kind", ""))
		if set_data.has_member(kind_id):
			kinds[kind_id] = true
	return kinds.size()


## The set the Warden is wearing in full, if any. One at a time: two full sets
## would need sixteen slots and the hero has eight.
func completed_set() -> GearSetData:
	for one: GearSetData in ContentDB.gear_sets_sorted():
		if one.members.is_empty():
			continue
		if set_pieces_worn(one.id) >= one.members.size():
			return one
	return null


## **Expedition Momentum**, and the two keys it is allowed to touch.
##
## Pressing past a crossroads without extracting pays a little more of what the
## road is hiding - resources off bodies, and one more wave read ahead. It does
## **not** touch `hero_damage`, `tower_damage` or anything else that decides a
## fight: a damage stack bought by refusing to save is a power scale nobody is
## tuning, and `curve_report` would be measuring a game that only exists for
## players who never bank.
func _add_momentum() -> void:
	if RunState.momentum <= 0.0:
		return
	var push: float = clampf(RunState.momentum, 0.0, Balance.MOMENTUM_MAX)
	_totals[KILL_RESOURCES] = float(_totals.get(KILL_RESOURCES, 0.0)) + push
	_totals[RESOURCE_RATE] = float(_totals.get(RESOURCE_RATE, 0.0)) + push * 0.5


func _add(relic: RelicData) -> void:
	if relic == null or relic.effect_id.is_empty():
		return
	_totals[relic.effect_id] = float(_totals.get(relic.effect_id, 0.0)) + relic.effect_magnitude


## One Road Card. No halves: a card's price is the hand slot it occupies.
func _add_card(card: RoadCardData) -> void:
	if card == null or card.effect_id.is_empty():
		return
	_totals[card.effect_id] = float(_totals.get(card.effect_id, 0.0)) \
		+ card.effect_magnitude


## Both halves of a portent, cost first.
##
## An omen with only one half authored is still added: the missing side simply
## does nothing. `omen_check` is what refuses that, because a card promising a
## price and charging none is a free upgrade in a costume.
func _add_omen(omen: OmenData) -> void:
	if omen == null:
		return
	if not omen.bane_effect.is_empty():
		_totals[omen.bane_effect] = float(_totals.get(omen.bane_effect, 0.0)) \
			+ omen.bane_magnitude
	if not omen.boon_effect.is_empty():
		_totals[omen.boon_effect] = float(_totals.get(omen.boon_effect, 0.0)) \
			+ omen.boon_magnitude


## Every regional socket adds a bounded situational rule. Verdant stabilizes a
## damaged town, Sunglass rewards wounded mobility, and Rimebound converts act
## wounds into control. The rule keys off region data, never individual ids.
func _apply_regional_adapters() -> void:
	for relic_id: String in RunState.socketed_relics:
		var relic := ContentDB.relics.get(relic_id, null) as RelicData
		if relic == null:
			continue
		match relic.region:
			1:
				if RunState.town_hp < RunState.town_max_hp * 0.70:
					_totals[TOWER_DAMAGE] = float(_totals.get(TOWER_DAMAGE, 0.0)) + 0.04
			2:
				if RunState.hero_hp > 0.0 and RunState.hero_hp < Balance.HERO_MAX_HP * 0.50:
					_totals[HERO_SPEED] = float(_totals.get(HERO_SPEED, 0.0)) + 0.025
			3:
				if RunState.hero_wounds > 0:
					_totals[SLOW_STRENGTH] = float(_totals.get(SLOW_STRENGTH, 0.0)) + 0.025


func _on_relics_changed(_relic_id: String) -> void:
	rebuild()


func _on_boss_defeated(_boss_id: String, _act: int) -> void:
	rebuild()
