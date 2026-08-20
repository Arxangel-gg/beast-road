extends Node

## Every id the sound tables name must resolve to a real stream.
##
##   godot --headless --path game res://tools/audio_verify.tscn
##
## The loader already warns on a missing file, but a warning during a tool run
## is easy to miss and the release gate is the only thing that catches it. This
## states it as a pass or a fail, and also checks the *groups*, which the loader
## cannot: a group naming an id that is not in the table plays nothing at all and
## warns about nothing, because there is no file to be missing.
##
## A scene rather than a SceneTree script: it reads the Sfx autoload, and a
## SceneTree script replaces the main loop so no autoload exists there.

func _ready() -> void:
	var failures: PackedStringArray = []
	var paths: Dictionary = Sfx.SOUNDS
	for key: Variant in paths:
		var path: String = String(paths[key])
		if not ResourceLoader.exists(path):
			failures.append("sfx \"%s\" points at a missing file: %s" % [key, path])
	for group: Variant in Sfx.GROUPS:
		var options: Array = Sfx.GROUPS[group] as Array
		if options.is_empty():
			failures.append("group \"%s\" is empty" % group)
		for option: Variant in options:
			# A member may be a sound *or* another group. "impact" names three
			# materials and each material names its own takes, which is the right
			# shape: the first choice is which surface was hit, the second is
			# which recording of it. Flattening that would make a group of nine
			# where the material no longer means anything.
			if not paths.has(String(option)) and not Sfx.GROUPS.has(String(option)):
				failures.append("group \"%s\" names \"%s\", which is neither a sound nor a group"
					% [group, option])
	for key: Variant in Sfx.MIX:
		if String(key) != "default" and not paths.has(String(key)):
			failures.append("mix names \"%s\", which is not a sound" % key)

	# A group that eventually resolves to nothing is the failure nesting could
	# hide, so every chain is followed to a real sound.
	for group: Variant in Sfx.GROUPS:
		if _resolves(String(group), paths, 0) == 0:
			failures.append("group \"%s\" never reaches a real sound" % group)

	print("[audio] %d sounds, %d groups, %d mix rows"
		% [paths.size(), Sfx.GROUPS.size(), Sfx.MIX.size()])
	for problem: String in failures:
		push_error("[audio] " + problem)
	print("[audio] %s" % ("PASS" if failures.is_empty() else "FAIL"))
	get_tree().quit(0 if failures.is_empty() else 1)


## How many real sounds a group reaches, following nested groups.
func _resolves(id: String, paths: Dictionary, depth: int) -> int:
	if depth > 4:
		return 0
	if paths.has(id):
		return 1
	if not Sfx.GROUPS.has(id):
		return 0
	var total: int = 0
	for option: Variant in Sfx.GROUPS[id] as Array:
		total += _resolves(String(option), paths, depth + 1)
	return total
