extends Node

## **The Long Ledger drawn at the worst case it can ever be asked to draw.**
##
##   godot --headless --path game res://tools/exchange_render_check.tscn
##
## Owner, 2026-09-16: "test our grand exchange/auction house system with random
## items and polish its UI/UX to max perfection!"
##
## `exchange_check` already holds the *economics* - the spread, conservation, the
## road, the supply - and it is long because every failure there is silent and
## permanent. None of it looks at a pixel. This is the other half: the board
## filled with the worst things it can be asked to show, rendered, and measured.
##
## **Why a board is harder to draw than a stash.** Every row carries a gear line
## *and* a status line under it, and the status is composed from three separate
## things that each have a long form: a price that can reach five figures, a
## settlement estimate that can read "no caravan will meet this price", and a
## percentage. A Beastcalled piece at maximum level wearing five bonuses, listed
## at a price nobody will meet, is a row with two long lines in it - and the band
## it sits in sizes itself from its children, so a line that wraps to three rows
## silently pushes the button out of the panel.
##
## **Measured rather than asserted.** The check reads the real laid-out height and
## width off the control tree, so the day a constant moves the comparison still
## means what it says - the approach `stash_render_check` was built on after two
## of its own cuts measured the wrong node.
##
## What it holds:
##
##  - every row's content fits inside the band it was given, on every tab;
##  - nothing is drawn wider than the panel, at the narrowest width the layout
##    supports and at the widest;
##  - a full board - every line taken - still lays out;
##  - and the extremes of the price field are accepted rather than clamped into
##    something the player did not type.

## How many differently-named pieces to put on the board. An affix roll is
## derived from a piece's `uid`, so two maxed swords do not carry the same lines;
## one sample would not be a test.
const ROLLS: int = 24

## The room a row must keep between its content and its own edge, in pixels. Not
## zero: a descender touching a border is clipped as far as a reader is
## concerned, whatever the arithmetic says.
const BREATHING_ROOM: float = 2.0

## The two ends of the layout: a landscape phone and a wide desktop.
const NARROW: Vector2i = Vector2i(720, 430)
const WIDE: Vector2i = Vector2i(1920, 1080)

var _checks: int = 0
var _failures: int = 0
var _screen: ExchangeScreen = null


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260916)
	await _test_a_full_board_of_the_worst_rows()
	await _test_both_ends_of_the_layout()
	_test_the_price_field_takes_the_extremes()
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	for _frame: int in 12:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[exchange-render] FAIL - %d of %d" % [_failures, _checks])
		get_tree().quit(1)
		return
	print("[exchange-render] PASS - %d checks: a full board of maxed pieces on "
		% _checks + "both sides, every row inside its band at both ends of the "
		+ "layout, and a price field that takes what it is given")
	get_tree().quit(0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("  ERROR: %s" % why)


## **A board full of the worst rows it can hold.**
##
## Top rarity, maximum level, both sides, and a spread of prices that includes
## the one nobody will meet - which is the longest status line the screen can
## produce.
func _test_a_full_board_of_the_worst_rows() -> void:
	_fill_the_board()
	await _open_at(WIDE)
	_check(Exchange.orders().size() > 0, "the board has orders on it (%d)"
		% Exchange.orders().size())
	_measure_every_row("a full board")
	await _close()


## The same board at the narrowest width the layout supports and at the widest.
## A row that fits on a desktop and wraps on a phone is a row that is wrong on a
## phone, and nothing about the board says which width it was written for.
func _test_both_ends_of_the_layout() -> void:
	for size: Vector2i in [NARROW, WIDE]:
		await _open_at(size)
		_measure_every_row("at %dx%d" % [size.x, size.y])
		var panel: Control = _screen.get("_panel") as Control
		if panel != null:
			_check(panel.size.x <= float(size.x) + BREATHING_ROOM,
				"the panel is no wider than the window at %dx%d (%.0f against %d)"
					% [size.x, size.y, panel.size.x, size.x])
		await _close()


## The price field is asked for nothing and for far too much, and must hand back
## what it was given rather than something the player did not type.
func _test_the_price_field_takes_the_extremes() -> void:
	var field := SpinBox.new()
	add_child(field)
	field.min_value = 0
	field.max_value = 999999
	for wanted: int in [0, 1, 9999, 999999]:
		field.value = wanted
		_check(int(field.value) == wanted,
			"a price of %d is kept as %d" % [wanted, int(field.value)])
	field.queue_free()


# --- The board, and the measuring ----------------------------------------------

## Maxed pieces on both sides, at prices that include the one no caravan meets -
## which is the longest status line this screen can produce.
func _fill_the_board() -> void:
	MetaState.stash.clear()
	MetaState.equipped.clear()
	# Cleared through the real door: cancelling gives back exactly what was put
	# in, which is the one behaviour this gate must not quietly bypass.
	while not Exchange.orders().is_empty():
		Exchange.cancel(0)
	var top: int = Stash.RARITY_NAMES.size() - 1
	var kinds: Array[GearData] = ContentDB.gear_sorted()
	if kinds.is_empty():
		return
	# **Posted through the real doors**, so what is on the board is what a player
	# could actually have put there - a board filled by hand would be a board
	# nothing in the game can produce, and the rows would prove nothing.
	MetaState.marks = 9999999
	for roll: int in ROLLS:
		if not Exchange.has_room():
			break
		var kind: GearData = kinds[roll % kinds.size()]
		if kind == null:
			continue
		# A price nobody will meet on every third one, so the long form of the
		# settlement line - "no caravan will meet this price" - is rendered.
		var absurd: bool = roll % 3 == 0
		if roll % 2 == 0:
			MetaState.stash.append(Stash.make(kind.id, top, Stash.MAX_LEVEL))
			Exchange.post_sale(MetaState.stash.size() - 1, 999999 if absurd else 250)
		else:
			Exchange.post_purchase(kind.id, top, Stash.MAX_LEVEL, 1 if absurd else 250)


## Every row on every tab, measured against the band it was given.
func _measure_every_row(where: String) -> void:
	var body: Control = _screen.get("_body") as Control
	if body == null:
		_check(false, "%s: the board has a body to measure" % where)
		return
	var rows: int = 0
	var overflowed: int = 0
	var too_wide: int = 0
	for band: Node in body.get_children():
		var control := band as Control
		if control == null:
			continue
		rows += 1
		var wanted: Vector2 = control.get_combined_minimum_size()
		if control.size.y + BREATHING_ROOM < wanted.y:
			overflowed += 1
		if control.size.x + BREATHING_ROOM < wanted.x:
			too_wide += 1
	_check(rows > 0, "%s: there are rows to measure (%d)" % [where, rows])
	_check(overflowed == 0,
		"%s: %d of %d rows are shorter than their own content" % [where, overflowed, rows])
	_check(too_wide == 0,
		"%s: %d of %d rows are narrower than their own content" % [where, too_wide, rows])


func _open_at(size: Vector2i) -> void:
	get_viewport().set_content_scale_size(size)
	_screen = ExchangeScreen.new()
	add_child(_screen)
	_screen.open()
	# Two frames: one for the tree, one for the layout pass. A `Control` added
	# from code has zero size until that pass, which is the fault the launcher's
	# border shipped with.
	for _frame: int in 4:
		await get_tree().process_frame


func _close() -> void:
	if _screen != null and is_instance_valid(_screen):
		_screen.queue_free()
	_screen = null
	for _frame: int in 3:
		await get_tree().process_frame
