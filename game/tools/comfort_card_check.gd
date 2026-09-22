extends Node

## The first-run comfort card writes nothing unless a slider moved.
##
##   godot --headless --path game res://tools/comfort_card_check.tscn
##
## `docs/ROAD_TO_1_0.md` §7.2 asked for the flash scale to be surfaced on the
## first launch rather than buried in a tab. All three comfort scales are
## offered before the first road now, and the whole risk of doing that is in one
## sentence: **a card shown to everybody must not change everybody's save.**
##
## **The ways this goes wrong, hardest first:**
##
## - **It writes on open.** A card that set what it found would rewrite the save
##   of every player who dismissed it - three values they already had, for a
##   screen they never touched. Checked by serializing the whole account either
##   side of an untouched card and insisting the two are byte-identical, which
##   also catches a new settings key being declared for it.
## - **It stores "seen".** `MetaState._read_settings` drops undeclared keys, so
##   a flag has to join the defaults, and then every save on the machine grows a
##   key on its next write. Whether to offer is *derived* from `runs_started`,
##   which the save already keeps.
## - **It restates a key, a range or a step.** Two screens draw these scales now.
##   A card holding its own copy is a card that can disagree with Settings about
##   what a slider does - the failure an Arcane node's reach shipped with, and
##   the one the beast scope's unclamped shake shipped with.
## - **A slider that reaches nothing.** The point of the card is that moving one
##   changes the game, so each is moved and read back through the function the
##   game itself asks.

var _failures: int = 0
var _checks: int = 0
## Which tests reached their own last line. A GDScript runtime error stops the
## function it is in and nothing else, so a test that aborts halfway would
## otherwise read exactly like a test that passed - which `hold_check` and
## `coop_heroes_check` have each been caught by once.
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_offer_is_derived()
	_test_a_dismissed_card_writes_nothing()
	_test_every_slider_reaches_the_game()
	_test_the_card_and_the_settings_agree()
	for stage: String in ["derived", "silent", "reaches", "agree"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check "
				+ "it had not made yet is a check nobody made") % stage)
	MetaState.resume_saves()
	if _failures == 0:
		print(("[comfort] PASS - %d checks: offered only before a first road, "
			+ "dismissed without a byte written, every slider reaching the "
			+ "game, and one definition shared with Settings") % _checks)
	else:
		push_error("[comfort] FAIL - %d problem(s)" % _failures)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 8:
		await get_tree().process_frame
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("[comfort] " + why)


func _card() -> ComfortCard:
	var card := ComfortCard.new()
	add_child(card)
	return card


## **Derived from a statistic the save already keeps**, so nothing new is
## stored and the offer re-arms by itself after `Erase progress` and for a
## Warden in a fresh slot.
func _test_the_offer_is_derived() -> void:
	var kept: int = MetaState.runs_started
	MetaState.runs_started = 0
	_check(ComfortCard.should_offer(),
		"a Warden who has never taken a road must be offered the card")
	MetaState.runs_started = 1
	_check(not ComfortCard.should_offer(),
		"a Warden who has taken a road must not be shown it again")
	MetaState.runs_started = 97
	_check(not ComfortCard.should_offer(),
		"a veteran must not be shown it either")
	MetaState.runs_started = kept
	# And no flag was invented to answer that question.
	var text: String = MetaState.serialized_save()
	var parsed: Variant = JSON.parse_string(text)
	var settings: Dictionary = {}
	if parsed is Dictionary:
		settings = (parsed as Dictionary).get("settings", {}) as Dictionary
	for key: Variant in settings.keys():
		var name: String = String(key)
		_check(not name.contains("comfort"),
			("the save carries a '%s' key - the offer must be derived, because "
				+ "a declared flag is a byte every existing account gains for a "
				+ "card its owner never saw") % name)
	_reached["derived"] = true


## **The bound.** Open the real card, close it, and the account is where it was.
func _test_a_dismissed_card_writes_nothing() -> void:
	var kept: Dictionary = MetaState.settings.duplicate(true)
	# **Away from the defaults first.** On a clean profile the settings already
	# hold what the card would write, so a card that set every value on open
	# produced a byte-identical save and this check passed with the fault in it.
	# Moved off the defaults, a card that writes anything at all is caught.
	for row: Dictionary in UserSettings.COMFORT_ROWS:
		UserSettings.set_value(String(row["key"]), 0.4)
	var before: String = MetaState.serialized_save()
	var card: ComfortCard = _card()
	card.open()
	_check(card.visible, "the card must be visible once opened")
	card.close()
	_check(not card.visible, "and hidden once closed")
	var after: String = MetaState.serialized_save()
	_check(before == after,
		("opening and dismissing the card changed the save (%d bytes -> %d) - "
			+ "it must write nothing at all unless a slider moved")
			% [before.length(), after.length()])
	# And it knows it was untouched, which is what decides whether it saves at
	# all. A card that set a value on open with the same number in it would
	# leave the save identical and still have written - this is the half of the
	# bound a byte comparison cannot see.
	_check(not bool(card.get("_touched")),
		"a dismissed card reported itself touched, so it would have saved")
	for row: Dictionary in UserSettings.COMFORT_ROWS:
		_check(is_equal_approx(UserSettings.number(String(row["key"]), 1.0), 0.4),
			("opening the card moved '%s' to %.2f - it may read a value and "
				+ "must never write one") % [row["key"],
				UserSettings.number(String(row["key"]), 1.0)])
	card.queue_free()
	MetaState.settings = kept
	_reached["silent"] = true


## Each slider moved through its own `value_changed`, and read back through the
## function the *game* asks - never off the setting it wrote, which would pass
## on a card that had invented a key of its own.
func _test_every_slider_reaches_the_game() -> void:
	var kept: Dictionary = MetaState.settings.duplicate(true)
	var card: ComfortCard = _card()
	card.open()
	var wanted: float = 0.25
	for row: Dictionary in UserSettings.COMFORT_ROWS:
		var slider: HSlider = _slider_for(card, String(row["key"]))
		_check(slider != null, "the card has no slider for '%s'" % row["key"])
		if slider == null:
			continue
		slider.value = wanted
		slider.value_changed.emit(wanted)
	_check(is_equal_approx(JuiceDirector.shake_scale(), wanted),
		"the shake slider reached %.2f rather than %.2f"
			% [JuiceDirector.shake_scale(), wanted])
	_check(is_equal_approx(JuiceDirector.flash_scale(), wanted),
		"the flash slider reached %.2f rather than %.2f"
			% [JuiceDirector.flash_scale(), wanted])
	# Density is read as a question rather than a number, so it is asked one:
	# at a quarter an ordinary number is refused far more often than not.
	var drawn: int = 0
	for _try: int in 400:
		if JuiceDirector.wants_number(false):
			drawn += 1
	_check(drawn < 160,
		("the damage-number slider reached nothing - %d of 400 ordinary numbers "
			+ "were still drawn at a quarter density") % drawn)
	# A touched card saves; that half matters too, or the choice is lost on quit.
	var before: String = MetaState.serialized_save()
	card.close()
	_check(MetaState.serialized_save() == before,
		"closing a touched card must not change the account beyond the settings")
	card.queue_free()
	MetaState.settings = kept
	_reached["reaches"] = true


## **One definition, read off the built controls.** The settings panel and the
## card both build from `UserSettings.COMFORT_ROWS`; this reads the sliders the
## card actually stood up, so a card that hard-coded a range would fail even
## while the table beside it was right.
func _test_the_card_and_the_settings_agree() -> void:
	var card: ComfortCard = _card()
	card.open()
	_check(UserSettings.COMFORT_ROWS.size() == 3,
		"three comfort scales are expected, the table holds %d"
			% UserSettings.COMFORT_ROWS.size())
	for row: Dictionary in UserSettings.COMFORT_ROWS:
		var key: String = String(row["key"])
		var slider: HSlider = _slider_for(card, key)
		if slider == null:
			continue
		_check(is_equal_approx(slider.min_value, float(row["minimum"]))
			and is_equal_approx(slider.max_value, float(row["maximum"]))
			and is_equal_approx(slider.step, float(row["step"])),
			("'%s' is drawn %.2f-%.2f by %.2f against the table's %.2f-%.2f by "
				+ "%.2f") % [key, slider.min_value, slider.max_value, slider.step,
				float(row["minimum"]), float(row["maximum"]), float(row["step"])])
	card.close()
	card.queue_free()
	# And the one place that reads this setting for the walk reads it through
	# the same door every other scope does. A source walk, because the fault is
	# an *omission* - a raw read added beside this one is silently unclamped.
	var beast: String = FileAccess.get_file_as_string(
		"res://scenes/run/beast_scope.gd")
	_check(not beast.contains("settings.get(UserSettings.SHAKE_KEY"),
		("the beast scope reads the shake setting raw - the slider reaches 1.5 "
			+ "and every other consumer clamps to 1, so a player who turned it "
			+ "up got one answer on the walk and another on the road"))
	_reached["agree"] = true


func _slider_for(card: ComfortCard, key: String) -> HSlider:
	var holder: Node = card.find_child(key, true, false)
	if holder == null:
		return null
	return holder.find_child("Slider", true, false) as HSlider
