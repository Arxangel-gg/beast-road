extends Node

## Holds `CrashWatch`: a session that ends without saying so is noticed at the
## next launch, what is reported about it is allowlisted and scrubbed, and the
## menu offers it for review rather than copying it blind.
##
## Everything here runs against a fixture folder through `CrashWatch.root`, the
## seam `MetaState.slot_root` set the pattern for, so no marker or log in the
## profile the sweep shares is ever read or written. This gate never touches the
## clipboard.

const FIXTURE: String = "user://crash_watch_fixture"
const PRIVATE_NAME: String = "Alyndra7731"

var _failures: PackedStringArray = []
var _checks: int = 0
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	var saved_root: String = CrashWatch.root
	_clear_fixture()
	CrashWatch.root = FIXTURE
	_test_the_watcher_is_off_headless()
	_test_a_clean_session_reports_nothing()
	_test_a_standing_marker_is_a_crash()
	_test_a_cut_marker_still_counts()
	_test_the_log_is_read_and_scrubbed()
	_test_the_report_carries_it()
	await _test_the_menu_offers_it_for_review()
	_test_the_wiring()
	CrashWatch.forget()
	CrashWatch.root = saved_root
	_clear_fixture()
	for stage: String in ["headless", "clean", "standing", "cut", "log", "report", "menu", "wiring"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check it had "
				+ "not made yet is a check nobody made") % stage)
	for failure: String in _failures:
		push_error("[crash-watch] " + failure)
	if _failures.is_empty():
		print(("[crash-watch] PASS - %d checks: a clean session reports nothing, a standing "
			+ "marker is a crash even cut short, only error lines of the last log are carried "
			+ "and scrubbed of the player's folders, the report carries it only when there was "
			+ "one, and the menu opens it for review") % _checks)
	else:
		print("[crash-watch] FAIL - %d problem(s)" % _failures.size())
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0 if _failures.is_empty() else 1)


## No gate may write a marker into the profile every gate shares.
func _test_the_watcher_is_off_headless() -> void:
	_check(not CrashWatch.watching(), "a headless process must not keep a marker")
	var watcher: Node = GameDirector.get_node_or_null("CrashWatch")
	_check(watcher != null, "GameDirector must stand the watcher up")
	if watcher != null:
		_check(not bool(watcher.get("_armed")), "the watcher must stay disarmed headless")
	_reached["headless"] = true


func _test_a_clean_session_reports_nothing() -> void:
	CrashWatch.begin(1000)
	_check(not CrashWatch.pending(), "a first launch with no marker reported a crash")
	_check(FileAccess.file_exists(CrashWatch.marker_path()), "a session must stand its marker")
	var marker: Dictionary = _marker()
	_check(int(marker.get("started", 0)) == 1000 and String(marker.get("version", "")) == BuildInfo.VERSION,
		"the marker must say when the session began and which build it was")
	CrashWatch.end()
	_check(not FileAccess.file_exists(CrashWatch.marker_path()), "a clean end must take the marker down")
	CrashWatch.begin(1100)
	_check(not CrashWatch.pending(), "a session after a clean end reported a crash")
	CrashWatch.end()
	_reached["clean"] = true


func _test_a_standing_marker_is_a_crash() -> void:
	var saved_act: int = RunState.act
	var saved_wave: int = RunState.wave_number
	var saved_active: bool = GameDirector.run_active
	RunState.act = 4
	RunState.wave_number = 37
	GameDirector.run_active = true
	CrashWatch.begin(1000)
	CrashWatch.write_marker(1600)
	RunState.act = saved_act
	RunState.wave_number = saved_wave
	GameDirector.run_active = saved_active
	# No end: the session never said goodbye.
	CrashWatch.begin(2000)
	_check(CrashWatch.pending(), "a marker left standing must read as a session that crashed")
	var last: Dictionary = CrashWatch.last_session()
	_check(String(last.get("ended", "")) == "unexpectedly", "the report must say how it ended")
	_check(int(last.get("ran_seconds", -1)) == 600,
		"it must say how long the session ran, from its own breadcrumb (%s)" % str(last.get("ran_seconds")))
	_check(int(last.get("act", 0)) == 4 and int(last.get("wave", 0)) == 37 and bool(last.get("in_run", false)),
		"it must say where the Warden was when it stopped")
	_check(String(last.get("scope", "")) != "unknown", "a scope this build knows must be named")
	var wanted: Array = ["ended", "version", "ran_seconds", "in_run", "scope", "act", "wave", "errors"]
	var keys: Array = last.keys()
	wanted.sort()
	keys.sort()
	_check(keys == wanted, "the last session carries exactly its allowlisted fields: %s" % str(keys))
	CrashWatch.forget()
	_check(not CrashWatch.pending() and CrashWatch.last_session().is_empty(),
		"forgetting must clear what was said")
	CrashWatch.end()
	_reached["standing"] = true


func _test_a_cut_marker_still_counts() -> void:
	# The crash can interrupt the breadcrumb itself.
	_write(CrashWatch.marker_path(), "{\"version\": \"v0.5")
	var forged: Dictionary = {}
	CrashWatch.begin(3000)
	_check(CrashWatch.pending(), "a marker cut short by the crash still says the session crashed")
	forged = CrashWatch.last_session()
	_check(String(forged.get("scope", "")) == "unknown" and int(forged.get("ran_seconds", -1)) == 0,
		"a marker that cannot be read must report nothing it does not know")
	CrashWatch.end()
	# And one that names nonsense cannot put it in the report.
	_write(CrashWatch.marker_path(), JSON.stringify({"scope": PRIVATE_NAME, "act": 999999,
		"wave": -5, "started": 10, "seen": 99999999999, "version": "v1\n\t" + "x".repeat(400)}))
	CrashWatch.begin(4000)
	forged = CrashWatch.last_session()
	_check(String(forged.get("scope", "")) == "unknown", "an unknown scope must not be carried as written")
	_check(int(forged.get("act", 0)) <= 99 and int(forged.get("wave", 0)) >= 0
		and int(forged.get("ran_seconds", 0)) <= Balance.CRASH_SESSION_CEILING_SECONDS,
		"every number in the report must be bounded")
	_check(String(forged.get("version", "")).length() <= SupportDiagnostics.MAX_METADATA_LENGTH
		and not String(forged.get("version", "")).contains("\n"), "the version must be bounded plain text")
	CrashWatch.forget()
	CrashWatch.end()
	_reached["cut"] = true


func _test_the_log_is_read_and_scrubbed() -> void:
	var logs: String = FIXTURE.path_join(CrashWatch.LOG_FOLDER)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(logs))
	var home: String = "C:" + String.chr(92) + "Users" + String.chr(92) + PRIVATE_NAME + String.chr(92) + "Documents"
	_write(logs.path_join("godot2026-01-01T10.00.00.log"), "ERROR: from an older session\n")
	var lines: PackedStringArray = [
		"Godot Engine v4.7.1 - an ordinary line that is not an error",
		"ERROR: Could not open C:/Users/%s/AppData/Roaming/thing.png" % PRIVATE_NAME,
		"   at: load (core/io/resource_loader.cpp:291)",
		"WARNING: a warning is not carried",
		"   at: the location under a warning is not carried either",
		"SCRIPT ERROR: Invalid access in %s" % home,
		"ERROR: under /home/%s/games/wilderhold" % PRIVATE_NAME,
		"ERROR: %s/beast_road_save.json failed" % OS.get_user_data_dir(),
		"CrashHandlerException: Program crashed with signal 11",
		"[1] error(-1): no debug info in PE/COFF executable",
		"ERROR: " + "y".repeat(600),
	]
	_write(logs.path_join("godot2026-01-02T10.00.00.log"), "\n".join(lines) + "\n")
	_write(logs.path_join(CrashWatch.CURRENT_LOG), "ERROR: this session's own log is never read\n")
	_check(CrashWatch.previous_log().get_file() == "godot2026-01-02T10.00.00.log",
		"the newest log that is not this session's must be the one read (%s)" % CrashWatch.previous_log())
	var got: PackedStringArray = CrashWatch.log_errors()
	var joined: String = "\n".join(got)
	_check(not joined.contains("ordinary line") and not joined.contains("warning is not carried")
		and not joined.contains("under a warning"), "only error lines and their locations may be carried")
	_check(joined.contains("resource_loader.cpp") and joined.contains("signal 11") and joined.contains("[1] error"),
		"the location under an error and the crash's own lines must be carried")
	_check(not joined.contains("older session") and not joined.contains("never read"),
		"neither an older session's log nor this session's must be read")
	_check(not joined.contains(PRIVATE_NAME), "a home folder named after the player must be scrubbed: " + joined)
	_check(joined.contains("<you>"), "a scrubbed home folder must still say where it was")
	_check(not joined.contains(OS.get_user_data_dir()) and joined.contains("user://beast_road_save.json"),
		"the data folder must read as user://")
	var longest: int = 0
	for line: String in got:
		longest = maxi(longest, line.length())
	_check(longest <= Balance.CRASH_LINE_MAX, "every carried line must be cut to its ceiling")
	var many: PackedStringArray = []
	for index: int in 120:
		many.append("ERROR: line %d" % index)
	_write(logs.path_join("godot2026-01-03T10.00.00.log"), "\n".join(many) + "\n")
	got = CrashWatch.log_errors()
	_check(got.size() == Balance.CRASH_REPORT_LINES and got[got.size() - 1] == "ERROR: line 119",
		"only the last %d error lines may be carried, newest last" % Balance.CRASH_REPORT_LINES)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(logs.path_join("godot2026-01-03T10.00.00.log")))
	_reached["log"] = true


func _test_the_report_carries_it() -> void:
	var clean: Dictionary = SupportDiagnostics.capture(Vector2i(1280, 720))
	_check(not clean.has("last_session"), "a report after a clean session must not invent a crash")
	CrashWatch.begin(5000)
	CrashWatch.begin(5100)
	_check(CrashWatch.pending(), "the crash under test must be pending")
	var report: Dictionary = SupportDiagnostics.capture(Vector2i(1280, 720))
	_check(report.has("last_session"), "a report after a crash must carry the last session")
	var text: String = SupportDiagnostics.report_text(Vector2i(1280, 720))
	_check(JSON.parse_string(text) is Dictionary, "the report must still parse as ordinary JSON")
	_check(not text.contains(PRIVATE_NAME), "nothing private may reach the report")
	_check(text.length() < 8192 + Balance.CRASH_REPORT_LINES * (Balance.CRASH_LINE_MAX + 16),
		"the report must stay bounded")
	_reached["report"] = true


func _test_the_menu_offers_it_for_review() -> void:
	_check(CrashWatch.pending(), "the menu test needs a crash pending")
	var menu: MainMenu = load("res://scenes/ui/main_menu.tscn").instantiate() as MainMenu
	add_child(menu)
	for _frame: int in 6:
		await get_tree().process_frame
	var notice := menu.find_child("CrashNotice", true, false) as Button
	_check(notice != null, "a pending crash must be said on the menu")
	if notice != null:
		_check(notice.get_index() == 0, "the notice belongs at the top of the column")
		_check(notice.text == SupportDiagnosticsPanel.COPY.crash_notice and not notice.text.is_empty(),
			"the notice's words must come from data")
		notice.pressed.emit()
		for _frame: int in 3:
			await get_tree().process_frame
		var settings: SettingsPanel = null
		for node: Node in menu.get_children():
			if node is SettingsPanel:
				settings = node as SettingsPanel
		_check(settings != null and settings.visible, "the notice must open the settings")
		if settings != null:
			var tabs: TabContainer = settings._tabs
			_check(tabs != null and tabs.get_current_tab_control() != null
				and tabs.get_current_tab_control().name == "Data", "the notice must open the Data tab")
			var panel := settings.find_child("SupportDiagnostics", true, false) as SupportDiagnosticsPanel
			_check(panel != null and panel._preview.visible and panel._preview.text.contains("last_session"),
				"the report must be prepared for review, carrying the last session")
			_check(panel != null and panel._copy_button.visible,
				"copying stays the player's own press, after reading")
	menu.queue_free()
	for _frame: int in 3:
		await get_tree().process_frame
	CrashWatch.forget()
	var calm: MainMenu = load("res://scenes/ui/main_menu.tscn").instantiate() as MainMenu
	add_child(calm)
	for _frame: int in 4:
		await get_tree().process_frame
	_check(calm.find_child("CrashNotice", true, false) == null, "with no crash the menu must say nothing")
	calm.queue_free()
	for _frame: int in 3:
		await get_tree().process_frame
	CrashWatch.end()
	_reached["menu"] = true


## The failure worth a source walk is an omission: a watcher nobody stands up
## reads as a game that never crashes.
func _test_the_wiring() -> void:
	var director: String = FileAccess.get_file_as_string("res://autoload/GameDirector.gd")
	_check(director.contains("add_child(CrashWatch.new())"), "GameDirector must stand the watcher up")
	var menu: String = FileAccess.get_file_as_string("res://scenes/ui/main_menu.gd")
	_check(menu.contains("_build_crash_notice()"), "the menu must offer a crash")
	var diagnostics: String = FileAccess.get_file_as_string("res://scripts/systems/support_diagnostics.gd")
	_check(diagnostics.contains("CrashWatch.last_session()"), "the support report must carry the last session")
	_reached["wiring"] = true


func _marker() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CrashWatch.marker_path()))
	return parsed as Dictionary if parsed is Dictionary else {}


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "could not write fixture " + path)
		return
	file.store_string(text)
	file.close()


func _clear_fixture() -> void:
	var base: String = ProjectSettings.globalize_path(FIXTURE)
	for sub: String in [CrashWatch.LOG_FOLDER, ""]:
		var folder: String = base.path_join(sub) if not sub.is_empty() else base
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		for file_name: String in dir.get_files():
			DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(base.path_join(CrashWatch.LOG_FOLDER))
	DirAccess.make_dir_recursive_absolute(base)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
