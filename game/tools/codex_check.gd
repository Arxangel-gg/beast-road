extends Node

## The codex records what the road showed you (owner decision, 2026-08-31).
##
## Three promises. Discovery has to be *recorded* where things are met, or the
## codex is an empty list beside a full game. It has to persist, because a codex
## that forgets is a codex nobody opens twice. And an unmet entry has to still be
## listed, or the screen cannot say how much road is left - which is most of the
## reason anybody opens one.

var _failures: int = 0


func _ready() -> void:
	MetaState.codex_seen.clear()
	_check(MetaState.seen_count("enemy") == 0, "a cleared codex must know nothing")

	# Recorded, and only once.
	_check(MetaState.record_seen("enemy", "bogkin"), "meeting a thing must record it")
	_check(not MetaState.record_seen("enemy", "bogkin"),
		"and meeting it again must not count twice")
	_check(MetaState.has_seen("enemy", "bogkin"), "and it must be remembered")
	_check(MetaState.seen_count("enemy") == 1, "counted once, got %d"
		% MetaState.seen_count("enemy"))

	# Kinds do not bleed into each other: "affix:cruel" is not "enemy:cruel".
	MetaState.record_seen("affix", "cruel")
	_check(not MetaState.has_seen("enemy", "cruel"),
		"a kind prefix must keep the lists apart")
	_check(MetaState.seen_count("affix") == 1, "and each kind counts its own")

	# It survives a save and a reload, which is the whole point of a codex.
	MetaState.save_game()
	MetaState.codex_seen.clear()
	MetaState.load_save()
	_check(MetaState.has_seen("enemy", "bogkin"),
		"a discovery must survive being saved and read back")

	# Every section the screen offers must name a table that exists, or it
	# silently shows nothing and looks like a game with no content.
	var total: int = 0
	for section: Dictionary in CodexScreen.SECTIONS:
		var source: String = String(section["source"])
		var table: Variant = ContentDB.get(source)
		_check(table is Dictionary and not (table as Dictionary).is_empty(),
			"section '%s' must read a real table, '%s' gave nothing"
				% [String(section["title"]), source])
		if table is Dictionary:
			total += (table as Dictionary).size()
	_check(total > 20, "there must be something to find, counted %d" % total)
	print("[codex] %d sections, %d entries to find" % [CodexScreen.SECTIONS.size(), total])

	if _failures == 0:
		print("[codex] PASS - discoveries record once, keep their kinds, and "
			+ "survive a reload")
	else:
		printerr("[codex] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[codex] FAIL: %s" % why)
