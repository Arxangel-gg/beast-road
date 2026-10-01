extends Node

## The codex records what the road showed you (owner decision, 2026-08-31).
##
## Three promises. Discovery has to be *recorded* where things are met, or the
## codex is an empty list beside a full game. It has to persist, because a codex
## that forgets is a codex nobody opens twice. And an unmet entry has to still be
## listed, or the screen cannot say how much road is left - which is most of the
## reason anybody opens one.

var _failures: int = 0

## The player's save file, byte for byte, put back before this exits.
var _save_before: String = ""
var _save_existed: bool = false


func _ready() -> void:
	# **The one tool that may not hold saves, and so has to clean up instead.**
	#
	# Every other gate that edits `MetaState` calls `hold_saves()` and is done -
	# see `save_guard_check`. This one cannot: the promise it exists to check is
	# that a discovery survives *being written to disk and read back*, and a held
	# save would make the reload return whatever was already in the file. So it
	# does the real round trip and hands the player their own bytes back
	# afterwards, on every exit path.
	_save_existed = FileAccess.file_exists(MetaState.SAVE_PATH)
	if _save_existed:
		var file: FileAccess = FileAccess.open(MetaState.SAVE_PATH, FileAccess.READ)
		if file != null:
			_save_before = file.get_as_text()
			file.close()

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

	await _test_the_pages()

	_restore_the_save()
	if _failures == 0:
		print("[codex] PASS - discoveries record once, keep their kinds, and "
			+ "survive a reload")
	else:
		printerr("[codex] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **The tabs and the search, driven on the real screen** (owner, 2026-09-22:
## tabs for the acts and for the spirits, and *"also add a search for the
## codex"*).
##
## Rows are counted off the built list rather than the filter being called
## directly, because the failure this catches is a page that *draws* nothing -
## an act whose entries no terrain names, a search that narrows to zero and
## says nothing about it. A helper returning the right array while the screen
## shows an empty panel is the shape `_test_the_pages` exists to refuse.
func _test_the_pages() -> void:
	# Everything met, so the search may reach descriptions and no page is empty
	# for want of discoveries rather than for want of content.
	for section: Dictionary in CodexScreen.SECTIONS:
		var table: Dictionary = ContentDB.get(String(section["source"]))
		for id: Variant in table.keys():
			MetaState.record_seen(String(section["kind"]), String(id))

	var screen := CodexScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	await get_tree().process_frame

	var all_rows: int = _rows_on(screen, CodexScreen.TAB_ALL)
	_check(all_rows > 20, "the whole book must list something, drew %d" % all_rows)

	# **Every act has a page of its own with bodies on it.** A range that stops
	# short is this project's most repeated fault - the relics, the Chronicle,
	# the campaign tiers, the wildlife, the affixes and the wave library each
	# shipped one - and it never errors, it simply draws an empty act.
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		var drawn: int = _rows_on(screen, act)
		_check(drawn > 0, "Act %d must have a page with something on it" % act)
		_check(drawn < all_rows,
			"Act %d drew the whole book (%d), so it is filtering nothing" % [act, drawn])

	var spirits: int = _rows_on(screen, CodexScreen.TAB_SPIRITS)
	_check(spirits >= ContentDB.wildlife().size(),
		"the journal must list every species, drew %d of %d"
			% [spirits, ContentDB.wildlife().size()])

	# The search narrows, and an empty one costs nothing.
	var animals: Array[WildlifeData] = ContentDB.wildlife()
	var wanted: String = animals[0].display_name
	screen.set("_tab", CodexScreen.TAB_SPIRITS)
	screen.set("_search", wanted.to_lower())
	screen.call("_refresh")
	await get_tree().process_frame
	var narrowed: int = _count_rows(screen)
	_check(narrowed > 0 and narrowed < spirits,
		"searching '%s' must narrow the journal, drew %d of %d"
			% [wanted, narrowed, spirits])

	screen.set("_search", "")
	screen.call("_refresh")
	await get_tree().process_frame
	_check(_count_rows(screen) == spirits,
		"clearing the search must put the whole journal back")

	await _test_bonded_only(screen, spirits)

	# A search that finds nothing says so, rather than drawing an empty panel.
	screen.set("_tab", CodexScreen.TAB_ALL)
	screen.set("_search", "zzzqqxnothingatall")
	screen.call("_refresh")
	await get_tree().process_frame
	_check(_count_rows(screen) == 0,
		"a search with no answer must draw no entries, drew %d" % _count_rows(screen))
	# And it must *say* so. An empty panel under a search box reads as a fault
	# in the screen rather than as an answer, which is the whole reason
	# `_nothing_found` exists - so the message is what is checked, not the
	# absence of rows.
	var said: bool = false
	for label: Node in _labels_under(screen.get("_rows") as Node):
		if (label as Label).text.to_lower().contains("nothing here answers"):
			said = true
	_check(said, "a search with no answer must say so on the page")

	# **An unfound entry does not leak its description to the search.** The page
	# deliberately withholds it; a search that matched it would read it out.
	var probe: EnemyData = null
	for value: Variant in ContentDB.enemies.values():
		var foe := value as EnemyData
		if foe != null and foe.description.length() > 12:
			probe = foe
			break
	if probe != null:
		MetaState.codex_seen.erase("enemy:%s" % probe.id)
		var word: String = probe.description.to_lower().split(" ")[0]
		screen.set("_search", word)
		screen.call("_refresh")
		await get_tree().process_frame
		var leaked: bool = false
		for row: Node in _row_nodes(screen):
			for label: Node in _labels_under(row):
				if (label as Label).text == probe.display_name:
					leaked = true
		_check(not leaked,
			"an unmet entry must not be found by a word in the text it is hiding")

	screen.set("_search", "")
	screen.queue_free()
	await get_tree().process_frame


## **The spirits' page can show only what is bonded** (owner, 2026-10-01).
## Driven through the toggle itself, pressed as a player presses it: a filter
## that worked when its flag was set by hand and was never reached by the
## button is the shape this project has paid for before.
func _test_bonded_only(screen: CodexScreen, spirits: int) -> void:
	var toggle := screen.get("_bonded_toggle") as CheckButton
	_check(toggle != null, "the spirits' page has no Bonded only toggle")
	if toggle == null:
		return
	screen.set("_tab", CodexScreen.TAB_ALL)
	screen.call("_refresh")
	await get_tree().process_frame
	_check(not toggle.visible, "the Bonded only toggle shows on a page that is not the spirits'")
	screen.set("_tab", CodexScreen.TAB_SPIRITS)
	screen.call("_refresh")
	await get_tree().process_frame
	_check(toggle.visible, "the Bonded only toggle is not shown on the spirits' page")

	var saved: Dictionary = MetaState.spirit_bonded.duplicate(true)
	MetaState.spirit_bonded.clear()
	toggle.button_pressed = true
	await get_tree().process_frame
	_check(_count_rows(screen) == 0,
		"with nothing bonded the toggle must show no species, drew %d" % _count_rows(screen))
	var said: bool = false
	for label: Node in _labels_under(screen.get("_rows") as Node):
		if (label as Label).text.to_lower().contains("no spirit walks with you"):
			said = true
	_check(said, "an empty bonded page must say why it is empty")

	# One variant of each of two species bonded: exactly two species drawn,
	# and opening one shows its one spirit and nothing it still owes.
	var animals: Array[WildlifeData] = ContentDB.wildlife()
	animals.sort_custom(func(a: WildlifeData, b: WildlifeData) -> bool:
		return a.display_name < b.display_name)
	var first: WildlifeData = animals[0]
	var second: WildlifeData = animals[animals.size() - 1]
	MetaState.spirit_bonded[SpiritBond.variants_of(first.id)[0]] = true
	MetaState.spirit_bonded[SpiritBond.variants_of(second.id)[0]] = true
	screen.call("_refresh")
	await get_tree().process_frame
	_check(_count_rows(screen) == 2,
		"two bonded species must draw two rows, drew %d" % _count_rows(screen))
	screen.set("_spirit_open", first.id)
	screen.call("_refresh")
	await get_tree().process_frame
	_check(_count_rows(screen) == 3,
		"an opened species under the toggle must show only its bonded spirit, drew %d rows"
			% _count_rows(screen))

	toggle.button_pressed = false
	await get_tree().process_frame
	screen.set("_spirit_open", "")
	screen.call("_refresh")
	await get_tree().process_frame
	_check(_count_rows(screen) == spirits,
		"turning the toggle off must put the whole journal back, drew %d of %d"
			% [_count_rows(screen), spirits])
	MetaState.spirit_bonded = saved


## How many rows a tab draws.
func _rows_on(screen: CodexScreen, tab: int) -> int:
	screen.set("_tab", tab)
	screen.call("_refresh")
	return _count_rows(screen)


func _count_rows(screen: CodexScreen) -> int:
	return _row_nodes(screen).size()


## The list's own children, minus the headings and the standing note - what is
## counted is entries, and a page of two headings is an empty page.
func _row_nodes(screen: CodexScreen) -> Array[Node]:
	var out: Array[Node] = []
	var list := screen.get("_rows") as VBoxContainer
	if list == null:
		return out
	for child: Node in list.get_children():
		if child.is_queued_for_deletion():
			continue
		if child is Label:
			continue
		out.append(child)
	return out


func _labels_under(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels_under(child))
	return out


## Puts the player's file back exactly as it was found.
##
## Held from here on as well, so nothing that runs during shutdown - an autosave
## on exit, a settings write - can put the probe entries back after this.
func _restore_the_save() -> void:
	MetaState.hold_saves()
	if not _save_existed:
		if FileAccess.file_exists(MetaState.SAVE_PATH):
			DirAccess.remove_absolute(
				ProjectSettings.globalize_path(MetaState.SAVE_PATH))
		return
	if _save_before.is_empty():
		return
	var file: FileAccess = FileAccess.open(MetaState.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		_failures += 1
		printerr("[codex] FAIL: could not put the player's save back")
		return
	file.store_string(_save_before)
	file.close()
	# And back into memory, so nothing downstream is looking at probe state.
	MetaState.load_save()


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[codex] FAIL: %s" % why)
