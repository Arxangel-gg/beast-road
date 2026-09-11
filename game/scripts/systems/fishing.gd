class_name Fishing
extends Node2D

## Ponds beside the roads, and the line you put in them.
##
## **The cost of fishing is standing still on a battlefield.** There is no key
## to press: walk to a pond, stop, and the line goes in; move, or take a blow,
## and it comes out. That is the whole design. A keypress would have made this a
## free action performed while backpedalling, and what makes a catch worth
## anything is that you chose to stop defending for six seconds to get it.
##
## It is also why fishing needs no input plumbing at all, and therefore works on
## a phone and on a controller the day it ships.
##
## **Where a pond may sit is the other half.** Off the roads - the owner's own
## framing - and far enough from one that nobody was going to build there
## anyway, so a pond never costs a tower slot that mattered. Derived from the
## grid rather than typed, exactly as `Treeline` derives its exclusions: the
## grid is the authority on where the roads are, so it is the authority on where
## water may stand.
##
## **Both machines grow the same ponds and neither is told about them.** The
## scatter is seeded from the run seed and the region, so a guest computes the
## identical water without a packet - the same treatment the relic offer and the
## omen offer get, and for the reason CLAUDE.md gives: a fact that can be
## relayed is a fact that can be subtly wrong.

## One pond per region, path derived from the region id.
const POND_ART_FORMAT: String = "res://art/battlefield/pond_%s.png"

## How the water reads in each region: how many attempts are made, and how big
## a pond is drawn. A waste has few and they are small; a jungle is wet. [TUNE]
const REGIONS: Dictionary = {
	"jungle": {"ponds": 6, "scale": Vector2(0.95, 1.25)},
	"desert": {"ponds": 3, "scale": Vector2(0.75, 1.0)},
	"snow": {"ponds": 4, "scale": Vector2(0.85, 1.15)},
}

## Where the pond's origin sits inside its art, as a fraction of height. Water
## lies flat, so it sorts by its own near edge rather than by its centre.
const SURFACE_ANCHOR: float = 0.82

var grid: BattleGrid = null

## The scope the ponds are in. Asked for the hero whose line this is and for
## somewhere to put the Food, rather than reaching up the tree for either.
var field: Node = null

## Where the ponds are parented: the battlefield's y-sorted entity layer, so a
## hero standing in front of one occludes it. Same reason `Treeline` and
## `Wildlife` do it.
var host: Node2D = null

## The pond records. Each is {sprite, at, stock, line, float_node}.
var _ponds: Array[Dictionary] = []

## The pond this machine's player currently has a line in, or -1.
var _fishing_at: int = -1
var _line_left: float = 0.0
var _line_total: float = 0.0
var _announce_clock: float = 0.0


func _ready() -> void:
	# A blow takes the line out of the water. Fishing is a thing you do instead
	# of fighting, not a thing you do while being hit.
	EventBus.hero_damaged.connect(_on_hero_damaged)


## Re-digs the ponds for the current region.
func scatter() -> void:
	for pond: Dictionary in _ponds:
		var sprite: Node = pond.get("sprite", null)
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
	_ponds.clear()
	_stop_fishing()

	var region: String = RunState.terrain_id
	var path: String = POND_ART_FORMAT % region
	if not ResourceLoader.exists(path) or grid == null:
		return
	var art: Texture2D = load(path) as Texture2D
	var shape: Dictionary = REGIONS.get(region, REGIONS["jungle"])

	# The run's own stream. Retuning how many ponds a jungle holds must not
	# rewrite what a seeded run's waves or gear do, which is what a named stream
	# is for; and because it *is* the run's seed, both machines dig the same
	# ponds without a word crossing the wire.
	var rng: RandomNumberGenerator = RunState.rng("fishing")
	var wanted: int = int(shape["ponds"])
	var span: Vector2 = shape["scale"] as Vector2
	for _attempt: int in Balance.FISHING_PLACEMENT_ATTEMPTS:
		if _ponds.size() >= wanted:
			break
		var at: Vector2 = _candidate(rng)
		if not _is_good_water(at):
			continue
		_dig(art, at, rng.randf_range(span.x, span.y))


## A point somewhere on the open ground inside the map.
##
## Inside the grid rather than beyond it, and that is load-bearing: the hero is
## clamped to the grid (`Battlefield` sets `bounds_extent`), so a pond outside
## it would be a thing the player can see and can never reach. The treeline can
## live out there because nobody has to walk to a tree.
##
## **Drawn on a radius rather than on a square, and pulled inward.** A uniform
## sample over the square puts most candidates near the rim simply because that
## is where most of the area is, and the road clearance then rejects everything
## else - so the first version put every pond in the outer band, a twelve-second
## walk from the town each way. Fishing is meant to cost the seconds you stand
## still, not the half-minute you spent getting there. Squaring the roll biases
## toward the middle, and the clearance still keeps water off the roads.
func _candidate(rng: RandomNumberGenerator) -> Vector2:
	var reach: float = BattleGrid.HALF_EXTENT - BattleGrid.TILE * 2.0
	var lean: float = rng.randf() * rng.randf()
	return Vector2.RIGHT.rotated(rng.randf() * TAU) * (lean * reach)


## Whether water may stand here.
##
## Three refusals, each derived from something that already knows the answer:
## open ground by the grid, clear of the roads by distance to the lane paths,
## and clear of the other ponds so two never overlap into one puddle.
func _is_good_water(at: Vector2) -> bool:
	if grid == null:
		return false
	if grid.cell_at(BattleGrid.world_to_tile(at)) != BattleGrid.Cell.OPEN:
		return false
	if at.length() < Balance.FISHING_TOWN_CLEARANCE:
		return false
	for path: Variant in grid.lane_paths:
		for point: Vector2 in (path as PackedVector2Array):
			if at.distance_to(point) < Balance.FISHING_ROAD_CLEARANCE:
				return false
	for pond: Dictionary in _ponds:
		if at.distance_to(pond["at"] as Vector2) < Balance.FISHING_POND_SPACING:
			return false
	return true


func _dig(art: Texture2D, at: Vector2, size: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.scale = Vector2.ONE * size
	sprite.global_position = at
	sprite.offset = Vector2(0.0,
		-float(art.get_height()) * (SURFACE_ANCHOR - 0.5))
	sprite.z_as_relative = false
	sprite.add_to_group(Graphics.FILTER_GROUP)
	(host if host != null else self).add_child(sprite)
	_ponds.append({
		"sprite": sprite,
		"at": at,
		"stock": Balance.FISHING_POND_STOCK,
		"float": null,
	})


func _process(delta: float) -> void:
	if _ponds.is_empty():
		return
	var angler: Node2D = _local_hero()
	if angler == null:
		_stop_fishing()
		return
	var standing: bool = _is_still(angler)
	var nearest: int = _pond_near(angler.global_position)
	if nearest < 0 or not standing:
		_stop_fishing()
		return
	if nearest != _fishing_at:
		_begin_fishing(nearest)
		return
	_line_left = maxf(_line_left - delta, 0.0)
	# Ten a second rather than sixty. A progress bar cannot show more, and the
	# bus does not need to carry what nothing can read.
	_announce_clock -= delta
	if _announce_clock <= 0.0:
		_announce_clock = 0.1
		EventBus.fishing_progress.emit(1.0 - _line_left / maxf(_line_total, 0.01))
	if _line_left <= 0.0:
		_land(nearest)


## Which pond is close enough to fish, or -1.
func _pond_near(at: Vector2) -> int:
	for index: int in _ponds.size():
		var pond: Dictionary = _ponds[index]
		if int(pond["stock"]) <= 0:
			continue
		if at.distance_to(pond["at"] as Vector2) <= Balance.FISHING_RADIUS:
			return index
	return -1


## Standing still enough to fish.
##
## Read off the body's own velocity rather than off the input, so being shoved,
## dashed or stepped on by the beast all count as moving - which is right: the
## line is out of the water in every one of those cases.
func _is_still(angler: Node2D) -> bool:
	var body := angler as CharacterBody2D
	if body == null:
		return true
	return body.velocity.length() <= Balance.FISHING_STILL_SPEED


func _begin_fishing(index: int) -> void:
	_stop_fishing()
	_fishing_at = index
	# What is on the line is decided when it goes in, not when it comes out, so
	# the wait is honest: a Legendary makes you stand there for half a minute
	# rather than rewarding a wait that was already over.
	var catch: FishData = _roll_fish()
	if catch == null:
		_fishing_at = -1
		return
	_ponds[index]["hooked"] = catch.id
	_line_total = catch.patience
	_line_left = catch.patience
	var pond: Dictionary = _ponds[index]
	var bob: Sprite2D = _float_marker(pond["at"] as Vector2)
	_ponds[index]["float"] = bob
	_announce_clock = 0.0
	EventBus.preparation_warning.emit("The line is in. Stay still.")
	EventBus.fishing_started.emit(_line_total)


func _stop_fishing() -> void:
	if _fishing_at >= 0 and _fishing_at < _ponds.size():
		var bob: Variant = _ponds[_fishing_at].get("float", null)
		if bob != null and is_instance_valid(bob as Node):
			(bob as Node).queue_free()
		_ponds[_fishing_at]["float"] = null
	if _fishing_at >= 0:
		EventBus.fishing_ended.emit()
	_fishing_at = -1
	_line_left = 0.0


## Picks what is on the line, by weight, among the fish that live here.
func _roll_fish() -> FishData:
	var eligible: Array[FishData] = []
	var total: float = 0.0
	for kind: FishData in ContentDB.fish_sorted():
		if not kind.lives_in(RunState.terrain_id):
			continue
		eligible.append(kind)
		total += maxf(kind.weight, 0.0)
	if eligible.is_empty() or total <= 0.0:
		return null
	var rng: RandomNumberGenerator = RunState.rng("fishing")
	var target: float = rng.randf() * total
	for kind: FishData in eligible:
		target -= maxf(kind.weight, 0.0)
		if target <= 0.0:
			return kind
	return eligible[eligible.size() - 1]


## The catch is landed: Food on the ground, the fish in the stash.
func _land(index: int) -> void:
	var pond: Dictionary = _ponds[index]
	var kind: FishData = ContentDB.fish(String(pond.get("hooked", "")))
	_stop_fishing()
	if kind == null:
		return
	_ponds[index]["stock"] = int(pond["stock"]) - 1
	var at: Vector2 = pond["at"] as Vector2
	if int(_ponds[index]["stock"]) <= 0:
		# Fished out, and it says so: the water goes flat and dull rather than
		# silently refusing a player who walks back to it.
		var sprite: Variant = _ponds[index].get("sprite", null)
		if sprite != null and is_instance_valid(sprite as Node):
			(sprite as Sprite2D).modulate = Balance.FISHING_SPENT_TINT

	# The fish is this player's, on this player's account, and needs no wire.
	MetaState.take_fish(kind.id)
	# The Food is run currency and the host owns that, so a guest asks rather
	# than paying itself - by id, never by amount, so a forged packet can name
	# a fish that does not exist and never a number that does not.
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.LAND_FISH, [kind.id])
	elif field != null and field.has_method("spawn_loot"):
		field.call("spawn_loot", RunState.FOOD, kind.food, at)

	Vfx.ring(at, Balance.FISHING_SPLASH_RADIUS, kind.rarity_colour(), 0.5, 5.0)
	Vfx.number(at, float(kind.food), Balance.LOOT_GLOW_COLOUR, false)
	Sfx.play("sfx_loot_collect")
	# Named out loud, through the strip that already carries "not enough Gold".
	# The splash and the Food number say *something* was landed; only this says
	# which fish, and which fish is the whole reason to have waited.
	EventBus.preparation_warning.emit("%s landed  ·  +%d Food"
		% [kind.display_name, kind.food])
	EventBus.fish_caught.emit(kind.id, kind.food)


## A float on the water, so a player can see the line is in.
func _float_marker(at: Vector2) -> Sprite2D:
	var path: String = Balance.LOOT_ART_FORMAT % RunState.FOOD
	if not ResourceLoader.exists(path):
		return null
	var bob := Sprite2D.new()
	bob.texture = load(path)
	var art: float = maxf(float(bob.texture.get_width()), 1.0)
	bob.scale = Vector2.ONE * (Balance.FISHING_FLOAT_SIZE / art)
	bob.global_position = at + Vector2(0.0, -Balance.FISHING_FLOAT_LIFT)
	bob.z_as_relative = false
	(host if host != null else self).add_child(bob)
	var tween: Tween = bob.create_tween().set_loops()
	tween.tween_property(bob, "position:y", bob.position.y - 6.0, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bob, "position:y", bob.position.y, 0.7) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return bob


## This machine's own player, not the partner's.
##
## The scope's `hero` rather than a scan of the heroes group, and the difference
## is the whole of co-op fishing: each angler fishes their own line into their
## own account's stash, so the partner standing in a pond must not put a fish in
## yours. `CoopHeroes` makes that distinction the same way.
func _local_hero() -> Node2D:
	if field == null:
		return null
	var who := field.get("hero") as Node2D
	if who == null or not who.has_method("is_alive"):
		return null
	return who if bool(who.call("is_alive")) else null


func _on_hero_damaged(_amount: float, _from: Vector2, _at: Vector2) -> void:
	_stop_fishing()


## How many ponds are dug, and how many still hold anything. For the gate.
func pond_count() -> int:
	return _ponds.size()


func stocked_count() -> int:
	var open: int = 0
	for pond: Dictionary in _ponds:
		if int(pond["stock"]) > 0:
			open += 1
	return open


## Where the ponds are, for the gate and for anything that needs to avoid them.
func pond_positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for pond: Dictionary in _ponds:
		out.append(pond["at"] as Vector2)
	return out


## Whether a line is in the water right now.
func is_fishing() -> bool:
	return _fishing_at >= 0
