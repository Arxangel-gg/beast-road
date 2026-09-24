class_name ThreatPointers
extends Control

## **Arrows at the edge of the screen for what the player has to go and find.**
##
## Owner, 2026-09-22, of the beasts that roam: *"indicators also implemented to
## help players identify where they are"* - and of the wave that would not end
## because somebody was lost. Four kinds, each something the game is already
## waiting on or already announced:
##
## - **the last bodies of a wave** - exactly the set `Stragglers` plumes, asked
##   of it, so the arrow and the plume cannot disagree about who is left;
## - **an act boss** on the field;
## - **a beast hunting the players** - a savage sent after the hunter, a parent
##   whose nest was robbed, an animal the Wildblight has taken;
## - **a dragon that has landed**, which is an event the sky already announced.
##
## **The fog's bound, narrowed exactly as `Stragglers` narrowed it.** The fog
## hides and never helps; these point only at things that are hunting the
## player or that a wave or an announcement is already asking the player about.
## An arrow at every elite, every camp and every animal would be the fog turned
## off. Nothing reads any of it and it moves no number.

enum Kind { STRAGGLER, BOSS, BEAST, DRAGON }

var field: Battlefield = null
var _targets: Array[Dictionary] = []
var _clock: float = 0.0
var _life: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process_measured(delta: float) -> void:
	_life += delta
	_clock -= delta
	if _clock <= 0.0:
		_clock = Balance.THREAT_POINTER_REFRESH
		_gather()
	queue_redraw()


## What is being pointed at, by kind, as `{node, kind}`.
func _gather() -> void:
	_targets.clear()
	if field == null or not is_instance_valid(field) or not field.is_inside_tree() \
			or not field.visible:
		return
	var stragglers: Node = field.get("_stragglers") as Node
	if stragglers != null and is_instance_valid(stragglers) and stragglers.has_method("marked"):
		for id: Variant in stragglers.call("marked"):
			var body := instance_from_id(int(id)) as Node2D
			if body != null and is_instance_valid(body):
				_targets.append({"node": body, "kind": Kind.STRAGGLER})
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var boss := node as Enemy
		if boss == null or boss.is_dying() or boss.data == null \
				or boss.data.category != EnemyData.Category.BOSS \
				or not field.is_ancestor_of(boss):
			continue
		_targets.append({"node": boss, "kind": Kind.BOSS})
	var animals: Wildlife = field.wildlife_system()
	if animals != null:
		for sprite: Node2D in animals.hunting_sprites():
			_targets.append({"node": sprite, "kind": Kind.BEAST})
	for node: Node in get_tree().get_nodes_in_group(DragonPass.GROUP):
		var dragon := node as DragonPass
		if dragon != null and is_instance_valid(dragon) and dragon.is_landed():
			_targets.append({"node": dragon, "kind": Kind.DRAGON})


## Where each arrow stands and which way it points, for everything off the
## screen: `{kind, at, facing}` in this control's coordinates. The drawing and
## the gate both read this, so what is checked is what is drawn.
func pointers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var screen: Rect2 = get_viewport_rect()
	var inset: float = Balance.THREAT_POINTER_INSET
	var room := Rect2(screen.position + Vector2.ONE * inset,
		screen.size - Vector2.ONE * inset * 2.0)
	if room.size.x <= 0.0 or room.size.y <= 0.0:
		return out
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var centre: Vector2 = room.get_center()
	for target: Dictionary in _targets:
		# Read as a Variant and checked before any cast: casting a freed body
		# throws, and a body dies between one gather and the next all the time.
		var held: Variant = target["node"]
		if not is_instance_valid(held):
			continue
		var node := held as Node2D
		if node == null or not node.is_inside_tree():
			continue
		var seen: Vector2 = canvas * node.global_position
		if room.has_point(seen):
			continue
		var toward: Vector2 = seen - centre
		if toward.length() < 1.0:
			continue
		# Along the line from the middle of the screen to the target, as far as
		# the inset rectangle allows - so the arrow sits where the eye would
		# follow it out.
		var reach_x: float = (room.size.x * 0.5) / maxf(absf(toward.x), 0.001)
		var reach_y: float = (room.size.y * 0.5) / maxf(absf(toward.y), 0.001)
		var at: Vector2 = centre + toward * minf(reach_x, reach_y)
		out.append({"kind": int(target["kind"]), "at": at, "facing": toward.normalized()})
	return out


func _draw_measured() -> void:
	var beat: float = 0.5 + 0.5 * sin(_life * Balance.THREAT_POINTER_PULSE_HZ * TAU)
	for pointer: Dictionary in pointers():
		var kind: int = int(pointer["kind"])
		var tint: Color = Balance.THREAT_POINTER_COLOURS[clampi(kind, 0,
			Balance.THREAT_POINTER_COLOURS.size() - 1)]
		var at: Vector2 = pointer["at"] as Vector2
		var facing: Vector2 = pointer["facing"] as Vector2
		var size: float = Balance.THREAT_POINTER_SIZE * (1.0 + 0.12 * beat)
		var across: Vector2 = facing.orthogonal()
		var tip: Vector2 = at + facing * size
		var arrow := PackedVector2Array([tip, at - facing * size * 0.4 + across * size * 0.8,
			at - facing * size * 0.4 - across * size * 0.8])
		# A dark rim first, so the arrow reads over snow as well as over night.
		var rim := PackedVector2Array([tip + facing * 3.0,
			at - facing * size * 0.55 + across * (size * 0.8 + 3.5),
			at - facing * size * 0.55 - across * (size * 0.8 + 3.5)])
		draw_colored_polygon(rim, Color(0.05, 0.04, 0.03, 0.75))
		draw_colored_polygon(arrow, Color(tint, 0.7 + 0.3 * beat))
		draw_circle(at - facing * size * 0.9, size * 0.32, Color(tint, 0.85))


## `FrameProfile` bucket "pointers": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"pointers", started)


## `FrameProfile` bucket "d_threat_pointers": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"d_threat_pointers", started)
