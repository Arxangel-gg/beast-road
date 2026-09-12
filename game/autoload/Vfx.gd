extends Node

const BloodBurstScript = preload("res://scripts/systems/blood_burst.gd")

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
## The drawn hit sheets (2026-09-11): a cut for the chain's fast steps, a burst
## for the finisher, embers for a death in a burning region.
const HIT_CUT_ART: String = "res://art/vfx/cut.png"
const HIT_BURST_ART: String = "res://art/vfx/burst.png"
const EMBERS_ART: String = "res://art/vfx/embers.png"
## Regions whose dead go up in embers rather than dust.
const EMBER_TERRAINS: Array[String] = ["ashen_reach", "rustwood"]
const MUZZLE_ART_FORMAT: String = "res://art/vfx/muzzle_%s.png"
const BOSS_BREAK_SHADER: String = "res://scripts/shaders/boss_phase_break.gdshader"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_particle_art()
	_build_screen_layer()

	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.hero_attack_landed.connect(_on_attack_landed)
	EventBus.hero_swing_resolved.connect(_on_swing_resolved)
	EventBus.hero_loosed.connect(_on_hero_loosed)
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
## Authored particle art, loaded once. Missing files leave every effect exactly
## as it was - this layer is an addition, so a damaged install degrades to the
## procedural shapes rather than to nothing.
const RING_TEXTURE_PATH: String = "res://art/vfx/vfx_ring.png"
const SPARK_TEXTURE_PATH: String = "res://art/vfx/vfx_spark.png"

## How much of the ring texture's width the drawn ring actually covers: 98 of
## 128 pixels. Measured rather than assumed, and kept beside the path so that
## redrawing the art means updating one number here.
const RING_ART_FILL: float = 98.0 / 128.0

## And how much of the spark texture's width its teardrop covers: 8 of 32.
const SPARK_ART_FILL: float = 8.0 / 32.0

var _ring_texture: Texture2D = null
var _spark_texture: Texture2D = null


func _load_particle_art() -> void:
	if ResourceLoader.exists(RING_TEXTURE_PATH):
		_ring_texture = load(RING_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(SPARK_TEXTURE_PATH):
		_spark_texture = load(SPARK_TEXTURE_PATH) as Texture2D


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
		_spark_mote(shard, dir * length, colour, life)


## The hot head of a shard. Same additive contract as `_ring_bloom`: a child of
## the streak, tinted by `self_modulate`, carried and faded by the parent's tween.
##
## The streak is what reads as *speed*; the mote is what reads as *matter*. Sat
## at the leading end rather than the origin, because a shard that fades from its
## own tail is what debris does and a lit dot at the back is what a bug looks like.
func _spark_mote(shard: Line2D, tip: Vector2, colour: Color, life: float) -> void:
	if _spark_texture == null:
		return
	var mote := Sprite2D.new()
	mote.texture = _spark_texture
	mote.centered = true
	mote.position = tip
	# The drawn shape is a teardrop with its fat, bright end at local +Y and its
	# taper at -Y, so the head faces the direction of travel at angle - 90deg.
	# Facing it along +X instead - the obvious guess - lays the droplet broadside
	# to its own flight, which reads as tumbling debris rather than a hot mote.
	mote.rotation = tip.angle() - PI * 0.5
	mote.self_modulate = Color(colour.r, colour.g, colour.b, 0.9)
	# Sized against the *drawn* width, not the canvas: the art fills 8 of 32
	# pixels across, so measuring the file would have made every mote a quarter
	# of its intended size - which is exactly what the first version did, and it
	# was invisible on screen rather than wrong-looking.
	var span: float = maxf(float(_spark_texture.get_width()), 1.0) * SPARK_ART_FILL
	# 1.8x the streak's own width. Wider and the head swallows the line that is
	# carrying the sense of speed; the streak is the motion, this is only the
	# matter at the front of it.
	var born: float = shard.width * 1.8 / span
	mote.scale = Vector2.ONE * born
	shard.add_child(mote)
	# Shrinking rather than growing: the piece is cooling as it flies, and a mote
	# that swelled while its streak faded would read as an approaching object.
	mote.create_tween().tween_property(mote, "scale", Vector2.ONE * born * 0.35, life) \
			.set_ease(Tween.EASE_IN)


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
	_ring_bloom(line, to_radius, colour, life)


## The authored rim, laid *under* the procedural ring rather than instead of it.
##
## `ring` and `spark` are the two workhorses of this file - 38 and 35 call sites
## between them, most of what a player ever sees - and both drew bare geometry: a
## polyline circle and coloured line segments. The sprite gives the shockwave a
## soft body and a falloff a one-pixel line cannot have, while the polyline keeps
## the crisp leading edge that reads as the *front* of the wave.
##
## Deliberately additive rather than a replacement. Frames on top of procedural
## motion is how the rest of this project animates: the transform sells the
## movement and the art sells the material. A sprite scaled on its own would just
## be a fading disc.
##
## It is a *child* of the ring, for three reasons that each cost a bug elsewhere:
## the `VFX_MAX_LIVE` cap counts direct children of the container, so a tracked
## sibling would have halved the effective budget; a child dies with its parent,
## so there is no second lifetime to leak; and `modulate` is inherited, so the
## ring's own fade carries the bloom out with it and the two can never desync.
##
## Scaling is safe here in a way it explicitly is not for the Line2D above - a
## Sprite2D has no width in local units to be multiplied by the transform.
##
## The texture is drawn white so `modulate` can tint it to whatever the caller
## asked for. A coloured source multiplies into mud the moment somebody asks for
## blue.
func _ring_bloom(line: Line2D, to_radius: float, colour: Color, life: float) -> void:
	if _ring_texture == null:
		return
	var glow := Sprite2D.new()
	glow.texture = _ring_texture
	glow.centered = true
	# Behind the polyline, so the crisp edge stays the thing the eye lands on.
	glow.z_index = -1
	glow.self_modulate = Color(colour.r, colour.g, colour.b, 0.55)
	# The drawn ring does not reach the edge of its own canvas - it occupies 98 of
	# the texture's 128 pixels - so scaling by diameter alone lands the bloom
	# inside the polyline by about a fifth of the radius, which reads as two
	# separate rings rather than one with a body. The first version did exactly
	# that. Scale by the *visible* span instead.
	var span: float = maxf(float(_ring_texture.get_width()), 1.0) / RING_ART_FILL
	glow.scale = Vector2.ONE * (8.0 / span)
	line.add_child(glow)
	var tween: Tween = glow.create_tween()
	tween.tween_property(glow, "scale", Vector2.ONE * (to_radius * 2.0 / span), life) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


## Floating damage text. Pops in, arcs upward, hangs and fades.
##
## Procedural rather than a fixed rise: the number leaves the body fast, slows
## as it climbs, and lingers at the top of its arc, which is where the eye
## catches it. A big hit climbs further, hangs longer, tilts a few degrees and
## punches past its own size before settling. Every hit pops a little, because a
## number that appears at full size and floats off is a receipt, and the old
## ones were receipts.
func number(at: Vector2, amount: float, colour: Color, big: bool = false) -> void:
	if world == null or amount < 1.0:
		return
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.add_theme_font_size_override("font_size", Balance.VFX_NUMBER_SIZE_BIG if big else Balance.VFX_NUMBER_SIZE)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 8 if big else 6)
	label.z_index = Balance.VFX_Z + 1
	_track(label)
	# Scaled and tilted about its own centre rather than its top-left corner,
	# or the pop swings the text sideways instead of growing it in place.
	label.pivot_offset = label.get_minimum_size() * 0.5
	label.global_position = at + Vector2(randf_range(-14.0, 14.0), -20.0) - label.pivot_offset
	var pop: float = Balance.VFX_NUMBER_POP * (1.15 if big else 1.0)
	label.scale = Vector2.ONE * 0.35
	if big:
		label.rotation_degrees = randf_range(-Balance.VFX_NUMBER_TILT_DEGREES,
			Balance.VFX_NUMBER_TILT_DEGREES)

	var rise: float = Balance.VFX_NUMBER_RISE \
			* (1.0 + (Balance.VFX_NUMBER_BIG_RISE_BONUS if big else 0.0))
	var life: float = Balance.VFX_NUMBER_LIFE * (1.25 if big else 1.0)
	var start: Vector2 = label.global_position
	var sideways: float = randf_range(-26.0, 26.0)
	# Two legs: a fast climb that decelerates into a hang, then a short settle
	# back down while it fades - the arc a thrown thing makes, not a lift.
	var tween: Tween = label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position",
			start + Vector2(sideways * 0.7, -rise), life * 0.55) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.chain().tween_property(label, "global_position",
			start + Vector2(sideways, -rise * 0.82), life * 0.45) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(label, "scale", Vector2.ONE * pop, life * 0.16) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.chain().tween_property(label, "scale", Vector2.ONE, life * 0.24) \
			.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "modulate:a", 0.0, life * 0.5).set_delay(life * 0.5)
	tween.chain().tween_callback(label.queue_free)


## A short bright cone where a tower fired from, plus the element's own flash.
##
## The third beat of the shot, and the one that had no art. A tower firing is
## the most repeated event in the game and it read as: nothing at the barrel, a
## painted bolt in flight, a painted burst on arrival. The origin was a flat
## coloured triangle.
##
## `element` is optional and defaults to none, because two of the three callers
## of a flash like this are not elemental. Given one, the authored frames play
## once *under* the cone - the cone is the instantaneous white-hot stab that
## sells the timing, the sprite is the material.
func muzzle(at: Vector2, direction: Vector2, colour: Color,
		element: int = -1) -> void:
	if world == null:
		return
	# Drawn first, because whether there is art changes what the cone should be.
	var painted: bool = _muzzle_art(at, direction, colour, element)

	var flash := Polygon2D.new()
	# **The cone shrinks and goes white when there is art behind it.**
	#
	# At full size in the element's own colour it was not an accent, it was a
	# flat coloured wedge sitting on top of the flash and winning - a triangle
	# with texture behind it, which reads worse than either alone. What the cone
	# is actually good at is the instant: a hard white stab at the barrel on the
	# frame the shot leaves. So with art it becomes exactly that, and without it
	# stays the whole effect it has always been.
	var length: float = Balance.VFX_MUZZLE_LENGTH * (0.45 if painted else 1.0)
	var spread: float = Balance.VFX_MUZZLE_WIDTH * (0.5 if painted else 1.0)
	flash.polygon = PackedVector2Array([
		Vector2.ZERO,
		Vector2(length, -spread),
		Vector2(length * 1.15, 0.0),
		Vector2(length, spread),
	])
	flash.color = colour.lerp(Color.WHITE, 0.75) if painted else colour
	flash.rotation = direction.angle()
	flash.z_index = Balance.VFX_Z
	_track(flash)
	flash.global_position = at

	var tween: Tween = flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "modulate:a", 0.0, Balance.VFX_MUZZLE_LIFE)
	tween.tween_property(flash, "scale", Vector2(1.35, 0.5), Balance.VFX_MUZZLE_LIFE)
	tween.chain().tween_callback(flash.queue_free)


## Elemental art for the barrel flash, played once.
##
## A *sibling* rather than a child of the cone, unlike the ring's bloom: the cone
## squashes to (1.35, 0.5) as it fades, and a child would be squashed with it -
## which is right for a stretching cone and wrong for a puff of dust. It carries
## its own life instead, and `_track` counts it against the same cap.
##
## Rotated to the shot so a flash reads as coming *out* of the tower, and given
## a random flip so a lane of one tower firing does not stamp the same picture.
func _muzzle_art(at: Vector2, direction: Vector2, colour: Color, element: int) -> bool:
	if element < 0 or world == null:
		return false
	var path: String = MUZZLE_ART_FORMAT % TowerData.element_name(element).to_lower()
	if not ResourceLoader.exists(path):
		return false
	var frames: Array[Texture2D] = GameData.load_idle_frames(path)
	var art := Sprite2D.new()
	art.texture = load(path)
	art.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	art.add_to_group(Graphics.FILTER_GROUP)
	art.modulate = Color(colour.lerp(Color.WHITE, 0.4), 0.9)
	art.rotation = direction.angle()
	art.scale = Vector2(1.0, 1.0 if randf() < 0.5 else -1.0) \
			* (Balance.VFX_MUZZLE_LENGTH * 2.0
			/ maxf(float(art.texture.get_width()), 1.0))
	art.z_index = Balance.VFX_Z - 1
	_track(art)
	art.global_position = at + direction * Balance.VFX_MUZZLE_LENGTH * 0.35

	var life: float = Balance.VFX_MUZZLE_LIFE * 2.2
	if frames.size() > 1:
		var step: Callable = func(index: float) -> void:
			if is_instance_valid(art):
				art.texture = frames[clampi(int(index), 0, frames.size() - 1)]
		art.create_tween().tween_method(step, 0.0, float(frames.size()), life)
	var fade: Tween = art.create_tween()
	fade.tween_property(art, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	fade.tween_callback(art.queue_free)
	return true


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


## A local, quality-cheap phase fracture: one 256px sprite, one short shader,
## then gone. The expanding edge pulses are part of the same fragment pass.
func boss_phase_break(at: Vector2, colour: Color) -> void:
	if world == null or not Graphics.polish_shaders() \
			or not ResourceLoader.exists(BOSS_BREAK_SHADER):
		return
	var fracture := Sprite2D.new()
	fracture.texture = LightKit.falloff_texture()
	fracture.scale = Vector2.ONE * (360.0 \
		/ maxf(float(fracture.texture.get_width()), 1.0))
	fracture.z_index = Balance.VFX_Z + 1
	var material := ShaderMaterial.new()
	material.shader = load(BOSS_BREAK_SHADER) as Shader
	material.set_shader_parameter("crack_colour", colour)
	material.set_shader_parameter("progress", 0.0)
	material.set_shader_parameter("pulses", float(Balance.BOSS_PHASE_EDGE_PULSES))
	fracture.material = material
	_track(fracture)
	fracture.global_position = at
	var drive: Callable = func(value: float) -> void:
		if is_instance_valid(fracture):
			material.set_shader_parameter("progress", value)
	var tween: Tween = fracture.create_tween()
	tween.tween_method(drive, 0.0, 1.0, Balance.BOSS_PHASE_CRACK_DURATION)
	tween.tween_callback(fracture.queue_free)


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


## The weapon itself, carried through the arc with its edge trailing behind it.
##
## Drawn *with* `slash`, not instead of it, because the two say different
## things: the wedge is the area the swing covered, the blade is the object that
## covered it. The wedge alone reads as an area effect centred on the hero; the
## blade alone reads as a sprite sliding through the air.
##
## Degrades silently to nothing when no weapon is worn or its icon is missing.
## A hero with an empty weapon slot still swings, and an unarmed swing that drew
## a phantom blade would be worse than one that draws none.
##
## ## The ribbon, and why it is not a line
##
## Reported as "melee weapon attack sweeps feel a little clunky and slow in
## comparison to the original quick trail only that would happen before... that
## trail with the weapon would be better, with the trail following the weapon's
## tip to hilt, and matching its color" (owner, 2026-09-01). Three separate
## faults, and only one of them was the timing:
##
## * **It was slow.** `VFX_BLADE_LIFE_SCALE` was 1.9, so the blade was still
##   travelling long after the swing had resolved its damage. Now 0.85 - the
##   edge outruns the wedge instead of trailing it.
## * **The trail was a rope.** A single `Line2D` along one radius draws the path
##   of one point on the blade, which reads as something being swung on a chain.
##   A sword's trail is the *area the edge swept*: wide at the point, pinched at
##   the hand. That is a filled strip between two radii, which is what this
##   builds.
## * **It was the wrong colour.** The tint came from the rarity band, so every
##   Fine weapon cut green whatever it was made of. It is sampled from the
##   weapon's own art now, and the rarity band is only the fallback for art that
##   has no colour of its own to give.
func blade_sweep(at: Vector2, direction: Vector2, reach: float, arc_degrees: float,
		texture: Texture2D, tint: Color) -> void:
	if world == null or texture == null:
		return
	var half: float = deg_to_rad(arc_degrees * 0.5)
	# **The same extent the wedge covers, and the same clock.** `slash` turns
	# a +-half wedge through +-0.6*half, so its far edge reaches 1.6*half each
	# side; the blade used to travel 0.85*half and finish a fifth of a second
	# earlier, which read as the weapon falling short of its own trail
	# (owner, 2026-09-11). Both ends are Balance now, and the ribbon is drawn
	# every frame rather than on tween steps, so it no longer tears.
	var from: float = direction.angle() - half * Balance.VFX_BLADE_ARC_SCALE
	var to: float = direction.angle() + half * Balance.VFX_BLADE_ARC_SCALE
	var life: float = Balance.VFX_SLASH_LIFE * Balance.VFX_BLADE_LIFE_SCALE
	var radius: float = reach * Balance.VFX_BLADE_RADIUS

	var pivot := Node2D.new()
	pivot.z_index = Balance.VFX_Z + 1
	_track(pivot)
	pivot.global_position = at
	pivot.rotation = from

	# The ribbon belongs to the world, not to the pivot: it records where the
	# edge has been, so it must not turn with the thing that is still moving.
	var trail := Polygon2D.new()
	# Named so a gate can tell it from the wedge `slash` draws, which is also a
	# Polygon2D centred on the same point.
	trail.name = "BladeRibbon"
	trail.z_index = Balance.VFX_Z
	trail.color = Color.WHITE
	# **Soft across its width, and added rather than painted.** Photographed
	# mid-swing (`blade_shot`, 2026-09-11) the strip had a hard outer rim and a
	# hard straight edge where the swing began, and it multiplied a dark steel
	# colour over the ground so it read as a shadow with a sword in it. The
	# gradient feathers both edges of the strip, the taper in `_draw_blade_trail`
	# removes the straight edge, and additive blending makes it light.
	trail.texture = _ribbon_gradient()
	trail.material = _ribbon_material()
	_track(trail)
	trail.global_position = at

	var blade := Sprite2D.new()
	blade.texture = texture
	blade.modulate = tint
	# The icon is drawn on the up-right diagonal, not upright - checked against
	# the actual sprites rather than assumed. Turning it back by that much makes
	# the point lead along the radius it rides.
	blade.rotation = -deg_to_rad(Balance.VFX_BLADE_ART_DEGREES)
	blade.position = Vector2.RIGHT * radius
	var longest: float = float(maxi(texture.get_width(), texture.get_height()))
	if longest > 0.0:
		blade.scale = Vector2.ONE * (reach * Balance.VFX_BLADE_SIZE / longest)
	pivot.add_child(blade)

	var tween: Tween = pivot.create_tween()
	tween.set_parallel(true)
	# Eased out, so the edge is fastest at the start of the arc. A linear sweep
	# reads as a machine; a swing decelerates into its follow-through.
	tween.tween_property(pivot, "rotation", to, life)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_method(_draw_blade_trail.bind(trail, at, reach, from, to, tint),
		0.0, 1.0, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(blade, "modulate:a", 0.0, life).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(pivot.queue_free)

	var fade: Tween = trail.create_tween()
	fade.tween_interval(life)
	fade.tween_property(trail, "modulate:a", 0.0,
		life * Balance.VFX_BLADE_TRAIL_FADE)
	fade.tween_callback(trail.queue_free)


## Lays the swept area down behind the edge as it travels. Called by a tween, so
## it has to survive the node being freed underneath it - a tween step can land
## on the same frame as the free.
##
## Built as a closed strip: the outer edge runs from the start of the arc to
## wherever the point is now, and the inner edge comes back along the hilt
## radius. Vertex colours fade it toward the tail, which is what makes the shape
## read as speed rather than as a painted crescent.
func _draw_blade_trail(progress: float, trail: Polygon2D, at: Vector2,
		reach: float, from: float, to: float, tint: Color) -> void:
	if not is_instance_valid(trail):
		return
	# **Nothing has been swept yet, so there is no strip to draw.**
	#
	# Every point below is placed at `lerpf(from, to, progress * along)`. At
	# progress zero that is `from` for every one of them, so the outer arc
	# collapses onto a single point, the inner arc onto another, and the polygon
	# has thirty-four vertices and no area. Godot cannot triangulate that and
	# says so: `ERROR: Invalid polygon data, triangulation failed.`
	#
	# It failed a release build on 2026-09-10 and had never failed one before,
	# which is what took the diagnosis to the wrong place first. `tween_method`
	# calls with its start value, so the fault is in *every* swing - but whether
	# the degenerate strip actually reaches the triangulator depends on where the
	# first tween step lands, and on this machine it never did in three full
	# runs of `breather_check`. An error line fails a release even at exit zero,
	# so an intermittent one is a build that fails for nobody's reason.
	#
	# Cleared rather than skipped: an empty polygon is a legal polygon and draws
	# nothing, while leaving the previous frame's shape would freeze the last
	# swing's trail on screen for the length of the next one.
	if progress <= 0.0 or is_equal_approx(from, to):
		trail.polygon = PackedVector2Array()
		trail.vertex_colors = PackedColorArray()
		return
	var hilt: float = reach * Balance.VFX_BLADE_TRAIL_HILT
	var tip: float = reach * Balance.VFX_BLADE_TRAIL_TIP
	var steps: int = Balance.VFX_BLADE_TRAIL_STEPS
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var outer_tint := PackedColorArray()
	var inner_tint := PackedColorArray()
	var outer_uv := PackedVector2Array()
	var inner_uv := PackedVector2Array()
	for i: int in steps + 1:
		var along: float = float(i) / float(steps)
		var angle: float = lerpf(from, to, progress * along)
		var arm: Vector2 = Vector2.RIGHT.rotated(angle)
		# **The strip tapers to its tail.** The inner edge starts a couple of
		# pixels inside the outer one and opens to the hilt radius at the head,
		# so the swing begins as a point rather than a straight cut across the
		# arc. Never to zero width: a strip with coincident edges is the
		# degenerate polygon the comment above is about.
		var spread: float = pow(along, Balance.VFX_BLADE_TRAIL_TAPER)
		var edge: float = lerpf(tip - 2.0, hilt, spread)
		outer.append(arm * tip)
		inner.append(arm * edge)
		outer_uv.append(Vector2(0.0, 0.0))
		inner_uv.append(Vector2(0.0, RIBBON_GRADIENT_HEIGHT))
		var shade: Color = tint
		# The leading edge burns toward white: the steel is ahead of its own
		# smear, and that contrast is what reads as a cut rather than a fan.
		if along > 1.0 - Balance.VFX_BLADE_TRAIL_HOT:
			var heat: float = (along - (1.0 - Balance.VFX_BLADE_TRAIL_HOT)) \
				/ Balance.VFX_BLADE_TRAIL_HOT
			shade = shade.lerp(Color.WHITE, heat * Balance.VFX_BLADE_TRAIL_HEAT)
		shade.a = lerpf(Balance.VFX_BLADE_TRAIL_TAIL_ALPHA,
			Balance.VFX_BLADE_TRAIL_HEAD_ALPHA, along)
		outer_tint.append(shade)
		# The hilt side is dimmer at every step: the hand moves slowly and the
		# point moves fast, and the trail should say so.
		var near: Color = shade
		near.a *= 0.35
		inner_tint.append(near)

	# Down the outer edge and back along the inner one, so the two arcs close
	# into one strip rather than crossing themselves.
	inner.reverse()
	inner_tint.reverse()
	inner_uv.reverse()
	var shape := PackedVector2Array(outer)
	shape.append_array(inner)
	var shades := PackedColorArray(outer_tint)
	shades.append_array(inner_tint)
	var uvs := PackedVector2Array(outer_uv)
	uvs.append_array(inner_uv)
	trail.polygon = shape
	trail.vertex_colors = shades
	trail.uv = uvs
	trail.global_position = at


## The ribbon's cross-width gradient: clear at both edges, full in the middle.
## A `Polygon2D` reads its texture in pixels, so the strip's outer vertices sit
## at v = 0 and its inner ones at v = RIBBON_GRADIENT_HEIGHT.
const RIBBON_GRADIENT_HEIGHT: float = 64.0
var _ribbon_texture: GradientTexture2D = null
var _ribbon_glow: CanvasItemMaterial = null


func _ribbon_gradient() -> GradientTexture2D:
	if _ribbon_texture != null:
		return _ribbon_texture
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.7, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	_ribbon_texture = GradientTexture2D.new()
	_ribbon_texture.gradient = ramp
	_ribbon_texture.width = 4
	_ribbon_texture.height = int(RIBBON_GRADIENT_HEIGHT)
	_ribbon_texture.fill_from = Vector2(0.0, 0.0)
	_ribbon_texture.fill_to = Vector2(0.0, 1.0)
	return _ribbon_texture


func _ribbon_material() -> CanvasItemMaterial:
	if _ribbon_glow != null:
		return _ribbon_glow
	_ribbon_glow = CanvasItemMaterial.new()
	_ribbon_glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _ribbon_glow


## The colour a weapon actually is, averaged from its own art.
##
## The blade trail used to be tinted by *rarity*, which meant every Fine weapon
## cut green and every Runed one cut blue whatever it was made of - so the one
## piece of feedback that could have said "you are holding a rime maul" said
## "this drop was a good one", a fact the player already knew.
##
## Averaged over the opaque pixels and weighted toward the saturated ones, so a
## mostly-grey blade with a red grip does not come out grey: the eye names a
## weapon by its accent, not by its bulk. Cached per texture - this reads an
## image, and a swing happens three times a second.
var _blade_tints: Dictionary = {}


func blade_tint(texture: Texture2D, fallback: Color) -> Color:
	if texture == null:
		return fallback
	var key: String = texture.resource_path
	if key.is_empty():
		return fallback
	if _blade_tints.has(key):
		return _blade_tints[key]
	var image: Image = texture.get_image()
	if image == null:
		_blade_tints[key] = fallback
		return fallback
	var total := Vector3.ZERO
	var weight: float = 0.0
	# A grid rather than every pixel: an icon is 128 square and the answer does
	# not change between neighbours.
	var step: int = maxi(1, image.get_width() / 24)
	for x: int in range(0, image.get_width(), step):
		for y: int in range(0, image.get_height(), step):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.a < 0.5:
				continue
			# Saturation plus a floor: a pure steel blade has almost none, and
			# weighting only by saturation would divide by nothing.
			var pull: float = 0.25 + pixel.s * pixel.v
			total += Vector3(pixel.r, pixel.g, pixel.b) * pull
			weight += pull
	if weight <= 0.0:
		_blade_tints[key] = fallback
		return fallback
	var mean := Color(total.x / weight, total.y / weight, total.z / weight)
	# Lifted toward white. An average is always duller than the thing it
	# averages, and a trail the colour of the blade's shadow reads as smoke.
	mean = mean.lerp(Color.WHITE, 0.4)
	if mean.s > 0.02:
		mean.s = minf(mean.s * 1.35, 1.0)
	mean.v = maxf(mean.v, 0.72)
	_blade_tints[key] = mean
	return mean

## The icon of the weapon the player is wearing, and the colour of its rarity.
## Returns a null texture when the slot is empty, which every caller reads as
## "draw no blade".
func _worn_blade() -> Array:
	var piece: Dictionary = MetaState.equipped_piece(GearData.Slot.WEAPON)
	if piece.is_empty():
		return [null, Color.WHITE]
	var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
	if kind == null:
		return [null, Color.WHITE]
	var path: String = kind.get_sprite_path()
	if not ResourceLoader.exists(path):
		return [null, Color.WHITE]
	return [load(path) as Texture2D, Stash.rarity_colour(piece)]


## The bow, shown for the length of one release and then gone.
##
## **No arrow is drawn here.** The arrow is a real projectile with real damage
## that the hero spawns and the field owns; painting a second one into the
## animation would put a shaft on screen that hits nothing, and the two would
## disagree the moment the real one was blocked.
##
## Driven by `hero_loosed` rather than by the hero, for the same reason the
## blade is driven by `hero_swing_resolved`: in co-op a guest's own shots are
## the ones it must never miss seeing.
func bow_loose(at: Vector2, direction: Vector2) -> void:
	if world == null:
		return
	var weapon: RangedWeaponData = ContentDB.ranged_weapons.get(RunState.ranged_id, null)
	if weapon == null:
		return
	var path: String = weapon.get_sprite_path()
	if not ResourceLoader.exists(path):
		return
	var texture := load(path) as Texture2D
	if texture == null:
		return

	var heading: Vector2 = direction.normalized() if direction.length() > 0.001 else Vector2.RIGHT
	var bow := Sprite2D.new()
	bow.texture = texture
	bow.z_index = Balance.VFX_Z + 1
	# Turned back by however its own art was painted, then aimed. Two weapons,
	# two conventions - see `RangedWeaponData.art_degrees`.
	bow.rotation = heading.angle() - deg_to_rad(weapon.art_degrees)
	var longest: float = float(maxi(texture.get_width(), texture.get_height()))
	if longest > 0.0:
		bow.scale = Vector2.ONE * (Balance.VFX_BOW_SIZE / longest)
	_track(bow)
	bow.global_position = at + heading * Balance.VFX_BOW_OFFSET

	# The kick is backwards along the shot, which is the whole read: the arrow
	# left, and the thing that threw it moved the other way.
	var kicked: Vector2 = bow.global_position - heading * Balance.VFX_BOW_RECOIL
	var tween: Tween = bow.create_tween()
	tween.tween_property(bow, "global_position", kicked, Balance.VFX_BOW_LIFE * 0.25) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(bow, "global_position", bow.global_position,
		Balance.VFX_BOW_LIFE * 0.4).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(bow, "modulate:a", 0.0, Balance.VFX_BOW_LIFE * 0.75) \
			.set_delay(Balance.VFX_BOW_LIFE * 0.25)
	tween.tween_callback(bow.queue_free)

	# The string letting go, at the bow rather than at the arrow.
	spark(bow.global_position, Color("ffe6b4"), 4, heading, 260.0)


func _on_hero_loosed(from: Vector2, direction: Vector2, _ammo_id: String) -> void:
	bow_loose(from, direction)


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
	_play_burst_frames(burst, path)
	tween.chain().tween_callback(burst.queue_free)


## A drawn burst at a point: any authored frame sequence, played once.
##
## `impact` is this for the four elements; this is the general one, for the
## splash a cast makes, the rings a bite spreads, the sparks a blow throws.
## Additive for light on water and on steel, mixed for water itself.
func sheet_burst(at: Vector2, path: String, size: float, tint: Color = Color.WHITE,
		additive: bool = false, rotation_radians: float = 0.0) -> void:
	if world == null or not ResourceLoader.exists(path):
		return
	var burst := Sprite2D.new()
	burst.texture = load(path)
	burst.rotation = rotation_radians
	burst.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	burst.add_to_group(Graphics.FILTER_GROUP)
	burst.modulate = tint
	burst.z_index = Balance.VFX_Z
	if additive:
		var glow := CanvasItemMaterial.new()
		glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		burst.material = glow
	_track(burst)
	burst.global_position = at
	burst.scale = Vector2.ONE * (size / maxf(float(burst.texture.get_width()), 1.0))
	var frames: Array[Texture2D] = GameData.load_idle_frames(path)
	var life: float = float(maxi(frames.size(), 3)) / Balance.VFX_ART_FRAME_RATE
	var tween: Tween = burst.create_tween()
	tween.tween_property(burst, "modulate:a", 0.0, life * 0.35).set_delay(life * 0.65)
	_play_burst_frames(burst, path)
	tween.chain().tween_callback(burst.queue_free)


## Steps an impact through its authored frames, once, over the life of the
## burst.
##
## Played through rather than looped: an impact happens, it does not idle. A
## loop on a 0.3-second sprite would show the same second frame twice and read
## as a stutter rather than as a hit.
##
## Frame zero is the ordinary texture, so an element that ships one drawing has
## an empty sequence here and keeps exactly the behaviour it had before any of
## this existed.
func _play_burst_frames(burst: Sprite2D, path: String) -> void:
	var frames: Array[Texture2D] = GameData.load_idle_frames(path)
	if frames.size() < 2:
		return
	var step: Callable = func(index: float) -> void:
		if is_instance_valid(burst):
			burst.texture = frames[clampi(int(index), 0, frames.size() - 1)]
	burst.create_tween().tween_method(step, 0.0, float(frames.size()),
		float(frames.size()) / Balance.VFX_ART_FRAME_RATE)


## Optional character-hit layer. Procedural droplets leave their persistent
## marks at their own landing points, so gore is correctly body-anchored and no
## bitmap stamp appears at an actor's feet. Presentation remains local: co-op
## machines derive it from the same authoritative health/death facts.
func blood(at: Vector2, direction: Vector2, size: float,
		ground_at: Vector2 = Vector2.INF) -> void:
	if world == null or not bool(UserSettings.value(UserSettings.BLOOD_VFX_KEY, true)):
		return
	var floor_at: Vector2 = ground_at
	if floor_at == Vector2.INF:
		floor_at = at + Vector2(0.0, size * 0.62)
	var burst: Node2D = BloodBurstScript.new() as Node2D
	burst.configure(at, floor_at, direction, size, _ground, _blood_rng)
	_track(burst)
	burst.global_position = at


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
	muzzle(origin, (at - origin).normalized(), colour, tower.element)


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
func _on_swing_resolved(at: Vector2, aim: Vector2, reach: float, step: int) -> void:
	# The step is told, not inferred. It used to be recovered by matching `reach`
	# against the range table, which a weapon's own reach scale defeats
	# completely - every swing would have read as a first step.
	var index: int = clampi(step, 0, Balance.HERO_ATTACK_ARC_DEGREES.size() - 1)
	var arc: float = Balance.HERO_ATTACK_ARC_DEGREES[index]
	var finisher: bool = index >= Balance.HERO_CHAIN_LENGTH - 1
	var blade: Array = _worn_blade()
	var texture := blade[0] as Texture2D
	# **The wedge only when there is no blade.** It is the area the swing
	# covered, which is exactly the information the ribbon now carries - and
	# carries better, because it is the shape of the weapon rather than a fan
	# from the hero's chest. Drawn together they read as one heavy grey flash
	# with a sword inside it, which is the whole of "melee weapon attack sweeps
	# feel a little clunky" (owner, 2026-09-01). An unarmed hero still swings,
	# and still needs to see something.
	if texture == null:
		slash(at, aim, reach, arc,
			Color(0.95, 0.88, 0.72, 0.28 if finisher else 0.18))
	# The blade's own colour, sampled from its art, with the rarity band kept as
	# the fallback for a weapon whose icon has nothing to say.
	blade_sweep(at, aim, reach, arc, texture,
		blade_tint(texture, (blade[1] as Color).lerp(Color.WHITE, 0.35)))


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
	# **Drawn steel over the procedural sparks** (2026-09-11). The sparks carry
	# direction and count; the sheet carries the look of a blow - a thin bright
	# cut for the fast steps, a white-hot burst for the finisher - and both
	# were made from the same PixelLab concept sheet so they belong together.
	# Added rather than mixed, so they read on a dark road and a bright one.
	sheet_burst(at + aim * 56.0, HIT_CUT_ART if not finisher else HIT_BURST_ART,
		Balance.VFX_HIT_SHEET_SIZE * (1.35 if finisher else 1.0),
		Color(1.0, 0.95, 0.85, 0.95), true, aim.angle() if not finisher else 0.0)
	if finisher:
		ring(at, 70.0, Color(1.0, 0.82, 0.5, 0.55), 0.3, 5.0)
		rays(at + aim * 46.0, Color(1.0, 0.9, 0.67, 0.85), 9, 68.0, aim.angle())
		flash_at(at + aim * 54.0, Color("ffd99b"), 22.0)


func _on_enemy_died(enemy_id: String, at: Vector2) -> void:
	var data: EnemyData = ContentDB.enemy(enemy_id)
	var colour := Color("c96a4a")
	var spark_count: int = 10
	var radius: float = 34.0
	var swell: float = _feed_momentum(at)
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
	# The streak swells the burst rather than adding a second one beside it: one
	# louder death reads as momentum, two deaths reads as a bug.
	spark_count = int(round(float(spark_count) * swell))
	radius *= lerpf(1.0, 1.25, clampf(swell - 1.0, 0.0, 1.0))
	spark(at, colour, spark_count, Vector2.ZERO, 220.0 + radius)
	blood(at, Vector2.ZERO, maxf(Balance.VFX_BLOOD_DEATH_SIZE, radius * 1.05))
	dust(at, Color(0.34, 0.22, 0.18, 0.34), 4 + spark_count / 5, radius * 0.9)
	ring(at, radius, Color(colour, 0.48), 0.28 + radius / 500.0, 3.0 + radius / 35.0)
	flash_at(at, colour, 14.0 + radius * 0.18)
	if data != null and data.category != EnemyData.Category.BREED:
		rays(at, colour.lerp(Color.WHITE, 0.42), 8 if data.category == EnemyData.Category.ELITE else 16,
			radius * 1.25)
	# In a burning region the dead go up in embers rather than dust: the same
	# death, dressed for where it happened.
	if EMBER_TERRAINS.has(RunState.terrain_id):
		sheet_burst(at + Vector2(0.0, -radius * 0.4), EMBERS_ART, radius * 2.4,
			Color(1.0, 0.9, 0.75, 0.9), true)


func _on_hero_damaged(amount: float, from: Vector2, at: Vector2) -> void:
	number(at, amount, Color("ff6b5a"), true)
	var direction: Vector2 = (at - from).normalized()
	spark(at, Color("ff8a7a"), 8, direction, 200.0)
	var hero: Hero = Hero.nearest_on_field(get_tree(), at)
	blood(at, direction, Balance.VFX_BLOOD_HIT_SIZE,
		hero.global_position if hero != null else Vector2.INF)
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
	boss_phase_break(at, colour)
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


# --- Kill momentum -----------------------------------------------------------
#
# A rising crescendo as the hero cuts through a pack.
#
# **It lives here because `Vfx` cannot reach anything that matters.** This node
# has no path to damage, health, currency or the wave director, so a streak
# implemented in it is cosmetic by construction rather than by discipline. A
# momentum system that quietly buffed damage would be a difficulty change the
# three-act curve was never tuned against, and would belong in the GDD rather
# than in a polish pass.
#
# Deaths from every source feed it - a tower kill counts. The player is watching
# one road, not their own hit count, and a streak that ignored the towers would
# go quiet during exactly the moments the defence is working.

## Kills in the current streak, and when the last one landed.
var _streak: int = 0
var _streak_at_ms: int = 0

## The highest tier announced so far this streak, so a word is shown once when it
## is crossed rather than on every kill above it.
var _streak_tier: int = -1


## Records a kill and returns how much to swell its death burst by.
##
## Returns 1.0 at rest, so every existing caller is unchanged when nothing is
## streaking. The window is checked against the wall clock rather than a delta:
## hitstop sets `Engine.time_scale` to zero, and a streak timed with the frame
## delta would stop decaying during exactly the freezes that kills cause.
func _feed_momentum(at: Vector2) -> float:
	var now: int = Time.get_ticks_msec()
	if now - _streak_at_ms > int(Balance.MOMENTUM_WINDOW * 1000.0):
		_streak = 0
		_streak_tier = -1
	_streak_at_ms = now
	_streak += 1

	var tier: int = -1
	for index: int in Balance.MOMENTUM_TIERS.size():
		if _streak >= Balance.MOMENTUM_TIERS[index]:
			tier = index
	if tier < 0:
		return 1.0

	var colour: Color = Balance.MOMENTUM_COLOURS[tier]
	if tier > _streak_tier:
		# Announced once, on the kill that crossed it. Said every kill above the
		# threshold it would be a word sitting permanently on the screen, which
		# is wallpaper rather than an event.
		_streak_tier = tier
		word(at + Vector2(0.0, -70.0), Balance.MOMENTUM_WORDS[tier], colour, 30 + tier * 4)
		EventBus.camera_shake_requested.emit(
			Balance.MOMENTUM_SHAKE * (float(tier + 1) / float(Balance.MOMENTUM_TIERS.size())),
			0.22)
		rays(at, colour, 10 + tier * 4, 90.0 + float(tier) * 26.0)

	var reach: float = float(tier + 1) / float(Balance.MOMENTUM_TIERS.size())
	return lerpf(1.0, Balance.MOMENTUM_BURST_SCALE, reach)


## Where the streak stands, for anything that wants to read it. Nothing in
## gameplay does, and nothing should - see the note above.
func momentum_streak() -> int:
	if Time.get_ticks_msec() - _streak_at_ms > int(Balance.MOMENTUM_WINDOW * 1000.0):
		return 0
	return _streak
