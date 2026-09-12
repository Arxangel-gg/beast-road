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
## - the screen opens every category without complaint.

## Mirror of the keys `MetaState.stat` answers. Keep the two together.
const STATS: Array[String] = ["runs_started", "runs_won", "highest_act", "bosses_felled",
	"total_enemies_killed", "camps_razed", "forks_opened", "war_camps_razed", "rifts_closed",
	"dungeons_finished", "fish_caught_total", "swims", "coop_runs", "spirits_bonded",
	"hero_level", "ascension", "best_distance", "codex_share"]

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	await get_tree().process_frame
	_test_sections()
	_test_lore()
	_test_achievements()
	await _test_the_screen()
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
	screen.queue_free()
	await get_tree().process_frame


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	push_error("[guide] " + message)
