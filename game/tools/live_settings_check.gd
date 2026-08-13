extends Node

## Changes a setting mid-run and asserts the game responds.
##
## Reported: "the graphics settings do not appear to actually affect the game
## visually when changed. Neither do the Colorblind options."
##
## Every existing check applied a preset *before* the scope was built, which is
## the one case that was never in doubt. Nothing tested the thing a player
## actually does: open settings during a run, change something, look at the game.
## A setting that only takes effect on the next battlefield is, from where they
## are sitting, a setting that does nothing.

var _failures: PackedStringArray = []


func _ready() -> void:
	RunState.reset()
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	add_child(load("res://scenes/run/run.tscn").instantiate())
	for _f: int in 4:
		await get_tree().process_frame

	await _check_graphics()
	await _check_colourblind()

	for problem: String in _failures:
		push_error(problem)
	print("[live] %d of 7 live/persistence checks pass" % (7 - _failures.size()))
	_bail(1 if not _failures.is_empty() else 0)


func _check_graphics() -> void:
	Graphics.apply_preset(Graphics.PRESET_HIGH)
	await get_tree().process_frame
	var shadows_before: int = _count_visible(ShadowKit.GROUP)
	var foliage_before: int = _foliage_clumps()
	var clouds_before: int = _count_class("CloudShadows")
	var casters_before: int = _count_visible(ShadowKit.CASTER_GROUP)
	print("[live] HIGH  shadows=%d foliage=%d clouds=%d casters=%d"
		% [shadows_before, foliage_before, clouds_before, casters_before])

	# What a player does: change it while the game is in front of them.
	Graphics.apply_preset(Graphics.PRESET_LOW)
	for _f: int in 6:
		await get_tree().process_frame

	var shadows_after: int = _count_visible(ShadowKit.GROUP)
	var foliage_after: int = _foliage_clumps()
	var clouds_after: int = _count_class("CloudShadows")
	var casters_after: int = _count_visible(ShadowKit.CASTER_GROUP)
	print("[live] LOW   shadows=%d foliage=%d clouds=%d casters=%d"
		% [shadows_after, foliage_after, clouds_after, casters_after])

	if shadows_after >= shadows_before and shadows_before > 0:
		_failures.append("contact shadows did not drop on Low (%d -> %d)"
			% [shadows_before, shadows_after])
	if foliage_after >= foliage_before and foliage_before > 0:
		_failures.append("foliage did not thin on Low (%d -> %d)"
			% [foliage_before, foliage_after])
	if clouds_after >= clouds_before and clouds_before > 0:
		_failures.append("cloud shadows did not switch off on Low")
	if casters_after >= casters_before and casters_before > 0:
		_failures.append("shadow casters did not clear on Low (%d -> %d)"
			% [casters_before, casters_after])


func _check_colourblind() -> void:
	Palette.set_mode(Palette.MODE_OFF)
	var before: Color = TowerData.element_colour(TowerData.Element.FIRE)
	Palette.set_mode(Palette.MODE_DEUTERANOPIA)
	await get_tree().process_frame
	var after: Color = TowerData.element_colour(TowerData.Element.FIRE)
	print("[live] fire %s -> %s" % [before.to_html(false), after.to_html(false)])
	if before.is_equal_approx(after):
		_failures.append("colourblind mode did not change the Fire element colour")

	# The Settings panel writes presentation state into MetaState, then a future
	# launch bridges it back out. Both directions must work or the controls only
	# survive until the process exits.
	UserSettings.store_presentation()
	var stored_graphics: Dictionary = MetaState.settings.get(UserSettings.GRAPHICS_KEY, {})
	if stored_graphics.is_empty():
		_failures.append("graphics choices were not copied into the persisted settings schema")
	Palette.set_mode(Palette.MODE_OFF)
	UserSettings.load_presentation()
	if Palette.mode() != Palette.MODE_DEUTERANOPIA:
		_failures.append("colourblind choice did not restore from persisted settings")


## Visible members of a group. Not a name match: Godot renames duplicates, so
## two hundred contact shadows are "ContactShadow", "ContactShadow2" and so on,
## and matching the bare name finds about four of them.
func _count_visible(group: StringName) -> int:
	var total: int = 0
	for node: Node in get_tree().get_nodes_in_group(group):
		var item := node as CanvasItem
		if item != null and item.is_visible_in_tree():
			total += 1
	return total


## Counts what is actually drawn, not what exists.
##
## Quality hides rather than deletes, so a player who turns a setting back up
## gets it back without the scope being rebuilt. Counting nodes therefore
## measures nothing: a hidden occluder is still a node and still blocks no light.
func _count_class(type_name: String) -> int:
	var total: int = 0
	for node: Node in _all(get_tree().root):
		var matches: bool = node.is_class(type_name) or (node.get_script() != null \
				and node.get_script().get_global_name() == type_name)
		if not matches:
			continue
		var item := node as CanvasItem
		if item == null or item.is_visible_in_tree():
			total += 1
	return total


func _foliage_clumps() -> int:
	for node: Node in _all(get_tree().root):
		if node is Foliage:
			return node.get_child_count()
	return 0


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
