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

## Blood on the ground. Outlives individual effects, so it is kept apart from
## them - see `bind_world`.
var _ground: BloodField = null

## Spatter shapes are cosmetic, so they draw from their own stream rather than
## the run's seeded one - blood must never move a gameplay roll.
var _blood_rng := RandomNumberGenerator.new()

var _screen: CanvasLayer
var _flash: ColorRect
var _vignette: ColorRect
var _flash_left: float = 0.0
var _flash_total: float = 0.0
var _flash_peak: float = 0.0

## Town damage arrives one hit at a time, and once a lane breaks there can be
## half a dozen enemies on the wall at once. Ungated, the full-screen flash was
## retriggered before it had a chance to decay, so it stopped being a flash: the
## screen simply *sat* red — at 54% opacity once the town was critical — for as
## long as anything was hitting it. Unreadable exactly when the player most needs
## to see what is happening.
##
## So the reaction is coalesced. Hits inside the window accumulate, and one burst
## at the end of it reports the total. The information is the same; it just
## arrives as a heartbeat rather than as a wall of red.
var _town_cooldown: float = 0.0
var _town_pending: float = 0.0
var _town_critical: bool = false


## Elemental impact art, derived from the element name like every other asset
## path in the project.
const IMPACT_ART_FORMAT: String = "res://art/vfx/impact_%s.png"
const BLOOD_ART_PATH: String = "res://art/vfx/blood_splatter.png"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_screen_layer()

	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.hero_attack_landed.connect(_on_attack_landed)
	EventBus.hero_swing_resolved.connect(_on_swing_resolved)
	EventBus.hero_damaged.connect(_on_hero_damaged)
	EventBus.town_damaged.connect(_on_town_damaged)
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.construction_completed.connect(_on_construction_completed)
	EventBus.relic_socketed.connect(_on_relic_socketed)
	EventBus.war_horn_activated.connect(_on_horn)
	EventBus.raid_available.connect(_on_raid_available)
	EventBus.hero_health_changed.connect(_on_hero_health)
	EventBus.command_order_used.connect(_on_command_order_used)
	# The four completions that had no answer at all. Everything that *fires*,
	# *lands* or *dies* was already spoken for; finishing something was not, which
	# meant surviving a wave and levelling up both happened in silence.
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.boss_defeated.connect(_on_boss_defeated_juice)
	EventBus.hero_levelled.connect(_on_hero_levelled)
	EventBus.hero_respawned.connect(_on_hero_respawned)
	# The vignette is driven by health, so with no hero left to report any, it
	# keeps whatever it was last told. Dying at the end of a run therefore
	# carried the red edge onto the main menu and stayed there - reported from
	# play, and invisible to anything that only ever looks at the battlefield.
	EventBus.run_ended.connect(func(_won: bool, _s: Dictionary) -> void:
		clear_vignette())
	EventBus.run_started.connect(func() -> void: clear_vignette())


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
	if _town_cooldown > 0.0:
		_town_cooldown = maxf(_town_cooldown - delta, 0.0)
		if _town_cooldown <= 0.0 and _town_pending > 0.0:
			_burst_town_damage(_town_pending)
			_town_pending = 0.0
			_town_cooldown = Balance.VFX_TOWN_FLASH_COOLDOWN

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

	# **Its own node, not a child of the effects layer.** `_track` evicts the
	# oldest child once the layer is full, which is right for transients and
	# wrong for a stain: a busy wave would quietly delete the blood it had just
	# spilled to make room for the sparks of the next hit.
	_ground = BloodField.new()
	_ground.name = "BloodField"
	node.add_child(_ground)


func clear() -> void:
	if _container != null and is_instance_valid(_container):
		for child: Node in _container.get_children():
			child.queue_free()
	if _ground != null and is_instance_valid(_ground):
		_ground.wipe()
	clear_vignette()


## Takes the red edge off the screen.
##
## Separate from `clear`, because the two are cleared at different moments: the
## effect layer goes with the scope it was drawn in, and the vignette goes with
## the *run*. A scope change must not wipe the warning that the hero is nearly
## dead.
func clear_vignette() -> void:
	if _vignette == null or not is_instance_valid(_vignette):
		return
	var material: ShaderMaterial = _vignette.material as ShaderMaterial
	if material != null:
		material.set_shader_parameter("strength", 0.0)


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
	line.default_color = colour
	line.width = width
	line.z_index = Balance.VFX_Z
	_track(line)
	line.global_position = at

	# The ring grows by having its points moved outward, NOT by scaling the node.
	#
	# Line2D width is in local units, so it scales with the transform. Growing a
	# 6px ring to radius 224 by scaling therefore ended it 1344px thick — not a
	# ring but a filled disc, whose polyline joins fanned out as spokes. Under
	# sustained town damage the overlap became a red starburst covering half the
	# map. (Counter-scaling the width does not fix it either: both values ease
	# quadratically, so their product still bulges through the middle of the
	# tween. Only leaving the scale alone actually holds the thickness.)
	#
	# Rebuilding thirty-three points per frame for a handful of live rings costs
	# nothing worth measuring.
	var grow: Callable = func(radius: float) -> void:
		if not is_instance_valid(line):
			return
		var scaled: PackedVector2Array = []
		for point: Vector2 in points:
			scaled.append(point * radius)
		line.points = scaled

	grow.call(4.0)

	var tween: Tween = line.create_tween()
	tween.set_parallel(true)
	tween.tween_method(grow, 4.0, to_radius, life)\
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


## Fast radial strokes: the readable white-hot frame between a bloom and its
## expanding shock ring. One Line2D per ray lets each length and timing vary.
func rays(at: Vector2, colour: Color, count: int = 8, radius: float = 60.0,
		rotation_offset: float = 0.0) -> void:
	if world == null:
		return
	for i: int in count:
		var angle: float = rotation_offset + TAU * float(i) / float(maxi(count, 1)) \
			+ randf_range(-0.08, 0.08)
		var direction := Vector2.RIGHT.rotated(angle)
		var inner: float = radius * randf_range(0.12, 0.24)
		var outer: float = radius * randf_range(0.72, 1.08)
		var ray := Line2D.new()
		ray.points = PackedVector2Array([direction * inner, direction * outer])
		ray.width = randf_range(2.0, 4.5)
		ray.default_color = colour
		ray.z_index = Balance.VFX_Z
		ray.scale = Vector2.ONE * 0.35
		_track(ray)
		ray.global_position = at
		var life: float = Balance.VFX_RAY_LIFE * randf_range(0.8, 1.15)
		var tween: Tween = ray.create_tween()
		tween.set_parallel(true)
		tween.tween_property(ray, "scale", Vector2.ONE, life)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		tween.tween_property(ray, "modulate:a", 0.0, life).set_delay(life * 0.18)
		tween.chain().tween_callback(ray.queue_free)


## Low, soft puffs that anchor impacts to the ground. These are translucent
## octagons rather than opaque particles, keeping busy lanes readable.
func dust(at: Vector2, colour: Color, count: int = 6, radius: float = 54.0) -> void:
	if world == null:
		return
	for i: int in count:
		var puff := Polygon2D.new()
		var points: PackedVector2Array = []
		var size: float = randf_range(5.0, 10.0)
		for point: int in 8:
			points.append(Vector2.RIGHT.rotated(TAU * float(point) / 8.0) \
				* size * randf_range(0.82, 1.15))
		puff.polygon = points
		puff.color = Color(colour.r, colour.g, colour.b, minf(colour.a, 0.42))
		puff.z_index = Balance.VFX_Z - 1
		_track(puff)
		var direction := Vector2.RIGHT.rotated(TAU * float(i) / float(maxi(count, 1)) \
			+ randf_range(-0.35, 0.35))
		puff.global_position = at + direction * randf_range(4.0, 14.0)
		var life: float = Balance.VFX_DUST_LIFE * randf_range(0.8, 1.25)
		var tween: Tween = puff.create_tween()
		tween.set_parallel(true)
		tween.tween_property(puff, "global_position",
			at + direction * radius * randf_range(0.65, 1.1), life)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_property(puff, "scale", Vector2.ONE * randf_range(1.6, 2.5), life)
		tween.tween_property(puff, "modulate:a", 0.0, life)
		tween.chain().tween_callback(puff.queue_free)


## One authored-feeling construction beat shared by new towers and upgrades.
func build_burst(at: Vector2, colour: Color, upgrade: bool = false) -> void:
	dust(at, Color(0.36, 0.28, 0.18, 0.38), 8 if upgrade else 6,
		76.0 if upgrade else 58.0)
	rays(at, colour.lerp(Color.WHITE, 0.45), 10 if upgrade else 7,
		88.0 if upgrade else 62.0, PI * 0.125)
	ring(at, 132.0 if upgrade else 88.0, Color(colour, 0.72),
		0.46 if upgrade else 0.34, 5.0)
	flash_at(at, colour, 38.0 if upgrade else 28.0)
	EventBus.camera_shake_requested.emit(
		Balance.VFX_BUILD_SHAKE * (1.5 if upgrade else 1.0), 0.24)


## World-space phase title; short enough to read without covering combat.
func word(at: Vector2, text: String, colour: Color, size: int = 28) -> void:
	if world == null or text.is_empty():
		return
	var label := Label.new()
	label.text = text.to_upper()
	label.custom_minimum_size = Vector2(240.0, 48.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.025, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	label.z_index = Balance.VFX_Z + 2
	_track(label)
	label.global_position = at + Vector2(-120.0, -94.0)
	label.scale = Vector2.ONE * 0.72
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", label.global_position + Vector2(0.0, -52.0), 0.75)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(label, "scale", Vector2.ONE, 0.18)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.28)
	tween.chain().tween_callback(label.queue_free)


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
## A painted impact burst, scaled and spun in.
##
## Layered over the sparks and the ring rather than replacing them: the sparks
## carry the direction, the ring carries the blast radius, and this carries the
## element. One static frame doing all the work would read as a decal; one frame
## on top of motion that already reads reads as a hit.
##
## Silently does nothing when the element has no art, so a missing file costs the
## same as it did before there was any.
func impact(at: Vector2, element: int, colour: Color, size: float) -> void:
	if world == null:
		return
	var path: String = IMPACT_ART_FORMAT % TowerData.element_name(element).to_lower()
	if not ResourceLoader.exists(path):
		return
	var burst := Sprite2D.new()
	burst.texture = load(path)
	burst.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	burst.add_to_group(Graphics.FILTER_GROUP)
	burst.modulate = Color(colour.lerp(Color.WHITE, 0.45), 0.95)
	burst.z_index = Balance.VFX_Z
	# A different quarter-turn each time, so a lane full of the same tower firing
	# does not stamp the identical picture forty times.
	burst.rotation = TAU * float(randi() % 4) / 4.0
	_track(burst)
	burst.global_position = at

	var start: float = size / maxf(float(burst.texture.get_width()), 1.0)
	burst.scale = Vector2.ONE * start * 0.45
	var tween: Tween = burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2.ONE * start, 0.14).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.26).set_delay(0.06)
	tween.chain().tween_callback(burst.queue_free)


## Optional character-hit layer. The authored splatter is distinct from the
## ordinary spark/number language so disabling gore cannot make a landed attack
## harder to read. Presentation is local on purpose: the guest already derives
## mirrored-hit reactions from authoritative health and enemy deaths are relayed
## as facts, so no cosmetic network packet is required.
func blood(at: Vector2, direction: Vector2, size: float) -> void:
	if world == null or not bool(UserSettings.value(UserSettings.BLOOD_VFX_KEY, true)) \
			or not ResourceLoader.exists(BLOOD_ART_PATH):
		return
	var splatter := Sprite2D.new()
	splatter.texture = load(BLOOD_ART_PATH)
	splatter.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	splatter.add_to_group(Graphics.FILTER_GROUP)
	splatter.modulate = Color(0.88, 0.76, 0.76, 0.92)
	splatter.z_index = Balance.VFX_Z
	splatter.rotation = direction.angle() if direction.length_squared() > 0.001 \
		else randf() * TAU
	_track(splatter)
	splatter.global_position = at

	var final_scale: float = size / maxf(float(splatter.texture.get_width()), 1.0)
	splatter.scale = Vector2.ONE * final_scale * 0.42
	var tween: Tween = splatter.create_tween()
	tween.set_parallel(true)
	tween.tween_property(splatter, "scale", Vector2.ONE * final_scale,
		Balance.VFX_BLOOD_LIFE).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tween.tween_property(splatter, "modulate:a", 0.0,
		Balance.VFX_BLOOD_LIFE).set_delay(Balance.VFX_BLOOD_LIFE * 0.2)
	tween.chain().tween_callback(splatter.queue_free)

	# A few directional motes keep a hit moving even when the source sprite is
	# seen edge-on. This reuses the established transient shard primitive rather
	# than introducing a second permanent blood asset.
	spark(at, Color("9b2d32"), Balance.VFX_BLOOD_SPARKS, direction, size * 2.2)

	# And the ground keeps it. The splash above is gone in a third of a second;
	# this is the part that makes a field read as having been fought over.
	if _ground != null and is_instance_valid(_ground):
		_ground.splat(at, direction, size, _blood_rng)


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

func _on_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	var tower: TowerData = RunState.tower_at(anchor)
	if tower == null or world == null:
		return
	var origin: Vector2 = BattleGrid.footprint_centre(anchor)
	var colour: Color = TowerData.element_colour(tower.element)
	muzzle(origin, (at - origin).normalized(), colour)


## The arc of a swing. Drawn for every swing, including the ones that miss.
##
## **Driven by the swing, not by the hit**, and in co-op those are very
## different events. `hero_attack_landed` only fires when an enemy actually took
## damage, and on a guest no enemy ever does - they belong to the host, so
## `take_damage` refuses and the swing reports nothing hit. The result was a
## guest who could see their partner swing and never themselves: the host, where
## the damage was real, saw both.
##
## `hero_swing_resolved` fires either way and carries the aim of the hero that
## actually swung, which fixes a second bug in the same breath - the aim used to
## come from the first node in the hero group, and with four heroes on the field
## that is whichever one happens to be first.
func _on_swing_resolved(at: Vector2, aim: Vector2, reach: float) -> void:
	var arc: float = Balance.HERO_ATTACK_ARC_DEGREES[0]
	# Reach identifies the chain step, which is what decides how the arc reads.
	for step: int in Balance.HERO_ATTACK_RANGE.size():
		if is_equal_approx(Balance.HERO_ATTACK_RANGE[step], reach):
			arc = Balance.HERO_ATTACK_ARC_DEGREES[step]
			break
	var finisher: bool = is_equal_approx(reach,
		Balance.HERO_ATTACK_RANGE[Balance.HERO_CHAIN_LENGTH - 1])
	slash(at, aim, reach, arc,
		Color(0.95, 0.88, 0.72, 0.28 if finisher else 0.18))


## The impact. Only on a hit, which is correct - sparks come off something.
func _on_attack_landed(chain_step: int, targets: int, at: Vector2) -> void:
	# The hero who actually swung, taken as the one nearest the impact rather
	# than whichever the HUD is following. With four on the field the sparks
	# used to fly along someone else's aim.
	var hero: Hero = Hero.nearest_on_field(get_tree(), at)
	var aim: Vector2 = Vector2.RIGHT
	if hero != null:
		aim = hero.aim_direction()
	var finisher: bool = chain_step >= Balance.HERO_CHAIN_LENGTH - 1

	spark(at + aim * 60.0, Color("ffd9a0"), 6 + targets * 2, aim,
		320.0 if finisher else 220.0)
	if finisher:
		ring(at, 70.0, Color(1.0, 0.82, 0.5, 0.55), 0.3, 5.0)
		rays(at + aim * 46.0, Color(1.0, 0.9, 0.67, 0.85), 9, 68.0, aim.angle())
		flash_at(at + aim * 54.0, Color("ffd99b"), 22.0)


func _on_enemy_died(enemy_id: String, at: Vector2) -> void:
	var data: EnemyData = ContentDB.enemy(enemy_id)
	var colour := Color("c96a4a")
	var spark_count: int = 10
	var radius: float = 34.0
	if data != null:
		match data.category:
			EnemyData.Category.ELITE:
				colour = Color("f2a85d")
				spark_count = 18
				radius = 56.0
			EnemyData.Category.BOSS:
				colour = Color("ff6b6b")
				spark_count = 34
				radius = 104.0
			_:
				pass
	spark(at, colour, spark_count, Vector2.ZERO, 220.0 + radius)
	blood(at, Vector2.ZERO, maxf(Balance.VFX_BLOOD_DEATH_SIZE, radius * 1.05))
	dust(at, Color(0.34, 0.22, 0.18, 0.34), 4 + spark_count / 5, radius * 0.9)
	ring(at, radius, Color(colour, 0.48), 0.28 + radius / 500.0, 3.0 + radius / 35.0)
	flash_at(at, colour, 14.0 + radius * 0.18)
	if data != null and data.category != EnemyData.Category.BREED:
		rays(at, colour.lerp(Color.WHITE, 0.42), 8 if data.category == EnemyData.Category.ELITE else 16,
			radius * 1.25)


func _on_hero_damaged(amount: float, from: Vector2, at: Vector2) -> void:
	number(at, amount, Color("ff6b5a"), true)
	var direction: Vector2 = (at - from).normalized()
	spark(at, Color("ff8a7a"), 8, direction, 200.0)
	blood(at, direction, Balance.VFX_BLOOD_HIT_SIZE)
	flash(Color(0.75, 0.1, 0.08), Balance.VFX_HURT_FLASH, 0.28)


## The town taking a hit is the loudest thing that can happen: it is the only
## damage in the game the player cannot heal.
func _on_town_damaged(amount: float, current_hp: float, max_hp: float) -> void:
	_town_critical = max_hp > 0.0 and current_hp / max_hp < Balance.VFX_TOWN_CRITICAL
	if _town_cooldown > 0.0:
		# Inside the window: fold this hit into the next burst rather than firing
		# a second flash over the top of the one still running.
		_town_pending += amount
		return
	_burst_town_damage(amount)
	_town_cooldown = Balance.VFX_TOWN_FLASH_COOLDOWN


func _burst_town_damage(amount: float) -> void:
	flash(Color(0.8, 0.15, 0.1), Balance.VFX_TOWN_FLASH, 0.4)
	EventBus.camera_shake_requested.emit(Balance.VFX_TOWN_SHAKE, 0.35)
	if world != null:
		number(Vector2.ZERO, amount, Color("ff5a48"), true)
		ring(Vector2.ZERO, Balance.TOWN_RADIUS * 1.4, Color(0.9, 0.3, 0.2, 0.5), 0.5, 6.0)
	# A harder flash once the town is genuinely in danger.
	if _town_critical:
		flash(Color(0.9, 0.1, 0.05), Balance.VFX_TOWN_FLASH * 1.6, 0.6)


func _on_spell_cast(_spell_id: String, _slot: int, at: Vector2) -> void:
	ring(at, 120.0, Color(0.72, 0.62, 0.95, 0.6), 0.45, 5.0)
	spark(at, Color("b8a8f0"), 14, Vector2.ZERO, 300.0)
	rays(at, Color(0.88, 0.82, 1.0, 0.8), 12, 102.0, PI * 0.125)
	flash_at(at, Color("cbbdff"), 34.0)


func _on_wave_started(_wave_number: int, lanes: Array) -> void:
	for value: Variant in lanes:
		var lane: int = int(value)
		var at: Vector2 = Battlefield.lane_spawn_point(lane)
		var inward: Vector2 = -Battlefield.lane_vector(lane)
		dust(at, Color(0.48, 0.35, 0.22, 0.3), 5, 48.0)
		ring(at, 46.0, Color(1.0, 0.42, 0.22, 0.42), 0.3, 3.0)
		spark(at, Color("ff9a58"), 5, inward, 135.0)


func _on_boss_spawned(_boss_id: String, _act: int) -> void:
	flash(Color(0.6, 0.1, 0.1), 0.5, 1.0)


func _on_boss_phase_changed(boss_id: String, phase: int, phase_name: String) -> void:
	var at := Vector2.ZERO
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy := node as Enemy
		if enemy != null and enemy.data != null and enemy.data.id == boss_id:
			at = enemy.global_position
			break
	var colour := Color("ffb05f") if phase <= 1 else Color("ff5f8f")
	flash(colour, 0.34, 0.48)
	rays(at, colour.lerp(Color.WHITE, 0.35), 14, 142.0, float(phase) * 0.2)
	ring(at, 168.0, Color(colour, 0.75), 0.58, 7.0)
	ring(at, 96.0, Color(1.0, 0.92, 0.78, 0.68), 0.34, 4.0)
	dust(at, Color(0.4, 0.18, 0.16, 0.38), 12, 118.0)
	word(at, phase_name, colour, 31)
	EventBus.camera_shake_requested.emit(Balance.VFX_BOSS_PHASE_SHAKE, 0.48)


func _on_construction_completed(_building_id: String, _tier: int) -> void:
	flash(Color(1.0, 0.72, 0.3), 0.16, 0.32)


## A wave is over. The loudest thing about it should be the quiet.
##
## A pulse out from the town rather than a burst somewhere: what just happened is
## that the pressure came off the city, and the city is where the player's eye
## already is. Deliberately gentler than a kill - a wave clearing is relief, and
## celebrating it as hard as a boss would flatten the difference between them.
func _on_wave_cleared(_wave_number: int) -> void:
	ring(Vector2.ZERO, Balance.TOWN_RADIUS * 2.1, Color(0.62, 0.86, 0.72, 0.5),
		0.7, 3.0)
	flash(Color(0.5, 0.8, 0.65), 0.07, 0.4)


## A boss is down. This one is allowed to be loud.
##
## The boss's own death burst has already played through `enemy_died` - this is
## the *act* landing on top of it, which is why it is a screen flash and a long
## shake rather than another thing at a position.
func _on_boss_defeated_juice(_boss_id: String, _act: int) -> void:
	flash(Color(1.0, 0.86, 0.55), 0.34, 0.9)
	EventBus.camera_shake_requested.emit(9.0, 0.5)


## Levelling up. At the hero, because that is what changed.
##
## Rays rather than a ring: a ring reads as an area of effect, and this is not
## one - nothing on the field has been touched, the player has.
func _on_hero_levelled(level: int, _attribute_points: int, _skill_points: int) -> void:
	var at: Vector2 = _hero_position()
	rays(at, Color(1.0, 0.85, 0.42), 10, 96.0)
	spark(at, Color(1.0, 0.9, 0.6), 14, Vector2.UP, 190.0)
	word(at + Vector2(0.0, -70.0), "LEVEL %d" % level, Color(1.0, 0.88, 0.5), 30)


## Back on your feet. A short exhale, not a celebration.
##
## It marks where the hero *is*, which after eight seconds of watching the field
## without one is genuinely useful information rather than decoration.
func _on_hero_respawned(at: Vector2) -> void:
	ring(at, 92.0, Color(0.86, 0.92, 1.0, 0.6), 0.4, 3.0)
	dust(at, Color(0.8, 0.84, 0.9), 8, 46.0)


## Where the hero this player is driving currently stands.
func _hero_position() -> Vector2:
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero := node as Node2D
		if hero != null:
			return hero.global_position
	return Vector2.ZERO


func _on_relic_socketed(_relic_id: String) -> void:
	flash(Color(0.68, 0.5, 1.0), 0.14, 0.3)


func _on_horn(_duration: float) -> void:
	flash(Color(0.75, 0.35, 0.12), 0.35, 0.8)


func _on_raid_available(_weakened_for: float) -> void:
	flash(Color(0.55, 0.45, 0.85), 0.32, 0.7)


func _on_command_order_used(order_id: String, lane: int, _slot: int, at: Vector2) -> void:
	match order_id:
		"overdrive":
			flash_at(at, Color("fff1b8"), 44.0)
			ring(at, 150.0, Color("e8a33d", 0.78), 0.52, 7.0)
			rays(at, Color("ffd470"), 14, 120.0)
			word(at, "OVERDRIVE", Color("ffd470"), 28)
		"rally_road":
			var direction: Vector2 = Battlefield.lane_vector(lane)
			for distance: float in [Balance.TOWN_RADIUS, Balance.TOWER_SLOT_RADIUS,
					Balance.LANE_SPAWN_RADIUS * 0.72]:
				ring(direction * distance, 124.0, Color("e8a33d", 0.68), 0.58, 7.0)
				rays(direction * distance, Color("fff0bd"), 12, 92.0, direction.angle())
			word(at, "RALLY ROAD", Color("fff0bd"), 30)
			flash(Color("e8a33d"), 0.16, 0.34)
		"last_stand":
			ring(at, Balance.TOWN_RADIUS * 2.1, Color("fff0bd", 0.9), 0.75, 12.0)
			ring(at, Balance.TOWN_RADIUS * 1.4, Color("e8a33d", 0.82), 0.48, 8.0)
			rays(at, Color("fff6d8"), 24, Balance.TOWN_RADIUS * 2.2)
			word(at, "LAST STAND", Color("fff0bd"), 38)
			flash(Color("fff0bd"), 0.38, 0.65)
			EventBus.camera_shake_requested.emit(16.0, 0.55)


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
