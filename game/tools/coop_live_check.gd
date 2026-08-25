extends Node

## Two real game processes, one socket, one scripted session.
##
##   godot --headless --path game res://tools/coop_live_check.tscn -- --role=host
##   godot --headless --path game res://tools/coop_live_check.tscn -- --role=guest
##
## Driven by `tools/coop_live.sh`, which launches both and reads both exits.
##
## **Why this exists when `coop_check.tscn` already passes.** That one stands two
## sessions up inside one process, which is what makes it cheap enough to run on
## every push — but it is not the path a player takes. It shares one `EventBus`
## autoload between the pair, one `RunState`, one class cache and one clock, and
## it drives `Coop` instances parented under hand-made subtrees rather than the
## autoload the game actually ships with.
##
## Every one of those differences could hide a real bug. Two processes share
## nothing: each has its own autoloads, its own default `MultiplayerAPI`, its own
## frame timing, and the packets go through the operating system's loopback rather
## than between two objects that happen to be in the same heap. If the shipping
## `Coop` singleton were mis-registered, or a fact only worked because both sides
## were reading the same `RunState`, this is what would catch it and the in-process
## harness would not.
##
## It is deliberately **not** in `guard.yml`. It needs two processes and a real
## port, which is a different shape of thing from a check that runs in a sandbox
## on every push, and a port collision on a shared runner would make it flaky —
## which is worse than absent (see `breather_check` for what that costs).

## Its own port, away from both `Balance.COOP_PORT` and the in-process gate's.
const LIVE_PORT: int = 45881

## Seconds either side will wait for the other before giving up.
##
## Generous: one process may reach `_ready` well before the other has finished
## loading, and a fixed sleep in the launcher would be either flaky or slow.
const PATIENCE: float = 25.0

var _role: String = ""
var _failures: int = 0
var _waited: float = 0.0
var _done: bool = false

## Guest side: facts received from the other process.
var _heard: Array = []
var _xp_awards: Array[float] = []


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.split("=")[1]
	if _role != "host" and _role != "guest":
		printerr("[live] --role=host or --role=guest is required")
		get_tree().quit(2)
		return

	RunState.reset(false, 314159265)
	GameDirector.run_active = true
	EventBus.enemy_died.connect(func(id: String, at: Vector2) -> void:
		_heard.append(["enemy_died", id, at]))
	EventBus.coop_enemy_spawned.connect(
		func(net_id: int, data_id: String, lane: int, at: Vector2,
				hp: float, dmg: float, spd: float) -> void:
			_heard.append(["spawned", net_id, data_id, lane]))
	EventBus.coop_tower_state.connect(
		func(anchor: Vector2i, id: String, level: int) -> void:
			_heard.append(["tower", anchor, id, level]))
	EventBus.coop_xp_awarded.connect(
		func(amount: float) -> void: _xp_awards.append(amount))

	if _role == "host":
		_check(Coop.host(LIVE_PORT), "the host must open the port: %s" % Coop.last_error)
	else:
		_check(Coop.join("127.0.0.1", LIVE_PORT),
			"the guest must start dialling: %s" % Coop.last_error)
	print("[live] %s ready" % _role)


func _process(delta: float) -> void:
	if _done:
		return
	_waited += delta
	if Coop.partner_present():
		_done = true
		# Deferred so both sides are certainly past their own `_ready` before
		# anything is sent. A packet that arrives while the other process is
		# still building its scene is a packet nobody was listening for.
		_run.call_deferred()
		return
	if _waited >= PATIENCE:
		_done = true
		_check(false, "%s waited %.0fs and never saw a partner" % [_role, PATIENCE])
		_finish()


func _run() -> void:
	if _role == "host":
		await _run_host()
	else:
		await _run_guest()
	_finish()


## The host authors a small, checkable set of facts.
func _run_host() -> void:
	_check(Coop.is_host() and not Coop.is_guest(), "the host must hold authority")
	_check(Coop.player_count() == 2, "and count two players once joined")
	await _hold(0.5)

	EventBus.enemy_died.emit("bogkin", Vector2(64.0, -32.0))
	EventBus.coop_enemy_spawned.emit(7, "bogkin", 1, Vector2(500.0, 0.0), 1.0, 1.0, 1.0)
	EventBus.coop_tower_state.emit(Vector2i(2, 3), "ember_spire", 1)
	# Awarded through the real path, so this exercises the shared-XP rule rather
	# than a hand-built signal.
	RunState.gain_hero_xp(250.0)
	await _hold(2.0)
	print("[live] host sent its facts")


## The guest must have received every one of them, unchanged.
func _run_guest() -> void:
	_check(Coop.is_guest() and not Coop.is_host(),
		"the guest must not hold authority")
	_check(Coop.player_count() == 2, "and count two players")
	var xp_before: float = RunState.hero_xp
	var level_before: int = RunState.hero_level
	await _hold(3.5)

	_check(_has("enemy_died"), "a kill must cross two processes")
	_check(_has("spawned"), "an enemy spawn must cross")
	_check(_has("tower"), "a tower placement must cross")

	# Shared XP: the award arrives and lands on this machine's own hero.
	_check(not _xp_awards.is_empty(), "an XP award must cross")
	if not _xp_awards.is_empty():
		_check(is_equal_approx(_xp_awards[0], 250.0),
			"and arrive as the amount awarded, got %.1f" % _xp_awards[0])
	var grew: bool = RunState.hero_xp > xp_before or RunState.hero_level > level_before
	_check(grew, "and must actually raise this player's own hero")

	# The guard must be clean: nothing here had any business authoring a fact.
	var relay: CoopRelay = Coop.relay()
	if relay != null:
		_check(relay.violations().is_empty(),
			"a guest must not have authored anything: %s"
				% ", ".join(relay.violations()))


func _has(kind: String) -> bool:
	for entry: Array in _heard:
		if String(entry[0]) == kind:
			return true
	return false


func _hold(seconds: float) -> void:
	var left: float = seconds
	while left > 0.0:
		left -= get_process_delta_time()
		await get_tree().process_frame


func _finish() -> void:
	Coop.leave()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	if _failures == 0:
		print("[live] %s PASS" % _role)
	get_tree().quit(_failures)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[live] %s: %s" % [_role, why])
