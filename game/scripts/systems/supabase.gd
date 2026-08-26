class_name Supabase
extends Node

## One place that knows how to talk to the project's REST endpoint.
##
## Two systems need it - the public lobby list and the WebRTC signalling that
## introduces two players to each other - and a second copy of the URL, the key
## and the header block is a second thing to get wrong. Everything here is
## request/response with a callback; nothing throws, and nothing blocks.
##
## **The anon key is meant to be in the client.** That is what an anon key is: it
## identifies the project and grants nothing on its own. What protects the data
## is on the other side - the tables take no direct writes, only `security
## definer` functions that check a token, and reads go through views with no
## secrets in them. See `docs/MATCHMAKING.md`.

const API: String = "https://xscyioampvjfqcciccie.supabase.co/rest/v1/"
const ANON: String = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhzY3lpb2FtcHZqZnFjY2ljY2llIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODcyNDI2NDksImV4cCI6MjEwMjgxODY0OX0.oN74ghnJqAlWtoRKWJVzb4Otw19lH68po_v2z2JlXmU"

## Long enough for a slow connection, short enough that a blocked host is
## reported rather than waited on forever. The launcher learned that lesson the
## expensive way: an HTTP client with no timeout does not fail, it hangs.
const TIMEOUT: float = 8.0


## One request. The callback always runs, exactly once, with `ok` and a decoded
## body. `ok` false covers every failure - refused, timed out, unparseable - and
## callers are expected to treat all of them the same way, because to a player
## they are the same thing.
##
## Each call gets its own `HTTPRequest`, freed when it answers: one node cannot
## have two requests in flight, and signalling polls while the lobby refreshes
## often enough for that to matter.
func request(path: String, method: int, body: Dictionary, done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	http.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray,
				raw: PackedByteArray) -> void:
			var ok: bool = result == HTTPRequest.RESULT_SUCCESS \
				and code >= 200 and code < 300
			var parsed: Variant = null
			if ok and raw.size() > 0:
				parsed = JSON.parse_string(raw.get_string_from_utf8())
			http.queue_free()
			done.call(ok, parsed))
	var headers := PackedStringArray([
		"apikey: " + ANON,
		"Authorization: Bearer " + ANON,
		"Content-Type: application/json",
		"Accept: application/json",
	])
	var payload: String = "" if method == HTTPClient.METHOD_GET \
		else JSON.stringify(body)
	if http.request(API + path, headers, method, payload) != OK:
		http.queue_free()
		done.call(false, null)


## Calls a database function. Everything this project writes goes through one.
##
## Not `rpc`: that is `Node.rpc`, Godot's own multiplayer call, and shadowing it
## on a Node is a parse error rather than a subtle bug - which is the good case.
func call_rpc(name: String, arguments: Dictionary, done: Callable) -> void:
	request("rpc/" + name, HTTPClient.METHOD_POST, arguments, done)


## A short, human-readable code. Used for rooms, and for nothing that has to be
## unguessable on its own - the room it names is empty the moment a partner
## arrives, and holds no secrets while it waits.
##
## No I, L, O or U: the first three are unreadable next to 1 and 0, and the
## fourth turns an alphabet of six characters into an occasional embarrassment.
static func room_code() -> String:
	const LETTERS: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
	var out: String = ""
	for _character: int in 6:
		out += LETTERS[randi() % LETTERS.length()]
	return out


## A secret this machine keeps, proving it owns a row it created.
static func token() -> String:
	var out: String = ""
	for _character: int in 24:
		out += "0123456789abcdefghijklmnopqrstuvwxyz"[randi() % 36]
	return out
