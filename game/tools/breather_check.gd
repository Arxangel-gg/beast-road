extends Node

## Watches a real run and reports whether a between-wave breather ever opens.
##
## The reported bug was "I never got a chance to prepare in between each wave" -
## a phase that is unreachable, not one that is wrong. That is invisible to every
## other gate: the game runs, waves come, nothing errors. Only counting the
## transitions catches it.
##
## **Seeded, since 2026-08-25, and it has to be.** This ran on `RunState.reset()`
## with no seed, which draws a fresh random one - so every run rolled a different
## roster, different spawn positions and a different time to clear wave 1.
## Measured across runs of identical code, the first breather opened anywhere
## between 24 and 63 seconds. Against a 60-second window that is a coin toss, and
## the gate had been passing on luck rather than on the property it names.
##
## A flaky gate is worse than no gate: it trains everyone to re-run it until it
## goes green, which is the same as not having it. The seed makes this measure
## the breather mechanic instead of the dice, and the window is now wide enough
## that a slow-but-legal wave is not a failure.


## Fixed so the wave roster, spawn positions and clear time repeat exactly.
## Any seed would do; this one is simply the one that was verified.
const SEED: int = 271828182

var _breathers: int = 0
var _waves: int = 0
var _last_phase: int = -1
var _elapsed: float = 0.0
## Two full wave cycles with room to spare. 60 was the old default and sat right
## on the edge: a wave that took a legal 63 seconds to clear failed a gate that
## has no opinion about how long a wave takes.
var _seconds: float = 150.0
var _run: Node = null
var _field: Battlefield = null
var _started: bool = false
var _nag: float = 1.0
var _breather_age: float = 0.0
## Set when a breather ends with nothing having pressed Ride On, which is the
## property the countdown exists to provide.
var _proved_auto_start: bool = false


func _ready() -> void:
	# Runs while the tree is paused, so a run that *ends* is a failure with a
	# sentence rather than a process that never returns.
	#
	# The ending screen pauses the tree and waits for a click, and a headless
	# gate has no one to click it. This check therefore hung for six minutes and
	# was killed, which reads as "the gate is broken" rather than "the run ended
	# early" - the most expensive kind of failure to diagnose. Nothing here is
	# meant to run during a pause; the mode exists so the pause can be *reported*.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			_seconds = float(argument.split("=")[1])

	RunState.reset(false, SEED)
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	await get_tree().process_frame

	for node: Node in _all(get_tree().root):
		if node is Run:
			_run = node
		elif node is Battlefield:
			_field = node

	# Towers, while Preparation still allows building them. Without a defence
	# nothing ever dies, the road never clears, and a breather can never open -
	# which would look exactly like the bug this is testing for.
	RunState.gain_every_currency(99999)
	var towers: Array[TowerData] = ContentDB.base_towers()
	# Free placement, so a defence is built by walking out from each bend pocket
	# until legal ground is found rather than by naming slot indices.
	for lane: int in Balance.LANE_COUNT:
		for _pair: int in 2:
			_field.try_build(_field.free_anchor_near(lane), towers[lane % towers.size()])
	print("[breather] built %d towers during opening preparation"
		% get_tree().get_nodes_in_group(&"towers").size())

	# **The hero does not have to survive this gate to pass it.**
	#
	# Nothing here drives the hero: it stands at its spawn for 150 seconds while
	# waves arrive and, since predatory wildlife exist, while wolves and bears
	# hunt it. Three wounds later the run ends, the ending screen pauses the
	# tree, and a check about *phase transitions* has failed for a reason that
	# has nothing to do with phases.
	#
	# Same shape as the zero-Gold change: a harness whose subject is not the
	# economy must fund itself, and a harness whose subject is not survival must
	# survive. Made invulnerable rather than given health, so it cannot become a
	# slow drain that fails this on a long run.
	if _field.hero != null and _field.hero.health != null:
		_field.hero.health.add_invulnerability(_seconds + 60.0)
	# The hero is intentionally playable during safe planning. It must be the
	# active battlefield avatar even though towers and the next formation wait.
	if not _field.hero.is_in_group(Hero.GROUP) \
			or _field.entity_root.process_mode == Node.PROCESS_MODE_DISABLED:
		push_error("Preparation froze or deactivated the battlefield hero")
		_bail(1)


func _process(delta: float) -> void:
	_elapsed += delta

	# Opening Preparation is player-controlled, so begin once the automated
	# defence is established. Between-wave preparation is tested separately.
	if not _started and RunState.is_preparation():
		_nag -= delta
		if _nag <= 0.0:
			_nag = 1.0
			_run.call("_on_ride_on_requested")
	elif RunState.phase == RunState.Phase.ROAD_BATTLE:
		_started = true

	if RunState.phase != _last_phase:
		if _last_phase == RunState.Phase.PREPARATION and _breathers > 0 and RunState.phase == RunState.Phase.ROAD_BATTLE:
			_proved_auto_start = true
		if _last_phase == RunState.Phase.ROAD_BATTLE \
				and RunState.phase == RunState.Phase.PREPARATION:
			_breathers += 1
			if _field.enemy_count() > 0 or _field.wave_director.is_deploying():
				push_error("Preparation opened with %d enemies and deploying=%s" % [
					_field.enemy_count(), str(_field.wave_director.is_deploying())])
				_bail(1)
				return
			print("[breather] #%d opened at %.1fs after wave %d"
				% [_breathers, _elapsed, RunState.wave_number])
			_breather_age = 0.0
		_last_phase = RunState.phase

	if _started and RunState.is_preparation():
		_breather_age += delta
		# The opposite of what this used to assert. A between-wave breather is a
		# countdown now and has to end on its own, so nothing here presses Ride On
		# and overrunning the window is the failure.
		if _breather_age > Balance.PREPARATION_BETWEEN_WAVES + 2.0:
			push_error("A between-wave breather ran %.1fs without starting the wave"
				% _breather_age)
			_bail(1)
			return

	if RunState.phase == RunState.Phase.ENDED:
		push_error("The run ended at %.1fs, before the window closed - this gate "
			% _elapsed + "cannot measure breathers in a run that is over")
		_bail(1)
		return

	if RunState.wave_number > _waves:
		_waves = RunState.wave_number

	if _elapsed >= _seconds:
		set_process(false)
		print("[breather] %.0fs: waves=%d breathers=%d build_allowed_in_prep=%s"
			% [_seconds, _waves, _breathers, str(RunState.can_build_now())])
		# One per wave, not merely at least one. The first version of this feature
		# opened breathers on a clear road, which produced three across six waves -
		# and an opportunity the player cannot rely on is one they cannot plan
		# around, which is most of its value gone.
		if _breathers < _waves - 1:
			push_error("%d breathers across %d waves - every wave should get one"
				% [_breathers, _waves])
			_bail(1)
			return
		if not _proved_auto_start:
			push_error("No between-wave breather was seen ending on its own")
			_bail(1)
			return
		_bail(0)


func _bail(code: int) -> void:
	# This harness owns the instantiated run. Let it leave the tree before asking
	# the engine to stop; quitting with the live battlefield still attached made
	# an otherwise passing check emit ObjectDB/resource leak diagnostics.
	if is_instance_valid(_run):
		_run.queue_free()
	_field = null
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	get_tree().quit(code)


func _all(from: Node) -> Array[Node]:
	var found: Array[Node] = [from]
	for child: Node in from.get_children():
		found.append_array(_all(child))
	return found
