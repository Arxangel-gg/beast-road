class_name PenYard
extends Node2D

const ActorPolishScript = preload("res://scripts/systems/actor_polish.gd")

## The pen, drawn: the animals the Warden has raised, living in it.
##
## **Owner brief, 2026-09-15:** *"Alive companions should be keepable at a pen
## where they have idle and roam and rest/sleep and other animations."*
##
## Each kept animal stands up its own sprite and picks its own poses - grazing
## where it is, wandering somewhere new, lying down for a while. Nothing is
## scheduled and nothing is shared: each one keeps its own clock, so a pen of
## twelve never reads as twelve copies of one animation, which is the whole
## reason to draw a pen rather than list one.
##
## **It is a picture of `MetaState.pen` and nothing more.** It rolls no dice that
## matter, writes nothing, and is read by nothing: taking an animal out, letting
## one go and losing one all happen through `MetaState`, and this redraws when
## told. Close the screen and the pen is exactly what it was.
##
## **The coats come from `Phenotype`**, off each animal's own name, so the fox
## you raised is the fox in the pen rather than the roster's painting - and the
## one you take out on the road is that same fox. That is the phenotype bound
## working in a second place: nothing reads a coat, it is simply *which animal
## this is*.

## How far apart two animals try to settle, so a pen never reads as a pile.
const SPACING: float = 74.0

var _stage: Vector2 = Vector2(520.0, 260.0)
var _animals: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_process(true)
	refresh()


## How big the yard is on screen. Set before or after `refresh`; either re-lays.
func set_stage(size: Vector2) -> void:
	_stage = size
	_settle_places()
	queue_redraw()


## Re-read the pen and stand up what is in it.
##
## **Seeded off each animal's own name**, so re-opening the screen puts every
## creature back where it was rather than shuffling the pen each visit - a pen
## that rearranged itself every time would read as a different pen.
func refresh() -> void:
	for animal: Dictionary in _animals:
		var node := animal.get("node") as Node2D
		if node != null and is_instance_valid(node):
			node.queue_free()
	_animals.clear()
	for kept: Dictionary in MetaState.pen:
		var species: String = String(kept.get("species", ""))
		var kind := ContentDB.wildlife_kinds.get(species, null) as WildlifeData
		if kind == null:
			continue
		_animals.append(_stand(kept, kind))
	_settle_places()
	queue_redraw()


## One animal, with its own art, its own coat and its own clock.
func _stand(kept: Dictionary, kind: WildlifeData) -> Dictionary:
	var uid: String = String(kept.get("uid", ""))
	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base: String = kind.get_sprite_path()
	if ResourceLoader.exists(base):
		sprite.texture = load(base) as Texture2D
	sprite.scale = Vector2.ONE * clampf(kind.scale * 0.8, 0.6, 2.2)
	sprite.flip_h = not kind.art_faces_right
	# Its own coat, off its own name. The animal in the pen is the animal that
	# walks out of it.
	Phenotype.dress(ActorPolishScript.attach(sprite), kind,
		absi(hash(uid)) if not uid.is_empty() else 0)
	add_child(sprite)
	var own := RandomNumberGenerator.new()
	own.seed = absi(hash("pen:" + uid))
	return {
		"uid": uid,
		"kind": kind,
		"node": sprite,
		"idle": GameData.load_idle_frames(base),
		"move": GameData.load_move_frames(base),
		"base": sprite.texture,
		"rng": own,
		"pose": 0,
		"left": own.randf_range(Balance.PEN_POSE_SECONDS.x,
			Balance.PEN_POSE_SECONDS.y),
		"home": Vector2.ZERO,
		"to": Vector2.ZERO,
		"clock": own.randf() * 10.0,
	}


## Where each animal lives in the yard: spread on a lattice rather than scattered,
## because a random scatter in a small rectangle puts two of them on top of each
## other about as often as not - the same lesson the outskirts taught.
func _settle_places() -> void:
	if _animals.is_empty():
		return
	var across: int = maxi(1, int(floor(_stage.x / SPACING)))
	for index: int in _animals.size():
		var column: int = index % across
		var row: int = index / across
		var rows: int = int(ceil(float(_animals.size()) / float(across)))
		var at := Vector2(
			(float(column) + 0.5) / float(across) * _stage.x - _stage.x * 0.5,
			(float(row) + 0.5) / float(maxi(rows, 1)) * _stage.y - _stage.y * 0.5)
		var own := _animals[index]["rng"] as RandomNumberGenerator
		at += Vector2(own.randf_range(-12.0, 12.0), own.randf_range(-8.0, 8.0))
		_animals[index]["home"] = at
		_animals[index]["to"] = at
		var node := _animals[index]["node"] as Node2D
		if node != null:
			node.position = at


func _process(delta: float) -> void:
	for animal: Dictionary in _animals:
		_tick(animal, delta)


## Graze, wander, lie down, and back again. Three poses and its own clock, which
## at a dozen animals is enough that no two are ever doing the same thing.
func _tick(animal: Dictionary, delta: float) -> void:
	var node := animal["node"] as Node2D
	if node == null or not is_instance_valid(node):
		return
	animal["clock"] = float(animal["clock"]) + delta
	animal["left"] = float(animal["left"]) - delta
	if float(animal["left"]) <= 0.0:
		_choose(animal)
	var pose: int = int(animal["pose"])
	var frames: Array = animal["move"] if pose == 1 else animal["idle"]
	if pose == 1:
		var to := animal["to"] as Vector2
		var step: Vector2 = (to - node.position)
		if step.length() > 3.0:
			node.position += step.normalized() * Balance.PEN_ROAM_SPEED * delta
			var kind := animal["kind"] as WildlifeData
			(node as Sprite2D).flip_h = (step.x < 0.0) == kind.art_faces_right
		else:
			animal["left"] = 0.0
	# Resting animals lie a little lower and breathe slower, which is the whole
	# difference at this size - a sleeping sprite is a still sprite with its
	# shadow closer to it.
	var breathe: float = 1.0 if pose != 2 else 0.35
	var texture: Texture2D = animal["base"] as Texture2D
	if not frames.is_empty():
		var step: int = int(float(animal["clock"]) * 4.0 * breathe) % (frames.size() + 1)
		if step > 0:
			texture = frames[step - 1] as Texture2D
	(node as Sprite2D).texture = texture
	node.position.y += sin(float(animal["clock"]) * 1.4) * 0.06 * breathe


func _choose(animal: Dictionary) -> void:
	var own := animal["rng"] as RandomNumberGenerator
	var roll: float = own.randf()
	# Mostly standing about, sometimes off somewhere, occasionally lying down.
	# A pen where everything is always moving reads as agitated rather than kept.
	if roll < 0.45:
		animal["pose"] = 0
	elif roll < 0.8:
		animal["pose"] = 1
		var home := animal["home"] as Vector2
		animal["to"] = home + Vector2(own.randf_range(-1.0, 1.0),
			own.randf_range(-0.5, 0.5)).normalized() \
			* own.randf_range(20.0, Balance.PEN_ROAM_RADIUS)
	else:
		animal["pose"] = 2
	animal["left"] = own.randf_range(Balance.PEN_POSE_SECONDS.x,
		Balance.PEN_POSE_SECONDS.y)


## How many animals are standing in the yard. For the gate.
func standing() -> int:
	return _animals.size()


## What pose an animal is in - 0 grazing, 1 wandering, 2 resting. For the gate.
func pose_of(uid: String) -> int:
	for animal: Dictionary in _animals:
		if String(animal["uid"]) == uid:
			return int(animal["pose"])
	return -1


## Drive the yard by hand, for a gate with no minutes to spend.
func advance(seconds: float, steps: int = 30) -> void:
	var step: float = seconds / maxf(float(steps), 1.0)
	for _tick_index: int in steps:
		_process(step)


func _draw() -> void:
	# The ground they are kept on. Drawn rather than an asset because it is a
	# rectangle of earth behind a dozen sprites, and a painting of one would be
	# a manifest row for something nobody looks at.
	var half: Vector2 = _stage * 0.5
	draw_rect(Rect2(-half, _stage), Color(0.16, 0.19, 0.14), true)
	draw_rect(Rect2(-half, _stage), Color(0.32, 0.29, 0.21), false, 3.0)
	for animal: Dictionary in _animals:
		var node := animal["node"] as Node2D
		if node == null or not is_instance_valid(node):
			continue
		var lying: bool = int(animal["pose"]) == 2
		draw_circle(node.position + Vector2(0.0, 6.0 if lying else 10.0),
			14.0 if lying else 11.0, Color(0.0, 0.0, 0.0, 0.26))
