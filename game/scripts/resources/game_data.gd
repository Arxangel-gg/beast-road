class_name GameData
extends Resource

## Base for every content resource (GDD §11: data-driven from day one).
##
## The rule this class exists to enforce: **a sprite path is derived from the
## resource `id`, and from nothing else** (CLAUDE.md §4). There is no manifest
## to edit, no path field to fill in, and no per-asset lookup table. Installing
## real art is overwriting a PNG.
##
## Subclasses supply the folder and the filename prefix; the id supplies the
## rest. If you ever feel the need to add an `icon_path` export to one of these,
## the answer is to fix the id in the `.tres` instead.

## Stable, unique, snake_case. This is the filename, the save-file key, and the
## thing other resources refer to. Renaming one is a content migration.
@export var id: String = ""

## Player-facing name. Never used for lookup.
@export var display_name: String = ""

## One line of flavour or rules text, shown in tooltips.
@export_multiline var description: String = ""


## Overridden by every subclass. Returns "" when the id is unset so a
## half-authored resource fails loudly at the point of use rather than silently
## loading the wrong texture.
func get_sprite_path() -> String:
	return ""


## The one place the naming convention is spelled out.
static func derive_path(folder: String, prefix: String, resource_id: String) -> String:
	if resource_id.is_empty():
		return ""
	return "res://art/%s/%s%s.png" % [folder, prefix, resource_id]


## The authored structure-idle convention. Frame zero is always the ordinary
## sprite path; generated continuation frames sit beside it as `_idle_01`,
## `_idle_02`, and so on. Keeping the source pose as frame zero means replacing
## or regenerating a structure never requires a resource or scene edit.
static func idle_frame_path(base_path: String, index: int) -> String:
	if base_path.is_empty() or index <= 0:
		return base_path
	return "%s_idle_%02d.png" % [base_path.get_basename(), index]


## Loads a complete-by-convention idle sequence. No continuation frame is a
## supported state and returns an empty series, which lets callers retain their
## transform fallback. Once frame 01 exists, loading stops at the first gap so
## a damaged install cannot jump across a missing pose.
## The authored *move* convention, exactly parallel to the idle one.
##
## `_move_01`, `_move_02` and so on beside the ordinary sprite, which stays pose
## zero for both loops. A creature that walks and a creature that stands still
## are two sequences over one source, so neither needs a resource edit.
## The authored *flight* convention, for anything that leaves the ground.
##
## A third sequence rather than reusing the move one, because a bird walking and
## a bird flying are not the same animal doing the same thing at two speeds - a
## crow that hopped across the sky was the whole of the report.
## The authored *attack* convention, for anything that fights.
##
## Its own sequence rather than a reuse of the walk, because the wind-up is the
## thing the player reads to decide whether to move - an animal that swung with
## its walking pose would be a hit with no tell in front of it.
static func attack_frame_path(base_path: String, index: int) -> String:
	if base_path.is_empty() or index <= 0:
		return base_path
	return "%s_attack_%02d.png" % [base_path.get_basename(), index]


static func load_attack_frames(base_path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if base_path.is_empty():
		return out
	for index: int in range(1, 9):
		var path: String = attack_frame_path(base_path, index)
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


static func flight_frame_path(base_path: String, index: int) -> String:
	if base_path.is_empty() or index <= 0:
		return base_path
	return "%s_fly_%02d.png" % [base_path.get_basename(), index]


static func load_flight_frames(base_path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if base_path.is_empty():
		return out
	for index: int in range(1, 9):
		var path: String = flight_frame_path(base_path, index)
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


static func move_frame_path(base_path: String, index: int) -> String:
	if base_path.is_empty() or index <= 0:
		return base_path
	return "%s_move_%02d.png" % [base_path.get_basename(), index]


## **The base sprite is not part of a move loop**, which is the one place this
## differs from the idle convention.
##
## Frame zero being the ordinary sprite is right for standing still: the base
## *is* the resting pose. It is wrong for walking, because the base is an animal
## sitting or standing and the authored frames are it mid-stride - so a two-frame
## walk alternated between sitting and running, which reads as the sprite being
## replaced rather than animated. Reported from play as a squirrel that "flashes,
## almost like it is not the same squirrel".
static func load_move_frames(base_path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if base_path.is_empty():
		return out
	for index: int in range(1, 9):
		var path: String = move_frame_path(base_path, index)
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


static func load_idle_frames(base_path: String) -> Array[Texture2D]:
	return _load_sequence(base_path, idle_frame_path)


## One sequence loader for both conventions.
##
## Shared rather than copied, because the awkward parts - frame zero being the
## ordinary sprite, and stopping at the first gap so a damaged install cannot
## jump across a missing pose - are exactly the parts that would drift if there
## were two of them.
static func _load_sequence(base_path: String, namer: Callable) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if base_path.is_empty() or not ResourceLoader.exists(base_path):
		return out
	var first: String = namer.call(base_path, 1)
	if not ResourceLoader.exists(first):
		return out
	out.append(load(base_path) as Texture2D)
	# Eight is a defensive ceiling, not an authored frame count. Production
	# structure loops currently ship three continuation frames and the art gate
	# owns that contract; runtime remains forward-compatible with a longer loop.
	for index: int in range(1, 9):
		var path: String = namer.call(base_path, index)
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


## True when the id is set and the derived file is actually on disk. Useful in
## tooling and in asserts; not something gameplay code should need.
func has_sprite() -> bool:
	var path: String = get_sprite_path()
	return not path.is_empty() and ResourceLoader.exists(path)
