class_name Wayside
extends Node2D

## **Wayside encounters** (2026-09-25, `docs/IDEAS_REVIEW_2026-09-25.md` §4, §8).
##
## One thing on the outskirts an act, now and then, that stops and asks: an
## overturned cart, a cairn of offerings, a Warden's bones, an animal in a
## snare. It is walked up to, answered from the card, and gone.
##
## **What was missing was the choice, not the events.** The road already has a
## trail to follow, nests to rob, a blight, a savage for the over-farmer and a
## dragon overhead - every one of them something that happens. This is the one
## thing out there that asks, and it asks with doors the game already has:
## gear on the ground, a sighting toward a bond, the purse, a heal, a share of
## a level, the species' savage, the earth's anger. `_open_door` is the one
## place those are opened, so a choice cannot reach anything else.
##
## **Solo, for 1.0.** A shared road would have to put the choice to the party,
## which is `PartyEvents`' conversation and its own piece of work; until it is
## built an encounter is simply not laid on a networked road.
##
## **Placed the way the gathering nodes are**, from `Fishing.band_tiles`, clear
## of the gates, the camps, the plots, the nodes and the water - because the
## Interact press it answers is the same press all of those answer, and two
## prompts on one spot is one button meaning two things.
##
## **Nothing persists.** The encounter is the act's, re-laid with the region by
## `Battlefield.refresh_terrain`, and whether an act has one is rolled from the
## run's seed on dice of its own, so it moves no other roll.

const PROMPT_OWNER: StringName = &"wayside"

var grid: BattleGrid = null
var field: Node = null
var host: Node2D = null
## Ground already claimed: gates, camps, plots, gathering nodes.
var avoid: PackedVector2Array = []
## The ponds, as the rectangles they occupy.
var avoid_water: Array[Rect2] = []

## The encounter laid this act, or empty:
## {id, at, root, sprite, species, rarity, resolved, clock, glint_in, fade}
var _laid: Dictionary = {}
## Decoration's own dice, so a glint moves no roll that matters.
var _jitter: RandomNumberGenerator = RandomNumberGenerator.new()
var _prompt: String = ""
## A card is up for it, so it does not prompt again underneath the card.
var _asked: bool = false


func _ready() -> void:
	_jitter.randomize()
	EventBus.wayside_chosen.connect(_on_chosen)
	EventBus.wayside_left.connect(_on_left)


## Whether this road lays encounters at all: solo, not the Walk, and from the
## act the road first has something to ask.
func may_lay() -> bool:
	if Coop.is_networked() or RunState.walking:
		return false
	# Answered already, on this road: a resumed front does not ask twice.
	if RunState.wayside_answered.has(RunState.act):
		return false
	return RunState.act >= Balance.WAYSIDE_FIRST_ACT


## Lays this act's encounter, if the road has one.
func scatter() -> void:
	_clear()
	if grid == null or not may_lay():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("wayside:%d:%s" % [RunState.act, RunState.terrain_id])
	if rng.randf() >= Balance.WAYSIDE_CHANCE_PER_ACT:
		return
	var data: WaysideData = _choose(rng)
	if data == null:
		return
	var species: String = ""
	if data.scene == WaysideData.Scene.ANIMAL:
		species = _animal_of_the_region(rng)
		if species.is_empty():
			return
	var anchors: Array[Vector2i] = Fishing.band_tiles(grid, Balance.GATHER_EDGE_BAND)
	if anchors.is_empty():
		return
	for _attempt: int in Balance.WAYSIDE_PLACEMENT_ATTEMPTS:
		var tile: Vector2i = anchors[rng.randi_range(0, anchors.size() - 1)]
		var at: Vector2 = BattleGrid.tile_to_world(tile)
		if _is_good_ground(at):
			_lay(data, at, species, rng)
			return


## Which encounter, weighted, among those the act has reached.
func _choose(rng: RandomNumberGenerator) -> WaysideData:
	var pool: Array[WaysideData] = []
	var total: float = 0.0
	for id_value: Variant in ContentDB.wayside_ids():
		var data: WaysideData = ContentDB.wayside(String(id_value))
		if data == null or data.first_act > RunState.act or data.weight <= 0.0:
			continue
		pool.append(data)
		total += data.weight
	if pool.is_empty():
		return null
	var pick: float = rng.randf() * total
	for data: WaysideData in pool:
		pick -= data.weight
		if pick <= 0.0:
			return data
	return pool[pool.size() - 1]


## A harmless animal that belongs to this act's ground: something a Warden
## could stop for, never a predator and never a legend (a legend has a trail
## of its own). One the act lists is preferred; any harmless kind will do.
func _animal_of_the_region(rng: RandomNumberGenerator) -> String:
	var home: Array[String] = []
	var any: Array[String] = []
	for kind_value: Variant in ContentDB.wildlife_kinds.values():
		var kind := kind_value as WildlifeData
		if kind == null or kind.is_hostile() or kind.mythic or kind.art_top_down:
			continue
		if not ResourceLoader.exists(kind.get_sprite_path()):
			continue
		any.append(kind.id)
		if kind.acts.has(RunState.act):
			home.append(kind.id)
	var from: Array[String] = home if not home.is_empty() else any
	if from.is_empty():
		return ""
	from.sort()
	return from[rng.randi_range(0, from.size() - 1)]


## The region's hunter, for a prop encounter whose choice sets one loose.
func _predator_of_the_region() -> String:
	var home: Array[String] = []
	var any: Array[String] = []
	for kind_value: Variant in ContentDB.wildlife_kinds.values():
		var kind := kind_value as WildlifeData
		if kind == null or not kind.is_hostile() or kind.mythic:
			continue
		any.append(kind.id)
		if kind.acts.has(RunState.act):
			home.append(kind.id)
	var from: Array[String] = home if not home.is_empty() else any
	if from.is_empty():
		return ""
	from.sort()
	return from[0]


func _is_good_ground(at: Vector2) -> bool:
	var half := Vector2.ONE * BattleGrid.TILE
	var rim := Rect2(at - half, half * 2.0)
	if not Fishing.ground_is_open(grid, rim, Balance.GATHER_NODE_CLEARANCE_TILES):
		return false
	if at.length() < Balance.FISHING_TOWN_CLEARANCE:
		return false
	for spawn: Variant in grid.spawn_points:
		if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
			return false
	for lane: int in grid.ambush_points.size():
		for spawn: Variant in (grid.ambush_points[lane] as Array):
			if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
				return false
	for taken: Vector2 in avoid:
		if at.distance_to(taken) < Balance.WAYSIDE_SPACING:
			return false
	var wet: float = Balance.FISHING_RADIUS + Balance.FISHING_CAST_MAX * 0.5 \
		+ Balance.WAYSIDE_RADIUS
	for pond: Rect2 in avoid_water:
		var near := Vector2(clampf(at.x, pond.position.x, pond.end.x),
			clampf(at.y, pond.position.y, pond.end.y))
		if at.distance_to(near) < wet:
			return false
	return true


func _lay(data: WaysideData, at: Vector2, species: String, rng: RandomNumberGenerator) -> void:
	var root := Node2D.new()
	root.name = "Wayside"
	root.global_position = at
	var sprite: Sprite2D = null
	# The animal, when there is one: its own painting, a little dimmed - it is
	# hurt, or caught, and it is not going anywhere.
	if not species.is_empty():
		var kind: WildlifeData = ContentDB.wildlife_kinds.get(species, null) as WildlifeData
		var art: Texture2D = load(kind.get_sprite_path()) as Texture2D
		sprite = _standing(art, root)
		sprite.scale = Vector2.ONE * kind.scale
		sprite.modulate = Balance.WAYSIDE_ANIMAL_TINT
		sprite.flip_h = rng.randf() < 0.5
	# The prop: the whole scene for a PROP, the snare or the broken shaft at the
	# animal's feet for an ANIMAL.
	var path: String = data.get_sprite_path()
	if ResourceLoader.exists(path):
		var prop: Sprite2D = _standing(load(path) as Texture2D, root)
		if sprite == null:
			sprite = prop
		else:
			prop.position = Vector2(Balance.WAYSIDE_PROP_BESIDE, 6.0)
	if sprite == null:
		root.free()
		return
	var halo: GroundGlow = GroundGlow.lay(root, Balance.WAYSIDE_GLOW_COLOUR,
		Balance.WAYSIDE_GLOW_RADIUS, Balance.WAYSIDE_GLOW_ALPHA, 1.0, false)
	halo.z_index = -1
	(host if host != null else self).add_child(root)
	_laid = {
		"id": data.id, "at": at, "root": root, "sprite": sprite,
		"species": species, "rarity": data.animal_rarity,
		"resolved": false, "clock": 0.0, "fade": 0.0,
		"glint_in": rng.randf_range(Balance.WAYSIDE_GLINT_SECONDS.x, Balance.WAYSIDE_GLINT_SECONDS.y),
	}


## A sprite stood on its foot, like everything else on the field.
func _standing(art: Texture2D, parent: Node2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	sprite.add_to_group(Graphics.FILTER_GROUP)
	sprite.offset = Vector2(0.0, -float(art.get_height()) * 0.42)
	parent.add_child(sprite)
	return sprite


func _clear() -> void:
	var root: Node = _laid.get("root", null) as Node
	if root != null and is_instance_valid(root):
		root.queue_free()
	_laid = {}
	_asked = false
	_set_prompt("")


# --- Answering -------------------------------------------------------------------

func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"wayside", started)


func _process_measured(delta: float) -> void:
	if _laid.is_empty():
		return
	_tick_look(delta)
	if bool(_laid["resolved"]):
		return
	var who: Node2D = _local_hero()
	if who == null or _asked:
		_set_prompt("")
		return
	if who.global_position.distance_to(_laid["at"] as Vector2) > Balance.WAYSIDE_RADIUS:
		_set_prompt("")
		return
	var data: WaysideData = ContentDB.wayside(String(_laid["id"]))
	if data == null:
		return
	_set_prompt("Look  ·  %s" % title_of(data))
	var source := who.get("input") as HeroInput
	if source != null and source.pressed(HeroInput.BUTTON_INTERACT):
		_asked = true
		_set_prompt("")
		EventBus.wayside_reached.emit(data.id, title_of(data))


## The title, with the animal's name when the encounter has one.
func title_of(data: WaysideData) -> String:
	var species: String = String(_laid.get("species", ""))
	if species.is_empty():
		return data.title_for("")
	var kind: WildlifeData = ContentDB.wildlife_kinds.get(species, null) as WildlifeData
	return data.title_for(kind.display_name if kind != null else species)


## A choice was made on the card. Paid, then each half opened; a choice the
## purse cannot pay for is refused before anything moves.
func _on_chosen(encounter_id: String, choice_id: String) -> void:
	_asked = false
	if _laid.is_empty() or String(_laid["id"]) != encounter_id or bool(_laid["resolved"]):
		return
	var data: WaysideData = ContentDB.wayside(encounter_id)
	var choice: WaysideChoiceData = ContentDB.wayside_choice(choice_id)
	if data == null or choice == null or not data.choice_ids.has(choice_id):
		return
	if not RunState.spend_cost(choice.cost()):
		return
	_open_door(choice.boon, choice.boon_amount, choice.boon_currency)
	_open_door(choice.bane, choice.bane_amount, "")
	_laid["resolved"] = true
	if not RunState.wayside_answered.has(RunState.act):
		RunState.wayside_answered.append(RunState.act)
	_set_prompt("")
	EventBus.wayside_resolved.emit(encounter_id, choice_id)


func _on_left(_encounter_id: String) -> void:
	_asked = false


## **The one place a choice reaches the game**, through the door each effect
## already has. Nothing else a choice says can do anything.
func _open_door(effect: int, amount: float, currency: String) -> void:
	var at: Vector2 = _laid["at"] as Vector2
	match effect:
		WaysideChoiceData.Effect.CURRENCY:
			var paid: int = int(round(amount * Balance.kill_act_scale(RunState.act)))
			if paid > 0 and field != null and field.has_method("spawn_loot"):
				field.call("spawn_loot", currency, paid, at)
		WaysideChoiceData.Effect.GEAR:
			if field == null or not field.has_method("spawn_gear"):
				return
			var tier: CampaignTierData = RunState.tier()
			var tier_order: int = tier.order if tier != null else 0
			for _piece: int in maxi(int(amount), 1):
				var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order,
					RunState.rng("wayside"))
				if not piece.is_empty():
					field.call("spawn_gear", piece, at)
		WaysideChoiceData.Effect.SIGHTING:
			var species: String = String(_laid.get("species", ""))
			if species.is_empty():
				return
			for _sighting: int in maxi(int(amount), 1):
				MetaState.record_spirit_encounter(species, int(_laid["rarity"]), false)
		WaysideChoiceData.Effect.HEAL:
			var who: Node2D = _local_hero()
			var health: Health = who.get("health") as Health if who != null else null
			if health != null:
				health.heal(health.max_hp * clampf(amount, 0.0, 1.0))
		WaysideChoiceData.Effect.EXPERIENCE:
			var level_cost: float = RunState.hero_xp_for_level(RunState.hero_level)
			if not is_inf(level_cost):
				RunState.gain_hero_xp(level_cost * clampf(amount, 0.0, 1.0))
		WaysideChoiceData.Effect.SAVAGE:
			var species: String = String(_laid.get("species", ""))
			if species.is_empty():
				species = _predator_of_the_region()
			var animals: Node = field.call("wildlife_system") if field != null \
				and field.has_method("wildlife_system") else null
			if animals != null and not species.is_empty():
				animals.call("send_savage", species)
		WaysideChoiceData.Effect.WRATH:
			if amount > 0.0:
				EventBus.earth_offended.emit(amount)
		_:
			pass


func _local_hero() -> Node2D:
	if field == null:
		return null
	var who := field.get("hero") as Node2D
	if who == null or not who.has_method("is_alive"):
		return null
	return who if bool(who.call("is_alive")) else null


func _set_prompt(text: String) -> void:
	if text == _prompt and EventBus.prompt_owner() == PROMPT_OWNER:
		return
	if text.is_empty() and EventBus.prompt_owner() != PROMPT_OWNER:
		_prompt = ""
		return
	if not EventBus.claim_prompt(PROMPT_OWNER, text):
		return
	_prompt = text
	EventBus.interact_prompt.emit(text, "LOOK" if not text.is_empty() else "")


# --- The look ----------------------------------------------------------------------

## A slow breath while it waits, a glint now and then so it is found from across
## the road, and a fade once it has been answered. Drawn and never read.
func _tick_look(delta: float) -> void:
	var sprite := _laid.get("sprite", null) as Sprite2D
	var root := _laid.get("root", null) as Node2D
	if sprite == null or not is_instance_valid(sprite) or root == null or not is_instance_valid(root):
		return
	_laid["clock"] = float(_laid["clock"]) + delta
	if bool(_laid["resolved"]):
		_laid["fade"] = float(_laid["fade"]) + delta / maxf(Balance.WAYSIDE_FADE_SECONDS, 0.01)
		root.modulate.a = clampf(1.0 - float(_laid["fade"]), 0.0, 1.0)
		if float(_laid["fade"]) >= 1.0:
			root.queue_free()
			_laid = {}
		return
	var breath: float = 1.0 + sin(float(_laid["clock"]) * TAU / Balance.WAYSIDE_BREATH_SECONDS) \
		* Balance.WAYSIDE_BREATH
	sprite.scale.y = absf(sprite.scale.x) * breath
	_laid["glint_in"] = float(_laid["glint_in"]) - delta
	if float(_laid["glint_in"]) <= 0.0:
		_laid["glint_in"] = _jitter.randf_range(Balance.WAYSIDE_GLINT_SECONDS.x,
			Balance.WAYSIDE_GLINT_SECONDS.y)
		var top: Vector2 = root.global_position + sprite.offset * absf(sprite.scale.y)
		Vfx.spark(top, Balance.WAYSIDE_GLOW_COLOUR, 5, Vector2.UP, 90.0)


# --- For the minimap, the gate and the terrain ---------------------------------------

## Where the encounter stands, or `Vector2.INF` when the act has none.
func position_of() -> Vector2:
	if _laid.is_empty() or bool(_laid["resolved"]):
		return Vector2.INF
	return _laid["at"] as Vector2


func laid_id() -> String:
	return "" if _laid.is_empty() else String(_laid["id"])


func laid_species() -> String:
	return "" if _laid.is_empty() else String(_laid.get("species", ""))


func is_resolved() -> bool:
	return not _laid.is_empty() and bool(_laid["resolved"])


## For the gate: lay a particular encounter at a particular place, bypassing
## the act's roll and the ground search - the placement is tested separately,
## and a gate that waited on the act's dice would be a coin toss.
func lay_for_test(data: WaysideData, at: Vector2, species: String = "") -> void:
	_clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if data.scene == WaysideData.Scene.ANIMAL and species.is_empty():
		species = _animal_of_the_region(rng)
	_lay(data, at, species, rng)
