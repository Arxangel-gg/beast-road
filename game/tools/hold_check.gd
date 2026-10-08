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
## Which tests reached their own last line. See the loop in `_run`.
var _reached: Dictionary = {}
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_yard_is_a_place()
	_test_every_station_has_a_door()
	_test_the_residents_stand_on_nothing()
	_test_the_shelves_are_walkable()
	_test_the_smith_gives_up_the_anvil()
	_test_the_residents_work_at_their_posts()
	_test_the_seats_are_the_sessions()
	_test_the_warden_wears_their_own_dye()
	_test_a_stranger_wears_their_gear()
	_test_the_strangers_are_dressed()
	await _test_the_chrome_is_above_the_sky()
	await _test_the_crowd_changes_and_does_things()
	_test_the_shelf_refreshes_by_rule()
	_test_buying_never_prints_marks()
	_test_the_shelf_trails_the_warden()
	_test_the_commission_costs_more()
	_test_the_pond_is_bounded()
	await _test_a_thumb_drives_the_hold()
	await _test_a_click_uses_what_it_lands_on()
	await _test_a_click_reaches_the_yard_through_the_menu()
	await _test_the_stone_card_comes_back()
	await _test_the_four_doors_moved_in()
	await _test_the_doors_say_what_waits()
	await _test_the_hold_talks()
	# **A test that aborted must not read as a test that passed.** A GDScript
	# runtime error - which is what every fault in this batch was - stops the
	# function it happens in and nothing else. So planting the act-start fault
	# made this gate lose three checks and still print PASS, which is the
	# comparison-of-two-nothings shape wearing a gate's clothes. Each test
	# below stamps its own name as its last statement, and every stamp is
	# accounted for here.
	for stage: String in ["pond_fish", "act_start_door", "stranger_gear", "strangers_dressed", "thumb", "news", "chrome",
			"click", "menu_click", "stone_card", "four_doors", "talks"]:
		_check(_reached.has(stage),
			("'%s' never reached its end - it aborted partway, and every check "
				+ "it had not made yet is a check nobody made") % stage)
	MetaState.resume_saves()
	if _failures == 0:
		print(("[hold] PASS - %d checks: every station presses a door, every "
			+ "shelf can be walked on and off, nobody "
			+ "carries their own pavement, the smith "
			+ "stands aside, seats are the session's, the shelf keeps its stock "
			+ "across a restart, buying is always dearer than selling, and a "
			+ "commission costs more and teaches nothing, the pond gives up "
			+ "three and then goes quiet, everybody in "
			+ "it is working at their own post, and a thumb can walk, sprint, "
			+ "tap and open a door in it, and every door says what is waiting "
			+ "behind it and nothing else") % _checks)
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
## for each area"*, laid out like Nahantu rather than as three bands. What makes
## that a place rather than a picture is the step rule - a Warden cannot walk up
## an earth bank - and **the step rule is also the way to strand somebody**: a
## shelf with no flight onto it is a shelf you can see and never reach, and
## every character in the map still reads as perfectly good ground.
##
## This project has already paid for that exact failure once, with ponds dug
## where nobody could fish them. So this walks the yard the way a Warden does
## rather than reading the map: a flood fill from the road out over the real
## `step_is_legal`, and then every station, every resident and every pen has to
## have been reached.
func _test_the_shelves_are_walkable() -> void:
	var yard: HoldYard = _stand_a_yard()

	# The map is rectangular. A ragged one has its right-hand edge wherever the
	# shortest line happened to stop, which is a shape nobody authored.
	_check(HoldYard.MAP.size() == HoldYard.MAP_H,
		"the map is %d rows against MAP_H %d"
		% [HoldYard.MAP.size(), HoldYard.MAP_H])
	var ragged: int = 0
	for row: String in HoldYard.MAP:
		if row.length() != HoldYard.MAP_W:
			ragged += 1
	_check(ragged == 0, "%d rows are not %d cells wide" % [ragged, HoldYard.MAP_W])

	# Every flight joins exactly two levels one apart, with ground at both ends.
	# A flight whose high side is not higher is a staircase to nowhere, and it
	# draws perfectly.
	var flights: int = 0
	for y: int in HoldYard.MAP_H:
		for x: int in HoldYard.MAP_W:
			var cell := Vector2i(x, y)
			var ch: String = _mark(cell)
			if not Elevation.WAY.has(ch):
				continue
			flights += 1
			var way: Vector2i = Elevation.WAY[ch]
			var low: String = _mark(cell + way)
			var high: String = _mark(cell - way)
			_check(Elevation.LEVEL.has(low) and Elevation.LEVEL.has(high)
					and int(Elevation.LEVEL[high]) == int(Elevation.LEVEL[low]) + 1,
				"the flight at %d,%d climbs from %s to %s" % [x, y, low, high])
	_check(flights >= 6,
		"the Hold has %d flight cells - a place with no stairs is one shelf"
		% flights)

	# A bank is a bank. Two points either side of a cliff, nowhere near a flight,
	# must refuse each other - measured rather than assumed, because a step rule
	# that always says yes is a flat Hold that passes every other check here.
	var cliffs: int = 0
	var climbed: int = 0
	for y: int in HoldYard.MAP_H - 1:
		for x: int in HoldYard.MAP_W:
			var above := Vector2i(x, y)
			var below := Vector2i(x, y + 1)
			if not Elevation.LEVEL.has(_mark(above)) \
					or not Elevation.LEVEL.has(_mark(below)):
				continue
			if int(Elevation.LEVEL[_mark(above)]) \
					<= int(Elevation.LEVEL[_mark(below)]):
				continue
			cliffs += 1
			var top: Vector2 = HoldYard.at_cell(above)
			var foot: Vector2 = HoldYard.at_cell(below)
			if yard.step_is_legal(foot, top):
				climbed += 1
	_check(cliffs > 0, "the Hold has no cliffs in it at all")
	_check(climbed == 0,
		"%d of %d cliffs can be walked straight up - the shelves are a picture"
		% [climbed, cliffs])

	# And a flight is a way through, driven the way a Warden takes one.
	var shut: int = 0
	for y: int in HoldYard.MAP_H:
		for x: int in HoldYard.MAP_W:
			var cell := Vector2i(x, y)
			if not Elevation.WAY.has(_mark(cell)):
				continue
			var way: Vector2i = Elevation.WAY[_mark(cell)]
			var foot: Vector2 = HoldYard.at_cell(cell + way)
			var top: Vector2 = HoldYard.at_cell(cell - way)
			var middle: Vector2 = HoldYard.at_cell(cell)
			if not (yard.step_is_legal(foot, middle)
					and yard.step_is_legal(middle, top)):
				shut += 1
	_check(shut == 0, "%d flights cannot be climbed" % shut)

	# The whole yard, walked from the road out.
	var reached: Dictionary = _walk_the_yard(yard)
	for id: String in yard.station_ids():
		var at: Vector2 = yard.station_at(id)
		_check(reached.has(_cell(at)),
			("%s is on ground no Warden can walk to from the road - it stands on a "
				+ "shelf with no flight onto it") % id)
	for person: Dictionary in HoldYard.RESIDENTS:
		var at: Vector2 = HoldYard.at_cell(person["cell"] as Vector2i)
		_check(reached.has(_cell(at)),
			"%s stands where nobody can reach them" % String(person["name"]))
	for index: int in yard.pens():
		var pen: Vector2 = HoldYard.at_cell(HoldYard.PEN_FIRST
			+ Vector2i(index * HoldYard.PEN_STEP, 0))
		_check(reached.has(_cell(pen)),
			"pen %d is on ground no Warden can walk to" % index)
	yard.queue_free()


## What the map says is at a cell.
func _mark(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= HoldYard.MAP.size():
		return " "
	var row: String = HoldYard.MAP[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return " "
	return row[cell.x]


## Which cell of the walking grid a point falls in.
func _cell(at: Vector2) -> Vector2i:
	return Vector2i(int(floor(at.x / WALK_GRID)), int(floor(at.y / WALK_GRID)))


## Every cell a Warden can reach from the road out, walking the yard's own
## step rule. A breadth-first walk rather than a reading of the table, because
## the table is the thing being checked.
func _walk_the_yard(yard: HoldYard) -> Dictionary:
	var half: Vector2 = HoldYard.YARD * 0.5
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [_cell(HoldYard.at_cell(HoldYard.ENTRY))]
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

	# **No cottage stands in front of a door.** The houses were laid on
	# 2026-09-17 and three stations added since (the Gate, the Inn, the Cairn)
	# were put on ground a cottage already stood in front of, so each was a door
	# a Warden could walk to and never see - every rule here passed, because
	# none of them asked what was drawn over what. A cottage behind a building
	# is scenery; one in front of it, over a share of its picture, is the fault.
	for one: String in ids:
		var picture: Rect2 = yard.station_picture(one)
		if picture.size.x <= 0.0:
			continue
		for house: Dictionary in yard.house_pictures():
			var rect: Rect2 = house["rect"] as Rect2
			var cover: Rect2 = rect.intersection(picture)
			var share: float = cover.get_area() / picture.get_area()
			# A tie is drawn in the order the yard adds them, and the houses come
			# after the stations: standing on the same row is standing in front.
			_check(float(house["ground"]) < picture.end.y - 1.0 or share < 0.15,
				"a cottage stands in front of %s and covers %d%% of it - a door nobody can see"
					% [one, int(share * 100.0)])

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


## **Everybody in the Hold is doing their job.**
##
## The owner asked for the residents to be *"set up perfectly and polished for
## their AI behaviors"*, and a walk and a breath are not that: four people
## standing about a fortified shelter while nothing is made is a lobby with
## scenery in it. Each of them has a work loop now - a hammer, a crate, a feed
## pail, a bridle - and it plays while they are at their own post and nobody
## is asking for their tools.
##
## **Three ways this can be a lie, and all three are checked here.** The
## frames can be missing from disk, which `_test_the_residents_stand_on_nothing`
## would not see because it walks the idle and the walk. The state can be
## decided and drawn by nothing, which is the `DisciplineEffects` lie and is
## why the texture is read off the sprite rather than the flag off the record.
## And the loop can be *one frame long* - a cycle that never advances is a
## still picture wearing an animation's name - so the gate counts the distinct
## frames a second of work actually draws.
func _test_the_residents_work_at_their_posts() -> void:
	for person: Dictionary in HoldYard.RESIDENTS:
		var art: String = String(person["art"])
		var who: String = String(person["id"])
		var frames: Array[Texture2D] = GameData.load_state_frames(art, "work")
		_check(frames.size() >= 3,
			"%s has a work loop on disk (%d frames)" % [who, frames.size()])
	var yard: HoldYard = _stand_a_yard()
	# Well away from every station, so nobody is standing aside and nobody is
	# being looked up at: this is the Hold as it stands when the Warden is not
	# in it, which is most of the time it is drawn.
	yard.stand_warden(Vector2(-1400.0, 900.0))
	yard.advance(0.2, 20)
	for person: Dictionary in HoldYard.RESIDENTS:
		var who: String = String(person["id"])
		_check(yard.doing(who) == &"work",
			"%s works at their own post with the Warden away (%s)"
			% [who, yard.doing(who)])
		var wanted: Dictionary = {}
		for texture: Texture2D in GameData.load_state_frames(
				String(person["art"]), "work"):
			wanted[texture.resource_path] = true
		var seen: Dictionary = {}
		var stranger: String = ""
		for step: int in range(30):
			yard.advance(1.0 / 30.0, 1)
			var texture: Texture2D = yard.resident_frame(who)
			if texture == null:
				continue
			seen[texture.resource_path] = true
			if not wanted.has(texture.resource_path):
				stranger = texture.resource_path
		# **Not merely that the sprite changed.** The first cut counted
		# distinct frames, and a build where the work state was decided and
		# drawn by nothing passed it perfectly: the resident fell through to
		# the idle loop, which also turns over four frames a second. What the
		# state has to produce is *its own* art.
		_check(stranger.is_empty(),
			"and %s draws its work frames while working, not %s"
			% [who, stranger.get_file()])
		_check(seen.size() >= 3,
			"and the loop actually turns over - %s drew %d frames in a second"
			% [who, seen.size()])
	# And the work stops when somebody wants the tools, which is the other half
	# of the behaviour the anvil test holds: a smith who kept hammering while
	# the Warden stood at his anvil would be standing aside in the record and
	# swinging on screen.
	yard.stand_warden(yard.station_at("anvil"))
	yard.advance(0.2, 20)
	_check(yard.doing("smith") != &"work",
		"and Orden stops hammering when the Warden comes to the anvil")
	yard.queue_free()


## **The Hold's pond gives up three and then goes quiet.**
##
## Owner, 2026-09-17: *"players can also only fish for up to 3 fish every 10
## minutes at their Hold's pond."*
##
## The cap is the only thing standing between a hub pond and an unbounded supply
## of the game's one persistent consumable - `FISH_MEALS_PER_RUN` is what keeps
## a full larder from making a Warden unkillable, and a pond in the one place
## nothing is hunting you is exactly how that would be farmed around.
##
## Driven through the real door with the clock handed in, rather than by reading
## the constants back: a window that never actually closes and one that never
## opens both read as perfectly correct numbers.
func _test_the_pond_is_bounded() -> void:
	var was: Dictionary = MetaState.hold_pond.duplicate(true)
	MetaState.hold_pond = {}
	var now: float = 1000.0
	_check(MetaState.hold_pond_left(now) == Balance.HOLD_POND_CATCHES,
		"a pond nobody has fished offers %d" % MetaState.hold_pond_left(now))
	var taken: int = 0
	for _try: int in Balance.HOLD_POND_CATCHES + 3:
		if MetaState.hold_pond_take(now):
			taken += 1
	_check(taken == Balance.HOLD_POND_CATCHES,
		"the pond gave up %d fish in one window against a cap of %d"
		% [taken, Balance.HOLD_POND_CATCHES])
	_check(MetaState.hold_pond_left(now) == 0,
		"an emptied pond still says it has fish in it")
	_check(MetaState.hold_pond_wait(now) > 0.0,
		"an emptied pond reports no wait at all")
	# A moment before the window is up it is still quiet, and a moment after it
	# is full again. Both ends, because a window that closes early is a cap that
	# does not cap and one that never opens is a pond nobody fishes twice.
	_check(MetaState.hold_pond_left(now + Balance.HOLD_POND_WINDOW - 1.0) == 0,
		"the window opened early")
	_check(MetaState.hold_pond_left(now + Balance.HOLD_POND_WINDOW + 1.0)
			== Balance.HOLD_POND_CATCHES,
		"the window never opened again")
	# And the pond is somewhere a Warden can actually stand.
	var yard: HoldYard = _stand_a_yard()
	var shore: Vector2 = yard.station_at("pond")
	_check(shore != Vector2.INF, "the Hold has no pond to fish")
	if shore != Vector2.INF:
		_check(_walk_the_yard(yard).has(_cell(shore)),
			"the pond stands on ground no Warden can walk to")
	yard.queue_free()
	MetaState.hold_pond = was
	_test_the_pond_gives_up_a_fish()


## **And something rises.** The test above drives the pond's *budget* - how many
## casts a window allows and when it opens again - and every one of those checks
## was green while `_pond_catch` threw on its first loop iteration and returned
## null, so the Hold's pond had never produced a fish on any account since it was
## written. `_fish_the_pond` catches that as "Nothing is rising." and says so
## politely, which is the worst shape a fault can take.
##
## Driven through the screen's own catch rather than by re-deriving the roll,
## because the fault was a member access inside it - a test that rolled its own
## fish would have passed with the bug in place, which is the `GearRow.set_text`
## mistake this project has already made once.
func _test_the_pond_gives_up_a_fish() -> void:
	# Built rather than loaded: the Hold is a `CanvasLayer` the menu constructs
	# in code (`main_menu.gd:281`), and there is no scene to instantiate.
	var hub := HubScreen.new()
	add_child(hub)
	var pool: Array = ContentDB.fish_sorted()
	_check(not pool.is_empty(), "there are no fish for the Hold's pond to hold")
	if pool.is_empty():
		hub.queue_free()
		return
	# Twenty casts, because the roll is weighted and one null is a fault whether
	# it happens on the first cast or the twentieth.
	var caught: int = 0
	var names: Dictionary = {}
	for _cast: int in 20:
		var fish: FishData = hub.call("_pond_catch") as FishData
		if fish != null:
			caught += 1
			names[fish.id] = true
			_check(int(fish.rarity) <= Balance.HOLD_POND_RARITY_CEILING,
				("the Hold's pond gave up %s at rarity %d, over its ceiling of "
					+ "%d - the rare fish are the road's")
					% [fish.id, int(fish.rarity), Balance.HOLD_POND_RARITY_CEILING])
	_check(caught == 20,
		"the Hold's pond gave up a fish on %d of 20 casts" % caught)
	_check(names.size() > 1,
		("the Hold's pond returned the same fish on every one of 20 casts (%s) "
			+ "- the weighting reaches nothing") % ", ".join(names.keys()))
	hub.queue_free()
	_reached["pond_fish"] = true
	_test_the_act_start_door_opens_the_room()


## **The door the CI profile could never press.**
##
## "Start at an act" is only built for an account that has passed Act I
## (`hub_screen.gd`, inside `if furthest > 1:`), and a scratch profile is a new
## account - so no gate had ever rendered that button, let alone pressed it.
## `_road_act_start` assigned `act_start.take_the_road`, which `ActStartScreen`
## did not declare; the assignment threw and aborted the function **after**
## `_hide_road()` and `suspend()` had run, so the Hold hid its own frame, card
## and yard and opened nothing at all.
##
## That is the recorded lesson in a third costume: when a gate passes in CI, it
## has only been asked about the state CI has. The account is given a road
## behind it here, which is the whole point.
func _test_the_act_start_door_opens_the_room() -> void:
	var kept: float = MetaState.best_distance
	MetaState.best_distance = Balance.act_start_distance(4) + 10.0
	_check(ActStart.furthest_act() > 1,
		"the harness failed to give the account a road behind it")
	var hub := HubScreen.new()
	add_child(hub)
	var screen := ActStartScreen.new()
	add_child(screen)
	screen.visible = false
	hub.act_start = screen
	hub.visible = true

	hub.call("_road_act_start")
	_check(screen.visible,
		("the Hold's act-start door left the screen closed - and the room "
			+ "suspended behind it, which is a Warden looking at nothing"))
	_check(screen.take_the_road.is_valid(),
		("the Hold did not hand the act-start screen anywhere to hand the road "
			+ "back to, so the party would never be asked"))
	# And the screen hands it back rather than starting a run behind the
	# party's back. Driven through the screen's own Begin path.
	var handed: Array = []
	screen.take_the_road = func(act: int, doctrine: String) -> void:
		handed.append([act, doctrine])
	screen.call("_begin")
	_check(handed.size() == 1,
		("the act-start screen began a road without handing it back (%d hands)")
			% handed.size())
	screen.queue_free()
	hub.queue_free()
	MetaState.best_distance = kept
	_reached["act_start_door"] = true


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


## **The dye the Warden chose is on the Warden in the room** (owner,
## 2026-09-22: *"player's custom colours set in the Hold do not appear on the
## player in the Hold"*).
##
## The card dressed its own portrait and nothing else, so a slider changed the
## picture on the card while the figure walking about stayed the painted
## Warden. Read off the sprite's own material rather than off the save, because
## the fault was entirely between the two: the number was written correctly and
## reached no sprite.
func _test_the_warden_wears_their_own_dye() -> void:
	var was: Dictionary = MetaState.look.duplicate(true)
	var yard: HoldYard = _stand_a_yard()

	# **Driven through the session, not through the yard.** The fault was a
	# missing *call*, and a gate that calls `set_look` itself proves the
	# painter works while the screen still never asks it to - which is the
	# shape this project has shipped twice.
	var session := HoldSession.new()
	session.yard = yard
	add_child(session)

	MetaState.set_look(WardenLook.KEY_CLOAK, 0.33)
	MetaState.set_look(WardenLook.KEY_SASH, -0.21)
	session.my_look_changed()
	var worn: Dictionary = _dye_on(yard, 0)
	_check(is_equal_approx(float(worn.get("cloak", 0.0)), 0.33)
			and is_equal_approx(float(worn.get("sash", 0.0)), -0.21),
		"the Warden in the room wears the dye the card set, wears %s" % str(worn))

	# A stranger wears what the host said, and never this machine's own.
	yard.set_look(1, PackedFloat32Array([-0.4, 0.15]))
	var theirs: Dictionary = _dye_on(yard, 1)
	_check(is_equal_approx(float(theirs.get("cloak", 0.0)), -0.4),
		"a stranger wears the dye the host sent, wears %s" % str(theirs))
	_check(not is_equal_approx(float(theirs.get("cloak", 0.0)),
			float(worn.get("cloak", 0.0))),
		"and never this machine's own")

	session.queue_free()
	yard.queue_free()
	MetaState.look = was


## **A different crowd every visit, doing things** (owner, 2026-09-22).
##
## Two yards stood one after the other must not be the same three strangers,
## and a simulated Warden that has walked to a station must eventually swing.
## The errand is driven rather than the constant read: a `doing` written into
## the seat and looked at by nobody is the shape this project keeps shipping.
## **Another player in the Hold wears their gear** (2026-09-26). A guest's
## hello carried a name, a title, a pen and a dye, so everybody stood in the
## bare body. Driven through the host's door: the party seats a peer, the
## session hears its hello, the table goes on the wire, and the yard dresses
## the figure the session drew.
func _test_a_stranger_wears_their_gear() -> void:
	var yard: HoldYard = _stand_a_yard()
	var session := HoldSession.new()
	session.yard = yard
	add_child(session)
	var party: CoopParty = Coop.party()
	party.open("Host")
	var peer: int = 91
	var slot: int = party.seat(peer, "Somebody")
	var kinds: Array = four_kinds()
	var look: Dictionary = WardenLook.plain()
	# Collected into the array rather than assigned: a lambda captures a local
	# by value, so assigning to it inside would change nothing out here.
	var sent: Array = []
	var listen := func(rows: Array) -> void:
		sent.clear()
		sent.append_array(rows)
	EventBus.hold_seats.connect(listen)
	session._on_request(CoopRelay.Request.HOLD_HELLO,
		["Somebody", "Warden", [], false, WardenLook.pack(look), kinds], peer)
	EventBus.hold_seats.disconnect(listen)
	var row: Array = sent[slot] if slot < sent.size() else []
	_check(row.size() > 5 and row[5] == Hero.clean_worn_kinds(kinds),
		"the Hold's table must carry a guest's gear in its sixth column: %s" % str(row))
	var figure: int = int(session._figure.get(slot, -1))
	var animator: HeroAnimator = null
	if figure > 0:
		animator = yard.seat_state(figure).get("animator") as HeroAnimator
	_check(wears(animator, outfit_of(look, kinds)),
		"the guest's figure in the yard must wear the gear their hello carried")
	# The guest's side of the same wire, read off the source because a guest
	# path cannot run offline: the told table is read, and the hello sends it.
	var source: String = FileAccess.get_file_as_string("res://scripts/systems/hold_session.gd")
	_check(source.contains("_table[index][\"gear\"] = Hero.clean_worn_kinds(fields[5])"),
		"a guest must read the gear column off the host's table")
	_check(source.contains("WardenLook.pack(WardenLook.worn()), Hero.worn_kinds()])"),
		"the hello must carry this machine's gear")
	party.clear()
	session.queue_free()
	yard.queue_free()
	_reached["stranger_gear"] = true


## **The Wardens nobody is sitting in are people, dressed** (owner, 2026-10-01:
## *"AI players at the Hold should be random appearance including color and
## looks selections as well as worn gear that affects appearance such as armor
## and capes and weapons"*).
##
## Two halves. The roll: over a few hundred keys a stranger is mostly armed and
## armoured, often caped, sometimes helmed, never in a trophy, in every cloth
## colour and every body - measured over fixed keys rather than three seats,
## because three seats is a coin toss. And the door: the session's table drew a
## dye-only row over every simulated seat, which re-dressed each of them as the
## bare body the moment it was drawn, so the figures are read after the session
## has composed and drawn its own table.
func _test_the_strangers_are_dressed() -> void:
	var keys: int = 300
	var worn: Array[int] = []
	worn.resize(Hero.DRESS_SLOTS.size())
	worn.fill(0)
	var colours: Dictionary = {}
	var bodies: Dictionary = {}
	var trophies: int = 0
	var stable: bool = true
	for index: int in keys:
		var who: String = "gate:stranger:%d" % index
		var stranger: Dictionary = HoldYard.stranger_of(who)
		stable = stable and str(stranger) == str(HoldYard.stranger_of(who))
		var gear: Array = stranger["gear"] as Array
		var look: Dictionary = stranger["look"] as Dictionary
		bodies[int(look[WardenLook.KEY_BODY])] = true
		colours[int(look[WardenLook.KEY_TOP_COLOUR])] = true
		for place: int in gear.size():
			var kind: GearData = ContentDB.gear(String(gear[place]))
			if kind == null:
				continue
			worn[place] += 1
			if kind.trophy:
				trophies += 1
			_check(kind.slot == Hero.DRESS_SLOTS[place],
				"a stranger wears %s in the %d place, which is not its slot" % [kind.id, place])
	_check(stable, "a stranger's roll differs between two asks of the same key")
	_check(float(worn[0]) / keys > 0.8, "strangers are armed %d times in %d" % [worn[0], keys])
	_check(float(worn[1]) / keys > 0.6, "strangers are armoured %d times in %d" % [worn[1], keys])
	_check(worn[2] > keys / 4 and worn[2] < keys, "strangers wear capes %d times in %d" % [worn[2], keys])
	_check(worn[3] > keys / 8, "strangers wear helmets %d times in %d" % [worn[3], keys])
	# The fifth is the shield (2026-10-07), carried by about a third.
	_check(worn[4] > keys / 8 and worn[4] < keys / 2, "strangers carry shields %d times in %d" % [worn[4], keys])
	_check(trophies == 0, "a stranger wore a trophy %d times" % trophies)
	_check(colours.size() >= 10, "strangers' tops came in %d colours" % colours.size())
	var bodies_drawn: int = 0
	for body: String in WardenDress.BODIES:
		if WardenDress.available(body):
			bodies_drawn += 1
	_check(bodies.size() == bodies_drawn, "strangers came in %d of %d bodies" % [bodies.size(), bodies_drawn])

	var yard: HoldYard = _stand_a_yard()
	var session := HoldSession.new()
	session.yard = yard
	add_child(session)
	# **The door the Hold opens alone** (2026-10-08). This used to call the
	# host's `_compose`, which filled every stranger - and passed while the
	# solo path filled names and nothing else and dressed every walker bare.
	session._read_session()
	var dressed: int = 0
	var outfits: Dictionary = {}
	for index: int in range(1, yard.seats()):
		if yard.seat_kind(index) != HoldSession.Seat.SIMULATED:
			continue
		var animator: HeroAnimator = yard.seat_state(index).get("animator") as HeroAnimator
		var stranger: Dictionary = HoldYard.stranger_of(yard.sim_key(index))
		var expected: Dictionary = WardenDress.outfit(stranger["look"] as Dictionary,
			ContentDB.gear(String((stranger["gear"] as Array)[0])),
			ContentDB.gear(String((stranger["gear"] as Array)[1])),
			ContentDB.gear(String((stranger["gear"] as Array)[2])),
			ContentDB.gear(String((stranger["gear"] as Array)[3])))
		_check(wears(animator, expected) and animator != null
				and str(animator._outfit.get("hair", "")) == str(expected.get("hair", "")),
			"the session's table re-dressed stranger %d as something it was not rolled as" % index)
		if animator != null:
			dressed += 1
			outfits[str(animator._outfit.get("body_layer", "")) + str(animator._outfit.get("hair", ""))
				+ str(animator._outfit.get("held", ""))] = true
	_check(dressed >= 2, "the session drew %d strangers" % dressed)
	_check(outfits.size() >= mini(dressed, 2),
		"%d strangers wore %d outfits between them" % [dressed, outfits.size()])
	session.queue_free()
	yard.queue_free()
	_reached["strangers_dressed"] = true


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


func _test_the_crowd_changes_and_does_things() -> void:
	var first: HoldYard = _stand_a_yard()
	var second: HoldYard = _stand_a_yard()
	# **The windows are lit** (owner, 2026-09-22: the Hold lacked lighting).
	# Counted off the yard's own glow rather than off `HoldGlow.LIT`, because
	# a table naming ten stations proves nothing about whether any of them was
	# handed a lamp.
	var glow := first.get("_glow") as HoldGlow
	_check(glow != null and glow.lit() >= 8,
		"the Hold's buildings must light their windows, lit %d"
			% (glow.lit() if glow != null else -1))
	var differs: bool = false
	for index: int in range(1, mini(first.seats(), second.seats())):
		if first.sim_key(index) != second.sim_key(index):
			differs = true
	_check(differs, "two visits must not draw the same crowd")
	_check(not first.sim_key(1).is_empty(), "a simulated seat must have a key")

	# A station errand, forced, and then driven until the swing.
	var seat: Dictionary = first.call("seat_state", 1) as Dictionary
	_check(not seat.is_empty(), "a simulated seat must be readable")
	if not seat.is_empty():
		seat["kind"] = HoldSession.Seat.SIMULATED
		seat["doing"] = HoldYard.Errand.WORK
		seat["busy"] = 0.0
		seat["to"] = seat["at"]
		var animator := seat["animator"] as HeroAnimator
		var swung: bool = false
		for _step: int in 90:
			first.call("_drift", seat, 0.05)
			if animator != null and String(animator.get("_state")).begins_with("attack"):
				swung = true
				break
		_check(swung, "a Warden standing at a station must work at it")

	second.queue_free()
	first.queue_free()
	await get_tree().process_frame


## What a seat's figure is actually painted with.
func _dye_on(yard: HoldYard, index: int) -> Dictionary:
	var sprite: Sprite2D = yard.call("seat_sprite", index) as Sprite2D
	if sprite == null:
		return {}
	var material := sprite.material as ShaderMaterial
	if material == null:
		return {}
	return {
		"cloak": float(material.get_shader_parameter("look_cloak")),
		"sash": float(material.get_shader_parameter("look_sash")),
	}


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


# --- A thumb in the Hold ------------------------------------------------------


## **A phone can walk the Hold** (owner, 2026-09-27: *"Need mobile controls at
## the Hold."*). The Hold had tap-to-walk and nothing else: no stick, no dash,
## no sprint, no horse, and every door wanted a second tap on the very spot.
##
## Driven through the viewport's own input, with touch forced on as a phone has
## it, against a real `HubScreen` - so what is held is the whole road a thumb
## takes: the controls come up *above* the yard (on the road's layer they would
## be drawn under it, which is the easiest way for this to look finished and be
## invisible), the stick walks and a push to its rim sprints, a tap in the
## stick's own corner is still a tap on the yard, the button for what is in
## reach opens its door, and the lot goes away under the Warden's card.
func _test_a_thumb_drives_the_hold() -> void:
	var kept_touch: Variant = MetaState.settings.get(TouchInput.TOUCH_KEY, null)
	MetaState.settings[TouchInput.TOUCH_KEY] = true
	TouchInput.refresh()
	var hub := HubScreen.new()
	add_child(hub)
	hub.visible = true
	var yard: HoldYard = hub._yard
	yard.set_driving(true)
	await _frames(3)

	_check(TouchInput.in_place(), "touch is on and the Hold is open, and the controls are not driving it")
	_check(TouchInput.visible, "the Hold's touch controls are not shown")
	_check(TouchInput.layer > hub.layer,
		"the touch controls are on layer %d under the Hold's %d, so they are drawn under the yard"
			% [TouchInput.layer, hub.layer])
	var screen: Rect2 = get_viewport().get_visible_rect()
	var dash: Control = TouchInput._dash
	_check(dash.visible, "there is no dash button in the Hold")
	_check(screen.encloses(Rect2(dash.position, dash.size)), "the dash button is off the screen")
	var prompt: Rect2 = hub._prompt.get_global_rect()
	for which: int in 3:
		var spot: Rect2 = TouchInput.place_rect(which)
		_check(screen.encloses(spot), "a Hold button (%d) is off the screen at %s" % [which, spot])
		var prompt_line := Rect2(prompt.position.x + prompt.size.x * 0.25, prompt.position.y,
			prompt.size.x * 0.5, prompt.size.y)
		_check(not spot.intersects(prompt_line),
			"a Hold button (%d) at %s covers the prompt line at %s" % [which, spot, prompt_line])
	_check(not TouchInput._enter.visible, "an ENTER button with nothing in reach")
	_check(TouchInput._ride.visible == yard.can_ride(), "the ride button disagrees with whether there is a horse")

	# Walk: half a push east, for a while.
	var zone: Rect2 = TouchInput.zone(false)
	var thumb: Vector2 = zone.position + Vector2(zone.size.x * 0.4, zone.size.y * 0.45)
	yard._seats[0]["at"] = yard._on_ground(yard.at_cell(HoldYard.ENTRY))
	var from: Vector2 = yard.warden_at()
	_touch(0, thumb, true)
	_drag(0, thumb + Vector2(Balance.TOUCH_STICK_REACH * 0.55, 0.0))
	await _seconds(0.6)
	var walked: float = yard.warden_at().x - from.x
	_check(walked > 30.0, "half a push east on the stick walked the Warden %.1f units" % walked)
	_check(not Input.is_action_pressed(&"sprint"), "half a push sprints")
	_drag(0, thumb + Vector2(Balance.TOUCH_STICK_REACH * 1.2, 0.0))
	await _frames(2)
	_check(Input.is_action_pressed(&"sprint"), "the stick pushed to its rim does not sprint")
	_touch(0, thumb + Vector2(Balance.TOUCH_STICK_REACH * 1.2, 0.0), false)
	await _frames(2)
	for action: StringName in [&"move_right", &"sprint"]:
		_check(not Input.is_action_pressed(action), "%s is still held after the thumb lifted" % action)

	# A tap in the stick's own corner is a tap on the yard.
	yard._walk_to = Vector2.INF
	_touch(1, thumb, true)
	_touch(1, thumb, false)
	await _frames(1)
	_check(yard._walk_to != Vector2.INF, "a tap in the move stick's corner did not walk the Warden there")
	yard._walk_to = Vector2.INF

	# The door in reach: bound, stood beside, and opened with the button.
	var opened: Array = []
	var target: Dictionary = {}
	for station: Dictionary in yard._stations:
		if not String(station["door"]).is_empty():
			target = station
			break
	_check(not target.is_empty(), "the Hold has no station with a door")
	if not target.is_empty():
		var door := Button.new()
		door.name = String(target["door"])
		add_child(door)
		door.pressed.connect(func() -> void: opened.append(true))
		yard.bind(String(target["door"]), door)
		yard._seats[0]["at"] = (target["at"] as Vector2) + Vector2(0.0, 40.0)
		await _frames(3)
		var enter: Control = TouchInput._enter
		_check(enter.visible, "standing at %s there is no button for it" % String(target["id"]))
		_check(TouchInput._enter.label == "ENTER", "a building's button says %s" % TouchInput._enter.label)
		var middle: Vector2 = enter.position + enter.size * 0.5
		_touch(2, middle, true)
		await _frames(2)
		_touch(2, middle, false)
		_check(opened.size() == 1, "the ENTER button opened the door %d times" % opened.size())
		door.queue_free()

	# Under the card there is nothing to drive.
	yard.set_driving(true)
	hub._show_card()
	await _frames(2)
	_check(not TouchInput.visible, "the touch controls stay up over the Warden's card")
	hub._hide_card()
	hub.queue_free()
	await _frames(2)
	_check(not TouchInput.in_place(), "the controls still drive a Hold that has gone")
	if kept_touch == null:
		MetaState.settings.erase(TouchInput.TOUCH_KEY)
	else:
		MetaState.settings[TouchInput.TOUCH_KEY] = kept_touch
	TouchInput.refresh()
	_reached["thumb"] = true


## **A click on a building or a person uses it** (owner, 2026-09-30), from in
## reach at once and from out of reach by walking there first; a click on
## nothing walks; any other order drops a walk that was going to open
## something; the hover lights and lets go; and a Warden standing still turns
## to where they are pointed.
func _test_a_click_uses_what_it_lands_on() -> void:
	var hub := HubScreen.new()
	add_child(hub)
	hub.visible = true
	var yard: HoldYard = hub._yard
	yard.set_driving(true)
	await _frames(3)
	# A station with a door, and a point inside its painting that lands on it and
	# not on a keeper standing in front of it.
	var target: Dictionary = {}
	var spot: Vector2 = Vector2.INF
	var opened: Array = []
	var door := Button.new()
	add_child(door)
	door.pressed.connect(func() -> void: opened.append(true))
	for station: Dictionary in yard._stations:
		if String(station["door"]).is_empty() or station["node"] == null:
			continue
		# Bound first: a door never adopted is a building with nothing in it,
		# and neither the focus nor a click will use one.
		yard.bind(String(station["door"]), door)
		var box: Rect2 = yard._hit_box(station["node"] as Sprite2D)
		for ix: int in 7:
			for iy: int in 7:
				var probe: Vector2 = box.position + box.size * Vector2(
					(float(ix) + 0.5) / 7.0, (float(iy) + 0.5) / 7.0)
				if yard.interactable_at(probe) == String(station["id"]):
					spot = probe
					break
			if spot != Vector2.INF:
				break
		if spot != Vector2.INF:
			target = station
			break
	_check(not target.is_empty(), "no building in the Hold can be clicked")
	if not target.is_empty():
		var id: String = String(target["id"])
		var reach: Vector2 = (target["at"] as Vector2) + Vector2(0.0, 40.0)

		# From across the yard: walk there, then open it.
		yard._seats[0]["at"] = yard._on_ground(yard.at_cell(HoldYard.ENTRY))
		if yard.in_reach(id):
			yard._seats[0]["at"] = reach + Vector2(900.0, 0.0)
		_check(yard.click_at(spot), "a click on %s did not land on it" % id)
		_check(opened.is_empty() and yard._pending_use == id and yard._walk_to != Vector2.INF,
			"a click on %s from out of reach should walk there first, not open it" % id)
		yard._seats[0]["at"] = reach
		await _frames(2)
		_check(opened.size() == 1 and yard._pending_use.is_empty(),
			"arriving at %s did not open it (%d)" % [id, opened.size()])

		# In reach: at once, and through the screen's own tap as well.
		_check(yard.click_at(spot) and opened.size() == 2,
			"a click on %s in reach did not open it" % id)
		var on_screen: Vector2 = yard.position + spot * yard.scale.x
		hub._tap_at(on_screen)
		_check(opened.size() == 3, "the screen's own click did not reach %s" % id)

		# Any other order drops a walk that was going to open something.
		yard._seats[0]["at"] = reach + Vector2(900.0, 0.0)
		yard.click_at(spot)
		Input.action_press(&"move_left")
		await _frames(2)
		Input.action_release(&"move_left")
		_check(yard._pending_use.is_empty(), "walking away did not cancel the click")

		# The hover lights and lets go, and the cursor points while it is over.
		yard._set_hover(id)
		_check(yard._cursor_pointing and yard._hover_node == target["node"],
			"hovering %s did not light it" % id)
		yard._set_hover("")
		_check(not yard._cursor_pointing
			and (target["node"] as Sprite2D).self_modulate == Color.WHITE,
			"a hover that moved off %s left it lit" % id)
	door.queue_free()

	var corner: Vector2 = Vector2(-HoldYard.YARD.x * 0.5 + 60.0, HoldYard.YARD.y * 0.5 - 60.0)
	_check(not yard.click_at(corner), "a click on bare ground claimed to land on something")

	# Standing still, the Warden turns to where they are pointed.
	var at: Vector2 = yard.warden_at()
	yard.turn_warden_toward(at + Vector2(300.0, -Balance.HOLD_CURSOR_CHEST))
	_check((yard._seats[0]["facing"] as Vector2).x > 0.9, "the Warden did not turn to a point east of them")
	yard.turn_warden_toward(at + Vector2(-300.0, -Balance.HOLD_CURSOR_CHEST))
	_check((yard._seats[0]["facing"] as Vector2).x < -0.9, "the Warden did not turn to a point west of them")
	var src: String = FileAccess.get_file_as_string("res://scripts/systems/hold_yard.gd")
	_check(src.contains("\t\t_face_the_cursor(seat)"),
		"a standing Warden is never turned to the cursor")
	hub.queue_free()
	await _frames(2)
	_reached["click"] = true


## **A real click, through the real menu, lands on the door it is over** (owner,
## 2026-09-30: *"Left clicking on interactables still doesn't work such as in
## the hold"*).
##
## The test above calls `click_at` and the screen's `_tap_at` by hand, and both
## were right all along. What was wrong is what a click meets on the way: the
## Hold is a layer over a main menu that is still standing, the yard is a
## `Node2D`, and so a click on the smithy was taken by the menu's title art and
## a click over the stable pressed the hidden menu's own Hold button. Only a
## click pushed through the viewport, over the composition the game actually
## builds, can see that - so this stands the real menu up, opens its Hold, and
## clicks every door it can see while every menu button underneath is watched.
func _test_a_click_reaches_the_yard_through_the_menu() -> void:
	get_window().size = Vector2i(1920, 1080)
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	WardenGlass.mark_offered()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	add_child(menu)
	await _frames(20)
	var hub: HubScreen = menu.get("_hub") as HubScreen
	_check(hub != null, "the real menu has no Hold")
	if hub == null:
		menu.queue_free()
		_reached["menu_click"] = true
		return
	hub.open()
	await _frames(10)
	var yard: HoldYard = hub._yard
	# Every button the menu itself owns - not the ones adopted into the Hold,
	# which the Hold reparents and presses on purpose.
	var under: Array = []
	for node: Node in menu.find_children("*", "BaseButton", true, false):
		if hub.is_ancestor_of(node):
			continue
		var button := node as BaseButton
		button.pressed.connect(func() -> void: under.append(button.name))
	var room: Rect2 = get_viewport().get_visible_rect().grow_individual(-60.0, -200.0, -60.0, -140.0)
	var start: Vector2 = yard.warden_at()
	var clicked: int = 0
	for station: Dictionary in yard._stations:
		var id: String = String(station["id"])
		var node := station["node"] as Sprite2D
		if node == null or yard.interactable_at(yard._hit_box(node).get_center()) != id:
			continue
		# Far enough that two frames of walking cannot arrive and open it: an
		# arrival opens the real door, and the road's panel would then stand over
		# every later click.
		if start.distance_to(yard._reach_point(id)) < Balance.HOLD_REACH * 3.0:
			continue
		var spot: Vector2 = yard._hit_box(node).get_center()
		var screen: Vector2 = yard.get_global_transform_with_canvas() * spot
		if not room.has_point(screen):
			continue
		yard._pending_use = ""
		yard._walk_to = Vector2.INF
		_click(screen)
		await _frames(2)
		clicked += 1
		_check(yard._pending_use == id,
			("a real click on %s at %s did not reach it - the yard never heard it "
				+ "(the control under the mouse was %s)") % [id, screen,
				_hovered_at(screen)])
		# Back where it started, so the yard does not pan the next door away.
		yard._pending_use = ""
		yard._walk_to = Vector2.INF
		yard._seats[0]["at"] = start
		await _frames(2)
	_check(clicked >= 4, "only %d doors were on screen to click - the test measured nothing" % clicked)
	# Bare ground walks there, through the same backdrop.
	var ground: Vector2 = get_viewport().get_visible_rect().size * Vector2(0.5, 0.62)
	if yard.interactable_at(yard.get_global_transform_with_canvas().affine_inverse() * ground).is_empty():
		yard._walk_to = Vector2.INF
		_click(ground)
		await _frames(2)
		_check(yard._walk_to != Vector2.INF, "a real click on bare ground did not walk the Warden")
	_check(under.is_empty(),
		"clicking the yard pressed the menu's own buttons underneath it: %s" % [under])
	hub.close()
	menu.queue_free()
	await _frames(3)
	_reached["menu_click"] = true


## **Closing a door opened from the stone comes back to the stone** (owner,
## 2026-10-01: *"Closing a sub UI of the Warden stone should return back to the
## Warden stone instead of requiring reopening the Warden stone again"*).
##
## Through the real menu, because the return is the menu's: a door's screen
## closing is heard by `MainMenu._on_door_closed`, which opens the room again.
## A door pressed from the card comes back to the card; one walked up to in the
## yard comes back to the yard. And Escape in the Glass closes the Glass and
## nothing under it - it had no answer of its own, so the Hold's put the card
## away and left the Glass standing over the yard.
func _test_the_stone_card_comes_back() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	WardenGlass.mark_offered()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	add_child(menu)
	await _frames(20)
	var hub: HubScreen = menu.get("_hub") as HubScreen
	var chronicle: CanvasLayer = menu.get("_chronicle") as CanvasLayer
	_check(hub != null and chronicle != null, "the real menu has no Hold or no Chronicle")
	if hub == null or chronicle == null:
		menu.queue_free()
		_reached["stone_card"] = true
		return
	hub.open()
	await _frames(4)
	var card: Control = hub.get("_card_root") as Control
	var door: Button = hub.find_child("Chronicle", true, false) as Button

	# From the card: the door's screen opens over the Hold, and closing it comes
	# back to the card.
	hub.call("_show_card")
	await _frames(2)
	_check(card.visible, "the Warden's stone card did not open")
	door.pressed.emit()
	await _frames(3)
	_check(chronicle.visible, "the Chronicle did not open from the card")
	_check(not card.visible, "the card stood over the Chronicle it opened")
	chronicle.call("hide_screen")
	await _frames(3)
	_check(hub.visible and not hub.is_suspended(), "the room did not come back after the Chronicle")
	_check(card.visible, "closing a door opened from the stone landed in the yard, not on the stone")

	# From the yard: the same door returns to the yard.
	hub.call("_hide_card")
	await _frames(2)
	door.pressed.emit()
	await _frames(3)
	chronicle.call("hide_screen")
	await _frames(3)
	_check(not card.visible, "a door walked up to in the yard came back to the stone card")

	# The Glass, opened from the card, closes on Escape and leaves the card.
	hub.call("_show_card")
	await _frames(2)
	var glass_door: Button = hub.find_child("OpenGlass", true, false) as Button
	_check(glass_door != null, "the card has no door to the Glass")
	if glass_door != null:
		glass_door.pressed.emit()
		await _frames(3)
		var glass: CanvasLayer = hub.get("_glass") as CanvasLayer
		_check(glass != null and glass.visible, "the Glass did not open from the card")
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = true
		get_viewport().push_input(escape)
		await _frames(3)
		_check(glass != null and not glass.visible, "Escape did not close the Glass")
		_check(card.visible, "Escape in the Glass also put the stone card away")

	# **The road from the stone** (owner, 2026-10-06): a new expedition and,
	# with a front banked, the road back to it - through the door the gate's
	# road panel uses, so a party is asked. A fresh road with a front banked
	# asks before it throws the front away; the Walk's door stays beside them.
	var went: Array = []
	hub.set("road_test_hook", func(kind: int, act: int, _doctrine: String) -> void:
		went.append([kind, act]))
	var front_was: Dictionary = MetaState.expedition.duplicate(true)
	MetaState.expedition = {}
	hub.call("_show_card")
	await _frames(2)
	_check(hub.find_child("WalkAgain", true, false) != null, "the Walk's door left the card")
	_check(hub.find_child("RoadContinue", true, false) == null,
		"the stone offers a road back with no front banked")
	var fresh: Button = hub.find_child("RoadNew", true, false) as Button
	_check(fresh != null, "the stone card has no door to a new road")
	if fresh != null:
		fresh.pressed.emit()
		await _frames(2)
	_check(went == [[HoldSession.Road.FRESH, 1]],
		"a fresh road with nothing banked did not simply go: %s" % str(went))
	went.clear()
	MetaState.expedition = {
		"version": Expedition.VERSION, "seed": 4242, "act": 2, "wave": 9, "wall": 1.0,
		"purse": {RunState.GOLD: 500}, "momentum": 0.0, "tier": "normal",
		"map_mode": MapModes.KEEP, "map_varied": false, "towers": [],
	}
	_check(MetaState.has_expedition(), "the harness's banked front does not read")
	hub.call("_show_card")
	await _frames(2)
	var back: Button = hub.find_child("RoadContinue", true, false) as Button
	fresh = hub.find_child("RoadNew", true, false) as Button
	_check(back != null, "with a front banked the stone offers no road back to it")
	if fresh != null:
		fresh.pressed.emit()
		await _frames(2)
		_check(went.is_empty() and fresh.text.contains("press again"),
			"a fresh road with a front banked went without asking: %s / %s" % [str(went), fresh.text])
		fresh.pressed.emit()
		await _frames(2)
		_check(went == [[HoldSession.Road.FRESH, 1]],
			"the second press did not take the fresh road: %s" % str(went))
	went.clear()
	if back != null:
		hub.call("_show_card")
		await _frames(2)
		back = hub.find_child("RoadContinue", true, false) as Button
		if back != null:
			back.pressed.emit()
			await _frames(2)
		_check(went == [[HoldSession.Road.CONTINUE, 2]],
			"the road back did not continue the banked front at its act: %s" % str(went))
	MetaState.expedition = front_was
	hub.set("road_test_hook", Callable())
	hub.call("_hide_card")
	await _frames(2)
	hub.close()
	menu.queue_free()
	await _frames(3)
	_reached["stone_card"] = true


## **The Guide, the trailer and the Wardens are doors in the Hold and not on
## the front door** (owner, 2026-10-06), beside co-op, which already was.
## Through the real menu: each button stands in the Hold's grid, bound to a
## building of its own in the yard, and the front door's column no longer
## holds it; pressing the Guide's door from the Hold opens the Guide over the
## room and closing it comes back.
func _test_the_four_doors_moved_in() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	WardenGlass.mark_offered()
	var menu: Control = load("res://scenes/ui/main_menu.tscn").instantiate() as Control
	add_child(menu)
	await _frames(20)
	var hub: HubScreen = menu.get("_hub") as HubScreen
	var column: Node = (menu.get("new_run_button") as Button).get_parent() \
		if menu.get("new_run_button") != null else null
	_check(hub != null and column != null, "the real menu has no Hold or no column")
	if hub == null or column == null:
		menu.queue_free()
		_reached["four_doors"] = true
		return
	var yard: HoldYard = hub.get("_yard") as HoldYard
	var grid: Node = hub.get("_grid") as Node
	for door: String in ["Guide", "Wardens", "Coop"]:
		var button: Node = grid.get_node_or_null(door) if grid != null else null
		_check(button is Button, "the Hold's doors have no %s" % door)
		_check(column.get_node_or_null(door) == null, "the front door still carries %s" % door)
		_check(yard != null and yard.bound(door), "%s has no building in the yard" % door)
	# The trailer's door exists only when the film is in the build; where it
	# is, it moved in with the others.
	if TrailerPlayer.available():
		_check(grid != null and grid.get_node_or_null("Trailer") is Button
				and column.get_node_or_null("Trailer") == null and yard != null and yard.bound("Trailer"),
			"the trailer's door did not move into the Hold")
	# Pressing the Guide from the Hold opens it over the room, and closing it
	# comes back to the room.
	hub.open()
	await _frames(4)
	var guide_door: Button = grid.get_node_or_null("Guide") as Button if grid != null else null
	var guide: CanvasLayer = menu.get("_guide") as CanvasLayer
	if guide_door != null and guide != null:
		guide_door.pressed.emit()
		await _frames(3)
		_check(guide.visible and hub.is_suspended(), "the Guide did not open over the Hold from its door")
		guide.call("close")
		await _frames(3)
		_check(hub.visible and not hub.is_suspended(), "closing the Guide did not come back to the Hold")
	hub.close()
	menu.queue_free()
	await _frames(3)
	_reached["four_doors"] = true


func _click(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	get_viewport().push_input(motion)
	for down: bool in [true, false]:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = down
		press.position = at
		press.global_position = at
		get_viewport().push_input(press)


func _hovered_at(at: Vector2) -> String:
	var over: Control = get_viewport().gui_get_hovered_control()
	return String(over.get_path()) if over != null else "nothing"


func _touch(finger: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = finger
	touch.position = at
	touch.pressed = down
	get_viewport().push_input(touch, true)


func _drag(finger: int, at: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = finger
	drag.position = at
	get_viewport().push_input(drag, true)


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


## In seconds rather than frames: headless runs far above sixty a second.
func _seconds(span: float) -> void:
	var until: int = Time.get_ticks_msec() + int(span * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


# --- What waits at each door ---------------------------------------------------


## **Every door says what is waiting behind it, and nothing else** (owner,
## 2026-09-27: indicators *"further attention grabbing ... to get the player to
## come interact with it to check the notifications/see what's new"*).
##
## A badge is only worth having if it is true both ways: one that lit on every
## visit whether or not anything had changed would teach a player to ignore
## badges. So the news is driven from the account and read back - points to
## place appear and go, a better piece in the stash appears and goes when it is
## worn - and over a real Hold every door is loud exactly when `HoldNews` says
## so, and a loud door the view does not show becomes an arrow on the rim.
func _test_the_doors_say_what_waits() -> void:
	var kept_points: int = MetaState.hero_attribute_points
	var kept_stash: Array = MetaState.stash.duplicate(true)
	var kept_equipped: Dictionary = MetaState.equipped.duplicate()

	MetaState.hero_attribute_points = 3
	var card: Array[Dictionary] = HoldNews.of("card")
	_check(_says(card, "3 attribute points"), "3 points to place and the Stone does not say so: %s" % str(card))
	_check(HoldNews.count(card) >= 3, "the Stone's badge counts %d for 3 points" % HoldNews.count(card))
	MetaState.hero_attribute_points = 0
	_check(not _says(HoldNews.of("card"), "attribute"),
		"the Stone still says there are attribute points with none to place")

	MetaState.stash.clear()
	MetaState.equipped.clear()
	MetaState.stash.append(Stash.make("ashfall_glaive", 0, 1))
	MetaState.stash.append(Stash.make("ashfall_glaive", 4, 5))
	MetaState.equip(GearData.Slot.WEAPON, 0)
	_check(_says(HoldNews.of("stash"), "weapon"),
		"a far better weapon lies unworn and the stash does not say so: %s" % str(HoldNews.of("stash")))
	MetaState.equip(GearData.Slot.WEAPON, 1)
	_check(HoldNews.of("stash").is_empty(),
		"the best weapon is worn and the stash still calls: %s" % str(HoldNews.of("stash")))

	_check(HoldNews.of("pond").is_empty() == (MetaState.hold_pond_left() <= 0),
		"the pond's badge disagrees with the pond")
	_check(HoldNews.of("road").is_empty() == not MetaState.has_expedition(),
		"the road's badge disagrees with whether a front is banked")

	MetaState.hero_attribute_points = 2
	var hub := HubScreen.new()
	add_child(hub)
	hub.visible = true
	var yard: HoldYard = hub._yard
	for station: Dictionary in HoldYard.STATIONS:
		var door: String = String(station["door"])
		if door.is_empty() or yard.bound(door):
			continue
		var button := Button.new()
		button.name = door
		hub.add_child(button)
		yard.bind(door, button)
	hub._beacons.refresh_news()
	await _frames(3)
	var marks: Dictionary = hub._beacons.marks
	_check(marks.size() == yard.beacon_marks().size(),
		"%d doors and %d markers" % [yard.beacon_marks().size(), marks.size()])
	_check(marks.has("card") and bool(marks["card"]["hot"]) and int(marks["card"]["count"]) >= 2,
		"the Stone has points waiting and its marker is quiet: %s" % str(marks.get("card", {}).get("count", -1)))
	for id: String in marks:
		_check(bool(marks[id]["hot"]) == not HoldNews.of(id).is_empty(),
			"the %s marker is %s while its news is %s" % [id,
				"loud" if bool(marks[id]["hot"]) else "quiet", str(HoldNews.of(id))])
	hub._tick_prompt()
	_check(hub._prompt.text.contains("waiting"),
		"doors are waiting and the prompt says: %s" % hub._prompt.text)

	# The far side of the yard from the Stone, zoomed all the way in.
	var stone: Vector2 = (marks["card"] as Dictionary).get("foot", Vector2.ZERO) as Vector2
	var far: Vector2 = yard.warden_at()
	var widest: float = -1.0
	for mark: Dictionary in yard.beacon_marks():
		if String(mark["id"]) == "card":
			stone = mark["at"] as Vector2
	for mark: Dictionary in yard.beacon_marks():
		var gap: float = (mark["at"] as Vector2).distance_to(stone)
		if gap > widest:
			widest = gap
			far = mark["at"] as Vector2
	yard._seats[0]["at"] = far
	hub.set_zoom(Balance.HOLD_ZOOM_MAX)
	await _seconds(1.5)
	marks = hub._beacons.marks
	var screen: Rect2 = get_viewport().get_visible_rect()
	_check(bool(marks["card"]["arrow"]),
		"zoomed in at the far side, the Stone's marker at %s is not an arrow" % str(marks["card"]["at"]))
	_check(screen.has_point(marks["card"]["edge"] as Vector2),
		"the Stone's arrow is off the screen at %s" % str(marks["card"]["edge"]))
	_check((marks["card"]["edge"] as Vector2).y >= hub._beacons.room_top,
		"the Stone's arrow sits on the Hold's own bar: edge %s, room top %.1f, beacons %s, room %s" % [str(marks["card"]["edge"]), hub._beacons.room_top, str(hub._beacons.size), str(hub._beacons._room())])

	hub.queue_free()
	MetaState.hero_attribute_points = kept_points
	MetaState.stash = kept_stash
	MetaState.equipped = kept_equipped
	await _frames(2)
	_reached["news"] = true


func _says(lines: Array[Dictionary], words: String) -> bool:
	for line: Dictionary in lines:
		if String(line.get("text", "")).to_lower().contains(words.to_lower()):
			return true
	return false


## **The Hold's chrome is above its sky** (owner, 2026-09-28: *"The Hold gets a
## dark overlay cast over everything including the UIs"*). The hour is a
## `CanvasModulate` under the yard and a `CanvasModulate` tints its whole
## canvas, so the bar, the prompt, the markers and the card were graded like
## the buildings. They stand on a layer of their own now, above the thumb's
## controls, and it follows the room's visibility - a nested layer does not
## hide with its parent, and `is_visible_in_tree` cannot see a hidden layer,
## which is why this reads the layer itself.
## **The Hold talks** (2026-10-01): the road's chat in the room. Enter opens it
## with nothing focused and a line said goes to the party's bus; a button with
## the focus keeps Enter; Say is shown in company and not alone.
func _test_the_hold_talks() -> void:
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	hub.open()
	for _f: int in 4:
		await get_tree().process_frame
	var chat: PartyChat = hub.chat()
	_check(chat != null and chat.is_visible_in_tree(), "the Hold has no chat in the room")
	if chat == null:
		hub.queue_free()
		_reached["talks"] = true
		return
	var said: Array[String] = []
	var listen := func(_slot: int, text: String) -> void: said.append(text)
	EventBus.coop_chat.connect(listen)
	get_viewport().gui_release_focus()
	_push_enter()
	await get_tree().process_frame
	_check(chat.is_chatting(), "Enter in the Hold, with nothing focused, did not open the chat")
	chat.box.text = "anyone for Act IV?"
	_push_enter()
	await get_tree().process_frame
	_check(not chat.is_chatting(), "Enter in the Hold sent the line and left the box open")
	_check(said.has("anyone for Act IV?"), "a line said in the Hold never reached the party's bus")
	# A button holding the focus keeps Enter for itself.
	var close_button := hub.get("_close_button") as Button
	_check(close_button != null, "the Hold has no Close button to hold the focus")
	if close_button != null:
		close_button.grab_focus()
		await get_tree().process_frame
		_check(not chat.may_open(), "the chat would take Enter from a focused button")
		get_viewport().gui_release_focus()
	EventBus.coop_chat.disconnect(listen)
	var say := hub.find_child("Say", true, false) as Button
	_check(say != null and not say.visible, "Say shows with nobody to talk to")
	Coop.set("_state", Coop.State.HOSTING)
	hub.call("_refresh_bar")
	_check(say != null and say.visible, "Say is hidden in company")
	Coop.set("_state", Coop.State.OFFLINE)
	hub.call("_refresh_bar")
	hub.close()
	hub.queue_free()
	await get_tree().process_frame
	_reached["talks"] = true


func _push_enter() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_ENTER
	down.physical_keycode = KEY_ENTER
	down.pressed = true
	get_viewport().push_input(down)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	get_viewport().push_input(up)


func _test_the_chrome_is_above_the_sky() -> void:
	var hub := HubScreen.new()
	add_child(hub)
	await get_tree().process_frame
	var chrome: CanvasLayer = hub.get_node_or_null("Chrome") as CanvasLayer
	_check(chrome != null, "the Hold has no chrome layer of its own")
	if chrome == null:
		hub.queue_free()
		_reached["chrome"] = true
		return
	_check(chrome.layer > hub.layer, "the chrome sits under the room (%d against %d)" % [chrome.layer, hub.layer])
	_check(chrome.layer > hub.layer + 1,
		"the chrome sits under the thumb's controls, which stand one above the room")
	for what: String in ["Frame", "Card"]:
		var node: Node = hub.find_child(what, true, false)
		_check(node != null and node.get_parent() == chrome,
			"the Hold's %s is not on the chrome layer, so the hour's tint reaches it" % what)
	var sky: Node = hub.find_child("HoldSky", true, false)
	_check(sky != null and sky is CanvasModulate and (sky as CanvasItem).get_canvas_layer_node() == hub,
		"the Hold's sky is not the room's own canvas, so this test compares the wrong thing")
	_check(not chrome.visible, "the chrome is shown while the Hold is not")
	hub.open()
	await get_tree().process_frame
	_check(chrome.visible, "opening the Hold did not show its chrome")
	hub.close()
	await get_tree().process_frame
	_check(not chrome.visible, "closing the Hold left its chrome on screen")
	hub.queue_free()
	await get_tree().process_frame
	_reached["chrome"] = true
