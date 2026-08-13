extends Node

## Watches a real run and reports whether a between-wave breather ever opens.
##
## The reported bug was "I never got a chance to prepare in between each wave" -
## a phase that is unreachable, not one that is wrong. That is invisible to every
## other gate: the game runs, waves come, nothing errors. Only counting the
## transitions catches it.

var _breathers: int = 0
var _waves: int = 0
var _last_phase: int = -1
var _elapsed: float = 0.0
var _seconds: float = 60.0
var _run: Node = null
var _field: Battlefield = null
var _started: bool = false
var _nag: float = 1.0


func _ready() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seconds="):
			_seconds = float(argument.split("=")[1])

	RunState.reset()
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
	RunState.gain_resources(99999)
	var towers: Array[TowerData] = ContentDB.base_towers()
	for lane: int in Balance.LANE_COUNT:
		for slot: int in [0, 2]:
			_field.try_build(lane, slot, towers[lane % towers.size()])
	print("[breather] built %d towers during opening preparation"
		% get_tree().get_nodes_in_group(&"towers").size())
	# The hero is intentionally playable during safe planning. It must be the
	# active battlefield avatar even though towers and the next formation wait.
	if not _field.hero.is_in_group(Hero.GROUP) \
			or _field.entity_root.process_mode == Node.PROCESS_MODE_DISABLED:
		push_error("Preparation froze or deactivated the battlefield hero")
		_bail(1)


func _process(delta: float) -> void:
	_elapsed += delta

	# The opening Preparation has an eighteen second minimum and refuses Ride On
	# until it expires, so this asks once a second until the first battle starts
	# rather than once at frame zero. After that it stops asking - otherwise it
	# would skip the very breathers it is here to count.
	if not _started and RunState.is_preparation():
		_nag -= delta
		if _nag <= 0.0:
			_nag = 1.0
			_run.call("_on_ride_on_requested")
	elif RunState.phase == RunState.Phase.ROAD_BATTLE:
		_started = true

	if RunState.phase != _last_phase:
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
		_last_phase = RunState.phase

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
		_bail(0)


func _bail(code: int) -> void:
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
