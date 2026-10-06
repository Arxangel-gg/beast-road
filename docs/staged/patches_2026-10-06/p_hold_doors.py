import sys; sys.path.insert(0, r"C:\Users\Hamed\AppData\Local\Temp\claude\E--Arxangel-GameDev-BeastRoad\19c67aba-492a-46b1-b9b8-c51fb20d916f\scratchpad")
from patchlib import patch

patch("scripts/systems/hold_yard.gd", [(
r'''	{"id": "stable", "door": "Stable", "art": "res://art/city/building_granary_tier_02.png",
		"label": "The Stable", "cell": Vector2i(8, 20)},
''',
r'''	{"id": "stable", "door": "Stable", "art": "res://art/city/building_granary_tier_02.png",
		"label": "The Stable", "cell": Vector2i(8, 20)},
	# **Four doors that stood on the front door until 2026-10-06** (owner:
	# "Move Watch Trailer, Guide, Co-op and Warden slots into the Hold as juicy
	# animated interactables; remove from main menu; elevate the Hold"). Each is
	# the menu's own button adopted into the room, as every door here is, so the
	# screen it opens and the way back are untouched; what is new is a building
	# to walk up to, with the gem, the beacon and the badge every station wears.
	# The Guide is an archive on the upper shelf beside the Codex and the
	# Chronicle, where the books are; the trailer plays from a lookout on the
	# eastern shelf; the muster for a party stands on the raised pocket east of
	# the gate, which is where a party would gather before the road; and the
	# Hall of Wardens - which Warden walks out of here - stands on the eastern
	# shelf under the Ledger. **This re-cuts the 2026-09-22 line** that choosing
	# a Warden from inside a room the Warden owns is the wrong way round; the
	# owner asked for it by name, and the slot screen refuses mid-road as before.
	{"id": "archive", "door": "Guide", "art": "res://art/city/building_town_hall_tier_02.png",
		"label": "The Archive", "cell": Vector2i(14, 4)},
	{"id": "lookout", "door": "Trailer", "art": "res://art/city/building_watchtower_tier_02.png",
		"label": "The Lookout", "cell": Vector2i(31, 7)},
	{"id": "muster", "door": "Coop", "art": "res://art/city/building_scavenging_post_tier_02.png",
		"label": "The Muster", "cell": Vector2i(30, 17)},
	{"id": "hall", "door": "Wardens", "art": "res://art/city/building_treasury_tier_02.png",
		"label": "The Hall of Wardens", "cell": Vector2i(31, 11)},
''')])

patch("scenes/ui/main_menu.gd", [(
r'''	for door: String in ["Stash", "Ledger", "Vendor", "Smithy", "Pen", "Stable",
			"Chronicle",
			"Codex", "Leaderboard", "WalkAgain"]:
		var found: Node = column.get_node_or_null(door)
''',
r'''	# The Guide, the trailer, co-op and the Wardens moved in on 2026-10-06
	# (owner: "remove from main menu; elevate the Hold"); the front door keeps
	# the road, the first Walk, the Hold, Settings and Quit.
	for door: String in ["Stash", "Ledger", "Vendor", "Smithy", "Pen", "Stable",
			"Chronicle",
			"Codex", "Leaderboard", "WalkAgain", "Guide", "Trailer", "Coop", "Wardens"]:
		var found: Node = column.get_node_or_null(door)
''')])

patch("tools/hold_check.gd", [(
r'''	await _test_the_stone_card_comes_back()
	await _test_the_doors_say_what_waits()
''',
r'''	await _test_the_stone_card_comes_back()
	await _test_the_four_doors_moved_in()
	await _test_the_doors_say_what_waits()
'''), (
r'''	for stage: String in ["pond_fish", "act_start_door", "stranger_gear", "strangers_dressed", "thumb", "news", "chrome",
			"click", "menu_click", "stone_card", "talks"]:
''',
r'''	for stage: String in ["pond_fish", "act_start_door", "stranger_gear", "strangers_dressed", "thumb", "news", "chrome",
			"click", "menu_click", "stone_card", "four_doors", "talks"]:
'''), (
r'''func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
''',
r'''## **The Guide, the trailer, co-op and the Wardens are doors in the Hold and
## not on the front door** (owner, 2026-10-06). Through the real menu: each
## button stands in the Hold's grid, bound to a building of its own in the
## yard, and the front door's column no longer holds it; pressing the Guide's
## door from the Hold opens the Guide over the room and closing it comes back.
func _test_the_four_doors_moved_in() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	WardenGlass.mark_offered()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	add_child(menu)
	await _frames(20)
	var hub: HubScreen = menu.get("_hub") as HubScreen
	var column: Node = (menu.get("new_run_button") as Button).get_parent() \
		if menu.get("new_run_button") != null else null
	_check(hub != null and column != null, "the real menu has no Hold or no column")
	if hub == null or column == null:
		menu.queue_free()
		_reached["four_doors"] = true
		return
	var yard: HoldYard = hub.get("_yard") as HoldYard
	var grid: Node = hub.get("_grid") as Node
	for door: String in ["Guide", "Coop", "Wardens"]:
		var button: Node = grid.get_node_or_null(door) if grid != null else null
		_check(button is Button, "the Hold's doors have no %s" % door)
		_check(column.get_node_or_null(door) == null, "the front door still carries %s" % door)
		_check(yard != null and yard.bound(door), "%s has no building in the yard" % door)
	# The trailer's door exists only when the film is in the build; where it
	# is, it moved in with the others.
	if TrailerPlayer.available():
		_check(grid != null and grid.get_node_or_null("Trailer") is Button
				and column.get_node_or_null("Trailer") == null and yard != null and yard.bound("Trailer"),
			"the trailer's door did not move into the Hold")
	# Pressing the Guide from the Hold opens it over the room, and closing it
	# comes back to the room.
	hub.open()
	await _frames(4)
	var guide_door: Button = grid.get_node_or_null("Guide") as Button if grid != null else null
	var guide: CanvasLayer = menu.get("_guide") as CanvasLayer
	if guide_door != null and guide != null:
		guide_door.pressed.emit()
		await _frames(3)
		_check(guide.visible and hub.is_suspended(), "the Guide did not open over the Hold from its door")
		guide.call("close")
		await _frames(3)
		_check(hub.visible and not hub.is_suspended(), "closing the Guide did not come back to the Hold")
	hub.close()
	menu.queue_free()
	await _frames(3)
	_reached["four_doors"] = true


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
''')])
