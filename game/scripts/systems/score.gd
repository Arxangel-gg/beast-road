class_name Score
extends RefCounted

## What a finished run is worth, as one number.
##
## Pure functions over a plain summary dictionary — the same dictionary
## `EventBus.run_ended` already carries — with no autoload reach, so the formula
## can be checked without a save, a scene, or a network. `Leaderboard` owns
## submitting it; this owns what it means.
##
## ## Why one number, and what it deliberately ignores
##
## A single score makes one board instead of four, which is the point of a board:
## you want to know where you stand, not where you stand on the third of five
## axes. The cost is that the formula becomes a balance surface — every
## coefficient is a statement about what playing well means — so all of them live
## in `Balance` and none of them are hidden in here.
##
## **Hero level is not scored.** It is recorded and shown, because it is context
## a reader wants, but it must not be a term: levels and gear persist across runs
## now, so scoring them would rank the player who has played most rather than the
## player who played best. The tier a run was played on carries that instead —
## Nightmare and Hell are level-gated, so the tier already says roughly what the
## hero was, and the boards are read per tier.
##
## **Gold, resources and towers built are not scored.** They are means, not ends;
## rewarding them would pay for hoarding and for building towers that were never
## needed.

## Every field a submitted run carries, in the order a board shows them.
const FIELDS: Array[String] = ["submission_id", "name", "tier", "score", "act",
	"wave", "hero_level", "duration", "victory", "seed", "version"]


## The score for one finished run.
##
## `summary` is the dictionary `run_ended` emits. Anything missing reads as zero,
## so an older summary scores low rather than erroring — a board is not worth
## crashing a debrief over.
static func of(summary: Dictionary, tier: CampaignTierData) -> int:
	var total: float = 0.0

	# Progress, which is most of it. A run is a road and the question a board
	# answers first is how far down it you got.
	total += float(_number(summary, "wave")) * Balance.SCORE_PER_WAVE
	total += float(maxi(_number(summary, "act") - 1, 0)) * Balance.SCORE_PER_ACT

	if bool(summary.get("victory", false)):
		total += Balance.SCORE_VICTORY

		# Speed, and only on a win. Timing a loss would reward dying quickly,
		# and timing a win rewards a defence that holds without being nursed.
		# Below par earns nothing rather than costing something: a slow win is
		# still a win and should not score under a fast loss.
		var par: float = Balance.SCORE_PAR_SECONDS
		var spare: float = par - float(_number(summary, "time"))
		total += clampf(spare / maxf(par, 1.0), 0.0, 1.0) * Balance.SCORE_SPEED

	# What the town had left. Measured from damage taken rather than from health
	# remaining, because Hearthmend repairs it — and a town that was rebuilt
	# three times was not defended, it was patched.
	var taken: float = float(_number(summary, "town_damage"))
	var intact: float = clampf(1.0 - taken / maxf(Balance.TOWN_MAX_HP, 1.0), 0.0, 1.0)
	total += intact * Balance.SCORE_TOWN_INTACT

	# Deaths cost, but cannot take a run below what its progress earned. A
	# formula that can reach zero invites a player to stop playing rather than
	# risk one more death, which is the opposite of what a board is for.
	var deaths: float = float(_number(summary, "deaths")) * Balance.SCORE_DEATH_COST
	total = maxf(total - deaths, total * Balance.SCORE_DEATH_FLOOR)

	# The tier multiplies at the end so it scales the whole run and not one term.
	# Boards are still read per tier; this only keeps a Hell run from sorting
	# under a Normal one on an all-tiers view.
	total *= tier.score_scale if tier != null else 1.0
	return clampi(int(round(total)), 0, Balance.LEADERBOARD_SCORE_MAX)


## One run, in the shape the leaderboard stores.
##
## Built here rather than in `Leaderboard` so that what a row *is* and what a row
## is *worth* are decided in the same place, and so the submitter has nothing to
## get wrong.
static func row(summary: Dictionary, tier: CampaignTierData, player: String,
		hero_level: int, version: String, submission_id: String) -> Dictionary:
	return {
		"submission_id": submission_id.left(36),
		"name": clean_name(player),
		"tier": tier.id if tier != null else "normal",
		"score": of(summary, tier),
		"act": clampi(_number(summary, "act"), 1, Balance.LEADERBOARD_ACT_MAX),
		"wave": clampi(_number(summary, "wave"), 0, Balance.LEADERBOARD_WAVE_MAX),
		"hero_level": clampi(hero_level, 1, Balance.HERO_MAX_LEVEL),
		"duration": clampi(_number(summary, "time"), 0,
			Balance.LEADERBOARD_DURATION_MAX),
		"victory": bool(summary.get("victory", false)),
		# `str`, not `String`: a run seed is an int and Godot 4 has no
		# `String(int)` constructor, so this threw on every completed run and
		# took the whole row with it.
		"seed": str(summary.get("seed", "")).left(32),
		"version": safe_version(version),
	}


## A row received from the network or an edited save, reduced to the public
## schema and bounded before any UI sees it.
static func clean_row(entry: Dictionary) -> Dictionary:
	return {
		"submission_id": String(entry.get("submission_id", "")).left(36),
		"name": clean_name(String(entry.get("name", ""))),
		"tier": String(entry.get("tier", "normal")).left(16),
		"score": clampi(_value_as_int(entry.get("score", 0)), 0,
			Balance.LEADERBOARD_SCORE_MAX),
		"act": clampi(_value_as_int(entry.get("act", 1)), 1,
			Balance.LEADERBOARD_ACT_MAX),
		"wave": clampi(_value_as_int(entry.get("wave", 0)), 0,
			Balance.LEADERBOARD_WAVE_MAX),
		"hero_level": clampi(_value_as_int(entry.get("hero_level", 1)), 1,
			Balance.HERO_MAX_LEVEL),
		"duration": clampi(_value_as_int(entry.get("duration", 0)), 0,
			Balance.LEADERBOARD_DURATION_MAX),
		"victory": bool(entry.get("victory", false)),
		"seed": str(entry.get("seed", "")).left(32),
		"version": safe_version(String(entry.get("version", ""))),
	}


## A version string the board will actually accept.
##
## Bounded at both ends, not just the top. The table checks
## `char_length(version) between 1 and 32`; capping the maximum and leaving the
## minimum to chance is what made an empty version a permanent 400 rather than a
## cosmetic blank - the row was rejected, requeued, and retried against a
## constraint no amount of retrying could satisfy.
static func safe_version(value: String) -> String:
	var trimmed: String = value.strip_edges().left(32)
	return trimmed if not trimmed.is_empty() else Balance.SCORE_VERSION_FALLBACK


## Names are the one field a stranger chooses, so they are the one field that
## needs a rule.
##
## Trimmed, capped, and stripped of anything that is not printable — a board is
## rendered into a `Label`, and a name carrying newlines or control characters
## would break the row it sits in for everyone reading it, not just its owner.
static func clean_name(player: String) -> String:
	var out: String = ""
	for character: String in player.strip_edges():
		var code: int = character.unicode_at(0)
		if not _unsafe_name_code(code):
			out += character
		if out.length() >= Balance.SCORE_NAME_MAX:
			break
	return out if not out.is_empty() else Balance.SCORE_NAME_FALLBACK


## Format controls can reverse or hide the rest of a public row even though
## they are technically printable. Keep international names; reject only the
## control ranges that alter layout rather than draw a glyph.
static func _unsafe_name_code(code: int) -> bool:
	return code < 32 or (code >= 127 and code <= 159) \
		or (code >= 0x200B and code <= 0x200F) \
		or (code >= 0x202A and code <= 0x202E) \
		or (code >= 0x2066 and code <= 0x2069) or code == 0xFEFF


## A summary field as an int, however it was stored. Times are floats and waves
## are ints, and a board should not care which.
static func _number(summary: Dictionary, key: String) -> int:
	return _value_as_int(summary.get(key, 0))


static func _value_as_int(value: Variant) -> int:
	if value is float:
		return int(round(value as float))
	if value is int:
		return value as int
	return 0
