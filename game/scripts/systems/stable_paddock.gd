class_name StablePaddock
extends Node2D

const ActorPolishScript = preload("res://scripts/systems/actor_polish.gd")

## **The stable's paddock, with horses in it** (owner brief, 2026-09-17).
##
## The owner's words: *"I want the most aesthetic solution in The Hold for it
## like a stable or something and animated horses with AI and a vendor at it."*
##
## This is `PenYard`'s idea applied to the stock rather than to the collection:
## one sprite per horse, **each with its own clock**, grazing where it stands,
## wandering somewhere new, tossing its head - so a paddock of five is never
## five copies of one animation. That is the whole reason to draw a paddock
## rather than list one, and the gate drives forty seconds and refuses a yard
## where every animal is doing the same thing.
##
## **It is a picture and nothing else.** It reads `ContentDB.mounts_sorted()` and
## `MetaState.mounts` to decide what is standing there and which one is the
## Warden's; it writes nothing, rolls no die that matters, and is read by
## nothing. Buying and saddling happen through `MetaState`'s own doors, which is
## the rule `PenScreen` follows for the same reason - a screen that had its own
## opinion about the price would be a second place for the price to live.
##
## **A horse the player owns stands differently**, and that is the only piece of
## information in the picture: the saddled one waits at the rail nearest the
## gate rather than out in the field. A plate would be a label on an animal; a
## horse standing where a horse waits for somebody is the place saying it.

## **The fallback lives on `MountRig` now**, not here. A missing painting has
## to degrade to a stiller picture rather than to a hole in the Hold
## (CLAUDE.md §4), and having two places decide what that picture is would be
## two answers to one question - which is how a paddock ends up drawing a
## different animal from the one the Warden rides.

## Whose authored coat spreads a paddock horse is dressed from. See `_stand`.
const COAT_SOURCE: String = "steppe_horse"

## How far apart two horses try to settle.
const SPACING: float = 150.0

## The earth the Hold is painted on, so the paddock is a patch of the same
## ground rather than a shape laid over it. Read by name rather than handed
## in, because a paddock with a different floor from the yard around it is
## exactly the pane of glass this replaced.
const TURF_ART: String = "res://art/terrain/terrain_jungle.png"

var _turf: Texture2D = null

## Whether this is the only floor under the horses. False in the Hold, where
## the yard behind it is the ground and this only wears it.
var _standing: bool = true
var _stage: Vector2 = Balance.STABLE_PADDOCK
var _horses: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	name = "StablePaddock"
	y_sort_enabled = true
	_rng.seed = hash("hold-stable")
	if ResourceLoader.exists(TURF_ART):
		_turf = load(TURF_ART) as Texture2D
	refresh()
	set_process(true)


## How big the paddock is. Set before or after `refresh`; either re-lays it.
## Told that the ground it is drawn on belongs to somebody else, so it wears
## that rather than painting over it. See `_draw`.
func stand_in_a_yard(soil: Texture2D) -> void:
	_standing = false
	if soil != null:
		_turf = soil
	queue_redraw()


func set_stage(size: Vector2) -> void:
	_stage = size
	_settle_places()


## Stands up the stock.
##
## **Seeded off each horse's own id**, so re-opening the Hold puts every animal
## back where it was rather than shuffling the paddock each visit - a field that
## rearranged itself every time would read as a different field.
func refresh() -> void:
	for horse: Dictionary in _horses:
		var node := horse.get("node") as Node2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_horses.clear()
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	# Every kind on show, and the field filled out with repeats if the roster is
	# shorter than the paddock. A stable that only stood the kinds it happened to
	# have would read as empty on a small roster and crowded on a large one.
	for index: int in Balance.STABLE_HORSES:
		_horses.append(_stand(stock[index % stock.size()], index))
	_settle_places()


## One horse, with its own art, its own coat and its own clock.
##
## **A `MountRig` rather than a bare sprite**, and that is the fix for a real
## miss rather than a tidy-up. The first cut reached for
## `GameData.load_idle_frames` - the `_idle_01` convention every *structure* and
## animal in this game uses - and a mount does not have those: its art is an
## eight-facing sheet per state. So every lookup came back empty, and the
## paddock was static sprites sliding around a field. The owner asked for
## *animated* horses with AI.
##
## The rig already reads those sheets, turns a body onto its heading, paces the
## legs against how fast it is going and casts the pool it stands in. A paddock
## horse is the same animal the Warden rides, doing the same things, which is
## also why it cannot drift from what a ride looks like.
func _stand(kind: MountData, index: int) -> Dictionary:
	var rig := MountRig.new()
	rig.name = "Horse%d" % index
	add_child(rig)
	rig.show_mount(kind)
	# **Back to zero, because there is nobody to hide behind.**
	#
	# `MountRig` sets `z_index = -1` so the animal draws behind the person on
	# it - correct when the rig is a sibling of a rider. Here it is a child of a
	# node that *draws ground*, and a child at a negative z goes under its
	# parent's own `_draw`: every horse in the paddock was being painted over by
	# the paddock's earth. The stable stood five animals and showed none of
	# them, which is what the owner reported.
	#
	# This is the third time a negative z has cost this project a feature, after
	# a mount on the road and the Hold's own campfire. The rule is the same
	# every time: a negative z is not "behind the thing beside me", it is
	# "behind my parent as well".
	#
	# **One above, not zero.** Zero was tried first and changed nothing: this
	# node is y-sorted, so a horse standing up-field of the paddock's origin
	# still sorted before the paddock's own drawing and went under the earth
	# patch anyway. A horse in a paddock is above the paddock's dirt and below
	# everything else, which is exactly one.
	rig.z_index = 1
	# **Its own coat, off its own place in the line**, so two of the same kind in
	# one field are two horses rather than one horse drawn twice. Same bound as
	# every phenotype in the game: nothing reads it, and `PHENOTYPE_HUE_CEILING`
	# stops a bay turning blue.
	#
	# Dressed from the steppe horse's own `WildlifeData` rather than from a set
	# of spreads typed in here. It is a real horse in the roster with authored
	# spreads somebody judged for a horse, and borrowing them is one number to
	# tune instead of two.
	var coat := ContentDB.wildlife_kinds.get(COAT_SOURCE, null) as WildlifeData
	var skin: Sprite2D = rig.body()
	if coat != null and skin != null:
		Phenotype.dress(ActorPolishScript.attach(skin), coat,
			absi(hash(kind.id + str(index))))
	var own := RandomNumberGenerator.new()
	own.seed = absi(hash("stable:" + kind.id + str(index)))
	return {
		"id": kind.id,
		"kind": kind,
		"node": rig,
		"rng": own,
		"pose": 0,
		"left": own.randf_range(Balance.STABLE_PAUSE_MIN, Balance.STABLE_PAUSE_MAX),
		"home": Vector2.ZERO,
		"to": Vector2.ZERO,
		"clock": own.randf() * 10.0,
	}


## Where each horse lives: on a lattice rather than scattered, because a random
## scatter in a small rectangle puts two of them on top of each other about as
## often as not - the same lesson the outskirts taught and the pen repeats.
##
## The saddled horse is lifted out of the lattice and put at the rail, which is
## the one thing this picture says.
func _settle_places() -> void:
	if _horses.is_empty():
		return
	var across: int = maxi(1, int(floor(_stage.x / SPACING)))
	var rows: int = int(ceil(float(_horses.size()) / float(across)))
	for index: int in _horses.size():
		var own := _horses[index]["rng"] as RandomNumberGenerator
		var at: Vector2
		if String(_horses[index]["id"]) == MetaState.mount_saddled and index < across:
			at = Vector2((float(index) + 0.5) / float(across) * _stage.x - _stage.x * 0.5,
				-_stage.y * 0.5 + 18.0)
		else:
			at = Vector2(
				(float(index % across) + 0.5) / float(across) * _stage.x - _stage.x * 0.5,
				(float(index / across) + 0.5) / float(maxi(rows, 1)) * _stage.y
					- _stage.y * 0.5)
			at += Vector2(own.randf_range(-16.0, 16.0), own.randf_range(-10.0, 10.0))
		_horses[index]["home"] = at
		_horses[index]["to"] = at
		var node := _horses[index]["node"] as Node2D
		if node != null:
			node.position = at


func _process(delta: float) -> void:
	for horse: Dictionary in _horses:
		_tick(horse, delta)


## Graze, wander, stand. Each on its own clock, which at five animals is enough
## that no two are ever doing the same thing.
func _tick(horse: Dictionary, delta: float) -> void:
	var rig := horse["node"] as MountRig
	if rig == null or not is_instance_valid(rig):
		return
	horse["clock"] = float(horse["clock"]) + delta
	horse["left"] = float(horse["left"]) - delta
	if float(horse["left"]) <= 0.0:
		_choose(horse)
	if int(horse["pose"]) == 1:
		var step: Vector2 = (horse["to"] as Vector2) - rig.position
		if step.length() > 4.0:
			var way: Vector2 = step.normalized()
			rig.position += way * Balance.STABLE_WANDER_SPEED * delta
			rig.set_facing(way)
			# Paced against the walk the rig was authored at, so a paddock horse
			# ambling reads slower than one the Warden is riding. The same scale
			# the field drives it with.
			rig.set_speed_scale(Balance.STABLE_WANDER_SPEED
				/ maxf(Balance.HERO_MOVE_SPEED, 1.0) * 3.0)
			rig.play("walk")
		else:
			horse["left"] = 0.0
	else:
		rig.set_speed_scale(1.0)
		rig.play("idle")
		# A slow shift of weight. Grazing animals dip; the one at the rail does
		# not, because it is waiting rather than eating.
		rig.position.y = (horse["home"] as Vector2).y \
			+ sin(float(horse["clock"]) * 1.1) * 0.5


func _choose(horse: Dictionary) -> void:
	var own := horse["rng"] as RandomNumberGenerator
	var roll: float = own.randf()
	if roll < 0.55:
		horse["pose"] = 0
		horse["left"] = own.randf_range(Balance.STABLE_GRAZE_MIN,
			Balance.STABLE_GRAZE_MAX)
		return
	horse["pose"] = 1
	var home := horse["home"] as Vector2
	var to := home + Vector2(own.randf_range(-1.0, 1.0),
		own.randf_range(-0.45, 0.45)).normalized() * own.randf_range(40.0, 130.0)
	# Inside the fence. A horse that wandered out of the paddock would be the
	# stable's whole point walking away from it.
	horse["to"] = Vector2(
		clampf(to.x, -_stage.x * 0.5 + 20.0, _stage.x * 0.5 - 20.0),
		clampf(to.y, -_stage.y * 0.5 + 12.0, _stage.y * 0.5 - 12.0))
	horse["left"] = own.randf_range(Balance.STABLE_PAUSE_MIN,
		Balance.STABLE_PAUSE_MAX)


func _draw() -> void:
	# The patches read the turf in world coordinates, so the sheet has to wrap
	# rather than clamp - left on the default, every UV past one comes back as
	# the edge column and the wear is one flat smear.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	# The fence: four rails around the ground, drawn rather than tiled, because a
	# paddock is a rectangle and a tileset for one would be four corners of art
	# to keep in step with a number in `Balance`.
	var half: Vector2 = _stage * 0.5
	var ground := Rect2(-half, _stage)
	# **Worn ground rather than one flat colour.** Photographed on 2026-09-17:
	# a paddock this size drawn as a single translucent rect is the largest flat
	# rectangle in the Hold, and it reads as a green box the horses stand on top
	# of. Three ellipses of bare earth where they actually walk, and tufts near
	# the rail where grass survives, make it ground - the same treatment the pens
	# got, for the same reason and at the same cost of nothing.
	# **The yard's own earth rather than a colour laid over it.**
	# Photographed again on 2026-09-17 after the first pass: three ellipses of
	# wear over a flat translucent fill is still a flat translucent fill, and at
	# this size it is the largest rectangle in the Hold - it read as a pane of
	# green glass with horses standing on it. The ground the rest of the place
	# is painted with, worn toward the middle, is earth.
	# **And nothing opaque goes over a yard somebody else painted.** Standing
	# on the stable screen this node is the only floor there is, so it lays
	# one; standing in the Hold there is a whole terraced yard behind it, and
	# a darkened rectangle over that is a rectangle however well it is
	# textured - which is what the third photograph of this place showed,
	# after two passes that had each made the *inside* of it better.
	if _standing:
		if _turf != null:
			draw_texture_rect(_turf, ground, true, Color(0.50, 0.53, 0.40))
		else:
			draw_rect(ground, Color(0.24, 0.27, 0.16, 0.60), true)
	# **And the wear is feathered, which the third pass is about.** Three flat
	# ellipses laid over a textured rect is still a flat film over a textured
	# rect: the widest of them was 0.46 of the paddock's *width* against a
	# half-height well under that, so all three covered the whole ground and
	# the texture underneath was washed straight back out. `GroundWear` is the
	# one definition the Hold's paths, its pens and this all wear now.
	GroundWear.patch(get_canvas_item(), _turf, Vector2.ZERO, _stage.x * 0.34,
		Balance.HOLD_SOIL_TINT, 0.52)
	for tuft: int in 22:
		var along: float = fmod(float(tuft) * 0.618034, 1.0)
		var down: float = fmod(float(tuft) * 0.381966 + 0.29, 1.0)
		var at := Vector2(-half.x + _stage.x * along, -half.y + _stage.y * down)
		if at.length() < _stage.x * 0.26:
			continue
		draw_line(at, at + Vector2(1.0, -6.0), Color(0.33, 0.40, 0.23, 0.8), 1.5)
		draw_line(at, at + Vector2(-2.0, -5.0), Color(0.29, 0.35, 0.21, 0.7), 1.5)
	# **Posts and rails, not an outline.** A rectangle of line reads as a
	# diagram - the pens learned that the same day and this is the same fence
	# built the same way: uprights with a thickness and a lit side, two bars
	# between them, and the gate is the pair of posts that are missing.
	var timber := Color(0.42, 0.32, 0.22)
	var posts: int = maxi(4, int(_stage.x / 90.0))
	var span: float = _stage.x / float(posts)
	for index: int in posts + 1:
		var x: float = -half.x + span * float(index)
		var gate: bool = absf(x) < 44.0
		# The far rail first and low, so a horse standing at the back of the
		# paddock is in front of it rather than behind a plank.
		if not gate:
			_post(Vector2(x, -half.y), 18.0, timber.darkened(0.25))
			if index > 0:
				_rail(Vector2(x - span, -half.y - 13.0), Vector2(x, -half.y - 13.0),
					timber.darkened(0.25))
	for index: int in posts + 1:
		var x: float = -half.x + span * float(index)
		_post(Vector2(x, half.y), 30.0, timber)
		if index > 0:
			_rail(Vector2(x - span, half.y - 22.0), Vector2(x, half.y - 22.0), timber)
			_rail(Vector2(x - span, half.y - 10.0), Vector2(x, half.y - 10.0),
				timber.darkened(0.12))
	# The two sides, which are short enough to be posts alone.
	for side: int in 2:
		var x: float = -half.x if side == 0 else half.x
		var down: int = maxi(2, int(_stage.y / 90.0))
		var drop: float = _stage.y / float(down)
		for index: int in down:
			var y: float = -half.y + drop * float(index + 1)
			_post(Vector2(x, y), 26.0, timber.darkened(0.06))
			_rail(Vector2(x, y - drop - 18.0), Vector2(x, y - 18.0),
				timber.darkened(0.18))


## One upright with a thickness and a lit face - the pens' own post, because a
## fence drawn two different ways in one yard is two fences.
func _post(foot: Vector2, tall: float, timber: Color) -> void:
	var wide: float = 5.0
	var head: Vector2 = foot - Vector2(0.0, tall)
	draw_colored_polygon(PackedVector2Array([
		head - Vector2(wide * 0.5, 0.0), head,
		foot, foot - Vector2(wide * 0.5, 0.0)]), timber.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([
		head, head + Vector2(wide * 0.5, 0.0),
		foot + Vector2(wide * 0.5, 0.0), foot]), timber.darkened(0.22))
	draw_line(head - Vector2(wide * 0.5, 0.0), head + Vector2(wide * 0.5, 0.0),
		timber.lightened(0.3), 1.5)


## A bar between two posts, with its own underside.
func _rail(from: Vector2, to: Vector2, timber: Color) -> void:
	draw_line(from, to, timber, 4.0)
	draw_line(from + Vector2(0.0, 2.0), to + Vector2(0.0, 2.0),
		timber.darkened(0.3), 1.5)


## How many horses are standing. For the gate.
func standing() -> int:
	return _horses.size()


## What pose a horse is in - 0 grazing, 1 wandering. For the gate.
func pose_at(index: int) -> int:
	if index < 0 or index >= _horses.size():
		return -1
	return int(_horses[index]["pose"])


## Drive the paddock by hand, for a gate with no minutes to spend. The same seam
## `PenYard` and `MusicPlayer` expose, and for the same reason: waiting out forty
## seconds of animation to prove five animals differ is a test of the clock.
func drive(seconds: float, step: float = 0.1) -> void:
	var left: float = seconds
	while left > 0.0:
		for horse: Dictionary in _horses:
			_tick(horse, step)
		left -= step
