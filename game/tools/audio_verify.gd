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

## The functions on a resource that answer "which recording". Named rather
## than found, because "a method returning a String that looks like an id" is
## a guess and this is a list somebody can read.
const SOUND_HELPERS: Array[String] = [
	"hurt_sfx", "death_sfx", "hit_sfx", "fall_sfx", "wing_sfx",
]

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

	# **And the mirror: a recording nothing can ever play.**
	#
	# The check above catches a caller naming a sound that does not exist. This
	# catches a sound existing that no caller names - which is how `sfx_wildfire`
	# sat recorded, registered and mixed for two days with `wildfire.gd` holding
	# no audio at all. Its mix row even authors a throttle, written for a call
	# site that was never made.
	#
	# It was already written down and acted on by nothing: SFX_PROMPTS.md has a
	# "prompted but never played" section whose prose says "Not a fault - a few
	# are chosen from data rather than written into code". True of the other 155
	# entries, which are music and ambience resolved by format string; false of
	# the one sfx_ entry in the list.
	for lonely: String in _sounds_no_caller_can_reach():
		failures.append(lonely)

	# **And every region lies under a bed that exists.**
	#
	# Nothing had ever read this table. Seven of the ten regions declare a bed
	# whose file is not on disk, and `Ambience.play` turns a missing file into
	# `stop()` - so acts IV to X were played in silence. That is worse than the
	# battle track's version of the same gap, which at least had a wrong answer
	# rather than no answer, and it is the kind of absence nothing can notice:
	# quiet is what ambience sounds like when it is working.
	for terrain: Variant in ContentDB.terrains.values():
		var region := terrain as TerrainData
		if region == null:
			continue
		var bed: String = Ambience.resolved_bed(region.id)
		if not Ambience.BEDS.has(bed):
			failures.append("%s lies under \"%s\", which is not a bed" % [region.id, bed])
			continue
		if not ResourceLoader.exists(String(Ambience.BEDS[bed])):
			failures.append(("%s lies under \"%s\", whose file is not on disk, so the "
				+ "region is silent") % [region.id, bed])
	for key: Variant in Ambience.WEATHER_BEDS:
		if not ResourceLoader.exists(String(Ambience.WEATHER_BEDS[key])):
			failures.append("the weather bed \"%s\" has no file" % str(key))

	# **Every breed on the road has a voice, and it is one that exists.**
	#
	# Six enemy archetypes were recorded, registered and mixed - beast, horde,
	# horn, siege, swarm and wraith - and on 2026-09-17 *not one of sixty-eight
	# breeds named any of them*. `Enemy.speak` was fully built: pitched by the
	# body making it, rationed across the field so a wave is not a wall of
	# noise, positional, and called from the behaviour tell. It returned on its
	# first line every time, because `voice_sfx` was empty everywhere. The whole
	# roster was mute and nothing could have said so.
	#
	# That is `sfx_wildfire` at sixty-eight times the scale - a recording made,
	# registered, mixed and played by nobody - and the answer is the one this
	# file has now reached three times: walk the *content* against the table,
	# not the table against itself.
	var mute: PackedStringArray = []
	var breeds: Array = ContentDB.enemies.values()
	breeds.sort_custom(func(a: EnemyData, b: EnemyData) -> bool: return a.id < b.id)
	for breed: EnemyData in breeds:
		if breed == null:
			continue
		if breed.voice_sfx.is_empty():
			mute.append(breed.id)
		elif not paths.has(breed.voice_sfx) \
				and not Sfx.GROUPS.has(breed.voice_sfx):
			# **Parenthesised.** `%` binds tighter than `+`, so without these the
			# format is applied to the last fragment alone - one `%s` against two
			# arguments, which is an error rather than a message.
			failures.append(("breed \"%s\" names a voice that is neither a sound "
				+ "nor a group: %s") % [breed.id, breed.voice_sfx])
	if not mute.is_empty():
		failures.append(("%d breed(s) have no voice at all, so `Enemy.speak` "
			+ "returns on its first line for them and they are silent on the "
			+ "road: %s") % [mute.size(), ", ".join(mute)])

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


## Every literal sound name a caller passes to `Sfx`, checked against the tables.
##
## Source text rather than behaviour, deliberately: the failure is that *nothing
## happens*, and a gate cannot hear nothing.
##
## `play_group` returns on an unknown key without even the `_blocked_missing`
## tally, which is how four call sites went silent for the life of the project.
## `play` is only slightly better - it counts the miss and returns - so a typo
## there is silence with a number nobody reads. Both are walked.
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
			for call: String in ["play_group(\"", "play_group_at(\"",
					"Sfx.play(\"", "Sfx.play_at(\""]:
				var at: int = line.find(call)
				if at < 0:
					continue
				var from: int = at + call.length()
				var shut: int = line.find("\"", from)
				if shut < 0:
					continue
				var named: String = line.substr(from, shut - from)
				if named.is_empty():
					continue
				# `play` resolves a sound first and falls back to a group of the
				# same name, so either table satisfies it. `play_group` only reads
				# GROUPS - but accepting both here costs nothing and keeps one
				# walker: the failure being caught is a name nothing can resolve.
				if Sfx.GROUPS.has(named) or Sfx.SOUNDS.has(named):
					continue
				bad.append(("%s:%d names the sound \"%s\", which is in neither "
					+ "SOUNDS nor GROUPS - it plays nothing and says nothing")
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


## Sound ids in `SOUNDS` that no caller anywhere names.
##
## "Names" is deliberately generous, because a strict reading would drown in
## false positives: a literal on any line of any `.gd` or `.tres` counts, so ids
## picked out of a data field or listed in a constant array are reached, and a
## member of a group that is itself reached is reached too.
##
## `Sfx.gd`'s own declaration rows are skipped - a table row is not a caller, and
## counting it makes the whole check vacuous, which is the first way I wrote it.
func _sounds_no_caller_can_reach() -> PackedStringArray:
	var named: Dictionary = {}
	for path: String in _every_script("res://"):
		_gather_named(path, named)
	_gather_called_helpers(named)
	for path: String in _every_data("res://data"):
		_gather_named(path, named)
	# A group's members are reached when the group is.
	var moved: bool = true
	while moved:
		moved = false
		for group: Variant in Sfx.GROUPS:
			if not named.has(String(group)):
				continue
			for option: Variant in (Sfx.GROUPS[group] as Array):
				if not named.has(String(option)):
					named[String(option)] = true
					moved = true
	var lonely: PackedStringArray = []
	for id: Variant in Sfx.SOUNDS:
		if not named.has(String(id)):
			lonely.append(("the recording \"%s\" is registered and mixed and no caller "
				+ "names it - it can never be heard") % str(id))
	return lonely


## **A resource that maps an id to a sound is a table, not a caller.**
##
## `WildlifeData.death_sfx()` is a `match` over seven recording names. Every
## one of those names is a literal in a `.gd` file, so the walk above counts
## them as reached - whether or not anything ever calls the function. Checked
## by planting the fault: with `Wildlife` no longer playing a death cry at
## all, this gate passed, which is the `DisciplineEffects` lie in a third
## place.
##
## So the literals inside a resource's sound helper only count when the helper
## itself is called from somewhere that is not the resource. A grep is a weak
## proof of behaviour and a strong proof of *wiring*, which is the half that
## goes silently false.
func _gather_called_helpers(named: Dictionary) -> void:
	var elsewhere: Dictionary = {}
	for path: String in _every_script("res://"):
		if path.begins_with("res://scripts/resources/"):
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		for line: String in file.get_as_text().split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for helper: Variant in SOUND_HELPERS:
				if line.contains(String(helper) + "("):
					elsewhere[String(helper)] = true
	for path: String in _every_script("res://scripts/resources"):
		var body := FileAccess.open(path, FileAccess.READ)
		if body == null:
			continue
		var taking: String = ""
		for line: String in body.get_as_text().split("\n"):
			var trimmed: String = line.strip_edges()
			if trimmed.begins_with("func "):
				taking = ""
				for helper: Variant in SOUND_HELPERS:
					if trimmed.begins_with("func " + String(helper) + "("):
						taking = String(helper)
				continue
			if taking.is_empty() or not elsewhere.has(taking):
				continue
			if trimmed.begins_with("#"):
				continue
			var from: int = 0
			while true:
				var open: int = line.find("\"sfx_", from)
				if open < 0:
					break
				var shut: int = line.find("\"", open + 1)
				if shut < 0:
					break
				named[line.substr(open + 1, shut - open - 1)] = true
				from = shut + 1


## Every `"sfx_..."` literal in one file, ignoring comments and, in `Sfx.gd`
## itself, the table rows that declare rather than call.
func _gather_named(path: String, into: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return
	# A resource under `scripts/resources` is a table of names exactly as
	# `Sfx.gd` is: it says what a thing is *called*, and something else has to
	# call it. Its literals arrive through `_gather_called_helpers` instead.
	if path.begins_with("res://scripts/resources/"):
		return
	var is_table: bool = path.ends_with("autoload/Sfx.gd")
	# **Every `const ... Dictionary` block is a declaration, not a caller.**
	#
	# The first cut skipped a line that began with `"sfx_` *and had no bracket*,
	# meaning to skip the `SOUNDS` rows. A `GROUPS` row is
	# `"sfx_x": ["sfx_x_1", ...]` - it has a bracket, so it was kept, so every
	# group and every take in it counted as "named" by its own table row. The
	# check was therefore vacuous for anything that has a group, which is nearly
	# every recording in the project: **500 sounds across 62 families - the whole
	# of the ecology's hurt, death, hit, fall, wing, egg, nest and blight cues,
	# and thirty species' own voices - were registered, mixed and played by
	# nobody, and this said zero.**
	#
	# That is the same shape as a comparison of two nothings, one step further
	# in: the skip was written against one table's *shape* rather than against
	# what a table *is*. Blocks now, by name.
	var declaring: bool = false
	for line: String in file.get_as_text().split("
"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#"):
			continue
		if is_table:
			if trimmed.begins_with("const SOUNDS") \
					or trimmed.begins_with("const GROUPS") \
					or trimmed.begins_with("const MIX"):
				declaring = true
				continue
			if declaring:
				if trimmed == "}":
					declaring = false
				continue
		# **Every quoted literal, not only the ones beginning `sfx_`.**
		#
		# Not every group carries the prefix - `swing_light` is one - so a scan
		# keyed on `"sfx_` never saw the call that reaches it and reported both
		# of its takes as unplayable. Recording every literal costs a dictionary
		# of strings nobody asks about and cannot miss a name.
		var from: int = 0
		while true:
			var open: int = line.find("\"", from)
			if open < 0:
				break
			var shut: int = line.find("\"", open + 1)
			if shut < 0:
				break
			into[line.substr(open + 1, shut - open - 1)] = true
			from = shut + 1


func _every_data(root: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	for name: String in dir.get_directories():
		found.append_array(_every_data(root.path_join(name)))
	for name: String in dir.get_files():
		if name.ends_with(".tres"):
			found.append(root.path_join(name))
	return found
