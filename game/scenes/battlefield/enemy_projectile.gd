class_name EnemyProjectile
extends Node2D

## The field this shot crosses, found once by walking up, for the mirrors.
var _field: Battlefield = null
var _looked_for_field: bool = false

## A dodgeable hostile shot. It commits to the target's position at release,
## so moving during the telegraph is the answer; it never homes after the hero.

## Which of the three flying shots this is. LOB and LANCE are not projectiles
## at all - they are `EnemyGroundStrike`, because what they hit is a place.
enum Kind { BOLT, SPRAY, HEX }

## Set before the shot enters the tree. BOLT is what every shot was until
## 2026-09-13, so a caller that sets nothing gets exactly the old behaviour.
var kind: int = Kind.BOLT

## Which forged sheet each kind lands under. Authored rather than derived
## from the enum's name so a fourth kind fails `forge_check` by not being
## here, rather than silently drawing the bolt.
##
## **Three, not five.** `EnemyShotData.Kind` has five, and a mortar and a
## lance resolve as `EnemyGroundStrike` rather than as a flying shot - they
## land where they were aimed, which is the whole reason they are a separate
## node. Their sheets are played there.
const _FORGED_BY_KIND: Dictionary = {
	Kind.BOLT: "shot_bolt",
	Kind.SPRAY: "shot_spray",
	Kind.HEX: "shot_hex",
}
## How much mana a HEX takes off whoever it reaches.
var mana_burn: float = 0.0

## **What it looks like in flight**, set from the shot that threw it before it
## enters the tree. The projectile is drawn from constants rather than from art,
## so a fire bolt costs a colour and no sprite. Left at the roster's own values,
## every shot looks the way every shot has always looked.
var tint: Color = Balance.ENEMY_PROJECTILE_COLOUR
var core_tint: Color = Balance.ENEMY_PROJECTILE_CORE_COLOUR
var shell_tint: Color = Balance.ENEMY_PROJECTILE_SHELL_COLOUR
## The head's shape and motion, from `EnemyShotData` (2026-09-21). Pictures
## only: the node flies its path whatever the head is doing.
var head: int = EnemyShotData.Head.RUNE
var head_scale: float = 1.0
var spin: float = 0.0
var wobble: float = 0.0
var trail_scale: float = 1.0
var pace_scale: float = 1.0

var _target: Node2D = null
var _destination: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.RIGHT
var _damage: float = 0.0
var _life: float = 0.0
## The ribbon behind the head: where the shot has been, drawn on an additive
## child rather than kept as two `Line2D`s (2026-09-24). See `InkRibbon`.
var _ribbon: EnemyShotGlow = null
var _history: PackedVector2Array = []
var _mote_left: float = 0.0


func configure(target: Node2D, damage: float, origin: Vector2) -> void:
	_target = target
	_damage = damage
	global_position = origin
	_destination = _combat_origin(target) if target != null and is_instance_valid(target) else origin
	_direction = (_destination - origin).normalized()
	rotation = _direction.angle()


## The same shot with nothing to hit, for a guest drawing the host's decision.
##
## A puppet resolves nothing, so this carries no target and no damage - the host
## has already worked out who was hit and reports it as health in the next batch.
## What was missing was the shot itself: a ranged enemy on the guest's screen
## simply hurt people from across the field with nothing in between.
func configure_toward(destination: Vector2, origin: Vector2) -> void:
	_target = null
	_damage = 0.0
	global_position = origin
	_destination = destination
	_direction = (destination - origin).normalized() 		if destination.distance_to(origin) > 1.0 else Vector2.RIGHT
	rotation = _direction.angle()


func _ready() -> void:
	z_index = Balance.VFX_Z - 1
	_ribbon = EnemyShotGlow.new()
	_ribbon.shot = self
	add_child(_ribbon)

	var glow := Sprite2D.new()
	glow.texture = LightKit.falloff_texture()
	glow.modulate = Color(tint, 0.72)
	glow.scale = Vector2.ONE * Balance.ENEMY_PROJECTILE_GLOW_SCALE * sqrt(head_scale)
	add_child(glow)
	# On the shared shot-light budget (2026-09-24); see `LightKit`.
	if LightKit.shot_light_free():
		LightKit.add_light(self, tint,
			Balance.ENEMY_PROJECTILE_LIGHT_RADIUS, Balance.ENEMY_PROJECTILE_LIGHT_ENERGY)
		LightKit.take_shot_light()
		_carries_light = true
	_mote_left = Balance.ENEMY_PROJECTILE_MOTE_INTERVAL
	queue_redraw()


var _carries_light: bool = false


func _exit_tree() -> void:
	if _carries_light:
		_carries_light = false
		LightKit.give_shot_light()


func _process_measured(delta: float) -> void:
	_life += delta
	if _life >= Balance.ENEMY_PROJECTILE_MAX_LIFE:
		queue_free()
		return
	# A Stillwater Mirror in its way swallows it (2026-09-14): the shot ends
	# here with no impact, and the mirror spends a charge.
	if _field == null and not _looked_for_field:
		_looked_for_field = true
		var node: Node = get_parent()
		while node != null and _field == null:
			_field = node as Battlefield
			node = node.get_parent()
	if _field != null and _field.absorb_hostile_shot(global_position):
		queue_free()
		return
	# A hex follows, slowly. It turns at a fixed rate rather than homing
	# exactly, which is what makes outrunning one possible and what makes
	# putting a body between you and it work.
	if kind == Kind.HEX and _target != null and is_instance_valid(_target):
		_destination = _combat_origin(_target)
		var wanted: float = (_destination - global_position).angle()
		_direction = Vector2.RIGHT.rotated(
			rotate_toward(_direction.angle(), wanted, Balance.ENEMY_SHOT_HEX_TURN * delta))
		rotation = _direction.angle()
	var distance_before: float = global_position.distance_to(_destination)
	global_position += _direction * Balance.ENEMY_PROJECTILE_SPEED * _pace() * delta
	# The trail is a length in units, laid a point every step of travel, so
	# it is the same ribbon at any frame rate; the point count is a cap.
	if _history.is_empty() \
			or _history[_history.size() - 1].distance_to(global_position) >= Balance.ENEMY_PROJECTILE_TRAIL_STEP:
		_history.append(global_position)
		var length: float = 0.0
		for index: int in range(_history.size() - 1, 0, -1):
			length += _history[index].distance_to(_history[index - 1])
			if length > Balance.ENEMY_PROJECTILE_TRAIL_LENGTH * trail_scale:
				_history = _history.slice(index - 1)
				break
	while _history.size() > Balance.ENEMY_PROJECTILE_TRAIL_POINTS:
		_history.remove_at(0)
	if _ribbon != null:
		_ribbon.queue_redraw()
	_mote_left -= delta
	if _mote_left <= 0.0:
		_mote_left += Balance.ENEMY_PROJECTILE_MOTE_INTERVAL
		# One shard a tick is the floor `spark` keeps, so under load the
		# director could never thin these; thinned here instead (2026-09-24).
		var keep: float = JuiceDirector.weight(JuiceDirector.Priority.COSMETIC) \
			* Graphics.particle_scale()
		if keep >= 1.0 or randf() < keep:
			Vfx.spark(global_position - _direction * Balance.ENEMY_PROJECTILE_HEAD_RADIUS,
				core_tint, 1, -_direction,
				Balance.ENEMY_PROJECTILE_MOTE_SPEED)
	queue_redraw()
	# **A shot hits what it passes through.**
	#
	# Until 2026-09-13 a shot only ever resolved where its *destination* was,
	# which was invisible while every shot was aimed at a body - the body and
	# the destination were the same place. The fan and the boss volley are aimed
	# at points either side of their target instead, so both flew straight past
	# whoever they were thrown at and burst harmlessly at the far end of their
	# range. Caught by `enemy_shot_check` measuring the damage rather than
	# trusting the aim.
	if _target != null and is_instance_valid(_target) 			and global_position.distance_to(_combat_origin(_target)) 				<= Balance.ENEMY_PROJECTILE_BLAST_RADIUS:
		_impact()
		return
	var distance_after: float = global_position.distance_to(_destination)
	if distance_after <= Balance.ENEMY_PROJECTILE_HIT_RADIUS:
		_impact()
		return
	# A hex is *steering* at its destination, so "it stopped getting closer"
	# would end it on every turn it takes. It flies until it arrives or until
	# its life runs out, and that is the thing being outrun.
	if kind != Kind.HEX and distance_after > distance_before:
		_impact()


## How fast this one flies, against the baseline.
func _pace() -> float:
	return (Balance.ENEMY_SHOT_HEX_SPEED if kind == Kind.HEX else 1.0) * pace_scale


func _impact() -> void:
	if _target != null and is_instance_valid(_target) \
			and global_position.distance_to(_combat_origin(_target)) <= Balance.ENEMY_PROJECTILE_BLAST_RADIUS:
		var target_health: Health = Health.of(_target)
		if target_health != null:
			target_health.take_damage(_damage, global_position)
		# And a hex takes mana with it. Nothing else in the game does, which is
		# why a hex is the shot a caster has to respect and a swordhand does
		# not - the one difference between five shots that is about *who* you
		# are rather than about where you are standing.
		if mana_burn > 0.0:
			var who := _target as Hero
			if who != null:
				who.mana = maxf(who.mana - mana_burn, 0.0)
				EventBus.hero_mana_changed.emit(who.mana, who.mana_max())
	_land_the_look()
	queue_free()


## **What the head does when it lands** - the same blow, dressed by its shape.
## A stone throws dust and no sparks; a flame throws its embers upward; a
## shard shatters into many fast, bright slivers; a skull leaves slow dark
## wisps; the rest burst as every shot always has. Nothing here reads back.
func _land_the_look() -> void:
	var sparks: int = Balance.ENEMY_PROJECTILE_IMPACT_SPARKS
	var radius: float = Balance.ENEMY_PROJECTILE_BLAST_RADIUS * sqrt(head_scale)
	match head:
		EnemyShotData.Head.STONE:
			Vfx.dust(global_position, Color(shell_tint.lightened(0.35), 0.8), 7, radius * 0.8)
			Vfx.spark(global_position, shell_tint.lightened(0.2), 5, -_direction, 120.0)
		EnemyShotData.Head.FLAME:
			Vfx.spark(global_position, core_tint, sparks + 6, Vector2.UP, 150.0)
			Vfx.spark(global_position, tint, 6, -_direction, 90.0)
		EnemyShotData.Head.SHARD:
			Vfx.spark(global_position, core_tint, sparks + 10, -_direction, 260.0)
			Vfx.spark(global_position, Color.WHITE.lerp(tint, 0.4), 6, Vector2.ZERO, 200.0)
		EnemyShotData.Head.SKULL:
			Vfx.spark(global_position, shell_tint.lightened(0.15), sparks, Vector2.UP, 46.0)
			Vfx.spark(global_position, core_tint, 4, -_direction, 120.0)
		EnemyShotData.Head.LEAF:
			Vfx.spark(global_position, core_tint, sparks - 4, Vector2.DOWN, 70.0)
		EnemyShotData.Head.GEAR, EnemyShotData.Head.BELL:
			Vfx.spark(global_position, core_tint, sparks, -_direction, 220.0)
			Vfx.ring(global_position, radius * 1.3, Color(tint, 0.55), 0.42, 3.0)
		_:
			Vfx.spark(global_position, core_tint, sparks, -_direction, 180.0)
	Vfx.ring(global_position, radius * 0.58, Color(core_tint, 0.82), 0.20, 2.5)
	Vfx.ring(global_position, radius, Color(tint, 0.66), 0.34, 5.0)
	Vfx.flash_at(global_position, Color(core_tint, 0.72),
		Balance.ENEMY_PROJECTILE_HEAD_RADIUS * 2.2 * head_scale)
	# **And the forged sheet for this kind of shot**, in its own core colour.
	# Five kinds, five sheets: a bolt's clean ring, a spray's speckled cloud,
	# a mortar's flat ellipse on the ground, a lance's streak along its line,
	# a hex's slow churn. It is the shape of the blow being drawn, never its
	# size - the damage was dealt above and nothing here reads it.
	Vfx.forge_play(_FORGED_BY_KIND.get(kind, "shot_bolt"), global_position,
		radius * 2.2, Color(core_tint, 0.85), _direction.angle())


## **The picture, and only the picture.** The sway and the spin are applied to
## the drawing's transform, never to `global_position`, so a shot that wobbles
## still hits exactly where it flies - the bound every tower shot style is held
## to, in the other direction.
func _draw_measured() -> void:
	var pulse: float = sin(_life * Balance.ENEMY_PROJECTILE_PULSE_SPEED) * 0.5 + 0.5
	var size: float = Balance.ENEMY_PROJECTILE_HEAD_RADIUS * head_scale
	# Drawn in the node's own frame, which already faces the flight: a sway is
	# across the path, so it is the local y.
	var sway: Vector2 = Vector2(0.0, sin(_life * 11.0) * wobble)
	var turn: float = _life * spin * TAU
	draw_circle(sway, size * (1.55 + pulse * 0.16), Color(tint, 0.12 + pulse * 0.08))
	draw_set_transform(sway, turn, Vector2.ONE)
	match head:
		EnemyShotData.Head.ORB:
			draw_circle(Vector2.ZERO, size * 1.05, shell_tint)
			draw_arc(Vector2.ZERO, size * 1.05, 0.0, TAU, 20, Color(tint, 0.9), 1.6, true)
			draw_circle(Vector2(size * 0.15, -size * 0.15), size * (0.5 + pulse * 0.08), core_tint)
		EnemyShotData.Head.DART:
			var dart := PackedVector2Array([
				Vector2(size * 2.4, 0.0), Vector2(size * 0.6, -size * 0.55),
				Vector2(-size * 1.6, -size * 0.3), Vector2(-size * 1.9, 0.0),
				Vector2(-size * 1.6, size * 0.3), Vector2(size * 0.6, size * 0.55)])
			draw_colored_polygon(dart, shell_tint)
			draw_polyline(_closed(dart), Color(tint, 0.95), 1.5, true)
			draw_line(Vector2(size * 2.2, 0.0), Vector2(-size * 1.2, 0.0), core_tint, 2.0, true)
		EnemyShotData.Head.SHARD:
			var shard := PackedVector2Array([
				Vector2(size * 1.7, 0.0), Vector2(size * 0.3, -size * 0.9),
				Vector2(-size * 0.9, -size * 0.5), Vector2(-size * 1.3, size * 0.2),
				Vector2(-size * 0.2, size * 0.95), Vector2(size * 0.8, size * 0.5)])
			draw_colored_polygon(shard, shell_tint)
			draw_polyline(_closed(shard), Color(core_tint, 0.95), 1.6, true)
			draw_line(shard[1], shard[4], Color(core_tint, 0.7), 1.2, true)
			draw_circle(Vector2(size * 0.3, 0.0), size * 0.3, Color.WHITE.lerp(core_tint, 0.4))
		EnemyShotData.Head.STONE:
			var stone := PackedVector2Array()
			for index: int in 8:
				var angle: float = float(index) / 8.0 * TAU
				var bump: float = 0.85 + 0.25 * sin(float(index) * 2.7 + 0.8)
				stone.append(Vector2(cos(angle), sin(angle)) * size * 1.15 * bump)
			draw_colored_polygon(stone, shell_tint)
			draw_polyline(_closed(stone), shell_tint.darkened(0.45), 2.0, true)
			draw_circle(Vector2(-size * 0.2, -size * 0.25), size * 0.35, shell_tint.lightened(0.25))
		EnemyShotData.Head.SKULL:
			draw_circle(Vector2(size * 0.1, -size * 0.1), size * 1.0, shell_tint.lightened(0.55))
			draw_rect(Rect2(-size * 0.5, size * 0.55, size * 1.0, size * 0.55), shell_tint.lightened(0.45))
			draw_circle(Vector2(size * 0.45, -size * 0.25), size * 0.3, core_tint)
			draw_circle(Vector2(-size * 0.25, -size * 0.25), size * 0.3, core_tint)
			draw_line(Vector2(-size * 0.4, size * 0.75), Vector2(size * 0.4, size * 0.75),
				shell_tint.darkened(0.3), 1.5, true)
		EnemyShotData.Head.LEAF:
			var leaf := PackedVector2Array()
			for index: int in 12:
				var t: float = float(index) / 12.0 * TAU
				leaf.append(Vector2(cos(t) * size * 1.9, sin(t) * size * 0.75))
			draw_colored_polygon(leaf, shell_tint)
			draw_polyline(_closed(leaf), Color(tint, 0.9), 1.4, true)
			draw_line(Vector2(size * 1.7, 0.0), Vector2(-size * 1.7, 0.0), core_tint, 1.6, true)
		EnemyShotData.Head.BOLA:
			draw_line(Vector2(-size * 1.4, 0.0), Vector2(size * 1.4, 0.0), shell_tint.lightened(0.3), 2.2, true)
			draw_circle(Vector2(size * 1.4, 0.0), size * 0.65, shell_tint)
			draw_circle(Vector2(-size * 1.4, 0.0), size * 0.65, shell_tint)
			draw_arc(Vector2(size * 1.4, 0.0), size * 0.65, 0.0, TAU, 12, Color(tint, 0.9), 1.4, true)
			draw_arc(Vector2(-size * 1.4, 0.0), size * 0.65, 0.0, TAU, 12, Color(tint, 0.9), 1.4, true)
		EnemyShotData.Head.FLAME:
			var flick: float = 1.0 + sin(_life * 27.0) * 0.18
			var flame := PackedVector2Array([
				Vector2(size * 1.1, 0.0), Vector2(size * 0.2, -size * 0.8 * flick),
				Vector2(-size * 1.4 * flick, -size * 0.35), Vector2(-size * 2.2 * flick, 0.0),
				Vector2(-size * 1.4 * flick, size * 0.35), Vector2(size * 0.2, size * 0.8 * flick)])
			draw_colored_polygon(flame, Color(tint, 0.9))
			draw_circle(Vector2(size * 0.35, 0.0), size * (0.55 + pulse * 0.1), core_tint)
			draw_circle(Vector2(size * 0.5, 0.0), size * 0.25, Color.WHITE.lerp(core_tint, 0.3))
		EnemyShotData.Head.RING:
			draw_arc(Vector2.ZERO, size * 1.2, 0.0, TAU, 24, shell_tint, size * 0.55, true)
			draw_arc(Vector2.ZERO, size * 1.2, 0.0, TAU, 24, Color(tint, 0.95), size * 0.22, true)
			draw_circle(Vector2.ZERO, size * (0.3 + pulse * 0.1), core_tint)
		EnemyShotData.Head.BELL:
			var bell := PackedVector2Array([
				Vector2(size * 0.9, -size * 1.1), Vector2(size * 1.3, size * 0.4),
				Vector2(size * 1.3, size * 0.8), Vector2(-size * 1.3, size * 0.8),
				Vector2(-size * 1.3, size * 0.4), Vector2(-size * 0.9, -size * 1.1)])
			draw_colored_polygon(bell, shell_tint)
			draw_polyline(_closed(bell), Color(tint, 0.95), 1.6, true)
			draw_circle(Vector2(0.0, -size * 1.1), size * 0.35, shell_tint)
			draw_circle(Vector2(0.0, size * 0.85), size * 0.3, core_tint)
		EnemyShotData.Head.GEAR:
			for index: int in 8:
				var angle: float = float(index) / 8.0 * TAU
				var tooth: Vector2 = Vector2(cos(angle), sin(angle)) * size * 1.25
				draw_rect(Rect2(tooth - Vector2.ONE * size * 0.28, Vector2.ONE * size * 0.56), shell_tint)
			draw_circle(Vector2.ZERO, size * 1.05, shell_tint)
			draw_arc(Vector2.ZERO, size * 1.05, 0.0, TAU, 20, Color(tint, 0.9), 1.6, true)
			draw_circle(Vector2.ZERO, size * 0.4, core_tint)
			draw_circle(Vector2.ZERO, size * 0.18, shell_tint)
		_:
			var shell := PackedVector2Array([
				Vector2(size * 1.35, 0.0), Vector2(0.0, -size),
				Vector2(-size * 1.05, 0.0), Vector2(0.0, size)])
			draw_colored_polygon(shell, shell_tint)
			draw_polyline(_closed(shell), Color(tint, 0.92), 1.8, true)
			draw_circle(Vector2(size * 0.12, 0.0), size * (0.42 + pulse * 0.08), core_tint)
			var rune_spin: float = _life * Balance.ENEMY_PROJECTILE_PULSE_SPEED * 0.55
			draw_arc(Vector2.ZERO, Balance.ENEMY_PROJECTILE_RUNE_RADIUS * head_scale, rune_spin,
				rune_spin + PI * 0.72, 12, Color(core_tint, 0.78),
				Balance.ENEMY_PROJECTILE_RUNE_WIDTH, true)
			draw_arc(Vector2.ZERO, Balance.ENEMY_PROJECTILE_RUNE_RADIUS * head_scale, rune_spin + PI,
				rune_spin + PI * 1.72, 12, Color(tint, 0.68),
				Balance.ENEMY_PROJECTILE_RUNE_WIDTH, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = points.duplicate()
	out.append(points[0])
	return out


static func _trail_taper() -> Curve:
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 0.05))
	taper.add_point(Vector2(0.70, 0.58))
	taper.add_point(Vector2(1.0, 1.0))
	return taper


static func _combat_origin(node: Node2D) -> Vector2:
	if node.has_method("combat_origin"):
		var origin: Variant = node.call("combat_origin")
		if origin is Vector2:
			return origin as Vector2
	return node.global_position


## The ribbon behind the head, in world space so it stays put as the head
## moves, and additive so it reads as light: the shell colour tapering to
## nothing at the tail with the core colour as a filament inside it.
func draw_ribbon(on: CanvasItem) -> void:
	if _history.size() < 2:
		return
	var inverse: Transform2D = on.get_global_transform().affine_inverse()
	InkRibbon.ribbon(on, _history, inverse, Balance.ENEMY_PROJECTILE_WIDTH * trail_scale,
		Color(shell_tint, 0.90), 0.0, 1.0)
	InkRibbon.ribbon(on, _history, inverse,
		Balance.ENEMY_PROJECTILE_FILAMENT_WIDTH * trail_scale, Color(core_tint, 0.88), 0.0, 1.0)


class EnemyShotGlow extends Node2D:
	var shot: EnemyProjectile = null

	func _ready() -> void:
		top_level = true
		# Under the head, absolutely (a child draws after its parent).
		z_as_relative = false
		z_index = Balance.VFX_Z - 2
		var material := CanvasItemMaterial.new()
		material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		self.material = material

	func _draw() -> void:
		if shot != null and is_instance_valid(shot):
			shot.draw_ribbon(self)


## `FrameProfile` bucket "eshot": the real work is `_process_measured` above.
func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	_process_measured(delta)
	FrameProfile.add(&"eshot", started)


## `FrameProfile` bucket "eshot_draw": the real work is `_draw_measured` above.
func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	_draw_measured()
	FrameProfile.add(&"eshot_draw", started)
