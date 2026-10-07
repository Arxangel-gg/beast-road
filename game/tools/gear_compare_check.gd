extends Node

## Two pieces side by side, and the one thing the card must never do: decide.
##
##   godot --headless --path game res://tools/gear_compare_check.tscn
##
## Owner, 2026-09-17: *"Items hovered on at the Market should compare the gear
## slot with what the player currently has equipped ... along with stat
## comparisons between the one hovered and the gear equipped by the player."*
##
## Four ways this becomes worse than no card at all:
##
## - **It lies.** A comparison that adds up the numbers printed on the cards
##   agrees with the cards and can still disagree with the game. It asks
##   `Stash.affixes` - the same function `MetaState.gear_attribute_points` feeds
##   from - so a shop cannot promise a Might the Warden never gets.
## - **It eats the pointer.** The card is opened *by* a hover: one that took the
##   mouse would close itself the instant it appeared, flicker, and reopen.
## - **It calls a trade good when it is a trade.** A piece that gives three Might
##   for four Focus is a different build, not an upgrade, and colouring it green
##   because the total rose is the card making the decision the player opened it
##   to make.
## - **It says nothing about an empty slot**, which is the single most useful
##   thing it can say - and a card that simply vanishes says it by omission.

var _failures: int = 0
var _checks: int = 0
var _card: GearCompare = null


func _ready() -> void:
	MetaState.hold_saves()
	_card = GearCompare.new()
	add_child(_card)
	await get_tree().process_frame

	_test_it_never_takes_the_pointer()
	_test_an_empty_slot_says_so()
	_test_the_difference_is_measured_not_printed()
	_test_a_trade_is_not_an_upgrade()
	_test_the_market_opens_it_both_ways()
	await _test_the_shelf_says_better_or_worse()

	MetaState.resume_saves()
	if _failures == 0:
		print(("[gear-compare] PASS - %d checks: the card reads the same affixes "
			+ "the hero does, never takes the pointer, names an empty slot, and "
			+ "refuses to call a trade an upgrade") % _checks)
	else:
		push_error("[gear-compare] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _test_it_never_takes_the_pointer() -> void:
	_check(_card.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"the comparison takes the pointer, so hovering a row opens a panel that "
		+ "steals the hover, closes, and reopens - the loop that makes a tooltip "
		+ "feel broken")


func _test_an_empty_slot_says_so() -> void:
	var kind: GearData = _any_kind()
	if kind == null:
		_check(false, "no gear kinds to compare")
		return
	MetaState.equipped.clear()
	_card.show_pair(Stash.make(kind.id, 0, 1))
	_check(_card.visible,
		"the card did not open for a piece with nothing worn against it - which "
		+ "is the comparison that matters most to a new Warden")
	_check(_said_anywhere("nothing worn"),
		"an empty slot was drawn as a blank card rather than as an empty slot. "
		+ "\"You are wearing nothing here\" is the most useful thing this can say")


## **Driven through the real affixes rather than through numbers typed here.**
##
## The affixes are derived from a piece's own `uid`, so two pieces of the same
## kind and rarity differ - which is exactly why the card has to ask rather than
## assume, and why this check reads the same function back rather than a table.
func _test_the_difference_is_measured_not_printed() -> void:
	var kind: GearData = _any_kind()
	if kind == null:
		return
	var poor: Dictionary = Stash.make(kind.id, 0, 1)
	var rich: Dictionary = Stash.make(kind.id, Stash.RARITY_NAMES.size() - 1, 9)

	var poor_points: int = _total(Stash.affixes(poor, kind))
	var rich_points: int = _total(Stash.affixes(rich, kind))
	_check(rich_points > poor_points,
		("a Beastcalled level 9 granted %d points against a Common level 1's %d "
		+ "- with no gap there is nothing for this gate to measure and the "
		+ "comparison itself would be meaningless") % [rich_points, poor_points])

	# Wear the poor one, offer the rich one: the card must say it is a rise.
	MetaState.equipped.clear()
	MetaState.stash.clear()
	MetaState.stash.append(poor)
	MetaState.equip(int(kind.slot), 0)
	_card.show_pair(rich)
	_check(_verdict_ink().is_equal_approx(GearCompare.BETTER),
		"a strictly better piece was not called better, so the card is not "
		+ "reading the affixes the hero reads")

	# And the other way round, which a sign error would pass the first test on.
	MetaState.stash.clear()
	MetaState.stash.append(rich)
	MetaState.equip(int(kind.slot), 0)
	_card.show_pair(poor)
	_check(_verdict_ink().is_equal_approx(GearCompare.WORSE),
		"a strictly worse piece was not called worse - a comparison that reads "
		+ "the same either way has its sign wrong, and would pass a test that "
		+ "only ever offered an upgrade")


## A piece that gives with one hand and takes with the other is neither.
func _test_a_trade_is_not_an_upgrade() -> void:
	var kind: GearData = _any_kind()
	if kind == null:
		return
	# Two pieces of the same kind, rarity and level differ only by `uid`, which
	# is what decides their *secondary* attributes - so this is the real way a
	# trade arises rather than a contrived one.
	var worn: Dictionary = Stash.make(kind.id, 2, 5)
	var offered: Dictionary = Stash.make(kind.id, 2, 5)
	if _total(Stash.affixes(worn, kind)) != _total(Stash.affixes(offered, kind)):
		# Equal budgets are the point; if the roll gave different totals this
		# particular pair cannot show a pure trade, and saying so is better than
		# asserting something the data does not support.
		print("[gear-compare] note: the sampled pair did not tie, trade case skipped")
		return
	MetaState.stash.clear()
	MetaState.stash.append(worn)
	MetaState.equip(int(kind.slot), 0)
	_card.show_pair(offered)
	_check(not _verdict_ink().is_equal_approx(GearCompare.BETTER),
		"a piece worth exactly as much was called better. A trade is a different "
		+ "build, and calling it an upgrade is the card making the decision the "
		+ "player opened it to make")


## The Market has to open it on a hover *and* on focus.
func _test_the_market_opens_it_both_ways() -> void:
	var code: String = FileAccess.get_file_as_string("res://scenes/ui/vendor_screen.gd")
	_check(code.contains("mouse_entered.connect"),
		"the Market never opens the comparison on a hover, which is what the "
		+ "owner asked for in as many words")
	_check(code.contains("focus_entered.connect"),
		"the Market opens the comparison for a mouse and not for a pad - a hover "
		+ "wired only to the pointer is a feature for one of the three ways this "
		+ "game is played")
	_check(code.contains("_hide_compare"),
		"nothing ever closes the comparison, so a card opened over the shelf "
		+ "stays over it")


## **The shelf wears the card's verdict, and Upgrades only keeps what is
## better** (owner, 2026-10-07: *"A toggle button at the market to only show
## better items than what the player is wearing. Each item's row in the market
## should have a slight color indicator to show if it's better or worse"*).
##
## Driven through the real screen on a real shelf. A piece's affixes come from
## its own name, so whether one is better is never assumed here: every row is
## held to `GearCompare.verdict`, the card is held to the same answer, and the
## shelf is stocked so that both a better and a worse piece are on it.
func _test_the_shelf_says_better_or_worse() -> void:
	var kind: GearData = _any_kind()
	if kind == null:
		_check(false, "no gear kinds for the shelf")
		return
	MetaState.equipped.clear()
	var worn: Dictionary = Stash.make(kind.id, 2, 12)
	MetaState.stash.append(worn)
	MetaState.equip(int(kind.slot), MetaState.stash.size() - 1)
	var stock: Array = []
	for i: int in 6:
		stock.append(Stash.make(kind.id, 0, 1))
		stock.append(Stash.make(kind.id, Stash.RARITY_NAMES.size() - 1, 60))
	var verdicts: Dictionary = {}
	for piece: Dictionary in stock:
		var answer: int = GearCompare.verdict(piece)
		verdicts[answer] = true
		# The card says the same thing, in its own ink.
		_card.show_pair(piece)
		var ink: Color = _verdict_ink()
		if answer == GearCompare.Verdict.BETTER:
			_check(ink.is_equal_approx(GearCompare.BETTER),
				"the shelf calls a piece better and the card does not")
		elif answer == GearCompare.Verdict.WORSE:
			_check(ink.is_equal_approx(GearCompare.WORSE),
				"the shelf calls a piece worse and the card does not")
		elif answer == GearCompare.Verdict.TRADE:
			_check(ink.is_equal_approx(GearCompare.SAME),
				"the card named a winner for a trade")
	_card.hide_pair()
	_check(verdicts.has(GearCompare.Verdict.BETTER) and verdicts.has(GearCompare.Verdict.WORSE),
		"the shelf was never stocked with both a better and a worse piece (%s)" % [verdicts.keys()])

	var shelf_before: Variant = MetaState.vendor
	MetaState.vendor = {"stock": stock, "rolled_at": Time.get_unix_time_from_system()}
	var screen := VendorScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	await get_tree().process_frame
	var rows: Array = _wares(screen)
	_check(rows.size() == stock.size(), "the Market drew %d of %d wares" % [rows.size(), stock.size()])
	for row: Control in rows:
		var answer: int = int(row.get_meta(&"verdict", -1))
		var wash := row.get_theme_stylebox(&"panel") as StyleBoxFlat
		var said := row.find_child("Verdict", true, false) as Label
		_check(wash != null and Color(wash.border_color.r, wash.border_color.g,
			wash.border_color.b).is_equal_approx(Color(GearCompare.verdict_colour(answer).r,
			GearCompare.verdict_colour(answer).g, GearCompare.verdict_colour(answer).b)),
			"a ware's edge is not its verdict's colour")
		_check(said != null and said.text == GearCompare.verdict_word(answer),
			"a ware does not say its verdict beside its price")
	# Upgrades only: exactly the better pieces, and the empty-slot ones.
	var button := screen.find_child("UpgradesOnly", true, false) as Button
	_check(button != null, "the Market has no Upgrades only toggle")
	if button != null:
		button.button_pressed = true
		await get_tree().process_frame
		var kept: Array = _wares(screen)
		var wanted: int = 0
		for piece: Dictionary in stock:
			var answer: int = GearCompare.verdict(piece)
			if answer == GearCompare.Verdict.BETTER or answer == GearCompare.Verdict.EMPTY_SLOT:
				wanted += 1
		_check(kept.size() == wanted, "Upgrades only kept %d wares where %d are better"
			% [kept.size(), wanted])
		for row: Control in kept:
			var answer: int = int(row.get_meta(&"verdict", -1))
			_check(answer == GearCompare.Verdict.BETTER or answer == GearCompare.Verdict.EMPTY_SLOT,
				"Upgrades only kept a ware that is not better")
		button.button_pressed = false
		await get_tree().process_frame
		_check(_wares(screen).size() == stock.size(), "pressed again, the shelf did not come back whole")
	screen.hide_screen()
	screen.queue_free()
	MetaState.vendor = shelf_before
	MetaState.equipped.clear()
	MetaState.stash.pop_back()


func _wares(screen: Node) -> Array:
	var out: Array = []
	# By the verdict each row carries, not by name: siblings that share a name
	# are renamed by the tree.
	for node: Node in screen.find_children("*", "PanelContainer", true, false):
		if node.has_meta(&"verdict") and not node.is_queued_for_deletion():
			out.append(node)
	return out


# --- Harness -----------------------------------------------------------------

func _any_kind() -> GearData:
	for id: Variant in ContentDB.gear_kinds:
		var kind := ContentDB.gear_kinds[id] as GearData
		if kind != null:
			return kind
	return null


func _total(affixes: Array[Dictionary]) -> int:
	var sum: int = 0
	for affix: Dictionary in affixes:
		sum += int(affix["points"])
	return sum


## The verdict's colour, which is the card's overall opinion in one value.
##
## The line is a `RichTextLabel` so each stat term can wear its own red or
## green; `default_color` is what the line as a whole is painted in, which a
## coloured term overrides and the neutral cases do not.
func _verdict_ink() -> Color:
	var found: RichTextLabel = _find_verdict(_card)
	if found == null:
		_check(false, "the card has no verdict line at all")
		return Color.BLACK
	return found.get_theme_color(&"default_color")


func _find_verdict(from: Node) -> RichTextLabel:
	# The verdict is the one rich line on the card, so it is found by walking
	# rather than by an index - an index here would break the first time a row
	# was added above it.
	for child: Node in from.get_children():
		var line := child as RichTextLabel
		if line != null and not line.text.is_empty():
			return line
		var deeper: RichTextLabel = _find_verdict(child)
		if deeper != null:
			return deeper
	return null


func _said_anywhere(wanted: String) -> bool:
	return _walk_text(_card).to_lower().contains(wanted.to_lower())


func _walk_text(from: Node) -> String:
	var said: String = ""
	var label := from as Label
	if label != null:
		said += label.text + " "
	for child: Node in from.get_children():
		said += _walk_text(child)
	return said


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[gear-compare] " + why)
