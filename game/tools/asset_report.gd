@tool
extends EditorScript

## Editor front-end: File > Run (Ctrl+Shift+X) with this script open.
##
## Scans res://art/ and prints which assets are still placeholders and which
## have been replaced with real art, plus any disagreement between the art
## folder and docs/ASSET_MANIFEST.md.
##
## Headless equivalent:
##   godot --headless --path game --script res://tools/run_tool.gd -- report


func _run() -> void:
	var reporter := AssetReporter.new()
	var result: Dictionary = reporter.report()
	print(result["text"])
