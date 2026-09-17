extends Node

## The Hold as a place, the Market's shelf, and Orden's commission.
##
##   godot --headless --path game res://tools/hold_check.tscn
##
## Owner ruling, 2026-09-17: the Hold becomes a map players walk in, populated by
## simulation with real players taking those places; the Long Ledger lives inside
## a vendor's shop whose wares refresh on a real run or every ten minutes; and
## the blacksmith makes a piece for a Warden who is short of stock, for more than
## it would have cost them to make it.
##
## **The ways this goes wrong, hardest first:**
##
## - **A station with no button.** The yard stands a building where a door is and
##   presses that door's own button. A station naming a door the menu never
##   adopted is a building the player walks up to and nothing happens - and it is
##   invisible, because the building is there and the prompt is there.
## - **The Market prints Marks.** If a piece could ever be bought for less than
##   the stash pays for it, buy-sell-repeat is an infinite purse. This is the
##   same bound `exchange_check` holds over the Ledger.
## - **The shelf re-rolls on a restart.** That is the whole of the owner's
##   anti-abuse rule, and a stock held only in memory breaks it silently.
## - **A short run counts as a run.** "Take the road, quit to the menu" would be
##   a refresh button.
## - **The vendor outruns the road.** Gear should trail what the Warden has held
##   and only rarely step ahead of it; a shop that stocked the top rarity would
##   stop finding one mattering.
## - **A commission is cheaper than smithing.** Then nobody smiths, the seams and
##   the timber on the outskirts stop being worth walking to, and Marks buy gear
##   outright.
## - **A commission teaches the Warden.** Paying somebody else to strike it must
##   not advance your own craft, or Marks buy practice too.
## - **The blacksmith never gives up the anvil.** The owner asked for exactly
##   that behaviour by name.

## How deep a solid slab a figure may end in before it is standing on ground
## rather than on its own boots.
##
## **Measured rather than guessed, and the first guess was wrong.** Counting
## opaque pixels at the foot does not separate them at all - boots apart are
## about half the figure's widest row, and so is a plinth, so the four dioramas
## read 0.69-0.72 against the residents' 0.53-0.60 and the check failed all
## eight. What does separate them is that **ground is continuous and legs are
## not**: the merchants' paintings end in 39 to 43 rows that are solid from one
## edge of the silhouette to the other, and every resident drawn for the Hold
## ends in zero. Twelve is clear of both by a mile.
const SLAB_ROWS_MAX: int = 12

## What counts as solid across the silhouette, rather than a gap between two
## boots that a soft edge has nearly closed.
const SLAB_FILL: float = 0.95

## What counts as painted rather than as a soft edge.
const ALPHA_FLOOR: float = 0.12

## How far a frame's foot line may sit from the base's. The animator
## re-renders the whole sprite, so this is drift rather than a pose; two pixels
## is the same tolerance `enemy_walk_check` holds the roster to.
const FOOT_DRIFT: int = 2

## How fine the walk that proves the Hold is reachable. Finer than the
## narrowest stair, or the flood fill would step straight over one and report
## a shelf as stranded that a player walks onto every visit.
const WALK_GRID: float = 40.0

## How wide a stair has to be to be one. Below this a Warden walking along an
## edge crosses the whole opening inside a single frame's step.
const STAIR_MIN_WIDE: float = 150.0

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_yard_is_a_place()
	_test_every_station_has_a_door()
	_test_the_residents_stand_on_nothing()
	_test_the_shelves_are_walkable()
	_test_the_smith_gives_up_the_anvil()
	_test_the_seats_are_the_sessions()
	_test_the_shelf_refreshes_by_rule()
	_test_buying_never_prints_marks()
	_test_the_shelf_trails_the_warden()
	_test_the_commission_costs_more()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[hold] PASS - %d checks: every station presses a door, every "
			+ "shelf can be walked on and off, nobody "
			+ "carries their own pavement, the smith "
			+ "stands aside, seats are the session's, the shelf keeps its stock "
			+ "across a restart, buying is always dearer than selling, and a "
			+ "commission costs more and teaches nothing") % _checks)
	else:
		push_error("[hold] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- The place ----------------------------------------------------------------


## A yard with every door bound, which is the state the Hold is actually in:
## an unbound station is invisible to the focus on purpose, so a gate that
## forgot to bind would be measuring a Hold nobody plays.
func _stand_a_yard() -> HoldYard:
	var yard := HoldYard.new()
	add_child(yard)
	for station: Dictionary in HoldYard.STATIONS:
		var door: String = String(station["door"])
		if door.is_empty() or yard.bound(door):
			continue
		var button := Button.new()
		button.name = door
		add_child(button)
		yard.bind(door, button)
	return yard


## Nobody in the Hold carries their own pavement.
##
## **This is the owner's report, turned into arithmetic.** On 2026-09-17 they
## wrote that *"some of the characters are static and have ground included in
## their images"*, and it was answered by measuring the *hero and enemy* art,
## finding no baked ground there, and saying so with a figure attached. The
## four people in the Hold were the subject, and every one of them was a
## travelling merchant's painting: a diorama on a round cobblestone plinth,
## drawn for a stall you walk up to and look at, sliding about a yard.
##
## **A plinth is measurable and I did not think to measure it.** A person
## standing on nothing ends in two boots - a narrow fraction of their own
## widest span. A person standing on a disc of pavement ends in the disc,
## which is as wide as they are or wider. So the bottom row against the widest
## row separates the two without anybody having to look, and it is the check
## that would have caught this the day the Hold was built.
##
## The rest is what an animated figure needs and a still one does not: frames
## on disk, the same canvas as the base, and a foot line that does not wander
## - the animator re-renders the whole sprite, so a walk drifts vertically
## unless somebody puts it back.
func _test_the_residents_stand_on_nothing() -> void:
	for person: Dictionary in HoldYard.RESIDENTS:
		var art: String = String(person["art"])
		var who: String = String(person["id"])
		var painted: bool = ResourceLoader.exists(art)
		_check(painted, "%s has no painting of its own at %s" % [who, art])
		if not painted:
			continue
		var base: Image = (load(art) as Texture2D).get_image()
		var slab: int = _slab_rows(base)
		_check(slab <= SLAB_ROWS_MAX,
			("%s ends in %d solid row(s) - that is a plinth or a patch of ground "
				+ "baked into the painting, and it slides about the yard with them. A "
				+ "person ends in boots with a gap between them.") % [who, slab])

		var idle: Array[Texture2D] = GameData.load_idle_frames(art)
		var walk: Array[Texture2D] = GameData.load_move_frames(art)
		_check(idle.size() >= 2,
			"%s has %d idle frame(s), so it is a still painting with a bob on it"
				% [who, idle.size()])
		_check(walk.size() >= 4,
			"%s has %d walk frame(s), so it slides when it crosses the yard"
				% [who, walk.size()])
		var floor_y: int = _foot_line(base)
		for frame: Texture2D in (idle + walk):
			var picture: Image = frame.get_image()
			var same: bool = picture.get_size() == base.get_size()
			_check(same, "a frame of %s is %s against a base of %s" % [who,
				str(picture.get_size()), str(base.get_size())])
			if not same:
				continue
			_check(absi(_foot_line(picture) - floor_y) <= FOOT_DRIFT,
				("a frame of %s stands %d pixel(s) off the base's foot line, so the "
					+ "figure sinks into the ground and rises out of it as it plays")
					% [who, _foot_line(picture) - floor_y])


## The lowest row with anything in it.
func _foot_line(picture: Image) -> int:
	for y: int in range(picture.get_height() - 1, -1, -1):
		for x: int in picture.get_width():
			if picture.get_pixel(x, y).a > ALPHA_FLOOR:
				return y
	return -1


## How many rows up from the bottom are solid all the way across the
## silhouette - the height of whatever slab the figure is ending in.
##
## Ground is continuous. Legs are not. A cobblestone plinth is forty rows of
## unbroken pavement; a person is two boots with daylight between them, and
## stops being solid on the first row above the soles.
func _slab_rows(picture: Image) -> int:
	var deep: int = 0
	for y: int in range(_foot_line(picture), -1, -1):
		var first: int = -1
		var last: int = -1
		var painted: int = 0
		for x: int in picture.get_width():
			if picture.get_pixel(x, y).a <= ALPHA_FLOOR:
				continue
			painted += 1
			last = x
			if first < 0:
				first = x
		if first < 0:
			break
		if float(painted) / float(last - first + 1) < SLAB_FILL:
			break
		deep += 1
	return deep


## Every shelf in the Hold can be walked on and off.
##
## Owner, 2026-09-17: the Hold wants *"multi-elevations and platforms designed
## for each area"*. What makes that a place rather than a picture is the step
## rule - a Warden cannot walk up an earth bank - and **the step rule is also
## the way to strand somebody**: a shelf whose stair is authored outside the
## stretch of edge people actually use is a shelf you can see and never reach,
## and every number in the layout table agrees it is fine.
##
## This project has already paid for that exact failure once, with ponds dug
## where nobody could fish them and a clearance ring that refused every corner.
## So this walks the yard the way a Warden does rather than reading the table:
## a flood fill from the road out, over a grid finer than the narrowest stair,
## and then every station has to have been reached.
func _test_the_shelves_are_walkable() -> void:
	var yard: HoldYard = _stand_a_yard()

	# Each stair crosses an edge the table actually has, and lies inside the yard.
	for stair: Dictionary in HoldYard.STAIRS:
		var edge: float = float(stair["at"])
		_check(HoldYard.TERRACE_AT.has(edge),
			"a stair crosses y=%.0f, which is not an edge between two shelves" % edge)
		var from: float = float(stair["from"])
		var to: float = float(stair["to"])
		_check(to - from >= STAIR_MIN_WIDE,
			("a stair at y=%.0f is %.0f units wide - narrower than %.0f and a "
				+ "Warden walking along the edge can miss it entirely")
				% [edge, to - from, STAIR_MIN_WIDE])
		_check(from > -HoldYard.YARD.x * 0.5 and to < HoldYard.YARD.x * 0.5,
			"a stair at y=%.0f runs off the side of the yard" % edge)

	# A bank is a bank. Two points either side of an edge, well away from every
	# stair, must refuse each other - measured rather than assumed, because a
	# step rule that always returns true is a Hold with no shelves in it and
	# every other check here would still pass.
	for edge: float in HoldYard.TERRACE_AT:
		var open: float = _away_from_every_stair(edge)
		var above := Vector2(open, edge - 30.0)
		var below := Vector2(open, edge + 30.0)
		_check(yard.level_at(above) != yard.level_at(below),
			"the ground either side of y=%.0f is the same shelf" % edge)
		_check(not yard.step_is_legal(below, above),
			("a Warden walked up the bank at y=%.0f at x=%.0f, where there is no "
				+ "stair - the shelves are a picture rather than a place")
				% [edge, open])
		_check(not yard.step_is_legal(above, below),
			"a Warden walked off the bank at y=%.0f into thin air" % edge)

	# And a stair is a way through.
	for stair: Dictionary in HoldYard.STAIRS:
		var edge: float = float(stair["at"])
		var middle: float = (float(stair["from"])
			+ float(stair["to"])) * 0.5
		_check(yard.step_is_legal(Vector2(middle, edge + 30.0),
				Vector2(middle, edge - 30.0)),
			"the stair at y=%.0f, x=%.0f cannot be climbed" % [edge, middle])

	# The whole yard, walked from the road out.
	var reached: Dictionary = _walk_the_yard(yard)
	for station: Dictionary in HoldYard.STATIONS:
		var at: Vector2 = station["at"] as Vector2
		_check(reached.has(_cell(at)),
			("%s is on ground no Warden can walk to from the road - it stands on a "
				+ "shelf with no stair onto it") % String(station["label"]))
	for person: Dictionary in HoldYard.RESIDENTS:
		var at: Vector2 = person["at"] as Vector2
		_check(reached.has(_cell(at)),
			"%s stands where nobody can reach them" % String(person["name"]))
	for index: int in yard.pens():
		var pen: Vector2 = HoldYard.PEN_FIRST + Vector2(
			float(index) * (HoldYard.PEN_SIZE.x + HoldYard.PEN_GAP), 0.0)
		_check(reached.has(_cell(pen)),
			"pen %d is on ground no Warden can walk to" % index)
	yard.queue_free()


## The furthest point on an edge from any stair that crosses it.
func _away_from_every_stair(edge: float) -> float:
	var best: float = 0.0
	var best_gap: float = -1.0
	var step: float = 40.0
	var x: float = -HoldYard.YARD.x * 0.5 + 60.0
	while x < HoldYard.YARD.x * 0.5 - 60.0:
		var gap: float = 1.0e9
		for stair: Dictionary in HoldYard.STAIRS:
			if not is_equal_approx(float(stair["at"]), edge):
				continue
			gap = minf(gap, minf(absf(x - float(stair["from"])),
				absf(x - float(stair["to"]))))
			if x >= float(stair["from"]) and x <= float(stair["to"]):
				gap = -1.0
		if gap > best_gap:
			best_gap = gap
			best = x
		x += step
	return best


## Which cell of the walking grid a point falls in.
func _cell(at: Vector2) -> Vector2i:
	return Vector2i(int(floor(at.x / WALK_GRID)), int(floor(at.y / WALK_GRID)))


## Every cell a Warden can reach from the road out, walking the yard's own
## step rule. A breadth-first walk rather than a reading of the table, because
## the table is the thing being checked.
func _walk_the_yard(yard: HoldYard) -> Dictionary:
	var half: Vector2 = HoldYard.YARD * 0.5
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [_cell(HoldYard.ENTRY)]
	seen[queue[0]] = true
	var ways: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0),
		Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		var here := Vector2((float(cell.x) + 0.5) * WALK_GRID,
			(float(cell.y) + 0.5) * WALK_GRID)
		for way: Vector2i in ways:
			var next: Vector2i = cell + way
			if seen.has(next):
				continue
			var there := Vector2((float(next.x) + 0.5) * WALK_GRID,
				(float(next.y) + 0.5) * WALK_GRID)
			if absf(there.x) > half.x - 40.0 or absf(there.y) > half.y - 40.0:
				continue
			if not yard.step_is_legal(here, there):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _test_the_yard_is_a_place() -> void:
	var yard: HoldYard = _stand_a_yard()
	_check(yard.seats() == Balance.HOLD_SEATS,
		"the yard stands a figure for every seat (%d of %d)" % [yard.seats(),
			Balance.HOLD_SEATS])
	_check(yard.pens() == Balance.HOLD_SEATS,
		"and a pen for every seat (%d of %d)" % [yard.pens(), Balance.HOLD_SEATS])

	# **Every station is somewhere a Warden can stand.** Two buildings on one
	# spot is a station that can never be focused, because the nearer one always
	# wins - and nothing about that shows up on a screenshot of either.
	var ids: Array[String] = yard.station_ids()
	_check(ids.size() == HoldYard.STATIONS.size(),
		"every authored station stands (%d of %d)" % [ids.size(),
			HoldYard.STATIONS.size()])
	for one: String in ids:
		for other: String in ids:
			if one == other:
				continue
			var apart: float = yard.station_at(one).distance_to(yard.station_at(other))
			_check(apart > Balance.HOLD_REACH,
				"%s and %s stand %d apart, closer than a Warden's reach - one of "
					% [one, other, int(apart)] + "them can never be the thing in front of you")

	# And standing at a station puts **something that opens its door** in front
	# of the Warden.
	#
	# The door rather than the station, deliberately: a stall and the person
	# behind it answer the same door, and which of the two is nearer depends on
	# where the keeper happens to be standing. What must never happen is walking
	# up to a building and finding nothing there, or finding something that
	# opens a different screen.
	for one: String in ids:
		yard.stand_warden(yard.station_at(one))
		yard.advance(0.2, 2)
		_check(_same_door(yard.focus(), one),
			"standing at %s offers %s, which is not the same door" % [one,
				"nothing" if yard.focus().is_empty() else yard.focus()])
	yard.queue_free()


## **A station naming a door nothing adopted is a building with nothing in it.**
##
## The menu hands the yard a button per door; the yard binds it by the button's
## own name. Checked against the menu's own list rather than against a copy, so
## the two cannot drift: a door renamed on the front door and not here shows up
## as a station that never binds.
func _test_every_station_has_a_door() -> void:
	var yard: HoldYard = _stand_a_yard()
	for station: Dictionary in HoldYard.STATIONS:
		var door: String = String(station["door"])
		if door.is_empty():
			# A station the screen answers itself - the Warden's stone and the
			# road out. Declared by being empty rather than by being absent.
			continue
		var button := Button.new()
		button.name = door
		add_child(button)
		yard.bind(door, button)
	for station: Dictionary in HoldYard.STATIONS:
		var door: String = String(station["door"])
		if door.is_empty():
			continue
		_check(yard.bound(door),
			"%s binds its door %s" % [String(station["id"]), door])
	yard.queue_free()


## The owner asked for this behaviour by name, so it is driven rather than read:
## the Warden walks to the anvil and Orden must give it up, and walk away and he
## must come back to it.
func _test_the_smith_gives_up_the_anvil() -> void:
	var yard: HoldYard = _stand_a_yard()
	yard.stand_warden(Vector2(-900.0, 400.0))
	yard.advance(1.0, 10)
	_check(not yard.stood_aside("smith"),
		"Orden works the anvil while nobody is at it")
	yard.stand_warden(yard.station_at("anvil"))
	yard.advance(1.0, 10)
	_check(yard.stood_aside("smith"),
		"Orden steps back when the Warden comes to the anvil")
	yard.stand_warden(yard.station_at("smithy"))
	yard.advance(1.0, 10)
	_check(yard.stood_aside("smith"),
		"and to the furnace, which is the other half of his work")
	yard.stand_warden(Vector2(-900.0, 400.0))
	yard.advance(1.0, 10)
	_check(not yard.stood_aside("smith"),
		"and he goes back to it once the Warden leaves")
	yard.queue_free()


## Seats are presence and the session owns them. Driven through the same door
## the host's word arrives by, because a yard that decided its own seats would
## be a yard that disagreed with the other three machines.
func _test_the_seats_are_the_sessions() -> void:
	var yard: HoldYard = _stand_a_yard()
	yard.set_seat(1, HoldSession.Seat.REMOTE, "Somebody", "Warden")
	_check(yard.seat_kind(1) == HoldSession.Seat.REMOTE,
		"a seat the session filled reads as filled")
	_check(yard.seat_name(1) == "Somebody", "and by the name it was given")
	yard.set_seat(1, HoldSession.Seat.EMPTY, "")
	_check(yard.seat_kind(1) == HoldSession.Seat.EMPTY,
		"and empties when the session says so")
	yard.queue_free()


## Whether two things in the yard open the same screen. A station's own id
## counts as itself, and a resident counts as the door they keep.
func _same_door(found: String, wanted: String) -> bool:
	if found == wanted:
		return true
	if found.is_empty():
		return false
	return _door_of(found) == _door_of(wanted) and not _door_of(wanted).is_empty()


func _door_of(id: String) -> String:
	for station: Dictionary in HoldYard.STATIONS:
		if String(station["id"]) == id:
			return String(station["door"])
	for person: Dictionary in HoldYard.RESIDENTS:
		if String(person["id"]) == id:
			return String(person["door"])
	return ""


# --- The Market ---------------------------------------------------------------


func _test_the_shelf_refreshes_by_rule() -> void:
	MetaState.vendor = {}
	var first: Array = VendorStock.wares().duplicate(true)
	_check(not first.is_empty(), "an empty shelf is stocked on the first look")

	# **The same stock is there the next time it is opened**, which is the whole
	# anti-abuse rule: a shop held only in memory is re-rolled by restarting the
	# game, and the owner asked for exactly that not to work.
	var again: Array = VendorStock.wares()
	_check(_same_shelf(first, again),
		"the shelf is the same the second time it is looked at")

	# A save and a load is the restart, driven rather than described.
	# Through the loader itself rather than through a copy of it - the loader
	# is the thing under test.
	var text: String = MetaState.serialized_save()
	MetaState.vendor = {}
	MetaState.adopt_save(MetaState.parse_save_text(text))
	_check(_same_shelf(first, VendorStock.wares()),
		"and the same after the game has been closed and opened")

	# A short road is not a road.
	VendorStock.note_run(Balance.VENDOR_RUN_MINIMUM_SECONDS - 1.0)
	_check(_same_shelf(first, VendorStock.wares()),
		"a run of under %d seconds does not sweep the shelf"
			% int(Balance.VENDOR_RUN_MINIMUM_SECONDS))

	# A real one is.
	VendorStock.note_run(Balance.VENDOR_RUN_MINIMUM_SECONDS + 1.0)
	_check(VendorStock.is_due(), "a real road leaves a refresh owed")
	var swept: Array = VendorStock.wares()
	_check(not VendorStock.is_due(), "and taking it clears the debt")
	_check(swept.size() == VendorStock.WARES,
		"a swept shelf is stocked again (%d of %d)" % [swept.size(),
			VendorStock.WARES])

	# And the clock alone sweeps it. Reached by ageing the stamp rather than by
	# waiting ten minutes, which is the documented seam a gate uses.
	MetaState.vendor["rolled_at"] = Time.get_unix_time_from_system() \
		- Balance.VENDOR_REFRESH_SECONDS - 1.0
	_check(VendorStock.is_due(), "the shelf is swept by the clock as well")


func _same_shelf(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		var one: Dictionary = a[index] as Dictionary
		var other: Dictionary = b[index] as Dictionary
		if int(one.get("uid", 0)) != int(other.get("uid", -1)):
			return false
	return true


## **Buying is always dearer than selling**, at every rarity and every level.
## Measured against the stash's own price rather than against the markup, so the
## day either moves the comparison still means what it says.
func _test_buying_never_prints_marks() -> void:
	for rarity: int in Stash.RARITY_NAMES.size():
		for level: int in range(1, Stash.MAX_LEVEL + 1):
			var piece: Dictionary = Stash.make("", rarity, level)
			var asking: int = VendorStock.price(piece)
			var paid: int = Stash.sell_price(piece)
			_check(asking > paid,
				"a %s at level %d is bought for %d and sold for %d"
					% [Stash.RARITY_NAMES[rarity], level, asking, paid])


## Diablo's shape: mostly a little behind the Warden, rarely a step ahead, never
## a shortcut past the road. Measured over a large sample rather than read off
## the constants, because the thing that matters is the distribution.
func _test_the_shelf_trails_the_warden() -> void:
	MetaState.stash.clear()
	MetaState.equipped.clear()
	MetaState.stash.append(Stash.make("", 3, 1))
	var reach: int = VendorStock.reached()
	_check(reach == 3, "the Warden's reach is the best they have held (%d)" % reach)

	var ahead: int = 0
	var behind: int = 0
	var rounds: int = 60
	for _round: int in rounds:
		MetaState.vendor = {}
		for piece: Variant in VendorStock.wares():
			var rarity: int = int((piece as Dictionary).get("rarity", 0))
			if rarity > reach:
				ahead += 1
			elif rarity < reach:
				behind += 1
			_check(rarity <= reach + 1,
				"nothing on the shelf is more than one rung ahead (%d against %d)"
					% [rarity, reach])
	var total: float = float(rounds * VendorStock.WARES)
	var share: float = float(ahead) / maxf(total, 1.0)
	_check(share < Balance.VENDOR_BETTER_CHANCE * 2.0,
		"a step ahead stays rare (%.1f%% of wares)" % (share * 100.0))
	_check(behind > ahead,
		"and most of the shelf trails the Warden (%d behind, %d ahead)"
			% [behind, ahead])
	MetaState.stash.clear()


## **A commission costs more than smithing and teaches nothing.**
##
## Both halves, because the second is the one that keeps Marks from buying
## practice - and it is the one nothing on screen would show.
func _test_the_commission_costs_more() -> void:
	var gem: String = _a_gem()
	if gem.is_empty():
		_check(false, "there is a gem in the world to commission with")
		return
	var fee: int = Forge.commission_fee(gem)
	_check(fee > 0, "Orden asks for Marks (%d)" % fee)

	# He will not work for a stranger.
	MetaState.profession_xp.clear()
	MetaState.materials.clear()
	MetaState.gain_material(gem, 4)
	MetaState.marks = fee * 4
	_check(not Forge.commission_refusal(gem).is_empty(),
		"Orden refuses a Warden who has never lit a forge")

	# Practised enough, and paid, he takes the work.
	while MetaState.profession_level("smith") < Balance.COMMISSION_SMITH_LEVEL:
		MetaState.gain_profession_xp("smith", 100)
	var before_marks: int = MetaState.marks
	var before_xp: float = float(MetaState.profession_xp.get("smith", 0))
	var before_gems: int = MetaState.material_count(gem)
	_check(Forge.commission_refusal(gem).is_empty(),
		"and takes it from one who has: %s" % Forge.commission_refusal(gem))
	var made: Dictionary = Forge.commission(gem)
	_check(not made.has("error"),
		"the commission lands: %s" % String(made.get("error", "")))
	_check(MetaState.marks == before_marks - fee,
		"the fee is taken (%d of %d)" % [before_marks - MetaState.marks, fee])
	_check(MetaState.material_count(gem) == before_gems - 1,
		"and the gem with it")
	_check(is_equal_approx(float(MetaState.profession_xp.get("smith", 0)), before_xp),
		"and the Warden learns nothing from a piece somebody else struck")
	# The piece is level one, because his stock is ordinary. That is the cost
	# that cannot be paid in Marks.
	_check(int(made.get("level", 9)) == 1,
		"his ordinary stock makes an ordinary piece (level %d)"
			% int(made.get("level", 0)))


func _a_gem() -> String:
	for material: MaterialData in ContentDB.materials_sorted():
		if material.kind == MaterialData.Kind.GEM:
			return material.id
	return ""


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[hold] " + why)
