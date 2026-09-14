class_name EnemyGroundStrike
extends Node2D

## A blow the enemy throws at a *place*: telegraphed, then resolved.
##
## Two shapes, and both are dodged rather than blocked - a circle you leave and
## a line you step off. That is the whole reason this exists: before 2026-09-13
## every ranged enemy in the game fired the identical straight bolt, so there
## was exactly one ranged answer to learn and the fourteen breeds that fire were
## distinguishable only by their sprites.
##
## **It is a node rather than a timer on the enemy** for two reasons. A blow
## that was already thrown must land even if the thrower is killed during the
## tell - otherwise the correct play against every ranged breed is to kill it
## after it commits, which makes the telegraph a reward for the player rather
## than a warning. And it lives under the battlefield, so it freezes with the
## battlefield for a raid (working rule 8) without anything having to know it
## exists.
##
## The tell is drawn from the damage's own numbers - the same rule the boss
## slam and the hero's ranged spells are built under. A ring at a radius the
## blow will not use is worse than no ring at all.

enum Shape { CIRCLE, LINE }

var shape: int = Shape.CIRCLE
var damage: float = 0.0
## How long the player has between the tell and the blow.
var delay: float = 0.0
## CIRCLE: the radius struck. LINE: how far the line reaches.
var reach: float = 0.0
## LINE only: how far either side of the line counts as on it.
var half_width: float = 0.0
## LINE only: the direction the line runs, from this node's position.
var aim: Vector2 = Vector2.RIGHT
var tint: Color = Color(1.0, 0.5, 0.3, 1.0)
## Said out loud when the blow lands, so a debrief can name what killed you.
var blamed_on: String = ""
## How hard this throws whoever it catches, in px/s. Zero for every shot the
## roster fires: a bolt that moved you would be a second mechanic to learn on
## top of the five shapes, and the shapes are the lesson.
var knockback: float = 0.0

var _left: float = 0.0
var _drawn: bool = false


func _ready() -> void:
	z_index = Balance.VFX_Z - 2
	_left = maxf(delay, 0.05)
	_tell()
	queue_redraw()


func _process(delta: float) -> void:
	_left -= delta
	queue_redraw()
	if _left <= 0.0:
		_land()
		queue_free()


## The warning, drawn at exactly what the blow will do.
func _tell() -> void:
	if _drawn:
		return
	_drawn = true
	if shape == Shape.CIRCLE:
		Vfx.ring(global_position, reach, Color(tint, 0.5), _left, 5.0)
	Sfx.play("sfx_spell_cast", -9.0)


## Everything of the player's inside the shape takes it.
func _land() -> void:
	EventBus.camera_impact.emit(global_position, Balance.ENEMY_SHOT_IMPACT_SHARE)
	if shape == Shape.CIRCLE:
		Vfx.ring(global_position, reach, Color(tint, 0.82), 0.28, 6.0)
		Vfx.dust(global_position, Color(tint.r * 0.5, tint.g * 0.45, tint.b * 0.4), 10, reach * 0.6)
	else:
		var tip: Vector2 = global_position + aim * reach
		Vfx.spark(tip, tint, 8, aim, 220.0)
		Vfx.flash_at(global_position + aim * reach * 0.5, Color(tint, 0.5), half_width * 2.0)
	strike_the_players(get_tree(), damage, blamed_on, func(at: Vector2) -> bool:
		return _covers(at), knockback, global_position)


## Whether a point is inside this blow.
func _covers(at: Vector2) -> bool:
	if shape == Shape.CIRCLE:
		return global_position.distance_to(at) <= reach
	var along: float = (at - global_position).dot(aim)
	if along < 0.0 or along > reach:
		return false
	return absf((at - global_position).cross(aim)) <= half_width


## **One place that knows what "everything of the player's" means.**
##
## Heroes and their spirits, never the town and never a tower: an area blow that
## also hit the wall would double every siege number the acts are tuned against,
## and a ranged breed whose target *is* the wall falls back to an ordinary bolt
## rather than coming through here at all.
##
## Static and shared, because the boss slam wants exactly this and had its own
## copy of it. Two copies of "who counts as the player" is how one of them ends
## up forgetting about companions.
## `push` throws whoever it catches away from `thrown_from`, in px/s. It is the
## one thing here that is not damage, and it is bounded at the hero
## (`Balance.shove_ceiling`) rather than trusted to the caller. A spirit is not
## thrown at all: a companion is a follower with no momentum of its own, and a
## shove would only fight its own steering.
static func strike_the_players(tree: SceneTree, amount: float, blame: String,
		covers: Callable, push: float = 0.0,
		thrown_from: Vector2 = Vector2.ZERO) -> int:
	var struck: int = 0
	for node: Node in tree.get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not is_instance_valid(who) or not who.is_alive():
			continue
		if not bool(covers.call(who.global_position)):
			continue
		var health: Health = Health.of(who)
		if health == null:
			continue
		if not blame.is_empty():
			RunState.note_blow(blame, amount)
		health.take_damage(amount, who.global_position)
		if push > 0.0:
			# Standing exactly on the centre has no direction to be thrown in,
			# so the blow picks one rather than dropping the shove in silence.
			var away: Vector2 = who.global_position - thrown_from
			if away.is_zero_approx():
				away = Vector2.DOWN
			who.shove(away.normalized() * push)
		struck += 1
	for node: Node in tree.get_nodes_in_group(Companion.GROUP):
		var pet := node as Companion
		if pet == null or not is_instance_valid(pet) or not pet.is_alive():
			continue
		if not bool(covers.call(pet.global_position)):
			continue
		# A spirit takes less from a blow aimed at the ground than the person
		# standing on it. It is smaller and it is not the target.
		pet.take_damage(amount * Balance.ENEMY_SHOT_SPIRIT_SHARE, pet.global_position)
		struck += 1
	return struck


func _draw() -> void:
	var ratio: float = 1.0 - clampf(_left / maxf(delay, 0.001), 0.0, 1.0)
	if shape == Shape.CIRCLE:
		# The circle fills from the middle out, so the player reads how long
		# they have without counting anything.
		draw_circle(Vector2.ZERO, reach * ratio, Color(tint, 0.14))
		draw_arc(Vector2.ZERO, reach, 0.0, TAU, 48, Color(tint, 0.55), 2.4, true)
		return
	var side: Vector2 = aim.orthogonal() * half_width
	var strip := PackedVector2Array([
		side, aim * reach + side, aim * reach - side, -side])
	draw_colored_polygon(strip, Color(tint, 0.10 + ratio * 0.16))
	draw_polyline(PackedVector2Array([side, aim * reach + side]), Color(tint, 0.6), 1.8, true)
	draw_polyline(PackedVector2Array([-side, aim * reach - side]), Color(tint, 0.6), 1.8, true)
	# And a bright leading edge that runs the length of the line as it charges.
	var head: Vector2 = aim * reach * ratio
	draw_line(head + side, head - side, Color(tint, 0.85), 2.6, true)
