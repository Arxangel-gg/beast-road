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
static func load_idle_frames(base_path: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	if base_path.is_empty() or not ResourceLoader.exists(base_path):
		return out
	var first: String = idle_frame_path(base_path, 1)
	if not ResourceLoader.exists(first):
		return out
	out.append(load(base_path) as Texture2D)
	# Eight is a defensive ceiling, not an authored frame count. Production
	# structure loops currently ship three continuation frames and the art gate
	# owns that contract; runtime remains forward-compatible with a longer loop.
	for index: int in range(1, 9):
		var path: String = idle_frame_path(base_path, index)
		if not ResourceLoader.exists(path):
			break
		out.append(load(path) as Texture2D)
	return out


## True when the id is set and the derived file is actually on disk. Useful in
## tooling and in asserts; not something gameplay code should need.
func has_sprite() -> bool:
	var path: String = get_sprite_path()
	return not path.is_empty() and ResourceLoader.exists(path)
