@tool
extends EditorScript

## Editor front-end: File > Run (Ctrl+Shift+X) with this script open.
##
## Generates a placeholder PNG for every asset in docs/ASSET_MANIFEST.md that is
## not already on disk. Existing files are left alone, so this is safe to run
## after real art has been installed — that is the whole point of it being
## additive.
##
## To regenerate everything from scratch, set FORCE to true, run once, and set
## it back. It overwrites real art too, so it does not get a convenient toggle.
##
## Headless equivalent:
##   godot --headless --path game --script res://tools/run_tool.gd -- generate

const FORCE: bool = false


func _run() -> void:
	var generator := PlaceholderGenerator.new()
	var result: Dictionary = generator.generate(FORCE)

	print("Placeholders: %d created, %d already present, %d failed (of %d in manifest)" % [
		result["created"], result["skipped"], result["failed"], result["total"],
	])
	for e: String in generator.errors:
		push_warning("generate_placeholders: " + e)

	# New files on disk are invisible to the editor until the filesystem is
	# rescanned, and an unimported PNG cannot be assigned to a Sprite2D.
	if int(result["created"]) > 0:
		EditorInterface.get_resource_filesystem().scan()
