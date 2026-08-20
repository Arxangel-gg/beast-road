extends Node

## Submits finished runs to a shared board, and reads it back.
##
## ## Where the board lives
##
## A Supabase table reached over its REST interface. The key below is Supabase's
## **anon public key** — it is designed to be embedded in clients, and it is not
## the thing the project's no-shipped-token rule is about: that rule exists
## because a GitHub token grants write access to the repository, and this grants
## exactly what the table's Row Level Security policies say it grants and nothing
## else.
##
## Which means **the policies are the security**, not the key. `docs/LEADERBOARD.md`
## carries the SQL, and the short version is: anyone may read, anyone may insert
## one row within sane bounds, nobody may update or delete. Get that wrong and
## the key in this file is a write-anything credential; get it right and posting
## it publicly costs nothing.
##
## ## Why it never blocks anything
##
## Every call here is fire-and-forget. A debrief must not wait on a network, a
## menu must not fail to open because a host is down, and a player on a plane
## must get the same game as everyone else. Submission failures are recorded and
## retried on the next launch; read failures fall back to the local board.
##
## ## The local board is not a fallback bolted on
##
## Personal bests are kept in the save regardless of whether a submission
## succeeded, because they answer a different question — "is this my best run"
## rather than "where do I stand" — and because it is the only board that works
## with no network at all.

## The board, and the public key that reaches it.
const ENDPOINT: String = "https://xscyioampvjfqcciccie.supabase.co/rest/v1"
const ANON_KEY: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzY3lpb2FtcHZqZnFjY2ljY2llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyNDI2NDksImV4cCI6MjEwMjgxODY0OX0.oN74ghnJqAlWtoRKWJVzb4Otw19lH68po_v2z2JlXmU"

## The table. Named for what a row is, not for what the screen showing it is.
const TABLE: String = "runs"

## How long any one request may take. Short, because nothing waits on it and a
## request that has not answered in this long is not going to.
## Emitted when a fetch lands. `rows` is newest-query-first and already sorted by
## score; `from_network` is false when the local board answered instead.
signal board_loaded(tier_id: String, rows: Array, from_network: bool)

## Emitted after a submission resolves, either way. The screen uses it to stop
## saying "sending".
signal submitted(ok: bool, message: String)

var _requests: Array[HTTPRequest] = []


func _ready() -> void:
	# Anything queued by a previous session that never got through. Done on
	# launch rather than on demand so a player who finished a run offline does
	# not have to remember to do anything.
	if _network_allowed():
		_flush_pending()


## Sends one finished run. Returns immediately.
func submit(summary: Dictionary, tier: CampaignTierData) -> void:
	var row: Dictionary = Score.row(summary, tier, MetaState.player_name,
		MetaState.hero_level, ProjectSettings.get_setting("application/config/version", "dev"),
		_new_submission_id())
	_remember_locally(row)
	if not _network_allowed():
		_queue(row)
		submitted.emit(false, "Saved locally. It will send from a normal game session.")
		return
	_post(row)


## Asks for one tier's board. Answers through `board_loaded`, always — with
## network rows if they arrive, with the local board if they do not.
func fetch(tier_id: String) -> void:
	if not _network_allowed():
		board_loaded.emit(tier_id, local_board(tier_id), false)
		return
	var query: String = "%s/%s?select=%s&tier=eq.%s&order=score.desc&limit=%d" % [
		ENDPOINT, TABLE, ",".join(Score.FIELDS), tier_id.uri_encode(),
		Balance.LEADERBOARD_PAGE_SIZE]
	var request: HTTPRequest = _request()
	request.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray,
				body: PackedByteArray) -> void:
			_release(request)
			var response: Dictionary = _parse(result, code, body)
			var rows: Array = response.get("rows", []) as Array
			if not bool(response.get("ok", false)):
				board_loaded.emit(tier_id, local_board(tier_id), false)
			else:
				board_loaded.emit(tier_id, rows, true), CONNECT_ONE_SHOT)
	if request.request(query, _headers(), HTTPClient.METHOD_GET) != OK:
		_release(request)
		board_loaded.emit(tier_id, local_board(tier_id), false)


## This save's own best runs on a tier, best first. Always available.
func local_board(tier_id: String) -> Array:
	var out: Array = []
	for row: Dictionary in MetaState.best_runs:
		if String(row.get("tier", "")) == tier_id:
			out.append(row)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0)))
	return out


## Whether a row came from this save, so a board can mark it.
func is_own(row: Dictionary) -> bool:
	var submission_id: String = String(row.get("submission_id", ""))
	if submission_id.is_empty():
		return false
	return _contains_submission(MetaState.best_runs, submission_id)


# --------------------------------------------------------------- internals ---


func _post(row: Dictionary) -> void:
	var request: HTTPRequest = _request()
	request.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray,
				body: PackedByteArray) -> void:
			_release(request)
			# 201 is the documented success. Anything else is queued rather than
			# reported as lost: the run happened whatever the network thinks.
			if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
				submitted.emit(true, "Sent.")
				return
			_queue(row)
			submitted.emit(false, _why(result, code, body)), CONNECT_ONE_SHOT)

	var headers: PackedStringArray = _headers()
	headers.append("Content-Type: application/json")
	# Without this the insert answers with the row it wrote, which is a response
	# body nobody reads.
	headers.append("Prefer: resolution=ignore-duplicates,return=minimal")
	if request.request("%s/%s?on_conflict=submission_id" % [ENDPOINT, TABLE], headers,
			HTTPClient.METHOD_POST, JSON.stringify(row)) != OK:
		_release(request)
		_queue(row)
		submitted.emit(false, "Could not reach the board.")


func _headers() -> PackedStringArray:
	# Supabase wants the key twice: once as the project identifier and once as
	# the bearer token it authorises the request with.
	return PackedStringArray([
		"apikey: %s" % ANON_KEY,
		"Authorization: Bearer %s" % ANON_KEY,
	])


## Rows from a response, or empty for anything that is not a list of them.
func _parse(result: int, code: int, body: PackedByteArray) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		return {"ok": false, "rows": []}
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Array):
		return {"ok": false, "rows": []}
	var rows: Array = []
	for entry: Variant in parsed as Array:
		if entry is Dictionary:
			rows.append(Score.clean_row(entry as Dictionary))
	return {"ok": true, "rows": rows}


## A failure a person can act on.
##
## "Request failed" is what this said first, which is true of every failure and
## tells nobody whether to check their wifi or the table's policies.
func _why(result: int, code: int, body: PackedByteArray) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "No connection. Saved; it will send next launch."
	if code == 401 or code == 403:
		return "The board refused the entry. Check the table's insert policy."
	if code == 402:
		return "The board is temporarily unavailable. Saved; it will retry next launch."
	if code == 404:
		return "The board's table is missing."
	var text: String = body.get_string_from_utf8().strip_edges()
	return "Board error %d. Saved; it will send next launch.%s" % [code,
		"" if text.is_empty() else "  (%s)" % text.left(120)]


## Keeps a run in this save's own best list, capped.
func _remember_locally(row: Dictionary) -> void:
	var submission_id: String = String(row.get("submission_id", ""))
	if not submission_id.is_empty() and _contains_submission(MetaState.best_runs, submission_id):
		return
	MetaState.best_runs.append(row)
	MetaState.best_runs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("score", 0)) > int(b.get("score", 0)))
	# Capped by count rather than per tier: the cap exists to bound the save, and
	# a player who only plays one tier should still get a full board on it.
	if MetaState.best_runs.size() > Balance.LEADERBOARD_LOCAL_MAX:
		MetaState.best_runs.resize(Balance.LEADERBOARD_LOCAL_MAX)
	MetaState.save_game()


func _queue(row: Dictionary) -> void:
	var submission_id: String = String(row.get("submission_id", ""))
	if not submission_id.is_empty() and _contains_submission(MetaState.pending_runs,
			submission_id):
		return
	if MetaState.pending_runs.size() >= Balance.LEADERBOARD_PENDING_MAX:
		return
	MetaState.pending_runs.append(row)
	MetaState.save_game()


## Retries whatever never got through with the same idempotency keys.
##
## Cleared before the requests answer so each failed request can requeue itself
## once. The stable submission id makes repeated launches safe even if the table
## accepted a row and only its response was lost, while the queue's hard cap
## prevents an unavailable service growing the save without bound.
func _flush_pending() -> void:
	if MetaState.pending_runs.is_empty():
		return
	var queued: Array = MetaState.pending_runs.duplicate(true)
	MetaState.pending_runs.clear()
	MetaState.save_game()
	for row: Variant in queued:
		if row is Dictionary:
			_post(row as Dictionary)


func _request() -> HTTPRequest:
	var request := HTTPRequest.new()
	request.timeout = Balance.LEADERBOARD_REQUEST_TIMEOUT
	# A board is not a reason to keep a paused game ticking, but it is also not
	# something to freeze mid-flight when one opens.
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(request)
	_requests.append(request)
	return request


func _release(request: HTTPRequest) -> void:
	_requests.erase(request)
	request.queue_free()


func _network_allowed() -> bool:
	# Release gates run real debriefs. A headless process must never turn a test
	# fixture or a developer's pending outbox into a public submission.
	return DisplayServer.get_name() != "headless"


func _contains_submission(rows: Array, submission_id: String) -> bool:
	for value: Variant in rows:
		if value is Dictionary and String((value as Dictionary).get(
				"submission_id", "")) == submission_id:
			return true
	return false


## UUID v4 generated locally. Its job is idempotency, not identity: if a POST is
## accepted but its response is lost, the queued retry reaches the same primary
## key and cannot create a second row.
func _new_submission_id() -> String:
	var bytes: PackedByteArray = Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return "%08x-%04x-4%03x-8%03x-%012x" % [
			Time.get_unix_time_from_system(), randi() & 0xFFFF, randi() & 0xFFF,
			randi() & 0xFFF, randi()]
	bytes[6] = (bytes[6] & 0x0F) | 0x40
	bytes[8] = (bytes[8] & 0x3F) | 0x80
	var hex: String = bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4),
		hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]
