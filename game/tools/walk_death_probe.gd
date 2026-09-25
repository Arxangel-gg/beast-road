extends Node

## Diagnostic (2026-09-25): the owner died once on a new slot's first road -
## "maybe it was the Walk" - and was sent to the main menu with no report. This
## starts the Walk the way a new slot does, lets the Warden die once, and says
## where the game went. Never a gate.

func _ready() -> void:
	MetaState.hold_saves()
	# The Walk changes scene, which frees the current one: hand the tree a
	# stand-in to free so this probe outlives the change.
	var stand_in := Node.new()
	get_tree().root.add_child.call_deferred(stand_in)
	await get_tree().process_frame
	get_tree().current_scene = stand_in
	GameDirector.start_walk()
	await get_tree().create_timer(3.0).timeout
	var run := get_tree().current_scene
	print("[walk-probe] scene %s walking %s run_active %s" % [run.name if run != null else "none",
		RunState.walking, GameDirector.run_active])
	var hero: Hero = null
	if run != null and run.get("battlefield") != null:
		hero = (run.get("battlefield") as Battlefield).hero
	if hero == null:
		print("[walk-probe] no hero")
		get_tree().quit(1)
		return
	EventBus.walk_ended.connect(func(done: bool) -> void:
		print("[walk-probe] EventBus.walk_ended finished=%s wounds %d/%d" % [done, RunState.hero_wounds, RunState.max_wounds()]))
	print("[walk-probe] wounds before %d/%d, hp %.0f" % [RunState.hero_wounds, RunState.max_wounds(), hero.health.current_hp])
	hero.health.take_damage(hero.health.max_hp * 5.0, hero.global_position + Vector2(30, 0))
	await get_tree().create_timer(2.0).timeout
	print("[walk-probe] after one death: walking %s run_active %s wounds %d/%d scene %s" % [
		RunState.walking, GameDirector.run_active, RunState.hero_wounds, RunState.max_wounds(),
		get_tree().current_scene.name if get_tree().current_scene != null else "none"])
	get_tree().quit(0)
