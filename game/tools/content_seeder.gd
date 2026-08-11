class_name ContentSeeder
extends RefCounted

## One-time bootstrap that writes the content `.tres` files in /data.
##
## This exists so the first eighteen towers do not have to be typed out by hand.
## **After seeding, the `.tres` files are the source of truth** — this tool never
## overwrites an existing file, exactly like the placeholder generator, so
## re-running it after balancing will not undo the balancing.
##
## Adding content from here on means adding a `.tres`, not editing this file.
## The tables below are a starting point, not a registry.

var errors: PackedStringArray = []
var created: int = 0
var skipped: int = 0


func seed() -> Dictionary:
	errors = []
	created = 0
	skipped = 0
	_seed_towers()
	_seed_buildings()
	_seed_enemies()
	_seed_terrains()
	_seed_captives()
	_seed_relics()
	_seed_spells()
	return {"created": created, "skipped": skipped, "errors": errors.size()}


func _write(res: Resource, path: String) -> void:
	if FileAccess.file_exists(path):
		skipped += 1
		return
	var dir: String = path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var err: int = ResourceSaver.save(res, path)
	if err != OK:
		errors.append("save %s -> %d" % [path, err])
		return
	created += 1


func _tower(id: String, name: String, element: TowerData.Element, fields: Dictionary) -> void:
	var t := TowerData.new()
	t.id = id
	t.display_name = name
	t.element = element
	for key: String in fields:
		t.set(key, fields[key])
	_write(t, "res://data/towers/%s.tres" % id)


func _combo(id: String, name: String, a: TowerData.Element, b: TowerData.Element, desc: String, fields: Dictionary) -> void:
	var t := TowerData.new()
	t.id = id
	t.display_name = name
	t.description = desc
	t.is_combination = true
	t.parent_a = a
	t.parent_b = b
	t.element = a
	for key: String in fields:
		t.set(key, fields[key])
	_write(t, "res://data/towers/%s.tres" % id)


func _seed_towers() -> void:
	const F := TowerData.Element.FIRE
	const W := TowerData.Element.WATER
	const E := TowerData.Element.EARTH
	const A := TowerData.Element.AIR

	_tower("ember_spire", "Ember Spire", F, {"damage": 9.0, "attack_interval": 0.45})
	_tower("pyre_cannon", "Pyre Cannon", F, {"damage": 34.0, "attack_interval": 1.70, "aoe_radius": 110.0})
	_tower("rime_lance", "Rime Lance", W, {"damage": 16.0, "attack_interval": 0.95, "slow_factor": 0.60, "slow_duration": 1.5})
	_tower("hoarfrost_bell", "Hoarfrost Bell", W, {"damage": 0.0, "attack_interval": 1.0, "aoe_radius": 190.0, "slow_factor": 0.55, "slow_duration": 0.8})
	_tower("bulwark", "Bulwark", E, {"damage": 3.0, "attack_interval": 1.2, "taunts": true, "max_hp": 900.0})
	_tower("shard_thrower", "Shard Thrower", E, {"damage": 22.0, "attack_interval": 1.3, "extra_targets": 3})
	_tower("arc_coil", "Arc Coil", A, {"damage": 13.0, "attack_interval": 0.90, "extra_targets": 3})
	_tower("gale_turret", "Gale Turret", A, {"damage": 7.0, "attack_interval": 0.35, "knockback": 160.0})

	_combo("firestorm", "Firestorm", F, A, "Burn spreads to nearby enemies.",
		{"damage": 18.0, "attack_interval": 0.80, "aoe_radius": 90.0, "burn_dps": 12.0, "burn_duration": 3.0})
	_combo("magma", "Magma", F, E, "Leaves a damaging ground zone.",
		{"damage": 15.0, "attack_interval": 1.10, "ground_zone_dps": 22.0, "ground_zone_duration": 4.0})
	_combo("steam_burst", "Steam Burst", F, W, "Periodic area knockback.",
		{"damage": 20.0, "attack_interval": 1.50, "aoe_radius": 150.0, "knockback": 300.0})
	_combo("blizzard", "Blizzard", W, A, "Chain effects also slow.",
		{"damage": 14.0, "attack_interval": 0.85, "extra_targets": 4, "slow_factor": 0.50, "slow_duration": 2.0})
	_combo("glacier", "Glacier", W, E, "Chance to freeze; armours the lane.",
		{"damage": 12.0, "attack_interval": 1.20, "freeze_chance": 0.25, "lane_armour_bonus": 6.0})
	_combo("quake", "Quake", E, A, "Knockback ring on hit.",
		{"damage": 24.0, "attack_interval": 1.40, "aoe_radius": 130.0, "knockback": 380.0})
	_combo("conflagration", "Conflagration", F, F, "Heavy single target, deep burn.",
		{"damage": 30.0, "attack_interval": 0.70, "burn_dps": 20.0, "burn_duration": 3.0})
	_combo("deep_freeze", "Deep Freeze", W, W, "Long freezes, little damage.",
		{"damage": 8.0, "attack_interval": 1.30, "freeze_chance": 0.45, "slow_factor": 0.35, "slow_duration": 3.0})
	_combo("bastion", "Bastion", E, E, "Immovable. Armours the whole lane.",
		{"damage": 6.0, "attack_interval": 1.50, "taunts": true, "max_hp": 2000.0, "lane_armour_bonus": 12.0})
	_combo("tempest", "Tempest", A, A, "Fast chains across many targets.",
		{"damage": 16.0, "attack_interval": 0.50, "extra_targets": 6})


func _seed_buildings() -> void:
	var rows: Array = [
		["town_hall", "Town Hall", BuildingData.Effect.RELIC_SLOTS, [1.0, 2.0, 3.0], 0.0, true, false,
			"Relics only act while socketed here."],
		["forge", "Forge", BuildingData.Effect.BLUEPRINTS, [1.0, 2.0, 3.0], 0.0, false, false,
			"Unlocks and improves tower blueprints for this run."],
		["sanctum", "Sanctum", BuildingData.Effect.HERO_UPGRADE, [0.08, 0.16, 0.26], 72.0, false, false,
			"Hero max health, movement and spell cooldown."],
		["granary", "Granary", BuildingData.Effect.RESOURCE_RATE, [0.30, 0.65, 1.10], 144.0, false, false,
			"Raises the resource yield of every distance unit walked."],
		["scavenging_post", "Scavenging Post", BuildingData.Effect.CAPTIVE_LABOUR, [1.0, 2.0, 3.0], 216.0, false, true,
			"Work detail. Assigned prisoners raise the resource yield."],
		["watchtower", "Watchtower", BuildingData.Effect.WAVE_FORESIGHT, [1.0, 2.0, 3.0], 288.0, false, false,
			"Reveals the makeup of the next wave before it arrives."],
	]
	for row: Array in rows:
		var b := BuildingData.new()
		b.id = row[0]
		b.display_name = row[1]
		b.effect = row[2]
		var tiers: Array[float] = []
		for v: float in (row[3] as Array):
			tiers.append(v)
		b.effect_per_tier = tiers
		b.plot_angle_degrees = row[4]
		b.is_town_hall = row[5]
		b.accepts_captives = row[6]
		b.description = row[7]
		b.available_from_start = row[0] == "town_hall" or row[0] == "granary"
		_write(b, "res://data/buildings/%s.tres" % b.id)


func _seed_enemies() -> void:
	var breeds: Array = [
		["bogkin", "Bog-kin", 30.0, 8.0, 55.0, 1, "Waterlogged and slow, and there is always another."],
		["glassborn", "Glass-born", 18.0, 7.0, 105.0, 1, "Fast, brittle, and it hears you coming."],
		["steppehorde", "Steppe Horde", 22.0, 6.0, 78.0, 1, "Weak alone. They are never alone."],
	]
	for row: Array in breeds:
		var e := EnemyData.new()
		e.id = row[0]
		e.display_name = row[1]
		e.max_hp = row[2]
		e.contact_damage = row[3]
		e.move_speed = row[4]
		e.resource_value = row[5]
		e.description = row[6]
		e.category = EnemyData.Category.BREED
		_write(e, "res://data/enemies/%s.tres" % e.id)

	var elites: Array = [
		["warden", "Warden", 220.0, 14.0, 42.0, 0.85, "Shielded. Ignores knockback and soaks a lane."],
		["howler", "Howler", 120.0, 9.0, 60.0, 0.2, "Strengthens everything walking beside it."],
		["burrower", "Burrower", 160.0, 16.0, 70.0, 0.4, "Surfaces past the towers, already inside the ring."],
	]
	for row: Array in elites:
		var e := EnemyData.new()
		e.id = row[0]
		e.display_name = row[1]
		e.max_hp = row[2]
		e.contact_damage = row[3]
		e.move_speed = row[4]
		e.knockback_resistance = row[5]
		e.description = row[6]
		e.category = EnemyData.Category.ELITE
		e.body_radius = 30.0
		e.resource_value = 6
		e.raid_charge_value = 4.0
		_write(e, "res://data/enemies/%s.tres" % e.id)

	var bosses: Array = [
		["drowned_choir", "The Drowned Choir", 4200.0, 1],
		["mirrorfang", "Mirrorfang", 6400.0, 2],
		["rust_crown", "The Rust Crown", 9000.0, 3],
	]
	for row: Array in bosses:
		var e := EnemyData.new()
		e.id = row[0]
		e.display_name = row[1]
		e.max_hp = row[2]
		e.contact_damage = 26.0
		e.move_speed = 34.0
		e.knockback_resistance = 1.0
		e.body_radius = 90.0
		e.category = EnemyData.Category.BOSS
		e.resource_value = 120
		_write(e, "res://data/enemies/%s.tres" % e.id)


func _seed_terrains() -> void:
	var rows: Array = [
		["ashfen", "Ashfen Marsh", "bogkin", 1, TowerData.Element.FIRE, 0.25, 1.5, 0, 1.0, 1.0],
		["saltglass", "Saltglass Flats", "glassborn", 2, TowerData.Element.AIR, 0.20, 0.0, 1, 1.0, 0.9],
		["steppe", "Iron Steppe", "steppehorde", 3, TowerData.Element.EARTH, 0.20, 0.0, 0, 1.5, 0.75],
	]
	for row: Array in rows:
		var t := TerrainData.new()
		t.id = row[0]
		t.display_name = row[1]
		t.breed_id = row[2]
		t.act = row[3]
		t.favoured_element = row[4]
		t.favoured_element_bonus = row[5]
		t.enemy_hp_regen = row[6]
		t.bonus_chain_targets = row[7]
		t.wave_size_multiplier = row[8]
		t.wave_interval_multiplier = row[9]
		_write(t, "res://data/terrains/%s.tres" % t.id)


## The framing words live here and only here — see CaptiveData's header.
func _seed_captives() -> void:
	var rows: Array = [
		["bogkin", "Bog-kin Chieftain", 1.0],
		["glassborn", "Glass-born Chieftain", 1.2],
		["steppehorde", "Steppe Chieftain", 1.4],
	]
	for row: Array in rows:
		var c := CaptiveData.new()
		c.id = row[0]
		c.display_name = row[1]
		c.breed_id = row[0]
		c.work_multiplier = row[2]
		c.role_noun = "Captive"
		c.acquire_verb = "Bind"
		c.acquire_line = "%s is bound to the town and put to work." % c.display_name
		var allowed: Array[String] = ["scavenging_post"]
		c.allowed_building_ids = allowed
		_write(c, "res://data/captives/%s.tres" % c.id)


## Twenty relics plus the three boss cores (GDD §11). Effects are a key and a
## magnitude resolved by the relic system, so twenty relics stay twenty rows.
func _seed_relics() -> void:
	var rows: Array = [
		["01", "Cracked Bone Crown", "tower_damage", 0.10, "Towers strike harder."],
		["02", "Rusted Iron Heart", "town_max_hp", 150.0, "The walls hold longer."],
		["03", "Sealed Clay Jar", "resource_rate", 0.25, "More is scavenged from every mile."],
		["04", "Knotted Cord of Teeth", "hero_damage", 0.15, "The blade bites deeper."],
		["05", "Shattered Mirror Shard", "dash_cooldown", -0.6, "The step comes quicker."],
		["06", "Blackened Iron Key", "tower_range", 0.12, "Towers see further."],
		["07", "Wax-Sealed Scroll", "build_cost", -0.15, "Builders ask for less."],
		["08", "Horn Ring", "raid_charge", 0.30, "The horn calls louder."],
		["09", "Burnt Feather", "hero_speed", 0.12, "Lighter on the road."],
		["10", "River Stone Bound in Wire", "hero_max_hp", 30.0, "Harder to put down."],
		["11", "Ashen Reliquary", "burn_damage", 0.25, "Fire lingers."],
		["12", "Frost-Bitten Ledger", "slow_strength", 0.20, "Cold holds tighter."],
		["13", "Split Anvil", "tower_armour", 5.0, "Towers endure."],
		["14", "Coil of Copper", "chain_targets", 1.0, "Lightning reaches one more."],
		["15", "Grave Marker", "kill_resources", 0.5, "The dead pay better."],
		["16", "Salt-Crusted Idol", "beast_speed", 0.10, "The beast walks steadier."],
		["17", "Widow's Bell", "enemy_damage", -0.10, "They strike weakly."],
		["18", "Thresher's Chain", "knockback", 0.35, "Blows carry."],
		["19", "Pale Lantern", "wave_foresight", 1.0, "You see them coming."],
		["20", "Oathbreaker's Seal", "captive_output", 0.40, "The work detail yields more."],
	]
	for row: Array in rows:
		var r := RelicData.new()
		r.id = row[0]
		r.display_name = row[1]
		r.effect_id = row[2]
		r.effect_magnitude = row[3]
		r.description = row[4]
		_write(r, "res://data/relics/relic_%s.tres" % r.id)

	var cores: Array = [
		["core_drowned_choir", "Core of the Drowned Choir", 1, "tower_range", 0.10],
		["core_mirrorfang", "Core of Mirrorfang", 2, "dash_cooldown", -1.0],
		["core_rust_crown", "Core of the Rust Crown", 3, "tower_damage", 0.25],
	]
	for row: Array in cores:
		var r := RelicData.new()
		r.id = row[0]
		r.display_name = row[1]
		r.is_boss_core = true
		r.source_act = row[2]
		r.effect_id = row[3]
		r.effect_magnitude = row[4]
		r.description = "Always active. Never socketed."
		_write(r, "res://data/relics/%s.tres" % r.id)


## The eight hero spells (GDD §11), flavoured as scavenging incantations.
func _seed_spells() -> void:
	var rows: Array = [
		["rift_step", "Rift Step", 7.0, 0.0, 0.0, 0.0, 420.0, 0.0, false, "Step through a tear in the air."],
		["cinder_nova", "Cinder Nova", 9.0, 55.0, 190.0, 0.0, 0.0, 0.0, false, "A burst of ash and ember."],
		["bulwark_ward", "Bulwark Ward", 14.0, 0.0, 240.0, 6.0, 0.0, 0.0, false, "Shield one lane for a while."],
		["marrow_drain", "Marrow Drain", 8.0, 40.0, 110.0, 0.0, 0.0, 0.45, false, "Take back what it took."],
		["chain_hook", "Chain Hook", 6.0, 20.0, 0.0, 0.0, 360.0, 0.0, false, "Drag them to you."],
		["ash_veil", "Ash Veil", 16.0, 0.0, 0.0, 3.0, 0.0, 0.0, false, "Unseen and quick."],
		["tremor", "Tremor", 10.0, 35.0, 220.0, 0.0, 0.0, 0.0, false, "The ground throws them back."],
		["beasts_breath", "Beast's Breath", 18.0, 90.0, 320.0, 2.5, 0.0, 0.0, true, "Channel what the beast exhales."],
	]
	for row: Array in rows:
		var sp := SpellData.new()
		sp.id = row[0]
		sp.display_name = row[1]
		sp.cooldown = row[2]
		sp.damage = row[3]
		sp.effect_radius = row[4]
		sp.duration = row[5]
		sp.cast_range = row[6]
		sp.lifesteal = row[7]
		sp.is_channelled = row[8]
		sp.description = row[9]
		_write(sp, "res://data/spells/%s.tres" % sp.id)
