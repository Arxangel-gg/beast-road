extends Node

## The Codex's tabs and its spirit journal, so they can be looked at.
##
## `codex_check` proves a discovery is recorded once and survives a reload. It
## cannot see whether a page *reads* - whether the tabs say which one is open,
## whether an act's page is empty, whether the spirits draw their own animals
## next to what they eat. That is the whole of what the owner asked for on
## 2026-09-22 and none of it is a number.
##
## Saves are held and the account is put back: this marks half the book seen and
## bonds a handful of spirits, and a tool that eats a played journal is a fault
## this project has shipped twice.

var _seen_before: Array = []
var _encounters_before: Dictionary = {}
var _bonded_before: Dictionary = {}
var _equipped_before: String = ""


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_seen_before = MetaState.codex_seen.duplicate(true)
	_encounters_before = MetaState.spirit_encounters.duplicate(true)
	_bonded_before = MetaState.spirit_bonded.duplicate(true)
	_equipped_before = MetaState.equipped_spirit

	# Half a book: enough found entries to read, enough unfound ones that the
	# page still shows what an unfound row looks like.
	_see_half("enemy", ContentDB.enemies)
	_see_half("wildlife", ContentDB.wildlife_kinds)
	_see_half("affix", ContentDB.affixes)
	_see_half("weather", ContentDB.weathers)

	# One species met at every rarity and bonded at the low ones, one walking.
	var animals: Array[WildlifeData] = ContentDB.wildlife()
	animals.sort_custom(func(a: WildlifeData, b: WildlifeData) -> bool:
		return a.display_name < b.display_name)
	var walked: String = ""
	for index: int in mini(6, animals.size()):
		var kind: WildlifeData = animals[index]
		for rarity: int in 3:
			for _again: int in SpiritBond.needed(rarity, false):
				MetaState.record_spirit_encounter(kind.id, rarity, false, "steadfast")
		if walked.is_empty():
			walked = SpiritBond.key(kind.id, 1, false)
	MetaState.equipped_spirit = walked

	var screen := CodexScreen.new()
	add_child(screen)
	screen.open()
	await _shoot(screen, "all")

	screen.set("_tab", 3)
	screen.call("_refresh")
	await _shoot(screen, "act3")

	screen.set("_tab", CodexScreen.TAB_SPIRITS)
	screen.call("_refresh")
	await _shoot(screen, "spirits")

	# One open, so the variants and the upkeep ladder are both on screen.
	screen.set("_spirit_open", animals[0].id)
	screen.call("_refresh")
	await _shoot(screen, "spirit_open")

	MetaState.codex_seen = _seen_before
	MetaState.spirit_encounters = _encounters_before
	MetaState.spirit_bonded = _bonded_before
	MetaState.equipped_spirit = _equipped_before
	MetaState.resume_saves()

	print("[codex-shot] wrote four pages")
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit()


func _see_half(kind: String, table: Dictionary) -> void:
	var ids: Array = table.keys()
	ids.sort()
	for index: int in ids.size():
		if index % 2 == 0:
			MetaState.record_seen(kind, String(ids[index]))


func _shoot(screen: CanvasLayer, page: String) -> void:
	for _frame: int in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		OS.get_environment("SHOT_OUT").replace(".png", "_%s.png" % page))
