extends Node

## Every content resource's derived sprite actually exists on disk.
##
## **The manifest cannot catch this and neither could `report`.** Both work from
## `ASSET_MANIFEST.md` outward: they check that everything *declared* is present
## and real. An asset nobody remembered to declare is absent from the manifest,
## absent from disk, and absent from every check - so it is invisible until a
## player looks at the thing that should have drawn it.
##
## Six spell icons were missing exactly that way. The six summoning calls
## shipped, their sockets rendered, and each drew nothing at all; the manifest
## agreed with the disk because neither had ever heard of them.
##
## This walks the other direction: from the content that exists to the art its
## own `id` derives, which is the rule CLAUDE.md §4 makes the whole pipeline out
## of. If a resource can name a sprite, that sprite has to be there.

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	# Every database that holds `GameData`. Listed rather than discovered because
	# `ContentDB` exposes them as separate fields, and a missing one here is a
	# category nobody is checking - so the count is printed to make that visible.
	var books: Dictionary = {
		"towers": ContentDB.towers,
		"enemies": ContentDB.enemies,
		"relics": ContentDB.relics,
		"spells": ContentDB.spells,
		"wildlife": ContentDB.wildlife_kinds,
		"companions": ContentDB.companions,
		"traps": ContentDB.traps,
		"barricades": ContentDB.barricades,
		"gear": ContentDB.gear_kinds,
		"buildings": ContentDB.buildings,
		"captives": ContentDB.captives,
		"items": ContentDB.items,
		"factions": ContentDB.factions,
		"terrains": ContentDB.terrains,
		"disciplines": ContentDB.discipline_nodes,
		"tiers": ContentDB.tiers,
	}
	for label: String in books:
		for value: Variant in (books[label] as Dictionary).values():
			var data := value as GameData
			if data == null:
				continue
			# An empty path is a resource that deliberately has no art - a run
			# title, a spirit trait. Only a *named* sprite is a promise.
			var path: String = data.get_sprite_path()
			if path.is_empty():
				continue
			_checked += 1
			_check(ResourceLoader.exists(path),
				"%s '%s' derives %s, which does not exist - the content ships, "
					% [label, data.id, path]
					+ "the interface shows it, and it draws nothing")
	print("[content-art] %d derived sprites across %d content books"
		% [_checked, books.size()])
	_finish()


func _finish() -> void:
	if _failures == 0:
		print("[content-art] PASS - every resource that names a sprite has one")
	else:
		push_error("[content-art] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[content-art] FAIL: %s" % why)
