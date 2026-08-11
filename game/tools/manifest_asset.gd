class_name ManifestAsset
extends RefCounted

## One row of docs/ASSET_MANIFEST.md §5, resolved into everything the
## placeholder generator needs. Produced by ManifestParser; consumed by
## PlaceholderGenerator and AssetReporter.

## Full res:// path, e.g. "res://art/hero/hero_base.png".
var res_path: String = ""

var width: int = 0
var height: int = 0

## Manifest type column: T (transparent, ChatGPT) vs O (opaque, Midjourney).
## Decides whether the placeholder gets a transparent centre or a solid fill.
var transparent: bool = true

## The manifest's placeholder colour for this asset's category.
var colour: Color = Color.MAGENTA

## Manifest section this came from, e.g. "5.1 Hero". Reporting only.
var section: String = ""


func file_name() -> String:
	return res_path.get_file()


func size() -> Vector2i:
	return Vector2i(width, height)


func is_valid() -> bool:
	return not res_path.is_empty() and width > 0 and height > 0


func describe() -> String:
	return "%s %dx%d %s %s" % [
		res_path,
		width,
		height,
		"T" if transparent else "O",
		"#" + colour.to_html(false).to_upper(),
	]
