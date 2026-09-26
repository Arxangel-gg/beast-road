extends Node

## Holds the privacy note to the code (2026-09-26).
##
## `docs/PRIVACY.md` and the note in Settings › Data say what leaves a player's
## machine. A note like that is only true on the day it is written: the next
## network call anybody adds makes it false in silence. So this gate walks the
## code for every host it names and every script that makes a request, and
## fails until the note names them too. It sends nothing.

## Every script that talks to the network, and what it is for. A new one fails
## the gate until it is written into `docs/PRIVACY.md` and added here.
const KNOWN_TALKERS: Dictionary = {
	"res://autoload/Leaderboard.gd": "the leaderboard, on Submit",
	"res://autoload/Coop.gd": "hosting: UPnP and the public-address probe",
	"res://scripts/systems/coop_directory.gd": "the public lobby list",
	"res://scripts/systems/coop_webrtc.gd": "room signalling and STUN",
	"res://scripts/systems/coop_beacon.gd": "a hosted game announced on the local network",
	"res://scripts/systems/supabase.gd": "the database client the others share",
}
## What one leaderboard post carries, exactly as the note lists it.
const DOCUMENTED_POST: Array[String] = ["submission_id", "name", "tier", "score", "act",
	"wave", "hero_level", "duration", "victory", "seed", "version"]
## What one Ledger sale carries.
const DOCUMENTED_SALE: Array[String] = ["rarity", "price", "vendor"]
const ROOTS: Array[String] = ["res://autoload", "res://scripts", "res://scenes"]

var _failures: PackedStringArray = []
var _checks: int = 0
var _reached: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	var doc: String = _read_doc()
	_check(not doc.is_empty(), "docs/PRIVACY.md must exist beside the game")
	var sources: Dictionary = {}
	for root: String in ROOTS:
		_collect(root, sources)
	_test_every_host_is_named(doc, sources)
	_test_every_talker_is_known(sources)
	_test_a_post_carries_what_it_says(doc)
	_test_the_router_port_is_closed()
	await _test_the_note_is_in_the_game()
	for stage: String in ["hosts", "talkers", "post", "port", "note"]:
		_check(_reached.has(stage), "'%s' never reached its end" % stage)
	for failure: String in _failures:
		push_error("[privacy] " + failure)
	if _failures.is_empty():
		print(("[privacy] PASS - %d checks: every host the code names is in the note, every script "
			+ "that talks is known, a post carries exactly what the note lists, the router port "
			+ "is leased and closed, and the note is in the game") % _checks)
	else:
		print("[privacy] FAIL - %d problem(s)" % _failures.size())
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 20:
		await get_tree().process_frame
	MetaState.resume_saves()
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_every_host_is_named(doc: String, sources: Dictionary) -> void:
	var host := RegEx.create_from_string("(?:https?://|stun:|turn:)([a-z0-9.-]+\\.[a-z]{2,})")
	var found: Dictionary = {}
	for path: String in sources:
		for line: String in (sources[path] as String).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for hit: RegExMatch in host.search_all(line):
				found[hit.get_string(1)] = path
	_check(found.size() >= 4, "the walk must find the hosts the game talks to (found %d)" % found.size())
	for host_name: String in found:
		_check(doc.contains(host_name),
			"%s talks to %s and docs/PRIVACY.md does not say so" % [found[host_name], host_name])
	_reached["hosts"] = true


func _test_every_talker_is_known(sources: Dictionary) -> void:
	var talks := RegEx.create_from_string("HTTPRequest\\.new\\(|UPNP\\.new\\(|WebRTCPeerConnection\\.new\\(|HTTPClient\\.new\\(|StreamPeerTCP\\.new\\(|PacketPeerUDP\\.new\\(")
	for path: String in sources:
		if path.begins_with("res://tools/"):
			continue
		if talks.search(sources[path] as String) != null:
			_check(KNOWN_TALKERS.has(path),
				"%s opens a network connection and is not in the privacy note - write down what it sends" % path)
	for path: String in KNOWN_TALKERS:
		_check(sources.has(path), "%s is listed as talking and no longer exists" % path)
	_reached["talkers"] = true


func _test_a_post_carries_what_it_says(doc: String) -> void:
	var fields: Array[String] = []
	fields.assign(Score.FIELDS)
	var sorted_fields: Array = fields.duplicate()
	var documented: Array = DOCUMENTED_POST.duplicate()
	sorted_fields.sort()
	documented.sort()
	_check(sorted_fields == documented,
		"a leaderboard post carries %s; the note lists %s" % [str(sorted_fields), str(documented)])
	var results: String = FileAccess.get_file_as_string("res://scenes/ui/results_screen.gd")
	_check(results.contains("func _submit()") and results.contains("Leaderboard.submit("),
		"the leaderboard is posted from the results screen's Submit")
	for path: String in _all_scripts():
		if path == "res://scenes/ui/results_screen.gd" or path.begins_with("res://tools/"):
			continue
		_check(not FileAccess.get_file_as_string(path).contains("Leaderboard.submit("),
			"%s posts to the leaderboard; the note says only Submit does" % path)
	var exchange: String = FileAccess.get_file_as_string("res://autoload/Exchange.gd")
	var start: int = exchange.find("func _publish_sale(")
	var body: String = exchange.substr(start, 600) if start >= 0 else ""
	var keys := RegEx.create_from_string("\"([a-z_]+)\"\\s*:")
	var sent: Array = []
	for hit: RegExMatch in keys.search_all(body):
		sent.append(hit.get_string(1))
	sent.sort()
	var sale: Array = DOCUMENTED_SALE.duplicate()
	sale.sort()
	_check(sent == sale, "a Ledger sale sends %s; the note lists %s" % [str(sent), str(sale)])
	_check(doc.contains("Submit") and doc.contains("Long Ledger") and doc.contains("IP address")
		and doc.contains("local network"),
		"the note must say when the board is posted, what the Ledger sends, and that peers see an address")
	_reached["post"] = true


func _test_the_router_port_is_closed() -> void:
	var coop: String = FileAccess.get_file_as_string("res://autoload/Coop.gd")
	_check(coop.contains("Balance.COOP_UPNP_LEASE_SECONDS"), "a hosted port must be asked for on a lease")
	_check(coop.contains("delete_port_mapping("), "a hosted port must be closed again")
	var leave: int = coop.find("func leave()")
	var exit: int = coop.find("func _exit_tree()")
	_check(leave >= 0 and coop.substr(leave, 1200).contains("_close_port()"), "stopping hosting must close the port")
	_check(exit >= 0 and coop.substr(exit, 400).contains("_close_port()"), "quitting must close the port")
	_reached["port"] = true


func _test_the_note_is_in_the_game() -> void:
	var copy: DiagnosticCopyData = SupportDiagnosticsPanel.COPY
	_check(not copy.privacy_heading.is_empty() and not copy.privacy_body.is_empty(),
		"the note must be authored in data")
	for words: String in ["Submit", "Long Ledger", "Co-op", "IP address", "never sent"]:
		_check(copy.privacy_body.contains(words), "the note in the game must say '%s'" % words)
	var settings := SettingsPanel.new()
	add_child(settings)
	await get_tree().process_frame
	var note := settings.find_child("PrivacyNote", true, false) as Label
	_check(note != null and note.text == copy.privacy_body, "Settings › Data must show the note")
	settings.queue_free()
	await get_tree().process_frame
	_reached["note"] = true


func _read_doc() -> String:
	var path: String = ProjectSettings.globalize_path("res://").path_join("../docs/PRIVACY.md")
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _collect(folder: String, into: Dictionary) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.ends_with(".gd"):
			var path: String = folder.path_join(file_name)
			into[path] = FileAccess.get_file_as_string(path)
	for sub: String in dir.get_directories():
		_collect(folder.path_join(sub), into)


func _all_scripts() -> Array[String]:
	var into: Dictionary = {}
	for root: String in ROOTS:
		_collect(root, into)
	var out: Array[String] = []
	for path: String in into:
		out.append(path)
	return out


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
