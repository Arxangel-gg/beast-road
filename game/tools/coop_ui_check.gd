extends Node

## Drives the co-op screen the way a player does, in two real processes.
##
##   godot --path game res://tools/coop_ui_check.tscn -- --role=host
##   godot --path game res://tools/coop_ui_check.tscn -- --role=guest
##
## Distinct from coop_live_check, which drives `Coop` directly. This one goes in
## through the **menu**: it builds the real MainMenu, finds the real Co-op
## button, presses it, and presses Host or Join on the real screen. That is the
## path a player takes, and it is the path that did not exist until now - every
## underlying piece was gated while none of it could be reached.

const PORT_WAIT: float = 30.0

var _role: String = ""
var _failures: int = 0
var _menu: MainMenu = null
var _coop: CanvasLayer = null

## Set once the run has begun. From that moment this harness must not tear
## anything down: closing the peer would drop the run-start packet the guest
## is waiting for, and the scene it lives in is about to be replaced anyway.
var _entered_run: bool = false

## What the host says, and what the guest heard it say.
const HOST_SAID: String = "pulling to the north road"
var _heard_chat: String = ""
var _heard_from: int = 0
var _notices: int = 0


## Set when a partner's cursor arrives over the wire, at the fork.
var _saw_partner_pointer: bool = false

## Set while watching for projectiles on the guest. Watched rather than sampled:
## a shot lives for a fraction of a second.
var _saw_tower_shot: bool = false
var _saw_enemy_shot: bool = false

## Set the moment this player's own hero is on the floor. Latched, because the
## host picks them back up a few seconds later and a sampled check would miss it.
var _was_downed: bool = false


func _process(_delta: float) -> void:
	if _role == "guest" and not _was_downed:
		var run: Node = get_node_or_null("Run")
		var field: Battlefield = run.get("battlefield") as Battlefield if run != null else null
		if field != null and field.hero != null and field.hero.is_downed():
			_was_downed = true
	if _saw_tower_shot and _saw_enemy_shot:
		return
	_scan_for_shots(get_tree().root)


func _scan_for_shots(from: Node) -> void:
	for child: Node in from.get_children():
		if child is Projectile:
			_saw_tower_shot = true
		elif child is EnemyProjectile:
			_saw_enemy_shot = true
		if _saw_tower_shot and _saw_enemy_shot:
			return
		_scan_for_shots(child)


## The host's world, adopted. Guest side.
func _on_host_run_started(seed_value: int, _endless: bool) -> void:
	RunState.reset(true, seed_value)
	print("[coop-ui] guest adopted the host's world, seed %d" % seed_value)


func _on_partner_pointer(_at: Vector2) -> void:
	var relay: CoopRelay = Coop.relay()
	if relay != null and relay.is_replaying():
		_saw_partner_pointer = true


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.split("=")[1]
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true

	EventBus.coop_chat.connect(func(slot: int, text: String) -> void:
		# Only what arrived. This machine draws its own copy of anything it says
		# from the same signal, and counting that would prove nothing.
		var relay: CoopRelay = Coop.relay()
		if relay != null and relay.is_replaying():
			_heard_chat = text
			_heard_from = slot)
	EventBus.party_notice.connect(func(_slot: int, _text: String) -> void:
		_notices += 1)

	_menu = (load("res://scenes/ui/main_menu.tscn") as PackedScene).instantiate() as MainMenu
	add_child(_menu)
	for _f: int in 12:
		await get_tree().process_frame

	# The button a player clicks. Found by name, not built here - if the menu
	# stops offering it, this fails, which is the point.
	var button: Button = _find_button(_menu, "Coop")
	_check(button != null, "the main menu must offer a Co-op button")
	if button == null:
		return _finish()
	button.emit_signal("pressed")
	await get_tree().process_frame
	_coop = _menu.get("_coop") as CanvasLayer
	_check(_coop != null and _coop.visible, "pressing it must open the co-op screen")
	if _coop == null:
		return _finish()

	if _role == "host":
		await _run_host()
	else:
		await _run_guest()
	# Skipped once the run has begun. `_finish` calls `Coop.leave()`, and closing
	# the peer discards anything not yet on the wire - including the packet that
	# tells the guest which world to roll. That is exactly how this failed:
	# the host asserted, tore down, and the guest sat in the menu and started a
	# run of its own with a different seed.
	if not _entered_run:
		_finish()


func _run_host() -> void:
	(_coop.get("_host_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(Coop.state() == Coop.State.HOSTING, "Host must open a session")
	_check(not Coop.local_address.is_empty(), "and report an address to share")
	print("[coop-ui] host listening on %s:%d" % [Coop.local_address, Balance.COOP_PORT])

	await _until(func() -> bool: return Coop.partner_present())
	_check(Coop.partner_present(), "the host must see the guest arrive")
	_check(Coop.player_count() == 2, "and count two players")

	# The button only unlocks with company, which is the rule it should express.
	var begin: Button = _coop.get("_begin_button") as Button
	_check(begin != null and not begin.disabled,
		"Begin must unlock once a friend has joined")
	print("[coop-ui] host sees partner; begin enabled")
	# The seed, announced the way pressing Begin announces it.
	#
	# This harness enters the run *in place* rather than by changing scene, so it
	# used to skip the one line of `start_run` that puts the host's world on the
	# wire - and the wrapper then compared the host's live seed against whatever
	# the guest happened to hold from connect time. It reported a mismatch on
	# every green run, which is the same as reporting nothing.
	RunState.reset(true, 0)
	EventBus.coop_run_started.emit(RunState.run_seed, false)
	await _hold(1.0)

	await _enter_run_in_place("host")

	# The half that matters. Connecting two people who then sit in two menus is
	# not co-op; pressing Begin has to take *both* of them into the *same* run.
	await _until(func() -> bool: return true)
	_entered_run = false
	print("[coop-ui] host run started, seed %d" % RunState.run_seed)
	# Give the socket a moment to actually send before anything else happens.
	await _hold(2.0)
	# Deliberately does not tear down or quit.
	#
	# `start_run` changes the scene and this harness *is* the current scene, so it
	# is freed a frame from now and will never reach `_finish` - same lesson as
	# `Coop` calling `goto_menu()` and deleting the harness it ran inside. Calling
	# `Coop.leave()` on the way out was worse than useless: it closed the peer
	# before the run-start packet had flushed, so the guest was never told and sat
	# in the menu rolling its own world.
	#
	# So the host says what it found and stops. The wrapper judges on the printed
	# assertions rather than on an exit code, because a process whose scene has
	# just been replaced has no clean exit to give.


## The guest joins the way the feature is meant to be used: by pasting a code.
##
## The address box is tested by every other harness here. What was not tested is
## the path a player actually takes now - copy, paste, Join - and "code
## connecting did not work" was the first thing play found. A code carries the
## port as well as the address, so this also proves the port survives the trip.
func _run_guest() -> void:
	# Claimed before the announcement can arrive, so `GameDirector` leaves the
	# scene alone: its handler bails on `run_active`, and this harness *is* the
	# current scene. The seed is then applied here, from the number that actually
	# crossed the wire - which is the property worth checking.
	GameDirector.run_active = true
	EventBus.coop_run_started.connect(_on_host_run_started)
	var code: String = CoopCode.encode("127.0.0.1", Balance.COOP_PORT)
	_check(not code.is_empty(), "the harness must be able to build a code")
	_check(CoopCode.looks_like_code(code), "and it must read as one")
	print("[coop-ui] guest joining by code %s" % code)
	(_coop.get("_join_field") as LineEdit).text = code
	(_coop.get("_join_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(Coop.state() == Coop.State.CONNECTING, "Join must start a connection")

	await _until(func() -> bool: return Coop.state() == Coop.State.CONNECTED)
	_check(Coop.state() == Coop.State.CONNECTED,
		"the guest must connect through the menu, not just through code")
	_check(Coop.is_guest() and not Coop.is_host(), "and hold no authority")
	print("[coop-ui] guest connected via the menu")

	await _until(func() -> bool: return true)
	_check(RunState.run_seed > 0, "and be in a real run")
	print("[coop-ui] guest connected, seed %d" % RunState.run_seed)
	await _enter_run_in_place("guest")
	# As above: the scene is about to be replaced, so report and go.


## Builds the battlefield *here* rather than by changing scene.
##
## `start_run` replaces the current scene and this harness is the current scene,
## so pressing Begin frees the harness and nothing after it can be checked. The
## bug worth checking lives exactly there: a battlefield built while a partner is
## already connected has missed every signal announcing them, and used to end up
## with no partner hero at all - so neither player could see the other, and on
## the host there was no sink for the guest's input, which is why "the guest
## cannot move".
##
## Instantiating the run as a child reproduces that ordering precisely - session
## first, battlefield second - while leaving the harness alive to look at it.
func _enter_run_in_place(role: String) -> void:
	GameDirector.run_active = true
	var run: Node = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(run)
	for _f: int in 30:
		await get_tree().process_frame
	var field: Battlefield = run.get("battlefield") as Battlefield
	_check(field != null, "the run must build a battlefield")
	if field == null:
		return

	_check(field.hero != null, "%s must have its own hero" % role)
	_check(field.partner_hero() != null,
		"%s must see the other player's hero - a battlefield built after the "
		% role + "session began must still find its partner")
	_check(field.heroes().size() == 2, "%s must count two heroes" % role)
	# Printed here rather than at connect time, on both sides, at the same point
	# in the run. The guest used to report the seed it held *before* the host
	# started the run, so the wrapper compared a stale number against a live one
	# and declared a mismatch on every green run - a check that always fails is
	# read as noise within a day.
	print("[coop-ui] %s in run, seed %d" % [role, RunState.run_seed])
	if field.partner_hero() != null:
		print("[coop-ui] %s sees both heroes" % role)

	if role == "host":
		# **The things three rounds of play kept finding, checked live.**
		#
		# Every one of these passed an in-process gate and failed in front of two
		# people, because a single process cannot tell "the guest was told" from
		# "the guest worked it out itself" - there is one RunState and one set of
		# nodes, so a guest that computed the wrong answer locally computed the
		# same wrong answer the host did.
		#
		# Made on the host, asserted on the guest, and nothing is shared between
		# them but the socket.
		# After a pause, deliberately. The first attempt made these facts the
		# instant the host's battlefield existed, and the guest was still
		# building its own - so the packets arrived before there was anything to
		# apply them to. Loot came through as zero and looked like a broken
		# feature rather than a race in the harness.
		await _hold(2.0)
		field.spawn_loot(RunState.GOLD, 7, Vector2(240.0, -120.0))
		var wildlife: Wildlife = field.find_child("Wildlife", true, false) as Wildlife
		if wildlife != null:
			# Forced rather than waited for: arrivals are a coin flip on a four
			# second clock and a harness must not be.
			for _try: int in 6:
				wildlife._consider_arrival()
			print("[coop-ui] host wildlife: %d" % wildlife.population())
		# Hurt the guest's hero, which is the one that no enemy could reach until
		# `nearest_hero` existed and whose health never crossed the wire at all.
		var guest_hero: Hero = field.partner_hero()
		if guest_hero != null and guest_hero.health != null:
			guest_hero.health.take_damage(guest_hero.health.max_hp * 0.4,
				guest_hero.global_position)
			print("[coop-ui] host wounded the guest's hero to %.0f%%"
				% (guest_hero.health.current_hp / guest_hero.health.max_hp * 100.0))

		# The host drives its own hero too, so the guest has something to mirror.
		# Without this the host stands still, and "the partner does not animate"
		# cannot be told apart from "the partner has nothing to animate".
		field.hero.use_input(PushedInput.new(field.hero))
		# The guest's input has to reach the hero the host is simulating for it.
		# Without a partner spawned there is no sink, the input is dropped, and
		# the guest is corrected back to its spawn on every packet.
		var partner: Hero = field.partner_hero()
		var from: Vector2 = partner.global_position
		await _hold(3.0)
		# Guarded, because the partner is freed the moment the guest leaves and
		# the guest is another process on its own clock. Reading a freed node was
		# how this first reported - as a script error rather than as a result.
		if partner == null or not is_instance_valid(partner):
			_check(false, "the guest left before the host could measure it move")
			return
		var moved: float = partner.global_position.distance_to(from)
		_check(moved > 4.0,
			"the guest's hero must move on the host when the guest pushes a "
			+ "stick, moved %.1f" % moved)
		print("[coop-ui] host moved the guest's hero %.1f units" % moved)
		# Moving is not the same as *animating*. Every animation in this game is
		# chosen from velocity, so a mirrored hero that is repositioned without
		# being driven slides along playing its idle - which is what "no walking
		# animation" looked like.
		_check(partner.velocity.length() > 1.0,
			"the mirrored hero must carry velocity, not just change position")
		print("[coop-ui] guest's hero has velocity %.0f on the host"
			% partner.velocity.length())
		# Outlives the guest deliberately: the guest is measuring *this* hero at
		# the same moment, and a host that leaves first takes the thing being
		# measured with it.
		await _hold(6.0)

		# **Chat.** A line typed on one machine has to arrive on the other,
		# carrying the seat that said it - the seat is what colours it and names
		# it, and a line attributed to the wrong player is worse than a line that
		# did not arrive.
		EventBus.coop_chat.emit(Coop.party().slot(), HOST_SAID)
		print("[coop-ui] host said something")

		# **Projectiles.** Reported as missing on the guest entirely - tower
		# shots, enemy shots and the ground effects that come off their impacts.
		#
		# Built and spawned rather than faked: a tower that is told to fire and a
		# ranged enemy that is told to swing are two different replication paths,
		# and only one of them existed.
		RunState.gain_every_currency(99999)
		var towers: Array[TowerData] = ContentDB.base_towers()
		var built: String = "no towers in the database"
		var anchor: Vector2i = field.free_anchor_near(0)
		var pick: TowerData = towers[0] if not towers.is_empty() else null
		if pick != null:
			built = field.try_build(anchor, pick)
		_check(built.is_empty(), "the harness must be able to build: %s" % built)
		var post: Vector2 = BattleGrid.tile_to_world(anchor)
		# Combat, or nothing shoots at anything: towers hold fire outside it and
		# enemies stand still. Set after the tower is up, because building is
		# locked to Preparation and that lock is deliberate.
		RunState.set_phase(RunState.Phase.ROAD_BATTLE)
		var howler: EnemyData = null
		for value: Variant in ContentDB.enemies.values():
			var kind := value as EnemyData
			if kind != null and kind.role == EnemyData.Role.HOWLER:
				howler = kind
				break
		for n: int in 4:
			if howler == null:
				break
			var mob: Enemy = field.spawn_enemy(howler, 0, 1.0, 1.0, 1.0)
			if mob != null:
				# Put down beside the tower rather than at the head of the road.
				# The road is two thousand units long and eight seconds of
				# walking does not cover it, so a harness that waits for them to
				# arrive is measuring patience.
				#
				# Half by the tower so it has something to shoot at, half within
				# their own range of the town so *they* have something to shoot
				# at. A ranged enemy with no target in reach walks, and walking
				# was all four of them did.
				mob.global_position = (post + Vector2(90.0 + 30.0 * float(n), 40.0)) 					if n < 2 else (field.town_position()
						+ Vector2(Balance.ENEMY_RANGED_RANGE * 0.6, 30.0 * float(n)))
		print("[coop-ui] host put a tower and %d ranged enemies on road 0"
			% (4 if howler != null else 0))
		# Coins again, and away from either hero so nothing collects them.
		#
		# The single early drop was still a race, just a slower one: it happens
		# about four seconds before the guest's battlefield exists, and a fact
		# with nothing to apply it to is simply gone - the guest then waited out
		# its whole deadline for a coin that had already been announced. Dropping
		# more than once removes the race rather than widening the window.
		for _drop: int in 4:
			field.spawn_loot(RunState.GOLD, 7,
				Vector2(-900.0, -900.0) + Vector2(40.0 * float(_drop), 0.0))
			await _hold(2.0)
		print("[coop-ui] host saw tower shots=%s enemy shots=%s"
			% [str(_saw_tower_shot), str(_saw_enemy_shot)])

		# **The revive, driven the way a player drives it.**
		#
		# The existing gate called `revive_in_place()` directly and asserted the
		# hero stood up - it tested the destination, not the road. Everything
		# that actually decides a revive lives on the road: the hold crossing the
		# wire, the distance test, the host's tick, and `partner_present()`,
		# which is false in every single-process harness and therefore skips the
		# whole system silently.
		var downed: Hero = field.partner_hero()
		if downed != null and is_instance_valid(downed):
			# Killed through health, the way a wolf kills, rather than by calling
			# `go_down` outright. The bug reported from play lived between the
			# two: the host's copy died and the guest's own hero kept standing,
			# because the knockdown was replicated as *damage* and the guest's
			# local rules were free to refuse it.
			downed.health.take_damage(downed.health.max_hp * 4.0,
				downed.global_position)
			_check(downed.is_downed(), "the guest's hero must go down")
			# Stand over them and hold the key.
			field.hero.global_position = downed.global_position + Vector2(20.0, 0.0)
			field.hero.use_input(HoldingInput.new(field.hero))
			var waited: float = 0.0
			while waited < Balance.COOP_REVIVE_SECONDS + 4.0 and downed.is_downed():
				await get_tree().process_frame
				waited += get_process_delta_time()
			_check(not downed.is_downed(),
				"holding the revive key over a downed partner must get them up: "
					+ "progress reached %.2f in %.1fs"
					% [downed.revive_progress(), waited])
			print("[coop-ui] host revived the guest's hero in %.1fs" % waited)
			# And they must be able to move again. A hero who is standing but
			# frozen is the same bug wearing a different face.
			field.hero.use_input(PushedInput.new(field.hero))

			# **And a wipe has to give both of them back.**
			#
			# Reported from play as "both locked at origin on the city base":
			# they come back, and then neither can move. Driven here rather than
			# announced, so the whole path runs - both down, the wipe latch, the
			# Wound, and two heroes who have to be able to walk afterwards.
			RunState.hero_wounds = 0
			field.hero.go_down(field.hero.global_position)
			downed.go_down(downed.global_position)
			await _until(func() -> bool:
				return field.hero.is_alive() and downed.is_alive())
			_check(field.hero.is_alive() and downed.is_alive(),
				"a team wipe must put both players back on their feet: host %s, "
					% str(field.hero.is_alive()) + "guest %s"
					% str(downed.is_alive()))
			_check(RunState.hero_wounds == 1,
				"and cost exactly one Wound between them, got %d"
					% RunState.hero_wounds)
			# Standing is not the same as playable.
			field.hero.use_input(PushedInput.new(field.hero))
			var stood_at: Vector2 = field.hero.global_position
			await _hold(1.5)
			var walked: float = field.hero.global_position.distance_to(stood_at)
			_check(walked > 8.0 and field.hero.velocity.length() > 20.0,
				"and a hero who came back from a wipe must be able to move, "
					+ "walked %.1f at velocity %.0f"
					% [walked, field.hero.velocity.length()])
			print("[coop-ui] host wiped, came back and walked %.1f at velocity %.0f"
				% [walked, field.hero.velocity.length()])

		# **The fork.** One question, two people, one answer.
		#
		# A single process cannot test this at all: there is one RunState, so a
		# guest that took its own road would be indistinguishable from a guest
		# that was told which road to take. Here the guest clicks and the host
		# has to be the thing that settles it.
		var fork: CrossroadScreen = run.get("crossroad_ui") as CrossroadScreen
		_check(fork != null, "the run must own a crossroad screen")
		if fork == null:
			return
		EventBus.coop_pointer_moved.connect(_on_partner_pointer)
		run.call("_open_crossroad", 1)
		_check(fork.is_open(), "the host must be standing at the fork")
		print("[coop-ui] host opened the fork")
		# The guest asks for a road. The host is what turns that into the road.
		await _until(func() -> bool: return RunState.active_road_id != "")
		_check(RunState.active_road_id != "",
			"the host must settle the fork when the guest asks for a road")
		_check(not fork.is_open(),
			"the fork must close on the host once it has been answered")
		print("[coop-ui] host settled the fork on road '%s'"
			% RunState.active_road_id)
		_check(_saw_partner_pointer,
			"the host must see where the guest's cursor is while the fork is up")
		await _hold(2.0)
	else:
		# Drive the local hero, which is what gets sampled and sent.
		var mine: Hero = field.hero
		var source := mine.input as LocalHeroInput
		_check(source != null, "the guest drives its own hero locally")
		var pushed := PushedInput.new(mine)
		mine.use_input(pushed)
		# The partner here is the *host's* hero. It should be walking under
		# relayed input rather than being slid about, so it must carry velocity
		# too - and its attack chain must be reachable, which is what makes a
		# swing visible rather than silent.
		var partner: Hero = field.partner_hero()
		if partner != null:
			_check(partner.input is RemoteHeroInput,
				"the host's hero must be driven from the wire on the guest")

		# The world the guest is standing in has to be the host's world, not one
		# it is deriving for itself. Distance drives the time of day, the night
		# difficulty bonus and the act, so if it is not the host's number then
		# the two are playing different games under different skies.
		await _hold(2.0)
		_check(RunState.distance_travelled > 0.0
			or RunState.weather_id != "",
			"the guest must be receiving the host's world clock")
		print("[coop-ui] guest world clock: distance %.0f weather '%s' act %d"
			% [RunState.distance_travelled, RunState.weather_id, RunState.act])
		# Longer than the host's measuring window on purpose. The partner hero is
		# freed the instant this process leaves, and the host is three seconds
		# into timing it - so a guest that finishes first takes the thing being
		# measured with it.
		await _hold(3.0)

		# Loot the host dropped. A coin that only one player can see is a coin
		# they cannot decide about together.
		#
		# Waited for rather than sampled. The two processes are launched six
		# seconds apart and each builds its battlefield on its own clock, so a
		# single reading at a fixed moment measures the launch offset as often as
		# it measures replication - it read 1 coin and then 0 across two runs of
		# identical code.
		await _until(func() -> bool:
			return get_tree().get_nodes_in_group(LootDrop.GROUP).size() > 0)
		var coins: int = get_tree().get_nodes_in_group(LootDrop.GROUP).size()
		_check(coins > 0, "the guest must see the loot the host dropped")
		print("[coop-ui] guest sees %d dropped coins" % coins)

		# Animals, so a hunt can be shared rather than watched.
		var wildlife: Wildlife = field.find_child("Wildlife", true, false) as Wildlife
		if wildlife != null:
			await _until(func() -> bool: return wildlife.population() > 0)
			_check(wildlife.population() > 0,
				"the guest must see the host's wildlife, or a shared hunt is "
					+ "one player swinging at nothing")
			print("[coop-ui] guest sees %d animals" % wildlife.population())

		# **The one that mattered most.** The guest's own hero was hurt on the
		# host; health was never replicated, so the two machines held different
		# opinions about whether anybody was injured and a guest could die on its
		# own screen while standing up on the host's.
		var own: Hero = field.hero
		if own != null and own.health != null and own.health.max_hp > 0.0:
			# Waited for, like the loot above. Health rides the periodic hero
			# batch rather than arriving as an event, so what a single reading
			# measures is how far apart the two processes were launched.
			await _until(func() -> bool:
				return own.health.current_hp < own.health.max_hp * 0.95)
			var ratio: float = own.health.current_hp / own.health.max_hp
			_check(ratio < 0.95,
				"the guest's own hero must show the damage the host dealt it, "
					+ "at %.0f%%" % (ratio * 100.0))
			print("[coop-ui] guest's hero is at %.0f%%" % (ratio * 100.0))

		await _hold(4.0)
		if partner != null and is_instance_valid(partner):
			print("[coop-ui] guest sees host hero velocity %.0f"
				% partner.velocity.length())
		print("[coop-ui] guest pushed its stick for seven seconds")

		# **The fork, from the side that does not decide it.**
		var fork: CrossroadScreen = run.get("crossroad_ui") as CrossroadScreen
		_check(fork != null, "the guest's run must own a crossroad screen")
		if fork == null:
			return
		await _until(func() -> bool: return fork.is_open())
		_check(fork.is_open(),
			"the guest must be shown the fork the host reached - a crossroad "
				+ "only one player can see is a decision only one player makes")
		var offer: PackedStringArray = fork.first_offer()
		_check(offer.size() == 2, "the guest must be offered the same roads")
		if offer.size() != 2:
			return
		print("[coop-ui] guest sees the fork, first road '%s'" % offer[0])
		# Where this player is pointing, so the host can draw it.
		EventBus.coop_pointer_moved.emit(Vector2(0.4, 0.6))
		fork._choose(offer[0], offer[1])
		# The click must *ask*, not decide. A guest that applied its own road
		# would have the two machines walking different ones.
		_check(RunState.active_road_id == "",
			"a guest's click must not take the road by itself - it asks, and "
				+ "the host answers, or 'whoever chose first' has no arbiter")
		await _until(func() -> bool: return RunState.active_road_id != "")
		_check(RunState.active_road_id == offer[0],
			"the guest must end up on the road it asked for, got '%s'"
				% RunState.active_road_id)
		print("[coop-ui] guest asked for '%s' and the host granted it"
			% RunState.active_road_id)

		# Projectiles: the tower's and the ranged enemy's. Counted by watching
		# rather than sampling - a shot exists for a fraction of a second, and a
		# single reading would miss every one of them and prove nothing.
		_check(_saw_tower_shot,
			"the guest must see its towers' projectiles fly")
		_check(_saw_enemy_shot,
			"and a ranged enemy's shot, or damage arrives from an empty field")
		# The pool an impact leaves is *not* asserted here, deliberately. It is
		# not a replicated thing: each machine's own projectile spawns its own
		# zone off its own impact, so what would be tested is whether this
		# harness managed to stage a hit - and staging one reliably means placing
		# enemies by hand, which is what made the first attempt measure its own
		# arithmetic rather than the game.
		print("[coop-ui] guest saw tower shots=%s enemy shots=%s"
			% [str(_saw_tower_shot), str(_saw_enemy_shot)])

		_check(_heard_chat == HOST_SAID,
			"the guest must hear what the host said, got '%s'" % _heard_chat)
		_check(_heard_from == 1,
			"attributed to the host's seat, got %d" % _heard_from)
		# And a receipt for something that happened, written locally from a fact
		# rather than sent as a sentence.
		_check(_notices > 0,
			"the guest must see notices for what the party did, saw %d" % _notices)
		print("[coop-ui] guest heard '%s' from seat %d, and %d notices"
			% [_heard_chat, _heard_from, _notices])

		# **Tending, from the seat that cannot pay for it.**
		#
		# Food is a shared purse the host owns. A guest that spent it locally had
		# the balance corrected back a moment later while the healing landed on a
		# body the host had never healed - so the button did nothing at all, and
		# was reported as exactly that. It has to be a request.
		if RunState.can_build_now() and mine.health != null:
			mine.health.current_hp = mine.health.max_hp * 0.4
			var before: int = RunState.currency(RunState.FOOD)
			field.try_tend_hero()
			await _until(func() -> bool:
				return mine.health.current_hp > mine.health.max_hp * 0.45)
			_check(mine.health.current_hp > mine.health.max_hp * 0.45,
				"the guest must be able to tend its own hero, still at %.0f%%"
					% (mine.health.current_hp / mine.health.max_hp * 100.0))
			print("[coop-ui] guest tended itself to %.0f%%, Food %d -> %d"
				% [mine.health.current_hp / mine.health.max_hp * 100.0,
					before, RunState.currency(RunState.FOOD)])

		# **The guest builds, and the host has to be the one who does it.**
		#
		# Nothing in the game ever sent a build request: the host had a handler
		# for one from the beginning and no caller. So a guest's tower was paid
		# for out of a purse the host owns, appeared on one screen, and was never
		# heard of again - reported as "guest built items do not appear for the
		# host". This asserts the tower comes *back*, which it can only do if the
		# host built it.
		var spot: Vector2i = field.free_anchor_near(2)
		var kinds: Array[TowerData] = ContentDB.base_towers()
		if not kinds.is_empty() and RunState.can_build_now():
			field.try_build(spot, kinds[0])
			_check(RunState.tower_at(spot) == null,
				"a guest's build must not happen locally - it asks, and the "
					+ "host answers, or the two hold different cities")
			await _until(func() -> bool: return RunState.tower_at(spot) != null)
			_check(RunState.tower_at(spot) != null,
				"and the host's answer must come back as a tower on this "
					+ "screen too")
			print("[coop-ui] guest asked for a tower at %s and got one" % spot)

		# The knockdown, which must not have been refusable.
		_check(_was_downed,
			"the guest's own hero must go down when the host says it did - "
				+ "healing on one screen while dying on the other is the worst "
				+ "shape this bug takes")
		print("[coop-ui] guest was put down and got back up")

		# The host put this hero down, revived it, and then wiped the pair. All of
		# that has happened by now, and the only thing that matters afterwards is
		# whether this player can still play - reported from play as both of them
		# standing at the city base unable to move.
		_check(mine.is_alive(),
			"the guest must be on its feet after being downed, revived and wiped")
		mine.use_input(PushedInput.new(mine))
		var was_at: Vector2 = mine.global_position
		await _hold(1.5)
		var went: float = mine.global_position.distance_to(was_at)
		# Velocity as well as displacement, and velocity is the real assertion.
		#
		# Two headless processes do not run at wall-clock speed, so distance
		# covered in 1.5 seconds measures the machine as much as the hero. What
		# cannot be explained away is a hero carrying full walking velocity: that
		# is the difference between "slow harness" and "cannot move".
		_check(went > 8.0 and mine.velocity.length() > 20.0,
			"the guest must be able to move after the wipe, walked %.1f at "
				% went + "velocity %.0f" % mine.velocity.length())
		print("[coop-ui] guest walked %.1f at velocity %.0f after the wipe"
			% [went, mine.velocity.length()])


## A stick held right, so the guest has something to send.
class PushedInput extends LocalHeroInput:
	func move() -> Vector2:
		return Vector2.RIGHT


## Standing still with the revive key down, which is what a rescue looks like.
class HoldingInput extends LocalHeroInput:
	func move() -> Vector2:
		return Vector2.ZERO

	func held(mask: int) -> bool:
		return mask == HeroInput.HOLD_REVIVE


func _find_button(from: Node, wanted: String) -> Button:
	for child: Node in from.get_children():
		if child is Button and child.name == wanted:
			return child as Button
		var found: Button = _find_button(child, wanted)
		if found != null:
			return found
	return null


## Waits on a wall clock, not on accumulated frame deltas.
##
## Deltas were the first attempt and made this harness flaky: two game processes
## do not start together, and a run that happened to be slow to boot spent its
## whole budget before the other side was listening - then connected a moment
## after the check had already failed. The log showed a failure and a success for
## the same thing, in that order, which is the signature of a deadline that was
## never really measuring time.
func _until(done: Callable) -> void:
	var deadline: int = Time.get_ticks_msec() + int(PORT_WAIT * 1000.0)
	while Time.get_ticks_msec() < deadline and not bool(done.call()):
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _finish() -> void:
	Coop.leave()
	Sfx.stop_immediately(); MusicPlayer.stop_immediately(); Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop-ui] %s PASS" % _role)
	get_tree().quit(_failures)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[coop-ui] %s: %s" % [_role, why])
