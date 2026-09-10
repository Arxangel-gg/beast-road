extends Node

## The trade window, on both of its screens, so it can be looked at.
##
## `trade_check` proves the rules and proves gear is never made twice. It cannot
## see whether a player can tell what they are agreeing to, and the second
## screen is worth nothing if it does not read clearly - its entire job is to be
## read.
##
## **It borrows the player's stash and gives it back.** This is not a gate, it is
## a tool somebody runs on their own machine against their own save - and it
## rewrites `MetaState.stash` to have something worth photographing. Left alone
## it wrote five probe pieces into the real save on every run, which is the same
## fault `merchant_check` shipped once and had to be cleaned up by hand.
##
## Saves are held for the whole run as well, because putting the stash back at
## the end is not the same as never having written it: a script error anywhere
## above leaves a player holding probe gear.

## The player's own gear, put back exactly as it was found.
var _stash_before: Array = []
var _equipped_before: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate(true)
	RunState.reset()
	# Two seats, so the screen has a partner to name.
	Coop.party().open("You")
	Coop.party().seat(77, "Partner")

	# **One kind per slot, at spread rarities, with one worn and one kept.**
	# Three copies of the same sword said nothing about whether a player can read
	# the list: every row was the same colour, the same words and the same
	# length, so a layout fault that only shows up between two unequal rows was
	# invisible. The window is a comparison, and it has to be looked at with
	# things worth comparing in it.
	var kinds: Array[String] = []
	var slots_seen: Dictionary = {}
	for value: Variant in ContentDB.gear_kinds.values():
		var one := value as GearData
		if one == null or slots_seen.has(one.slot):
			continue
		slots_seen[one.slot] = true
		kinds.append(one.id)
	kinds.sort()
	var kind: String = kinds[0] if not kinds.is_empty() else ""
	MetaState.stash = []
	for index: int in kinds.size():
		MetaState.stash.append(Stash.make(kinds[index], index % 5))
	MetaState.stash.append(Stash.make(kind, 4))
	if MetaState.stash.size() > 2:
		(MetaState.stash[2] as Dictionary)["favourite"] = true
	MetaState.equipped = {}
	# One worn piece, because "Worn" is a disabled row and a disabled row is the
	# one state a screenshot of an all-tradeable stash never shows.
	var worn: GearData = ContentDB.gear(String(
		(MetaState.stash[1] as Dictionary).get("kind", "")))
	if worn != null:
		MetaState.equipped[worn.slot] = 1

	var screen := (load("res://scenes/ui/trade_screen.gd") as GDScript).new() as CanvasLayer
	add_child(screen)
	await get_tree().process_frame

	# The table, built by hand rather than by two machines: the screen draws what
	# the booth says, and what is being looked at here is the drawing.
	var trade := TradeSession.new()
	trade.invite(TradeSession.GUEST)
	trade.accept_invite(TradeSession.HOST)
	trade.set_offer(TradeSession.HOST,
		[MetaState.stash[0], MetaState.stash[2]], Balance.TRADE_MAX_PIECES)
	trade.set_offer(TradeSession.GUEST,
		[Stash.make(kind, 4), Stash.make(kinds[-1] if not kinds.is_empty() else kind, 2)],
		Balance.TRADE_MAX_PIECES)
	TradeBooth.set("_session", trade)
	TradeBooth.set("_side", TradeSession.HOST)
	TradeBooth.set("_partner_name", "Partner")
	screen.call("_on_trade_changed")
	for _f: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		OS.get_environment("SHOT_OUT").replace(".png", "_offer.png"))

	trade.set_accepted(TradeSession.HOST, true)
	trade.set_accepted(TradeSession.GUEST, true)
	screen.call("_on_trade_changed")
	for _f: int in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		OS.get_environment("SHOT_OUT").replace(".png", "_confirm.png"))

	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	MetaState.resume_saves()

	print("[trade-shot] wrote both screens")
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit()
