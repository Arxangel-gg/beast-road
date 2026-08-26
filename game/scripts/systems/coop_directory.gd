class_name CoopDirectory
extends Node

## The public lobby list: games anybody, anywhere, can see and join.
##
## `CoopBeacon` finds games on your own network and needs no server. This is the
## other half - a small table in Supabase holding one row per game that is
## currently open, so two people who have never met can find each other. The row
## carries a **connect code** and nothing else about the machine behind it, so
## joining goes through exactly the same path as pasting a code by hand.
##
## **The row exists only while somebody is waiting.** It is deleted when the pair
## enters a run, when the host stops hosting, and when the game closes; anything
## that slips through those is swept by the heartbeat window every reader filters
## on. The table is empty when nobody is looking for a game, which is the state
## it should spend most of its life in.
##
## ### Why functions rather than table writes
##
## The anon key below is *meant* to be in the client - that is what an anon key
## is - and it is worth being precise about what stops it being abused.
## Anonymous clients have no identity, so a delete policy permissive enough for
## a host to remove its own row is permissive enough for anybody to remove every
## row. So the table takes no direct writes at all: it is reached through three
## `security definer` functions, each of which requires the secret token handed
## back when the row was created. Reading goes through a view that does not
## include that token.
##
## The SQL is in `docs/MATCHMAKING.md` and is applied once. Until it is, every
## call here fails quietly and the online list is simply empty - the game never
## errors and never blocks on it.

## The project, and its publishable anon key.
##
## Public by design: it identifies the project and grants nothing on its own.
## Everything it can reach is a view with no secrets in it and three functions
## that check a token. Never put a service-role key here.
const API: String = "https://xscyioampvjfqcciccie.supabase.co/rest/v1/"
const ANON: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzY3lpb2FtcHZqZnFjY2ljY2llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyNDI2NDksImV4cCI6MjEwMjgxODY0OX0.oN74ghnJqAlWtoRKWJVzb4Otw19lH68po_v2z2JlXmU"

## How often a listed host says it is still there. The sweep window in SQL is
## several heartbeats wide, so one dropped request does not un-list a game
## somebody is looking at.
const HEARTBEAT_SECONDS: float = 20.0

## How long a listing may go unrefreshed before the screen asks again.
const REFRESH_SECONDS: float = 6.0

## Bounded because it is drawn: a list nobody scrolls to the end of is a list.
const MAX_ROWS: int = 40
const MAX_NAME: int = 28

signal games_changed(games: Array)
signal status_changed(text: String)

var _games: Array = []

var _row_id: String = ""
var _token: String = ""
var _listed_code: String = ""
var _listed_name: String = ""

var _heartbeat_left: float = 0.0
var _refresh_left: float = 0.0
var _browsing: bool = false
var _status: String = ""


func _ready() -> void:
	set_process(false)


func games() -> Array:
	return _games


func status() -> String:
	return _status


## Whether this machine currently has a row in the table.
func is_listed() -> bool:
	return not _row_id.is_empty()


# --- Hosting -----------------------------------------------------------------

## Puts this game on the public list. Safe to call more than once.
func publish(code: String, game_name: String) -> void:
	if code.is_empty():
		return
	_listed_code = code
	_listed_name = _clean(game_name)
	if is_listed():
		# Already up. The code changes once the public address arrives a second
		# or two after hosting starts, so the row is updated, not duplicated.
		_beat()
		return
	_token = _make_token()
	_call("rpc/create_lobby", HTTPClient.METHOD_POST, {
		"p_code": _listed_code,
		"p_name": _listed_name,
		"p_token": _token,
	}, func(ok: bool, data: Variant) -> void:
		if not ok:
			_set_status("Could not reach the public lobby list.")
			return
		_row_id = _row_id_from(data)
		if _row_id.is_empty():
			_set_status("The public lobby list refused the listing.")
			return
		_heartbeat_left = HEARTBEAT_SECONDS
		_set_status("Listed publicly - anyone can find this game.")
		set_process(true))


## Takes this game off the list. Called when hosting stops **and** when the run
## begins: a party that is playing is not looking for anybody.
func withdraw() -> void:
	if not is_listed():
		return
	var row: String = _row_id
	var token: String = _token
	_row_id = ""
	_token = ""
	_set_status("")
	_call("rpc/delete_lobby", HTTPClient.METHOD_POST,
		{"p_id": row, "p_token": token},
		func(_ok: bool, _data: Variant) -> void: pass)
	_idle_if_done()


func _beat() -> void:
	if not is_listed():
		return
	_call("rpc/touch_lobby", HTTPClient.METHOD_POST, {
		"p_id": _row_id,
		"p_token": _token,
		"p_code": _listed_code,
		"p_players": Coop.player_count(),
	}, func(ok: bool, _data: Variant) -> void:
		if ok:
			return
		# The row was swept while this machine was quiet. Re-listing beats
		# vanishing from a list somebody is reading.
		_row_id = ""
		_token = ""
		publish(_listed_code, _listed_name))


# --- Browsing ----------------------------------------------------------------

func browse() -> void:
	_browsing = true
	_refresh_left = REFRESH_SECONDS
	set_process(true)
	_refresh()


func stop_browsing() -> void:
	_browsing = false
	_idle_if_done()


func _refresh() -> void:
	var query: String = "lobbies_public?select=code,name,players,locked,age_seconds" \
		+ "&order=created_at.desc&limit=%d" % MAX_ROWS
	_call(query, HTTPClient.METHOD_GET, {}, func(ok: bool, data: Variant) -> void:
		if not ok:
			# Silence rather than an error. A player with no connection still has
			# a local lobby and a code box, and neither cares about this.
			return
		_games = parse_rows(data, _listed_code)
		games_changed.emit(_games))


## Finds a party to join, or nothing.
##
## **The seat is claimed by the database, in the statement that finds it.** Two
## players pressing Find at the same instant must not both be handed the last
## seat in the same lobby, and a select-then-join from the client would do
## exactly that. The answer is a code, or "" meaning "nobody is waiting - host
## one yourself".
func find_party(done: Callable) -> void:
	_call("rpc/find_party", HTTPClient.METHOD_POST,
		{"p_max": Balance.COOP_MAX_PLAYERS},
		func(ok: bool, data: Variant) -> void:
			var code: String = String(data) if ok and data is String else ""
			done.call(joinable_code(code), code))


## Gives a claimed seat back, for a search that was abandoned or a join that
## failed. Without it a lobby slowly fills with people who never arrived.
func release_seat(code: String) -> void:
	if code.is_empty():
		return
	_call("rpc/release_seat", HTTPClient.METHOD_POST, {"p_code": code},
		func(_ok: bool, _data: Variant) -> void: pass)


## Asks the service whether a password opens a lobby.
##
## Checked in the database and never here: a client-side check is a suggestion,
## because anybody can call the API directly.
func check_password(code: String, secret: String, done: Callable) -> void:
	_call("rpc/lobby_password_ok", HTTPClient.METHOD_POST,
		{"p_code": code, "p_password": secret},
		func(ok: bool, data: Variant) -> void:
			done.call(ok and data is bool and bool(data)))


## Whether a code from the table is something this build can actually dial.
##
## **Two kinds of code go in this column.** A six-character *room* code is a
## WebRTC handshake and works from anywhere including a browser; a ten- or
## sixteen-character *connect* code carries addresses and needs ENet. Both are
## legitimate rows, so a listing that only understood one of them would silently
## hide every game hosted the other way - which is how a lobby list becomes a
## list of the games you happen to be able to see.
static func joinable_code(code: String) -> bool:
	var cleaned: String = code.strip_edges().to_upper().replace("-", "")
	if cleaned.length() == 6:
		# A room. Only offered where a room can be joined at all.
		if not CoopWebRTC.available():
			return false
		for character: String in cleaned:
			if not "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains(character):
				return false
		return true
	# An address code. Never offered in a browser, which cannot open the socket
	# it names - drawing it would be drawing a button that must fail.
	if OS.has_feature("web"):
		return false
	return not CoopCode.decode(code).is_empty()


## Turns whatever the table returned into rows fit to draw.
##
## **Static and public because everything in it arrived off the internet.** Rows
## are shape-checked, codes that do not parse are dropped rather than drawn - the
## button they would make cannot work - names are stripped of control characters
## and truncated, and counts are clamped. Pulled out of the request callback so a
## gate can hand it the shapes a hostile table would return without needing a
## network at all.
static func parse_rows(data: Variant, own_code: String = "") -> Array:
	var rows: Array = []
	if not (data is Array):
		return rows
	for entry: Variant in (data as Array):
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		var code: String = String(row.get("code", ""))
		if not joinable_code(code):
			continue
		# Our own listing. Offering to join yourself is not useful.
		if not own_code.is_empty() and code == own_code:
			continue
		rows.append({
			"code": code,
			"name": _clean(String(row.get("name", ""))),
			"players": clampi(int(row.get("players", 1)), 1, Balance.COOP_MAX_PLAYERS),
			"age": maxi(int(row.get("age_seconds", 0)), 0),
			# Whether it is locked, never what unlocks it. The view does not
			# return the password at all, so a browsing client can draw a padlock
			# without ever being told what opens it.
			"locked": bool(row.get("locked", false)),
		})
	return rows


func _process(delta: float) -> void:
	if is_listed():
		_heartbeat_left -= delta
		if _heartbeat_left <= 0.0:
			_heartbeat_left = HEARTBEAT_SECONDS
			_beat()
	if _browsing:
		_refresh_left -= delta
		if _refresh_left <= 0.0:
			_refresh_left = REFRESH_SECONDS
			_refresh()


func _idle_if_done() -> void:
	if not _browsing and not is_listed():
		set_process(false)


# --- Talking to the table ----------------------------------------------------

## One request. Every caller gets `ok` and a decoded body, and nothing throws.
##
## Each call gets its own `HTTPRequest`, freed when it answers. One reused node
## cannot have two requests in flight, and the heartbeat and the refresh land on
## the same second often enough for that to matter.
func _call(path: String, method: int, body: Dictionary, done: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		# No player to show a lobby to, and no gate should depend on a network it
		# may not have.
		done.call(false, null)
		return
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray,
				raw: PackedByteArray) -> void:
			var ok: bool = result == HTTPRequest.RESULT_SUCCESS \
				and code >= 200 and code < 300
			var parsed: Variant = null
			if ok and raw.size() > 0:
				parsed = JSON.parse_string(raw.get_string_from_utf8())
			request.queue_free()
			done.call(ok, parsed))
	var headers := PackedStringArray([
		"apikey: " + ANON,
		"Authorization: Bearer " + ANON,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var payload: String = "" if method == HTTPClient.METHOD_GET \
		else JSON.stringify(body)
	if request.request(API + path, headers, method, payload) != OK:
		request.queue_free()
		done.call(false, null)


## Supabase returns a bare scalar for a function that returns one.
func _row_id_from(data: Variant) -> String:
	if data is String:
		return String(data)
	if data is Array and (data as Array).size() > 0:
		return String((data as Array)[0])
	if data is Dictionary:
		return String((data as Dictionary).get("id", ""))
	return ""


func _set_status(text: String) -> void:
	if _status == text:
		return
	_status = text
	status_changed.emit(text)


## A secret this machine keeps, proving it owns the row it created.
func _make_token() -> String:
	var out: String = ""
	for _character: int in 24:
		out += "0123456789abcdefghijklmnopqrstuvwxyz"[randi() % 36]
	return out


## A name fit to draw, from a string that arrived over the internet.
static func _clean(text: String) -> String:
	var out: String = ""
	for character: String in text:
		if character.unicode_at(0) >= 32 and out.length() < MAX_NAME:
			out += character
	out = out.strip_edges()
	return out if not out.is_empty() else "A warden camp"


func _exit_tree() -> void:
	# **No network during teardown.**
	#
	# Withdrawing here meant building an `HTTPRequest` and adding it as a child
	# while the tree was being destroyed, which segfaulted the process
	# intermittently on exit - it passed three runs in a row and failed the
	# fourth. A row left behind is swept within the minute anyway, which is
	# precisely why the sweep exists rather than being a tidy-up nobody relies
	# on. Leaving is handled by `Coop.leave`, which runs while the game is alive.
	_row_id = ""
	_token = ""
