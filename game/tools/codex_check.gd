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

	# **The Walk records nothing** (owner, 2026-10-06: a new Warden's codex is
	# empty). Every recorder - a body's spawn, an animal's arrival, a sky rolled
	# - goes through this one door, so the guard is held here and the Walk's
	# own gate holds it on the real valley.
	var walking_was: bool = RunState.walking
	RunState.walking = true
	_check(not MetaState.record_seen("enemy", "walk_probe_body"),
		"a body met on the Walk must record nothing")
	_check(not MetaState.has_seen("enemy", "walk_probe_body"),
		"the valley wrote a body into the codex")
	RunState.walking = false
	_check(MetaState.record_seen("enemy", "walk_probe_body"),
		"off the Walk the same body must record")
	MetaState.codex_seen.erase("enemy:walk_probe_body")
	RunState.walking = walking_was

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

	_test_every_page_has_pictures()
	_test_mastery()
	await _test_the_pages()

	_restore_the_save()
	if _failures == 0:
		print("[codex] PASS - discoveries record once, keep their kinds, and "
			+ "survive a reload")
	else:
		printerr("[codex] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **Every entry on every page has a picture on disk** (owner, 2026-10-07:
## *"Weather and Marks of the Promoted in the Codex need images"*). Weather had
## no art path at all and the marks named a folder nothing had ever been put
## in, so two whole pages were empty frames - and nothing failed, because a
## missing texture is simply not drawn.
func _test_every_page_has_pictures() -> void:
	for section: Dictionary in CodexScreen.SECTIONS:
		var table: Variant = ContentDB.get(String(section["source"]))
		if not (table is Dictionary):
			continue
		var missing: PackedStringArray = []
		for value: Variant in (table as Dictionary).values():
			var entry := value as GameData
			if entry == null:
				continue
			var path: String = entry.get_sprite_path()
			if path.is_empty() or not ResourceLoader.exists(path):
				missing.append(entry.id)
		_check(missing.is_empty(), "the %s page has no picture for %s" % [String(section["title"]),
			", ".join(missing.slice(0, 8))])


## **Codex mastery** (triage of 2026-10-07): kills climb an enemy's entry
## through its tiers by its category; the Walk and a sandbox count nothing; the
## count survives a real save and reads back clean; the achievement's statistic
## counts what is mastered; the row says the tier and, once studied, how the
## enemy fights; and a body falling is counted where it falls.
func _test_mastery() -> void:
	var held: Dictionary = MetaState.codex_kills.duplicate()
	MetaState.codex_kills.clear()
	var breed: EnemyData = null
	var boss: EnemyData = null
	var plated: EnemyData = null
	var ids: Array = ContentDB.enemies.keys()
	ids.sort()
	for id: Variant in ids:
		var foe := ContentDB.enemies[id] as EnemyData
		if foe == null:
			continue
		if breed == null and foe.category == EnemyData.Category.BREED:
			breed = foe
		if boss == null and foe.category == EnemyData.Category.BOSS:
			boss = foe
		if plated == null and foe.hide == EnemyData.Hide.ARMOUR:
			plated = foe
	_check(breed != null and boss != null and plated != null, "the roster lacks a breed, a boss or a plated body")
	if breed == null or boss == null or plated == null:
		return
	_check(MetaState.codex_tier(breed) == MetaState.CodexTier.ENCOUNTERED, "an unfelled breed is past Encountered")
	MetaState.note_kill(breed.id)
	_check(MetaState.codex_tier(breed) == MetaState.CodexTier.KILLED, "one felled is not Killed")
	for _i: int in Balance.CODEX_STUDIED_KILLS[0] - 1:
		MetaState.note_kill(breed.id)
	_check(MetaState.codex_tier(breed) == MetaState.CodexTier.STUDIED,
		"%d felled is not Studied" % Balance.CODEX_STUDIED_KILLS[0])
	for _i: int in Balance.CODEX_MASTERED_KILLS[0] - Balance.CODEX_STUDIED_KILLS[0] - 1:
		MetaState.note_kill(breed.id)
	_check(MetaState.codex_tier(breed) == MetaState.CodexTier.STUDIED, "one short of mastery is Mastered")
	MetaState.note_kill(breed.id)
	_check(MetaState.codex_tier(breed) == MetaState.CodexTier.MASTERED,
		"%d felled is not Mastered" % Balance.CODEX_MASTERED_KILLS[0])
	_check(CodexScreen.mastery_line(breed).begins_with("Mastered"), "the row does not say Mastered")
	for _i: int in Balance.CODEX_MASTERED_KILLS[2]:
		MetaState.note_kill(boss.id)
	_check(MetaState.codex_tier(boss) == MetaState.CodexTier.MASTERED,
		"a boss felled %d times is not Mastered" % Balance.CODEX_MASTERED_KILLS[2])
	_check(is_equal_approx(MetaState.stat("codex_mastered"), 2.0),
		"the achievement's statistic counts %.0f mastered, not 2" % MetaState.stat("codex_mastered"))
	for _i: int in Balance.CODEX_STUDIED_KILLS[0]:
		MetaState.note_kill(plated.id)
	_check(" ".join(CodexScreen.studied_traits(plated)).contains("plated"),
		"a studied plated body does not say it is plated")
	# The Walk and a sandbox reach nothing of the account.
	var counted: int = MetaState.codex_kills_of(plated.id)
	RunState.walking = true
	MetaState.note_kill(plated.id)
	RunState.walking = false
	RunState.sandbox = true
	MetaState.note_kill(plated.id)
	RunState.sandbox = false
	_check(MetaState.codex_kills_of(plated.id) == counted, "the Walk or a sandbox counted a kill")
	# A real save: the count back exactly, a ghost breed dropped, the ceiling held.
	MetaState.codex_kills["no_such_breed"] = 7
	MetaState.codex_kills[plated.id] = Balance.CODEX_KILLS_CEILING * 3
	MetaState.save_game()
	MetaState.codex_kills.clear()
	MetaState.load_save()
	_check(MetaState.codex_kills_of(breed.id) == Balance.CODEX_MASTERED_KILLS[0],
		"the save read back %d felled, not %d" % [MetaState.codex_kills_of(breed.id), Balance.CODEX_MASTERED_KILLS[0]])
	_check(not MetaState.codex_kills.has("no_such_breed"), "a breed the content does not name came back from the save")
	_check(MetaState.codex_kills_of(plated.id) == Balance.CODEX_KILLS_CEILING, "a count past the ceiling came back past it")
	# A body falling is counted where it falls.
	var source: String = FileAccess.get_file_as_string("res://scenes/battlefield/enemy.gd")
	var died: int = source.find("func _on_died(")
	var next: int = source.find("\nfunc ", died + 4)
	_check(died >= 0 and source.substr(died, next - died).contains("MetaState.note_kill(data.id)"),
		"a body's death does not count it for the codex")
	MetaState.codex_kills = held


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

		# **And an unmet entry is "???", never its name** (owner, 2026-10-07: unknown
		# entries in the codex should have a placeholder for their names). Found by
		# its own name, it is not found at all - a search that answered to the name
		# would be the page saying what it is hiding.
		screen.set("_search", probe.display_name.to_lower())
		screen.call("_refresh")
		await get_tree().process_frame
		var named_rows: int = 0
		for row: Node in _row_nodes(screen):
			for label: Node in _labels_under(row):
				if (label as Label).text == probe.display_name:
					named_rows += 1
		_check(named_rows == 0, "an unmet %s answered a search for its own name" % probe.id)
		screen.set("_search", "")
		screen.call("_refresh")
		await get_tree().process_frame
		var unknowns: int = 0
		var leaked_name: bool = false
		for row: Node in _row_nodes(screen):
			for label: Node in _labels_under(row):
				if (label as Label).text == CodexScreen.UNKNOWN_NAME:
					unknowns += 1
				elif (label as Label).text == probe.display_name:
					leaked_name = true
		_check(unknowns >= 1, "an unmet entry must read %s on the page" % CodexScreen.UNKNOWN_NAME)
		_check(not leaked_name, "an unmet %s still shows its name on the page" % probe.id)

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
	# Stepped on purpose: the pictures are mid-loop, as they are whenever a slow
	# frame lands between a refresh and a read.
	screen.call("_process", 1.0)
	_check(_count_rows(screen) == 2,
		"two bonded species must draw two rows, drew %d" % _count_rows(screen))
	# **The frame says the rarity of the best bond** (owner, 2026-10-06). The
	# first's picture is framed in its one bond's tint; bonding a rarer variant
	# re-frames it in the rarer one's; a species nothing is bonded of keeps the
	# book's own frame.
	var first_variant: String = SpiritBond.variants_of(first.id)[0]
	var first_tint: Color = FrameKit.tint_of(_species_art(screen, first))
	_check(first_tint.is_equal_approx(screen.bond_frame_tint(
			SpiritBond.rarity_of(first_variant), SpiritBond.shiny_of(first_variant))),
		"a bonded species' picture is framed in %s, not its bond's rarity" % first_tint)
	var rarest: String = first_variant
	for variant: String in SpiritBond.variants_of(first.id):
		if SpiritBond.rarity_of(variant) > SpiritBond.rarity_of(rarest):
			rarest = variant
	MetaState.spirit_bonded[rarest] = true
	screen.call("_refresh")
	await get_tree().process_frame
	var rarest_tint: Color = screen.bond_frame_tint(SpiritBond.rarity_of(rarest), SpiritBond.shiny_of(rarest))
	_check(rarest != first_variant and FrameKit.tint_of(_species_art(screen, first)).is_equal_approx(rarest_tint),
		"a rarer bond did not re-frame the species' picture (%s against %s)"
			% [FrameKit.tint_of(_species_art(screen, first)), rarest_tint])
	_check(not rarest_tint.is_equal_approx(first_tint), "two rarities wear one frame")
	MetaState.spirit_bonded.erase(rarest)
	toggle.button_pressed = false
	screen.call("_refresh")
	await get_tree().process_frame
	var unbonded: WildlifeData = animals[1]
	_check(FrameKit.tint_of(_species_art(screen, unbonded)).is_equal_approx(FrameKit.CORNER),
		"a species nothing is bonded of wears a rarity's frame")
	toggle.button_pressed = true
	screen.call("_refresh")
	await get_tree().process_frame
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
## The picture on a species' row, found by the art it draws.
## **Any frame of its loop, not only the painting.** The codex steps every
## picture through its idle a few times a second, so a check that looked for
## the base painting found nothing whenever a step landed between the refresh
## and the read - a slow runner's frame - and read the book's own frame. It
## failed v0.75.0's release once the first species alphabetically was animated.
func _species_art(screen: CodexScreen, kind: WildlifeData) -> TextureRect:
	var path: String = kind.get_sprite_path()
	var frames: Array[Texture2D] = GameData.load_idle_frames(path)
	for node: Node in (screen.get("_rows") as Node).find_children("*", "TextureRect", true, false):
		var art := node as TextureRect
		if art != null and art.texture != null and (art.texture == load(path) or frames.has(art.texture)):
			return art
	return null


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
