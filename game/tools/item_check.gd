extends Node

## Carried consumables are content, not code.
##
## `ItemData`'s header promised that "a second consumable is a new file rather
## than another branch", and for as long as it said so it was untrue: the
## Draught's entire behaviour was `RunState.has_resurrection_draught`, a bool,
## taken by `if item_id == "resurrection_draught"` and drawn by a single
## hardcoded HUD icon. That is the `if enemy_name == "bogkin"` shape working
## rule 3 forbids, and it meant the second item could never be authored — only
## implemented.
##
## This gate holds the promise to its word.
##
## **The important one is the last.** `ItemData.Effect` is a roadmap: it names
## effects the dispatch is shaped for before anything consumes them. That is
## useful and it is also a trap, because a designer can author an item with an
## effect nothing reads, ship it, and discover it does nothing only when a player
## drinks it in Act III. So the wired set is written down here, and authoring
## outside it fails loudly at build time rather than quietly in someone's run.
##
## Adding a new effect is therefore two steps that cannot be done half-way: wire
## it where the game asks, then add it to `WIRED` below.

## The effects something in the game actually consumes today.
##
## REVIVE is read by `Hero._on_died`, which asks for it *by effect* and never
## learns what a Draught is. MEND and WARD are read by `Hero.use_carried_item`,
## behind the `use_item` action and the phone's USE button.
##
## A PURGE arm was written and removed before it shipped: the hero carries no
## statuses, so an item bearing it would have been authorable, takeable, drawn
## in the HUD, and completely inert. That is the exact failure this list exists
## to make impossible.
const WIRED: Array[int] = [
	ItemData.Effect.REVIVE,
	ItemData.Effect.MEND,
	ItemData.Effect.WARD,
]

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	RunState.reset()
	_test_the_roster_is_reachable()
	_test_carry_limits_hold()
	_test_effects_are_asked_for_by_effect()
	_test_every_authored_effect_is_wired()
	_finish()


func _test_the_roster_is_reachable() -> void:
	_check(not ContentDB.items.is_empty(), "there must be at least one consumable")
	for value: Variant in ContentDB.items.values():
		var kind := value as ItemData
		if kind == null:
			continue
		_check(not kind.display_name.is_empty(),
			"%s needs a name; it is drawn in a tooltip" % kind.id)
		_check(not kind.acquire_line.is_empty(),
			"%s needs an acquire line; taking one silently reads as nothing "
				% kind.id + "having happened")
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no icon at %s, so the HUD would draw a blank"
				% [kind.id, kind.get_sprite_path()])
		# An item no reward can produce is unreachable content. The Draught's own
		# odds live on the resource precisely so this can be asked generically.
		_check(kind.raid_clear_chance > 0.0,
			"%s can never be obtained: nothing rolls for it" % kind.id)
	# Counted here rather than on entry. A runtime error aborts the function it
	# happens in, so a counter incremented at the top marks a test that never
	# ran as having run - which is how spirit_check printed PASS while an
	# Invalid call skipped every assertion below it.
	_ran += 1


## The holding, and the limit on it. Asked through the generic API so a second
## consumable inherits the behaviour rather than reimplementing it.
func _test_carry_limits_hold() -> void:
	RunState.held_items.clear()
	for value: Variant in ContentDB.items.values():
		var kind := value as ItemData
		if kind == null:
			continue
		var limit: int = maxi(kind.carry_limit, 1)
		var taken: int = 0
		# One past the limit, so the refusal is exercised rather than assumed.
		for _attempt: int in limit + 3:
			if RunState.take_item(kind.id):
				taken += 1
		_check(taken == limit,
			"%s has a carry limit of %d but %d were accepted"
				% [kind.id, limit, taken])
		_check(RunState.item_count(kind.id) == limit,
			"%s should be held %d times, is held %d"
				% [kind.id, limit, RunState.item_count(kind.id)])
		# And spending returns every one of them, leaving nothing behind.
		for _spend: int in limit:
			_check(RunState.spend_item(kind.id), "%s should be spendable" % kind.id)
		_check(RunState.item_count(kind.id) == 0,
			"%s should be gone once spent" % kind.id)
		_check(not RunState.spend_item(kind.id),
			"spending %s that is not held must fail rather than going negative"
				% kind.id)
	RunState.held_items.clear()
	_ran += 1


## The lookup the hero actually uses: by effect, never by id.
func _test_effects_are_asked_for_by_effect() -> void:
	RunState.held_items.clear()
	_check(RunState.item_with_effect(ItemData.Effect.REVIVE) == null,
		"holding nothing must find nothing")
	var revive: ItemData = null
	for value: Variant in ContentDB.items.values():
		var kind := value as ItemData
		if kind != null and kind.effect == ItemData.Effect.REVIVE:
			revive = kind
			break
	_check(revive != null, "something in the roster must stop a death")
	if revive == null:
		return
	RunState.take_item(revive.id)
	var found: ItemData = RunState.item_with_effect(ItemData.Effect.REVIVE)
	_check(found != null and found.id == revive.id,
		"a held revive must be findable by its effect rather than by its id")
	# The automatic filter is what separates an insurance policy from a button.
	var automatic: ItemData = RunState.item_with_effect(ItemData.Effect.REVIVE, true)
	_check(automatic != null, "%s is automatic and must be found as one" % revive.id)
	RunState.held_items.clear()
	_ran += 1


func _test_every_authored_effect_is_wired() -> void:
	for value: Variant in ContentDB.items.values():
		var kind := value as ItemData
		if kind == null:
			continue
		_check(WIRED.has(int(kind.effect)),
			("%s carries effect %d, which nothing in the game reads. It would be "
				+ "taken, drawn in the HUD, and do nothing. Wire it where the "
				+ "game asks, then add it to item_check.WIRED.")
				% [kind.id, int(kind.effect)])
	_ran += 1


func _finish() -> void:
	if _ran != 4:
		_failures += 1
		print("[items] only %d of 4 tests ran" % _ran)
	if _failures == 0:
		print("[items] PASS - consumables are content: reachable, carry-limited, "
			+ "asked for by effect, and none authored against an unwired one")
	else:
		push_error("[items] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[items] %s" % why)
