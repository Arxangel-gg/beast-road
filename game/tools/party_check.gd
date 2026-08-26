extends Node

## Three and four players, in three and four real processes.
##
##   godot --headless --path game res://tools/party_check.tscn -- --role=host
##   godot --headless --path game res://tools/party_check.tscn -- --role=guest
##
## Driven by `tools/party.sh`, which starts one host and as many guests as it is
## asked for. **A second process could never have caught this**: the whole
## two-to-four change is about a party being keyed on seats rather than on the
## word "partner", and with two players a wrong seat and a right one are the same
## number.
##
## What it asserts, on every machine: everybody is here, everybody has a distinct
## seat, everybody has a body, and no two players wear the same colour.

const SETTLE: float = 8.0

## How long the host stays up after measuring, so nobody is counting an empty
## room. Longer than the stagger between processes plus one settle.
const LINGER: float = 16.0

var _role: String = ""
var _failures: int = 0
var _want: int = 2
var _rosters: int = 0
var _last_rows: int = 0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.split("=")[1]
		elif argument.begins_with("--players="):
			_want = maxi(int(argument.split("=")[1]), 2)
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true

	if _role == "host":
		_check(Coop.host(), "the host must open a port")
	else:
		await _hold(3.0)
		_check(Coop.join("127.0.0.1"), "a guest must be able to dial")
		await _until(func() -> bool: return Coop.state() == Coop.State.CONNECTED)
		_check(Coop.state() == Coop.State.CONNECTED, "and reach the host")

	EventBus.coop_party_roster.connect(func(rows: Array) -> void:
		_rosters += 1
		_last_rows = rows.size())

	# Everybody, not just the first arrival. A party fills over several seconds
	# and a harness that measures too early measures the queue.
	await _until(func() -> bool: return Coop.player_count() >= _want)
	_check(Coop.player_count() == _want,
		"%s must count %d players, saw %d"
			% [_role, _want, Coop.player_count()])

	# The roster is host-authored and lands a packet behind the connection.
	await _until(func() -> bool: return Coop.party().seats().size() >= _want)
	var seats: Array = Coop.party().seats()
	_check(seats.size() == _want,
		"%s must see %d seats, saw %d (rosters received: %d, last carried %d, "
			% [_role, _want, seats.size(), _rosters, _last_rows]
			+ "peers %d, state %d)" % [Coop.player_count(), Coop.state()])

	var numbers: Dictionary = {}
	var colours: Dictionary = {}
	for entry: Variant in seats:
		var seat := entry as CoopParty.Seat
		_check(seat.slot >= 1 and seat.slot <= Balance.COOP_MAX_PLAYERS,
			"a seat number must be inside the table, got %d" % seat.slot)
		_check(not numbers.has(seat.slot),
			"two players must not share seat %d" % seat.slot)
		numbers[seat.slot] = true
		var shade: String = str(seat.colour())
		_check(not colours.has(shade),
			"two players must not wear the same colour, %s twice" % seat.colour_name())
		colours[shade] = true
	_check(Coop.party().slot() >= 1,
		"%s must know which seat it is in" % _role)
	print("[party] %s is seat %d (%s) of %d" % [_role, Coop.party().slot(),
		Coop.party().colour_name_here(), seats.size()])

	# **Built here rather than begun.**
	#
	# `start_run` replaces the current scene and this harness *is* the current
	# scene, so pressing Begin frees it and nothing after this line ever runs -
	# which is what a first attempt did, printing the seat and then hanging until
	# it was killed. Instantiating the run as a child reproduces the ordering
	# that matters - session first, battlefield second - while leaving the
	# harness alive to look at it.
	GameDirector.run_active = true
	var run: Node = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(run)
	# **Waited for, not sampled.**
	#
	# Three processes start seconds apart, so "my own start plus eight seconds"
	# is a different moment on each of them - one measured before the last player
	# was seated and another after the first had gone home. Asking until the
	# answer is right, with a deadline, removes the stagger from the question
	# entirely: either everybody eventually sees everybody, or they do not.
	#
	# The battlefield's heroes, not every hero node in the tree. `GROUP_ANY` also
	# holds the raid arena's, which is a different fight and not in this party.
	var field: Battlefield = run.get("battlefield") as Battlefield
	_check(field != null, "%s must have a battlefield" % _role)
	if field == null:
		_finish()
		return
	await _until(func() -> bool: return field.heroes().size() >= _want)
	var heroes: Array = field.heroes()
	_check(heroes.size() == _want,
		"%s must see %d heroes on the field, saw %d"
			% [_role, _want, heroes.size()])
	var worn: Dictionary = {}
	for node: Node in heroes:
		var who := node as Hero
		if who == null:
			continue
		_check(not worn.has(who.party_slot),
			"two heroes must not claim seat %d" % who.party_slot)
		worn[who.party_slot] = true
	print("[party] %s sees %d heroes in seats %s"
		% [_role, heroes.size(), str(worn.keys())])

	# **Measured first, then lingers.** A host that leaves while anybody is still
	# counting tears the session down underneath them, and they report a party
	# that shrank rather than one that never formed.
	if _role == "host":
		await _hold(LINGER)
	_finish()


## Waits on a wall clock, generously.
##
## **Four Godot processes on one machine is the load this measures under**, and
## thirty seconds turned out to be marginal: the same code failed with two
## seatless guests on one run and passed completely on the next. That is a flaky
## harness, which is worse than no harness - it teaches you to re-run until
## green. The deadline is patience, not a property of the game, so it costs
## nothing to make it plainly sufficient.
func _until(done: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + 75000
	while Time.get_ticks_msec() < deadline and not bool(done.call()):
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[party] %s: %s" % [_role, why])


func _finish() -> void:
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	if _failures == 0:
		print("[party] %s PASS" % _role)
	get_tree().quit(_failures)
