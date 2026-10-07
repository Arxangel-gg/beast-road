extends Node

## The Guide, the lore and the achievements (owner brief, 2026-09-12): what
## the main menu's Guide shows, and the three data sets behind it.
##
## What this holds:
##
## - every guide section sits in a category the screen has a tab for, has a
##   title and a body, and its picture is on disk - a section that names a
##   picture nobody took shows a hole;
## - every lore entry unlocks on an act the road has, and says something;
## - **every achievement names a statistic the account keeps.** An
##   achievement is a threshold on a number `MetaState.stat` reads; a
##   misspelt key reads zero forever and the achievement can never unlock,
##   silently. The keys are listed here, beside the reader, so adding a
##   statistic means adding it twice on purpose;
## - the screen opens every category without complaint;
## - **a picture opens larger on a tap and closes on the next tap, on it or
##   outside it** (2026-09-30; the tap on the picture itself since
##   2026-10-06, the owner's convenience ask that two sessions had read as a
##   bug to reproduce): never to the whole screen, never on a drag.

## Mirror of the keys `MetaState.stat` answers. Keep the two together.
const STATS: Array[String] = ["runs_started", "runs_won", "highest_act", "bosses_felled",
	"total_enemies_killed", "camps_razed", "forks_opened", "war_camps_razed", "rifts_closed",
	"dungeons_finished", "fish_caught_total", "swims", "coop_runs", "spirits_bonded",
	"hero_level", "ascension", "best_distance", "codex_share", "codex_mastered",
	"perfect_evades", "perfect_guards", "heralds_felled"]

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_test_sections()
	_test_lore()
	_test_achievements()
	await _test_the_screen()
	# A runtime error inside the screen test stops it and nothing else, so the
	# count of checks is not a proof that they ran (2026-09-22): the probe
	# stamps its own end.
	_check(_probe_done, "the viewport probe never reached its end - look for a SCRIPT ERROR above")
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[guide] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[guide] PASS - %d checks: %d sections, %d lore entries, %d achievements" % [
		_checked, ContentDB.guide_sections.size(), ContentDB.lore.size(), ContentDB.achievements.size()])
	get_tree().quit(0)


func _test_sections() -> void:
	_check(ContentDB.guide_sections.size() >= 30, "the guide has its sections (%d)" % ContentDB.guide_sections.size())
	var categories: Dictionary = {}
	for id: Variant in ContentDB.guide_sections:
		var section: GuideSectionData = ContentDB.guide_sections[id] as GuideSectionData
		if section == null:
			_check(false, "section %s is not a GuideSectionData" % String(id))
			continue
		_check(GuideScreen.CATEGORY_ORDER.has(section.category),
			"section %s sits in a category with a tab: '%s'" % [section.id, section.category])
		categories[section.category] = true
		_check(not section.title.is_empty() and section.body.strip_edges().length() >= 40,
			"section %s has a title and a real body" % section.id)
		_check(not section.image.is_empty() and ResourceLoader.exists(section.image),
			"section %s's picture is on disk: %s" % [section.id, section.image])
	for name: String in ["Basics", "Fighting", "Building", "The Road", "Fishing & Water", "Healing",
			"Resources", "Items & Gear", "Companions", "Camps & Rifts", "Co-op", "Glossary"]:
		_check(categories.has(name), "the '%s' tab has at least one section" % name)


func _test_lore() -> void:
	_check(ContentDB.lore.size() >= 20, "the world has its lore (%d entries)" % ContentDB.lore.size())
	var acts_covered: Dictionary = {}
	for id: Variant in ContentDB.lore:
		var entry: LoreEntryData = ContentDB.lore[id] as LoreEntryData
		if entry == null:
			_check(false, "lore %s is not a LoreEntryData" % String(id))
			continue
		_check(entry.unlock_act >= 0 and entry.unlock_act <= Balance.ACT_COUNT,
			"lore %s unlocks on an act the road has (%d)" % [entry.id, entry.unlock_act])
		_check(not entry.title.is_empty() and entry.body.strip_edges().length() >= 60,
			"lore %s says something" % entry.id)
		acts_covered[entry.unlock_act] = true
	_check(acts_covered.has(0), "some lore is known from the start")
	_check(acts_covered.size() >= 5, "the lore unlocks across the road (%d acts)" % acts_covered.size())


func _test_achievements() -> void:
	_check(ContentDB.achievements.size() >= 12, "there are achievements (%d)" % ContentDB.achievements.size())
	for key: String in STATS:
		# The mirror must be honest: a key here that the reader does not answer
		# would let a broken achievement through.
		MetaState.stat(key)
	for id: Variant in ContentDB.achievements:
		var achievement: AchievementData = ContentDB.achievements[id] as AchievementData
		if achievement == null:
			_check(false, "achievement %s is not an AchievementData" % String(id))
			continue
		_check(STATS.has(achievement.stat),
			"achievement %s names a statistic the account keeps: '%s'" % [achievement.id, achievement.stat])
		_check(achievement.threshold > 0.0, "achievement %s asks for something (%s)" % [achievement.id, achievement.threshold])
		_check(not achievement.title.is_empty() and not achievement.description.is_empty(),
			"achievement %s has a title and a line" % achievement.id)
	# A statistic at its threshold unlocks; below, it does not.
	var sample: AchievementData = null
	for id: Variant in ContentDB.achievements:
		var candidate: AchievementData = ContentDB.achievements[id] as AchievementData
		if candidate != null and candidate.stat == "camps_razed":
			sample = candidate
			break
	if sample != null:
		var was: int = MetaState.camps_razed
		MetaState.camps_razed = int(sample.threshold) - 1
		_check(MetaState.stat("camps_razed") < sample.threshold, "one short does not reach the threshold")
		MetaState.camps_razed = int(sample.threshold)
		_check(MetaState.stat("camps_razed") >= sample.threshold, "the threshold is reached at the number")
		MetaState.camps_razed = was


func _test_the_screen() -> void:
	var screen := GuideScreen.new()
	add_child(screen)
	await get_tree().process_frame
	for category: String in GuideScreen.CATEGORY_ORDER:
		screen.open(category)
		await get_tree().process_frame
	_check(true, "every category opens")
	screen.open(GuideScreen.CATEGORY_ORDER[0])
	for _f: int in 3:
		await get_tree().process_frame
	var pictures: Array[TextureRect] = []
	for node: Node in screen.find_children("*", "TextureRect", true, false):
		var rect := node as TextureRect
		if rect.gui_input.get_connections().size() > 0 and rect.texture != null:
			pictures.append(rect)
	_check(not pictures.is_empty(), "no picture in the Guide opens larger")
	if not pictures.is_empty():
		var picture: TextureRect = pictures[0]
		var at: Vector2 = picture.get_global_rect().get_center()
		# A drag is not a tap.
		screen._on_picture_input(_click(at, true), picture)
		screen._on_picture_input(_click(at + Vector2(0.0, 60.0), false), picture)
		_check(not screen.picture_open(), "a drag across a picture opened it")
		screen._on_picture_input(_click(at, true), picture)
		screen._on_picture_input(_click(at, false), picture)
		_check(screen.picture_open(), "a tap on a picture did not open it larger")
		await get_tree().process_frame
		var big: TextureRect = screen._zoom_picture
		var screen_size: Vector2 = screen.get_viewport().get_visible_rect().size
		_check(big.texture == picture.texture, "the enlarged picture is not the one tapped")
		_check(big.size.x > picture.size.x and big.size.x <= screen_size.x * Balance.GUIDE_ZOOM_SHARE + 1.0
			and big.size.y <= screen_size.y * Balance.GUIDE_ZOOM_SHARE + 1.0,
			"the enlarged picture is %s on a %s screen - larger than the list's, never the whole screen" % [big.size, screen_size])
		big.gui_input.emit(_click(big.get_global_rect().get_center(), false))
		_check(not screen.picture_open(), "a tap on the enlarged picture did not close it")
		screen.open_picture(picture.texture)
		var outside := screen._zoom.get_node("Outside") as ColorRect
		outside.gui_input.emit(_click(Vector2(4.0, 4.0), false))
		_check(not screen.picture_open(), "a tap outside the enlarged picture did not close it")
		screen.open_picture(picture.texture)
		screen.close()
		_check(not screen.picture_open(), "closing the Guide left a picture open over nothing")
	# **Through the viewport, as a player's mouse and a player's finger do**
	# (written to reproduce "Guide expanded image zooms back out when clicking
	# it", which turned out to be the owner's *ask* - see the file header - and
	# kept because the picking it proves is real). The checks above hand
	# events to the handlers, which proves the
	# functions and not the picking: a control that is not where it is drawn,
	# or one under another that takes the click, passes them and fails a
	# player. These push real presses at the screen and ask what happened.
	if not pictures.is_empty():
		screen.open(GuideScreen.CATEGORY_ORDER[0])
		for _f: int in 3:
			await get_tree().process_frame
		# Reopening rebuilt the list, so the pictures above are freed: the
		# first cut of this probe read one and aborted before a check ran -
		# and the gate printed PASS over it.
		var fresh: Array[TextureRect] = []
		for node: Node in screen.find_children("*", "TextureRect", true, false):
			var rect := node as TextureRect
			if rect.gui_input.get_connections().size() > 0 and rect.texture != null:
				fresh.append(rect)
		_check(not fresh.is_empty(), "no picture in the reopened Guide opens larger")
		if fresh.is_empty():
			screen.queue_free()
			await get_tree().process_frame
			return
		var picture: TextureRect = fresh[0]
		# Scrolled into view first: a picture below the window's edge is one
		# no click can land on, and the first cut of this probe clicked the
		# first picture of the category wherever its list had put it.
		var list := screen.get("_scroll") as ScrollContainer
		if list != null:
			list.ensure_control_visible(picture)
			for _f: int in 3:
				await get_tree().process_frame
		var at: Vector2 = picture.get_global_rect().get_center()
		var window: Rect2 = get_viewport().get_visible_rect()
		_check(window.has_point(at), "the picture to click sits at %s, outside the %s window" % [at, window])
		await _real_click(at)
		_check(screen.picture_open(), "a real click on a picture did not open it larger (over %s at %s)"
			% [_hovered_name(), at])
		if screen.picture_open():
			var big_at: Vector2 = screen._zoom_picture.get_global_rect().get_center()
			await _real_click(big_at)
			_check(not screen.picture_open(), "a real click on the enlarged picture did not close it")
			await _real_click(at)
			_check(screen.picture_open(), "a real click did not open the picture a second time")
			await _real_click(Vector2(4.0, 4.0))
			_check(not screen.picture_open(), "a real click outside the enlarged picture did not close it")
		# A finger: a touch the engine turns into the mouse a phone's tap is.
		await _real_tap(at)
		_check(screen.picture_open(), "a real tap on a picture did not open it larger")
		if screen.picture_open():
			var big_at: Vector2 = screen._zoom_picture.get_global_rect().get_center()
			await _real_tap(big_at)
			_check(not screen.picture_open(), "a real tap on the enlarged picture did not close it")
			await _real_tap(at)
			_check(screen.picture_open(), "a real tap did not open the picture a second time")
			await _real_tap(Vector2(4.0, 4.0))
			_check(not screen.picture_open(), "a real tap outside the enlarged picture did not close it")
		screen.close()
	_probe_done = true
	screen.queue_free()
	await get_tree().process_frame


## What the viewport thinks the pointer is over, for a failure line.
func _hovered_name() -> String:
	var over: Control = get_viewport().gui_get_hovered_control()
	return String(over.get_path()) if over != null else "nothing"


## A press and a release at a screen point, through the viewport's own picking.
func _real_click(at: Vector2) -> void:
	# In the canvas's own coordinates: the project stretches `canvas_items`, so
	# a logical point pushed as a window point lands somewhere else entirely -
	# the first cut of this probe clicked nothing and said so.
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion, true)
	await get_tree().process_frame
	get_viewport().push_input(_click(at, true), true)
	await get_tree().process_frame
	get_viewport().push_input(_click(at, false), true)
	for _f: int in 2:
		await get_tree().process_frame


## A finger down and up at a screen point, through `Input` so the engine
## emulates the mouse from it exactly as it does for a phone's tap.
func _real_tap(at: Vector2) -> void:
	# A finger arrives in window pixels, so the canvas point is taken out
	# through the stretch the window applies.
	var in_window: Vector2 = get_viewport().get_final_transform() * at
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = in_window
		touch.pressed = down
		Input.parse_input_event(touch)
		for _f: int in 2:
			await get_tree().process_frame
	for _f: int in 2:
		await get_tree().process_frame


func _click(at: Vector2, down: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	event.global_position = at
	return event


var _probe_done: bool = false


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[guide] " + message)
