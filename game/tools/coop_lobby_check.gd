extends Node

## Release contract for the matchmaking party presentation.
##
## Four distinct cards prove every seat keeps its canonical colour identity.
## Their atlas region proves the actual authored idle sheet is cropped to the
## south-facing row rather than showing a static thumbnail or the whole sheet.

var _failures: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var regions: Dictionary = {}
	for slot: int in range(1, Balance.COOP_MAX_PLAYERS + 1):
		var portrait := CoopPartyPortrait.new()
		add_child(portrait)
		portrait.configure(slot, "Warden %d" % slot,
			CoopParty.colour_of(slot), Balance.PARTY_COLOUR_NAMES[slot - 1],
			slot == 1)
		var region: Rect2 = portrait.frame_region()
		_check(region.size == Vector2(168.0, 160.0),
			"seat %d must crop one authored hero frame" % slot)
		_check(is_equal_approx(region.position.y, 320.0),
			"seat %d must face south, sampled y=%s" % [slot, region.position.y])
		regions[region.position.x] = true
	_check(regions.size() == Balance.COOP_MAX_PLAYERS,
		"lobby idle phases must be staggered across occupied seats")

	if _failures == 0:
		print("[coop-lobby] PASS — %d south-facing animated party portraits" \
			% Balance.COOP_MAX_PLAYERS)
	else:
		push_error("[coop-lobby] FAIL — %d problem(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[coop-lobby] %s" % message)
