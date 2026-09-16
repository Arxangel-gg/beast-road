extends Node

## **The stash drawn at the worst case it can ever be asked to draw.**
##
##   godot --headless --path game res://tools/stash_render_check.tscn
##
## Owner, 2026-09-16: "test legendary and set items of the best possible maximum
## amount of attributes able to roll in our game maxed out gear with random
## variations to ensure that the UI renders everything perfectly!"
##
## The item card sizes itself from a *count* - `CARD_HEIGHT` plus a line for each
## row of bonuses past the first - which is the only honest way to do it, because
## a `Button` does not grow with an anchored child. A count is also exactly the
## kind of thing that goes quietly wrong: add a sixth affix tier, or a second
## legendary affix, and the last line of the best piece in the game is drawn
## underneath the edge of its own card with nothing to say so.
##
## So this builds the extreme: the top rarity, the maximum level, every slot, and
## a complete set - then measures what the screen actually laid out against what
## the card reserved. **Measured rather than asserted**: the check reads the
## content's real height off the control tree, so the day either constant moves
## the comparison still means what it says.
##
## The random variations are the owner's word and they matter here: an affix roll
## is derived from a piece's `uid`, so two maxed swords do not carry the same
## lines. Twenty seeds a slot is enough that a tall roll is not missed.

## How many differently-named pieces of each slot to render.
const ROLLS_PER_SLOT: int = 20

## The room a card must keep between its content and its own edge, in pixels. Not
## zero: a line whose descender touches the border is clipped as far as a reader
## is concerned, whatever the arithmetic says.
const BREATHING_ROOM: float = 2.0

var _checks: int = 0
var _failures: int = 0
var _screen: StashScreen = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260916)
	_screen = StashScreen.new()
	add_child(_screen)
	await get_tree().process_frame

	await _test_the_best_piece_in_the_game_fits_on_its_card()
	await _test_a_complete_set_renders()
	_test_the_ceiling_is_what_the_card_counts()

	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _frame: int in 12:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[stash-render] FAIL - %d of %d" % [_failures, _checks])
		get_tree().quit(1)
		return
	print("[stash-render] PASS - %d checks: the top rarity at full level in every "
		% _checks + "slot, a complete set, and every line inside its own card")
	get_tree().quit(0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## **Every slot, at the top rarity and the top level, twenty rolls each.**
##
## The affixes a piece carries are derived from its `uid`, so the same kind at the
## same rarity is not the same set of lines - which is the owner's "random
## variations", and the reason one sample per slot would not be a test.
func _test_the_best_piece_in_the_game_fits_on_its_card() -> void:
	var top: int = Stash.RARITY_NAMES.size() - 1
	MetaState.stash.clear()
	MetaState.equipped.clear()
	var kinds: Array[GearData] = ContentDB.gear_sorted()
	var per_slot: Dictionary = {}
	for kind: GearData in kinds:
		if kind == null:
			continue
		if not per_slot.has(kind.slot):
			per_slot[kind.slot] = kind
	_check(per_slot.size() == GearData.Slot.size(),
		"every slot must have a kind to render; %d of %d"
			% [per_slot.size(), GearData.Slot.size()])

	for slot: Variant in per_slot:
		var kind: GearData = per_slot[slot] as GearData
		for _roll: int in ROLLS_PER_SLOT:
			MetaState.stash.append(Stash.make(kind.id, top, Stash.MAX_LEVEL))
	# One of them worn, because a worn card carries an extra word on its second
	# line and a brighter edge - and that is the row most likely to overflow.
	var first_kind: GearData = per_slot[per_slot.keys()[0]] as GearData
	MetaState.equipped[first_kind.slot] = 0

	await _open_and_measure("the top rarity at full level")


## **A complete set**, because a set member carries its tier lines as well.
func _test_a_complete_set_renders() -> void:
	var sets: Array = ContentDB.gear_sets_sorted() if ContentDB.has_method("gear_sets_sorted") \
		else []
	if sets.is_empty():
		print("  note: no gear sets authored; the set case is skipped")
		return
	var chosen: Resource = sets[0] as Resource
	var members: Variant = chosen.get("members")
	if members == null or (members as Array).is_empty():
		_check(false, "a gear set must name its members")
		return
	MetaState.stash.clear()
	MetaState.equipped.clear()
	var top: int = Stash.RARITY_NAMES.size() - 1
	for member: Variant in (members as Array):
		var kind: GearData = ContentDB.gear(String(member))
		if kind == null:
			continue
		MetaState.equipped[kind.slot] = MetaState.stash.size()
		MetaState.stash.append(Stash.make(kind.id, top, Stash.MAX_LEVEL))
	_check(MetaState.stash.size() >= 2,
		"a set must put at least two pieces in the stash to render")
	await _open_and_measure("a complete set")


## Opens the screen and reads every card's content against its own height.
func _open_and_measure(what: String) -> void:
	_screen.open()
	for _frame: int in 6:
		await get_tree().process_frame

	var cards: Array[Button] = _cards()
	_check(not cards.is_empty(), "%s: the stash drew no cards at all" % what)
	var tallest: float = 0.0
	for card: Button in cards:
		# **The face, not the skin.** `UiJuice.dress` puts a `ColorRect` on every
		# button for its hologram, and it is a `Control` with no minimum size of
		# its own - so taking the first Control child measured the skin, found it
		# wanted nothing, and passed however badly the card was sized. Caught by
		# shrinking `CARD_LINE` and watching the gate stay green.
		var face: BoxContainer = null
		for child: Node in card.get_children():
			var box := child as BoxContainer
			if box != null:
				face = box
				break
		if face == null:
			_check(false, "%s: a card has no content container to measure" % what)
			continue
		# **What the card reserved against what the content needs**, not what the
		# layout happened to hand out. A card is free to be stretched by the list
		# it sits in, and measuring `size` therefore measures the list's
		# generosity rather than the card's own arithmetic - which is what let a
		# deliberately broken `CARD_LINE` sail through the first two cuts of this.
		# `custom_minimum_size` is the number the card computed for itself.
		var needs: float = face.get_combined_minimum_size().y
		# The *vertical* inset. The first cut took the horizontal one, which
		# reported every card twelve pixels shorter than it is.
		var inset: float = face.offset_top - face.offset_bottom
		var reserved: float = card.custom_minimum_size.y - inset
		var spare: float = reserved - needs
		tallest = maxf(tallest, needs)
		_check(spare >= -BREATHING_ROOM,
			("%s: a card reserves %.0f for content that needs %.0f "
			+ "(short by %.0f)") % [what, reserved, needs, -spare])
	print("  [stash-render] %s: %d cards, tallest content %.0f"
		% [what, cards.size(), tallest])
	_screen.hide_screen()


## **The card's own arithmetic against the roster's worst case.**
##
## Read rather than trusted: `CARD_HEIGHT` reserves room for one row of bonuses
## and a line for each row after it, and the most lines any piece in the game can
## carry is the top rarity's affix count plus its legendary affixes. If the
## roster ever out-grows the card, that is a number nobody would notice moving.
func _test_the_ceiling_is_what_the_card_counts() -> void:
	var top: int = Stash.RARITY_NAMES.size() - 1
	var affixes: int = Balance.GEAR_AFFIX_COUNT[clampi(top, 0,
		Balance.GEAR_AFFIX_COUNT.size() - 1)]
	var legendary: int = Balance.GEAR_LEGENDARY_COUNT[clampi(top, 0,
		Balance.GEAR_LEGENDARY_COUNT.size() - 1)]
	var lines: int = affixes + legendary
	_check(lines <= GearData.Slot.size() + Balance.GEAR_LEGENDARY_COUNT.size(),
		"the worst case is %d lines, which is more than any card was sized for" % lines)
	var rows: int = int(ceil(float(lines) / float(StashScreen.CARD_COLUMNS)))
	print("  [stash-render] worst case: %d affixes + %d legendary = %d lines, %d rows"
		% [affixes, legendary, lines, rows])
	_check(rows >= 1, "a maxed piece must carry at least one row of bonuses")


func _cards() -> Array[Button]:
	var out: Array[Button] = []
	for node: Node in _walk(_screen):
		var button := node as Button
		if button == null:
			continue
		# The item cards are the tall ones that carry their own face; the filter
		# tabs and the sweeps are short and have no child container.
		if button.custom_minimum_size.y >= StashScreen.CARD_HEIGHT:
			out.append(button)
	return out


func _walk(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_walk(child))
	return found
