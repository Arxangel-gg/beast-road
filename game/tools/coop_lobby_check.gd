extends Node

## Release contract for the matchmaking party presentation.
##
## Four distinct cards prove every seat keeps its canonical colour identity.
## Their atlas region proves the actual authored idle sheet is cropped to the
## south-facing row rather than showing a static thumbnail or the whole sheet.

var _failures: int = 0
var _reached_gear: bool = false


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
	_test_a_partner_wears_their_gear()
	_check(_reached_gear, "the gear test aborted partway - every check it had not made is unmade")

	if _failures == 0:
		print("[coop-lobby] PASS — %d south-facing animated party portraits" \
			% Balance.COOP_MAX_PLAYERS)
	else:
		push_error("[coop-lobby] FAIL — %d problem(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## **A partner's card wears their gear** (2026-09-26). The lobby drew every
## partner in the bare body, because the roster carried a dye and no gear.
## Driven through the real doors: the host seats a guest, the guest declares,
## the roster goes out, a second party reads it as a guest would, and the card
## is configured the way the co-op screen configures it.
func _test_a_partner_wears_their_gear() -> void:
	var kinds: Array = four_kinds()
	_check(not String(kinds[0]).is_empty() and not String(kinds[1]).is_empty(),
		"the harness needs a drawn weapon and an armour to dress: %s" % str(kinds))
	var look: Dictionary = WardenLook.plain()
	var host := CoopParty.new()
	add_child(host)
	host.open("Host")
	var slot: int = host.seat(77, "Guest")
	host.declare(77, 0, WardenLook.pack(look), kinds)
	var told: Array = []
	for row: Variant in host.to_wire():
		if int((row as Array)[0]) == slot:
			told = row
	_check(told.size() > 6 and told[6] == Hero.clean_worn_kinds(kinds),
		"the roster must carry the guest's gear in its seventh column: %s" % str(told))
	var guest := CoopParty.new()
	add_child(guest)
	guest._on_roster(host.to_wire())
	var seat: CoopParty.Seat = guest.seat_for_slot(slot)
	_check(seat != null and seat.gear == Hero.clean_worn_kinds(kinds),
		"a guest must read the gear off the roster: %s" % (str(seat.gear) if seat != null else "no seat"))
	var bare: Dictionary = outfit_of(look, [])
	var expected: Dictionary = outfit_of(look, kinds)
	_check(not wears_keys_equal(bare, expected),
		"the harness's gear must change the outfit, or this check proves nothing")
	var card := CoopPartyPortrait.new()
	add_child(card)
	card.configure(slot, "Guest", CoopParty.colour_of(slot),
		Balance.PARTY_COLOUR_NAMES[slot - 1], false, WardenLook.pack(look),
		seat.gear if seat != null else [])
	_check(wears(card._stage.animator(), expected),
		"a partner's card must wear the gear the roster carried")
	# A packet may hold anything: a kind this build lacks, or one in the wrong slot.
	host.declare(77, 0, WardenLook.pack(look), ["no_such_kind", kinds[0], kinds[0], kinds[0]])
	var cleaned: Array = []
	for row: Variant in host.to_wire():
		if int((row as Array)[0]) == slot:
			cleaned = (row as Array)[6]
	_check(cleaned == ["", "", "", ""],
		"gear in the wrong slots must arrive as nothing, not as %s" % str(cleaned))
	card.queue_free()
	guest.queue_free()
	host.queue_free()
	_reached_gear = true


static func wears_keys_equal(a: Dictionary, b: Dictionary) -> bool:
	for key: String in ["held", "body_layer", "cape_layer", "helmet"]:
		if str(a.get(key, "")) != str(b.get(key, "")):
			return false
	return true


## One real kind for each dressed slot - weapon, armour, cape, helmet - chosen
## so the outfit they make differs from the bare body's, or a check comparing
## the two could pass with the gear never arriving.
static func four_kinds() -> Array:
	var slots: Array[int] = [GearData.Slot.WEAPON, GearData.Slot.ARMOUR,
		GearData.Slot.CAPE, GearData.Slot.HELMET]
	var out: Array = ["", "", "", ""]
	var ids: Array = ContentDB.gear_kinds.keys()
	ids.sort()
	for index: int in slots.size():
		for id: Variant in ids:
			var gear: GearData = ContentDB.gear(String(id))
			if gear == null or gear.slot != slots[index]:
				continue
			if index == 0 and WardenDress.held_path(gear).is_empty():
				continue
			out[index] = String(id)
			break
	return out


## The outfit four kinds should make on `look`.
static func outfit_of(look: Dictionary, kinds: Array) -> Dictionary:
	var clean: Array[String] = Hero.clean_worn_kinds(kinds)
	return WardenDress.outfit(look, ContentDB.gear(clean[0]), ContentDB.gear(clean[1]),
		ContentDB.gear(clean[2]), ContentDB.gear(clean[3]))


## Whether a dressed animator wears `expected`, on the keys gear decides.
static func wears(animator: HeroAnimator, expected: Dictionary) -> bool:
	if animator == null:
		return false
	for key: String in ["held", "body_layer", "cape_layer", "helmet"]:
		if str(animator._outfit.get(key, "")) != str(expected.get(key, "")):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[coop-lobby] %s" % message)
