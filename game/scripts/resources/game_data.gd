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


## True when the id is set and the derived file is actually on disk. Useful in
## tooling and in asserts; not something gameplay code should need.
func has_sprite() -> bool:
	var path: String = get_sprite_path()
	return not path.is_empty() and ResourceLoader.exists(path)
