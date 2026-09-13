class_name Gathering
extends Node2D

## The trees and seams on the outskirts, and the work of getting something out
## of them.
##
## Owner brief, 2026-09-13: woodcutting and mining as crafts that persist across
## runs, nodes of different rarities with cooldowns, gems out of the ground -
## and, in the owner's own words, nodes that spawn **beyond the inner central
## square the paths make**, rarer the further from the city they are, and scaled
## by how practised the craft is.
##
## **Placed the way the ponds and the rift gates are**, and deliberately so: one
## rule for where the outskirts put things is one rule to get right.
## `Fishing.band_tiles` gives the open tiles beyond the authored core; a
## candidate is drawn from those rather than from a random point, because open
## ground out there is four corner pockets and a random throw lands in one about
## once in five hundred tries - which is how the first cut of the ponds dug
## nothing at all.
##
## **What is different here is the second and third gates on rarity.** A node
## may only be rolled at a spot far enough out (`GATHER_DISTANCE_BY_RARITY`) and
## by a hero practised enough to work it (`GATHER_LEVEL_SHARE_BY_RARITY` and the
## node's own `min_level`). So the ground near the city grows common wood
## forever, the good seams are out past the camps, and a Duskstone geode is not
## merely rare - it is somewhere a new Warden would not have found it and could
## not have broken it open.
##
## **Both machines dig the same nodes and neither is told about them.** Seeded
## from the run and the region like everything else out here, because a fact
## that can be relayed is a fact that can be subtly wrong. The craft levels are
## per-account and *not* shared, so a guest with a better Miner genuinely finds
## more at the same seam - that is their account, not a desync.

const FRAME_RATE: float = 5.0

var grid: BattleGrid = null
var field: Node = null
var host: Node2D = null
## Where the gates and the camps already are, so nothing is dug on top of them.
var avoid: PackedVector2Array = []

## **And the water, as rectangles rather than points.**
##
## A pond is a blob up to eight tiles across and fishing answers from its *rim*
## plus half a cast - about 270 units - so a node cleared by a fixed distance
## from the pond's centre can sit well inside that. Both systems read the same
## Interact press, so the hero would have started casting and chopping on one
## button. Measured from the rim, with both reaches added, the two prompts
## cannot overlap.
var avoid_water: Array[Rect2] = []

## {root, sprite, at, id, left, cooldown, frames, clock, swing, swinging}
var _nodes: Array[Dictionary] = []
var _near: int = -1
var _prompt: String = ""
var _prompt_button: String = ""
var _working: int = -1
var _swing_left: float = 0.0
var _roll: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_roll.randomize()


# --- Digging -------------------------------------------------------------------

## Re-scatters the nodes for the current region.
func scatter() -> void:
	for node: Dictionary in _nodes:
		var root: Node = node.get("root", null)
		if root != null and is_instance_valid(root):
			root.queue_free()
	_nodes.clear()
	_near = -1
	_working = -1
	_set_prompt("", "")
	if grid == null:
		return
	var anchors: Array[Vector2i] = Fishing.band_tiles(grid, Balance.GATHER_EDGE_BAND)
	if anchors.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("gather:" + RunState.terrain_id)
	var wanted: int = Balance.GATHER_NODES_PER_REGION
	for _attempt: int in Balance.GATHER_PLACEMENT_ATTEMPTS:
		if _nodes.size() >= wanted:
			break
		var tile: Vector2i = anchors[rng.randi_range(0, anchors.size() - 1)]
		var at: Vector2 = BattleGrid.tile_to_world(tile)
		if not _is_good_ground(at):
			continue
		var kind: GatherNodeData = _roll_node(at, rng)
		if kind == null:
			continue
		_dig(kind, at, rng)


## Which node may grow here, given how far out it is and how practised the
## crafts are.
##
## **The three gates, in one place**, so the rule is arithmetic rather than a
## chain of conditions spread across the scatter.
func _roll_node(at: Vector2, rng: RandomNumberGenerator) -> GatherNodeData:
	var reach: float = at.length() / maxf(BattleGrid.HALF_EXTENT, 1.0)
	var eligible: Array[GatherNodeData] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for kind: GatherNodeData in ContentDB.gather_nodes_sorted():
		var rarity: int = clampi(kind.rarity, 0, Balance.GATHER_DISTANCE_BY_RARITY.size() - 1)
		# Far enough out.
		if reach < Balance.GATHER_DISTANCE_BY_RARITY[rarity]:
			continue
		# And practised enough. The node's own floor and the rarity's share of
		# the ladder, whichever asks more.
		var level: int = MetaState.profession_level(kind.craft)
		var wanted: int = maxi(kind.min_level, 1 + int(round(
			Balance.GATHER_LEVEL_SHARE_BY_RARITY[rarity] * float(Balance.PROFESSION_MAX_LEVEL - 1))))
		if level < wanted:
			continue
		var weight: float = maxf(kind.weight, 0.0) * kind.region_weight(RunState.terrain_id)
		if weight <= 0.0:
			continue
		eligible.append(kind)
		weights.append(weight)
		total += weight
	if eligible.is_empty() or total <= 0.0:
		return null
	var target: float = rng.randf() * total
	for index: int in eligible.size():
		target -= weights[index]
		if target <= 0.0:
			return eligible[index]
	return eligible[eligible.size() - 1]


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
	for taken: Vector2 in avoid:
		if at.distance_to(taken) < Balance.GATHER_NODE_SPACING:
			return false
	# Far enough from the water that a press can only mean one thing. See
	# `avoid_water`: the reach is the pond's own, measured from its rim.
	var wet: float = Balance.FISHING_RADIUS + Balance.FISHING_CAST_MAX * 0.5 \
		+ Balance.GATHER_RADIUS
	for pond: Rect2 in avoid_water:
		var near := Vector2(clampf(at.x, pond.position.x, pond.end.x),
			clampf(at.y, pond.position.y, pond.end.y))
		if at.distance_to(near) < wet:
			return false
	for node: Dictionary in _nodes:
		if at.distance_to(node["at"] as Vector2) < Balance.GATHER_NODE_SPACING:
			return false
	return true


func _dig(kind: GatherNodeData, at: Vector2, rng: RandomNumberGenerator) -> void:
	var path: String = kind.get_sprite_path()
	if not ResourceLoader.exists(path):
		return
	var art: Texture2D = load(path) as Texture2D
	var root := Node2D.new()
	root.name = "GatherNode"
	root.global_position = at
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	sprite.add_to_group(Graphics.FILTER_GROUP)
	# Sorted by its foot, like everything else standing on the field.
	sprite.offset = Vector2(0.0, -float(art.get_height()) * 0.42)
	root.add_child(sprite)
	(host if host != null else self).add_child(root)
	_nodes.append({
		"root": root, "sprite": sprite, "at": at, "id": kind.id,
		"left": _swings_in(kind), "cooldown": 0.0,
		"frames": GameData.load_idle_frames(path), "clock": rng.randf() * 3.0,
	})


## How many swings a node holds for this hero. Practice is one of the two things
## it buys, and it is an honest one: a better woodcutter gets more out of the
## same tree rather than out of a better tree they were already going to find.
func _swings_in(kind: GatherNodeData) -> int:
	var level: int = MetaState.profession_level(kind.craft)
	var share: float = float(level - 1) / maxf(float(Balance.PROFESSION_MAX_LEVEL - 1), 1.0)
	return kind.swings + int(round(share * float(Balance.GATHER_SKILL_BONUS_SWINGS)))


# --- Working -------------------------------------------------------------------

func _process(delta: float) -> void:
	if _nodes.is_empty():
		return
	for index: int in _nodes.size():
		_tick_node(index, delta)
	var who: Node2D = _local_hero()
	if who == null:
		_stop_working()
		_set_prompt("", "")
		return
	var near: int = _node_near(who.global_position)
	_near = near
	if _working >= 0:
		_tick_swing(who, delta)
		return
	if near < 0:
		# **A worked-out seam is the other half of the report.** `_node_near`
		# skips a node on cooldown, so walking up to one you had emptied gave no
		# prompt at all and no reason - indistinguishable from standing in the
		# wrong place. It says what it is and when it is back instead.
		var resting: int = _resting_node_near(who.global_position)
		if resting >= 0:
			var spent_kind: GatherNodeData = ContentDB.gather_node(
				String(_nodes[resting]["id"]))
			if spent_kind != null:
				_set_prompt("%s  ·  worked out  ·  back in %s"
					% [spent_kind.display_name,
						_rest_left(float(_nodes[resting]["cooldown"]))], "")
				return
		_set_prompt("", "")
		return
	var kind: GatherNodeData = ContentDB.gather_node(String(_nodes[near]["id"]))
	if kind == null:
		return
	_set_prompt("%s  ·  %s" % [_verb(kind), kind.display_name], "WORK")
	var source := who.get("input") as HeroInput
	if source != null and source.pressed(HeroInput.BUTTON_INTERACT):
		_begin(near, kind)


## The swing itself. Stopped by walking away, exactly as a cast is - a gather is
## a thing you stop to do, which is what makes doing one during a wave a choice
## rather than free income.
func _tick_swing(who: Node2D, delta: float) -> void:
	if _working < 0 or _working >= _nodes.size():
		_stop_working()
		return
	var node: Dictionary = _nodes[_working]
	var kind: GatherNodeData = ContentDB.gather_node(String(node["id"]))
	if kind == null or int(node["left"]) <= 0:
		_stop_working()
		return
	if who.global_position.distance_to(node["at"] as Vector2) > Balance.GATHER_RADIUS * 1.2:
		_stop_working("You walked away from it.")
		return
	var own_speed: Vector2 = who.call("own_speed") if who.has_method("own_speed") \
		else (who.get("velocity") as Vector2)
	if own_speed.length() > Balance.GATHER_STILL_SPEED:
		_stop_working("You walked away from it.")
		return
	_swing_left -= delta
	if _swing_left > 0.0:
		return
	_land_a_swing(kind)


## One swing's worth out of the node.
func _land_a_swing(kind: GatherNodeData) -> void:
	var node: Dictionary = _nodes[_working]
	var level: int = MetaState.profession_level(kind.craft)
	var share: float = float(level - 1) / maxf(float(Balance.PROFESSION_MAX_LEVEL - 1), 1.0)
	var amount: int = kind.material_per_swing
	var lucky: bool = _roll.randf() < share * Balance.GATHER_SKILL_DOUBLE_CHANCE
	if lucky:
		amount *= 2
	MetaState.gain_material(kind.material_id, amount)
	var before: int = MetaState.profession_level(kind.craft)
	var after: int = MetaState.gain_profession_xp(kind.craft, kind.xp_per_swing)
	if after > before:
		EventBus.craft_levelled.emit(kind.craft, after)
	EventBus.gathered.emit(kind.material_id, amount)

	var at: Vector2 = node["at"] as Vector2
	# Chips come off *toward* whoever swung, not straight up: a spray that
	# ignores where the blow came from reads as the node doing something to
	# itself.
	var who: Node2D = _local_hero()
	var back: Vector2 = (who.global_position - at).normalized() \
		if who != null else Vector2.UP
	Vfx.spark(at, _spark_colour(kind),
		Balance.GATHER_LUCKY_SPARKS if lucky else 7, back, 190.0)
	Sfx.play("sfx_hit_stone", -5.0)
	EventBus.camera_impact.emit(at, Balance.GATHER_LUCKY_SHAKE if lucky \
		else Balance.GATHER_SWING_SHAKE)
	_recoil(_working, -back)
	_say_the_take(at, kind, amount, lucky)

	_nodes[_working]["left"] = int(node["left"]) - 1
	var left: int = int(_nodes[_working]["left"])
	if left <= 0:
		_work_it_out(kind)
		return
	_swing_left = _swing_seconds(kind)
	_swing_the_hero(_working)
	# What is left, while the work is happening. A seam that is one swing from
	# empty should not be a surprise.
	_set_prompt("%s  ·  %s  ·  %d left" % [_verb(kind), kind.display_name, left],
		"")


## **What the swing paid, said out loud.**
##
## `EventBus.gathered` has carried this since the crafts were built and nothing
## ever listened, so every swing looked the same as every other - which is the
## whole of the owner's report. The word floats off the node in the material's
## own colour, and a swing the craft doubled says so in a bigger one: that roll
## is the only place practice is visible, and it was invisible.
func _say_the_take(at: Vector2, kind: GatherNodeData, amount: int,
		lucky: bool) -> void:
	var material: MaterialData = ContentDB.material(kind.material_id)
	var named: String = material.display_name if material != null \
		else kind.display_name
	var colour: Color = _spark_colour(kind)
	if lucky:
		# Brightened rather than recoloured: it has to read as the same material
		# struck well, not as a different material.
		colour = colour.lerp(Color.WHITE, 0.35)
	Vfx.word(at + Vector2(0.0, -26.0), "+%d %s" % [amount, named], colour,
		Balance.GATHER_LUCKY_WORD_SIZE if lucky else Balance.GATHER_WORD_SIZE)
	if lucky:
		Vfx.ring(at, 64.0, Color(colour, 0.7), 0.32, 3.0)
		Sfx.play("sfx_relic_socket", -7.0)


## The node is spent. It goes grey and comes back on its own clock, so a region
## is not a fixed budget the player empties in Act I and walks past for nine
## more acts.
func _work_it_out(kind: GatherNodeData) -> void:
	var index: int = _working
	var rarity: int = clampi(kind.rarity, 0, Balance.GATHER_RESPAWN_SECONDS.size() - 1)
	_nodes[index]["cooldown"] = Balance.GATHER_RESPAWN_SECONDS[rarity]
	var at: Vector2 = _nodes[index]["at"] as Vector2
	Vfx.dust(at, Color(0.44, 0.38, 0.3), 12, 60.0)
	Vfx.ring(at, 70.0, Color(_spark_colour(kind), 0.6), 0.35, 4.0)
	# Said on the node as well as in the log: the log is at the edge of the
	# screen and the player is looking at the seam they just emptied.
	Vfx.word(at + Vector2(0.0, -46.0), "Worked out", Color(0.78, 0.74, 0.66), 22)
	_fell(index, kind)
	_stop_working("%s is worked out." % kind.display_name)


func _begin(index: int, kind: GatherNodeData) -> void:
	_working = index
	_swing_left = _swing_seconds(kind)
	_set_prompt("", "")
	Sfx.play("sfx_ui_click", -8.0)
	_swing_the_hero(index)


## The hero visibly works, facing what they are working, once per swing and in
## time with it. See `Hero.play_work_swing` for why it is the heavy swing sheet.
func _swing_the_hero(index: int) -> void:
	var who: Node2D = _local_hero()
	if who == null or not who.has_method("play_work_swing") 			or index < 0 or index >= _nodes.size():
		return
	who.call("play_work_swing", _nodes[index]["at"] as Vector2)


func _stop_working(why: String = "") -> void:
	if _working < 0:
		return
	_working = -1
	_swing_left = 0.0
	if not why.is_empty():
		EventBus.gather_stopped.emit(why)


## How long one swing takes. The craft's only other reward, and it is time
## rather than power.
func _swing_seconds(kind: GatherNodeData) -> float:
	var level: int = MetaState.profession_level(kind.craft)
	var share: float = float(level - 1) / maxf(float(Balance.PROFESSION_MAX_LEVEL - 1), 1.0)
	return kind.swing_seconds * lerpf(1.0, Balance.GATHER_SKILL_SPEED_FLOOR, share)


func _tick_node(index: int, delta: float) -> void:
	var node: Dictionary = _nodes[index]
	var sprite: Sprite2D = node["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var cooldown: float = float(node["cooldown"])
	if cooldown > 0.0:
		cooldown = maxf(cooldown - delta, 0.0)
		_nodes[index]["cooldown"] = cooldown
		if cooldown <= 0.0:
			var kind: GatherNodeData = ContentDB.gather_node(String(node["id"]))
			if kind != null:
				_nodes[index]["left"] = _swings_in(kind)
				Vfx.ring(node["at"] as Vector2, 60.0, Color(0.7, 0.85, 0.6, 0.6), 0.5, 3.0)
	var spent: bool = float(_nodes[index]["cooldown"]) > 0.0
	var clock: float = float(node["clock"]) + delta
	_nodes[index]["clock"] = clock
	var frames: Array[Texture2D] = node["frames"]
	if frames.size() > 1 and not spent:
		sprite.texture = frames[int(clock * FRAME_RATE) % frames.size()]
	# A node that has come back stands up again: the fall left it rotated,
	# dropped and transparent, and nothing else would ever undo that.
	# The foot anchor lives in `sprite.offset`, so a standing node's position is
	# zero and anything else is something the recoil or the fall did to it.
	if not spent and float(node.get("recoil", 0.0)) <= 0.0 \
			and (not is_zero_approx(sprite.rotation) or not sprite.position.is_zero_approx()):
		sprite.rotation = 0.0
		sprite.position = Vector2.ZERO
	sprite.modulate = Color(0.42, 0.44, 0.42, 0.75) if spent else Color.WHITE

	# The recoil, ticked here because this is the clock the node already has.
	# A half sine over its own life: away hard, back soft.
	var recoil: float = float(node.get("recoil", 0.0))
	if recoil <= 0.0:
		return
	recoil = maxf(recoil - delta, 0.0)
	_nodes[index]["recoil"] = recoil
	var share: float = recoil / maxf(Balance.GATHER_RECOIL_SECONDS, 0.001)
	var push: float = sin(share * PI) * Balance.GATHER_RECOIL
	var away: Vector2 = node.get("recoil_from", Vector2.RIGHT)
	# Mostly sideways: a blow shoves a trunk off its line far more than it
	# lifts it, and a node that bobbed vertically would read as floating.
	sprite.position = Vector2(away.x * push, away.y * push * 0.4)
	sprite.rotation = deg_to_rad(Balance.GATHER_RECOIL_TILT) * sin(share * PI) \
		* (-1.0 if away.x < 0.0 else 1.0)


func _node_near(at: Vector2) -> int:
	var best: int = -1
	var nearest: float = INF
	for index: int in _nodes.size():
		var node: Dictionary = _nodes[index]
		if float(node["cooldown"]) > 0.0 or int(node["left"]) <= 0:
			continue
		var gap: float = at.distance_to(node["at"] as Vector2)
		if gap <= Balance.GATHER_RADIUS and gap < nearest:
			nearest = gap
			best = index
	return best


## The nearest node that is resting, for the prompt that explains itself.
func _resting_node_near(at: Vector2) -> int:
	var best: int = -1
	var nearest: float = INF
	for index: int in _nodes.size():
		var node: Dictionary = _nodes[index]
		if float(node["cooldown"]) <= 0.0:
			continue
		var gap: float = at.distance_to(node["at"] as Vector2)
		if gap <= Balance.GATHER_RADIUS and gap < nearest:
			nearest = gap
			best = index
	return best


## A rest read as minutes and seconds rather than as a number of seconds.
func _rest_left(seconds: float) -> String:
	var whole: int = int(ceil(maxf(seconds, 0.0)))
	if whole < 60:
		return "%ds" % whole
	return "%dm %02ds" % [whole / 60, whole % 60]


func _verb(kind: GatherNodeData) -> String:
	return "Chop" if kind.craft == "woodcutter" else "Mine"


func _spark_colour(kind: GatherNodeData) -> Color:
	var material: MaterialData = ContentDB.material(kind.material_id)
	if material == null:
		return Color(0.8, 0.7, 0.5)
	match material.kind:
		MaterialData.Kind.WOOD:
			return Color(0.72, 0.52, 0.32)
		MaterialData.Kind.ORE:
			return Color(0.78, 0.72, 0.66)
		_:
			return Color(0.9, 0.72, 0.38)


func _local_hero() -> Node2D:
	if field == null:
		return null
	var who := field.get("hero") as Node2D
	if who == null or not who.has_method("is_alive"):
		return null
	return who if bool(who.call("is_alive")) else null


func _set_prompt(text: String, button: String) -> void:
	if text == _prompt and button == _prompt_button:
		return
	_prompt = text
	_prompt_button = button
	EventBus.interact_prompt.emit(text, button)


# --- For the minimap, and for the gate ------------------------------------------

func node_count() -> int:
	return _nodes.size()


func node_positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for node: Dictionary in _nodes:
		out.append(node["at"] as Vector2)
	return out


func node_ids() -> Array[String]:
	var out: Array[String] = []
	for node: Dictionary in _nodes:
		out.append(String(node["id"]))
	return out


## Whether a node is worked out right now, for the map and the gate.
func node_is_spent(index: int) -> bool:
	if index < 0 or index >= _nodes.size():
		return true
	return float(_nodes[index]["cooldown"]) > 0.0 or int(_nodes[index]["left"]) <= 0


## Whether the hero is mid-swing, so the field can play the right pose.
func is_working() -> bool:
	return _working >= 0


# --- What a struck node does (2026-09-13) --------------------------------------

## One blow's worth of recoil, away from whoever swung.
##
## Written onto the node's own entry rather than tweened, because a tween on a
## sprite that the respawn is about to reset is a tween nobody cancels - and the
## node's clock is already being ticked every frame in `_tick_node`.
func _recoil(index: int, away: Vector2) -> void:
	if index < 0 or index >= _nodes.size():
		return
	_nodes[index]["recoil"] = Balance.GATHER_RECOIL_SECONDS
	_nodes[index]["recoil_from"] = away


## The node goes over. A tree falls; a seam drops and crumbles.
##
## The direction is the one the blow came from, so a tree falls away from the
## axe rather than in whatever direction the code happened to pick.
func _fell(index: int, kind: GatherNodeData) -> void:
	if index < 0 or index >= _nodes.size():
		return
	var sprite: Sprite2D = _nodes[index]["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var away: Vector2 = _nodes[index].get("recoil_from", Vector2.RIGHT)
	var timber: bool = kind.craft == "woodcutter"
	var at: Vector2 = _nodes[index]["at"] as Vector2
	var tween: Tween = sprite.create_tween()
	tween.set_parallel(true)
	if timber:
		# Pivoted at the foot, because a tree hinges where it is rooted. The
		# sprite is offset up by its own height already, so its origin *is* the
		# foot and the rotation needs no re-anchoring.
		var lean: float = deg_to_rad(Balance.GATHER_FALL_DEGREES) \
			* (-1.0 if away.x < 0.0 else 1.0)
		tween.tween_property(sprite, "rotation", lean, Balance.GATHER_FALL_SECONDS) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	else:
		tween.tween_property(sprite, "position",
			sprite.position + Vector2(0.0, Balance.GATHER_CRUMBLE_DROP),
			Balance.GATHER_FALL_SECONDS * 0.5).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(sprite, "modulate:a", 0.0, Balance.GATHER_FALL_SECONDS)
	Sfx.play("sfx_tower_upgrade" if timber else "sfx_hit_stone", -6.0)
	Vfx.dust(at, Color(0.5, 0.44, 0.34), 16, 90.0)
	EventBus.camera_impact.emit(at, 0.34)
