class_name HoldNews
extends RefCounted

## What is waiting at each door of the Hold, read off the account every time it
## is asked and **stored nowhere**.
##
## Owner, 2026-09-27: *"Interactables at the Hold need to have clear and
## aesthetic indicators for interaction that are further attention grabbing and
## have more indicators to get the player to come interact with it to check the
## notifications/see what's new."*
##
## **Derived, never stored**, which is the comfort card's and the Glass's rule
## for the same reason: a "seen" flag per door would be a new save key every
## account gains, and it would go stale the moment the thing it describes
## changed somewhere else. Everything here is a question the account can already
## answer - points unspent, fish rising, a line met, a piece that beats the worn
## one - so a badge can never say something is waiting when it is not, and never
## miss something that is.
##
## **What is not here, deliberately.** The Codex and the Chronicle would want
## "new since you last looked", which is exactly the stored flag this refuses,
## so they wear the plain marker every door wears. A badge that lit up on every
## visit whether or not anything had changed would teach the player to ignore
## badges, which is the one thing this exists to prevent.
##
## Each entry is `{"text": String, "count": int}`; a door's badge shows the sum.


static func of(station_id: String) -> Array[Dictionary]:
	match station_id:
		"card":
			return _card()
		"road":
			return _road()
		"pond":
			return _pond()
		"ledger":
			return _ledger()
		"stash":
			return _stash()
		"vendor":
			return _vendor()
		"smithy":
			return _smithy()
		"stable":
			return _stable()
	return []


## The badge's figure for a door: every waiting thing counted once.
static func count(lines: Array[Dictionary]) -> int:
	var total: int = 0
	for line: Dictionary in lines:
		total += maxi(int(line.get("count", 1)), 1)
	return total


static func _line(text: String, amount: int = 1) -> Dictionary:
	return {"text": text, "count": amount}


static func _plural(amount: int, one: String, many: String) -> String:
	return one if amount == 1 else many


# --- The doors ----------------------------------------------------------------


## The Warden's Stone opens the Disciplines, the attributes and the Glass.
static func _card() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var skill: int = MetaState.skill_points_free()
	if skill > 0:
		out.append(_line("%d skill %s to learn" % [skill,
			_plural(skill, "point", "points")], skill))
	var placed: int = MetaState.hero_attribute_points
	if placed > 0:
		out.append(_line("%d attribute %s to place" % [placed,
			_plural(placed, "point", "points")], placed))
	return out


static func _road() -> Array[Dictionary]:
	if MetaState.has_expedition():
		return [_line("Your front is banked and waiting")]
	return []


static func _pond() -> Array[Dictionary]:
	var left: int = MetaState.hold_pond_left()
	if left > 0:
		return [_line("%d %s rising" % [left, _plural(left, "fish", "fish")], left)]
	return []


static func _ledger() -> Array[Dictionary]:
	var met: int = 0
	for order: ExchangeOrder in Exchange.orders():
		if order.stage == ExchangeOrder.Stage.FILLED:
			met += 1
	if met > 0:
		return [_line("%d %s met - collect" % [met,
			_plural(met, "line", "lines")], met)]
	return []


## A piece in the stash worth more attribute points than the one worn in its
## slot - including a slot with nothing in it at all.
static func _stash() -> Array[Dictionary]:
	var better: Array[String] = []
	for slot: int in GearData.Slot.values():
		var worn: int = worn_points(slot)
		for index: int in MetaState.stash.size():
			if MetaState.is_equipped_index(index):
				continue
			var piece: Dictionary = MetaState.stash[index] as Dictionary
			var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
			if kind == null or int(kind.slot) != slot:
				continue
			if Stash.points(piece, kind) > worn:
				better.append(slot_name(slot))
				break
	if better.is_empty():
		return []
	var text: String = "A better %s in the stash" % better[0].to_lower()
	if better.size() > 1:
		text = "Better %s and %d more in the stash" % [better[0].to_lower(), better.size() - 1]
	return [_line(text, better.size())]


## A ware the Warden can afford that beats what they wear, or a shelf that is
## owed a restock - which the market does the moment it is looked at, so "fresh
## stock" is true before the door is even opened.
static func _vendor() -> Array[Dictionary]:
	if VendorStock.is_due():
		return [_line("Tessel has fresh stock")]
	var beats: int = 0
	var first: String = ""
	for ware: Variant in VendorStock.wares():
		if not (ware is Dictionary):
			continue
		var piece: Dictionary = ware
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind == null or VendorStock.price(piece) > MetaState.marks:
			continue
		if Stash.points(piece, kind) > worn_points(int(kind.slot)):
			beats += 1
			if first.is_empty():
				first = slot_name(int(kind.slot)).to_lower()
	if beats > 0:
		return [_line("A %s on the shelf beats yours" % first, beats)]
	return []


## Any wood, ore and gem the Warden holds that the forge would take right now.
static func _smithy() -> Array[Dictionary]:
	var woods: Array[String] = []
	var ores: Array[String] = []
	var gems: Array[String] = []
	for id: Variant in MetaState.materials.keys():
		var kind: MaterialData = ContentDB.material(String(id))
		if kind == null or MetaState.material_count(String(id)) <= 0:
			continue
		match kind.kind:
			MaterialData.Kind.WOOD:
				woods.append(String(id))
			MaterialData.Kind.ORE:
				ores.append(String(id))
			MaterialData.Kind.GEM:
				gems.append(String(id))
	for wood: String in woods:
		for ore: String in ores:
			for gem: String in gems:
				if Forge.refusal(wood, ore, gem).is_empty():
					return [_line("Enough to forge a piece")]
	return []


static func _stable() -> Array[Dictionary]:
	for id: Variant in ContentDB.mounts.keys():
		var kind: MountData = ContentDB.mount(String(id))
		if kind == null or MetaState.owns_mount(String(id)):
			continue
		if MetaState.marks >= kind.price:
			return [_line("A horse you can afford")]
	return []


# --- Shared -------------------------------------------------------------------


## What the piece worn in a slot is worth, or zero with nothing there.
static func worn_points(slot: int) -> int:
	var worn: Dictionary = MetaState.equipped_piece(slot)
	if worn.is_empty():
		return 0
	return Stash.points(worn, ContentDB.gear(String(worn.get("kind", ""))))


static func slot_name(slot: int) -> String:
	var names: Array = GearData.Slot.keys()
	return String(names[slot]).capitalize() if slot >= 0 and slot < names.size() else "piece"
