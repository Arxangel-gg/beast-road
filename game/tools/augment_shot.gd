extends Node

## Renders an augment draft, so the table can be looked at.
##
##   godot --path game res://tools/augment_shot.tscn
##
## Diagnostic only, never a gate. `augment_check` proves the draft opens, holds
## the clock and takes the card a player presses; it cannot see whether three
## cards, their levels, their branch and the four tools underneath read as one
## decision - and this project has paid several times for the difference
## between a number agreeing and a picture agreeing.
##
## Three pictures: a draft over an empty hand, a draft over a hand with a card to
## level (so the "II -> III" rows are in it), and the pause screen's hand and
## damage lines.

func _ready() -> void:
	# Held for the whole run: this tool edits `MetaState`, and a tool that edits
	# the account must never be able to write it to the player's disk.
	MetaState.hold_saves()
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, 20260926)
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _f: int in 14:
		await get_tree().process_frame
	RunState.set_phase(RunState.Phase.PREPARATION)
	RunState.act = 6

	RunState.queue_augment(Augments.SOURCE_RANK)
	# The table as it arrives, still guarded: dim, and not yet taking a press.
	for _f: int in 12:
		await get_tree().process_frame
	await _shoot("augment_shot_guarded")
	await _let_the_deal_land()
	await _shoot("augment_shot_fresh")

	# A hand with something to grow, three levels deep.
	RunState.skip_augment()
	run.crossroad_ui.close_augment_draft()
	for id: String in ["whetstone_hour", "cleared_sightlines", "set_stance"]:
		RunState.take_road_card(id)
	RunState.take_road_card("whetstone_hour")
	RunState.take_road_card("whetstone_hour")
	RunState.augment_luck = 5
	# A camp's draft, whose floor is Common: a boss deals Rare and above, so a
	# boss draft over a hand of commons can never put a levelling row on the
	# table, and the first run of this tool photographed exactly that.
	RunState.queue_augment(Augments.SOURCE_CAMP)
	run._augments_put_off = false
	for _f: int in 20:
		await get_tree().process_frame
	# Deal until a held card is on the table, so a levelling row is in the shot.
	for _attempt: int in 12:
		var holds: bool = false
		for id: String in RunState.augment_offer:
			holds = holds or RunState.road_cards.has(id)
		if holds:
			break
		RunState.augment_rerolls = 6
		RunState.reroll_augment()
		run.crossroad_ui.open_augment_draft()
		for _f: int in 6:
			await get_tree().process_frame
	await _let_the_deal_land()
	await _shoot("augment_shot_level")

	# **A card that names its pair** (2026-10-01): a hand holding Chain Spark,
	# dealt until a card with an *Evolves* row is on the table - Chain Spark's
	# own next level, or Quickening Oil marking the half already held.
	RunState.skip_augment()
	run.crossroad_ui.close_augment_draft()
	RunState.take_road_card("chain_spark")
	RunState.queue_augment(Augments.SOURCE_CAMP)
	run._augments_put_off = false
	for _f: int in 20:
		await get_tree().process_frame
	for _attempt: int in 16:
		var names: bool = false
		for id: String in RunState.augment_offer:
			names = names or not CrossroadScreen.evolution_line_text(id,
				RunState.road_cards).is_empty()
		if names:
			break
		RunState.augment_rerolls = 6
		RunState.reroll_augment()
		run.crossroad_ui.open_augment_draft()
		for _f: int in 6:
			await get_tree().process_frame
	await _let_the_deal_land()
	await _shoot("augment_shot_evolves")

	RunState.skip_augment()
	run.crossroad_ui.close_augment_draft()
	DamageLedger.note("tower:ember_spire", 5200.0)
	DamageLedger.note(DamageLedger.WARDEN, 2100.0)
	DamageLedger.note(DamageLedger.BURN, 640.0)
	var pause: Node = get_tree().get_first_node_in_group(&"pause_menu")
	if pause != null:
		pause.call("toggle")
		for _f: int in 10:
			await get_tree().process_frame
		await _shoot("augment_shot_pause")
		pause.call("toggle")

	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(0)


## **In seconds, never frames** (2026-09-26). The cards flip in and the tools
## row fades in on a stagger, so twenty frames at a hundred and eighty a second
## photographed one card, a sliver and nothing under them - and read as a broken
## draft. The whole entrance is well under two seconds.
func _let_the_deal_land() -> void:
	await get_tree().create_timer(2.0).timeout


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = "user://%s.png" % name
	img.save_png(path)
	print("[augment-shot] %s -> %s" % [name, ProjectSettings.globalize_path(path)])
