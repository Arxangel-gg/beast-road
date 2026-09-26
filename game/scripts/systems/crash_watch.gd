class_name CrashWatch
extends Node

## Did the last session end the way a session is meant to?
##
## `ROAD_TO_1_0.md` put crash reporting first among what testers need: without
## it a tester's bad evening teaches nothing. A crash reporter wants somewhere to
## send a report, and this game has nowhere honest to send one - the only
## service it talks to is the leaderboard, whose key every copy carries (see the
## Long Ledger in CLAUDE.md). Where a report should go is the owner's decision.
## **This is the half that needs no server**, and it is the half every answer to
## that decision will need anyway.
##
## A session writes a marker when it starts and removes it when it ends cleanly.
## A marker still standing at the next launch is a session that crashed, hung
## and was killed, or lost its power. The support report then carries what is
## known about it - where the Warden was, how long the session ran, and the
## error lines from that session's own log with the player's folder names taken
## out - and the main menu says so once and opens that report for review. It
## is copied only by the player's own press, and **nothing is ever sent**.
##
## **Not on the web**, where `user://` is the browser's storage, there is no log
## file, and a closed tab never runs a clean exit - every visit would read as a
## crash. **Never headless**, so no gate writes a marker into the profile the
## sweep shares. A phone that pauses the game takes the marker down while it is
## paused, because the system may end a paused app without asking and that is
## not a crash.

const MARKER: String = "session_open.json"
const LOG_FOLDER: String = "logs"
const CURRENT_LOG: String = "godot.log"

## Where the marker and the logs are: `user://` in a shipping game, moved to a
## fixture by `crash_watch_check` alone, as `MetaState.slot_root` is.
static var root: String = "user://"

static var _pending: bool = false
static var _last: Dictionary = {}
static var _started: int = 0
static var _error_line: RegEx = null
static var _trace_line: RegEx = null
static var _windows_home: RegEx = null
static var _unix_home: RegEx = null

var _armed: bool = false
var _clock: float = 0.0


## Whether this machine keeps a marker at all.
static func watching() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("web")


func _ready() -> void:
	name = "CrashWatch"
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not watching():
		set_process(false)
		return
	CrashWatch.begin()
	_armed = true


func _process(delta: float) -> void:
	# A breadcrumb, so a report can say where the Warden was when it stopped.
	_clock += delta
	if _clock < Balance.CRASH_BREADCRUMB_SECONDS:
		return
	_clock = 0.0
	CrashWatch.write_marker()


func _notification(what: int) -> void:
	if not _armed:
		return
	if what == NOTIFICATION_APPLICATION_PAUSED:
		CrashWatch.end()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		CrashWatch.write_marker()


func _exit_tree() -> void:
	if _armed:
		CrashWatch.end()


## Reads what the last session left behind, then stands this session's marker.
## `now` is a seam for the gate; a shipping call passes nothing.
static func begin(now: int = -1) -> void:
	_pending = false
	_last = {}
	if FileAccess.file_exists(marker_path()):
		_last = _describe(_read(marker_path()), log_errors())
		_pending = true
	_started = now if now >= 0 else int(Time.get_unix_time_from_system())
	write_marker(_started)


## The session is ending, or pausing where the system may end it: no marker.
static func end() -> void:
	if FileAccess.file_exists(marker_path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(marker_path()))


static func write_marker(now: int = -1) -> void:
	var stamp: int = now if now >= 0 else int(Time.get_unix_time_from_system())
	var body: Dictionary = {
		"version": BuildInfo.VERSION,
		"started": _started if _started > 0 else stamp,
		"seen": stamp,
		"in_run": GameDirector.run_active,
		"scope": SupportDiagnostics._enum_name(GameDirector.Scope, GameDirector.current_scope),
		"act": RunState.act,
		"wave": RunState.wave_number,
	}
	var file := FileAccess.open(marker_path(), FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(body))
	file.close()


static func marker_path() -> String:
	return root.path_join(MARKER)


## Whether the last session ended without saying so, this launch.
static func pending() -> bool:
	return _pending


## What is known about the session that ended unexpectedly: every field
## allowlisted and bounded, as `SupportDiagnostics` requires of its own.
static func last_session() -> Dictionary:
	return _last.duplicate(true)


## The player has seen it; the menu stops offering it.
static func forget() -> void:
	_pending = false
	_last = {}


static func _read(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text: String = file.get_as_text()
	file.close()
	# A marker cut short by the crash itself still counts: it is standing. Read
	# through an instance, because `JSON.parse_string` prints an engine error on
	# the cut text, and a crash report that writes an error line is a small joke.
	var json := JSON.new()
	if json.parse(text) != OK:
		return {}
	return json.data as Dictionary if json.data is Dictionary else {}


static func _describe(marker: Dictionary, errors: PackedStringArray) -> Dictionary:
	var started: int = int(marker.get("started", 0))
	var seen: int = int(marker.get("seen", started))
	var scope: String = String(marker.get("scope", "unknown"))
	var known: bool = false
	for key: Variant in GameDirector.Scope.keys():
		if String(key).to_lower() == scope:
			known = true
	var lines: Array = []
	for line: String in errors:
		lines.append(line)
	return {
		"ended": "unexpectedly",
		"version": SupportDiagnostics._metadata(String(marker.get("version", "unknown"))),
		"ran_seconds": clampi(seen - started, 0, Balance.CRASH_SESSION_CEILING_SECONDS),
		"in_run": bool(marker.get("in_run", false)),
		"scope": scope if known else "unknown",
		"act": clampi(int(marker.get("act", 0)), 0, 99),
		"wave": clampi(int(marker.get("wave", 0)), 0, 100000),
		"errors": lines,
	}


## The error lines of the last session's log, newest last, scrubbed. A line
## that is not an error or the location under one is never carried: the rest
## of a log is whatever anything happened to print.
static func log_errors() -> PackedStringArray:
	var out := PackedStringArray()
	var path: String = previous_log()
	if path.is_empty():
		return out
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return out
	var size: int = file.get_length()
	var tail: int = mini(size, Balance.CRASH_LOG_TAIL_BYTES)
	file.seek(size - tail)
	var text: String = file.get_buffer(tail).get_string_from_utf8()
	file.close()
	_compile()
	var kept: Array[String] = []
	var under_error: bool = false
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges(false, true)
		if _error_line.search(line) != null:
			kept.append(scrub(line))
			under_error = true
		elif under_error and _trace_line.search(line) != null:
			kept.append(scrub(line))
		else:
			under_error = false
	for index: int in range(maxi(kept.size() - Balance.CRASH_REPORT_LINES, 0), kept.size()):
		out.append(kept[index])
	return out


## The newest log the last session wrote. Godot moves the previous session's
## log aside before any script runs, so it is the newest file that is not the
## one this session is writing.
static func previous_log() -> String:
	var folder: String = root.path_join(LOG_FOLDER)
	var dir := DirAccess.open(folder)
	if dir == null:
		return ""
	var best: String = ""
	var best_time: int = -1
	for file_name: String in dir.get_files():
		if file_name == CURRENT_LOG or not file_name.begins_with("godot") or not file_name.ends_with(".log"):
			continue
		var when: int = FileAccess.get_modified_time(folder.path_join(file_name))
		# A modified time is whole seconds; the rotated names carry the time, so a
		# tie goes to the later name.
		if when > best_time or (when == best_time and file_name > best.get_file()):
			best_time = when
			best = folder.path_join(file_name)
	return best


## A log line with the player's own folders taken out: their data folder, the
## game's folder, and any home directory named after them.
static func scrub(line: String) -> String:
	_compile()
	var out: String = line
	for place: String in [ProjectSettings.globalize_path("user://"), OS.get_user_data_dir()]:
		var trimmed: String = place.trim_suffix("/").trim_suffix(String.chr(92))
		if trimmed.length() > 3:
			out = out.replace(trimmed, "user:/").replace(trimmed.replace("/", String.chr(92)), "user:/")
	var game_dir: String = OS.get_executable_path().get_base_dir()
	if game_dir.length() > 3:
		out = out.replace(game_dir, "<game>").replace(game_dir.replace("/", String.chr(92)), "<game>")
	out = _windows_home.sub(out, "$1<you>", true)
	out = _unix_home.sub(out, "$1<you>", true)
	if out.length() > Balance.CRASH_LINE_MAX:
		out = out.substr(0, Balance.CRASH_LINE_MAX)
	return out


static func _compile() -> void:
	if _error_line != null:
		return
	_error_line = RegEx.create_from_string(
		"^\\s*(ERROR|SCRIPT ERROR|USER ERROR|USER SCRIPT ERROR|CrashHandlerException|Program crashed|GDScript backtrace)")
	_trace_line = RegEx.create_from_string("^\\s*(at:|\\[\\d+\\])")
	_windows_home = RegEx.create_from_string("(?i)([a-z]:[\\\\/]+(?:users|documents and settings)[\\\\/]+)[^\\\\/\\s\"']+")
	_unix_home = RegEx.create_from_string("(/(?:home|Users)/)[^/\\s\"']+")
