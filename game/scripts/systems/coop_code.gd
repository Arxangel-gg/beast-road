class_name CoopCode
extends RefCounted

## A short, sayable stand-in for "an address and a port".
##
## **The thing that stops people playing together is the address.** A player who
## has to find their own public IP, read out four numbers and a port, and have a
## friend type them correctly will not play co-op twice. A code is one field to
## copy and one field to paste, it carries the port so nobody has to know there
## is one, and it fails loudly rather than connecting to a stranger when a
## character is mistyped.
##
## Ten characters from a 32-letter alphabet with the ambiguous shapes removed -
## no I, L, O or U, so nothing is ever misread as a 1 or a 0 and no code can
## accidentally spell a word. Six bytes go in: four of address and two of port.
## Grouped in fives with a dash, which is only decoration and is ignored coming
## back in.

const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"
const LENGTH: int = 10


## Turns an IPv4 address and a port into a code, or "" if the address is not one.
static func encode(address: String, port: int) -> String:
	var octets: PackedStringArray = address.strip_edges().split(".")
	if octets.size() != 4 or port <= 0 or port > 65535:
		return ""
	var value: int = 0
	for text: String in octets:
		if not text.is_valid_int():
			return ""
		var octet: int = int(text)
		if octet < 0 or octet > 255:
			return ""
		value = (value << 8) | octet
	value = (value << 16) | port

	var out: String = ""
	for index: int in LENGTH:
		# Most significant group first, so codes for neighbouring addresses look
		# different at the front rather than only at the tail.
		var shift: int = (LENGTH - 1 - index) * 5
		out += ALPHABET[(value >> shift) & 31]
	return "%s-%s" % [out.substr(0, 5), out.substr(5, 5)]


## Turns a code back into `{"address": String, "port": int}`, or {} if it is not
## a code. Tolerant of case, spaces and dashes; intolerant of anything else,
## because a code that half-parses sends somebody to the wrong machine.
static func decode(code: String) -> Dictionary:
	var cleaned: String = code.to_upper().replace("-", "").replace(" ", "").strip_edges()
	if cleaned.length() != LENGTH:
		return {}
	var value: int = 0
	for index: int in LENGTH:
		var digit: int = ALPHABET.find(cleaned[index])
		if digit < 0:
			return {}
		value = (value << 5) | digit
	var port: int = value & 0xFFFF
	var address: int = (value >> 16) & 0xFFFFFFFF
	if port <= 0:
		return {}
	return {
		"address": "%d.%d.%d.%d" % [(address >> 24) & 255, (address >> 16) & 255,
			(address >> 8) & 255, address & 255],
		"port": port,
	}


## Whether this looks like a code rather than an address somebody typed.
##
## Asked before parsing so the join box can accept either without guessing: an
## address has dots and a code never does.
static func looks_like_code(text: String) -> bool:
	var cleaned: String = text.to_upper().replace("-", "").replace(" ", "").strip_edges()
	return cleaned.length() == LENGTH and not cleaned.contains(".")
