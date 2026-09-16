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
			continue
		var stream: AudioStreamOggVorbis = load(path) as AudioStreamOggVorbis
		if stream == null:
			failures.append("sfx \"%s\" is not an OGG Vorbis stream" % key)
		elif stream.loop:
			failures.append("one-shot sfx \"%s\" must not loop" % key)
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
		if (String(key) != "default" and not paths.has(String(key))
				and not Sfx.GROUPS.has(String(key))):
			failures.append("mix names \"%s\", which is neither a sound nor a group" % key)
		if String(key).begins_with("sfx_wildlife_"):
			var wildlife_group: Array = Sfx.GROUPS.get(String(key), []) as Array
			if wildlife_group.size() < 4:
				failures.append("wildlife mix \"%s\" needs at least four recorded takes" % key)

	# **A sound on disk that nothing registers is silence with a file behind
	# it.** Seven were found that way on 2026-09-15 - every quake, tornado,
	# thunderclap and meteor in the game - recorded, placed, named by the
	# systems that throw them, and absent from `SOUNDS`. `Sfx.play` counts a
	# missing id and returns, which is correct and is exactly why nobody
	# noticed: no error, just nothing where a sound should be. The table used
	# to be the only record of what exists; the directory is the other one, and
	# the two have to agree.
	var audio := DirAccess.open("res://audio/sfx")
	if audio == null:
		failures.append("the sound directory must be readable")
	else:
		var registered: Dictionary = {}
		for key: Variant in paths:
			registered[String(paths[key]).get_file()] = true
		for file: String in audio.get_files():
			if not file.ends_with(".ogg"):
				continue
			if not registered.has(file):
				failures.append(("%s is on disk and in no table, so nothing can "
					+ "ever play it") % file)

	# **A stand-in must not be the loudest thing in the room.**
	#
	# Measured on 2026-09-15: the 43 synthesised placeholders played eight
	# decibels above the 139 recordings, and seven of them had no mix row at
	# all, so they took the loudest default there is. Nothing could have caught
	# that - no gate can hear - so the part of it a gate *can* see is held here:
	# a sound the project knows is a stand-in carries its own authored level,
	# and that level is below the default. The loudness itself is measured by
	# `tools/level_placeholders.py`, which a human runs.
	for stand_in: String in Sfx.PLACEHOLDERS:
		if not paths.has(stand_in):
			failures.append("placeholder \"%s\" is listed and is not a sound" % stand_in)
			continue
		if not Sfx.MIX.has(stand_in):
			failures.append(("placeholder \"%s\" has no mix row, so it plays at the "
				+ "loudest default there is") % stand_in)
			continue
		var level: float = float((Sfx.MIX[stand_in] as Dictionary).get("db", 0.0))
		if level >= float(Sfx.DEFAULT_MIX.get("db", -3.0)):
			failures.append(("placeholder \"%s\" is authored at %0.1f dB, at or above "
				+ "the default: a stand-in must not shout over the recordings")
				% [stand_in, level])

	# A group that eventually resolves to nothing is the failure nesting could
	# hide, so every chain is followed to a real sound.
	for group: Variant in Sfx.GROUPS:
		if _resolves(String(group), paths, 0) == 0:
			failures.append("group \"%s\" never reaches a real sound" % group)

	# Variation groups with their own mix row must throttle as one audible event,
	# not as independent recordings. Inspect the same pure policy playback uses;
	# starting a decoder in this short test can exit before the audio thread has
	# released it, which turns a passing gate into a false resource-leak failure.
	if Sfx.variation_mix_id("sfx_wildlife_badger", "sfx_wildlife_badger_1") \
			!= "sfx_wildlife_badger":
		failures.append("wildlife variations do not share the base species mix policy")

	# **And every group a caller names has to exist.**
	#
	# `Sfx.play_group` returns on its first line when the key is not in `GROUPS`
	# - no error, no warning, not even the `_blocked_missing` tally `play` keeps,
	# because nothing was missing: a key simply was not there. So a call site
	# that names the wrong group is perfect silence with working code behind it.
	#
	# Everything above this line checks the *tables* against each other and
	# against the directory, and all of it passed while four call sites named
	# groups that have never existed - including every drop landing on the road
	# and every pickup off it. That is the `DisciplineEffects` lie in the audio
	# system: the data is impeccable and the consumer is wrong.
	#
	# `play` is deliberately not walked the same way: it falls back to a group of
	# the same name and already counts what it cannot find.
	for missing: String in _groups_callers_name_that_do_not_exist():
		failures.append(missing)

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


## Every `play_group("x")` and `play_group_at("x")` in the project whose `x` is
## not a key in `GROUPS`. Source text rather than behaviour, deliberately: the
## failure is that nothing happens, and a gate cannot hear nothing.
func _groups_callers_name_that_do_not_exist() -> PackedStringArray:
	var bad: PackedStringArray = []
	for path: String in _every_script("res://"):
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var line_number: int = 0
		for line: String in file.get_as_text().split("
"):
			line_number += 1
			# Its own docstring names a group that does not exist, on purpose.
			if line.strip_edges().begins_with("#"):
				continue
			for call: String in ["play_group(\"", "play_group_at(\""]:
				var at: int = line.find(call)
				if at < 0:
					continue
				var from: int = at + call.length()
				var shut: int = line.find("\"", from)
				if shut < 0:
					continue
				var named: String = line.substr(from, shut - from)
				if named.is_empty() or Sfx.GROUPS.has(named):
					continue
				bad.append(("%s:%d names the sound group \"%s\", which is not in "
					+ "GROUPS - it plays nothing and says nothing")
					% [path, line_number, named])
	return bad


func _every_script(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	for name: String in dir.get_directories():
		if name.begins_with("."):
			continue
		found.append_array(_every_script(root.path_join(name)))
	for name: String in dir.get_files():
		if name.ends_with(".gd"):
			found.append(root.path_join(name))
	return found
