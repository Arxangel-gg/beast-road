class_name Camps
extends Node2D

## The raider camps on the outskirts, the fork barriers, and the war camp
## whose fall opens a dungeon (owner brief, 2026-09-12).
##
## Two camps branch off every road past the old edge: an easier one and a
## harder one. Their bodies are the region's own breeds at a scale - camp mode
## on `Enemy` - and they stay where they are: patrol the ground, go for a hero
## who comes close, follow only as far as the leash, and walk home healing when
## the hero leaves. Razing one pays run currency, gear rolled at a better tier
## order, and Shards, and the camp stands again on a timer. Raze both of a
## road's camps and the **fork** past them opens: the barriers fall, the road's
## waves now come from two spawns at the map's edge, and the **war camp**
## between the legs wakes. Raze that and a dungeon mouth opens on its ground.
##
## **The bound is that a camp pays what the road already pays.** Currency,
## gear on the same tables, Shards; the tier-order bonus a camp's gear rolls
## at is *odds*, not a new kind of thing, and nothing new persists -
## `MetaState.camps_razed` is a statistic. A camp body is an ordinary enemy
## in camp mode, so it is announced, mirrored and killed by everything that
## already handles enemies, and a guest sees the same bodies the host does.
##
## The host decides everything - who stands, who fell, when a camp respawns -
## and tells the guest the camp's *state* rather than its bodies, because the
## bodies already travel as enemies. The guest keeps its props, barriers and
## gates in step from that one fact.

enum State { LOCKED, ALIVE, RAZED, RESPAWNING }

const PROP_KINDS: Array[String] = ["tent", "fire", "palisade", "banner", "crates",
	"bones", "pot", "rack", "cage"]
const PROP_FORMAT: String = "res://art/battlefield/camp_%s.png"
const TOTEM_ART: String = "res://art/battlefield/war_totem.png"
const BARRIER_ART: String = "res://art/battlefield/fork_barrier.png"

var grid: BattleGrid = null
var field: Node = null
var host: Node2D = null

## One record per camp: {lane, tier, centre, rect, state, mobs, respawn_left,
## props, razed_once, totem}.
var _sites: Array[Dictionary] = []
## Per lane: the two barriers {body, sprite, at} while the fork is closed.
var _barriers: Array = []
var _rng := RandomNumberGenerator.new()
var _prop_art: Dictionary = {}


func _ready() -> void:
	EventBus.rift_ended.connect(_on_rift_ended)
	EventBus.coop_camp_state.connect(_on_coop_camp_state)
	EventBus.coop_fork_opened.connect(_on_coop_fork_opened)
	for kind: String in PROP_KINDS:
		var path: String = PROP_FORMAT % kind
		if ResourceLoader.exists(path):
			_prop_art[kind] = load(path)


# --- Laying the camps ----------------------------------------------------------

## Re-lays every camp for the current act: props, barriers, and - on the
## authority - the bodies. Forks close again with the act, because the
## outskirts are re-dug with the region.
func scatter() -> void:
	clear()
	if grid == null:
		return
	_rng.seed = RunState.run_seed * 1000003 + hash("camps:" + RunState.terrain_id)
	for lane: int in Balance.LANE_COUNT:
		RunState.forks_open[lane] = false
		grid.set_fork_open(lane, false)
	for camp: Dictionary in grid.camps:
		var site: Dictionary = {
			"lane": int(camp["lane"]),
			"tier": int(camp["tier"]),
			"centre": camp["centre"] as Vector2,
			"rect": camp["rect"] as Rect2,
			"state": State.LOCKED if int(camp["tier"]) == BattleGrid.CampTier.BARON else State.ALIVE,
			"mobs": [],
			"respawn_left": 0.0,
			"props": null,
			"razed_once": false,
			"totem": null,
		}
		_sites.append(site)
		_build_props(site)
	for lane: int in Balance.LANE_COUNT:
		_barriers.append(_build_barriers(lane))
	if not Coop.is_guest():
		for site: Dictionary in _sites:
			if int(site["state"]) == State.ALIVE:
				_stand_up(site)


## Takes everything down: props, barriers, bodies.
func clear() -> void:
	for site: Dictionary in _sites:
		_dismiss_mobs(site)
		var props: Node = site.get("props", null)
		if props != null and is_instance_valid(props):
			props.queue_free()
	_sites.clear()
	for pair: Variant in _barriers:
		for barrier: Dictionary in (pair as Array):
			for key: String in ["body", "sprite"]:
				var node: Node = barrier.get(key, null)
				if node != null and is_instance_valid(node):
					node.queue_free()
	_barriers.clear()


func _dismiss_mobs(site: Dictionary) -> void:
	for mob: Variant in (site["mobs"] as Array):
		var enemy := mob as Enemy
		if enemy != null and is_instance_valid(enemy) and not enemy.is_dying():
			enemy.dismiss()
	site["mobs"] = []


## The props on a camp's ground: a fire in the middle, the rest scattered
## inside the clearing, all sorted by their feet like everything else that
## stands on the field. The war camp gets its totem as well.
func _build_props(site: Dictionary) -> void:
	var root := Node2D.new()
	root.name = "Camp%d_%d" % [int(site["lane"]), int(site["tier"])]
	(host if host != null else self).add_child(root)
	site["props"] = root
	var rect: Rect2 = site["rect"] as Rect2
	var centre: Vector2 = site["centre"] as Vector2
	var fire: Texture2D = _prop_art.get("fire", null)
	var placed: Array[Vector2] = []
	if fire != null:
		_plant_prop(root, fire, centre + Vector2(0.0, 20.0))
		placed.append(centre)
	var kinds: Array[String] = []
	for kind: String in PROP_KINDS:
		if kind != "fire" and _prop_art.has(kind):
			kinds.append(kind)
	if not kinds.is_empty():
		var wanted: int = _rng.randi_range(Balance.CAMP_PROP_COUNT.x, Balance.CAMP_PROP_COUNT.y)
		var inset: float = Balance.CAMP_PROP_INSET
		for _attempt: int in wanted * 8:
			if placed.size() >= wanted + 1:
				break
			var at := Vector2(_rng.randf_range(rect.position.x + inset, rect.end.x - inset),
				_rng.randf_range(rect.position.y + inset, rect.end.y - inset))
			var crowded: bool = false
			for other: Vector2 in placed:
				if at.distance_to(other) < 76.0:
					crowded = true
					break
			if crowded:
				continue
			placed.append(at)
			_plant_prop(root, _prop_art[kinds[_rng.randi_range(0, kinds.size() - 1)]], at)
	if int(site["tier"]) == BattleGrid.CampTier.BARON and ResourceLoader.exists(TOTEM_ART):
		var totem: Sprite2D = _plant_prop(root, load(TOTEM_ART), centre + Vector2(0.0, -8.0))
		site["totem"] = totem
	_dress_props(site)


func _plant_prop(root: Node2D, art: Texture2D, at: Vector2) -> Sprite2D:
	var prop := Sprite2D.new()
	prop.texture = art
	prop.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	prop.add_to_group(Graphics.FILTER_GROUP)
	prop.offset = Foliage.foot_offset(art)
	prop.position = at
	prop.flip_h = _rng.randf() < 0.5
	root.add_child(prop)
	return prop


## Props read the camp's state: lit and whole while it stands, scorched while
## it is down, and dim while a war camp is still asleep.
func _dress_props(site: Dictionary) -> void:
	var root: Node2D = site.get("props", null) as Node2D
	if root == null or not is_instance_valid(root):
		return
	var tint: Color = Color.WHITE
	match int(site["state"]):
		State.LOCKED:
			tint = Color(0.5, 0.5, 0.58, 0.9)
		State.RAZED, State.RESPAWNING:
			tint = Color(0.42, 0.36, 0.34, 0.95)
		_:
			tint = Color.WHITE
	var tween: Tween = root.create_tween()
	tween.tween_property(root, "modulate", tint, Balance.CAMP_RAZE_FADE)


## The two barriers across a lane's legs: a body the hero cannot pass and the
## art that says why. Both go when the fork opens.
func _build_barriers(lane: int) -> Array:
	var out: Array = []
	var pair: Array = grid.barriers[lane]
	var art: Texture2D = load(BARRIER_ART) if ResourceLoader.exists(BARRIER_ART) else null
	for record: Dictionary in pair:
		var at: Vector2 = record["at"] as Vector2
		var along: Vector2 = record["along"] as Vector2
		var body := StaticBody2D.new()
		body.name = "ForkBarrier"
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = at
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		# Across the leg: the leg is three tiles wide, the body a touch wider.
		rect.size = Vector2(BattleGrid.TILE * 3.4, Balance.FORK_BARRIER_THICKNESS)
		shape.shape = rect
		shape.rotation = along.angle() + PI * 0.5
		body.add_child(shape)
		(host if host != null else self).add_child(body)
		var sprite: Sprite2D = null
		if art != null:
			sprite = Sprite2D.new()
			sprite.texture = art
			sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
			sprite.add_to_group(Graphics.FILTER_GROUP)
			sprite.offset = Foliage.foot_offset(art)
			sprite.position = at
			# The art lies across a north-south leg; an east-west leg turns it.
			if absf(along.x) > absf(along.y):
				sprite.rotation = PI * 0.5 * (1.0 if along.x > 0.0 else -1.0)
			(host if host != null else self).add_child(sprite)
		out.append({"body": body, "sprite": sprite, "at": at})
	return out


# --- Standing a camp up --------------------------------------------------------

## Puts a camp's bodies down. Authority only.
func _stand_up(site: Dictionary) -> void:
	_dismiss_mobs(site)
	site["state"] = State.ALIVE
	site["respawn_left"] = 0.0
	_dress_props(site)
	var tier: int = int(site["tier"])
	var lane: int = int(site["lane"])
	var centre: Vector2 = site["centre"] as Vector2
	var count: int = _rng.randi_range(Balance.CAMP_MOBS_MIN[tier], Balance.CAMP_MOBS_MAX[tier])
	var mobs: Array = []
	if tier == BattleGrid.CampTier.BARON:
		var champion: Enemy = _spawn_body(site, _pick_elite(), centre, Balance.CAMP_BARON_SCALE, true)
		if champion != null:
			mobs.append(champion)
	for index: int in count:
		var at: Vector2 = centre + Vector2.RIGHT.rotated(TAU * float(index) / float(count) + _rng.randf() * 0.6) \
			* _rng.randf_range(60.0, 110.0)
		var body: Enemy = _spawn_body(site, _pick_breed(tier), at, 1.0,
			_rng.randf() < Balance.CAMP_ELITE_CHANCE[tier] and tier != BattleGrid.CampTier.BARON)
		if body != null:
			mobs.append(body)
	site["mobs"] = mobs
	_announce(site)
	if bool(site["razed_once"]):
		EventBus.camp_respawned.emit(lane, tier)
		Vfx.ring(centre, 140.0, Color(1.0, 0.45, 0.3, 0.7), 0.6, 5.0)


func _spawn_body(site: Dictionary, data: EnemyData, at: Vector2, extra_scale: float,
		promoted: bool) -> Enemy:
	if data == null or field == null or not field.has_method("spawn_enemy"):
		return null
	var tier: int = int(site["tier"])
	var lane: int = int(site["lane"])
	var director: WaveDirector = field.get("wave_director") as WaveDirector
	var hp: float = Balance.CAMP_HP_SCALE[tier] * extra_scale
	var dmg: float = Balance.CAMP_DAMAGE_SCALE[tier]
	var spd: float = 1.0
	if director != null:
		hp *= director.act_hp_scale(lane)
		dmg *= director.act_damage_scale(lane)
		spd = director.act_speed_scale(lane)
	var rank: Enemy.Rank = Enemy.Rank.COMMON
	var worn: Array[EnemyAffixData] = []
	if promoted:
		rank = Enemy.Rank.CHAMPION if tier == BattleGrid.CampTier.BARON else Enemy.Rank.ELITE
		worn = _roll_affixes(2 if tier == BattleGrid.CampTier.BARON else 1)
	var enemy: Enemy = field.spawn_enemy(data, lane, hp, dmg, spd, false, rank, worn)
	if enemy == null:
		return null
	enemy.global_position = at
	enemy.make_camp_mob(site["centre"] as Vector2, Balance.CAMP_LEASH)
	return enemy


func _roll_affixes(count: int) -> Array[EnemyAffixData]:
	var pool: Array[EnemyAffixData] = []
	var ids: Array = ContentDB.affixes.keys()
	ids.sort()
	for id: Variant in ids:
		var affix := ContentDB.affixes[id] as EnemyAffixData
		if affix != null and affix.from_act <= RunState.act:
			pool.append(affix)
	var out: Array[EnemyAffixData] = []
	for _pick: int in mini(count, pool.size()):
		var index: int = _rng.randi_range(0, pool.size() - 1)
		out.append(pool[index])
		pool.remove_at(index)
	return out


## A body for a camp of this tier: the region's own breeds, with the harder
## camp leaning on the sturdier roles.
func _pick_breed(tier: int) -> EnemyData:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var pool: Array[EnemyData] = []
	if terrain != null:
		for id: String in terrain.enemy_ids:
			var data: EnemyData = ContentDB.enemy(id)
			if data != null and data.category == EnemyData.Category.BREED:
				pool.append(data)
	if pool.is_empty():
		pool = ContentDB.enemies_of_category(EnemyData.Category.BREED)
	if pool.is_empty():
		return null
	if tier >= BattleGrid.CampTier.HARD:
		var sturdy: Array[EnemyData] = []
		for data: EnemyData in pool:
			if data.role == EnemyData.Role.WARDEN or data.role == EnemyData.Role.VANGUARD:
				sturdy.append(data)
		if not sturdy.is_empty() and _rng.randf() < 0.7:
			return sturdy[_rng.randi_range(0, sturdy.size() - 1)]
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _pick_elite() -> EnemyData:
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	var pool: Array[EnemyData] = []
	if terrain != null:
		for id: String in terrain.elite_ids:
			var data: EnemyData = ContentDB.enemy(id)
			if data != null:
				pool.append(data)
	if pool.is_empty():
		pool = ContentDB.enemies_of_category(EnemyData.Category.ELITE)
	if pool.is_empty():
		return _pick_breed(BattleGrid.CampTier.HARD)
	return pool[_rng.randi_range(0, pool.size() - 1)]


# --- Living -------------------------------------------------------------------

func _process(delta: float) -> void:
	if Coop.is_guest() or _sites.is_empty():
		return
	for site: Dictionary in _sites:
		match int(site["state"]):
			State.ALIVE:
				_prune(site)
				if (site["mobs"] as Array).is_empty():
					_raze(site)
			State.RESPAWNING:
				site["respawn_left"] = float(site["respawn_left"]) - delta
				if float(site["respawn_left"]) <= 0.0:
					_stand_up(site)
			_:
				pass


func _prune(site: Dictionary) -> void:
	var living: Array = []
	for mob: Variant in (site["mobs"] as Array):
		# Validity before the cast: a body freed outright (a scope torn down,
		# a gate) is not an Enemy any more and casting it is an error.
		if mob == null or not is_instance_valid(mob):
			continue
		var enemy := mob as Enemy
		if enemy != null and not enemy.is_dying():
			living.append(enemy)
	site["mobs"] = living


## The camp fell. Pay, say so, and decide what it opened.
func _raze(site: Dictionary) -> void:
	var lane: int = int(site["lane"])
	var tier: int = int(site["tier"])
	var centre: Vector2 = site["centre"] as Vector2
	site["razed_once"] = true
	_pay(site)
	MetaState.camps_razed += 1
	Vfx.ring(centre, 170.0, Color(1.0, 0.7, 0.35, 0.85), 0.7, 6.0)
	Vfx.spark(centre, Color("ffb56a"), 22, Vector2.UP, 220.0)
	EventBus.camera_shake_requested.emit(6.0, 0.25)
	Sfx.play("sfx_camp_razed")
	EventBus.camp_cleared.emit(lane, tier)
	if tier == BattleGrid.CampTier.BARON:
		site["state"] = State.RAZED
		_dress_props(site)
		_announce(site)
		_open_dungeon(site)
		return
	site["state"] = State.RESPAWNING
	site["respawn_left"] = Balance.CAMP_RESPAWN_SECONDS[tier]
	_dress_props(site)
	_announce(site)
	EventBus.preparation_warning.emit("%s camp razed on the %s road" % [
		"Outer" if tier == BattleGrid.CampTier.EASY else "Inner", _lane_name(lane)])
	if not RunState.forks_open[lane] and _both_camps_fell(lane):
		_open_fork(lane)


func _both_camps_fell(lane: int) -> bool:
	for site: Dictionary in _sites:
		if int(site["lane"]) != lane or int(site["tier"]) == BattleGrid.CampTier.BARON:
			continue
		if not bool(site["razed_once"]):
			return false
	return true


## What a razed camp leaves on its ground.
func _pay(site: Dictionary) -> void:
	if field == null:
		return
	var tier: int = int(site["tier"])
	var centre: Vector2 = site["centre"] as Vector2
	var value: int = Balance.CAMP_CURRENCY[tier]
	var spread: RandomNumberGenerator = RunState.rng("gear")
	if field.has_method("spawn_loot"):
		field.spawn_loot(RunState.GOLD, int(round(value * 0.55)), centre + Vector2(-24.0, 0.0))
		field.spawn_loot(RunState.FOOD, int(round(value * 0.25)), centre + Vector2(24.0, 12.0))
		field.spawn_loot(RunState.STONE, int(round(value * 0.20)), centre + Vector2(0.0, -20.0))
	if field.has_method("spawn_gear"):
		var campaign: CampaignTierData = RunState.tier()
		var order: int = (campaign.order if campaign != null else 0) + Balance.CAMP_GEAR_TIER_BONUS[tier]
		for _piece: int in Balance.CAMP_GEAR_DROPS[tier]:
			var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), order, spread)
			if not piece.is_empty():
				field.spawn_gear(piece, centre + Vector2.RIGHT.rotated(spread.randf() * TAU)
					* spread.randf_range(30.0, 80.0))
	var shards: int = Balance.CAMP_SHARDS[tier]
	if shards > 0:
		MetaState.shards += shards
		MetaState.save_game()


## Both camps fell: the barriers come down, the road's waves come from the
## edge, and the war camp wakes.
func _open_fork(lane: int) -> void:
	RunState.forks_open[lane] = true
	if grid != null:
		grid.set_fork_open(lane, true)
	_fell_barriers(lane)
	for site: Dictionary in _sites:
		if int(site["lane"]) == lane and int(site["tier"]) == BattleGrid.CampTier.BARON \
				and int(site["state"]) == State.LOCKED:
			_stand_up(site)
	EventBus.fork_opened.emit(lane)
	EventBus.coop_fork_opened.emit(lane)
	EventBus.preparation_warning.emit("The %s road forks. Its war camp is awake." % _lane_name(lane))
	Sfx.play("sfx_fork_open")


func _fell_barriers(lane: int) -> void:
	if lane >= _barriers.size():
		return
	for barrier: Dictionary in (_barriers[lane] as Array):
		var body: Node = barrier.get("body", null)
		if body != null and is_instance_valid(body):
			body.queue_free()
		var sprite: Sprite2D = barrier.get("sprite", null) as Sprite2D
		var at: Vector2 = barrier["at"] as Vector2
		Vfx.dust(at, Color(0.55, 0.45, 0.35), 18, 120.0)
		Vfx.spark(at, Color("d9b27a"), 10, Vector2.UP, 160.0)
		if sprite != null and is_instance_valid(sprite):
			var fall: Tween = sprite.create_tween()
			fall.set_parallel(true)
			fall.tween_property(sprite, "modulate:a", 0.0, Balance.FORK_BARRIER_FALL)
			fall.tween_property(sprite, "scale:y", 0.35, Balance.FORK_BARRIER_FALL)
			fall.chain().tween_callback(sprite.queue_free)
	_barriers[lane] = []


## The war camp fell: a dungeon mouth opens where its totem stood.
func _open_dungeon(site: Dictionary) -> void:
	var lane: int = int(site["lane"])
	var centre: Vector2 = site["centre"] as Vector2
	if field != null and field.has_method("rift_gates"):
		var gates: RiftGates = field.rift_gates()
		if gates != null:
			gates.dig_at(RiftArena.Kind.DUNGEON, centre)
	var totem: Sprite2D = site.get("totem", null) as Sprite2D
	if totem != null and is_instance_valid(totem):
		var fall: Tween = totem.create_tween()
		fall.tween_property(totem, "modulate", Color(0.4, 0.35, 0.4, 0.6), 0.8)
	EventBus.war_camp_razed.emit(lane, centre)
	EventBus.preparation_warning.emit("The %s war camp fell. A dungeon opens on its ground." % _lane_name(lane))


## The dungeon closed: the war camp begins to stand again, after a while.
func _on_rift_ended(_reward: Dictionary) -> void:
	if Coop.is_guest():
		return
	for site: Dictionary in _sites:
		if int(site["tier"]) == BattleGrid.CampTier.BARON and int(site["state"]) == State.RAZED:
			site["state"] = State.RESPAWNING
			site["respawn_left"] = Balance.CAMP_RESPAWN_SECONDS[BattleGrid.CampTier.BARON] \
				+ Balance.CAMP_BARON_DUNGEON_GRACE
			_announce(site)


func _lane_name(lane: int) -> String:
	return ["north", "east", "south", "west"][clampi(lane, 0, 3)]


# --- Co-op ------------------------------------------------------------------

func _announce(site: Dictionary) -> void:
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_camp_state.emit(int(site["lane"]), int(site["tier"]), int(site["state"]))


func _on_coop_camp_state(lane: int, tier: int, state: int) -> void:
	if not Coop.is_guest():
		return
	for site: Dictionary in _sites:
		if int(site["lane"]) == lane and int(site["tier"]) == tier:
			site["state"] = state
			if state == State.RAZED or state == State.RESPAWNING:
				site["razed_once"] = true
			_dress_props(site)
			if tier == BattleGrid.CampTier.BARON and state == State.RAZED:
				_open_dungeon(site)
			return


func _on_coop_fork_opened(lane: int) -> void:
	if not Coop.is_guest():
		return
	RunState.forks_open[lane] = true
	if grid != null:
		grid.set_fork_open(lane, true)
	_fell_barriers(lane)
	EventBus.fork_opened.emit(lane)


# --- For the gate --------------------------------------------------------------

func site_count() -> int:
	return _sites.size()


func state_of(lane: int, tier: int) -> int:
	for site: Dictionary in _sites:
		if int(site["lane"]) == lane and int(site["tier"]) == tier:
			return int(site["state"])
	return -1


func mobs_of(lane: int, tier: int) -> Array:
	for site: Dictionary in _sites:
		if int(site["lane"]) == lane and int(site["tier"]) == tier:
			return site["mobs"] as Array
	return []


func barrier_count(lane: int) -> int:
	if lane < 0 or lane >= _barriers.size():
		return 0
	return (_barriers[lane] as Array).size()


## Forces a camp to respawn now. For the gate.
func stand_now(lane: int, tier: int) -> void:
	for site: Dictionary in _sites:
		if int(site["lane"]) == lane and int(site["tier"]) == tier:
			_stand_up(site)
