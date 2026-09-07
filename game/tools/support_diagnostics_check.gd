extends Node

## This gate never writes the clipboard, a save, a file or a network request.
const PRIVATE_MARKER: String = "private-do-not-export-73951"
const TEST_SEED: int = 314159265
const EXPECTED_FIELDS: Dictionary = {
	"": ["format", "build", "platform", "viewport", "quality", "run"],
	"build": ["version", "engine"],
	"platform": ["os", "display_backend", "configured_renderer", "video_adapter"],
	"viewport": ["width", "height"],
	"quality": ["preset", "cast_shadows", "ground_shadows", "cloud_shadows",
		"particles", "foliage", "frame_cap", "brightness_lift", "smooth_pixel_art",
		"colourblind_mode", "touch_controls_visible"],
	"run": ["context", "seed", "phase", "scope", "act", "segment", "wave",
		"tier", "terrain", "weather", "totals"],
	"totals": ["distance", "combat_seconds", "planning_seconds", "enemies_defeated",
		"hero_deaths", "wounds_suffered", "raids_completed", "towers_built",
		"tower_upgrades", "towers_lost", "town_hits_taken", "town_damage_taken"],
}

var _failures: PackedStringArray = []


func _ready() -> void:
	MetaState.hold_saves()
	_test_clipboard_contract()
	_test_allowlist_and_purity()
	await _test_settings_integration()
	for failure: String in _failures:
		push_error("[support-diagnostics] " + failure)
	print("[support-diagnostics] %s - private-by-default, bounded snapshot and settings preview"
		% ("PASS" if _failures.is_empty() else "FAIL"))
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_clipboard_contract() -> void:
	_check(ContentDB.ui_texts.get("support_diagnostics") == SupportDiagnosticsPanel.COPY,
		"diagnostic copy must be registered by its authored content ID")
	# Verify the local engine API without reading or changing the real clipboard.
	_check(ClassDB.class_has_method("DisplayServer", "clipboard_set")
		and ClassDB.class_has_method("DisplayServer", "has_feature")
		and ClassDB.class_has_integer_constant("DisplayServer", "FEATURE_CLIPBOARD"),
		"local engine must support the guarded clipboard API")


func _test_allowlist_and_purity() -> void:
	var saved_settings: Dictionary = MetaState.settings.duplicate(true)
	var saved_graphics: Dictionary = Graphics._chosen.duplicate(true)
	var saved_active: bool = GameDirector.run_active
	var saved_phase: RunState.Phase = RunState.phase
	var saved_seed: int = RunState.run_seed
	var saved_tier: String = RunState.tier_id
	var saved_time: float = RunState.run_time_seconds
	var saved_damage: float = RunState.town_damage_taken
	MetaState.settings["support_test_private"] = {"token": PRIVATE_MARKER,
		"player_name": PRIVATE_MARKER, "room_code": PRIVATE_MARKER}
	Graphics._chosen["support_test_private"] = PRIVATE_MARKER
	GameDirector.run_active = false
	RunState.phase = RunState.Phase.PREPARATION
	var menu: Dictionary = SupportDiagnostics.capture(Vector2i(1280, 720))
	_check(menu["run"] == {"context": "none"},
		"a menu without a completed run must not report a fictional run")
	GameDirector.run_active = true
	RunState.phase = RunState.Phase.ROAD_BATTLE
	RunState.run_seed = TEST_SEED
	RunState.run_time_seconds = 123.456
	RunState.town_damage_taken = INF
	RunState.tier_id = PRIVATE_MARKER
	var before_settings: PackedByteArray = var_to_bytes(MetaState.settings)
	var before_graphics: PackedByteArray = var_to_bytes(Graphics._chosen)
	var report: Dictionary = SupportDiagnostics.capture(Vector2i(1280, 720))
	_check_keys(report, "")
	for key: String in ["build", "platform", "viewport", "quality", "run"]:
		_check_keys(report[key] as Dictionary, key)
	_check_keys((report["run"] as Dictionary)["totals"] as Dictionary, "totals")
	_check(report["viewport"] == {"width": 1280, "height": 720},
		"the report must preserve the actual viewport")
	var run: Dictionary = report["run"]
	_check(run["seed"] == TEST_SEED and run["phase"] == "road_battle"
		and run["context"] == "current", "seed and current phase must be reproducible")
	_check(run["tier"] == "unknown", "unknown content IDs must not export arbitrary strings")
	var totals: Dictionary = run["totals"]
	_check(is_equal_approx(float(totals["combat_seconds"]), 123.46)
		and totals["town_damage_taken"] == 0.0,
		"numeric values must be rounded and non-finite values made JSON-safe")
	var text: String = SupportDiagnostics.report_text(Vector2i(1280, 720))
	_check(not text.contains(PRIVATE_MARKER),
		"private settings and arbitrary run strings must never enter a report")
	_check(text.length() < 8192 and JSON.parse_string(text) is Dictionary,
		"the report must remain bounded and parse as ordinary JSON")
	_check(before_settings == var_to_bytes(MetaState.settings)
		and before_graphics == var_to_bytes(Graphics._chosen)
		and RunState.run_seed == TEST_SEED and RunState.run_time_seconds == 123.456,
		"collecting diagnostics must not mutate settings or run state")
	GameDirector.run_active = false
	RunState.phase = RunState.Phase.ENDED
	_check(SupportDiagnostics.capture(Vector2i.ONE)["run"]["context"] == "last_finished",
		"the retained end-of-run snapshot must be distinguished from an active run")
	_check(SupportDiagnostics._metadata("driver\n\t" + "x".repeat(256)).length()
		<= SupportDiagnostics.MAX_METADATA_LENGTH,
		"driver metadata must be length-bounded")
	MetaState.settings = saved_settings
	Graphics._chosen = saved_graphics
	GameDirector.run_active = saved_active
	RunState.phase = saved_phase
	RunState.run_seed = saved_seed
	RunState.tier_id = saved_tier
	RunState.run_time_seconds = saved_time
	RunState.town_damage_taken = saved_damage


func _test_settings_integration() -> void:
	var before: PackedByteArray = var_to_bytes(MetaState.settings)
	var settings := SettingsPanel.new()
	add_child(settings)
	await get_tree().process_frame
	var panel := settings.find_child("SupportDiagnostics", true, false) as SupportDiagnosticsPanel
	_check(panel != null, "Settings must contain the support report controls")
	if panel != null:
		_check(panel._preview.text.is_empty() and not panel._preview.visible
			and not panel._copy_button.visible,
			"opening Settings must not collect a report or expose a stale copy")
		var prepare := panel.get_node("PrepareReport") as Button
		prepare.pressed.emit()
		_check(panel._preview.visible and panel._preview.selection_enabled
			and not panel._preview.bbcode_enabled and not panel._preview.scroll_active
			and panel._copy_button.visible,
			"preparing must expose a selectable plain-text preview and copy button")
		var snapshot: String = panel._preview.text
		await get_tree().process_frame
		_check(snapshot == panel._preview.text,
			"the preview must remain the exact snapshot the player reviewed")
		var ancestor: Node = panel.get_parent()
		while ancestor != null and not ancestor is ScrollContainer:
			ancestor = ancestor.get_parent()
		_check(ancestor is ScrollContainer,
			"the preview must use the Data tab's existing themed scroll container")
		_check(not SupportDiagnosticsPanel.COPY.description.is_empty()
			and not SupportDiagnosticsPanel.COPY.copy_requested_note.is_empty(),
			"the privacy disclosure and clipboard caveat must be authored in data")
	_check(before == var_to_bytes(MetaState.settings),
		"opening and preparing diagnostics must not change saved settings")
	settings.queue_free()
	await get_tree().process_frame


func _check_keys(value: Dictionary, group: String) -> void:
	var expected: Array = (EXPECTED_FIELDS[group] as Array).duplicate()
	var actual: Array = value.keys()
	expected.sort()
	actual.sort()
	_check(expected == actual, "unexpected diagnostic schema field in '%s'" % group)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
