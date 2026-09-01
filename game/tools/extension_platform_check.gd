extends Node

## Every platform the game exports to has the native libraries it needs.
##
## **This is the check that was missing when two phones could not see each
## other.** The WebRTC extension shipped Windows and Linux binaries and no
## Android one, so on a phone `WebRTCPeerConnection` was an interface with
## nothing behind it: it constructed happily, and then `add_peer` failed with
## "Could not add the other player to the session" - which reads like a network
## problem and is a missing file.
##
## Nothing else could have caught it. The export succeeds, the game runs, the
## menu works; only the transport is hollow, and only on the one platform the
## developer's machine is not.
##
## Derived from `export_presets.cfg` rather than from a list here, so adding a
## platform to the project adds it to this check. A preset that exports is a
## platform that has to work.

var _failures: int = 0


func _ready() -> void:
	var presets: String = _read("res://export_presets.cfg")
	_check(not presets.is_empty(), "export_presets.cfg must be readable")

	# Which platforms the project actually ships.
	var platforms: Dictionary = {}
	for line: String in presets.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("platform="):
			platforms[trimmed.split("=")[1].replace("\"", "").to_lower()] = true

	for path: String in _extensions("res://addons"):
		var body: String = _read(path)
		if body.is_empty():
			continue
		var declared: Dictionary = {}
		var missing: PackedStringArray = []
		for line: String in body.split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with(";") or not trimmed.contains("="):
				continue
			var key: String = trimmed.split("=")[0].strip_edges().to_lower()
			var value: String = trimmed.split("=")[1].strip_edges().replace("\"", "")
			if not value.ends_with(".so") and not value.ends_with(".dll") \
					and not value.ends_with(".dylib") and not value.ends_with(".framework"):
				continue
			declared[key.split(".")[0]] = true
			# A manifest naming a file that is not there is worse than one that
			# omits the platform: it reads as supported.
			var lib: String = path.get_base_dir() + "/" + value
			if not FileAccess.file_exists(lib):
				missing.append(value)
		_check(missing.is_empty(),
			"%s names libraries that are not in the repository: %s"
				% [path.get_file(), ", ".join(missing)])

		for platform: Variant in platforms:
			var name: String = String(platform)
			# The web platform needs nothing: a browser implements WebRTC and
			# the engine binds straight to it.
			if name.contains("web"):
				continue
			var key: String = "windows" if name.contains("windows") else name.split(" ")[0]
			_check(declared.has(key),
				"%s ships for '%s' but %s has no library for it - the extension "
					% [ProjectSettings.get_setting("application/config/name", "the game"),
						key, path.get_file()]
					+ "will construct and then fail at runtime")

	if _failures == 0:
		print("[extensions] PASS - every exported platform has its native libraries")
	else:
		push_error("[extensions] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _extensions(from: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var dir: DirAccess = DirAccess.open(from)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		var full: String = from + "/" + entry
		if dir.current_is_dir():
			out.append_array(_extensions(full))
		elif entry.ends_with(".gdextension"):
			out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _read(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var body: String = file.get_as_text()
	file.close()
	return body


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[extensions] %s" % why)
