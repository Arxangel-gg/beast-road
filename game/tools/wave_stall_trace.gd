extends Node

## Which bodies never reach the town, and what they were doing instead.
##
##   godot --headless --path game res://tools/wave_stall_trace.tscn -- --seconds=300
##   godot --headless --path game res://tools/wave_stall_trace.tscn -- --resume
##   godot --headless --path game res://tools/wave_stall_trace.tscn -- --no-wildlife
##
## A diagnostic, never a gate. The owner's report, 2026-09-22: "Not all enemies
## that have spawned go to the city base! Some seem to go off elsewhere or get
## lost preventing the wave from completing!"
##
## `enemy_siege_trace --mode=full` exists and cannot answer this, because its
## `_ready` clears the wildlife and switches the sky's events off - which is two
## of the ways a body can be pulled off the road removed before the measurement
## starts. This leaves the field exactly as it ships and watches two kinds of
## progress per body: closing on the wall, and advancing along the route it was
## given. A body doing **neither** for `LOST_AFTER` seconds is lost, whatever it
## thinks it is doing. Distance alone is not enough - the roads bend, so a body
## can walk half a minute of legitimate road while its distance to the town goes
## up, and the first cut of this flagged every one of them.
##
## It also prints the watchdog's own two readings every sample, because a rescue
## that never fires looks identical to a body that is still walking.

const SAMPLE: float = 0.5
## Seconds a body may fail to improve on its own best distance before it is
## called lost. Generous on purpose: a far route is nearly twice the direct one,
## a rout is 2.4s, and a body fighting a hero is legitimately standing still.
const LOST_AFTER: float = 25.0
## No body is judged before this, so a spawn walking its first leg is never it.
const MIN_AGE: float = 12.0
## How many samples of a lost body are kept for the dump.
const KEEP: int = 14

var _run: Run = null
var _field: Battlefield = null
var _clock: float = 0.0
var _seconds: float = 300.0
var _wildlife: bool = true
var _resume: bool = false
## instance id -> record
var _seen: Dictionary = {}
var _waves: Array[String] = []


func _ready() -> void:
	MetaState.hold_saves()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		elif arg == "--no-wildlife":
			_wildlife = false
		elif arg == "--resume":
			_resume = true
	if _resume:
		RunState.reset(true, 0)
		var applied: bool = Expedition.apply(MetaState.expedition)
		print("[stall] resumed expedition applied=%s act=%d wave=%d towers=%d" % [
			applied, RunState.act, RunState.wave_number,
			(MetaState.expedition.get("towers", []) as Array).size()])
	else:
		RunState.reset(false, 20260922)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(_run)
	for _frame: int in 24:
		await get_tree().process_frame
	_field = _run.battlefield
	if _field == null:
		print("[stall] no battlefield")
		get_tree().quit(1)
		return
	if not _wildlife:
		var animals: Node = _field.get_node_or_null("Wildlife")
		if animals != null and animals.has_method("clear"):
			animals.call("clear")
			animals.process_mode = Node.PROCESS_MODE_DISABLED

	# **Neither end of the fight may finish.** A town that falls settles the run
	# and every body after it is measured on a field that has stopped; a Warden
	# who dies does the same through a second door. Both are the floor the
	# withdrawal already uses, and `enemy_siege_check` learned this the hard way
	# when a giant ended its run forty breeds into the roster.
	if _field.town != null and _field.town.health != null:
		_field.town.health.floor_hp = _field.town.health.max_hp * 0.35
	if _field.hero != null and _field.hero.health != null:
		_field.hero.health.floor_hp = _field.hero.health.max_hp * 0.5

	EventBus.wave_cleared.connect(_on_wave_cleared)
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	_field.resume()
	if _field.wave_director != null and _field.wave_director.has_method("start"):
		_field.wave_director.start()
	print("[stall] town at %s bounds %s; wildlife=%s seconds=%.0f" % [
		_field.town_position(), _field.city_bounds(), _wildlife, _seconds])

	var next_sample: float = 0.0
	var next_census: float = 0.0
	while _clock < _seconds:
		await get_tree().process_frame
		_clock += get_process_delta_time()
		if _clock < next_sample:
			continue
		next_sample = _clock + SAMPLE
		var census: bool = _clock >= next_census
		if census:
			next_census = _clock + 10.0
		_sample(census)
	_report()
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 12:
		await get_tree().process_frame
	get_tree().quit(0)


func _on_wave_cleared(number: int) -> void:
	_waves.append("%d@%.0fs" % [number, _clock])
	print("[stall] %.1fs WAVE %d CLEARED" % [_clock, number])


func _gap_to_town(at: Vector2) -> float:
	var bounds: Rect2 = _field.city_bounds()
	var edge := Vector2(clampf(at.x, bounds.position.x, bounds.end.x),
		clampf(at.y, bounds.position.y, bounds.end.y))
	return at.distance_to(edge)


func _state_name(enemy: Enemy) -> String:
	var state: int = int(enemy.get("_state"))
	return Enemy.State.keys()[state] if state < Enemy.State.keys().size() else str(state)


func _target_name(enemy: Enemy) -> String:
	var target: Node = enemy.get("_target") as Node
	if target == null or not is_instance_valid(target):
		return "none"
	if target == _field.town:
		return "TOWN"
	if target is Hero:
		return "HERO"
	if target is Tower:
		return "TOWER"
	if target is Companion:
		return "SPIRIT"
	return String(target.get_class()) + ":" + String(target.name)


func _snapshot(enemy: Enemy) -> String:
	var at: Vector2 = enemy.global_position
	var route: PackedVector2Array = enemy.get("_route") as PackedVector2Array
	# **Never cast it.** `_provoker` can hold an animal that has been freed, and
	# casting a freed object throws rather than answering null - the fault
	# `Battlefield._process` shipped once with a companion. Asked as a Variant,
	# `is_instance_valid` answers without touching it.
	var provoker: Variant = enemy.get("_provoker")
	var held: String = "yes" if provoker != null and is_instance_valid(provoker) else "no"
	return ("t=%6.1f %-7s tgt=%-12s pos=(%7.1f,%7.1f) gap=%7.1f path=%d/%d spd=%5.1f"
		+ " routed=%s prov=%s chill=%.2f frz=%.2f stun=%.2f slow=%.2f hp=%.0f/%.0f") % [
		_clock, _state_name(enemy), _target_name(enemy), at.x, at.y, _gap_to_town(at),
		int(enemy.get("_path_index")), route.size(), enemy.current_speed(),
		enemy.is_routed(), held,
		float(enemy.get("_chill")), float(enemy.get("_freeze_left")),
		float(enemy.get("_hitstun_left")), float(enemy.get("_slow_factor")),
		enemy.health.current_hp if enemy.health != null else -1.0,
		enemy.health.max_hp if enemy.health != null else -1.0]


func _sample(census: bool) -> void:
	var live: int = 0
	var camps: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		if enemy.is_camp_mob():
			camps += 1
			continue
		live += 1
		var id: int = enemy.get_instance_id()
		var gap: float = _gap_to_town(enemy.global_position)
		if not _seen.has(id):
			_seen[id] = {
				"breed": enemy.data.id if enemy.data != null else "?",
				"lane": enemy.lane, "born": _clock, "best": gap, "best_at": _clock,
				"leg": int(enemy.get("_path_index")),
				"trail": [], "flagged": false, "wave": RunState.wave_number}
		var record: Dictionary = _seen[id]
		if gap < float(record["best"]) - 2.0:
			record["best"] = gap
			record["best_at"] = _clock
		# **Advancing along its own road counts as progress**, and the first cut
		# of this did not say so. The roads bend: a body reaches 640 units from
		# the wall, the corridor takes it south to 746 and then east, and it is
		# half a minute before it beats its own best again. Closing on the town
		# is one kind of progress and walking the route you were given is the
		# other; a body doing neither is the only one that is lost.
		var leg: int = int(enemy.get("_path_index"))
		if leg > int(record["leg"]):
			record["leg"] = leg
			record["best_at"] = _clock
		var trail: Array = record["trail"]
		trail.append(_snapshot(enemy))
		if trail.size() > KEEP:
			trail.pop_front()
		var age: float = _clock - float(record["born"])
		var stale: float = _clock - float(record["best_at"])
		if age >= MIN_AGE and stale >= LOST_AFTER and not bool(record["flagged"]):
			record["flagged"] = true
			print("[stall] %.1fs LOST %s lane=%d best=%.0f stale=%.0fs  %s" % [
				_clock, record["breed"], int(record["lane"]), float(record["best"]),
				stale, _snapshot(enemy)])
			print("        route=%s" % [enemy.get("_route")])

	if not census:
		return
	var director: Node = _field.wave_director
	var stuck: float = float(director.get("_stuck_for")) if director != null else -1.0
	print("[stall] %.1fs wave=%d phase=%s bodies=%d camps=%d stuck_for=%.1f nearest=%.0f checksum=%.1f town=%.0f" % [
		_clock, RunState.wave_number, RunState.Phase.keys()[RunState.phase], live, camps,
		stuck, _field.nearest_enemy_distance(), _field.wave_activity_checksum(),
		_field.town.health.current_hp if _field.town != null else -1.0])


func _report() -> void:
	print("")
	print("[stall] ================= REPORT after %.0fs =================" % _clock)
	print("[stall] waves cleared: %s" % [", ".join(_waves)])
	var lost: int = 0
	for id: Variant in _seen.keys():
		var record: Dictionary = _seen[id]
		if not bool(record["flagged"]):
			continue
		lost += 1
		var alive: bool = is_instance_valid(instance_from_id(int(id)))
		print("")
		print(("[stall] --- LOST #%d %s lane=%d spawned in wave %d at %.1fs;"
			+ " best gap %.0f at %.1fs; still alive=%s") % [lost, record["breed"],
			int(record["lane"]), int(record["wave"]), float(record["born"]),
			float(record["best"]), float(record["best_at"]), alive])
		for line: String in (record["trail"] as Array):
			print("[stall]     " + line)
	print("")
	print("[stall] %d of %d bodies were lost at some point" % [lost, _seen.size()])
	print("[stall] still standing now:")
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dying():
			continue
		print("[stall]     camp=%s %-18s %s" % [enemy.is_camp_mob(),
			enemy.data.id if enemy.data != null else "?", _snapshot(enemy)])
