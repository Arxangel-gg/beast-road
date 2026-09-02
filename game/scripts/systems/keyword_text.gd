class_name KeywordText
extends RefCounted

## Lightweight semantic emphasis for prose-heavy UI.
##
## Content remains plain text in data. Presentation adds colour only at the
## final RichTextLabel, so saves, localisation work and gameplay logic never
## become coupled to BBCode. Words not in this short vocabulary stay untouched;
## the purpose is fast scanning, not turning every sentence into a rainbow.

const COLOURS: Dictionary = {
	"act": "d9a24d",
	"road": "d9a24d",
	"route": "d9a24d",
	"chronicle": "d9a24d",
	"oathbound": "d9a24d",
	"chain": "d9a24d",
	"chains": "d9a24d",
	"yuri": "d9a24d",
	"worldstrider": "d9a24d",
	"worldstriders": "d9a24d",
	"legacy": "d9a24d",
	"rank": "d9a24d",
	"town": "e2b65f",
	"tower": "e2b65f",
	"towers": "e2b65f",
	"gold": "e8bd55",
	"wood": "bd8a55",
	"food": "7fbd72",
	"stone": "aebbc3",
	"tools": "70b5dc",
	"tool": "70b5dc",
	"shards": "b68ad9",
	"marks": "d19adf",
	"health": "76c995",
	"heal": "76c995",
	"healing": "76c995",
	"wound": "e06f5d",
	"wounds": "e06f5d",
	"damage": "e06f5d",
	"breaches": "e06f5d",
	"killed": "e06f5d",
	"lost": "e06f5d",
	"failed": "e06f5d",
	"combat": "d77b55",
	"raid": "d77b55",
	"raids": "d77b55",
	"boss": "d77b55",
	"reward": "79c68a",
	"rewards": "79c68a",
	"unlock": "79c68a",
	"unlocks": "79c68a",
	"upgraded": "79c68a",
	"built": "79c68a",
	"kept": "79c68a",
	"preparation": "70b5dc",
	"planning": "70b5dc",
}


static func bbcode(source: String) -> String:
	var word_regex := RegEx.new()
	word_regex.compile("[A-Za-z][A-Za-z'-]*")
	var matches: Array[RegExMatch] = word_regex.search_all(source)
	var out: String = ""
	var cursor: int = 0
	for found: RegExMatch in matches:
		out += _safe(source.substr(cursor, found.get_start() - cursor))
		var word: String = found.get_string()
		var colour: String = String(COLOURS.get(word.to_lower(), ""))
		if colour.is_empty():
			out += _safe(word)
		else:
			out += "[b][color=#%s]%s[/color][/b]" % [colour, _safe(word)]
		cursor = found.get_end()
	out += _safe(source.substr(cursor))
	return out


static func apply(label: RichTextLabel, source: String) -> void:
	if label == null:
		return
	label.bbcode_enabled = true
	label.text = bbcode(source)


## Full-width brackets remain readable while never becoming author-controlled
## BBCode. Player names and future translated text can therefore be highlighted
## without opening an accidental markup path.
static func _safe(text: String) -> String:
	# Fullwidth brackets are absent from every bundled font, so escaping a
	# literal bracket drew two boxes on Android. BBCode understands [lb]
	# and [rb] for exactly this and they need no glyph at all.
	return text.replace("[", "[lb]").replace("]", "[rb]")
