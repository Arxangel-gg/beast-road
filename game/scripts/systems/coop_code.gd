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

## Ten characters is one address and a port. Sixteen is *two* addresses and a
## port, and that is the one worth sending.
##
## **A single address cannot serve both cases.** The public one is what a friend
## in another country needs and it is exactly the one that fails for a friend in
## the same house, because most routers will not loop a connection back to
## themselves. Reported from play as "code connecting did not work" - the code
## was right and the address in it could not have worked from where they were.
##
## So the code carries both, the joining machine tries the public one and falls
## back to the local one, and the player pastes one thing either way. Ten
## character codes still decode, because somebody will have one in a chat window.
const LENGTH: int = 10
const PAIR_LENGTH: int = 16


## A code carrying both of a host's addresses. Preferred over `encode`.
##
## `reachable` is tried first by whoever pastes it and `fallback` second, so the
## public address goes in the first slot. Either may be empty, in which case this
## falls back to the ten-character form for whichever one is present.
static func encode_pair(reachable: String, fallback: String, port: int) -> String:
	var first: PackedByteArray = _octets(reachable)
	var second: PackedByteArray = _octets(fallback)
	if first.is_empty():
		return encode(fallback, port)
	if second.is_empty() or first == second:
		return encode(reachable, port)
	if port <= 0 or port > 65535:
		return ""
	# Ten bytes is eighty bits and sixteen base-32 letters is eighty bits, so the
	# two fit exactly and there is no padding to reason about at either end.
	#
	# Streamed through a small bit buffer rather than assembled into one integer,
	# because eighty bits do not fit in one: GDScript ints are 64-bit, and the
	# first version quietly lost the top two octets of the first address. It
	# round-tripped the *second* address perfectly, which is exactly the kind of
	# half-right that reads as working.
	var bytes: PackedByteArray = first + second
	bytes.append((port >> 8) & 255)
	bytes.append(port & 255)
	var out: String = ""
	var buffer: int = 0
	var held: int = 0
	for byte: int in bytes:
		buffer = (buffer << 8) | byte
		held += 8
		while held >= 5:
			held -= 5
			out += ALPHABET[(buffer >> held) & 31]
	return "%s-%s" % [out.substr(0, 8), out.substr(8, 8)]


## The four octets of an IPv4 address, or an empty array if it is not one.
static func _octets(address: String) -> PackedByteArray:
	var parts: PackedStringArray = address.strip_edges().split(".")
	if parts.size() != 4:
		return PackedByteArray()
	var out := PackedByteArray()
	for part: String in parts:
		if not part.is_valid_int():
			return PackedByteArray()
		var octet: int = int(part)
		if octet < 0 or octet > 255:
			return PackedByteArray()
		out.append(octet)
	return out


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
	if cleaned.length() != LENGTH and cleaned.length() != PAIR_LENGTH:
		return {}
	var digits: Array[int] = []
	for index: int in cleaned.length():
		var digit: int = ALPHABET.find(cleaned[index])
		if digit < 0:
			return {}
		digits.append(digit)

	if cleaned.length() == LENGTH:
		var value: int = 0
		for digit: int in digits:
			value = (value << 5) | digit
		var port: int = value & 0xFFFF
		if port <= 0:
			return {}
		return {
			"address": _dotted((value >> 16) & 0xFFFFFFFF),
			"port": port,
			"alternate": "",
		}

	# Eighty bits in, ten bytes out: four octets, four octets, a port. Streamed
	# for the same reason `encode_pair` streams - eighty bits do not fit in one
	# GDScript integer.
	var bytes: PackedByteArray = PackedByteArray()
	var buffer: int = 0
	var held: int = 0
	for digit: int in digits:
		buffer = (buffer << 5) | digit
		held += 5
		if held >= 8:
			held -= 8
			bytes.append((buffer >> held) & 255)
	if bytes.size() != 10:
		return {}
	var port_pair: int = (bytes[8] << 8) | bytes[9]
	if port_pair <= 0:
		return {}
	return {
		"address": "%d.%d.%d.%d" % [bytes[0], bytes[1], bytes[2], bytes[3]],
		"alternate": "%d.%d.%d.%d" % [bytes[4], bytes[5], bytes[6], bytes[7]],
		"port": port_pair,
	}


static func _dotted(value: int) -> String:
	return "%d.%d.%d.%d" % [(value >> 24) & 255, (value >> 16) & 255,
		(value >> 8) & 255, value & 255]


## Whether this looks like a code rather than an address somebody typed.
##
## Asked before parsing so the join box can accept either without guessing: an
## address has dots and a code never does.
static func looks_like_code(text: String) -> bool:
	var cleaned: String = text.to_upper().replace("-", "").replace(" ", "").strip_edges()
	return not cleaned.contains(".") 		and (cleaned.length() == LENGTH or cleaned.length() == PAIR_LENGTH)
