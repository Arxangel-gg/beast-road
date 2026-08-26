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
## Long enough for a slow link to answer, short enough that a dead host is
## reported rather than waited on.
##
## Was 8, which is fine on a desk and marginal on anything else - and a poll
## that times out is counted as a failure, so a merely slow connection read as a
## broken one.
const TIMEOUT: float = 20.0


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
			# **Decoded on failure too.** PostgREST answers a raised exception
			# with a JSON body naming it, and throwing that away left every
			# failure looking the same to the caller - a service saying "this
			# room is gone" was indistinguishable from a request that timed out
			# on a busy connection, which are opposite problems with opposite
			# fixes. `ok` still says whether it worked; `parsed` now says why
			# it did not.
			if raw.size() > 0:
				parsed = JSON.parse_string(raw.get_string_from_utf8())
			if not ok and not (parsed is Dictionary):
				# A failure with no body from the service is a failure that
				# never reached it. `result` says which - timeout, could not
				# connect, no response - and without it every one of them is
				# just `false`, which is how a browser losing half its requests
				# looked exactly like a service that was refusing them.
				parsed = {"code": "HTTP", "result": result, "status": code}
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
	return _random_text(6, "0123456789ABCDEFGHJKMNPQRSTVWXYZ")


## A secret this machine keeps, proving it owns a row it created.
##
## **Not `randi()`.** This is a capability: whoever holds it *is* that side of
## the room, and the engine's global RNG is a seeded PRNG shared with gameplay,
## so its output is neither private nor guaranteed distinct between two copies
## of the game that started life the same way.
##
## Two peers drawing the same token is not a near miss, it is a deadlock, and a
## silent one. `enter_room` will set `guest_token` to a string that already sits
## in `host_token`, and from then on the service resolves *both* peers to the
## host - so `read_signals`, which returns only rows whose sender is the other
## side, hides each peer's notes from the other. Both sides poll successfully
## for forty-five seconds, both post successfully, and neither hears anything.
## Reproduced against the live service on 2026-08-26: with one shared token the
## host hears 0 notes, with two distinct tokens it hears 1.
static func token() -> String:
	return _random_text(24, "0123456789abcdefghijklmnopqrstuvwxyz")


## Random text from the OS, drawn without modulo bias.
##
## Bytes that would land in the short tail of the alphabet are discarded rather
## than folded in, so every character is equally likely. That matters more for
## `token` than for `room_code`, but there is no reason for the room code to be
## the guessable one - a predictable code is a stranger in your game.
static func _random_text(length: int, alphabet: String) -> String:
	var span: int = alphabet.length()
	var limit: int = 256 - (256 % span)
	var crypto := Crypto.new()
	var out: String = ""
	while out.length() < length:
		for byte: int in crypto.generate_random_bytes(length * 2):
			if byte >= limit:
				continue
			out += alphabet[byte % span]
			if out.length() == length:
				break
	return out
