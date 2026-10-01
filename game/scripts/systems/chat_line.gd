class_name ChatLine
extends RefCounted

## **What a line typed into the chat is, and how a line from the wire reads**
## (owner, 2026-10-01: *"Need to be able to chat in game, was already
## implemented but there's no controls hotkey for it and need you to elevate and
## polish it further and make it more like league of legends"*).
##
## Pure functions, so the screen, the relay and the gate ask one thing. A line
## is plain words, a command for this machine alone (`/help`, `/clear`,
## `/mute`, `/unmute`, `/time`), or one of two shapes that travel: an emote
## (`/me waves`) and a roll (`/roll`). What travels is text, as it always was -
## an emote goes as "/me waves" and a roll as "/roll 57 100", and every machine
## draws it by reading the same text through `read_wire`. A roll is rolled by
## the one who typed it, on dice of its own: it is a game between people and
## moves nothing in the run, so it has no reason to touch the run's streams.

enum Kind { EMPTY, SAY, EMOTE, ROLL, HELP, CLEAR, MUTE, UNMUTE, TIME, UNKNOWN }

## The commands, in the order `/help` lists them.
const COMMANDS: Array[Dictionary] = [
	{"usage": "/me <action>", "says": "says what your Warden does"},
	{"usage": "/roll [most]", "says": "rolls from 1 to 100, or to the number given"},
	{"usage": "/time", "says": "the road's clock, its act and its wave"},
	{"usage": "/mute <name>", "says": "hides what a partner says, on this screen only"},
	{"usage": "/unmute <name>", "says": "shows them again"},
	{"usage": "/clear", "says": "empties the log"},
	{"usage": "/help", "says": "this list"},
]

## The largest number a roll may be asked for.
const ROLL_MOST: int = 1000000


## The typed text with everything a line should not carry taken out: control
## characters (a newline would let one line pose as two), and anything past
## the length the box allows.
static func clean(typed: String) -> String:
	var out: String = ""
	for i: int in typed.length():
		var code: int = typed.unicode_at(i)
		if code < 32 or code == 127:
			out += " "
		else:
			out += typed[i]
	return out.strip_edges().substr(0, Balance.CHAT_MAX_LENGTH)


## What a typed line asks for.
static func parse(typed: String) -> Dictionary:
	var text: String = clean(typed)
	if text.is_empty():
		return {"kind": Kind.EMPTY}
	if not text.begins_with("/"):
		return {"kind": Kind.SAY, "text": text}
	var space: int = text.find(" ")
	var word: String = (text.substr(1, space - 1) if space > 0 else text.substr(1)).to_lower()
	var rest: String = text.substr(space + 1).strip_edges() if space > 0 else ""
	match word:
		"help", "h", "?", "commands":
			return {"kind": Kind.HELP}
		"me", "em", "emote":
			if rest.is_empty():
				return {"kind": Kind.UNKNOWN, "word": word, "why": "/me wants something to do"}
			return {"kind": Kind.EMOTE, "text": rest}
		"roll", "r", "dice":
			var most: int = 100
			if rest.is_valid_int():
				most = clampi(rest.to_int(), 2, ROLL_MOST)
			return {"kind": Kind.ROLL, "most": most}
		"time", "clock":
			return {"kind": Kind.TIME}
		"mute", "ignore":
			return {"kind": Kind.MUTE, "name": rest}
		"unmute", "unignore":
			return {"kind": Kind.UNMUTE, "name": rest}
		"clear", "cls":
			return {"kind": Kind.CLEAR}
		# League's party channel, so a hand that types "/p" out of habit is
		# still heard. A line that would itself begin with a slash loses it, or
		# it would be read as a command on the far side.
		"p", "party", "say", "s":
			var said: String = rest.lstrip("/").strip_edges()
			if said.is_empty():
				return {"kind": Kind.EMPTY}
			return {"kind": Kind.SAY, "text": said}
	return {"kind": Kind.UNKNOWN, "word": word}


## The text a line travels as. Empty for a line that does not travel.
static func wire(line: Dictionary, roll: int = 0) -> String:
	match int(line.get("kind", Kind.EMPTY)):
		Kind.SAY:
			return String(line["text"])
		Kind.EMOTE:
			return "/me " + String(line["text"])
		Kind.ROLL:
			return "/roll %d %d" % [roll, int(line["most"])]
	return ""


## How a line from the wire reads. A roll that does not add up is drawn as the
## words it arrived as, so a forged "/roll 900 100" claims nothing.
static func read_wire(text: String) -> Dictionary:
	var said: String = clean(text)
	if said.begins_with("/me "):
		var does: String = said.substr(4).strip_edges()
		if not does.is_empty():
			return {"kind": Kind.EMOTE, "text": does}
	if said.begins_with("/roll "):
		var parts: PackedStringArray = said.substr(6).split(" ", false)
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			var rolled: int = parts[0].to_int()
			var most: int = parts[1].to_int()
			if most >= 2 and most <= ROLL_MOST and rolled >= 1 and rolled <= most:
				return {"kind": Kind.ROLL, "rolled": rolled, "most": most}
	return {"kind": Kind.SAY, "text": said}


## Marked-up text for one line: the clock in grey, the speaker in their seat's
## colour, and the words in the log's own light - League's order, so who spoke
## is read before what they said. Everything a player typed is escaped, so a
## bracket in a name or a message is a bracket and never markup.
static func render(stamp: String, who: String, colour: Color, wire_text: String) -> String:
	var line: Dictionary = read_wire(wire_text)
	var clock: String = "[color=#8d8579]%s[/color] " % escape(stamp) if not stamp.is_empty() else ""
	var name: String = "[color=#%s]%s[/color]" % [colour.to_html(false), escape(who)]
	match int(line["kind"]):
		Kind.EMOTE:
			return "%s[i][color=#%s]* %s %s[/color][/i]" % [clock, colour.to_html(false),
				escape(who), escape(String(line["text"]))]
		Kind.ROLL:
			return "%s%s [color=#e8d9b0]rolls [b]%d[/b] (1-%d)[/color]" % [clock, name,
				int(line["rolled"]), int(line["most"])]
	return "%s%s[color=#8d8579]:[/color] [color=#ece6d8]%s[/color]" % [clock, name,
		escape(String(line["text"]))]


## A bracket written as text, never read as a tag.
static func escape(text: String) -> String:
	return text.replace("[", "[lb]")


## The road's clock as League writes it: minutes and seconds, and hours once
## there are any.
static func stamp(seconds: float) -> String:
	var whole: int = maxi(int(seconds), 0)
	var hours: int = whole / 3600
	var minutes: int = (whole % 3600) / 60
	var secs: int = whole % 60
	if hours > 0:
		return "[%d:%02d:%02d]" % [hours, minutes, secs]
	return "[%02d:%02d]" % [minutes, secs]
