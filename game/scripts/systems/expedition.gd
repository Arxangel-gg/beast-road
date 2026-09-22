class_name Expedition
extends RefCounted

## Successful extraction checkpoints the fortress and explicit run-local progress.
## Version 1 snapshots without the optional progress block remain readable.
## Wildlife and foliage regenerate; weather, hazards and earth wrath start clean.
## Account progression remains in MetaState and is never rolled back by a resume.

const VERSION: int = 1

## Explicit run-local checkpoint schema; account progression stays in MetaState.
const STATE_KEYS: Array[String] = [
	"segment",
	"terrain_id",
	"active_road_id",
	"active_road_difficulty_id",
	"beast_speed",
	"taken_omens",
	"pending_omens",
	"road_cards",
	"pending_road_cards",
	"pending_road_relics",
	"forks_open",
	"road_history",
	"kill_resource_remainder",
	"crossroad_rerolls_left",
	"blueprints",
	"market_trades_remaining",
	"merchant_visits",
	"market_service_act",
	"market_service_id",
	"town_max_hp",
	"building_tiers",
	"construction",
	"captives",
	"captive_assignments",
	"socketed_relics",
	"held_relics",
	"boss_cores",
	"traps",
	"barricades",
	"equipped_spells",
	"trained_discipline_nodes",
	"equipped_discipline_slots",
	"discipline_offers",
	"discipline_respec_uses",
	"bosses_felled",
	"raid_keys",
	"quartermaster_orders",
	"hero_hp",
	"hero_mana",
	"meals_eaten",
	"hero_wounds",
	"hero_max_wounds_bonus",
	"held_items",
	"ammo",
	"ranged_id",
	"ammo_id",
	"carried_eggs",
	"companion_sex",
	"spirit_called",
	"spirit_full_left",
	"spirit_upkeep_carry",
	"war_horn_uses",
	"command",
	"last_stand_used",
	"enemies_killed",
	"hero_deaths",
	"raids_completed",
	"chieftains_taken",
	"run_time_seconds",
	"planning_time_seconds",
	"resources_earned",
	"resources_spent",
	"currency_earned",
	"currency_spent",
	"towers_built",
	"traps_laid",
	"barricades_raised",
	"tower_upgrades",
	"towers_sold",
	"towers_lost",
	"town_damage_taken",
	"town_hits_taken",
	"peak_lane_pressure",
	"wave_archetype_counts",
	"command_earned",
	"command_orders_used",
	"wounds_suffered",
	"hearthmends_used",
	"kept",
	"seeds",
	"last_scar_offered", "last_scar_pending", "last_scar_active", "last_scar_resolved",
	"last_scar_failed", "last_scar_pursuer_spawned", "last_scar_pursuer_defeated",
	"last_scar_min_town_ratio", "mender_sparks_claimed_by_act", "mender_eligible_elites_by_act",
	"chronicle_host_progress", "raid_charge", "tower_haste_left",
	"tower_haste_scale", "pen_companion_fell",

]


static func _capture_progress() -> String:
	var progress: Dictionary = {}
	for key: String in STATE_KEYS:
		progress[key] = RunState.get(key)
	# Variant encoding preserves Vector2i map keys and typed arrays through JSON.
	return Marshalls.variant_to_base64(progress)


static func _restore_progress(encoded: String) -> void:
	if encoded.is_empty():
		return
	var decoded: Variant = Marshalls.base64_to_variant(encoded)
	if not decoded is Dictionary:
		return
	for key: String in STATE_KEYS:
		if decoded.has(key) and typeof(decoded[key]) == typeof(RunState.get(key)):
			RunState.set(key, decoded[key])



## **Take a photograph of the road as it stands.**
##
## Called at an extraction and nowhere else: a snapshot taken mid-wave would be a
## save-scum, and the whole tension of the crossroads is that what happened since
## the last one is at risk.
static func compose(field: Battlefield, name: String = "") -> Dictionary:
	var towers: Array[Dictionary] = []
	for key: Variant in RunState.towers:
		var anchor := key as Vector2i
		var entry: Dictionary = RunState.tower_entry(anchor)
		if entry.is_empty():
			continue
		towers.append({
			"x": anchor.x,
			"y": anchor.y,
			"kind": String(entry.get("tower_id", "")),
			"level": int(entry.get("level", 1)),
			"path": int(entry.get("path", TowerData.Path.NONE)),
			"priority": int(entry.get("target_priority", 0)),
			# **How hurt it is comes home with it.** Extraction that repaired
			# every emplacement would make the correct play "leave the moment
			# anything is damaged", and attrition would stop existing.
			#
			# Read off the live node, because tower health lives there and has
			# never been in `RunState` - it does not cross the wire either.
			"health": _health_of(field, anchor),
		})
	towers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return [int(a["x"]), int(a["y"])] < [int(b["x"]), int(b["y"])])
	var purse: Dictionary = {}
	for id: String in RunState.CURRENCIES:
		purse[id] = RunState.currency(id)
	return {
		"version": VERSION,
		"progress": _capture_progress(),
		"seed": RunState.run_seed,
		"act": RunState.act,
		"wave": RunState.wave_number,
		"distance": RunState.distance_travelled,
		"towers": towers,
		"purse": purse,
		"wall": RunState.town_hp / maxf(RunState.town_max_hp, 1.0),
		"momentum": RunState.momentum,
		"tier": RunState.tier_id,
		"name": name,
	}


## How hurt one standing tower is, or whole when there is no field to ask.
static func _health_of(field: Battlefield, anchor: Vector2i) -> float:
	if field == null or not field.has_method("tower_at_anchor"):
		return 1.0
	var built: Tower = field.tower_at_anchor(anchor)
	if built == null or not is_instance_valid(built):
		return 1.0
	return clampf(built.health_ratio(), 0.05, 1.0)


## Whether a stored expedition can be read into this build.
##
## A snapshot from a newer version, or one naming content that no longer exists,
## is refused rather than half-applied: half a fortress is worse than none,
## because the player cannot tell which half is missing.
static func is_readable(stored: Dictionary) -> bool:
	if stored.is_empty():
		return false
	if int(stored.get("version", 0)) != VERSION:
		return false
	if int(stored.get("wave", 0)) <= 0 or int(stored.get("act", 0)) <= 0:
		return false
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		if row == null or ContentDB.tower(String(row.get("kind", ""))) == null:
			return false
	return true


## **Put the road back down.**
##
## Applied to `RunState` *after* its reset and *before* the field is built, so
## the battlefield stands the towers up the same way it does for a guest being
## handed a host's world - through `_sync_towers`, which is the one path that
## makes a tower node. A second application path is a second thing that can
## drift.
static func apply(stored: Dictionary) -> bool:
	if not is_readable(stored):
		return false
	RunState.set_seed(int(stored.get("seed", 0)))
	_restore_progress(String(stored.get("progress", "")))
	RunState.wrath = 0.0
	RunState.ember = 0.0
	RunState.gale = 0.0
	RunState.tide = 0.0
	RunState.tremor = 0.0
	RunState.earth_events.clear()
	RunState.tower_health_restore.clear()
	RunState.act = int(stored.get("act", 1))
	RunState.wave_number = int(stored.get("wave", 1))
	RunState.distance_travelled = float(stored.get("distance", 0.0))
	RunState.momentum = float(stored.get("momentum", 0.0))
	RunState.towers.clear()
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		var anchor := Vector2i(int(row.get("x", 0)), int(row.get("y", 0)))
		RunState.towers[anchor] = {
			"tower_id": String(row.get("kind", "")),
			"level": int(row.get("level", 1)),
			"target_priority": int(row.get("priority", 0)),
			"path": int(row.get("path", TowerData.Path.NONE)),
		}
		# Waits for the node that is about to be built, which is the only place
		# tower health lives.
		RunState.tower_health_restore[anchor] = clampf(
			float(row.get("health", 1.0)), 0.05, 1.0)
	var purse: Dictionary = stored.get("purse", {}) as Dictionary
	for id: String in RunState.CURRENCIES:
		RunState.currencies[id] = int(purse.get(id, 0))
	RunState.tier_id = String(stored.get("tier", RunState.tier_id))
	# **The wall comes back as hurt as it was.** Same argument as the towers:
	# a wall that healed on extraction is a wall nobody ever has to mend.
	RunState.town_hp = RunState.town_max_hp \
		* clampf(float(stored.get("wall", 1.0)), 0.05, 1.0)
	# **The Warden comes back rested.** Owner, 2026-09-20: a resumed run
	# starts *"with full health and 0/3 wounds"*.
	#
	# The *front* keeps its scars - that is the attrition ruling, and it is why
	# the wall above comes back as worn as it was banked - but a person is not
	# a fortification. An expedition is an evening's break in one road, and a
	# Warden who stopped for the night on two wounds and came back on two would
	# be paying for having stopped. `-1.0` is the sentinel `hearthmend` already
	# uses for "fill on the next read", so this adds no second way to say full.
	RunState.hero_hp = -1.0
	RunState.hero_mana = -1.0
	RunState.hero_wounds = 0
	EventBus.hero_wounds_changed.emit(RunState.hero_wounds,
		RunState.max_wounds())
	Modifiers.rebuild()
	return true


## What the front looks like on a menu: "Act IV · Wave 37".
static func describe(stored: Dictionary) -> String:
	if not is_readable(stored):
		return ""
	var named: String = String(stored.get("name", ""))
	var where: String = "Act %d · Wave %d" % [
		int(stored.get("act", 1)), int(stored.get("wave", 1))]
	return where if named.is_empty() else "%s · %s" % [named, where]


## **What it costs to mend everything that is hurt**, as material ids to counts.
##
## Priced off each tower's own Gold cost and how much health it is missing, so a
## battered Bulwark costs more to put right than a scratched Barrow Stake, and a
## fortress that has been through a hundred waves is a real bill. Paid in wood
## and ore because the mines are the between-runs economy, and a fortress that
## weathers over a long campaign is the reason to work them.
##
## **Timber and ore rather than Gold** on purpose: Gold is a *run* currency and
## resets, so paying in it would mean mending was free the moment a new run
## started. Materials persist, which is what makes this a decision taken with
## something the player actually had to go and get.
static func repair_bill(stored: Dictionary) -> Dictionary:
	var bill: Dictionary = {}
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		if row == null:
			continue
		var missing: float = 1.0 - clampf(float(row.get("health", 1.0)), 0.0, 1.0)
		if missing <= 0.001:
			continue
		var kind: TowerData = ContentDB.tower(String(row.get("kind", "")))
		if kind == null:
			continue
		var worth: float = float(kind.build_cost()) \
			* float(maxi(int(row.get("level", 1)), 1))
		var units: int = maxi(1, int(round(worth * missing
			* Balance.FORTIFY_REPAIR_PER_HEALTH)))
		# Split between the two workable materials rather than one, so mending is
		# a reason to fell *and* to mine rather than to hoard whichever is
		# cheaper - the same argument the forge is priced under.
		bill[_cheapest(MaterialData.Kind.WOOD)] = int(bill.get(
			_cheapest(MaterialData.Kind.WOOD), 0)) + units
		bill[_cheapest(MaterialData.Kind.ORE)] = int(bill.get(
			_cheapest(MaterialData.Kind.ORE), 0)) + maxi(1, units / 2)
	# **And the gate, which this used to walk straight past.**
	#
	# The note on `wall_share` called that a real gap and said it was a
	# decision if the Hold should ever sell the repair. Owner, 2026-09-20:
	# it should - a resumed run is supposed to come back to a mended
	# fortress, *"so that its fires get put out and appears fully
	# repaired"*, and the wall is the thing a run is actually lost through.
	#
	# Priced off the wall's own health rather than off a tower's Gold, since
	# it has no build cost to take a share of.
	var gate: float = 1.0 - wall_share(stored)
	if gate > 0.001:
		var units: int = maxi(1, int(round(Balance.TOWN_MAX_HP * gate
			* Balance.FORTIFY_REPAIR_PER_HEALTH)))
		bill[_cheapest(MaterialData.Kind.WOOD)] = int(bill.get(
			_cheapest(MaterialData.Kind.WOOD), 0)) + units
		bill[_cheapest(MaterialData.Kind.ORE)] = int(bill.get(
			_cheapest(MaterialData.Kind.ORE), 0)) + maxi(1, units / 2)
	return bill


## The commonest material of a kind: mending wants the plentiful stuff, never
## the Duskstone somebody walked past three camps for.
static func _cheapest(kind: int) -> String:
	var best: MaterialData = null
	for value: Variant in ContentDB.materials.values():
		var one := value as MaterialData
		if one == null or one.kind != kind:
			continue
		if best == null or one.rarity < best.rarity \
				or (one.rarity == best.rarity and one.id < best.id):
			best = one
	return "" if best == null else best.id


## **Put the fortress right.** Every damaged emplacement, or none of them.
##
## All or nothing because a partial mend is a bill the player cannot read: they
## spend, and the fortress is still broken somewhere they cannot see until they
## are standing in it.
static func mend(stored: Dictionary) -> Dictionary:
	var out: Dictionary = stored.duplicate(true)
	var towers: Array = out.get("towers", []) as Array
	for index: int in towers.size():
		var row := towers[index] as Dictionary
		if row == null:
			continue
		row["health"] = 1.0
		towers[index] = row
	out["towers"] = towers
	# The gate too, which is what puts the fires out when the front is
	# picked back up: the town's damage stage is read off its health, and
	# `TownCore._rebuild_fires` is rebuilt rather than added to precisely so
	# that healing it clears them.
	out["wall"] = 1.0
	return out


## How many towers the fortress holds, and how many of them are hurt. For the
## menu and for the repair screen.
## **How much of the gate is still standing**, as a share.
##
## Separate from `fortifications` because that counts towers and the wall is not
## one - it is a single ratio on the snapshot, and it is the thing a run is lost
## through. It became worth showing on 2026-09-16, when turning for home started
## running a withdrawal the wall can be worn by: a Warden picking their front
## back up could not tell whether they were resuming behind a whole gate or a
## broken one until the road was already under them.
##
## **The Hold mends it now** (owner, 2026-09-20). This note used to say nothing
## between runs did, and named it a decision waiting to be taken; it has been.
## `repair_bill` prices the gate off its own health - it has no build cost to
## take a share of - and `mend` sets it whole, which is what puts the fires out
## when the front is picked back up. Inside a run it is still mended with Wood
## or through the Quartermaster.
static func wall_share(stored: Dictionary) -> float:
	return clampf(float(stored.get("wall", 1.0)), 0.0, 1.0)


## **Whether the front is worth mending, asked in one place.**
##
## Owner, 2026-09-22: the Hold should sell the repair *"if a successful
## extract is available to continue its run and it requires mending"*. Both
## halves of that were nearly right and the second was wrong: `repair_bill`
## has priced the gate since 2026-09-20, but both screens offered the button
## only when `fortifications().y` was above zero - which counts **towers**.
##
## So a front that came home behind a battered gate with every emplacement
## whole could not be mended from anywhere, while the purchase that would
## have mended it worked perfectly if it were ever reached. The bill is the
## question now, and it already knows about the wall.
static func needs_mending(stored: Dictionary) -> bool:
	return not repair_bill(stored).is_empty()


## What is hurt out there, for the button that offers to put it right. Named
## rather than counted, because "3 damaged" beside a whole board and a ruined
## gate is the same sentence that hid this for two days.
static func hurt_summary(stored: Dictionary) -> String:
	var towers: int = fortifications(stored).y
	var gate: float = 1.0 - wall_share(stored)
	var parts: PackedStringArray = []
	if towers > 0:
		parts.append("%d tower%s" % [towers, "" if towers == 1 else "s"])
	if gate > 0.001:
		parts.append("the gate at %d%%" % int(round(wall_share(stored) * 100.0)))
	return " and ".join(parts)


static func fortifications(stored: Dictionary) -> Vector2i:
	var standing: int = 0
	var hurt: int = 0
	for tower: Variant in (stored.get("towers", []) as Array):
		var row := tower as Dictionary
		if row == null:
			continue
		standing += 1
		if float(row.get("health", 1.0)) < 0.999:
			hurt += 1
	return Vector2i(standing, hurt)
