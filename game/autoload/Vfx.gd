extends Node

## Every transient visual in the game: sparks, damage numbers, muzzle flashes,
## rings, screen flashes.
##
## It listens on EventBus and draws itself. No system calls it to say "make a
## spark" — the tower says `tower_fired`, the enemy says `enemy_died`, and this
## decides what that looks like. That keeps the feedback layer entirely
## removable and stops combat code filling up with cosmetic calls.
##
## Everything is drawn from primitives (Line2D, Polygon2D, Label) rather than
## from particle textures, because the project has no VFX art and a spark made
## of two triangles is indistinguishable from one made of a PNG at this size.
##
## `world` is set by whichever scope is active. Screen-space effects need no
## world and work regardless.

## Where world-space effects are parented. Set by Battlefield and RaidArena.
var world: Node2D = null

## Effects live under a container of their own rather than directly in the
## scope, so the cap can be enforced by counting children. An earlier version
## kept an Array[Node] of live effects and hit "invalid previously freed
## instance" constantly: tweens free their own node, and simply *iterating* a
## typed array that contains a freed object is an error in GDScript. Holding no
## references at all is the fix, not guarding each one with is_instance_valid.
var _container: Node2D = null

var _screen: CanvasLayer
var _flash: ColorRect
var _vignette: ColorRect
var _flash_left: float = 0.0
var _flash_total: float = 0.0
var _flash_peak: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_screen_layer()

	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.hero_attack_landed.connect(_on_attack_landed)
	EventBus.hero_damaged.connect(_on_hero_damaged)
	EventBus.town_damaged.connect(_on_town_damaged)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.war_horn_activated.connect(_on_horn)
	EventBus.raid_available.connect(_on_raid_available)
	EventBus.hero_health_changed.connect(_on_hero_health)


func _build_screen_layer() -> void:
	_screen = CanvasLayer.new()
	_screen.layer = 90
	add_child(_screen)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.color = Color(1, 1, 1, 0)
	_screen.add_child(_flash)

	# An edge-only red that deepens as the hero bleeds.
	#
	# The first version was a plain full-screen ColorRect, which at low health
	# washed the whole view red and made the game unreadable rather than tense.
	# A vignette has to fall off from the edges, so it needs a radial mask, and
	# the cheapest correct way to get one is a shader.
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(1, 1, 1, 1)

	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.55, 0.05, 0.05, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Where the darkening starts, as a fraction of the half-diagonal. Higher keeps
// the centre of the screen clear.
uniform float inner : hint_range(0.0, 1.0) = 0.42;

void fragment() {
	// Distance from screen centre, normalised so the corners sit at 1.0.
	float d = length(UV - vec2(0.5)) / 0.7071;
	float edge = smoothstep(inner, 1.0, d);
	COLOR = vec4(tint.rgb, edge * strength);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("strength", 0.0)
	_vignette.material = material
	_screen.add_child(_vignette)


func _process(delta: float) -> void:
	if _flash_left <= 0.0:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	var t: float = _flash_left / maxf(_flash_total, 0.001)
	_flash.color.a = _flash_peak * t * t


## Called by a scope when it becomes the active world.
func bind_world(node: Node2D) -> void:
	world = node
	_container = null
	if node == null:
		return
	_container = Node2D.new()
	_container.name = "VfxLayer"
	_container.z_index = Balance.VFX_Z
	node.add_child(_container)


func clear() -> void:
	if _container != null and is_instance_valid(_container):
		for child: Node in _container.get_children():
			child.queue_free()


## Parents an effect and enforces the cap by freeing the oldest child. Children
## are ordered by insertion, so child 0 is always the oldest still alive.
func _track(node: Node) -> void:
	var parent: Node2D = _container if (_container != null and is_instance_valid(_container)) else world
	if parent == null:
		node.queue_free()
		return
	parent.add_child(node)
	while parent.get_child_count() > Balance.VFX_MAX_LIVE:
		parent.get_child(0).queue_free()
		# queue_free is deferred, so the child is still counted this frame.
		# Reparenting it out keeps the loop from spinning on the same node.
		parent.remove_child(parent.get_child(0))


# ==============================================================================
# Primitives
# ==============================================================================

## A burst of shards flying outward. `direction` biases the spray; pass ZERO for
## an even burst.
func spark(at: Vector2, colour: Color, count: int = 8, direction: Vector2 = Vector2.ZERO, speed: float = 260.0) -> void:
	if world == null:
		return
	for i: int in count:
		var angle: float
		if direction == Vector2.ZERO:
			angle = randf() * TAU
		else:
			angle = direction.angle() + randf_range(-Balance.VFX_SPARK_SPREAD, Balance.VFX_SPARK_SPREAD)
		var dir: Vector2 = Vector2.RIGHT.rotated(angle)
		var length: float = randf_range(6.0, 16.0)

		var shard := Line2D.new()
		shard.points = PackedVector2Array([Vector2.ZERO, dir * length])
		shard.width = randf_range(2.0, 4.0)
		shard.default_color = colour
		shard.z_index = Balance.VFX_Z
		_track(shard)
		shard.global_position = at

		var travel: float = speed * randf_range(0.5, 1.2)
		var life: float = Balance.VFX_SPARK_LIFE * randf_range(0.7, 1.3)
		var tween: Tween = shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", at + dir * travel, life)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(shard, "modulate:a", 0.0, life)
		tween.chain().tween_callback(shard.queue_free)


## An expanding ring. Reads as force in a way a flash does not.
func ring(at: Vector2, to_radius: float, colour: Color, life: float = 0.35, width: float = 4.0) -> void:
	if world == null:
		return
	var line := Line2D.new()
	var points: PackedVector2Array = []
	for i: int in 33:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 32.0))
	line.points = points
	line.width = width
	line.default_color = colour
	line.scale = Vector2.ONE * 4.0
	line.z_index = Balance.VFX_Z
	_track(line)
	line.global_position = at

	var tween: Tween = line.create_tween()
	tween.set_parallel(true)
	tween.tween_property(line, "scale", Vector2.ONE * to_radius, life)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(line, "modulate:a", 0.0, life)
	tween.chain().tween_callback(line.queue_free)


## Floating damage text. Rises, drifts and fades.
func number(at: Vector2, amount: float, colour: Color, big: bool = false) -> void:
	if world == null or amount < 1.0:
		return
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.add_theme_font_size_override("font_size", Balance.VFX_NUMBER_SIZE_BIG if big else Balance.VFX_NUMBER_SIZE)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 6)
	label.z_index = Balance.VFX_Z + 1
	_track(label)
	label.global_position = at + Vector2(randf_range(-14.0, 14.0), -20.0)

	var drift: Vector2 = Vector2(randf_range(-26.0, 26.0), -Balance.VFX_NUMBER_RISE)
	var life: float = Balance.VFX_NUMBER_LIFE
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + drift, life)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "modulate:a", 0.0, life).set_delay(life * 0.45)
	if big:
		# A crit punches up before settling, so it reads before you can count it.
		tween.tween_property(label, "scale", Vector2.ONE * 1.45, life * 0.18)\
			.set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(label, "scale", Vector2.ONE, life * 0.3)
	tween.chain().tween_callback(label.queue_free)


## A short bright cone where a tower fired from.
func muzzle(at: Vector2, direction: Vector2, colour: Color) -> void:
	if world == null:
		return
	var flash := Polygon2D.new()
	var length: float = Balance.VFX_MUZZLE_LENGTH
	var spread: float = Balance.VFX_MUZZLE_WIDTH
	flash.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(length, -spread),
		Vector2(length * 1.15, 0.0),
		Vector2(length, spread),
	])
	flash.color = colour
	flash.rotation = direction.angle()
	flash.z_index = Balance.VFX_Z
	_track(flash)
	flash.global_position = at

	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, Balance.VFX_MUZZLE_LIFE)
	tween.tween_property(flash, "scale", Vector2(1.35, 0.5), Balance.VFX_MUZZLE_LIFE)
	tween.chain().tween_callback(flash.queue_free)


## A wedge sweeping through the hero's swing arc.
func slash(at: Vector2, direction: Vector2, reach: float, arc_degrees: float, colour: Color) -> void:
	if world == null:
		return
	var wedge := Polygon2D.new()
	var points: PackedVector2Array = [Vector2.ZERO]
	var half: float = deg_to_rad(arc_degrees * 0.5)
	for i: int in 13:
		var a: float = lerpf(-half, half, float(i) / 12.0)
		points.append(Vector2.RIGHT.rotated(a) * reach)
	wedge.polygon = points
	wedge.color = colour
	wedge.rotation = direction.angle() - half * 0.6
	wedge.z_index = Balance.VFX_Z
	_track(wedge)
	wedge.global_position = at

	var tween: Tween = wedge.create_tween()
	tween.set_parallel(true)
	tween.tween_property(wedge, "rotation", direction.angle() + half * 0.6, Balance.VFX_SLASH_LIFE)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(wedge, "modulate:a", 0.0, Balance.VFX_SLASH_LIFE)
	tween.chain().tween_callback(wedge.queue_free)


## A brief bloom at a world position. Distinct from `spark`: this is the light
## of an impact rather than its debris, and it is what makes a hit feel hot.
func flash_at(at: Vector2, colour: Color, radius: float) -> void:
	if world == null:
		return
	var blob := Polygon2D.new()
	var points: PackedVector2Array = []
	for i: int in 12:
		points.append(Vector2.RIGHT.rotated(TAU * float(i) / 12.0) * radius)
	blob.polygon = points
	blob.color = Color(colour.lerp(Color.WHITE, 0.6), 0.85)
	blob.z_index = Balance.VFX_Z
	_track(blob)
	blob.global_position = at

	var tween: Tween = blob.create_tween()
	tween.set_parallel(true)
	tween.tween_property(blob, "scale", Vector2.ONE * 1.9, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(blob, "modulate:a", 0.0, 0.16)
	tween.chain().tween_callback(blob.queue_free)


## Full-screen colour wash. Decays quadratically so it snaps rather than smears.
func flash(colour: Color, peak: float, life: float) -> void:
	if peak <= _flash_peak * (_flash_left / maxf(_flash_total, 0.001)):
		return
	_flash.color = Color(colour.r, colour.g, colour.b, peak)
	_flash_peak = peak
	_flash_total = life
	_flash_left = life


# ==============================================================================
# EventBus reactions
# ==============================================================================

func _on_tower_fired(lane: int, slot: int, at: Vector2) -> void:
	var tower: TowerData = RunState.tower_in_slot(lane, slot)
	if tower == null or world == null:
		return
	var origin: Vector2 = Battlefield.slot_position(lane, slot)
	var colour: Color = TowerData.element_colour(tower.element)
	muzzle(origin, (at - origin).normalized(), colour)


func _on_attack_landed(chain_step: int, targets: int, at: Vector2) -> void:
	var hero: Node = get_tree().get_first_node_in_group(&"hero")
	var aim: Vector2 = Vector2.RIGHT
	if hero is Hero:
		aim = (hero as Hero).aim_direction()
	var finisher: bool = chain_step >= Balance.HERO_CHAIN_LENGTH - 1

	slash(at, aim, Balance.HERO_ATTACK_RANGE[chain_step],
		Balance.HERO_ATTACK_ARC_DEGREES[chain_step],
		Color(0.95, 0.88, 0.72, 0.28 if finisher else 0.18))
	spark(at + aim * 60.0, Color("ffd9a0"), 6 + targets * 2, aim,
		320.0 if finisher else 220.0)
	if finisher:
		ring(at, 70.0, Color(1.0, 0.82, 0.5, 0.55), 0.3, 5.0)


func _on_enemy_died(_enemy_id: String, at: Vector2) -> void:
	spark(at, Color("c96a4a"), 10, Vector2.ZERO, 200.0)
	ring(at, 34.0, Color(0.85, 0.45, 0.3, 0.4), 0.28, 3.0)


func _on_hero_damaged(amount: float, from: Vector2) -> void:
	var hero: Node = get_tree().get_first_node_in_group(&"hero")
	if hero is Node2D:
		var pos: Vector2 = (hero as Node2D).global_position
		number(pos, amount, Color("ff6b5a"), true)
		spark(pos, Color("ff8a7a"), 8, (pos - from).normalized(), 200.0)
	flash(Color(0.75, 0.1, 0.08), Balance.VFX_HURT_FLASH, 0.28)


## The town taking a hit is the loudest thing that can happen: it is the only
## damage in the game the player cannot heal.
func _on_town_damaged(amount: float, current_hp: float, max_hp: float) -> void:
	flash(Color(0.8, 0.15, 0.1), Balance.VFX_TOWN_FLASH, 0.4)
	EventBus.camera_shake_requested.emit(Balance.VFX_TOWN_SHAKE, 0.35)
	if world != null:
		number(Vector2.ZERO, amount, Color("ff5a48"), true)
		ring(Vector2.ZERO, Balance.TOWN_RADIUS * 1.4, Color(0.9, 0.3, 0.2, 0.5), 0.5, 6.0)
	# A harder flash once the town is genuinely in danger.
	if max_hp > 0.0 and current_hp / max_hp < Balance.VFX_TOWN_CRITICAL:
		flash(Color(0.9, 0.1, 0.05), Balance.VFX_TOWN_FLASH * 1.6, 0.6)


func _on_spell_cast(_spell_id: String, _slot: int, at: Vector2) -> void:
	ring(at, 120.0, Color(0.72, 0.62, 0.95, 0.6), 0.45, 5.0)
	spark(at, Color("b8a8f0"), 14, Vector2.ZERO, 300.0)


func _on_boss_spawned(_boss_id: String, _act: int) -> void:
	flash(Color(0.6, 0.1, 0.1), 0.5, 1.0)


func _on_horn(_duration: float) -> void:
	flash(Color(0.75, 0.35, 0.12), 0.35, 0.8)


func _on_raid_available(_weakened_for: float) -> void:
	flash(Color(0.55, 0.45, 0.85), 0.32, 0.7)


## The vignette tracks health continuously rather than on damage, so it is
## already dark when the player is low instead of pulsing only on hits.
func _on_hero_health(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		return
	var ratio: float = current / maximum
	var danger: float = clampf(1.0 - ratio / Balance.VFX_VIGNETTE_THRESHOLD, 0.0, 1.0)
	var material: ShaderMaterial = _vignette.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("strength", danger * Balance.VFX_VIGNETTE_MAX)
