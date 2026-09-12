class_name RiftGates
extends Node2D

## The gates on the battlefield that lead into a rift or a dungeon.
##
## Placed the way the ponds are: in the outer band of the field, on open
## ground, clear of the roads, the spawn mouths, the water and each other, from
## a generator seeded by the run and the region so both machines see the same
## gates. One rift a region from `Balance.RIFT_FIRST_ACT`; a dungeon mouth as
## well every `Balance.DUNGEON_EVERY_ACTS` acts, so the deep places are rare
## enough to be an event.
##
## Walk up and press: the same `interact` the ponds use, through the same
## prompt, so a key, a pad button and a thumb all arrive by one road. The gate
## asks the run (`EventBus.rift_requested`) rather than opening anything
## itself - the run owns the freeze - and is spent once the run accepts.

const RIFT_ART: String = "res://art/battlefield/rift_gate.png"
const DUNGEON_ART: String = "res://art/battlefield/dungeon_mouth.png"
const FRAME_RATE: float = 6.0

var grid: BattleGrid = null
var field: Node = null
var host: Node2D = null
## Where the water is, so a gate is never dug in a pond.
var avoid: PackedVector2Array = []

## {root, sprite, at, kind, spent, frames, clock}
var _gates: Array[Dictionary] = []
var _near: int = -1
var _prompt: String = ""
var _prompt_button: String = ""


## Re-digs the gates for the current region.
func scatter() -> void:
	for gate: Dictionary in _gates:
		var root: Node = gate.get("root", null)
		if root != null and is_instance_valid(root):
			root.queue_free()
	_gates.clear()
	_near = -1
	_set_prompt("", "")
	if grid == null or RunState.act < Balance.RIFT_FIRST_ACT:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = RunState.run_seed * 1000003 + hash("rifts:" + RunState.terrain_id)
	var wanted: Array[int] = [RiftArena.Kind.RIFT]
	if RunState.act % Balance.DUNGEON_EVERY_ACTS == 0:
		wanted.append(RiftArena.Kind.DUNGEON)
	# Anchored on the band's open tiles, as the ponds are; see `Fishing.band_tiles`.
	var anchors: Array[Vector2i] = Fishing.band_tiles(grid, Balance.RIFT_GATE_EDGE_BAND)
	if anchors.is_empty():
		return
	for kind: int in wanted:
		var art: String = RIFT_ART if kind == RiftArena.Kind.RIFT else DUNGEON_ART
		if not ResourceLoader.exists(art):
			continue
		for _attempt: int in 220:
			var rim: Rect2 = Fishing.footprint_rim(anchors[rng.randi_range(0, anchors.size() - 1)], FOOTPRINT)
			var at: Vector2 = rim.get_center()
			if _is_good_ground(at):
				_dig(kind, at, load(art) as Texture2D)
				break


## A gate stands on two tiles by two.
const FOOTPRINT: Vector2i = Vector2i(2, 2)


func _is_good_ground(at: Vector2) -> bool:
	var half: Vector2 = Vector2(FOOTPRINT) * BattleGrid.TILE * 0.5
	var rim := Rect2(at - half, half * 2.0)
	if not Fishing.ground_is_open(grid, rim, Balance.RIFT_GATE_CLEARANCE_TILES):
		return false
	if at.length() < Balance.FISHING_TOWN_CLEARANCE:
		return false
	for spawn: Variant in grid.spawn_points:
		if rim.grow(Balance.FISHING_SPAWN_CLEARANCE).has_point(spawn as Vector2):
			return false
	for water: Vector2 in avoid:
		if at.distance_to(water) < Balance.RIFT_GATE_CLEARANCE * 2.0:
			return false
	for gate: Dictionary in _gates:
		if at.distance_to(gate["at"] as Vector2) < Balance.RIFT_GATE_CLEARANCE * 2.4:
			return false
	return true


func _dig(kind: int, at: Vector2, art: Texture2D) -> void:
	var root := Node2D.new()
	root.name = "RiftGate" if kind == RiftArena.Kind.RIFT else "DungeonMouth"
	root.global_position = at
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	sprite.add_to_group(Graphics.FILTER_GROUP)
	# Sorted by its foot, like every other thing standing on the field.
	sprite.offset = Vector2(0.0, -float(art.get_height()) * 0.42)
	root.add_child(sprite)
	(host if host != null else self).add_child(root)
	var frames: Array[Texture2D] = GameData.load_idle_frames(art.resource_path)
	_gates.append({
		"root": root, "sprite": sprite, "at": at, "kind": kind, "spent": false,
		"frames": frames, "clock": randf() * 3.0,
	})


func _process(delta: float) -> void:
	if _gates.is_empty():
		return
	for index: int in _gates.size():
		_tick_gate(index, delta)
	var angler: Node2D = _local_hero()
	if angler == null:
		_near = -1
		_set_prompt("", "")
		return
	var near: int = _gate_near(angler.global_position)
	_near = near
	if near < 0:
		_set_prompt("", "")
		return
	var kind: int = int(_gates[near]["kind"])
	_set_prompt("Enter the rift" if kind == RiftArena.Kind.RIFT else "Descend into the dungeon",
		"ENTER")
	var source := angler.get("input") as HeroInput
	if source != null and source.pressed(HeroInput.BUTTON_INTERACT):
		EventBus.rift_requested.emit(kind)


## The frames, and a slow pulse of light through the gate.
func _tick_gate(index: int, delta: float) -> void:
	var gate: Dictionary = _gates[index]
	var sprite: Sprite2D = gate["sprite"] as Sprite2D
	if sprite == null or not is_instance_valid(sprite):
		return
	var clock: float = float(gate["clock"]) + delta
	_gates[index]["clock"] = clock
	var frames: Array[Texture2D] = gate["frames"]
	if frames.size() > 1 and not bool(gate["spent"]):
		sprite.texture = frames[int(clock * FRAME_RATE) % frames.size()]
	var pulse: float = 0.9 + 0.1 * sin(clock * 2.2)
	sprite.modulate = Color(0.55, 0.55, 0.6, 0.85) if bool(gate["spent"]) \
		else Color(pulse, pulse, 1.0 if int(gate["kind"]) == RiftArena.Kind.RIFT else pulse)


func _gate_near(at: Vector2) -> int:
	var best: int = -1
	var nearest: float = INF
	for index: int in _gates.size():
		var gate: Dictionary = _gates[index]
		if bool(gate["spent"]):
			continue
		var gap: float = at.distance_to(gate["at"] as Vector2)
		if gap <= Balance.RIFT_GATE_RADIUS and gap < nearest:
			nearest = gap
			best = index
	return best


## The run accepted the request: the gate closes behind the hero.
func spend(kind: int) -> Vector2:
	var index: int = _near
	if index < 0 or index >= _gates.size() or int(_gates[index]["kind"]) != kind:
		for candidate: int in _gates.size():
			if int(_gates[candidate]["kind"]) == kind and not bool(_gates[candidate]["spent"]):
				index = candidate
				break
	if index < 0 or index >= _gates.size():
		return Vector2.ZERO
	_gates[index]["spent"] = true
	_set_prompt("", "")
	return _gates[index]["at"] as Vector2


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


## For the gate: where the gates are, and which kinds.
func gate_positions() -> PackedVector2Array:
	var out: PackedVector2Array = []
	for gate: Dictionary in _gates:
		out.append(gate["at"] as Vector2)
	return out


func gate_kinds() -> Array[int]:
	var out: Array[int] = []
	for gate: Dictionary in _gates:
		out.append(int(gate["kind"]))
	return out
