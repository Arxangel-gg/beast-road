extends Node

## The Long Ledger's three tabs, so they can be looked at.
##
## `exchange_check` proves the economy. It cannot see whether a player can tell
## what a price means, and this screen's entire job is to teach that in one look.
##
## Saves are held and the account is put back: this rewrites the stash, the Marks
## and the board to have something worth photographing, and a tool that eats a
## played stash is a fault this project has shipped twice.

var _stash_before: Array = []
var _equipped_before: Dictionary = {}
var _marks_before: int = 0
var _orders_before: Array = []


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate(true)
	_marks_before = MetaState.marks
	_orders_before = MetaState.exchange_orders.duplicate(true)

	# One kind per slot at spread rarities, so the list has rows worth comparing.
	var kinds: Array[String] = []
	var slots: Dictionary = {}
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null or slots.has(kind.slot):
			continue
		slots[kind.slot] = true
		kinds.append(kind.id)
	MetaState.stash = []
	for index: int in kinds.size():
		MetaState.stash.append(Stash.make(kinds[index], index % 5, 1 + index % 3))
	MetaState.equipped = {}
	var worn: GearData = ContentDB.gear(kinds[1])
	if worn != null:
		MetaState.equipped[worn.slot] = 1
	MetaState.marks = 4200
	MetaState.exchange_orders = []
	Exchange.call("_adopt_save")

	var screen := ExchangeScreen.new()
	add_child(screen)
	await get_tree().process_frame

	# A board with something on it: one standing, one part way, one met.
	# Index 0 twice would hit the equipped piece the second time, once the
	# first has left the stash and every index behind it has moved down.
	Exchange.post_sale(0, Exchange.guide_price(MetaState.stash[0]))
	Exchange.post_sale(2, ExchangeMarket.max_ask(MetaState.stash[2]))
	Exchange.post_purchase(kinds[3], 3, 1,
		Exchange.guide_price(Stash.make(kinds[3], 3, 1)))
	Exchange.advance_road(Balance.JOURNEY_TOTAL_DISTANCE * 0.35)

	screen.open()
	await _shoot(screen, "board")

	screen.set("_tab", ExchangeScreen.Tab.SELL)
	# Index 1, not 0: the greathelm at 0 is the equipped one once two pieces
	# have left the stash, and the screen correctly refuses to list it.
	screen.set("_picked_uid", Stash.uid(MetaState.stash[1] as Dictionary))
	screen.call("_refresh")
	await _shoot(screen, "sell")

	screen.set("_tab", ExchangeScreen.Tab.BUY)
	screen.set("_want_kind", kinds[4])
	screen.set("_want_rarity", 4)
	screen.call("_refresh")
	await _shoot(screen, "buy")

	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	MetaState.marks = _marks_before
	MetaState.exchange_orders = _orders_before
	Exchange.call("_adopt_save")
	MetaState.resume_saves()

	print("[exchange-shot] wrote three tabs")
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit()


func _shoot(screen: CanvasLayer, name: String) -> void:
	for _frame: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		OS.get_environment("SHOT_OUT").replace(".png", "_%s.png" % name))
