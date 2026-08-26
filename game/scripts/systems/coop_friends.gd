class_name CoopFriends
extends Node

## Who you know, and which of them is playing right now.
##
## **No accounts, deliberately.** Signing in would mean holding passwords,
## resetting them and storing something worth stealing, for a game whose entire
## social feature is "let me play with the person I am already talking to".
##
## So a friend is a **play code**: six characters, generated once, kept in the
## save, given out the way a phone number is. The service stores one row per code
## - a name, a heartbeat, and the room they are hosting if they are hosting one -
## and answers questions about codes you already have. It will not list them, so
## a friends list is a lookup rather than a directory of everybody online.
##
## A row leaks nothing its owner did not hand out.

signal friends_changed(rows: Array)

## {"code", "name", "online", "room"} per known friend, however they are doing.
var _rows: Array = []
var _presence_left: float = 0.0
var _refresh_left: float = 0.0
var rest: Supabase = null


func _ready() -> void:
	set_process(false)


func rows() -> Array:
	return _rows


## Starts announcing this player and watching for the others. Called when the
## co-op screen opens, stopped when it closes: a friends list nobody is looking
## at is a request every twelve seconds for nothing.
func begin() -> void:
	set_process(true)
	_presence_left = 0.0
	_refresh_left = 0.0


func end() -> void:
	set_process(false)
	forget()


func _process(delta: float) -> void:
	_presence_left -= delta
	if _presence_left <= 0.0:
		_presence_left = Balance.PRESENCE_INTERVAL
		_announce()
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = Balance.FRIENDS_REFRESH
		refresh()


## Says this player is here, and where they are if anybody can join them.
##
## The room code is sent **only while hosting one**, which is the whole point: a
## friend seeing "in a room" can act on it, and a friend seeing where somebody is
## in a private game could not and should not.
func _announce() -> void:
	if rest == null:
		return
	rest.call_rpc("announce_presence", {
		"p_play_code": MetaState.own_play_code(),
		"p_name": Coop.lobby_name(),
		"p_room": Coop.room_code if not Coop.room_code.is_empty() else null,
	}, func(_ok: bool, _data: Variant) -> void: pass)


func refresh() -> void:
	var codes: Array = MetaState.friend_codes()
	if rest == null or codes.is_empty():
		_rows = _offline_rows()
		friends_changed.emit(_rows)
		return
	rest.call_rpc("friends_online", {"p_codes": codes},
		func(ok: bool, data: Variant) -> void:
			var live: Dictionary = {}
			if ok and data is Array:
				for entry: Variant in (data as Array):
					if not (entry is Dictionary):
						continue
					var row: Dictionary = entry
					live[String(row.get("play_code", ""))] = {
						"name": String(row.get("name", "")),
						"room": String(row.get("room_code", "")),
					}
			_rows = _offline_rows()
			for row: Variant in _rows:
				var friend: Dictionary = row
				var seen: Variant = live.get(String(friend["code"]), null)
				if seen is Dictionary:
					friend["online"] = true
					friend["room"] = String((seen as Dictionary).get("room", ""))
					# Their own name wins over the one stored here only when this
					# player never chose one - a nickname you wrote down is what
					# you want to see.
					if String(friend["name"]).is_empty():
						friend["name"] = String((seen as Dictionary).get("name", ""))
			friends_changed.emit(_rows))


## Everyone known, assumed offline. The shape the list is drawn from either way,
## so an unreachable service shows a greyed-out list rather than an empty one.
func _offline_rows() -> Array:
	var out: Array = []
	for entry: Variant in MetaState.friends:
		var row: Dictionary = entry
		out.append({
			"code": String(row.get("code", "")),
			"name": String(row.get("name", "")),
			"online": false,
			"room": "",
		})
	return out


## Takes this player off the list. Called when the co-op screen closes, while
## the game is still alive.
##
## **Not from `_exit_tree`.** Starting a request during teardown means adding an
## `HTTPRequest` to a tree that is being destroyed, which segfaults on exit often
## enough to fail a check and rarely enough to look like bad luck. The service
## drops anything unheard-from for two minutes, which is why that sweep exists.
func forget() -> void:
	if rest != null and not MetaState.play_code.is_empty():
		rest.call_rpc("forget_presence", {"p_play_code": MetaState.play_code},
			func(_ok: bool, _data: Variant) -> void: pass)
