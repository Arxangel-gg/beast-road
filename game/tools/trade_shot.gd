extends Node

## The trade window, on both of its screens, so it can be looked at.
##
## `trade_check` proves the rules and proves gear is never made twice. It cannot
## see whether a player can tell what they are agreeing to, and the second
## screen is worth nothing if it does not read clearly - its entire job is to be
## read.

func _ready() -> void:
	await get_tree().process_frame
	RunState.reset()
	# Two seats, so the screen has a partner to name.
	Coop.party().open("You")
	Coop.party().seat(77, "Partner")

	var kind: String = ""
	for value: Variant in ContentDB.gear_kinds.values():
		var one := value as GearData
		if one != null:
			kind = one.id
			break
	MetaState.stash = [Stash.make(kind, 3), Stash.make(kind, 1), Stash.make(kind, 0)]
	MetaState.equipped = {}

	var screen := (load("res://scenes/ui/trade_screen.gd") as GDScript).new() as CanvasLayer
	add_child(screen)
	await get_tree().process_frame

	# The table, built by hand rather than by two machines: the screen draws what
	# the booth says, and what is being looked at here is the drawing.
	var trade := TradeSession.new()
	trade.invite(TradeSession.GUEST)
	trade.accept_invite(TradeSession.HOST)
	trade.set_offer(TradeSession.HOST, [MetaState.stash[0]], Balance.TRADE_MAX_PIECES)
	trade.set_offer(TradeSession.GUEST, [Stash.make(kind, 4)], Balance.TRADE_MAX_PIECES)
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

	print("[trade-shot] wrote both screens")
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit()
