extends Node

## Pure/client-side leaderboard regression gate. It never performs a request;
## headless processes are explicitly network-disabled by the autoload.

var _failures: PackedStringArray = []


func _ready() -> void:
	var normal: CampaignTierData = ContentDB.tier("normal")
	var hell: CampaignTierData = ContentDB.tier("hell")
	_check(normal != null and hell != null, "Normal and Hell tiers must load")
	if normal == null or hell == null:
		_finish()
		return

	var loss: Dictionary = {
		"wave": 9, "act": 1, "time": 1200, "town_damage": 400,
		"deaths": 1, "victory": false, "endless_waves": 0,
	}
	var win: Dictionary = {
		"wave": 51, "act": 3, "time": 2400, "town_damage": 100,
		"deaths": 0, "victory": true, "endless_waves": 0,
	}
	var loss_score: int = Score.of(loss, normal)
	var win_score: int = Score.of(win, normal)
	_check(loss_score > 0, "a progressed loss must still score")
	_check(win_score > loss_score, "a full clear must outscore an Act I loss")
	_check(Score.of(win, hell) > win_score, "a harder tier must scale the whole score")

	var wounded: Dictionary = win.duplicate(true)
	wounded["deaths"] = 99
	_check(Score.of(wounded, normal) >= int(float(win_score) * Balance.SCORE_DEATH_FLOOR),
		"death penalties must respect the score floor")

	var bidi: String = "Ward" + String.chr(0x202E) + "en"
	_check(Score.clean_name("\n  Warden\t") == "Warden",
		"control characters must be removed from names")
	_check(Score.clean_name(bidi) == "Warden",
		"bidirectional layout controls must be removed from names")
	_check(Score.clean_name("") == Balance.SCORE_NAME_FALLBACK,
		"an empty name must receive the public fallback")

	var first: String = String(Leaderboard.call("_new_submission_id"))
	var second: String = String(Leaderboard.call("_new_submission_id"))
	_check(first.length() == 36 and first != second,
		"submission ids must be distinct UUID-shaped values")

	var row: Dictionary = Score.row(win, normal, "Warden", 12, "v1.2.3", first)
	_check(row.keys().size() == Score.FIELDS.size(),
		"a submitted row must contain exactly the public schema")
	_check(String(row.get("submission_id", "")) == first,
		"the idempotency key must survive row construction")

	var empty_response: Dictionary = Leaderboard.call("_parse",
		HTTPRequest.RESULT_SUCCESS, 200, "[]".to_utf8_buffer()) as Dictionary
	_check(bool(empty_response.get("ok", false)),
		"an empty successful board is not a network failure")
	_check(not bool(Leaderboard.call("_network_allowed")),
		"headless release gates must never contact the public board")

	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("[leaderboard] PASS — score, sanitising, idempotency and headless isolation")
	else:
		for failure: String in _failures:
			push_error("[leaderboard] " + failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
